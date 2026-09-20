// notification_service.dart — HalalCalorie v2.0
// Real local-notification implementation
// Packages: flutter_local_notifications ^17.2.0 | timezone ^0.9.4
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── IDs ────────────────────────────────────────────────────
  // +h for hourly water -> 108..122. Was 1+h, which put h=10 on id 11 == kLunch
  // and let the water reminder overwrite the lunch reminder.
  static const int kWater     = 100;
  static const int kBreakfast = 10;
  static const int kLunch     = 11;
  static const int kDinner    = 12;
  static const int kWorkout   = 30;
  static const int kGeneral   = 99;
  static const int kAscent   = 40; // Ascent daily-quest nudge

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
    tz.setLocalLocation(_deviceLocation());

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
      // Inexact on purpose: exact alarms need SCHEDULE_EXACT_ALARM (not in the
      // manifest, denied by default on Android 13+) and zonedSchedule throws
      // without it. A reminder a few minutes late beats none at all.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
        title: '💧 Water Reminder',
        body:  'Stay hydrated — a glass now keeps you sharp',
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
      title: '🌅 Breakfast Time',
      body:  'Say Bismillah and log your breakfast ✨',
    );
    await _daily(
      id: kLunch, hour: 13, minute: 0,
      title: '☀️ Lunch Time',
      body:  isAr ? 'لا تنسَ تسجيل غداءك في HalalCalorie' : "Don't forget to log your lunch",
    );
    await _daily(
      id: kDinner, hour: 19, minute: 30,
      title: '🌙 Dinner Time',
      body:  'Log your dinner and hit your daily goal 🌙',
    );
  }

  // ── Workout reminder ───────────────────────────────────────
  static Future<void> scheduleWorkoutReminder({bool isAr = true}) async {
    final prefs   = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_workout') ?? false;
    if (!enabled) { await _plugin.cancel(kWorkout); return; }
    await _daily(
      id: kWorkout, hour: 17, minute: 30,
      title: '💪 Workout Time',
      body:  'Move your body — even a short walk counts',
    );
  }

  // ── Ascent nudge (mid-afternoon) ───────────────────────────
  /// Mid-afternoon reminder that the day's quests are still open, in
  /// time to actually finish a few of them.
  static Future<void> scheduleAscentNudge({bool isAr = true}) async {
    final prefs = await SharedPreferences.getInstance();
    // Honours the old preference key so existing opt-outs are respected.
    final on = prefs.getBool('notif_ascent')
        ?? prefs.getBool('notif_barakah') ?? true;
    if (!on) { await _plugin.cancel(kAscent); return; }
    await _daily(
      id: kAscent, hour: 15, minute: 45,
      title: '▲ Your daily quests are still open',
      body:  'Water, steps and a quiet moment — small wins add up',
    );
  }

  // ── Cancel all ─────────────────────────────────────────────
  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  // ── Timezone ───────────────────────────────────────────────
  /// `DateTime.timeZoneName` is an abbreviation ("EET", "+03"), never an IANA
  /// id, so `tz.getLocation(name)` threw for nearly everyone and every reminder
  /// was scheduled on Asia/Riyadh time. Match the device instead: a zone whose
  /// UTC offset agrees at four points across the year (so DST shape matches
  /// too), preferring one whose abbreviation also agrees.
  static tz.Location _deviceLocation() {
    final now = DateTime.now();
    final probes = [
      for (final d in const [0, 91, 182, 273]) now.add(Duration(days: d)),
    ];
    tz.Location? best;
    var bestScore = -1;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      var matches = true;
      for (final p in probes) {
        if (tz.TZDateTime.from(p, loc).timeZoneOffset != p.timeZoneOffset) {
          matches = false;
          break;
        }
      }
      if (!matches) continue;
      final score =
          tz.TZDateTime.from(now, loc).timeZoneName == now.timeZoneName ? 1 : 0;
      if (score > bestScore) {
        best = loc;
        bestScore = score;
        if (score == 1) break;
      }
    }
    return best ?? tz.getLocation('UTC');
  }

  // ── Re-apply everything from the stored prefs ──────────────
  /// Water used to sit on ids 1+h (9..23), which collided with the meal ids
  /// (lunch = 11). Clear the old slots once so nothing stale lingers.
  static Future<void> _cancelLegacyWaterIds() async {
    for (int h = 8; h <= 22; h += 2) {
      await _plugin.cancel(1 + h);
    }
  }

  /// Idempotent: ids are stable, so this replaces rather than duplicates, and it
  /// re-anchors the times to the device's current timezone. Honours the master
  /// toggle, and each job is isolated so one failure can't block the others.
  static Future<void> rescheduleAll({bool isAr = true}) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notifications_on') ?? true)) {
      await _plugin.cancelAll();
      return;
    }
    if (!(prefs.getBool('notif_ids_v2') ?? false)) {
      await _cancelLegacyWaterIds();
      await prefs.setBool('notif_ids_v2', true);
    }
    final jobs = <Future<void> Function()>[
      () => scheduleMealReminder(isAr: isAr),
      () => scheduleWaterReminder(isAr: isAr),
      () => scheduleWorkoutReminder(isAr: isAr),
      () => scheduleAscentNudge(isAr: isAr),
    ];
    for (final job in jobs) {
      try {
        await job();
      } catch (e) {
        debugPrint('Notif schedule: $e');
      }
    }
  }
}
