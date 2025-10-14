// lib/src/ui/home_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../data/db.dart'; // Drift geçişi sırasında bu import gereksizleşti
// import 'providers.dart'; // providers.dart da gereksizleşti
import '../../providers/task_providers.dart'; // taskRepositoryProvider buradan gelmeli
import '../../models/task.dart'; // Task modelini import edin
import 'new_task_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // repo artık taskRepositoryProvider'dan okunuyor (TaskRepository tipi)
    final repo = ref.watch(taskRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Görevler')),
      body: StreamBuilder<List<Task>>(
        // ✅ Düzeltme: watchActive() yerine findAll() kullanılıyor
        stream: repo.findAll(),
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty)
            return const Center(child: Text('Henüz görev yok'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (c, i) {
              final t = items[i];
              return ListTile(
                title: Text(t.title),
                // Drift Task modelinizde notlar 'notes' olarak isimlendirilmişti,
                // ancak domain modelinizde (lib/models/task.dart) 'note' olarak kalmalı.
                // Eğer Drift modeline bağlı olan UI katmanı ise, burayı da kontrol edin.
                // Task modelinde 'note' olduğu için, burada 't.note' kullanıyoruz.
                subtitle: t.note == null ? null : Text(t.note!),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewTaskPage()),
          );
        },
        label: const Text('Ekle'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
