import 'package:drift/drift.dart' as d;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasker/src/ui/providers.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/task.dart';
import '../src/data/db.dart' hide Task;
import '../src/notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

const _uuid = Uuid();

// Repository'i sağlayan Riverpod Provider'ı güncellendi
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.read(appDbProvider);
  return TaskRepository(db);
});

class TaskRepository {
  final AppDb _db;

  TaskRepository(this._db);

  Stream<List<Task>> findAll() {
    final query = _db.select(_db.tasks)
      ..orderBy([
        (t) => d.OrderingTerm(
          expression: _db.tasks.done.cast<int>(d.DriftSqlType.int),
          mode: d.OrderingMode.asc,
        ),

        (t) => d.OrderingTerm(
          expression: _db.tasks.sort,
          mode: d.OrderingMode.asc,
        ),
      ]);
    return query.watch().map((driftTasks) {
      return driftTasks.map((driftTask) => Task.fromDrift(driftTask)).toList();
    });
  }

  Future<List<Task>> list() => findAll().first;

  Future<Task?> getById(String id) async {
    final query = _db.select(_db.tasks)..where((t) => t.id.equals(id));
    final result = await query.getSingleOrNull();
    return result != null ? Task.fromDrift(result) : null;
  }

  Future<String> add(Task task) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();

    // En son sıraya eklemek için sort değerini bul (undone görevler için)
    final lastSort =
        await (_db.select(_db.tasks)
              ..where((t) => t.done.equals(false))
              ..orderBy([
                (t) => d.OrderingTerm(
                  expression: _db.tasks.sort,
                  mode: d.OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .map((row) => row.sort)
            .getSingleOrNull();

    final nextSort = (lastSort ?? 0) + 1000;

    final companion = TasksCompanion.insert(
      id: id,
      title: task.title,
      notes: d.Value(task.note),
      done: d.Value(task.done),
      due: d.Value(task.due?.millisecondsSinceEpoch), // DateTime -> int
      repeat: d.Value(task.repeat.index),
      sort: d.Value(nextSort),
      createdAtUtc: now,
      updatedAtUtc: d.Value(null),
    );

    await _db.into(_db.tasks).insert(companion);

    final newTask = task.copyWith(id: id);
    _rescheduleNotificationForTask(newTask);

    return id;
  }

  Future<bool> update(Task task) async {
    if (task.id == null) return false;
    final now = DateTime.now().toUtc();

    final companion = TasksCompanion(
      id: d.Value(task.id!),
      title: d.Value(task.title),
      notes: d.Value(task.note),
      done: d.Value(task.done),
      due: d.Value(task.due?.millisecondsSinceEpoch),
      repeat: d.Value(task.repeat.index),
      sort: d.Value(task.sort),
      updatedAtUtc: d.Value(now),
    );

    final count = await (_db.update(
      _db.tasks,
    )..where((t) => t.id.equals(task.id!))).write(companion);

    _rescheduleNotificationForTask(task);

    return count == 1;
  }

  Future<int> delete(String id) async {
    final count = await (_db.delete(
      _db.tasks,
    )..where((t) => t.id.equals(id))).go();

    final notificationId = int.tryParse(id) ?? id.hashCode;
    NotificationService.cancel(notificationId);

    return count;
  }

  Future<int> deleteModel(Task t) async {
    if (t.id == null) return 0;
    return delete(t.id!);
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.tasks).go();
  }

  Future<void> reorder(List<Task> tasks) async {
    await _db.transaction(() async {
      for (final task in tasks) {
        if (!task.done && task.id != null) {
          await (_db.update(_db.tasks)..where((t) => t.id.equals(task.id!)))
              .write(TasksCompanion(sort: d.Value(task.sort)));
        }
      }
    });
  }

  /// Görevin durumuna göre bildirimleri yeniden planlar veya iptal eder.
  void _rescheduleNotificationForTask(Task task) {
    if (task.id == null) return;

    final notificationId = int.tryParse(task.id!) ?? task.id.hashCode;

    if (task.due == null || task.done) {
      NotificationService.cancel(notificationId);
      return;
    }

    DateTime due = task.due!;
    final now = DateTime.now();
    bool shouldReschedule = false;

    // Eğer bitiş tarihi geçmişse ve tekrar kuralı varsa, tarihi ileri al
    if (due.isBefore(now) && task.repeat != RepeatRule.none) {
      while (due.isBefore(now)) {
        switch (task.repeat) {
          case RepeatRule.daily:
            due = due.add(const Duration(days: 1));
            break;
          case RepeatRule.weekly:
            due = due.add(const Duration(days: 7));
            break;
          case RepeatRule.monthly:
            // Ay sonu sorunlarını ele al
            due = DateTime(
              due.year,
              due.month + 1,
              due.day,
              due.hour,
              due.minute,
            );
            break;
          case RepeatRule.none:
            break; // should not happen
        }
        shouldReschedule = true;
      }
    }

    if (shouldReschedule) {
      // Tarih ileri alındıysa, update metodu zaten reschedule'ı tekrar çağıracak.
      update(task.copyWith(due: due));
      return;
    }

    final tzWhen = tz.TZDateTime.from(due, tz.local);

    // Normal planlama
    switch (task.repeat) {
      case RepeatRule.none:
        NotificationService.scheduleAt(
          id: notificationId,
          title: task.title,
          body: task.note,
          when: tzWhen,
        );
        break;
      case RepeatRule.daily:
        NotificationService.scheduleDaily(
          id: notificationId,
          title: task.title,
          body: task.note,
          firstTime: tzWhen,
        );
        break;
      case RepeatRule.weekly:
        NotificationService.scheduleWeekly(
          id: notificationId,
          title: task.title,
          body: task.note,
          firstTime: tzWhen,
        );
        break;
      case RepeatRule.monthly:
        NotificationService.scheduleMonthly(
          id: notificationId,
          title: task.title,
          body: task.note,
          firstTime: tzWhen,
        );
        break;
    }
  }
}
