// notification_service.dart — HalalCalorie v56 (PATCH_V56_NOTIFICATIONS)
//
// Why reminders never showed up before v56:
//   * Android 13+ needs the POST_NOTIFICATIONS runtime permission. It was only
//     requested when the user flipped the master switch off and on again, and
//     the switch defaults to on, so the prompt never appeared.
//   * Everything was scheduled with the status-bar launcher icon, which Android
//     draws as a blank white square.
//   * Nothing told the user (or us) whether the OS was blocking notifications.
//
// v56 asks for the permission once after onboarding, reports the real state in
// the Notification Center, localises every reminder, makes notifications tappable
// and adds the premium "smart" reminders (streak guard, weekly review, sunnah-fast
// eve, suhoor / iftar by prayer time, custom times).
import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import 'package:flutter/material.dart' show Color;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'database.dart';
import 'fasting_calendar.dart';
import 'hijri.dart';
import 'l10n.dart';
import 'prayer_service.dart';

class NotifStatus {
  final bool enabled; // the OS lets us post notifications
  final bool exact; // exact alarms are allowed
  final int pending; // notifications currently scheduled
  const NotifStatus(
      {required this.enabled, required this.exact, required this.pending});
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static String _icon = 'ic_stat_halal';

  /// Set when the user taps a notification; the app shell consumes it.
  static final ValueNotifier<String?> pendingRoute = ValueNotifier<String?>(null);

  // ── IDs ────────────────────────────────────────────────────
  // +h for hourly water -> 108..122.
  static const int kWater = 100;
  static const int kBreakfast = 10;
  static const int kLunch = 11;
  static const int kDinner = 12;
  static const int kWorkout = 30;
  static const int kGeneral = 99;
  static const int kAscent = 40;
  // premium / smart
  static const int kStreak = 50;
  static const int kWeekly = 51;
  static const int kSunnahBase = 60; // 60..79
  static const int kSuhoorBase = 80; // 80..82
  static const int kIftarBase = 90; // 90..92
  static const int kTest = 97;
  static const int kTestLater = 98;

  static const _channel = AndroidNotificationChannel(
    'halalcalorie_main',
    'HalalCalorie Reminders',
    description: 'Meal, water and fasting reminders',
    importance: Importance.high,
    playSound: true,
  );

  // ── Init ───────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(_deviceLocation());

    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    Future<void> doInit(String icon) => _plugin.initialize(
          InitializationSettings(
              android: AndroidInitializationSettings(icon), iOS: ios),
          onDidReceiveNotificationResponse: _onResponse,
        );
    try {
      await doInit(_icon);
    } catch (e) {
      // The monochrome status icon is written by patch_android.py; if it is
      // missing, fall back to the launcher icon rather than losing every reminder.
      debugPrint('Notif icon fallback: $e');
      _icon = '@mipmap/ic_launcher';
      await doInit(_icon);
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final p = launch!.notificationResponse?.payload;
        if (p != null && p.isNotEmpty) pendingRoute.value = p;
      }
    } catch (_) {}

    _initialized = true;
  }

  static void _onResponse(NotificationResponse r) {
    final p = r.payload;
    if (p != null && p.isNotEmpty) pendingRoute.value = p;
  }

  // ── Permissions ────────────────────────────────────────────
  /// Shows the system prompt (Android 13+) and returns whether notifications
  /// are now allowed.
  static Future<bool> requestPermissions() async {
    await init();
    var granted = true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final asked = await android.requestNotificationsPermission();
      granted = asked ?? (await android.areNotificationsEnabled()) ?? false;
    }
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return granted;
  }

  /// Asks once, right after onboarding. Later the Notification Center handles
  /// re-asking and the "blocked in system settings" case.
  static Future<void> askPermissionOnce() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool('notif_perm_asked_v56') ?? false) return;
    await p.setBool('notif_perm_asked_v56', true);
    final ok = await requestPermissions();
    if (ok) await rescheduleAll();
  }

  static Future<NotifStatus> status() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    var enabled = true;
    var exact = false;
    var pending = 0;
    try {
      enabled = (await android?.areNotificationsEnabled()) ?? true;
      exact = (await android?.canScheduleExactNotifications()) ?? false;
    } catch (_) {}
    try {
      pending = (await _plugin.pendingNotificationRequests()).length;
    } catch (_) {}
    return NotifStatus(enabled: enabled, exact: exact, pending: pending);
  }

  static Future<void> openSystemSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }

  // ── Building blocks ────────────────────────────────────────
  static NotificationDetails _details(String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: _icon,
          color: const Color(0xFF238636),
          styleInformation: BigTextStyleInformation(body),
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  static Future<AndroidScheduleMode> _mode() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if ((await android?.canScheduleExactNotifications()) == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}
    // Exact alarms are not allowed by default on Android 13+; a reminder a few
    // minutes late beats one that throws and never fires.
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static Future<void> _zoned(
    int id,
    String title,
    String body,
    tz.TZDateTime when, {
    String? payload,
    DateTimeComponents? match,
  }) async {
    await init();
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details(body),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: match,
          payload: payload,
        );
    final mode = await _mode();
    try {
      await go(mode);
    } on PlatformException catch (e) {
      if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
        debugPrint('Exact alarm refused, using inexact: $e');
        await go(AndroidScheduleMode.inexactAllowWhileIdle);
      } else {
        rethrow;
      }
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    await _plugin.show(id, title, body, _details(body), payload: payload);
  }

  static Future<void> _daily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var sched =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!sched.isAfter(now)) sched = sched.add(const Duration(days: 1));
    await _zoned(id, title, body, sched,
        payload: payload, match: DateTimeComponents.time);
  }

  // ── Small helpers ──────────────────────────────────────────
  static Future<String> _lang() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('language') ?? 'ar';
  }

  static String _t(String lang, String ar, String en) => tLang(lang, ar, en);

  static Future<bool> _smartAllowed(SharedPreferences p, String key) async {
    final premium = p.getBool('is_premium') ?? false;
    final master = p.getBool('notifications_on') ?? true;
    return premium && master && (p.getBool(key) ?? true);
  }

  static int _minutes(SharedPreferences p, String key, int def) {
    // Custom reminder times are a premium perk; free users keep the defaults.
    final premium = p.getBool('is_premium') ?? false;
    return premium ? (p.getInt(key) ?? def) : def;
  }

  // ── Water (every 2 h, 8am–10pm) ────────────────────────────
  static Future<void> scheduleWaterReminder({bool isAr = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_water') ?? true;
    if (!enabled) {
      await _cancelWater();
      return;
    }
    final lang = await _lang();
    for (int h = 8; h <= 22; h += 2) {
      await _daily(
        id: kWater + h,
        hour: h,
        minute: 0,
        title: _t(lang, '💧 تذكير شرب الماء', '💧 Water Reminder'),
        body: _t(lang, 'كوب ماء الآن يُنعش تركيزك وطاقتك',
            'Stay hydrated — a glass now keeps you sharp'),
        payload: '/home',
      );
    }
  }

  static Future<void> _cancelWater() async {
    for (int h = 8; h <= 22; h += 2) {
      await _plugin.cancel(kWater + h);
    }
  }

  // ── Meals ──────────────────────────────────────────────────
  static Future<void> scheduleMealReminder({bool isAr = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_meals') ?? true;
    if (!enabled) {
      for (final id in [kBreakfast, kLunch, kDinner]) {
        await _plugin.cancel(id);
      }
      return;
    }
    final lang = await _lang();
    final b = _minutes(prefs, 'time_breakfast', 7 * 60 + 30);
    final l = _minutes(prefs, 'time_lunch', 13 * 60);
    final d = _minutes(prefs, 'time_dinner', 19 * 60 + 30);
    await _daily(
      id: kBreakfast,
      hour: b ~/ 60,
      minute: b % 60,
      title: _t(lang, '🌅 وقت الفطور', '🌅 Breakfast Time'),
      body: _t(lang, 'بسم الله — سجّل فطورك ✨',
          'Say Bismillah and log your breakfast ✨'),
      payload: '/nutrition',
    );
    await _daily(
      id: kLunch,
      hour: l ~/ 60,
      minute: l % 60,
      title: _t(lang, '☀️ وقت الغداء', '☀️ Lunch Time'),
      body: _t(lang, 'لا تنسَ تسجيل غدائك في HalalCalorie',
          "Don't forget to log your lunch"),
      payload: '/nutrition',
    );
    await _daily(
      id: kDinner,
      hour: d ~/ 60,
      minute: d % 60,
      title: _t(lang, '🌙 وقت العشاء', '🌙 Dinner Time'),
      body: _t(lang, 'سجّل عشاءك وحقّق هدفك اليومي 🌙',
          'Log your dinner and hit your daily goal 🌙'),
      payload: '/nutrition',
    );
  }

  // ── Workout ────────────────────────────────────────────────
  static Future<void> scheduleWorkoutReminder({bool isAr = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_workout') ?? false;
    if (!enabled) {
      await _plugin.cancel(kWorkout);
      return;
    }
    final lang = await _lang();
    final w = _minutes(prefs, 'time_workout', 17 * 60 + 30);
    await _daily(
      id: kWorkout,
      hour: w ~/ 60,
      minute: w % 60,
      title: _t(lang, '💪 وقت التمرين', '💪 Workout Time'),
      body: _t(lang, 'حرّك جسمك — حتى المشي القصير يُحسب',
          'Move your body — even a short walk counts'),
      payload: '/fitness',
    );
  }

  // ── Ascent nudge ───────────────────────────────────────────
  static Future<void> scheduleAscentNudge({bool isAr = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final on = prefs.getBool('notif_ascent') ?? prefs.getBool('notif_barakah') ?? true;
    if (!on) {
      await _plugin.cancel(kAscent);
      return;
    }
    final lang = await _lang();
    await _daily(
      id: kAscent,
      hour: 15,
      minute: 45,
      title: _t(lang, '▲ مهامك اليومية ما زالت مفتوحة',
          '▲ Your daily quests are still open'),
      body: _t(lang, 'ماء وخطوات ولحظة هدوء — الإنجازات الصغيرة تتراكم',
          'Water, steps and a quiet moment — small wins add up'),
      payload: '/ascent',
    );
  }

  // ═══════════════ Premium: smart reminders ═══════════════════

  /// Evening nudge that only exists while today has no meals logged.
  static Future<void> scheduleStreakGuard() async {
    final p = await SharedPreferences.getInstance();
    if (!await _smartAllowed(p, 'notif_streak')) {
      await _plugin.cancel(kStreak);
      return;
    }
    var logged = false;
    try {
      logged = (await AppDatabase.getTodayMeals()).isNotEmpty;
    } catch (_) {}
    final streak = p.getInt('streak') ?? 0;
    final lang = await _lang();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 30);
    if (logged || !when.isAfter(now)) when = when.add(const Duration(days: 1));
    await _zoned(
      kStreak,
      _t(lang, '🔥 لا تكسر سلسلتك', '🔥 Keep your streak alive'),
      streak > 1
          ? _t(lang, 'سلسلتك $streak يومًا — سجّل وجبة قبل نهاية اليوم',
              'Your $streak-day streak is on the line — log a meal before midnight')
          : _t(lang, 'سجّل وجباتك اليوم لتبدأ سلسلة جديدة',
              "Log today's meals to start a new streak"),
      when,
      payload: '/nutrition',
    );
  }

  /// Friday evening: the weekly review is ready.
  static Future<void> scheduleWeeklyReview() async {
    final p = await SharedPreferences.getInstance();
    if (!await _smartAllowed(p, 'notif_weekly')) {
      await _plugin.cancel(kWeekly);
      return;
    }
    final lang = await _lang();
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 0);
    while (d.weekday != DateTime.friday || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    await _zoned(
      kWeekly,
      _t(lang, '📊 مراجعتك الأسبوعية جاهزة', '📊 Your weekly review is ready'),
      _t(lang, 'اطّلع على تقدّمك والتزامك وتوقّع وزنك',
          'See your trends, consistency and weight forecast'),
      d,
      payload: '/insights',
      match: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// The evening before each recommended fast in the next three weeks.
  static Future<void> scheduleSunnahFasts() async {
    final p = await SharedPreferences.getInstance();
    for (var i = 0; i < 20; i++) {
      await _plugin.cancel(kSunnahBase + i);
    }
    if (!await _smartAllowed(p, 'notif_sunnah')) return;
    final lang = await _lang();
    final nowL = DateTime.now();
    final fasts = FastingCalendar.upcoming(
        from: DateTime(nowL.year, nowL.month, nowL.day), days: 21);
    final now = tz.TZDateTime.now(tz.local);
    var slot = 0;
    for (final f in fasts) {
      if (slot >= 20) break;
      final eve = DateTime(f.date.year, f.date.month, f.date.day - 1);
      final when =
          tz.TZDateTime(tz.local, eve.year, eve.month, eve.day, 20, 30);
      if (!when.isAfter(now)) continue;
      final titleAr = FastingCalendar.titleAr(f.kind);
      final titleEn = FastingCalendar.titleEn(f.kind);
      await _zoned(
        kSunnahBase + slot,
        _t(lang, '🌙 غدًا: $titleAr', '🌙 Tomorrow: $titleEn'),
        _t(lang, 'انوِ الصيام وتسحّر — فإن في السحور بركة',
            'Make your intention and eat suhoor — there is blessing in it'),
        when,
        payload: '/fasting',
      );
      slot++;
    }
  }

  /// Suhoor (45 min before Fajr) and iftar (10 min before Maghrib) for the next
  /// three days, on Ramadan days and on recommended fasting days. Today's prayer
  /// times are reused for the following days; they drift by about a minute a day.
  static Future<void> scheduleSuhoorIftar({
    required PrayerTimes? times,
    required bool ramadanMode,
  }) async {
    final p = await SharedPreferences.getInstance();
    for (var i = 0; i < 3; i++) {
      await _plugin.cancel(kSuhoorBase + i);
      await _plugin.cancel(kIftarBase + i);
    }
    if (times == null) return;
    final premium = p.getBool('is_premium') ?? false;
    final master = p.getBool('notifications_on') ?? true;
    if (!premium || !master) return;
    final wantSuhoor = p.getBool('notif_suhoor') ?? true;
    final wantIftar = p.getBool('notif_iftar') ?? true;
    final lang = await _lang();
    final nowL = DateTime.now();
    final now = tz.TZDateTime.now(tz.local);
    for (var d = 0; d < 3; d++) {
      final day = DateTime(nowL.year, nowL.month, nowL.day + d);
      final fasting = ramadanMode ||
          HijriDate.fromGregorian(day).isRamadan ||
          FastingCalendar.isSunnahFast(day);
      if (!fasting) continue;
      if (wantSuhoor) {
        final t = tz.TZDateTime(tz.local, day.year, day.month, day.day,
                times.fajr.hour, times.fajr.minute)
            .subtract(const Duration(minutes: 45));
        if (t.isAfter(now)) {
          await _zoned(
            kSuhoorBase + d,
            _t(lang, '🥣 وقت السحور', '🥣 Suhoor time'),
            _t(lang, 'تسحّروا فإن في السحور بركة — الفجر بعد ٤٥ دقيقة',
                'Eat suhoor, there is blessing in it — Fajr is in 45 minutes'),
            t,
            payload: '/fasting',
          );
        }
      }
      if (wantIftar) {
        final t = tz.TZDateTime(tz.local, day.year, day.month, day.day,
                times.maghrib.hour, times.maghrib.minute)
            .subtract(const Duration(minutes: 10));
        if (t.isAfter(now)) {
          await _zoned(
            kIftarBase + d,
            _t(lang, '🌇 الإفطار بعد ١٠ دقائق', '🌇 Iftar in 10 minutes'),
            _t(lang, 'ذهب الظمأ وابتلّت العروق وثبت الأجر إن شاء الله',
                'Break your fast with dates and water, then pray Maghrib'),
            t,
            payload: '/home',
          );
        }
      }
    }
  }

  /// Re-applies every smart reminder. Safe to call as often as you like.
  static Future<void> refreshSmart({
    PrayerTimes? times,
    bool ramadan = false,
  }) async {
    await init();
    final jobs = <Future<void> Function()>[
      scheduleStreakGuard,
      scheduleWeeklyReview,
      scheduleSunnahFasts,
      () => scheduleSuhoorIftar(times: times, ramadanMode: ramadan),
    ];
    for (final job in jobs) {
      try {
        await job();
      } catch (e) {
        debugPrint('Smart notif: $e');
      }
    }
  }

  // ── Tests ──────────────────────────────────────────────────
  static Future<void> sendTest() async {
    final lang = await _lang();
    await show(
      id: kTest,
      title: _t(lang, '✅ الإشعارات تعمل', '✅ Notifications are working'),
      body: _t(lang, 'ستصلك تذكيرات الماء والوجبات في أوقاتها بإذن الله',
          'Your water and meal reminders will arrive on time'),
      payload: '/home',
    );
  }

  static Future<void> scheduleTestInOneMinute() async {
    final lang = await _lang();
    final when =
        tz.TZDateTime.now(tz.local).add(const Duration(seconds: 60));
    await _zoned(
      kTestLater,
      _t(lang, '⏰ اختبار التذكير المجدول', '⏰ Scheduled reminder test'),
      _t(lang, 'وصل هذا الإشعار من جدولة النظام — كل شيء سليم',
          'This one came from the system scheduler — all good'),
      when,
      payload: '/home',
    );
  }

  // ── Cancel ─────────────────────────────────────────────────
  static Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  // ── Timezone ───────────────────────────────────────────────
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

  static Future<void> _cancelLegacyWaterIds() async {
    for (int h = 8; h <= 22; h += 2) {
      await _plugin.cancel(1 + h);
    }
  }

  /// Idempotent: ids are stable, so this replaces rather than duplicates.
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
      scheduleStreakGuard,
      scheduleWeeklyReview,
      scheduleSunnahFasts,
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
