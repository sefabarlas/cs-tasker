// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasker/pages/about_page.dart';
import 'package:tasker/pages/backup_page.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';
import 'task_edit_page.dart';
import '../widgets/task_tile.dart';

enum TaskFilter { all, today, done }

/* ---------- Grup tipi ve görünür liste girdisi ---------- */

enum _SectionType { today, tomorrow, later, done }

class _Entry {
  const _Entry.header(this.section) : task = null;
  const _Entry.task(this.task) : section = null;

  final _SectionType? section;
  final Task? task;

  bool get isHeader => section != null;
  bool get isTask => task != null;
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  TaskFilter _filter = TaskFilter.all;

  // 🔎 Kalıcı arama
  final _searchCtl = TextEditingController();
  String _query = '';

  // 🔽 Bölüm daraltma durumları (Done varsayılan kapalı)
  final Map<_SectionType, bool> _collapsed = {
    _SectionType.today: false,
    _SectionType.tomorrow: false,
    _SectionType.later: false,
    _SectionType.done: true,
  };

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() {
      setState(() => _query = _searchCtl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(taskListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Görevler'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Hakkında',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'backup') {
                if (!context.mounted) return;
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const BackupPage()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'backup',
                child: Text('Yedekle / Geri Yükle'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                // 🗂️ Filtreler
                SegmentedButton<TaskFilter>(
                  segments: const [
                    ButtonSegment(
                      value: TaskFilter.all,
                      label: Text('Tümü'),
                      icon: Icon(Icons.list_alt),
                    ),
                    ButtonSegment(
                      value: TaskFilter.today,
                      label: Text('Bugün'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: TaskFilter.done,
                      label: Text('Tamamlanan'),
                      icon: Icon(Icons.check_circle),
                    ),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
                const SizedBox(height: 10),
                // 🔎 Arama çubuğu
                _InlineSearchField(controller: _searchCtl),
              ],
            ),
          ),
        ),
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => RefreshIndicator(
          onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Hata: $e')),
              const SizedBox(height: 200),
            ],
          ),
        ),
        data: (items) {
          // 1) Filtre
          final filtered = _applyFilter(items, _filter);
          // 2) Arama
          final flatList = _applySearch(filtered, _query);

          // 3) Gruplama + sayaçlar
          final buckets = _bucketize(flatList);
          final counts = _countsFor(buckets);
          final entries = _buildEntriesFromBuckets(
            buckets,
            collapsed: _collapsed,
          );

          if (flatList.isEmpty) {
            // Boşken de aşağı çek–yenile çalışsın:
            return RefreshIndicator(
              onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 40),
                  _EmptyState(),
                  SizedBox(height: 200),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(taskListProvider.notifier).refresh(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final e = entries[index];

                if (e.isHeader) {
                  final section = e.section!;
                  final c = counts[section]!;
                  final collapsed = _collapsed[section] ?? false;

                  return KeyedSubtree(
                    key: ValueKey('hdr_${section.name}'),
                    child: _SectionHeader(
                      section: section,
                      total: c.total,
                      done: c.done,
                      collapsed: collapsed,
                      onToggle: () => setState(() {
                        _collapsed[section] = !(collapsed);
                      }),
                    ),
                  );
                }

                final t = e.task!;
                return KeyedSubtree(
                  key: ValueKey('row_${t.id}'),
                  child: _TaskRow(task: t, ref: ref),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TaskEditPage()));
          if (context.mounted) {
            ref.read(taskListProvider.notifier).refresh();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Yeni görev'),
      ),
    );
  }

  /* ---------- Gruplama ve yardımcılar ---------- */

  _SectionType _groupFor(Task t) {
    if (t.done) return _SectionType.done;

    final now = DateTime.now();
    DateTime d(DateTime x) => DateTime(x.year, x.month, x.day);
    final today = d(now);
    final tomorrow = today.add(const Duration(days: 1));
    final afterTomorrow = today.add(const Duration(days: 2));

    if (t.due != null) {
      final dueD = d(t.due!);
      if (dueD == today) return _SectionType.today;
      if (dueD == tomorrow) return _SectionType.tomorrow;
      if (dueD.isAfter(tomorrow) || dueD == afterTomorrow) {
        return _SectionType.later;
      }
    }
    // due yoksa ve tamamlanmamışsa "Sonra"
    return _SectionType.later;
  }

  Map<_SectionType, List<Task>> _bucketize(List<Task> list) {
    final Map<_SectionType, List<Task>> buckets = {
      _SectionType.today: [],
      _SectionType.tomorrow: [],
      _SectionType.later: [],
      _SectionType.done: [],
    };
    for (final t in list) {
      buckets[_groupFor(t)]!.add(t);
    }
    // Done her zaman en sonda (render sırası build’de zaten kontrol ediliyor)
    return buckets;
  }

  Map<_SectionType, _Count> _countsFor(Map<_SectionType, List<Task>> buckets) {
    return {
      for (final e in buckets.entries)
        e.key: _Count(e.value.length, e.value.where((t) => t.done).length),
    };
  }

  List<_Entry> _buildEntriesFromBuckets(
    Map<_SectionType, List<Task>> buckets, {
    required Map<_SectionType, bool> collapsed,
  }) {
    final entries = <_Entry>[];

    void addSection(_SectionType s) {
      final items = buckets[s]!;
      if (items.isEmpty) return;
      entries.add(_Entry.header(s));
      if (!(collapsed[s] ?? false)) {
        for (final t in items) {
          entries.add(_Entry.task(t));
        }
      }
    }

    addSection(_SectionType.today);
    addSection(_SectionType.tomorrow);
    addSection(_SectionType.later);
    addSection(_SectionType.done); // sabit en son

    return entries;
  }

  List<Task> _applyFilter(List<Task> src, TaskFilter f) {
    switch (f) {
      case TaskFilter.today:
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return src.where((t) {
          final d = t.due;
          return d != null && d.isAfter(start) && d.isBefore(end);
        }).toList();
      case TaskFilter.done:
        return src.where((t) => t.done).toList();
      case TaskFilter.all:
        return src;
    }
  }

  List<Task> _applySearch(List<Task> src, String q) {
    if (q.isEmpty) return src;
    final lower = q.toLowerCase();
    return src.where((t) {
      final title = t.title.toLowerCase();
      final note = (t.note ?? '').toLowerCase();
      return title.contains(lower) || note.contains(lower);
    }).toList();
  }

  /* ---------- Hızlı Aksiyonlar (uzun bas) ---------- */

  Future<void> _showQuickActions(BuildContext context, Task t) async {
    final repo = ref.read(taskListProvider.notifier);

    Future<void> _apply(Task updated) async {
      await repo.updateTask(updated);
      HapticFeedback.selectionClick();
    }

    DateTime _at(int days, {int hours = 0}) {
      final base = DateTime.now().add(Duration(days: days, hours: hours));
      final hour = t.due?.hour ?? 9;
      final minute = t.due?.minute ?? 0;
      return DateTime(base.year, base.month, base.day, hour, minute);
    }

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.alarm_add),
              title: const Text('1 saat ertele'),
              onTap: () async {
                final due = (t.due ?? DateTime.now()).add(
                  const Duration(hours: 1),
                );
                await _apply(t.copyWith(done: false, due: due));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('3 saat ertele'),
              onTap: () async {
                final due = (t.due ?? DateTime.now()).add(
                  const Duration(hours: 3),
                );
                await _apply(t.copyWith(done: false, due: due));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Bugün'),
              onTap: () async {
                await _apply(_taskWithSectionApplied(t, _SectionType.today));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_view_day),
              title: const Text('Yarın'),
              onTap: () async {
                await _apply(_taskWithSectionApplied(t, _SectionType.tomorrow));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range),
              title: const Text('+1 hafta'),
              onTap: () async {
                await _apply(t.copyWith(done: false, due: _at(7)));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('+1 ay'),
              onTap: () async {
                final now = DateTime.now();
                final nextMonth = DateTime(now.year, now.month + 1, now.day);
                final hour = t.due?.hour ?? 9;
                final minute = t.due?.minute ?? 0;
                await _apply(
                  t.copyWith(
                    done: false,
                    due: DateTime(
                      nextMonth.year,
                      nextMonth.month,
                      nextMonth.day,
                      hour,
                      minute,
                    ),
                  ),
                );
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.back_hand),
              title: const Text('Due’yu temizle (Sonra)'),
              onTap: () async {
                await _apply(_taskWithSectionApplied(t, _SectionType.later));
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(t.done ? Icons.undo : Icons.check_circle),
              title: Text(t.done ? 'Tamamlamayı geri al' : 'Tamamla'),
              onTap: () async {
                await _apply(t.copyWith(done: !t.done));
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// Bir görevi hedef bölüme taşındığında uygun due/done ile döndürür.
  Task _taskWithSectionApplied(Task t, _SectionType section) {
    switch (section) {
      case _SectionType.today:
        final base = DateTime.now();
        final hour = t.due?.hour ?? 9;
        final minute = t.due?.minute ?? 0;
        return t.copyWith(
          done: false,
          due: DateTime(base.year, base.month, base.day, hour, minute),
        );

      case _SectionType.tomorrow:
        final now = DateTime.now();
        final hour = t.due?.hour ?? 9;
        final minute = t.due?.minute ?? 0;
        final tom = DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 1));
        return t.copyWith(
          done: false,
          due: DateTime(tom.year, tom.month, tom.day, hour, minute),
        );

      case _SectionType.later:
        return t.copyWith(done: false, due: null);

      case _SectionType.done:
        return t.copyWith(done: true);
    }
  }
}

/* ---------- Satır + Dismiss + Hızlı aksiyon sarmalayıcı ---------- */

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.ref});
  final Task task;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final t = task;

    return Dismissible(
      key: ValueKey<String>(t.id!),
      direction: DismissDirection.horizontal,

      // Sil (sağdan sola), Tamamla/Geri Al (soldan sağa)
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // SİLME
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Silinsin mi?'),
              content: Text('“${t.title}” kalıcı olarak silinecek.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Sil'),
                ),
              ],
            ),
          );
          if (ok == true) {
            final removed = t;
            await ref.read(taskListProvider.notifier).remove(t);

            // Undo
            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Silindi: ${removed.title}'),
                  action: SnackBarAction(
                    label: 'Geri Al',
                    onPressed: () async {
                      // Bu callback içinde context/State dispose olabilir; yalnızca provider çağırıyoruz.
                      await ref
                          .read(taskListProvider.notifier)
                          .add(removed.copyWith(id: null));
                    },
                  ),
                ),
              );
            }
            return true; // Dismissible kendi kaldırır
          }
          return false;
        } else {
          // TAMAMLA / GERİ AL
          await ref.read(taskListProvider.notifier).toggle(t);
          HapticFeedback.selectionClick();
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                duration: const Duration(milliseconds: 1200),
                content: Text(t.done ? 'Geri alındı' : 'Tamamlandı'),
              ),
            );
          }
          return false; // listeyi biz yeniliyoruz
        }
      },

      // Sil için kırmızı arka plan (sağdan sola)
      secondaryBackground: ExcludeSemantics(
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.red.withOpacity(.12),
          child: const Icon(Icons.delete, size: 28),
        ),
      ),

      // Tamamla/Geri al için yeşil arka plan (soldan sağa)
      background: ExcludeSemantics(
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.green.withOpacity(.12),
          child: Icon(t.done ? Icons.undo : Icons.check_circle, size: 28),
        ),
      ),

      // 🔥 Hızlı menü: uzun bas
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () {
          final state = context.findAncestorStateOfType<_HomePageState>();
          state?._showQuickActions(context, t);
        },
        child: TaskTile(
          task: t,
          onTap: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => TaskEditPage(initial: t)));
          },
        ),
      ),
    );
  }
}

/* ---------- UI parçaları ---------- */

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.section,
    required this.total,
    required this.done,
    required this.collapsed,
    required this.onToggle,
  });

  final _SectionType section;
  final int total;
  final int done;
  final bool collapsed;
  final VoidCallback onToggle;

  String get _label {
    switch (section) {
      case _SectionType.today:
        return 'Bugün';
      case _SectionType.tomorrow:
        return 'Yarın';
      case _SectionType.later:
        return 'Sonra';
      case _SectionType.done:
        return 'Tamamlanan';
    }
  }

  IconData get _icon {
    switch (section) {
      case _SectionType.today:
        return Icons.today;
      case _SectionType.tomorrow:
        return Icons.calendar_view_day;
      case _SectionType.later:
        return Icons.upcoming;
      case _SectionType.done:
        return Icons.check_circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // “Bugün” ilerleme çubuğu (tamamlananlar aşağıya iniyor ama oran doğru)
    final showProgress = section == _SectionType.today && total > 0;
    final progress = total == 0 ? 0.0 : (done / total);

    return InkWell(
      onTap: onToggle,
      child: Container(
        key: ValueKey('section_${section.name}'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        color: scheme.surfaceContainerHighest.withOpacity(.35),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.titleSmall?.color?.withOpacity(.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // sayaç
                Text(
                  '$done/$total',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(width: 8),
                Icon(
                  collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 20,
                ),
              ],
            ),
            if (showProgress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineSearchField extends StatelessWidget {
  const _InlineSearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Görevlerde ara…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Temizle',
                onPressed: () => controller.clear(),
                icon: const Icon(Icons.clear),
              ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: scheme.outline),
            const SizedBox(height: 12),
            Text(
              'Hiç sonuç yok',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Arama terimini değiştirin veya yeni bir görev ekleyin.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count {
  const _Count(this.total, this.done);
  final int total;
  final int done;
}
