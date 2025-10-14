import 'package:timezone/timezone.dart' as tz;
import '../notifications/notification_service.dart';
import 'time_service.dart';

class SchedulerService {
  SchedulerService(this._time);
  final TimeService _time;

  Future<void> scheduleOneShot({
    required String tzId,
    required DateTime localDateTime,
    required int notificationId,
    required String title,
    required String body,
  }) async {
    final tzdt = _time.localToTz(tzId, localDateTime);
    await NotificationService.scheduleAt(
      id: notificationId,
      title: title,
      body: body,
      when: tzdt,
    );
  }

  Future<void> snooze({
    required int notificationId,
    required Duration delta,
    required String title,
    required String body,
  }) async {
    final when = tz.TZDateTime.now(tz.local).add(delta);
    await NotificationService.scheduleAt(
      id: notificationId,
      title: title,
      body: body,
      when: when,
    );
  }

  Future<void> cancel(int notificationId) =>
      NotificationService.cancel(notificationId);
}
