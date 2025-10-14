import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/task.dart';
import '../../providers/task_providers.dart';

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
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Başlık'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(labelText: 'Notlar'),
            maxLines: 3,
          ),
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
                initialTime: TimeOfDay.fromDateTime(
                  now.add(const Duration(minutes: 5)),
                ),
              );
              if (time == null) return;
              _picked = DateTime(
                date.year,
                date.month,
                date.day,
                time.hour,
                time.minute,
              );
              setState(() {});
            },
            child: Text(
              _picked == null ? 'Tarih & Saat Seç' : _picked.toString(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _picked == null || _title.text.trim().isEmpty
                ? null
                : () async {
                    // ✅ taskRepoProvider yerine taskRepositoryProvider kullanılıyor
                    final taskRepo = ref.read(taskRepositoryProvider);

                    // ❌ Eski, manuel planlama mantığı kaldırıldı
                    // final time = ref.read(timeServiceProvider);
                    // final id = const Uuid().v4();
                    // final nowUtc = DateTime.now().toUtc();
                    // const tzId = 'Europe/Istanbul';
                    // final utc = time.toUtcFromLocal(tzId, _picked!);

                    // 1) Yeni Task Modelini Oluştur
                    final newTask = Task(
                      title: _title.text.trim(),
                      note: _notes.text.trim().isEmpty
                          ? null
                          : _notes.text.trim(),
                      due: _picked,
                      // done, repeat, sort, createdAt, updatedAt repo içinde ayarlanacak
                    );

                    // 2) Görevi ekle (TaskRepository, Drift'e çevrimi ve planlamayı halleder)
                    // ❌ Hata vardı: taskRepo.add(TasksCompanion.insert(...))
                    // ✅ Düzeltme: taskRepo.add(Task model)
                    await taskRepo.add(newTask);

                    // ❌ Hatırlatıcı ve Scheduler ile ilgili tüm eski kodlar kaldırıldı
                    /*
              final reminderId = const Uuid().v4();
              final notifId = DateTime.now().millisecondsSinceEpoch % 1000000000; 
              await reminderRepo.insertReminder(RemindersCompanion.insert(...));
              await scheduler.scheduleOneShot(...);
              */

                    if (mounted) Navigator.pop(context);
                  },
            child: const Text('Kaydet ve Planla'),
          ),
        ],
      ),
    );
  }
}
