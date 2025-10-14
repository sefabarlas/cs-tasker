// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_timezone_updated_gradle/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'constants/app_info.dart';
import 'pages/home_page.dart';
import 'pages/task_edit_page.dart';
import 'providers/task_providers.dart';
import 'src/notifications/notification_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> _initTz() async {
  tz.initializeTimeZones();
  final localTz = await FlutterNativeTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(localTz));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initTz();
  await NotificationService.init(); // izinler burada istenir

  runApp(const ProviderScope(child: TaskerApp()));

  // 🔔 Bildirime tıklanınca ilgili görevin düzenleme sayfasına git
  NotificationService.onNotificationTap.listen((payload) async {
    // olası formatlar:
    // 1) "taskId:123"
    // 2) "action:complete;taskId:123"
    // 3) "action:snooze5;taskId:123"

    String data = payload;
    String? action;
    if (payload.startsWith('action:')) {
      final parts = payload.split(';');
      action = parts[0].split(':').elementAtOrNull(1);
      data = parts.elementAtOrNull(1) ?? '';
    }

    final m = RegExp(r'taskId:(\d+)').firstMatch(data);
    if (m == null) return;

    final id = int.tryParse(m.group(1)!);
    if (id == null) return;

    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final container = ProviderScope.containerOf(ctx);
    final repo = container.read(taskRepositoryProvider);
    final task = await repo.getById(id);
    if (task == null) return;

    if (action == 'complete') {
      await repo.update(task.copyWith(done: true));
      await container.read(taskListProvider.notifier).refresh();
      return;
    } else if (action == 'snooze5') {
      final newDue = DateTime.now().add(const Duration(minutes: 5));
      await repo.update(task.copyWith(due: newDue, done: false));
      await container.read(taskListProvider.notifier).refresh();
      return;
    }

    // aksiyon yoksa => detay sayfasına git
    Navigator.of(ctx).push(
      MaterialPageRoute(builder: (_) => TaskEditPage(initial: task)),
    );
  });
}

class TaskerApp extends StatelessWidget {
  const TaskerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = Colors.indigo;
    return MaterialApp(
      title: appName,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        brightness: Brightness.light,
        cardTheme: CardThemeData(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        chipTheme: const ChipThemeData(
          showCheckmark: false,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      ),
      home: const HomePage(),
    );
  }
}