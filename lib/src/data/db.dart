// lib/src/data/db.dart
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

  // YENİ: Şema versiyonu 3'e yükseltildi
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from == 1) {
          await m.createTable(tags);
          await m.createTable(taskTags);
        }
        // YENİ: Versiyon 2'den 3'e geçerken Tasks tablosuna `priority` sütununu ekle
        if (from == 2) {
          await m.addColumn(tasks, tasks.priority as GeneratedColumn<Object>);
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