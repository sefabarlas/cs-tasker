// lib/data/task_repository.dart
import 'package:timezone/timezone.dart' as tz;
import '../models/task.dart';
import '../src/notifications/notification_service.dart';
import '../data/task_db.dart';

class TaskRepository {
  final TaskDb _db;
  TaskRepository(this._db);

  Future<List<Task>> list() => _db.getAll();
  Future<Task?> getById(int id) => _db.getById(id);

  Future<void> add(Task t) async {
    // yeni not-done görevlerin sort'u listenin sonuna: index*1000
    final allItems = await _db.getAll();
    final lastIndex = allItems.where((e) => !e.done).length;

    final now = DateTime.now();
    final toInsert = t.copyWith(
      sort: lastIndex * 1000,
      createdAt: now,           // 🆕 oluşturulma zamanı
      updatedAt: null,          // ilk eklemede yok
    );

    final id = await _db.insert(toInsert);
    await _rescheduleNotificationForTask(toInsert.copyWith(id: id));
  }

  Future<void> update(Task t) async {
    final now = DateTime.now();
    final toSave = t.copyWith(updatedAt: now); // 🆕 güncellenme zamanı
    await _db.update(toSave);
    await _rescheduleNotificationForTask(toSave);
  }

  Future<void> delete(int id) async {
    await _db.delete(id);
    await NotificationService.cancel(id); // planlanmış hatırlatmayı da kaldır
  }

    Future<void> deleteAll() async {
    final list = await _db.getAll();
    for (final t in list) {
      await _db.delete(t.id!);
    }
  }

  Future<void> addMany(List<Task> tasks) async {
    for (final t in tasks) {
      await _db.insert(t);
    }
  }

  /// Sürükleyerek sıralama: sadece tamamlanmamış listede çalışır.
  Future<List<Task>> reorder(int oldIndex, int newIndex) async {
    final items = await _db.getAll();
    final undone = items.where((e) => !e.done).toList();
    if (newIndex > undone.length) newIndex = undone.length;
    if (newIndex > oldIndex) newIndex -= 1;

    final moved = undone.removeAt(oldIndex);
    undone.insert(newIndex, moved);

    for (var i = 0; i < undone.length; i++) {
      undone[i] = undone[i].copyWith(sort: i * 1000, updatedAt: DateTime.now());
    }

    await _db.updateMany(undone);
    return _db.getAll();
  }

  /// Bildirim planlama/iptal mantığını tek yerde topluyoruz.
  Future<void> _rescheduleNotificationForTask(Task t) async {
    if (t.id != null) {
      await NotificationService.cancel(t.id!);
    }

    if (t.id == null || t.done || t.due == null) return;

    final now = DateTime.now();
    DateTime due = t.due!;
    if (!due.isAfter(now)) {
      switch (t.repeat) {
        case RepeatRule.daily:
          while (!due.isAfter(now)) {
            due = due.add(const Duration(days: 1));
          }
          break;
        case RepeatRule.weekly:
          while (!due.isAfter(now)) {
            due = due.add(const Duration(days: 7));
          }
          break;
        case RepeatRule.monthly:
          while (!due.isAfter(now)) {
            due = DateTime(due.year, due.month + 1, due.day, due.hour, due.minute);
          }
          break;
        case RepeatRule.none:
          return;
      }
    }

    final when = tz.TZDateTime.from(due, tz.local);
    final title = 'Görev: ${t.title}';
    final body = (t.note?.isNotEmpty ?? false) ? t.note! : 'Hatırlatma zamanı geldi.';
    final payload = 'taskId:${t.id}';

    switch (t.repeat) {
      case RepeatRule.none:
        await NotificationService.scheduleAt(
          id: t.id!,
          title: title,
          body: body,
          when: when,
          payload: payload,
        );
        break;
      case RepeatRule.daily:
        await NotificationService.scheduleDaily(
          id: t.id!,
          title: title,
          body: body,
          firstTime: when,
          payload: payload,
        );
        break;
      case RepeatRule.weekly:
        await NotificationService.scheduleWeekly(
          id: t.id!,
          title: title,
          body: body,
          firstTime: when,
          payload: payload,
        );
        break;
      case RepeatRule.monthly:
        await NotificationService.scheduleMonthly(
          id: t.id!,
          title: title,
          body: body,
          firstTime: when,
          payload: payload,
        );
        break;
    }
  }
}