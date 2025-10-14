// lib/src/ui/providers.dart (Son Hali)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tasker/data/task_repository.dart';
import 'package:tasker/src/notifications/notification_service.dart';
import '../data/db.dart'; // AppDb, Task, vb.
import '../domain/time_service.dart';
import '../domain/scheduler_service.dart';

// ⚠️ NOT: dbProvider'ın lib/src/data/db.dart'ta tanımlandığını varsayıyoruz.
// Eğer oraya taşıdıysanız, buradaki tanım çakışmaya neden olabilir.
// En temiz yöntem, AppDb provider'ını tek bir yerde tanımlayıp buradan kullanmaktır.

// AppDb Provider'ı
final appDbProvider = Provider<AppDb>((ref) => AppDb());

// 🛠️ Task Repository (Drift'i kullanacak)
// Eski taskRepoProvider yerine TaskRepository'yi kullanıyoruz
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.read(appDbProvider);
  return TaskRepository(db);
});

// Hatırlatıcı Repository (Eğer daha sonra Reminders tablosunu kullanacaksanız)
// Şimdilik TaskRepo'yu sildiğimiz için bunu yoruma alıyoruz, ileride ReminderRepo sınıfı yazıldığında açılır.
// final reminderRepoProvider = Provider<ReminderRepo>((ref) => ReminderRepo(ref.read(appDbProvider)));

final timeServiceProvider = Provider<TimeService>((ref) => TimeService());
final schedulerProvider = Provider<SchedulerService>(
  (ref) => SchedulerService(ref.read(timeServiceProvider)),
);

// Notification Service provider'ı (lib/providers/task_providers.dart'ta da tanımlıydı)
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
