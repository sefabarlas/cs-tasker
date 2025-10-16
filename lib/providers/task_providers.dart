// lib/providers/task_providers.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasker/src/ui/providers.dart';
import '../data/task_repository.dart'; // Yeni Drift tabanlı repo
import '../models/task.dart';

/// 🛠️ Task Repository (Drift'i kullanacak)
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.read(appDbProvider); // lib/src/data/db.dart'tan
  return TaskRepository(db);
});

// YENİ: Tüm etiketleri getiren provider
final allTagsProvider = FutureProvider<List<Tag>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return repo.getAllTags();
});

/// Liste + arama + sıralama (Stream'i yönetir)
final taskListProvider = AsyncNotifierProvider<TaskListNotifier, List<Task>>(
  TaskListNotifier.new,
);

class TaskListNotifier extends AsyncNotifier<List<Task>> {
  late final TaskRepository _repo;
  StreamSubscription<List<Task>>? _streamSubscription;

  @override
  Future<List<Task>> build() async {
    _repo = ref.read(taskRepositoryProvider);

    // Drift'ten gelen Stream'i dinle ve state'i güncelle
    _streamSubscription = _repo.findAll().listen((items) {
      state = AsyncData(_sorted(items));
    });

    // İlk veriyi bekle (başlangıç için)
    final initialItems = await _repo.findAll().first;
    return _sorted(initialItems);
  }

  // Stream kullandığımız için artık 'refresh' metoduna gerek kalmadı.
  // Ancak, arayüzdeki `RefreshIndicator` için bunu bırakalım.
  Future<void> refresh() async {
    // Stream zaten güncellemeleri dinlediği için bu metod sadece ilk listeyi bekler.
    final items = await _repo.findAll().first;
    state = AsyncData(_sorted(items));
  }

  Future<void> add(Task t) async {
    await _repo.add(t);
    // Stream otomatik güncelleyecek.
  }

  Future<void> updateTask(Task t) async {
    await _repo.update(t);
    // Stream otomatik güncelleyecek.
  }

  Future<void> remove(Task t) async {
    await _repo.delete(t.id!);
    // Stream otomatik güncelleyecek.
  }

  /// home_page.dart’tan çağrılan toggle
  Future<void> toggle(Task t) async {
    // Done durumunu tersine çevir
    final toggled = t.copyWith(
      done: !t.done,
      // Tamamlanma/Geri alma durumunda sort'u manuel ayarlamak gerekebilir
      // Ancak repo'daki sorgu sort'u yeniden hesapladığı için gerek yok.
    );
    await _repo.update(toggled);
    // Stream otomatik güncelleyecek.
  }

  // ... (reorder metodu ve search metodu için TaskRepository'nin yeniden yazılması gerekiyor)

  Future<void> reorder(int oldIndex, int newIndex) async {
    // Mevcut (gruplanmamış/filtrelenmemiş) listeyi al
    final list = state.value;
    if (list == null) return;

    // Yalnızca tamamlanmamış listeyi al ve üzerinde reorder yap
    final undone = list.where((e) => !e.done).toList();

    if (newIndex > undone.length) newIndex = undone.length;
    if (newIndex > oldIndex) newIndex -= 1;

    final moved = undone.removeAt(oldIndex);
    undone.insert(newIndex, moved);

    // Yeni sort değerlerini ata (0, 1000, 2000, ...)
    for (var i = 0; i < undone.length; i++) {
      // sort alanının int olması gerekiyor
      undone[i] = undone[i].copyWith(sort: i * 1000, updatedAt: DateTime.now());
    }

    // Repository'ye toplu güncelleme gönder
    await _repo.reorder(undone);
    // Stream otomatik güncelleyecektir.
  }

  // Arama, in-memory (bellekte) değil, veritabanı sorgusu olarak yapılmalıdır.
  // Basitlik için şimdilik in-memory filtrelemeyi koruyoruz:
  void search(String q) async {
    // Stream'i geçici olarak durdur.
    _streamSubscription?.pause();

    final base = await _repo.findAll().first; // Güncel tüm listeyi al

    final filtered = q.trim().isEmpty
        ? base
        : base.where((t) {
            final s = q.toLowerCase();
            return t.title.toLowerCase().contains(s) ||
                (t.note ?? '').toLowerCase().contains(s);
          }).toList();

    state = AsyncData(_sorted(filtered));

    // Arama bittiğinde stream'i tekrar başlat (eğer arama kutusu boşsa)
    if (q.trim().isEmpty) {
      _streamSubscription?.resume();
    }
  }

  // --- SIRALAMA KURALI ---
  // 1) Tamamlanmamışlar önce
  // 2) Aynı grupta `sort` artan (DB’de saklanan sıra)
  List<Task> _sorted(List<Task> list) {
    final sorted = [...list]
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return a.sort.compareTo(b.sort);
      });
    return sorted;
  }
}
