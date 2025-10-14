// lib/providers/task_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasker/data/task_db.dart';
import '../data/task_repository.dart';
import '../models/task.dart';

/// DB provider
final taskDbProvider = Provider<TaskDb>((ref) => TaskDb());

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(taskDbProvider);
  return TaskRepository(db);
});

/// Liste + arama + sıralama
final taskListProvider =
    AsyncNotifierProvider<TaskListNotifier, List<Task>>(TaskListNotifier.new);

class TaskListNotifier extends AsyncNotifier<List<Task>> {
  late final TaskRepository _repo;

  @override
  Future<List<Task>> build() async {
    _repo = ref.read(taskRepositoryProvider);
    final items = await _repo.list();
    return _sorted(items);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    final items = await _repo.list();
    state = AsyncData(_sorted(items));
  }

  Future<void> add(Task t) async {
    await _repo.add(t);
    await refresh();
  }

  Future<void> updateTask(Task t) async {
    await _repo.update(t);
    await refresh();
  }

  Future<void> remove(Task t) async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.delete(t.id!);
    await refresh();
  }

  /// home_page.dart’tan çağrılan toggle
  Future<void> toggle(Task t) async {
    final repo = ref.read(taskRepositoryProvider);
    final toggled = t.copyWith(done: !t.done);
    await repo.update(toggled);
    await refresh();
  }

  /// Arama: başlık/nota göre filtrele, sonra kalıcı sıralamayı uygula
  void search(String q) async {
    final base = await _repo.list();
    final filtered = q.trim().isEmpty
        ? base
        : base.where((t) {
            final s = q.toLowerCase();
            return t.title.toLowerCase().contains(s) ||
                (t.note ?? '').toLowerCase().contains(s);
          }).toList();
    state = AsyncData(_sorted(filtered));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    state = const AsyncLoading();
    final list = await ref.read(taskRepositoryProvider).reorder(oldIndex, newIndex);
    state = AsyncValue.data(_sorted(list)); // 👈 kalıcı sort’a göre yeniden sırala
  }

  // --- SIRALAMA KURALI (KALICI) ---
  // 1) Tamamlanmamışlar önce
  // 2) Aynı grupta `sort` artan (DB’de saklanan sıra)
  List<Task> _sorted(List<Task> list) {
    final sorted = [...list]..sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.sort.compareTo(b.sort);
    });
    return sorted;
  }
}