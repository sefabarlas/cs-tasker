import 'package:drift/drift.dart';

class Tasks extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  IntColumn get due => integer().nullable()();
  IntColumn get repeat => integer().withDefault(const Constant(0))();
  IntColumn get sort => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Tag')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  @override
  Set<Column> get primaryKey => {id};
}

class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

class Reminders extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get taskId => text()(); // fk Tasks.id
  DateTimeColumn get localDateTime =>
      dateTime()(); // kullanıcının seçtiği yerel tarih+saat
  TextColumn get timeZoneId => text()(); // Europe/Istanbul
  DateTimeColumn get utcFireAt => dateTime()(); // hesaplanmış
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get notificationId => integer()(); // android/iOS için unique int
  @override
  Set<Column> get primaryKey => {id};
}
