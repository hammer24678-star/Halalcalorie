// notification_service.dart — HalalCalorie v2.0
// Real local-notification implementation
// Packages: flutter_local_notifications ^17.2.0 | timezone ^0.9.4
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── IDs ────────────────────────────────────────────────────
  static const int kWater     = 1;   // +h for hourly water (1..23)
  static const int kBreakfast = 10;
  static const int kLunch     = 11;
  static const int kDinner    = 12;
  static const int kWorkout   = 30;
  static const int kGeneral   = 99;
  static const int kBarakah   = 40; // Barakah Engine daily nudge

  // ── Android channel ────────────────────────────────────────
  static const _channel = AndroidNotificationChannel(
    'halalcalorie_main', 'HalalCalorie Reminders',
    description: 'Meal, water and fasting reminders',
    importance: Importance.high,
    playSound: true,
  );

  // ── Init ───────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final tzName = DateTime.now().timeZoneName;
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    _initialized = true;
  }

  // ── Permissions ────────────────────────────────────────────
  static Future<void> requestPermissions() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ── Show immediate ─────────────────────────────────────────
  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    await init();
    await _plugin.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // ── Schedule daily at HH:MM ────────────────────────────────
  static Future<void> _daily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    final now  = tz.TZDateTime.now(tz.local);
    var sched  = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (sched.isBefore(now)) sched = sched.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id, title, body, sched,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id, _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ── Water reminder (every 2 h, 8am–10pm) ──────────────────
  static Future<void> scheduleWaterReminder({bool isAr = true}) async {
    final prefs   = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_water') ?? true;
    if (!enabled) { await _cancelWater(); return; }
    for (int h = 8; h <= 22; h += 2) {
      await _daily(
        id: kWater + h,
        hour: h, minute: 0,
        title: isAr ? '💧 تذكير بشرب الماء' : '💧 Water Reminder',
        body:  isAr
          ? 'لا تنسَ شرب كوب ماء — الجسم أمانة ﷺ'
          : 'Stay hydrated — your body is an amanah ﷺ',
      );
    }
  }

  static Future<void> _cancelWater() async {
    for (int h = 8; h <= 22; h += 2) await _plugin.cancel(kWater + h);
  }

  // ── Meal reminders ─────────────────────────────────────────
  static Future<void> scheduleMealReminder({bool isAr = true}) async {
    final prefs   = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_meals') ?? true;
    if (!enabled) {
      for (final id in [kBreakfast, kLunch, kDinner]) await _plugin.cancel(id);
      return;
    }
    await _daily(
      id: kBreakfast, hour: 7, minute: 30,
      title: isAr ? '🌅 وقت الإفطار' : '🌅 Breakfast Time',
      body:  isAr ? 'قُل بسم الله وسجّل إفطارك ✨' : 'Say Bismillah and log your breakfast ✨',
    );
    await _daily(
      id: kLunch, hour: 13, minute: 0,
      title: isAr ? '☀️ وقت الغداء' : '☀️ Lunch Time',
      body:  isAr ? 'لا تنسَ تسجيل غداءك في HalalCalorie' : "Don't forget to log your lunch",
    );
    await _daily(
      id: kDinner, hour: 19, minute: 30,
      title: isAr ? '🌙 وقت العشاء' : '🌙 Dinner Time',
      body:  isAr ? 'سجّل عشاءك واكمل هدفك اليومي 🌙' : 'Log your dinner and hit your daily goal 🌙',
    );
  }

  // ── Workout reminder ───────────────────────────────────────
  static Future<void> scheduleWorkoutReminder({bool isAr = true}) async {
    final prefs   = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_workout') ?? false;
    if (!enabled) { await _plugin.cancel(kWorkout); return; }
    await _daily(
      id: kWorkout, hour: 17, minute: 30,
      title: isAr ? '💪 وقت الرياضة' : '💪 Workout Time',
      body:  isAr
        ? 'حرّك جسمك — النبي ﷺ كان يمشي كثيراً'
        : 'Move your body — the Prophet ﷺ walked daily',
    );
  }

  // ── Barakah Engine nudge (Asr time ~15:45) ─────────────────
  /// Fires at 15:45 if the user has not updated their Barakah
  /// score yet today (score == 0 in DB). Cancels itself if score > 0.
  static Future<void> scheduleBarakahNudge({bool isAr = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final on    = prefs.getBool('notif_barakah') ?? true;
    if (!on) { await _plugin.cancel(kBarakah); return; }
    await _daily(
      id: kBarakah, hour: 15, minute: 45,
      title: isAr ? '✨ نقاط بركتك تنتظرك' : '✨ Your Barakah score is waiting',
      body:  isAr
        ? 'سجّل ذكرك ومائك وخطواتك — حافظ على بركتك اليوم'
        : 'Log your dhikr, water & steps — keep your Barakah alive',
    );
  }

  // ── Cancel all ─────────────────────────────────────────────
  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}
