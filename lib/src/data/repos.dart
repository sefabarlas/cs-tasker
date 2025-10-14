import 'package:drift/drift.dart';
import 'db.dart';

class TaskRepo {
  TaskRepo(this.db);
  final AppDb db;

  Future<void> insertTask(TasksCompanion data) => db.into(db.tasks).insert(data);
  Stream<List<Task>> watchActive() =>
      (db.select(db.tasks)..where((t) => t.isCompleted.equals(false))).watch();
}

class ReminderRepo {
  ReminderRepo(this.db);
  final AppDb db;

  Future<void> insertReminder(RemindersCompanion data) =>
      db.into(db.reminders).insert(data);

  Future<void> updateUtc(String id, DateTime utc) =>
      (db.update(db.reminders)..where((r) => r.id.equals(id)))
          .write(RemindersCompanion(utcFireAt: Value(utc)));

  Future<List<Reminder>> getActive() =>
      (db.select(db.reminders)..where((r) => r.isActive.equals(true))).get();
}