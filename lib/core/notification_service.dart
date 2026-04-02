// notification_service.dart — HalalCalorie v1.0
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleWaterReminder() async {
    const android = AndroidNotificationDetails(
      'water', 'Water Reminders',
      importance: Importance.defaultImportance,
    );
    for (int h = 8; h <= 22; h += 2) {
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, h);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        h,
        'اشرب ماء',
        'حافظ على رطوبة جسمك',
        tz.TZDateTime.from(scheduled, tz.local),
        const NotificationDetails(android: android),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  static Future<void> cancelAll() => _plugin.cancelAll();
}
