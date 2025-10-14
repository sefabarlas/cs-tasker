import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/task_providers.dart';
import '../services/backup_service.dart';

class BackupPage extends ConsumerWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepositoryProvider);
    final backup = BackupService(repo);

    Future<void> _export() async {
      final file = await backup.exportToJsonFile();
      await Share.shareXFiles([XFile(file.path)], text: 'CS Tasker yedeği');
    }

    Future<void> _import({required bool replaceAll}) async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (res == null || res.files.single.path == null) return;

      final file = File(res.files.single.path!);

      try {
        final count = await backup.importFromJsonFile(file, replaceAll: replaceAll);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('İçe aktarıldı: $count görev')),
          );
          // listeyi tazele
          await ref.read(taskListProvider.notifier).refresh();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('İçe aktarma hatası: $e')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Yedekleme / Geri Yükleme')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Dışa Aktar (JSON)'),
            subtitle: Text('Tüm görevlerinizi JSON dosya olarak paylaşın/ kaydedin.'),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Yedek dosyası oluştur ve paylaş'),
            onTap: _export,
          ),
          const Divider(),
          const ListTile(
            title: Text('İçe Aktar (JSON)'),
            subtitle: Text('Yedek dosyasından görevleri geri yükleyin.'),
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('İçe aktar (Birleştir)'),
            subtitle: const Text('Aynı id’ler güncellenir, yeni olanlar eklenir.'),
            onTap: () => _import(replaceAll: false),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('İçe aktar (Tümünü değiştir)'),
            subtitle: const Text('Mevcut tüm görevler silinir, yedekten yüklenir.'),
            onTap: () => _import(replaceAll: true),
          ),
        ],
      ),
    );
  }
}