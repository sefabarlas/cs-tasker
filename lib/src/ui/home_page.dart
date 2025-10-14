import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/db.dart';
import 'providers.dart';
import 'new_task_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(taskRepoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Görevler')),
      body: StreamBuilder<List<Task>>(
        stream: repo.watchActive(),
        builder: (context, snap) {
          final items = snap.data ?? [];
          if (items.isEmpty) return const Center(child: Text('Henüz görev yok'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (c, i) {
              final t = items[i];
              return ListTile(
                title: Text(t.title),
                subtitle: t.notes == null ? null : Text(t.notes!),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const NewTaskPage()));
        },
        label: const Text('Ekle'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}