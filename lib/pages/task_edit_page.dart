// lib/pages/task_edit_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/task_providers.dart';

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

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _titleCtl.text = t?.title ?? '';
    _noteCtl.text = t?.note ?? '';
    _due = t?.due;
    _repeat = t?.repeat ?? RepeatRule.none;
    _done = t?.done ?? false;
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

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Tarih seç',
      cancelText: 'Vazgeç',
      confirmText: 'Devam',
      builder: (ctx, child) => Theme(
        data: theme.copyWith(useMaterial3: true),
        child: child!,
      ),
    );
    if (date == null) return;

    final tod = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due ?? now),
      helpText: 'Saat seç',
      cancelText: 'Vazgeç',
      confirmText: 'Tamam',
      builder: (ctx, child) => Theme(
        data: theme.copyWith(useMaterial3: true),
        child: child!,
      ),
    );
    if (tod == null) return;

    setState(() {
      _due = DateTime(date.year, date.month, date.day, tod.hour, tod.minute);
    });
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
    );

    final notifier = ref.read(taskListProvider.notifier);
    if (base == null) {
      await notifier.add(toSave);
    } else {
      await notifier.updateTask(toSave);
    }
    if (mounted) Navigator.pop(context);
  }

  // ---- metadata (createdAt / updatedAt) güvenli okuma ----
  DateTime? _safeCreatedAt() {
    try {
      final dynamic t = widget.initial;
      return t?.createdAt as DateTime?;
    } catch (_) {
      return null;
    }
  }

  DateTime? _safeUpdatedAt() {
    try {
      final dynamic t = widget.initial;
      return t?.updatedAt as DateTime?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    final createdAt = _safeCreatedAt();
    final updatedAt = _safeUpdatedAt();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Görevi Düzenle' : 'Yeni Görev'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Kaydet')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Başlık
            TextFormField(
              controller: _titleCtl,
              autofocus: !isEdit,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                hintText: 'Ne yapacaksın?',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Başlık gerekli' : null,
            ),
            const SizedBox(height: 12),

            // Not
            TextFormField(
              controller: _noteCtl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Not (isteğe bağlı)',
                hintText: 'Detay, link ya da ek açıklama…',
              ),
            ),
            const SizedBox(height: 16),

            // Tarih / Saat
            Text('Tarih & Saat', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _pickDateTime,
                  icon: const Icon(Icons.event),
                  label: const Text('Tarih/Saat Seç'),
                ),
                if (_due != null)
                  InputChip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(_formatDate(_due!)),
                    onDeleted: () => setState(() => _due = null),
                    deleteIcon: const Icon(Icons.clear),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Hızlı kısayollar
            Wrap(
              spacing: 8,
              runSpacing: -4,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.today, size: 16),
                  label: const Text('Bugün 09:00'),
                  onPressed: () {
                    final n = DateTime.now();
                    _setQuick(DateTime(n.year, n.month, n.day, 9, 0));
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.nightlight_round, size: 16),
                  label: const Text('Bu Akşam 20:00'),
                  onPressed: () {
                    final n = DateTime.now();
                    _setQuick(DateTime(n.year, n.month, n.day, 20, 0));
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Yarın 09:00'),
                  onPressed: () {
                    final n = DateTime.now().add(const Duration(days: 1));
                    _setQuick(DateTime(n.year, n.month, n.day, 9, 0));
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Tekrar
            DropdownButtonFormField<RepeatRule>(
              value: _repeat,
              decoration: const InputDecoration(labelText: 'Tekrar'),
              items: const [
                DropdownMenuItem(value: RepeatRule.none, child: Text('Yok')),
                DropdownMenuItem(value: RepeatRule.daily, child: Text('Günlük')),
                DropdownMenuItem(value: RepeatRule.weekly, child: Text('Haftalık')),
                DropdownMenuItem(value: RepeatRule.monthly, child: Text('Aylık')),
              ],
              onChanged: (v) => setState(() => _repeat = v ?? RepeatRule.none),
            ),
            const SizedBox(height: 12),

            // Tamamlandı (sadece düzenlemede)
            if (isEdit)
              SwitchListTile(
                value: _done,
                onChanged: (v) => setState(() => _done = v),
                title: const Text('Tamamlandı'),
                contentPadding: EdgeInsets.zero,
              ),

            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Kaydet'),
            ),

            // ----- METADATA FOOTER -----
            if (isEdit && (createdAt != null || updatedAt != null)) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              _MetaRow(
                icon: Icons.add_circle_outline,
                label: 'Eklenme',
                value: createdAt != null ? _formatDate(createdAt) : '—',
              ),
              const SizedBox(height: 6),
              _MetaRow(
                icon: Icons.edit_outlined,
                label: 'Güncellenme',
                value: updatedAt != null ? _formatDate(updatedAt) : '—',
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: .6,
                child: Text(
                  'Bu bilgiler salt okunurdur.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(label, style: t.bodySmall),
        const Spacer(),
        Text(value, style: t.bodySmall?.copyWith(fontFeatures: const [])),
      ],
    );
  }
}

// ---- helpers ----
String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${two(d.day)}.${two(d.month)}.${d.year}';
  final time = '${two(d.hour)}:${two(d.minute)}';
  return '$date $time';
}