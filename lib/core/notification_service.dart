// ============================================================
//  notification_service.dart — HalalCalorie
//  Real push notifications: water, streak, workout, prayer
// ============================================================
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Notification IDs ───────────────────────────────────────
  static const int idWater    = 100;
  static const int idStreak   = 200;
  static const int idWorkout  = 300;
  static const int idFajr     = 400;
  static const int idIftar    = 500;
  static const int idWeekly   = 600;

  // ── Init ───────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onTap,
    );

    await _requestPermissions();
    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  static Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static void _onTap(NotificationResponse resp) {
    debugPrint('Notification tapped: \${resp.payload}');
  }

  // ── Water reminders ────────────────────────────────────────
  // Every 2 hours from 8am to 10pm
  static Future<void> scheduleWaterReminders() async {
    await cancelWaterReminders();
    final hours = [8, 10, 12, 14, 16, 18, 20, 22];
    for (int i = 0; i < hours.length; i++) {
      await _scheduleDaily(
        id:      idWater + i,
        title:   '💧 وقت شرب الماء',
        body:    'اشرب كوباً من الماء الآن — هدفك 8 أكواب يومياً',
        hour:    hours[i],
        minute:  0,
        payload: 'water',
      );
    }
    debugPrint('Water reminders scheduled: \${hours.length} times/day');
  }

  static Future<void> cancelWaterReminders() async {
    for (int i = 0; i < 8; i++) {
      await _plugin.cancel(idWater + i);
    }
  }

  // ── Streak protection ──────────────────────────────────────
  // 8pm daily — remind to log food if not done
  static Future<void> scheduleStreakReminder() async {
    await _plugin.cancel(idStreak);
    await _scheduleDaily(
      id:      idStreak,
      title:   '🔥 لا تكسر تتابعك!',
      body:    'سجّل وجبتك اليوم قبل منتصف الليل واحمِ ستريكك',
      hour:    20,
      minute:  0,
      payload: 'streak',
    );
  }

  // ── Workout reminder ───────────────────────────────────────
  static Future<void> scheduleWorkoutReminder({
    int hour = 7, int minute = 0,
  }) async {
    await _plugin.cancel(idWorkout);
    await _scheduleDaily(
      id:      idWorkout,
      title:   '💪 وقت التمرين',
      body:    'ابدأ يومك بتمرين سنة — 15 دقيقة تكفي',
      hour:    hour,
      minute:  minute,
      payload: 'workout',
    );
  }

  // ── Prayer time notification ───────────────────────────────
  static Future<void> schedulePrayerNotification({
    required String prayerName,
    required DateTime time,
    int offsetMinutes = 5,
  }) async {
    final notifTime = time.subtract(Duration(minutes: offsetMinutes));
    if (notifTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      idFajr + prayerName.hashCode.abs() % 10,
      '🕌 \$prayerName قريباً',
      'باقي \$offsetMinutes دقائق على وقت \$prayerName',
      tz.TZDateTime.from(notifTime, tz.local),
      _notifDetails(payload: 'prayer'),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── Iftar reminder ─────────────────────────────────────────
  static Future<void> scheduleIftarReminder(DateTime iftarTime) async {
    final reminderTime = iftarTime.subtract(const Duration(minutes: 15));
    if (reminderTime.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      idIftar,
      '🌙 الإفطار قريب',
      'باقي 15 دقيقة على الإفطار — جهّز تمرك وماءك',
      tz.TZDateTime.from(reminderTime, tz.local),
      _notifDetails(payload: 'iftar'),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // ── Weekly summary notification ────────────────────────────
  // Every Sunday at 9am
  static Future<void> scheduleWeeklySummary() async {
    await _plugin.cancel(idWeekly);
    final now = tz.TZDateTime.now(tz.local);
    var nextSunday = now;
    while (nextSunday.weekday != DateTime.sunday) {
      nextSunday = nextSunday.add(const Duration(days: 1));
    }
    nextSunday = tz.TZDateTime(
        tz.local, nextSunday.year, nextSunday.month, nextSunday.day, 9);

    await _plugin.zonedSchedule(
      idWeekly,
      '📊 تقريرك الأسبوعي جاهز',
      'شاهد ملخص أسبوعك الصحي — كيف كانت سعراتك؟',
      nextSunday,
      _notifDetails(payload: 'weekly'),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // ── Instant notification ───────────────────────────────────
  static Future<void> show({
    required int    id,
    required String title,
    required String body,
    String?         payload,
  }) async {
    await _plugin.show(id, title, body, _notifDetails(payload: payload));
  }

  // ── Cancel all ────────────────────────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Schedule all defaults ─────────────────────────────────
  static Future<void> scheduleAllDefaults() async {
    await Future.wait([
      scheduleWaterReminders(),
      scheduleStreakReminder(),
      scheduleWorkoutReminder(),
      scheduleWeeklySummary(),
    ]);
    debugPrint('All default notifications scheduled');
  }

  // ── Helpers ───────────────────────────────────────────────
  static NotificationDetails _notifDetails({String? payload}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'halalcalorie_main',
        'HalalCalorie',
        channelDescription: 'تنبيهات هلال كالوري',
        importance:  Importance.high,
        priority:    Priority.high,
        color:       const Color(0xFF00A86B),
        largeIcon:   const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  static Future<void> _scheduleDaily({
    required int    id,
    required String title,
    required String body,
    required int    hour,
    required int    minute,
    String?         payload,
  }) async {
    final now  = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id, title, body, scheduled,
      _notifDetails(payload: payload),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
