import 'package:drift/drift.dart';

class Tasks extends Table {
  TextColumn get id => text()();           // uuid
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAtUtc => dateTime()();
  DateTimeColumn get updatedAtUtc => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Reminders extends Table {
  TextColumn get id => text()();           // uuid
  TextColumn get taskId => text()();       // fk Tasks.id
  DateTimeColumn get localDateTime => dateTime()(); // kullanıcının seçtiği yerel tarih+saat
  TextColumn get timeZoneId => text()();   // Europe/Istanbul
  DateTimeColumn get utcFireAt => dateTime()(); // hesaplanmış
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get notificationId => integer()(); // android/iOS için unique int
  @override
  Set<Column> get primaryKey => {id};
}