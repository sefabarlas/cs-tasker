import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'db.g.dart';

@DriftDatabase(tables: [Tasks, Reminders, Tags, TaskTags])
class AppDb extends _$AppDb {
  AppDb() : super(_open());
  
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        // Tüm tabloları sıfırdan oluştur
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        // Versiyon 1'den 2'ye geçerken
        if (from == 1) {
          // Yeni eklediğimiz iki tabloyu oluştur
          await m.createTable(tags);
          await m.createTable(taskTags);
        }
      },
    );
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'tasker.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
