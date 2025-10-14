import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _flnp = FlutterLocalNotificationsPlugin();
  static final StreamController<String> _tapPayloadCtrl =
      StreamController<String>.broadcast();

  static Stream<String> get onNotificationTap => _tapPayloadCtrl.stream;

  /// Uygulama ilk açıldığında çağrılır.
  static Future<void> init() async {
    final androidInit = const AndroidInitializationSettings('@mipmap/ic_launcher');

    // 👇 const KALDIRILDI — çünkü içindeki kategoriler const olamaz
    final darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'task_actions',
          actions: [
            DarwinNotificationAction.plain('complete', 'Tamamla'),
            DarwinNotificationAction.plain('snooze5', '5 dk ertele'),
          ],
          options: {DarwinNotificationCategoryOption.hiddenPreviewShowTitle},
        ),
      ],
    );

    final settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _flnp.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) async {
        final payload = resp.payload ?? '';
        final action = resp.actionId;

        if (action == 'complete') {
          _tapPayloadCtrl.add('action:complete;$payload');
        } else if (action == 'snooze5') {
          _tapPayloadCtrl.add('action:snooze5;$payload');
        } else {
          _tapPayloadCtrl.add(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 🔔 Platform bazlı izinler
    if (Platform.isAndroid) {
      final android = _flnp.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      final darwin = _flnp.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await darwin?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse resp) {
    // arka plan tıklamaları sessizce geçilir
  }

  /// Anında gösterilen bildirim
  static Future<void> showInstant({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const android = AndroidNotificationDetails(
      'default_channel_id',
      'General',
      channelDescription: 'General notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwin = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: android, iOS: darwin, macOS: darwin);

    await _flnp.show(id, title, body, details, payload: payload);
  }

  /// Zamanlı (tek seferlik) bildirim planlama
  static Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    String? payload,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now.add(const Duration(seconds: 1)))) {
      // geçmiş bir zaman => planlama yapma
      return;
    }

    final android = AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Task reminders',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        const AndroidNotificationAction('complete', 'Tamamla'),
        const AndroidNotificationAction('snooze5', '5 dk ertele'),
      ],
    );

    final darwin = const DarwinNotificationDetails(
      categoryIdentifier: 'task_actions',
    );

    final details =
        NotificationDetails(android: android, iOS: darwin, macOS: darwin);

    await _flnp.zonedSchedule(
      id,
      title,
      body,
      when,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      matchDateTimeComponents: null,
    );
  }

  /// Günlük tekrar eden bildirim
  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime firstTime,
    String? payload,
  }) async {
    final android = AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Task reminders',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        const AndroidNotificationAction('complete', 'Tamamla'),
        const AndroidNotificationAction('snooze5', '5 dk ertele'),
      ],
    );

    final darwin = const DarwinNotificationDetails(
      categoryIdentifier: 'task_actions',
    );

    final details =
        NotificationDetails(android: android, iOS: darwin, macOS: darwin);

    await _flnp.zonedSchedule(
      id,
      title,
      body,
      firstTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  /// Haftalık tekrar eden bildirim
  static Future<void> scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime firstTime,
    String? payload,
  }) async {
    final android = AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Task reminders',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        const AndroidNotificationAction('complete', 'Tamamla'),
        const AndroidNotificationAction('snooze5', '5 dk ertele'),
      ],
    );

    final darwin = const DarwinNotificationDetails(
      categoryIdentifier: 'task_actions',
    );

    final details =
        NotificationDetails(android: android, iOS: darwin, macOS: darwin);

    await _flnp.zonedSchedule(
      id,
      title,
      body,
      firstTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  /// Aylık tekrar eden bildirim
  static Future<void> scheduleMonthly({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime firstTime,
    String? payload,
  }) async {
    final android = AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Task reminders',
      importance: Importance.high,
      priority: Priority.high,
      actions: [
        const AndroidNotificationAction('complete', 'Tamamla'),
        const AndroidNotificationAction('snooze5', '5 dk ertele'),
      ],
    );

    final darwin = const DarwinNotificationDetails(
      categoryIdentifier: 'task_actions',
    );

    final details =
        NotificationDetails(android: android, iOS: darwin, macOS: darwin);

    await _flnp.zonedSchedule(
      id,
      title,
      body,
      firstTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      payload: payload,
    );
  }

  /// Belirli bir bildirimi iptal et
  static Future<void> cancel(int id) => _flnp.cancel(id);
}