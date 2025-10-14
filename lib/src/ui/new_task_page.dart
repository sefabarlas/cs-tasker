import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import 'providers.dart';
import 'package:drift/drift.dart' as drift;


class NewTaskPage extends ConsumerStatefulWidget {
  const NewTaskPage({super.key});

  @override
  ConsumerState<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends ConsumerState<NewTaskPage> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _picked;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Görev')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Başlık')),
          const SizedBox(height: 8),
          TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notlar'), maxLines: 3),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: now,
                lastDate: DateTime(now.year + 5),
              );
              if (date == null) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 5))),
              );
              if (time == null) return;
              _picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
              setState(() {});
            },
            child: Text(_picked == null ? 'Tarih & Saat Seç' : _picked.toString()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _picked == null || _title.text.trim().isEmpty ? null : () async {
              final taskRepo = ref.read(taskRepoProvider);
              final reminderRepo = ref.read(reminderRepoProvider);
              final scheduler = ref.read(schedulerProvider);
              final time = ref.read(timeServiceProvider);

              final id = const Uuid().v4();
              final nowUtc = DateTime.now().toUtc();

              // TR örneği: cihaz TZ'si (Europe/Istanbul) varsayımı
              const tzId = 'Europe/Istanbul';
              final utc = time.toUtcFromLocal(tzId, _picked!);

              // 1) Görevi ekle
              await taskRepo.insertTask(TasksCompanion.insert(
                id: id, title: _title.text.trim(), notes: _notes.text.isEmpty ? const drift.Value.absent() : drift.Value(_notes.text),
                isCompleted: const drift.Value(false), createdAtUtc: nowUtc,
              ));

              // 2) Hatırlatmayı ekle
              final reminderId = const Uuid().v4();
              final notifId = DateTime.now().millisecondsSinceEpoch % 1000000000; // int id
              await reminderRepo.insertReminder(RemindersCompanion.insert(
                id: reminderId,
                taskId: id,
                localDateTime: _picked!,
                timeZoneId: tzId,
                utcFireAt: utc,
                notificationId: notifId,
              ));

              // 3) Bildirimi planla
              await scheduler.scheduleOneShot(
                tzId: tzId,
                localDateTime: _picked!,
                notificationId: notifId,
                title: 'Hatırlatma',
                body: _title.text.trim(),
              );

              if (mounted) Navigator.pop(context);
            },
            child: const Text('Kaydet ve Planla'),
          )
        ],
      ),
    );
  }
}