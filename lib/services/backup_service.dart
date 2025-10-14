import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import '../data/task_repository.dart';

class BackupService {
  final TaskRepository repo;
  BackupService(this.repo);

  /// Tüm görevleri JSON dosyasına yazar, geçici dizinde dosya döner
  Future<File> exportToJsonFile() async {
    final items = await repo.list();

    final payload = {
      'format': 'cs_tasker',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tasks': items.map((t) => t.toExportJson()).toList(),
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cs_tasker_backup.json');
    await file.writeAsString(jsonStr);
    return file;
  }

  /// JSON dosyasından içe aktarım.
  /// replaceAll=true ise önce tüm görevleri siler, sonra ekler.
  /// merge (default) ise aynı id varsa günceller, yoksa sona ekler.
  Future<int> importFromJsonFile(File file, {bool replaceAll = false}) async {
    final raw = await file.readAsString();
    final decoded = json.decode(raw) as Map<String, dynamic>;

    if (decoded['format'] != 'cs_tasker') {
      throw FormatException('Geçersiz format');
    }

    final List tasksJson = decoded['tasks'] as List? ?? [];
    final incoming = tasksJson
        .map((e) => Task.fromExportJson(e as Map<String, dynamic>))
        .toList();

    if (replaceAll) {
      await repo.deleteAll();
      // Baştan sıralayalım
      for (var i = 0; i < incoming.length; i++) {
        final toAdd = incoming[i].copyWith(id: null, sort: i * 1000);
        await repo.add(toAdd);
      }
      return incoming.length;
    } else {
      // merge: id eşleşirse update, yoksa ekle (sona)
      final existing = await repo.list();
      final existingById = {
        for (final t in existing.where((e) => e.id != null)) t.id!: t,
      };
      int imported = 0;

      // yeni eklenecekler için base index
      int lastUndone = existing.where((e) => !e.done).length;

      for (final inc in incoming) {
        if (inc.id != null && existingById.containsKey(inc.id)) {
          // var olanı güncelle (id’yi koru)
          final keepId = inc.copyWith(id: inc.id);
          await repo.update(keepId);
          imported++;
        } else {
          // yeni ekle → tamamlanmamışsa sona sort ver, tamamlanmışsa zaten alta gider
          final sort = (!inc.done ? (lastUndone++ * 1000) : inc.sort);
          await repo.add(inc.copyWith(id: null, sort: sort));
          imported++;
        }
      }
      return imported;
    }
  }
}
