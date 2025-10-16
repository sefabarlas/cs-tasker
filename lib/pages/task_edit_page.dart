// lib/pages/task_edit_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart'; // YENİ
import '../models/task.dart';
import '../providers/task_providers.dart';

const _uuid = Uuid(); // YENİ

class TaskEditPage extends ConsumerStatefulWidget {
  const TaskEditPage({super.key, this.initial});
  final Task? initial;
  @override
  ConsumerState<TaskEditPage> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends ConsumerState<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  DateTime? _due;
  RepeatRule _repeat = RepeatRule.none;
  bool _done = false;
  List<Tag> _selectedTags = [];

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _titleCtl.text = t?.title ?? '';
    _noteCtl.text = t?.note ?? '';
    _due = t?.due;
    _repeat = t?.repeat ?? RepeatRule.none;
    _done = t?.done ?? false;
    _selectedTags = t?.tags ?? [];
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final initialDate = _due ?? now;
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 5);

    final date = await showDatePicker(context: context, initialDate: initialDate, firstDate: firstDate, lastDate: lastDate, helpText: 'Tarih seç', cancelText: 'Vazgeç', confirmText: 'Devam', builder: (ctx, child) => Theme(data: theme.copyWith(useMaterial3: true), child: child!));
    if (date == null) return;

    final tod = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due ?? now), helpText: 'Saat seç', cancelText: 'Vazgeç', confirmText: 'Tamam', builder: (ctx, child) => Theme(data: theme.copyWith(useMaterial3: true), child: child!));
    if (tod == null) return;

    setState(() => _due = DateTime(date.year, date.month, date.day, tod.hour, tod.minute));
  }

  void _setQuick(DateTime dt) => setState(() => _due = dt);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.initial;
    final toSave = Task(
      id: base?.id,
      title: _titleCtl.text.trim(),
      note: _noteCtl.text.trim().isEmpty ? null : _noteCtl.text.trim(),
      due: _due,
      repeat: _repeat,
      done: _done,
      sort: base?.sort ?? 0,
      createdAt: base?.createdAt,
      tags: _selectedTags,
    );

    final notifier = ref.read(taskListProvider.notifier);
    if (base == null) {
      await notifier.add(toSave);
    } else {
      await notifier.updateTask(toSave);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _showTagSelectionDialog() async {
    // Diyalogdan dönen güncel listeyi al ve state'i güncelle
    final newSelection = await showDialog<List<Tag>>(
      context: context,
      builder: (context) => TagSelectionDialog(initialSelected: _selectedTags),
    );
    if (newSelection != null) {
      setState(() => _selectedTags = newSelection);
    }
  }

  DateTime? _safeCreatedAt() {
    try {
      final dynamic t = widget.initial;
      return t?.createdAt as DateTime?;
    } catch (_) { return null; }
  }

  DateTime? _safeUpdatedAt() {
    try {
      final dynamic t = widget.initial;
      return t?.updatedAt as DateTime?;
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final createdAt = _safeCreatedAt();
    final updatedAt = _safeUpdatedAt();

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Görevi Düzenle' : 'Yeni Görev'), actions: [TextButton(onPressed: _save, child: const Text('Kaydet'))]),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextFormField(controller: _titleCtl, autofocus: !isEdit, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Başlık', hintText: 'Ne yapacaksın?'), validator: (v) => (v == null || v.trim().isEmpty) ? 'Başlık gerekli' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _noteCtl, maxLines: 4, decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', hintText: 'Detay, link ya da ek açıklama…')),
            const SizedBox(height: 20),
            Text('Etiketler', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                ..._selectedTags.map((tag) => Chip(label: Text(tag.name), onDeleted: () => setState(() => _selectedTags.remove(tag)))),
                ActionChip(avatar: const Icon(Icons.add), label: const Text('Ekle'), onPressed: _showTagSelectionDialog),
              ],
            ),
            const SizedBox(height: 20),
            Text('Tarih & Saat', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(onPressed: _pickDateTime, icon: const Icon(Icons.event), label: const Text('Tarih/Saat Seç')),
                if (_due != null) InputChip(avatar: const Icon(Icons.schedule, size: 16), label: Text(_formatDate(_due!)), onDeleted: () => setState(() => _due = null), deleteIcon: const Icon(Icons.clear)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: -4,
              children: [
                ActionChip(avatar: const Icon(Icons.today, size: 16), label: const Text('Bugün 09:00'), onPressed: () { final n = DateTime.now(); _setQuick(DateTime(n.year, n.month, n.day, 9, 0)); }),
                ActionChip(avatar: const Icon(Icons.nightlight_round, size: 16), label: const Text('Bu Akşam 20:00'), onPressed: () { final n = DateTime.now(); _setQuick(DateTime(n.year, n.month, n.day, 20, 0)); }),
                ActionChip(avatar: const Icon(Icons.calendar_today, size: 16), label: const Text('Yarın 09:00'), onPressed: () { final n = DateTime.now().add(const Duration(days: 1)); _setQuick(DateTime(n.year, n.month, n.day, 9, 0)); }),
              ],
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<RepeatRule>(value: _repeat, decoration: const InputDecoration(labelText: 'Tekrar'), items: const [DropdownMenuItem(value: RepeatRule.none, child: Text('Yok')), DropdownMenuItem(value: RepeatRule.daily, child: Text('Günlük')), DropdownMenuItem(value: RepeatRule.weekly, child: Text('Haftalık')), DropdownMenuItem(value: RepeatRule.monthly, child: Text('Aylık'))], onChanged: (v) => setState(() => _repeat = v ?? RepeatRule.none)),
            const SizedBox(height: 12),
            if (isEdit) SwitchListTile(value: _done, onChanged: (v) => setState(() => _done = v), title: const Text('Tamamlandı'), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 28),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Kaydet')),
            if (isEdit && (createdAt != null || updatedAt != null)) ...[
              const SizedBox(height: 24), const Divider(), const SizedBox(height: 8),
              _MetaRow(icon: Icons.add_circle_outline, label: 'Eklenme', value: createdAt != null ? _formatDate(createdAt) : '—'),
              const SizedBox(height: 6),
              _MetaRow(icon: Icons.edit_outlined, label: 'Güncellenme', value: updatedAt != null ? _formatDate(updatedAt) : '—'),
            ],
          ],
        ),
      ),
    );
  }
}

// YENİLENDİ: TagSelectionDialog'un tüm mantığı basitleştirildi.
class TagSelectionDialog extends ConsumerStatefulWidget {
  const TagSelectionDialog({super.key, required this.initialSelected});
  final List<Tag> initialSelected;

  @override
  ConsumerState<TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends ConsumerState<TagSelectionDialog> {
  late List<Tag> _selected;
  final _newTagCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.initialSelected);
  }

  @override
  void dispose() {
    _newTagCtl.dispose();
    super.dispose();
  }

  void _addNewTag() {
    final name = _newTagCtl.text.trim();
    if (name.isEmpty) return;

    final allTags = ref.read(allTagsProvider).value ?? [];
    final allAndSelectedTags = [...allTags, ..._selected];

    final exists = allAndSelectedTags.any((t) => t.name.toLowerCase() == name.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Bu etiket zaten mevcut.')));
      return;
    }
    // Veritabanına hemen eklemek yerine, sadece UI'da geçici bir etiket oluştur.
    // Gerçek kaydetme işlemi TaskRepository'de halledilecek.
    final newTag = Tag(id: _uuid.v4(), name: name);
    setState(() {
      _selected.add(newTag);
      _newTagCtl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allTagsAsync = ref.watch(allTagsProvider);
    return AlertDialog(
      title: const Text('Etiket Seç'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _newTagCtl, decoration: InputDecoration(labelText: 'Yeni Etiket Oluştur', suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _addNewTag)), onSubmitted: (_) => _addNewTag()),
            const SizedBox(height: 16),
            Expanded(
              child: allTagsAsync.when(
                data: (allTags) {
                  // Hem veritabanından gelenleri hem de yeni eklenenleri birleştir ve sırala
                  final displayedTags = {...allTags, ..._selected}.toList();
                  displayedTags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: displayedTags.length,
                    itemBuilder: (context, index) {
                      final tag = displayedTags[index];
                      final isSelected = _selected.any((t) => t.name.toLowerCase() == tag.name.toLowerCase());
                      return CheckboxListTile(
                        title: Text(tag.name),
                        value: isSelected,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              if (!isSelected) _selected.add(tag);
                            } else {
                              _selected.removeWhere((t) => t.name.toLowerCase() == tag.name.toLowerCase());
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Tamam')),
      ],
    );
  }
}

// MetaRow ve _formatDate (Değişiklik yok)
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Icon(icon, size: 18), const SizedBox(width: 8),
      Text(label, style: t.bodySmall), const Spacer(),
      Text(value, style: t.bodySmall?.copyWith(fontFeatures: const [])),
    ]);
  }
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${two(d.day)}.${two(d.month)}.${d.year}';
  final time = '${two(d.hour)}:${two(d.minute)}';
  return '$date $time';
}