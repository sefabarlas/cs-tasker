// lib/src/notifications/notification_service.dart
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:tasker/data/task_repository.dart';
import 'package:tasker/src/data/db.dart';
import 'package:tasker/models/task.dart' as model_task;

// --- ADIM 1: EN ÖNEMLİ KISIM ---
// Bu fonksiyon, sınıfın dışında, global bir alanda olmalıdır.
// Uygulama kapalıyken bile Flutter tarafından çağrılabilmesi için bu gereklidir.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Bu fonksiyon, onDidReceiveNotificationResponse ile aynı işi yapacak.
  // Bu yüzden doğrudan ona yönlendiriyoruz.
  onDidReceiveNotificationResponse(notificationResponse);
}

// Bu fonksiyon da global olmalı veya statik bir metodun içinde çağrılmalıdır.
// Bildirime tıklandığında veya bir aksiyon seçildiğinde çalışır.
void onDidReceiveNotificationResponse(NotificationResponse details) async {
  final payload = details.payload;
  final actionId = details.actionId;

  if (payload == null || !payload.startsWith('taskId:')) {
    return;
  }

  final taskId = payload.substring('taskId:'.length);

  // Arka planda veritabanına erişmek için YENİ bir bağlantı oluşturulur.
  final db = AppDb();
  final repo = TaskRepository(db);

  final task = await repo.getById(taskId);
  if (task == null) {
    await db.close();
    return;
  }

  model_task.Task? updatedTask;

  // Hangi aksiyona tıklandığını kontrol et
  switch (actionId) {
    case 'act_done':
      updatedTask = task.copyWith(done: true);
      break;
    case 'act_snooze_1h':
      final newDueDate = DateTime.now().add(const Duration(hours: 1));
      updatedTask = task.copyWith(due: newDueDate, done: false);
      break;
    case 'act_snooze_tomorrow':
      final now = DateTime.now();
      final newDueDate = DateTime(now.year, now.month, now.day + 1, 9, 0); // Yarın sabah 09:00
      updatedTask = task.copyWith(due: newDueDate, done: false);
      break;
  }

  if (updatedTask != null) {
    await repo.update(updatedTask);
  }

  // İşlem bittikten sonra veritabanı bağlantısını kapat. Bu çok önemli!
  await db.close();
}


class NotificationService {
  static final _flnp = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    final androidInit = const AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinInit = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory('task_actions', actions: [
          DarwinNotificationAction.plain('act_done', 'Tamamla'),
          DarwinNotificationAction.plain('act_snooze_1h', '1 Saat Ertele'),
          DarwinNotificationAction.plain('act_snooze_tomorrow', 'Yarına Ertele'),
        ]),
      ],
    );

    final settings = InitializationSettings(android: androidInit, iOS: darwinInit, macOS: darwinInit);

    await _flnp.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    if (Platform.isIOS) {
      await _flnp.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (Platform.isAndroid) {
      await _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
  }

  static NotificationDetails _getTaskNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'reminder_channel_id',
        'Reminders',
        channelDescription: 'Task reminders',
        importance: Importance.max,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('act_done', 'Tamamla'),
          AndroidNotificationAction('act_snooze_1h', '1 Saat Ertele'),
          AndroidNotificationAction('act_snooze_tomorrow', 'Yarına Ertele'),
        ],
      ),
      iOS: DarwinNotificationDetails(categoryIdentifier: 'task_actions'),
      macOS: DarwinNotificationDetails(categoryIdentifier: 'task_actions'),
    );
  }

  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String? body,
    required tz.TZDateTime when,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now.add(const Duration(seconds: 1)))) return;
    await _flnp.zonedSchedule(
      id, title, body, when,
      _getTaskNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String? body,
    required tz.TZDateTime firstTime,
    String? payload,
  }) async {
    await _flnp.zonedSchedule(
      id, title, body, firstTime,
      _getTaskNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  static Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String? body,
    required tz.TZDateTime firstTime,
    String? payload,
  }) async {
    await _flnp.zonedSchedule(
      id, title, body, firstTime,
      _getTaskNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }
  
  static Future<void> scheduleMonthly({
    required int id,
    required String title,
    required String? body,
    required tz.TZDateTime firstTime,
    String? payload,
  }) async {
    await _flnp.zonedSchedule(
      id, title, body, firstTime,
      _getTaskNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: payload,
    );
  }

  static Future<void> cancel(int id) => _flnp.cancel(id);
}