// lib/data/task_db.dart
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';

class TaskDb {
  Database? _db;

  Future<Database> open() async {
    _db ??= await openDatabase(
      'tasker.db',
      version: 6, // şema versiyonu
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            note TEXT,
            due INTEGER,
            repeat INTEGER NOT NULL DEFAULT 0,
            done INTEGER NOT NULL DEFAULT 0,
            sort INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // v2: sort sütunu
        if (oldV < 2) {
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN sort INTEGER NOT NULL DEFAULT 0');
          } catch (_) {}
          final rows = await db.query('tasks', orderBy: 'done ASC, due ASC');
          int i = 0, j = 0;
          for (final m in rows) {
            final done = (m['done'] as int? ?? 0) == 1;
            final id = m['id'] as int;
            final val = done ? (1000000000 + (j++)) : (i++ * 1000);
            await db.update('tasks', {'sort': val}, where: 'id=?', whereArgs: [id]);
          }
        }

        // v6: created_at ve updated_at sütunları
        if (oldV < 6) {
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN created_at INTEGER');
          } catch (_) {}
          try {
            await db.execute('ALTER TABLE tasks ADD COLUMN updated_at INTEGER');
          } catch (_) {}

          // created_at boş olanları "şimdi" ile doldur
          final now = DateTime.now().millisecondsSinceEpoch;
          await db.update('tasks', {'created_at': now}, where: 'created_at IS NULL');
        }
      },
    );
    return _db!;
  }

  Future<Database> _ensureOpen() async {
    if (_db == null || !_db!.isOpen) {
      return await open();
    }
    return _db!;
  }

  Future<List<Task>> getAll() async {
    final db = await _ensureOpen();
    final rows = await db.query(
      'tasks',
      orderBy: 'done ASC, sort ASC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getById(int id) async {
    final db = await _ensureOpen();
    final rows = await db.query('tasks', where: 'id=?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<int> insert(Task t) async {
    final db = await _ensureOpen();
    return await db.insert('tasks', t.toMap());
  }

  Future<int> update(Task t) async {
    final db = await _ensureOpen();
    return await db.update('tasks', t.toMap(), where: 'id=?', whereArgs: [t.id]);
  }

  Future<int> delete(int id) async {
    final db = await _ensureOpen();
    return await db.delete('tasks', where: 'id=?', whereArgs: [id]);
  }

  Future<void> updateMany(List<Task> tasks) async {
    final db = await _ensureOpen();
    final batch = db.batch();
    for (final t in tasks) {
      batch.update('tasks', t.toMap(), where: 'id=?', whereArgs: [t.id]);
    }
    await batch.commit(noResult: true);
  }
}