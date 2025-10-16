// lib/data/task_repository.dart
import 'package:drift/drift.dart' as d;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasker/src/ui/providers.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../models/task.dart' as model_task;
import '../src/data/db.dart' hide Task;
import '../src/notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

const _uuid = Uuid();

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.read(appDbProvider);
  return TaskRepository(db);
});

class TaskRepository {
  final AppDb _db;

  TaskRepository(this._db);

  Stream<List<model_task.Task>> findAll() {
    final taskQuery = _db.select(_db.tasks)
      ..orderBy([
        (t) => d.OrderingTerm(expression: t.done.cast<int>(d.DriftSqlType.int), mode: d.OrderingMode.asc),
        (t) => d.OrderingTerm(expression: t.sort, mode: d.OrderingMode.asc),
      ]);

    return taskQuery.watch().asyncMap((driftTasks) async {
      final taskIds = driftTasks.map((t) => t.id).toList();
      if (taskIds.isEmpty) {
        return driftTasks.map((driftTask) => model_task.Task.fromDrift(driftTask, tags: [])).toList();
      }
      
      final tagsQuery = _db.select(_db.taskTags).join([
        d.innerJoin(_db.tags, _db.tags.id.equalsExp(_db.taskTags.tagId))
      ])..where(_db.taskTags.taskId.isIn(taskIds));

      final tagLinks = await tagsQuery.get();
      final tagsByTaskId = <String, List<model_task.Tag>>{};
      for (final row in tagLinks) {
        final tag = row.readTable(_db.tags);
        final taskId = row.readTable(_db.taskTags).taskId;
        (tagsByTaskId[taskId] ??= []).add(model_task.Tag(id: tag.id, name: tag.name));
      }

      return driftTasks.map((driftTask) {
        return model_task.Task.fromDrift(driftTask, tags: tagsByTaskId[driftTask.id] ?? []);
      }).toList();
    });
  }

  Future<List<model_task.Task>> list() => findAll().first;

  Future<model_task.Task?> getById(String id) async {
    final taskQuery = _db.select(_db.tasks)..where((t) => t.id.equals(id));
    final taskResult = await taskQuery.getSingleOrNull();
    if (taskResult == null) return null;

    final tagsQuery = _db.select(_db.taskTags).join([
      d.innerJoin(_db.tags, _db.tags.id.equalsExp(_db.taskTags.tagId))
    ])..where(_db.taskTags.taskId.equals(id));
    final tagResults = await tagsQuery.get();
    final tags = tagResults.map((row) => model_task.Tag(id: row.readTable(_db.tags).id, name: row.readTable(_db.tags).name)).toList();
    return model_task.Task.fromDrift(taskResult, tags: tags);
  }

  Future<String> add(model_task.Task task) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    final lastSort = await (_db.select(_db.tasks)..where((t) => t.done.equals(false))..orderBy([(t) => d.OrderingTerm(expression: t.sort, mode: d.OrderingMode.desc)])..limit(1)).map((row) => row.sort).getSingleOrNull();
    final nextSort = (lastSort ?? 0) + 1000;

    final companion = TasksCompanion.insert(
      id: id,
      title: task.title,
      notes: d.Value(task.note),
      done: d.Value(task.done),
      due: d.Value(task.due?.millisecondsSinceEpoch),
      repeat: d.Value(task.repeat.index),
      sort: d.Value(nextSort),
      createdAtUtc: now,
      priority: d.Value(task.priority.index), // YENİ: priority eklendi
    );

    await _db.transaction(() async {
      await _db.into(_db.tasks).insert(companion);
      await _updateTagsForTask(id, task.tags);
    });

    final newTask = task.copyWith(id: id);
    _rescheduleNotificationForTask(newTask);
    return id;
  }

  Future<bool> update(model_task.Task task) async {
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
      priority: d.Value(task.priority.index), // YENİ: priority eklendi
    );

    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(task.id!))).write(companion);
      await _updateTagsForTask(task.id!, task.tags);
    });

    _rescheduleNotificationForTask(task);
    return true;
  }

  // YENİ: Test verilerini eklemek için metod
  Future<void> insertSampleData() async {
    // Önce mevcut tüm verileri temizle
    await deleteAll();

    // Test için etiket nesneleri
    final tagIs = model_task.Tag(id: '1', name: 'İş');
    final tagKisisel = model_task.Tag(id: '2', name: 'Kişisel');
    final tagAcil = model_task.Tag(id: '3', name: 'Acil');
    final tagHobi = model_task.Tag(id: '4', name: 'Hobi');

    // Tarihleri ayarla
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    final nextWeek = today.add(const Duration(days: 7));

    final List<model_task.Task> sampleTasks = [
      model_task.Task(title: 'Müşteri raporunu gönder', note: 'Q3 satış verilerini içeren acil rapor.', priority: model_task.Priority.high, due: yesterday.add(const Duration(hours: 17)), tags: [tagIs, tagAcil], done: false),
      model_task.Task(title: 'Proje sunumunu hazırla', note: 'Saat 14:00 toplantısı için son hazırlıklar.', priority: model_task.Priority.high, due: today.add(const Duration(hours: 11)), tags: [tagIs], done: false),
      model_task.Task(title: 'Ekip toplantısı notlarını paylaş', priority: model_task.Priority.medium, due: today.add(const Duration(hours: 10)), tags: [tagIs], done: true),
      model_task.Task(title: 'Doktor randevusunu onayla', note: 'Saat 16:30 için olan randevuyu ara ve onayla.', priority: model_task.Priority.medium, due: tomorrow.add(const Duration(hours: 16, minutes: 30)), tags: [tagKisisel], done: false),
      model_task.Task(title: 'Kütüphaneden kitapları iade et', priority: model_task.Priority.low, due: nextWeek.add(const Duration(hours: 12)), tags: [tagKisisel, tagHobi], done: false),
      model_task.Task(title: 'Yeni Flutter paketlerini araştır', note: 'State management ve animasyon için yeni çözümler.', priority: model_task.Priority.low, tags: [tagHobi], done: false),
      model_task.Task(title: 'Günlük yedeklemeyi kontrol et', priority: model_task.Priority.none, repeat: model_task.RepeatRule.daily, due: today.add(const Duration(hours: 22)), tags: [tagIs], done: false),
      model_task.Task(title: 'Market alışverişi yap', note: 'Süt, ekmek, yumurta', priority: model_task.Priority.none, tags: [tagKisisel], done: false),
      model_task.Task(title: 'Faturaları öde', priority: model_task.Priority.medium, due: today.subtract(const Duration(days: 5)), tags: [tagKisisel], done: true),
    ];
    
    // Her bir görevi veritabanına ekle
    for (final task in sampleTasks) {
      await add(task);
    }
  }
  
  Future<List<model_task.Tag>> getAllTags() async {
    final driftTags = await (_db.select(_db.tags)..orderBy([(t) => d.OrderingTerm(expression: t.name)])).get();
    return driftTags.map((tag) => model_task.Tag(id: tag.id, name: tag.name)).toList();
  }

  Future<void> _updateTagsForTask(String taskId, List<model_task.Tag> tags) async {
    await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(taskId))).go();
    if (tags.isEmpty) return;
    final tagIdsToLink = <String>[];
    for (final tagModel in tags) {
      final existingTag = await (_db.select(_db.tags)..where((t) => t.name.equals(tagModel.name))).getSingleOrNull();
      if (existingTag != null) {
        tagIdsToLink.add(existingTag.id);
      } else {
        final newTag = await createTag(tagModel.name);
        tagIdsToLink.add(newTag.id);
      }
    }
    await _db.batch((batch) {
      batch.insertAll(_db.taskTags, tagIdsToLink.map((tagId) => TaskTagsCompanion.insert(taskId: taskId, tagId: tagId)));
    });
  }

  Future<model_task.Tag> createTag(String name) async {
    final trimmedName = name.trim();
    final existing = await (_db.select(_db.tags)..where((t) => t.name.equals(trimmedName))).getSingleOrNull();
    if (existing != null) {
      return model_task.Tag(id: existing.id, name: existing.name);
    }
    final id = _uuid.v4();
    final companion = TagsCompanion.insert(id: id, name: trimmedName);
    await _db.into(_db.tags).insert(companion);
    return model_task.Tag(id: id, name: trimmedName);
  }

  Future<int> delete(String id) async {
    final count = await (_db.delete(_db.tasks)..where((t) => t.id.equals(id))).go();
    final notificationId = id.hashCode;
    NotificationService.cancel(notificationId);
    await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(id))).go();
    return count;
  }

  Future<void> deleteAll() async {
    await _db.delete(_db.taskTags).go();
    await _db.delete(_db.tasks).go();
    await _db.delete(_db.tags).go();
  }

  Future<void> reorder(List<model_task.Task> tasks) async {
    await _db.transaction(() async {
      for (final task in tasks) {
        if (!task.done && task.id != null) {
          await (_db.update(_db.tasks)..where((t) => t.id.equals(task.id!))).write(TasksCompanion(sort: d.Value(task.sort)));
        }
      }
    });
  }

  void _rescheduleNotificationForTask(model_task.Task task) {
    if (task.id == null) return;
    final notificationId = task.id.hashCode;
    if (task.due == null || task.done) {
      NotificationService.cancel(notificationId);
      return;
    }
    DateTime due = task.due!;
    final now = DateTime.now();
    bool shouldReschedule = false;
    if (due.isBefore(now) && task.repeat != model_task.RepeatRule.none) {
      while (due.isBefore(now)) {
        switch (task.repeat) {
          case model_task.RepeatRule.daily: due = due.add(const Duration(days: 1)); break;
          case model_task.RepeatRule.weekly: due = due.add(const Duration(days: 7)); break;
          case model_task.RepeatRule.monthly: due = DateTime(due.year, due.month + 1, due.day, due.hour, due.minute); break;
          case model_task.RepeatRule.none: break;
        }
        shouldReschedule = true;
      }
    }
    if (shouldReschedule) {
      update(task.copyWith(due: due));
      return;
    }
    final tzWhen = tz.TZDateTime.from(due, tz.local);
    final payload = 'taskId:${task.id}';
    switch (task.repeat) {
      case model_task.RepeatRule.none: NotificationService.scheduleAt(id: notificationId, title: task.title, body: task.note, when: tzWhen, payload: payload); break;
      case model_task.RepeatRule.daily: NotificationService.scheduleDaily(id: notificationId, title: task.title, body: task.note, firstTime: tzWhen, payload: payload); break;
      case model_task.RepeatRule.weekly: NotificationService.scheduleWeekly(id: notificationId, title: task.title, body: task.note, firstTime: tzWhen, payload: payload); break;
      case model_task.RepeatRule.monthly: NotificationService.scheduleMonthly(id: notificationId, title: task.title, body: task.note, firstTime: tzWhen, payload: payload); break;
    }
  }
}