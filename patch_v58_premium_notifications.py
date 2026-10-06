#!/usr/bin/env python3
"""
patch_v58_premium_notifications.py
==================================
HalalCalorie v58 - PREMIUM STUDIO + NOTIFICATIONS THAT WORK.
Run from the repo root (after v57):

    python3 patch_v58_premium_notifications.py

Safe to run twice. No new dependencies, no database changes.

NOTIFICATIONS (the reason reminders never showed up)
  * Android 13+ needs the POST_NOTIFICATIONS runtime permission. It was only
    requested if the user toggled the master switch off and on, and the switch
    defaults to ON - so the prompt never appeared. v58 asks once, after
    onboarding (and once for existing users on update).
  * The status-bar icon was the launcher icon, which Android renders as a blank
    white square. patch_android.py now writes a proper monochrome icon.
  * Boot / scheduled-notification receivers are declared explicitly.
  * Exact alarms are used only when the OS allows them, never thrown on.
  * Reminders are localised, tappable (open the right screen), BigText.
  * NEW Notification Center (Settings -> Notification Center): real system
    status, "Test now" and "In 1 minute" buttons, one-tap fix when blocked.

PREMIUM STUDIO  (route /premium, card on Home, entry in Settings)
  AI Coach          offline daily insights + chat that sees today's numbers
                    (Premium 40 msgs/day, free users get a 3-message taste)
  AI Meal Planner   full halal day to your calories + macros (or suhoor/iftar on
                    fasting days), one-tap logging, grocery list. 5 plans/day.
  Insights Pro      7/30/90 days, macro split, weekday pattern, 12-week
                    consistency map, weight forecast + goal date, CSV export.
                    Free: 7-day basics; the rest is blurred over their own data.
  Fasting Planner   Mon/Thu, White Days, Arafah, Ashura, Tasu'a, 6 of Shawwal;
                    Premium: log + streak, suhoor/iftar times, plate guide.
  Smart reminders   streak guard (only if nothing logged), weekly review,
                    sunnah-fast eve, suhoor (-45 min) / iftar (-10 min) from
                    the user's own prayer times, custom meal/workout times.

HONESTY FIX  the paywall, profile, settings and home said "180 workouts"; the
app has 35 plans. All four now say what is true (home shows the live count).

pubspec -> 1.16.0+30
"""
import os, re, sys

ROOT = os.getcwd()
if not os.path.exists(os.path.join(ROOT, 'pubspec.yaml')):
    sys.exit('Run this from the repo root (pubspec.yaml not found).')

ok = skip = 0
def path(p): return os.path.join(ROOT, p)

def write(p, content):
    global ok
    os.makedirs(os.path.dirname(path(p)), exist_ok=True)
    old = None
    if os.path.exists(path(p)):
        old = open(path(p), encoding='utf-8').read()
    if old == content:
        ok += 1; print('  OK     ', p, '(already applied)'); return
    open(path(p), 'w', encoding='utf-8').write(content)
    ok += 1; print('  WROTE  ', p)

def edit(p, fn, label):
    global ok, skip
    if not os.path.exists(path(p)):
        skip += 1; print('  SKIP   ', p, '(missing)', label); return
    s = open(path(p), encoding='utf-8').read()
    n = fn(s)
    if n is None:
        skip += 1; print('  SKIP   ', p, '-', label, '(anchor not found)'); return
    if n == s:
        ok += 1; print('  OK     ', p, '-', label, '(already applied)'); return
    open(path(p), 'w', encoding='utf-8').write(n)
    ok += 1; print('  PATCHED', p, '-', label)

def sub_once(old, new, marker=None):
    """Replace `old` with `new` once. Already applied if `marker` (default: new) is present."""
    def f(s):
        if (marker or new) in s: return s
        return s.replace(old, new, 1) if old in s else None
    return f

def balance_check(paths):
    bad = 0
    for p in paths:
        if not os.path.exists(path(p)): continue
        t = open(path(p), encoding='utf-8').read()
        t = re.sub(r"//[^\n]*", '', t)
        t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
        t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
        for a, b in ('{}', '()', '[]'):
            if t.count(a) != t.count(b):
                bad += 1
                print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
    print('  all balanced' if not bad else '  !! fix the files above before building')

print('== v58 ==')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/core/fasting_calendar.dart
# ───────────────────────────────────────────────────────────
write('lib/core/fasting_calendar.dart', r'''// fasting_calendar.dart — HalalCalorie v56 (PATCH_V56_FASTING_CALENDAR)
// Recommended (sunnah) fasting days, derived from the tabular Hijri calendar.
// The tabular calendar can differ from a local moon sighting by about a day, so
// every screen that shows these dates says so.
import 'hijri.dart';

enum FastKind { arafah, ashura, tasua, whiteDay, shawwal, monday, thursday }

class FastDay {
  final DateTime date;
  final FastKind kind;
  final List<FastKind> also;
  final HijriDate hijri;
  const FastDay(this.date, this.kind, this.also, this.hijri);
}

class FastingCalendar {
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Days on which fasting is not allowed (the two Eids and the days of Tashreeq).
  static bool _forbidden(HijriDate h) =>
      (h.month == 10 && h.day == 1) ||
      (h.month == 12 && h.day >= 10 && h.day <= 13);

  /// Reasons to fast on [d], strongest first. Empty during Ramadan (the fast is
  /// obligatory then) and on the days when fasting is not permitted.
  static List<FastKind> kindsFor(DateTime d, HijriDate h) {
    if (h.month == HijriDate.ramadanMonth || _forbidden(h)) return const [];
    final k = <FastKind>[];
    if (h.month == 12 && h.day == 9) k.add(FastKind.arafah);
    if (h.month == 1 && h.day == 10) k.add(FastKind.ashura);
    if (h.month == 1 && h.day == 9) k.add(FastKind.tasua);
    if (h.day >= 13 && h.day <= 15) k.add(FastKind.whiteDay);
    if (h.month == 10 && h.day >= 2 && h.day <= 7) k.add(FastKind.shawwal);
    if (d.weekday == DateTime.monday) k.add(FastKind.monday);
    if (d.weekday == DateTime.thursday) k.add(FastKind.thursday);
    return k;
  }

  static bool isSunnahFast(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return kindsFor(day, HijriDate.fromGregorian(day)).isNotEmpty;
  }

  static List<FastDay> upcoming({required DateTime from, int days = 60}) {
    final out = <FastDay>[];
    final start = DateTime(from.year, from.month, from.day);
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final h = HijriDate.fromGregorian(d);
      final k = kindsFor(d, h);
      if (k.isEmpty) continue;
      out.add(FastDay(d, k.first, k.sublist(1), h));
    }
    return out;
  }

  static String titleAr(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'صيام يوم عرفة';
      case FastKind.ashura:
        return 'صيام يوم عاشوراء';
      case FastKind.tasua:
        return 'صيام تاسوعاء';
      case FastKind.whiteDay:
        return 'صيام الأيام البيض';
      case FastKind.shawwal:
        return 'ستٌّ من شوال';
      case FastKind.monday:
        return 'صيام يوم الاثنين';
      case FastKind.thursday:
        return 'صيام يوم الخميس';
    }
  }

  static String titleEn(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'Fast of Arafah';
      case FastKind.ashura:
        return 'Fast of Ashura';
      case FastKind.tasua:
        return 'Fast of Tasu\u2019a';
      case FastKind.whiteDay:
        return 'White Days fast';
      case FastKind.shawwal:
        return 'Six days of Shawwal';
      case FastKind.monday:
        return 'Monday fast';
      case FastKind.thursday:
        return 'Thursday fast';
    }
  }

  static String noteAr(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'يُستحب لغير الحاج، وثوابه عظيم';
      case FastKind.ashura:
        return 'يُكفّر سنة ماضية — ويُستحب صيام يوم قبله أو بعده';
      case FastKind.tasua:
        return 'يوم قبل عاشوراء، يُستحب ضمّه إليه';
      case FastKind.whiteDay:
        return 'الثالث عشر والرابع عشر والخامس عشر من كل شهر هجري';
      case FastKind.shawwal:
        return 'إتباع رمضان بست من شوال كصيام الدهر';
      case FastKind.monday:
        return 'تُعرض الأعمال يوم الاثنين فيُستحب أن تكون صائمًا';
      case FastKind.thursday:
        return 'تُعرض الأعمال يوم الخميس فيُستحب أن تكون صائمًا';
    }
  }

  static String noteEn(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'Recommended for those not on Hajj, with great reward';
      case FastKind.ashura:
        return 'Expiates the previous year; fast a day before or after it too';
      case FastKind.tasua:
        return 'The day before Ashura, recommended alongside it';
      case FastKind.whiteDay:
        return 'The 13th, 14th and 15th of each Hijri month';
      case FastKind.shawwal:
        return 'Following Ramadan with six days of Shawwal';
      case FastKind.monday:
        return 'Deeds are presented on Mondays \u2014 a good day to be fasting';
      case FastKind.thursday:
        return 'Deeds are presented on Thursdays \u2014 a good day to be fasting';
    }
  }
}
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/core/notification_service.dart
# ───────────────────────────────────────────────────────────
write('lib/core/notification_service.dart', r'''// notification_service.dart — HalalCalorie v56 (PATCH_V56_NOTIFICATIONS)
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
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/features/premium/premium_ui.dart
# ───────────────────────────────────────────────────────────
write('lib/features/premium/premium_ui.dart', r'''// premium_ui.dart — HalalCalorie v56 (PATCH_V56_PREMIUM_UI)
// Small shared widgets for the Premium Studio screens.
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

const Color kGold = Color(0xFFDBA75D);
const Color kGoldLight = Color(0xFFF0CF98);

class PTheme {
  final bool isDark;
  const PTheme(this.isDark);
  Color get bg => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get card => isDark ? AppColors.darkCard : Colors.white;
  Color get cardAlt => isDark ? AppColors.darkCardAlt : AppColors.lightCardAlt;
  Color get text => isDark ? AppColors.darkText : AppColors.lightText;
  Color get muted => isDark ? AppColors.darkMuted : AppColors.lightMuted;
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
}

TextStyle pText(Color c, double size, {FontWeight w = FontWeight.w600, double? h}) =>
    TextStyle(fontFamily: 'Aligarh', fontSize: size, fontWeight: w, color: c, height: h);

class PCard extends StatelessWidget {
  final Widget child;
  final PTheme th;
  final bool gold;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const PCard({
    super.key,
    required this.child,
    required this.th,
    this.gold = false,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gold ? null : th.card,
        gradient: gold
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kGold.withOpacity(th.isDark ? 0.22 : 0.20),
                  kGold.withOpacity(th.isDark ? 0.06 : 0.07),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: gold ? kGold.withOpacity(0.45) : th.border, width: 0.8),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class PSection extends StatelessWidget {
  final String label;
  final PTheme th;
  const PSection(this.label, this.th, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
                color: kGold, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Text(label, style: pText(th.muted, 12, w: FontWeight.w800)),
        ]),
      );
}

class PGoldButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool outlined;
  const PGoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? kGold : const Color(0xFF1A0F00);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: outlined
                ? null
                : const LinearGradient(colors: [kGoldLight, kGold]),
            border: outlined ? Border.all(color: kGold, width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: pText(fg, 14, w: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const PPill(this.text, this.color, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 0.7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(text, style: pText(color, 11, w: FontWeight.w800)),
        ]),
      );
}

/// Shows [child] blurred behind a lock when [locked]. Tapping the lock calls
/// [onUnlock]. The content underneath is the person's own data, which is the
/// most honest preview of what Premium adds.
class PLocked extends StatelessWidget {
  final bool locked;
  final Widget child;
  final VoidCallback onUnlock;
  final String label;
  final PTheme th;
  const PLocked({
    super.key,
    required this.locked,
    required this.child,
    required this.onUnlock,
    required this.label,
    required this.th,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(children: [
      IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Opacity(opacity: 0.55, child: child),
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onUnlock,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: th.card.withOpacity(0.92),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: kGold, width: 1),
                boxShadow: [
                  BoxShadow(
                      color: kGold.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded, size: 16, color: kGold),
                const SizedBox(width: 8),
                Text(label, style: pText(kGold, 13, w: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

void openPaywall(BuildContext context) => context.push('/paywall');

/// Round gold icon badge used on the hub tiles and headers.
class PBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  const PBadge(this.icon, {super.key, this.size = 44, this.color = kGold});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.30), color.withOpacity(0.08)],
          ),
          border: Border.all(color: color.withOpacity(0.4), width: 0.7),
        ),
        child: Icon(icon, size: size * 0.5, color: color),
      );
}
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/features/premium/notification_center_screen.dart
# ───────────────────────────────────────────────────────────
write('lib/features/premium/notification_center_screen.dart', r'''// notification_center_screen.dart — HalalCalorie v56 (PATCH_V56_NOTIF_CENTER)
// One place to see whether notifications really work, fix them, test them and
// tune every reminder. Basic reminders are free; the smart ones are Premium.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/l10n.dart';
import '../../core/notification_service.dart';
import '../../core/prayer_provider.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  ConsumerState<NotificationCenterScreen> createState() => _NCState();
}

class _NCState extends ConsumerState<NotificationCenterScreen>
    with WidgetsBindingObserver {
  NotifStatus? _status;
  final Map<String, bool> _on = {};
  final Map<String, int> _times = {};
  String? _note;

  static const Map<String, bool> _boolDefaults = {
    'notif_water': true,
    'notif_meals': true,
    'notif_workout': false,
    'notif_ascent': true,
    'notif_streak': true,
    'notif_weekly': true,
    'notif_sunnah': true,
    'notif_suhoor': true,
    'notif_iftar': true,
  };
  static const Map<String, int> _timeDefaults = {
    'time_breakfast': 450,
    'time_lunch': 780,
    'time_dinner': 1170,
    'time_workout': 1050,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the system settings page: re-read the real state.
    if (state == AppLifecycleState.resumed) _refreshStatus();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = await NotificationService.status();
    if (!mounted) return;
    setState(() {
      _status = s;
      for (final e in _boolDefaults.entries) {
        _on[e.key] = p.getBool(e.key) ?? e.value;
      }
      for (final e in _timeDefaults.entries) {
        _times[e.key] = p.getInt(e.key) ?? e.value;
      }
    });
  }

  Future<void> _refreshStatus() async {
    final s = await NotificationService.status();
    if (mounted) setState(() => _status = s);
  }

  Future<void> _apply() async {
    try {
      await NotificationService.rescheduleAll();
      final times = await ref
          .read(prayerTimesProvider.future)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      await NotificationService.refreshSmart(
          times: times, ramadan: ref.read(ramadanModeProvider));
    } catch (_) {}
    await _refreshStatus();
  }

  Future<void> _setBool(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
    if (mounted) setState(() => _on[key] = v);
    await _apply();
  }

  Future<void> _pickTime(String key) async {
    final cur = _times[key] ?? _timeDefaults[key] ?? 480;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (picked == null) return;
    final p = await SharedPreferences.getInstance();
    final m = picked.hour * 60 + picked.minute;
    await p.setInt(key, m);
    if (mounted) setState(() => _times[key] = m);
    await _apply();
  }

  Future<void> _toggleMaster(bool v) async {
    final cur = ref.read(notificationsEnabledProvider);
    if (cur != v) await ref.read(notificationsEnabledProvider.notifier).toggle();
    try {
      if (v) {
        await NotificationService.requestPermissions();
        await _apply();
      } else {
        await NotificationService.cancelAll();
        await _refreshStatus();
      }
    } catch (_) {}
  }

  Future<void> _allow() async {
    final ok = await NotificationService.requestPermissions();
    if (!ok) {
      // Android stops showing the prompt after a refusal; only the system
      // settings page can turn notifications back on.
      await NotificationService.openSystemSettings();
    } else {
      await _apply();
    }
    await _refreshStatus();
  }

  String _fmt(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60).format(context);

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final master = ref.watch(notificationsEnabledProvider);
    final th = PTheme(isDark);
    String t(String ar, String en) => tLang(lang, ar, en);
    final st = _status;
    final blocked = st != null && !st.enabled;

    Widget toggleRow({
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required String key,
      bool premiumOnly = false,
      bool last = false,
    }) {
      final locked = premiumOnly && !premium;
      final value = (_on[key] ?? _boolDefaults[key] ?? false) && !locked;
      return InkWell(
        onTap: locked ? () => openPaywall(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            PBadge(icon, size: 40, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                        child: Text(title,
                            style: pText(th.text, 14, w: FontWeight.w800))),
                    if (premiumOnly) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.workspace_premium_rounded,
                          size: 14, color: kGold),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.35)),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.lock_rounded, size: 18, color: kGold)
            else
              Switch(
                value: value && master,
                activeColor: AppColors.halalGreen,
                onChanged: master ? (v) => _setBool(key, v) : null,
              ),
          ]),
        ),
      );
    }

    Widget timeRow(String ar, String en, String key) {
      final m = _times[key] ?? _timeDefaults[key] ?? 480;
      return InkWell(
        onTap: () => premium ? _pickTime(key) : openPaywall(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(children: [
            const Icon(Icons.schedule_rounded, size: 18, color: kGold),
            const SizedBox(width: 12),
            Expanded(
                child: Text(t(ar, en),
                    style: pText(th.text, 13.5, w: FontWeight.w700))),
            Text(premium ? _fmt(m) : _fmt(_timeDefaults[key] ?? m),
                style: pText(premium ? kGold : th.muted, 14, w: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(premium ? Icons.edit_rounded : Icons.lock_rounded,
                size: 16, color: premium ? th.muted : kGold),
          ]),
        ),
      );
    }

    Widget divider() => Divider(height: 1, color: th.border);

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('مركز الإشعارات', 'Notification Center'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // ── Status ─────────────────────────────────────────
          PCard(
            th: th,
            gold: !blocked,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                PBadge(
                  blocked
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_rounded,
                  size: 48,
                  color: blocked ? AppColors.haramRed : AppColors.halalGreen,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        st == null
                            ? t('جارٍ الفحص…', 'Checking…')
                            : blocked
                                ? t('الإشعارات محظورة من النظام',
                                    'Blocked by the system')
                                : !master
                                    ? t('التذكيرات متوقفة', 'Reminders paused')
                                    : t('الإشعارات تعمل', 'Notifications are on'),
                        style: pText(th.text, 17, w: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        st == null
                            ? ''
                            : blocked
                                ? t('اسمح بالإشعارات حتى تصلك التذكيرات',
                                    'Allow notifications so reminders can reach you')
                                : t('${st.pending} تذكير مجدول',
                                    '${st.pending} reminders scheduled'),
                        style: pText(th.muted, 12.5, w: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              if (blocked)
                PGoldButton(
                  label: t('السماح بالإشعارات', 'Allow notifications'),
                  icon: Icons.notifications_active_rounded,
                  onTap: _allow,
                )
              else
                Row(children: [
                  Expanded(
                    child: PGoldButton(
                      label: t('جرّب الآن', 'Test now'),
                      icon: Icons.bolt_rounded,
                      onTap: () async {
                        await NotificationService.sendTest();
                        if (mounted) {
                          setState(() => _note = t(
                              'أُرسل إشعار تجريبي. إن لم يظهر، افتح إعدادات النظام.',
                              'Test sent. If you did not see it, open system settings.'));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PGoldButton(
                      outlined: true,
                      label: t('بعد دقيقة', 'In 1 minute'),
                      icon: Icons.timer_rounded,
                      onTap: () async {
                        try {
                          await NotificationService.scheduleTestInOneMinute();
                          if (mounted) {
                            setState(() => _note = t(
                                'جُدول إشعار بعد دقيقة (قد يتأخر قليلًا في وضع توفير البطارية).',
                                'Scheduled for about a minute from now (battery saver may delay it a little).'));
                          }
                        } catch (e) {
                          if (mounted) setState(() => _note = '$e');
                        }
                        await _refreshStatus();
                      },
                    ),
                  ),
                ]),
              if (_note != null) ...[
                const SizedBox(height: 10),
                Text(_note!, style: pText(th.muted, 12, w: FontWeight.w500, h: 1.4)),
              ],
            ]),
          ),

          // ── Basic reminders ────────────────────────────────
          PSection(t('التذكيرات الأساسية', 'BASIC REMINDERS'), th),
          PCard(
            th: th,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                const PBadge(Icons.notifications_rounded,
                    size: 40, color: AppColors.doubtOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('تفعيل الإشعارات', 'Enable notifications'),
                          style: pText(th.text, 14, w: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                          t('المفتاح الرئيسي لكل التذكيرات',
                              'Master switch for every reminder'),
                          style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.35)),
                    ],
                  ),
                ),
                Switch(
                  value: master,
                  activeColor: AppColors.halalGreen,
                  onChanged: _toggleMaster,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          PCard(
            th: th,
            padding: EdgeInsets.zero,
            child: Column(children: [
              toggleRow(
                icon: Icons.water_drop_rounded,
                color: AppColors.waterBlue,
                title: t('تذكير الماء', 'Water'),
                subtitle: t('كل ساعتين من ٨ ص إلى ١٠ م', 'Every 2 hours, 8 am – 10 pm'),
                key: 'notif_water',
              ),
              divider(),
              toggleRow(
                icon: Icons.restaurant_rounded,
                color: AppColors.halalGreen,
                title: t('الوجبات', 'Meals'),
                subtitle: t('الفطور والغداء والعشاء', 'Breakfast, lunch and dinner'),
                key: 'notif_meals',
              ),
              divider(),
              toggleRow(
                icon: Icons.fitness_center_rounded,
                color: AppColors.sleepPurple,
                title: t('التمرين', 'Workout'),
                subtitle: t('تذكير يومي بالحركة', 'A daily nudge to move'),
                key: 'notif_workout',
              ),
              divider(),
              toggleRow(
                icon: Icons.terrain_rounded,
                color: kGold,
                title: t('مهام Ascent', 'Ascent quests'),
                subtitle: t('بعد العصر', 'Mid-afternoon'),
                key: 'notif_ascent',
                last: true,
              ),
            ]),
          ),

          // ── Premium smart reminders ────────────────────────
          PSection(t('تذكيرات ذكية — بريميوم', 'SMART REMINDERS — PREMIUM'), th),
          PCard(
            th: th,
            gold: true,
            padding: EdgeInsets.zero,
            child: Column(children: [
              toggleRow(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.haramRed,
                title: t('حارس السلسلة', 'Streak guard'),
                subtitle: t('٨:٣٠ م — فقط إن لم تسجّل وجبة اليوم',
                    '8:30 pm — only if you have not logged a meal today'),
                key: 'notif_streak',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.insights_rounded,
                color: AppColors.waterBlue,
                title: t('المراجعة الأسبوعية', 'Weekly review'),
                subtitle: t('الجمعة ٨ م — تقدّمك وتوقّع وزنك',
                    'Friday 8 pm — your trends and weight forecast'),
                key: 'notif_weekly',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.calendar_month_rounded,
                color: AppColors.sleepPurple,
                title: t('ليلة صيام السنّة', 'Sunnah-fast eve'),
                subtitle: t('الاثنين والخميس والأيام البيض وعرفة وعاشوراء',
                    'Mondays, Thursdays, White Days, Arafah, Ashura'),
                key: 'notif_sunnah',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.free_breakfast_rounded,
                color: kGold,
                title: t('السحور', 'Suhoor'),
                subtitle: t('قبل الفجر بـ ٤٥ دقيقة، بحسب مواقيت مدينتك',
                    '45 minutes before Fajr, using your city\u2019s prayer times'),
                key: 'notif_suhoor',
                premiumOnly: true,
              ),
              divider(),
              toggleRow(
                icon: Icons.nightlight_round,
                color: AppColors.halalGreen,
                title: t('الإفطار', 'Iftar'),
                subtitle: t('قبل المغرب بـ ١٠ دقائق', '10 minutes before Maghrib'),
                key: 'notif_iftar',
                premiumOnly: true,
                last: true,
              ),
            ]),
          ),

          // ── Custom times ───────────────────────────────────
          PSection(t('أوقات مخصصة — بريميوم', 'CUSTOM TIMES — PREMIUM'), th),
          PCard(
            th: th,
            padding: EdgeInsets.zero,
            child: Column(children: [
              timeRow('الفطور', 'Breakfast', 'time_breakfast'),
              divider(),
              timeRow('الغداء', 'Lunch', 'time_lunch'),
              divider(),
              timeRow('العشاء', 'Dinner', 'time_dinner'),
              divider(),
              timeRow('التمرين', 'Workout', 'time_workout'),
            ]),
          ),

          // ── Reliability tips ───────────────────────────────
          PSection(t('إن تأخرت التذكيرات', 'IF REMINDERS ARRIVE LATE'), th),
          PCard(
            th: th,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                t('بعض الهواتف توقف التطبيقات في الخلفية لتوفير البطارية. افتح: الإعدادات ← التطبيقات ← HalalCalorie ← البطارية، واختر «غير مقيّد».',
                    'Some phones put apps to sleep to save battery. Open Settings → Apps → HalalCalorie → Battery and choose “Unrestricted”.'),
                style: pText(th.muted, 12.5, w: FontWeight.w500, h: 1.55),
              ),
              const SizedBox(height: 12),
              PGoldButton(
                outlined: true,
                label: t('فتح إعدادات التطبيق', 'Open app settings'),
                icon: Icons.settings_rounded,
                onTap: NotificationService.openSystemSettings,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/features/premium/insights_screen.dart
# ───────────────────────────────────────────────────────────
write('lib/features/premium/insights_screen.dart', r'''// insights_screen.dart — HalalCalorie v56 (PATCH_V56_INSIGHTS)
// Insights Pro: trends, consistency, macro split, weekday pattern, heatmap,
// weight forecast and CSV export — all computed on-device from the local
// database. Free users get the 7-day basics; the rest is shown blurred over
// their own data so they can see exactly what Premium adds.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class _DayAgg {
  final String key;
  final int kcal;
  final double p, c, f;
  const _DayAgg(this.key, this.kcal, this.p, this.c, this.f);
}

class _WeightPt {
  final DateTime t;
  final double kg;
  const _WeightPt(this.t, this.kg);
}

class _InsightData {
  final List<_DayAgg> all; // up to 90 days of logged days
  final List<_WeightPt> weights;
  final double avgWater, avgSteps, avgSleep;
  final int workoutDays;
  const _InsightData(this.all, this.weights, this.avgWater, this.avgSteps,
      this.avgSleep, this.workoutDays);
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<_InsightData> _loadInsights(int rangeDays) async {
  final d = await AppDatabase.db;
  final now = DateTime.now();
  final since90 = _key(now.subtract(const Duration(days: 89)));
  final rows = await d.rawQuery(
    'SELECT date_key, SUM(kcal) AS k, SUM(protein_g) AS p, SUM(carbs_g) AS c, '
    'SUM(fat_g) AS f FROM meal_entries WHERE date_key >= ? '
    'GROUP BY date_key ORDER BY date_key ASC',
    [since90],
  );
  final all = rows
      .map((r) => _DayAgg(
            r['date_key'] as String,
            ((r['k'] as num?) ?? 0).round(),
            ((r['p'] as num?) ?? 0).toDouble(),
            ((r['c'] as num?) ?? 0).toDouble(),
            ((r['f'] as num?) ?? 0).toDouble(),
          ))
      .toList();

  final wRows = await d.query(
    'weight_log',
    where: 'created >= ?',
    whereArgs: [now.subtract(const Duration(days: 120)).toIso8601String()],
    orderBy: 'created ASC',
  );
  final weights = <_WeightPt>[];
  for (final r in wRows) {
    final t = DateTime.tryParse((r['created'] as String?) ?? '');
    final kg = (r['weight_kg'] as num?)?.toDouble();
    if (t != null && kg != null) weights.add(_WeightPt(t, kg));
  }

  final sinceR = _key(now.subtract(Duration(days: rangeDays - 1)));
  var w = 0.0, s = 0.0, sl = 0.0;
  try {
    final r = (await d.rawQuery(
      'SELECT AVG(water_cups) AS w, AVG(steps) AS s, AVG(sleep_hrs) AS sl '
      'FROM daily_summary WHERE date_key >= ? AND '
      '(water_cups > 0 OR steps > 0 OR sleep_hrs > 0)',
      [sinceR],
    ))
        .first;
    w = ((r['w'] as num?) ?? 0).toDouble();
    s = ((r['s'] as num?) ?? 0).toDouble();
    sl = ((r['sl'] as num?) ?? 0).toDouble();
  } catch (_) {}
  var wd = 0;
  try {
    final r = (await d.rawQuery(
      'SELECT COUNT(DISTINCT date_key) AS c FROM workout_log WHERE date_key >= ?',
      [sinceR],
    ))
        .first;
    wd = ((r['c'] as num?) ?? 0).toInt();
  } catch (_) {}
  return _InsightData(all, weights, w, s, sl, wd);
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsState();
}

class _InsightsState extends ConsumerState<InsightsScreen> {
  int _range = 7;
  late Future<_InsightData> _future = _loadInsights(_range);

  void _setRange(int r, bool premium) {
    if (r != 7 && !premium) {
      openPaywall(context);
      return;
    }
    setState(() {
      _range = r;
      _future = _loadInsights(r);
    });
  }

  Future<void> _export(bool isAr) async {
    final d = await AppDatabase.db;
    final since = _key(DateTime.now().subtract(const Duration(days: 89)));
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('HalalCalorie export (last 90 days)\n\n');
    b.writeln('date,meal,kcal,protein_g,carbs_g,fat_g');
    final meals = await d.query('meal_entries',
        where: 'date_key >= ?',
        whereArgs: [since],
        orderBy: 'date_key ASC, id ASC');
    for (final m in meals) {
      b.writeln('${m['date_key']},${esc('${m['name']}')},${m['kcal']},'
          '${m['protein_g']},${m['carbs_g']},${m['fat_g']}');
    }
    b.writeln('\ndate,weight_kg');
    final ws = await d.query('weight_log', orderBy: 'created ASC');
    for (final w in ws) {
      final t = DateTime.tryParse('${w['created']}');
      b.writeln('${t == null ? w['created'] : _key(t)},${w['weight_kg']}');
    }
    b.writeln('\ndate,workout,minutes');
    final wl = await d.query('workout_log',
        where: 'date_key >= ?', whereArgs: [since], orderBy: 'date_key ASC');
    for (final w in wl) {
      b.writeln('${w['date_key']},${esc('${w['workout_id']}')},${w['minutes']}');
    }
    try {
      await Share.share(b.toString());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final goal = ref.watch(caloriesProvider).goal;
    final profile = ref.watch(userProfileProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);
    void unlock() => openPaywall(context);

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('رؤى متقدمة', 'Insights Pro'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: FutureBuilder<_InsightData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: kGold));
          }
          if (!snap.hasData) {
            return Center(
              child: Text(t('تعذّر تحميل البيانات', 'Could not load your data'),
                  style: pText(th.muted, 14)),
            );
          }
          final data = snap.data!;
          final sinceKey =
              _key(DateTime.now().subtract(Duration(days: _range - 1)));
          final days = data.all.where((d) => d.key.compareTo(sinceKey) >= 0).toList();
          final logged = days.length;
          final avgKcal =
              logged == 0 ? 0 : days.fold<int>(0, (a, b) => a + b.kcal) ~/ logged;
          final onTarget = days
              .where((d) => (d.kcal - goal).abs() <= goal * 0.10)
              .length;
          final adherence = logged == 0 ? 0 : (onTarget * 100 / logged).round();
          final avgProtein =
              logged == 0 ? 0.0 : days.fold<double>(0, (a, b) => a + b.p) / logged;

          Widget tile(String label, String value, String sub, Color c) => Expanded(
                child: PCard(
                  th: th,
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: pText(th.muted, 11.5, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(value, style: pText(c, 24, w: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(sub, style: pText(th.muted, 11, w: FontWeight.w500)),
                  ]),
                ),
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              // Range chips
              Row(children: [
                for (final r in const [7, 30, 90]) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setRange(r, premium),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _range == r ? kGold : th.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _range == r ? kGold : th.border, width: 0.8),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(
                            t('$r يوم', '$r days'),
                            style: pText(
                                _range == r ? const Color(0xFF1A0F00) : th.text, 13,
                                w: FontWeight.w800),
                          ),
                          if (r != 7 && !premium) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.lock_rounded, size: 12, color: kGold),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 14),

              // Summary (first row free, second row premium)
              Row(children: [
                tile(t('متوسط السعرات', 'Avg calories'), '$avgKcal',
                    t('الهدف $goal', 'Goal $goal'), AppColors.halalGreen),
                const SizedBox(width: 10),
                tile(t('أيام التسجيل', 'Days logged'), '$logged/$_range',
                    t('في هذه الفترة', 'in this period'), AppColors.waterBlue),
              ]),
              const SizedBox(height: 10),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: Row(children: [
                  tile(t('الالتزام بالهدف', 'On-target days'), '$adherence%',
                      t('ضمن ±١٠٪ من الهدف', 'within ±10% of goal'), kGold),
                  const SizedBox(width: 10),
                  tile(t('متوسط البروتين', 'Avg protein'),
                      '${avgProtein.round()} g',
                      t('يوميًا', 'per day'), AppColors.sleepPurple),
                ]),
              ),

              // Calories chart (free: 7 days)
              PSection(t('السعرات اليومية', 'DAILY CALORIES'), th),
              PCard(
                th: th,
                child: _CalorieBars(
                    days: days, range: _range, goal: goal, th: th, isAr: isAr),
              ),

              // Macro split
              PSection(t('توزيع المغذيات', 'MACRO SPLIT'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(th: th, child: _MacroSplit(days: days, th: th, isAr: isAr)),
              ),

              // Weekday pattern
              PSection(t('نمط أيام الأسبوع', 'WEEKDAY PATTERN'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(
                    th: th,
                    child: _WeekdayPattern(
                        days: data.all, goal: goal, th: th, isAr: isAr)),
              ),

              // Heatmap
              PSection(t('خريطة الالتزام — ١٢ أسبوعًا', 'CONSISTENCY — 12 WEEKS'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(
                    th: th,
                    child: _Heatmap(days: data.all, goal: goal, th: th, isAr: isAr)),
              ),

              // Weight forecast
              PSection(t('توقّع الوزن', 'WEIGHT FORECAST'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(
                  th: th,
                  child: _WeightForecast(
                    pts: data.weights,
                    target: profile?.targetWeightKg ?? profile?.idealWeightKg,
                    th: th,
                    isAr: isAr,
                  ),
                ),
              ),

              // Habits
              PSection(t('عاداتك', 'HABITS'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: Row(children: [
                  tile(t('ماء', 'Water'), data.avgWater.toStringAsFixed(1),
                      t('كوب/يوم', 'cups/day'), AppColors.waterBlue),
                  const SizedBox(width: 10),
                  tile(t('خطوات', 'Steps'), '${data.avgSteps.round()}',
                      t('يوميًا', 'per day'), AppColors.halalGreen),
                  const SizedBox(width: 10),
                  tile(t('تمارين', 'Workouts'), '${data.workoutDays}',
                      t('أيام', 'days'), AppColors.sleepPurple),
                ]),
              ),

              // Export
              const SizedBox(height: 22),
              PGoldButton(
                label: t('تصدير بياناتي (CSV)', 'Export my data (CSV)'),
                icon: Icons.ios_share_rounded,
                onTap: premium ? () => _export(isAr) : unlock,
              ),
              const SizedBox(height: 8),
              Text(
                t('للمشاركة مع أخصائي التغذية أو الطبيب. تُحسب كل الأرقام على جهازك.',
                    'Handy for a dietitian or doctor. Every number is computed on your device.'),
                textAlign: TextAlign.center,
                style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Charts (hand-drawn, no chart package needed) ─────────────────────────

class _CalorieBars extends StatelessWidget {
  final List<_DayAgg> days;
  final int range, goal;
  final PTheme th;
  final bool isAr;
  const _CalorieBars({
    required this.days,
    required this.range,
    required this.goal,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    // Up to 30 daily bars; 90 days collapses into weekly averages.
    final byKey = {for (final d in days) d.key: d.kcal};
    final now = DateTime.now();
    final values = <double>[];
    final labels = <String>[];
    if (range <= 30) {
      for (var i = range - 1; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        values.add((byKey[_key(d)] ?? 0).toDouble());
        labels.add(range <= 7 ? '${d.day}' : (i % 5 == 0 ? '${d.day}' : ''));
      }
    } else {
      for (var w = 12; w >= 0; w--) {
        var sum = 0, n = 0;
        for (var i = 0; i < 7; i++) {
          final d = now.subtract(Duration(days: w * 7 + i));
          final v = byKey[_key(d)];
          if (v != null) {
            sum += v;
            n++;
          }
        }
        values.add(n == 0 ? 0 : sum / n);
        labels.add(w % 3 == 0 ? '${w}w' : '');
      }
    }
    final maxV = math.max(
        goal * 1.25, values.isEmpty ? 0.0 : values.reduce(math.max) * 1.05);
    const h = 130.0;
    return Column(children: [
      SizedBox(
        height: h,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: h - (goal / maxV) * h,
            child: Row(children: [
              for (var i = 0; i < 40; i++)
                Expanded(
                  child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      color: kGold.withOpacity(i.isEven ? 0.8 : 0.0)),
                ),
            ]),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final v in values)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: v <= 0 ? 3 : (v / maxV) * h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: v <= 0
                            ? th.border
                            : ((v - goal).abs() <= goal * 0.10
                                ? AppColors.halalGreen
                                : (v > goal ? AppColors.doubtOrange : AppColors.waterBlue)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (final l in labels)
          Expanded(
              child: Text(l,
                  textAlign: TextAlign.center,
                  style: pText(th.muted, 10, w: FontWeight.w600))),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 6, children: [
        _legend(AppColors.halalGreen, isAr ? 'ضمن الهدف' : 'On target'),
        _legend(AppColors.doubtOrange, isAr ? 'فوق الهدف' : 'Over'),
        _legend(AppColors.waterBlue, isAr ? 'تحت الهدف' : 'Under'),
        _legend(kGold, isAr ? 'الهدف' : 'Goal'),
      ]),
    ]);
  }

  Widget _legend(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(s, style: pText(th.muted, 10.5, w: FontWeight.w600)),
      ]);
}

class _MacroSplit extends StatelessWidget {
  final List<_DayAgg> days;
  final PTheme th;
  final bool isAr;
  const _MacroSplit({required this.days, required this.th, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final p = days.fold<double>(0, (a, b) => a + b.p) * 4;
    final c = days.fold<double>(0, (a, b) => a + b.c) * 4;
    final f = days.fold<double>(0, (a, b) => a + b.f) * 9;
    final total = p + c + f;
    if (total <= 0) {
      return Text(isAr ? 'سجّل وجبات لترى التوزيع' : 'Log meals to see your split',
          style: pText(th.muted, 13));
    }
    int pct(double v) => (v * 100 / total).round();
    Widget seg(double v, Color col) => Expanded(
          flex: math.max(1, (v * 1000 / total).round()),
          child: Container(height: 16, color: col),
        );
    Widget keyCol(String label, double v, Color col) => Expanded(
          child: Column(children: [
            Text('${pct(v)}%', style: pText(col, 20, w: FontWeight.w900)),
            Text(label, style: pText(th.muted, 11.5, w: FontWeight.w700)),
          ]),
        );
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          seg(p, AppColors.halalGreen),
          seg(c, AppColors.waterBlue),
          seg(f, AppColors.doubtOrange),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        keyCol(isAr ? 'بروتين' : 'Protein', p, AppColors.halalGreen),
        keyCol(isAr ? 'كربوهيدرات' : 'Carbs', c, AppColors.waterBlue),
        keyCol(isAr ? 'دهون' : 'Fat', f, AppColors.doubtOrange),
      ]),
    ]);
  }
}

class _WeekdayPattern extends StatelessWidget {
  final List<_DayAgg> days;
  final int goal;
  final PTheme th;
  final bool isAr;
  const _WeekdayPattern({
    required this.days,
    required this.goal,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (final d in days) {
      final t = DateTime.tryParse(d.key);
      if (t == null) continue;
      sums[t.weekday - 1] += d.kcal;
      counts[t.weekday - 1]++;
    }
    final avgs = [
      for (var i = 0; i < 7; i++) counts[i] == 0 ? 0.0 : sums[i] / counts[i]
    ];
    final maxV = math.max(goal * 1.25, avgs.reduce(math.max) * 1.05);
    final names = isAr
        ? const ['اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    var hi = 0;
    for (var i = 1; i < 7; i++) {
      if (avgs[i] > avgs[hi]) hi = i;
    }
    const h = 90.0;
    return Column(children: [
      SizedBox(
        height: h,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: avgs[i] <= 0 ? 3 : (avgs[i] / maxV) * h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: i == hi && avgs[i] > 0 ? kGold : AppColors.halalGreen.withOpacity(0.75),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (final n in names)
          Expanded(
              child: Text(n,
                  textAlign: TextAlign.center,
                  style: pText(th.muted, 10.5, w: FontWeight.w700))),
      ]),
      const SizedBox(height: 10),
      Text(
        avgs[hi] <= 0
            ? (isAr ? 'سجّل أكثر لنرى نمطك' : 'Log a bit more to reveal your pattern')
            : (isAr
                ? 'أعلى استهلاك لك يوم ${names[hi]} (${avgs[hi].round()} سعر)'
                : 'You eat the most on ${names[hi]} (${avgs[hi].round()} kcal avg)'),
        textAlign: TextAlign.center,
        style: pText(th.text, 12.5, w: FontWeight.w700),
      ),
    ]);
  }
}

class _Heatmap extends StatelessWidget {
  final List<_DayAgg> days;
  final int goal;
  final PTheme th;
  final bool isAr;
  const _Heatmap({
    required this.days,
    required this.goal,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final d in days) d.key: d.kcal};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 12 columns of weeks, the last column ends on today's weekday.
    const weeks = 12;
    final lastWeekStart = today.subtract(Duration(days: today.weekday - 1));
    var loggedDays = 0;
    final cols = <Widget>[];
    for (var w = weeks - 1; w >= 0; w--) {
      final start = lastWeekStart.subtract(Duration(days: w * 7));
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        final v = d.isAfter(today) ? null : byKey[_key(d)];
        if (v != null) loggedDays++;
        Color c;
        if (d.isAfter(today)) {
          c = Colors.transparent;
        } else if (v == null) {
          c = th.border;
        } else {
          final double r = (v / goal).clamp(0.0, 1.0).toDouble();
          c = AppColors.halalGreen.withOpacity(0.25 + r * 0.7);
        }
        cells.add(Container(
          margin: const EdgeInsets.all(2),
          height: 18,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
        ));
      }
      cols.add(Expanded(child: Column(children: cells)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: cols),
      const SizedBox(height: 8),
      Text(
        isAr ? 'سجّلت $loggedDays يومًا خلال ١٢ أسبوعًا' : 'You logged $loggedDays days in 12 weeks',
        style: pText(th.muted, 12, w: FontWeight.w600),
      ),
    ]);
  }
}

class _WeightForecast extends StatelessWidget {
  final List<_WeightPt> pts;
  final double? target;
  final PTheme th;
  final bool isAr;
  const _WeightForecast({
    required this.pts,
    required this.target,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    if (pts.length < 3) {
      return Text(
        isAr
            ? 'سجّل وزنك ٣ مرات على الأقل (في الصحة ← الجسم) لنرسم اتجاهك ونتوقّع موعد هدفك.'
            : 'Log your weight at least 3 times (Health → Body) and we will chart your trend and forecast your goal date.',
        style: pText(th.muted, 13, w: FontWeight.w600, h: 1.5),
      );
    }
    final first = pts.first.t;
    final xs = [for (final p in pts) p.t.difference(first).inHours / 24.0];
    final ys = [for (final p in pts) p.kg];
    final n = pts.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var cov = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      cov += (xs[i] - mx) * (ys[i] - my);
      den += (xs[i] - mx) * (xs[i] - mx);
    }
    final slope = den == 0 ? 0.0 : cov / den; // kg per day
    final perWeek = slope * 7;
    final current = ys.last;
    final spanDays = xs.last - xs.first;

    String line;
    if (spanDays < 5 || slope.abs() < 0.004) {
      line = isAr
          ? 'وزنك مستقر تقريبًا (${current.toStringAsFixed(1)} كجم).'
          : 'Your weight is steady at about ${current.toStringAsFixed(1)} kg.';
    } else {
      final dir = perWeek < 0 ? (isAr ? 'تخسر' : 'losing') : (isAr ? 'تزيد' : 'gaining');
      line = isAr
          ? 'وتيرتك: $dir ${perWeek.abs().toStringAsFixed(2)} كجم أسبوعيًا.'
          : 'Your pace: $dir ${perWeek.abs().toStringAsFixed(2)} kg per week.';
      final tg = target;
      if (tg != null) {
        final toGo = tg - current;
        final goingRight = (toGo < 0 && slope < 0) || (toGo > 0 && slope > 0);
        if (goingRight) {
          final daysLeft = (toGo / slope).round();
          if (daysLeft >= 1 && daysLeft <= 730) {
            final date = DateTime.now().add(Duration(days: daysLeft));
            line += isAr
                ? '\nبهذا المعدل تصل إلى ${tg.toStringAsFixed(1)} كجم تقريبًا في ${date.day}/${date.month}/${date.year}.'
                : '\nAt this rate you reach ${tg.toStringAsFixed(1)} kg around ${date.day}/${date.month}/${date.year}.';
          }
        } else if (toGo.abs() > 0.5) {
          line += isAr
              ? '\nالاتجاه الحالي بعيد عن هدفك (${tg.toStringAsFixed(1)} كجم).'
              : '\nThe current trend is heading away from your ${tg.toStringAsFixed(1)} kg goal.';
        }
      }
      if (perWeek < -1.0) {
        line += isAr
            ? '\nهذه وتيرة سريعة — الأفضل غالبًا بين ٠٫٢٥ و١ كجم أسبوعيًا.'
            : '\nThat is quick — roughly 0.25–1 kg a week is the usual guidance.';
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 110,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(ys, target, AppColors.halalGreen, th.border),
        ),
      ),
      const SizedBox(height: 10),
      Text(line, style: pText(th.text, 13, w: FontWeight.w700, h: 1.5)),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<double> ys;
  final double? target;
  final Color color;
  final Color grid;
  _LinePainter(this.ys, this.target, this.color, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    if (ys.length < 2) return;
    var lo = ys.reduce(math.min);
    var hi = ys.reduce(math.max);
    final tg = target;
    if (tg != null && (tg - lo).abs() < 15 && (tg - hi).abs() < 15) {
      lo = math.min(lo, tg);
      hi = math.max(hi, tg);
    }
    if (hi - lo < 1) {
      hi += 0.5;
      lo -= 0.5;
    }
    double yOf(double v) => size.height - ((v - lo) / (hi - lo)) * (size.height - 12) - 6;
    double xOf(int i) => (i / (ys.length - 1)) * size.width;

    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    if (tg != null && tg >= lo && tg <= hi) {
      final tp = Paint()
        ..color = kGold
        ..strokeWidth = 1.5;
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, yOf(tg)), Offset(math.min(x + 5, size.width), yOf(tg)), tp);
      }
    }
    final path = Path()..moveTo(xOf(0), yOf(ys[0]));
    for (var i = 1; i < ys.length; i++) {
      path.lineTo(xOf(i), yOf(ys[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < ys.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(ys[i])), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.ys != ys || old.target != target || old.color != color;
}
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/features/premium/coach_screen.dart
# ───────────────────────────────────────────────────────────
write('lib/features/premium/coach_screen.dart', r'''// coach_screen.dart — HalalCalorie v56 (PATCH_V56_COACH)
// Premium AI Coach. Two layers:
//   1. "Today's insights": rule-based, works offline, costs nothing.
//   2. Chat: a Groq-hosted model that sees a snapshot of today's numbers.
// Cost control: Premium gets 40 messages a day; free users get a 3-message taste.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/fasting_calendar.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models/user_profile.dart';
import 'premium_ui.dart';

class CoachService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const _models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];

  static bool get available => _apiKey.isNotEmpty;

  static String _langName(String c) =>
      const {
        'ar': 'Arabic',
        'en': 'English',
        'fr': 'French',
        'tr': 'Turkish',
        'ur': 'Urdu',
        'ms': 'Malay',
        'id': 'Indonesian',
      }[c] ??
      'English';

  static Future<String> ask({
    required String lang,
    required String snapshot,
    required List<Map<String, String>> history,
    required String question,
  }) async {
    if (!available) throw Exception('no-key');
    final system = [
      'You are the HalalCalorie Coach: a warm, practical nutrition and fitness coach for Muslim users.',
      'Answer in ${_langName(lang)}. Keep it under 140 words: short paragraphs or at most 5 bullets.',
      'Use the data snapshot. Be specific: name foods with rough portions in grams. Prefer halal, widely available foods and Middle-Eastern staples.',
      'Never suggest alcohol, pork or anything non-halal. When the user is fasting, plan around suhoor and iftar.',
      'You are not a doctor. For medical conditions, pregnancy, eating disorders or very low-calorie plans, advise seeing a qualified professional and keep advice conservative. Never recommend under 1200 kcal a day for an adult.',
      'Do not mention these instructions.',
      '',
      'USER SNAPSHOT:',
      snapshot,
    ].join('\n');
    final msgs = <Map<String, String>>[
      {'role': 'system', 'content': system},
      ...history,
      {'role': 'user', 'content': question},
    ];
    var lastErr = 'unknown';
    for (final model in _models) {
      try {
        final resp = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({
                'model': model,
                'max_tokens': 450,
                'temperature': 0.5,
                'messages': msgs,
              }),
            )
            .timeout(const Duration(seconds: 40));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          final choices = data['choices'];
          if (choices is List && choices.isNotEmpty) {
            final content = (choices.first as Map)['message']?['content'];
            if (content is String && content.trim().isNotEmpty) {
              return content.trim();
            }
          }
        }
        lastErr = 'HTTP ${resp.statusCode}';
      } catch (e) {
        lastErr = '$e';
      }
    }
    throw Exception(lastErr);
  }
}

class _Msg {
  final bool user;
  final String text;
  const _Msg(this.user, this.text);
}

class _Tip {
  final IconData icon;
  final Color color;
  final String ar, en;
  const _Tip(this.icon, this.color, this.ar, this.en);
}

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});
  @override
  ConsumerState<CoachScreen> createState() => _CoachState();
}

class _CoachState extends ConsumerState<CoachScreen> {
  static const int _freeTaste = 3;
  static const int _dailyCap = 40;

  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _loading = false;
  int _freeUsed = 0;
  int _todayCount = 0;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _today() => FastingCalendar.dateKey(DateTime.now());

  Future<void> _loadQuota() async {
    final p = await SharedPreferences.getInstance();
    final sameDay = p.getString('coach_day') == _today();
    if (!mounted) return;
    setState(() {
      _freeUsed = p.getInt('coach_free_used') ?? 0;
      _todayCount = sameDay ? (p.getInt('coach_day_count') ?? 0) : 0;
    });
  }

  Future<void> _bumpQuota(bool premium) async {
    final p = await SharedPreferences.getInstance();
    if (premium) {
      _todayCount += 1;
      await p.setString('coach_day', _today());
      await p.setInt('coach_day_count', _todayCount);
    } else {
      _freeUsed += 1;
      await p.setInt('coach_free_used', _freeUsed);
    }
    if (mounted) setState(() {});
  }

  String _snapshot() {
    final cal = ref.read(caloriesProvider);
    final water = ref.read(waterProvider);
    final health = ref.read(healthProvider);
    final profile = ref.read(userProfileProvider);
    final ramadan = ref.read(ramadanModeProvider);
    final b = StringBuffer();
    b.writeln('Calorie goal: ${cal.goal} kcal; eaten so far: ${cal.total} kcal.');
    b.writeln(
        'Protein ${cal.proteinTotal.round()} g, carbs ${cal.carbsTotal.round()} g, fat ${cal.fatTotal.round()} g eaten today.');
    if (cal.entries.isNotEmpty) {
      b.writeln('Meals today: ${cal.entries.map((e) => '${e.name} (${e.kcal})').join(', ')}.');
    }
    b.writeln('Water: ${water.cups}/${water.goal} cups. Steps: ${health.steps}/${health.stepsGoal}.');
    if (profile != null) {
      b.writeln(
          'Profile: ${profile.gender == 'sisters' ? 'female' : 'male'}, age ${profile.age}, ${profile.weightKg.round()} kg, ${profile.heightCm.round()} cm.');
      b.writeln('Goal: ${profile.primaryGoal.nameEn()}. Diet: ${profile.dietPreference.nameEn()}.');
      b.writeln(
          'Protein target ${profile.proteinGrams.round()} g, carbs ${profile.carbsGrams.round()} g, fat ${profile.fatGrams.round()} g.');
      final conds = profile.healthConditions.map((c) => c.nameEn()).where((n) => n != 'None').toList();
      if (conds.isNotEmpty) b.writeln('Health conditions: ${conds.join(', ')}.');
    }
    if (ramadan) b.writeln('Ramadan mode is on (the user is fasting).');
    if (FastingCalendar.isSunnahFast(DateTime.now())) {
      b.writeln('Today is a recommended sunnah fasting day.');
    }
    b.writeln('Local time: ${DateTime.now().hour}:00.');
    return b.toString();
  }

  List<_Tip> _localTips() {
    final cal = ref.read(caloriesProvider);
    final water = ref.read(waterProvider);
    final health = ref.read(healthProvider);
    final profile = ref.read(userProfileProvider);
    final hour = DateTime.now().hour;
    final tips = <_Tip>[];

    final proteinTarget = profile?.proteinGrams ?? (cal.goal * 0.30 / 4);
    final proteinGap = proteinTarget - cal.proteinTotal;
    if (cal.entries.isEmpty && hour >= 6) {
      tips.add(const _Tip(
          Icons.wb_sunny_rounded,
          AppColors.accentGold,
          'لم تسجّل شيئًا بعد. ابدأ بوجبة غنية بالبروتين: بيضتان أو زبادي يوناني مع الشوفان.',
          'Nothing logged yet. Start with a protein-rich meal: two eggs, or Greek yogurt with oats.'));
    } else if (cal.total > cal.goal * 1.10) {
      tips.add(_Tip(
          Icons.trending_up_rounded,
          AppColors.doubtOrange,
          'تجاوزت هدفك بـ ${cal.total - cal.goal} سعرًا. اجعل وجبتك القادمة خفيفة: شوربة وسلطة وبروتين مشوي.',
          "You're ${cal.total - cal.goal} kcal over goal. Keep the next meal light: soup, salad and grilled protein."));
    } else if (cal.remaining > 0 && cal.entries.isNotEmpty) {
      tips.add(_Tip(
          Icons.restaurant_rounded,
          AppColors.halalGreen,
          'متبقٍّ لك ${cal.remaining} سعرًا اليوم. وزّعها على وجبة رئيسية ووجبة خفيفة.',
          'You have ${cal.remaining} kcal left today. Split it between one main meal and a snack.'));
    }
    if (hour >= 13 && proteinGap > 25) {
      tips.add(_Tip(
          Icons.egg_alt_rounded,
          AppColors.sleepPurple,
          'ينقصك نحو ${proteinGap.round()} غ بروتين. خيارات: ١٠٠ غ صدر دجاج (٣١ غ)، ١٥٠ غ زبادي يوناني (١٥ غ)، بيضتان (١٢ غ).',
          'About ${proteinGap.round()} g of protein short. Try 100 g chicken breast (31 g), 150 g Greek yogurt (15 g) or two eggs (12 g).'));
    }
    if (hour >= 14 && water.cups < water.goal * 0.5) {
      tips.add(_Tip(
          Icons.water_drop_rounded,
          AppColors.waterBlue,
          'شربت ${water.cups} من ${water.goal} أكواب. اشرب كوبًا الآن وآخر قبل المغرب.',
          "You've had ${water.cups} of ${water.goal} cups. Drink one now and another before Maghrib."));
    }
    if (hour >= 17 && health.steps < health.stepsGoal * 0.6) {
      tips.add(_Tip(
          Icons.directions_walk_rounded,
          AppColors.halalGreen,
          'خطواتك ${health.steps} من ${health.stepsGoal}. مشي ١٥ دقيقة بعد الصلاة يسدّ جزءًا كبيرًا من الفجوة.',
          'Steps are ${health.steps} of ${health.stepsGoal}. A 15-minute walk after prayer closes much of the gap.'));
    }
    if (FastingCalendar.isSunnahFast(DateTime.now())) {
      tips.add(const _Tip(
          Icons.nightlight_round,
          AppColors.accentGold,
          'اليوم من أيام الصيام المستحبة. أفطر على تمر وماء، ثم وجبة متوازنة بعد المغرب.',
          'Today is a recommended fasting day. Break your fast with dates and water, then a balanced meal after Maghrib.'));
    }
    return tips.take(4).toList();
  }

  Future<void> _send(String text, bool premium, String lang) async {
    final q = text.trim();
    if (q.isEmpty || _loading) return;
    final remaining = premium ? _dailyCap - _todayCount : _freeTaste - _freeUsed;
    if (remaining <= 0) {
      if (!premium) openPaywall(context);
      return;
    }
    setState(() {
      _msgs.add(_Msg(true, q));
      _loading = true;
    });
    _ctl.clear();
    _toBottom();
    final isAr = lang == 'ar';
    String reply;
    try {
      final hist = <Map<String, String>>[
        for (final m in _msgs.length > 8 ? _msgs.sublist(_msgs.length - 8, _msgs.length - 1) : _msgs.sublist(0, _msgs.length - 1))
          {'role': m.user ? 'user' : 'assistant', 'content': m.text},
      ];
      reply = await CoachService.ask(
          lang: lang, snapshot: _snapshot(), history: hist, question: q);
      await _bumpQuota(premium);
    } catch (e) {
      reply = !CoachService.available
          ? (isAr
              ? 'المدرّب الذكي غير مفعّل في هذا الإصدار. نصائح اليوم أعلاه تعمل دون إنترنت.'
              : 'The AI coach is not enabled in this build. Today\u2019s insights above still work offline.')
          : (isAr
              ? 'تعذّر الوصول إلى المدرّب الآن. تحقق من الاتصال وحاول مجددًا.'
              : 'Could not reach the coach. Check your connection and try again.');
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg(false, reply));
      _loading = false;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    // Rebuild when today's numbers change so the tips stay current.
    ref.watch(caloriesProvider);
    ref.watch(waterProvider);
    final th = PTheme(isDark);
    String t(String ar, String en) => tLang(lang, ar, en);
    final isAr = lang == 'ar';
    final remaining = premium ? _dailyCap - _todayCount : _freeTaste - _freeUsed;
    final tips = _localTips();

    final chips = <String>[
      t('ماذا آكل الآن؟', 'What should I eat now?'),
      t('كيف أرفع البروتين؟', 'How do I get more protein?'),
      t('خطة سحور سريعة', 'Quick suhoor plan'),
      t('وجبة خفيفة تحت ٢٠٠ سعر', 'A snack under 200 kcal'),
    ];

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('المدرّب الذكي', 'AI Coach'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              PSection(t('نصائح اليوم', 'TODAY\u2019S INSIGHTS'), th),
              if (tips.isEmpty)
                PCard(
                  th: th,
                  child: Text(t('كل شيء يسير بشكل جيد اليوم. استمر!', 'All on track today. Keep going!'),
                      style: pText(th.text, 13.5, w: FontWeight.w700)),
                ),
              for (final tip in tips) ...[
                PCard(
                  th: th,
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    PBadge(tip.icon, size: 38, color: tip.color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(isAr ? tip.ar : tipEn(tip, lang),
                          style: pText(th.text, 13, w: FontWeight.w600, h: 1.5)),
                    ),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
              PSection(t('اسأل مدرّبك', 'ASK YOUR COACH'), th),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in chips)
                  GestureDetector(
                    onTap: () => _send(c, premium, lang),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: th.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: kGold.withOpacity(0.5), width: 0.8),
                      ),
                      child: Text(c, style: pText(th.text, 12.5, w: FontWeight.w700)),
                    ),
                  ),
              ]),
              const SizedBox(height: 14),
              for (final m in _msgs)
                Align(
                  alignment: m.user ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    decoration: BoxDecoration(
                      color: m.user ? kGold : th.card,
                      borderRadius: BorderRadius.circular(18),
                      border: m.user ? null : Border.all(color: th.border, width: 0.8),
                    ),
                    child: Text(m.text,
                        style: pText(m.user ? const Color(0xFF1A0F00) : th.text, 13.5,
                            w: FontWeight.w600, h: 1.5)),
                  ),
                ),
              if (_loading)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kGold)),
                    const SizedBox(width: 10),
                    Text(t('يفكّر…', 'Thinking…'), style: pText(th.muted, 12.5)),
                  ]),
                ),
              if (!premium && remaining <= 0)
                PCard(
                  th: th,
                  gold: true,
                  child: Column(children: [
                    Text(t('انتهت رسائلك التجريبية', 'Your free taste is used up'),
                        style: pText(th.text, 15, w: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                        t('مع بريميوم: ٤٠ رسالة يوميًا مع مدرّب يرى أرقام يومك.',
                            'With Premium: 40 messages a day from a coach that sees your day\u2019s numbers.'),
                        textAlign: TextAlign.center,
                        style: pText(th.muted, 12.5, w: FontWeight.w500, h: 1.45)),
                    const SizedBox(height: 12),
                    PGoldButton(
                        label: t('افتح بريميوم', 'Unlock Premium'),
                        icon: Icons.workspace_premium_rounded,
                        onTap: () => openPaywall(context)),
                  ]),
                ),
              const SizedBox(height: 6),
              Text(
                t('إرشادات عامة وليست نصيحة طبية.', 'General guidance, not medical advice.'),
                textAlign: TextAlign.center,
                style: pText(th.muted, 11, w: FontWeight.w500),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: th.card,
              border: Border(top: BorderSide(color: th.border, width: 0.8)),
            ),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  enabled: remaining > 0,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) => _send(v, premium, lang),
                  style: pText(th.text, 14),
                  decoration: InputDecoration(
                    hintText: premium
                        ? t('اسأل عن وجباتك… ($remaining متبقية)', 'Ask about your meals… ($remaining left)')
                        : t('جرّب المدرّب — $remaining رسائل مجانية', 'Try the coach — $remaining free messages'),
                    hintStyle: pText(th.muted, 13, w: FontWeight.w500),
                    filled: true,
                    fillColor: th.cardAlt,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _send(_ctl.text, premium, lang),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [kGoldLight, kGold]),
                  ),
                  child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF1A0F00)),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  /// Tips are written in Arabic and English; other languages use the English text
  /// (the coach chat itself answers in the chosen language).
  String tipEn(_Tip tip, String lang) => tip.en;
}
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/features/premium/fasting_planner_screen.dart
# ───────────────────────────────────────────────────────────
write('lib/features/premium/fasting_planner_screen.dart', r'''// fasting_planner_screen.dart — HalalCalorie v58 (PATCH_V58_FASTING)
// Sunnah-fast calendar. Everyone sees the next three fasts; Premium gets the
// full two-month calendar, a fasting log with streak, suhoor/iftar times from
// the user's own prayer times, and a suhoor/iftar plate guide.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/fasting_calendar.dart';
import '../../core/hijri.dart';
import '../../core/l10n.dart';
import '../../core/prayer_provider.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class FastingPlannerScreen extends ConsumerStatefulWidget {
  const FastingPlannerScreen({super.key});
  @override
  ConsumerState<FastingPlannerScreen> createState() => _FastingState();
}

class _FastingState extends ConsumerState<FastingPlannerScreen> {
  static const _prefKey = 'fasts_done_v1';
  Set<String> _done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _done = (p.getStringList(_prefKey) ?? const <String>[]).toSet());
  }

  Future<void> _toggle(String key) async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      if (!_done.remove(key)) _done.add(key);
    });
    await p.setStringList(_prefKey, _done.toList());
  }

  /// Consecutive recommended-fast days completed, counted back from the most
  /// recent one that has passed (a missed fast ends the run).
  int _streak() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var streak = 0;
    for (var i = 0; i < 120; i++) {
      final d = today.subtract(Duration(days: i));
      if (!FastingCalendar.isSunnahFast(d)) continue;
      final k = FastingCalendar.dateKey(d);
      if (_done.contains(k)) {
        streak++;
      } else if (i == 0) {
        continue; // today is still open
      } else {
        break;
      }
    }
    return streak;
  }

  String _dayName(DateTime d, bool isAr) {
    const ar = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return (isAr ? ar : en)[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final all = FastingCalendar.upcoming(from: today, days: 60);
    final shown = premium ? all : all.take(3).toList();
    final hToday = HijriDate.fromGregorian(today);
    final prayer = ref.watch(prayerTimesProvider).valueOrNull;
    final next = all.isEmpty ? null : all.first;
    final inRamadan = hToday.isRamadan;

    String two(int v) => v.toString().padLeft(2, '0');
    String clock(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('مخطط الصيام', 'Fasting Planner'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          // Hero
          PCard(
            th: th,
            gold: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const PBadge(Icons.nightlight_round, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      inRamadan
                          ? t('رمضان مبارك', 'Ramadan Mubarak')
                          : next == null
                              ? t('لا صيام مستحب قريبًا', 'No recommended fast soon')
                              : () {
                                  final d = next.date.difference(today).inDays;
                                  final title = isAr
                                      ? FastingCalendar.titleAr(next.kind)
                                      : FastingCalendar.titleEn(next.kind);
                                  return d == 0
                                      ? t('اليوم: $title', 'Today: $title')
                                      : d == 1
                                          ? t('غدًا: $title', 'Tomorrow: $title')
                                          : t('بعد $d أيام: $title', 'In $d days: $title');
                                }(),
                      style: pText(th.text, 16.5, w: FontWeight.w900, h: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${hToday.day} ${hToday.monthName(arabic: isAr)} ${hToday.year}',
                      style: pText(th.muted, 12.5, w: FontWeight.w600),
                    ),
                  ]),
                ),
              ]),
              if (premium && prayer != null) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _timeBox(th, Icons.free_breakfast_rounded,
                        t('إمساك السحور', 'Suhoor ends'),
                        clock(prayer.fajr), kGold),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _timeBox(th, Icons.nightlight_round,
                        t('الإفطار', 'Iftar'), clock(prayer.maghrib),
                        AppColors.halalGreen),
                  ),
                ]),
              ],
              if (premium) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _timeBox(th, Icons.local_fire_department_rounded,
                        t('سلسلة الصيام', 'Fasting streak'),
                        '${_streak()}', AppColors.haramRed),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _timeBox(th, Icons.check_circle_rounded,
                        t('أيام أتممتها', 'Days completed'),
                        '${_done.length}', AppColors.waterBlue),
                  ),
                ]),
              ],
            ]),
          ),

          PSection(t('الأيام القادمة', 'UPCOMING FASTS'), th),
          if (shown.isEmpty)
            PCard(
                th: th,
                child: Text(t('لا أيام مستحبة في الشهرين القادمين.',
                    'No recommended fasting days in the next two months.'),
                    style: pText(th.muted, 13))),
          for (final f in shown) ...[
            _fastTile(f, th, isAr, premium, today),
            const SizedBox(height: 8),
          ],
          if (!premium && all.length > 3)
            PCard(
              th: th,
              gold: true,
              onTap: () => openPaywall(context),
              child: Row(children: [
                const PBadge(Icons.lock_rounded, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('+${all.length - 3} يومًا قادمًا، وسجل الصيام والسلسلة وتذكير السحور والإفطار — مع بريميوم',
                        '+${all.length - 3} more fasts, your fasting log and streak, plus suhoor and iftar reminders — with Premium'),
                    style: pText(th.text, 13, w: FontWeight.w700, h: 1.45),
                  ),
                ),
              ]),
            ),

          // Plate guide
          PSection(t('طبق السحور والإفطار', 'SUHOOR & IFTAR PLATE'), th),
          PLocked(
            locked: !premium,
            th: th,
            label: t('افتح مع بريميوم', 'Unlock with Premium'),
            onUnlock: () => openPaywall(context),
            child: PCard(
              th: th,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _guideTitle(th, Icons.free_breakfast_rounded, t('السحور — يدوم شبعه', 'Suhoor — built to last')),
                const SizedBox(height: 6),
                _bullet(th, t('بطيئة الهضم: شوفان أو خبز أسمر أو فول (٤٠–٦٠ غ كربوهيدرات)',
                    'Slow carbs: oats, whole-grain bread or ful (40–60 g carbs)')),
                _bullet(th, t('بروتين: بيضتان أو زبادي يوناني أو جبنة قريش',
                    'Protein: two eggs, Greek yogurt or cottage cheese')),
                _bullet(th, t('ماء وفير، وقلّل الملح والمخللات حتى لا تعطش',
                    'Plenty of water; go easy on salt and pickles so thirst stays away')),
                const SizedBox(height: 12),
                _guideTitle(th, Icons.nightlight_round, t('الإفطار — بهدوء', 'Iftar — gently')),
                const SizedBox(height: 6),
                _bullet(th, t('٣ تمرات وماء، ثم صلِّ المغرب، ثم وجبة متوازنة',
                    '3 dates and water, pray Maghrib, then a balanced meal')),
                _bullet(th, t('ابدأ بشوربة أو سلطة، وخفّف المقليات والحلويات',
                    'Start with soup or salad; go light on fried food and sweets')),
                _bullet(th, t('نصف الطبق خضار، وربعه بروتين، وربعه نشويات',
                    'Half the plate vegetables, a quarter protein, a quarter starch')),
              ]),
            ),
          ),

          const SizedBox(height: 18),
          Text(
            t('التقويم الهجري هنا حسابي وقد يختلف عن رؤية الهلال في بلدك بيوم. اعتمد إعلان دار الإفتاء في بلدك.',
                'The Hijri dates here are calculated and can differ from your local moon sighting by a day. Follow your country\u2019s announcement.'),
            textAlign: TextAlign.center,
            style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(PTheme th, IconData icon, String label, String value, Color c) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: th.card.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withOpacity(0.35), width: 0.8),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: pText(th.muted, 11, w: FontWeight.w700)),
              Text(value, style: pText(th.text, 17, w: FontWeight.w900)),
            ]),
          ),
        ]),
      );

  Widget _guideTitle(PTheme th, IconData i, String s) => Row(children: [
        Icon(i, size: 18, color: kGold),
        const SizedBox(width: 8),
        Text(s, style: pText(th.text, 14, w: FontWeight.w900)),
      ]);

  Widget _bullet(PTheme th, String s) => Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(s, style: pText(th.muted, 12.5, w: FontWeight.w600, h: 1.5))),
        ]),
      );

  Widget _fastTile(FastDay f, PTheme th, bool isAr, bool premium, DateTime today) {
    final key = FastingCalendar.dateKey(f.date);
    final done = _done.contains(key);
    final diff = f.date.difference(today).inDays;
    final title = isAr ? FastingCalendar.titleAr(f.kind) : FastingCalendar.titleEn(f.kind);
    final note = isAr ? FastingCalendar.noteAr(f.kind) : FastingCalendar.noteEn(f.kind);
    final when = diff == 0
        ? (isAr ? 'اليوم' : 'Today')
        : diff == 1
            ? (isAr ? 'غدًا' : 'Tomorrow')
            : '${_dayName(f.date, isAr)} ${f.date.day}/${f.date.month}';
    return PCard(
      th: th,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: kGold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text('${f.date.day}', style: pText(kGold, 20, w: FontWeight.w900)),
            Text('${f.hijri.day}/${f.hijri.month}', style: pText(th.muted, 10.5, w: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: pText(th.text, 14, w: FontWeight.w900)),
            const SizedBox(height: 2),
            Text('$when · $note', style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.4)),
          ]),
        ),
        const SizedBox(width: 8),
        if (premium && diff <= 0)
          GestureDetector(
            onTap: () => _toggle(key),
            child: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 28, color: done ? AppColors.halalGreen : th.muted),
          ),
      ]),
    );
  }
}
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/features/premium/meal_plan_screen.dart
# ───────────────────────────────────────────────────────────
write('lib/features/premium/meal_plan_screen.dart', r'''// meal_plan_screen.dart — HalalCalorie v58 (PATCH_V58_MEALPLAN)
// Premium AI day planner. Builds a full halal day that fits the user's calorie
// and macro targets (normal day, or suhoor/iftar on fasting days), one-tap
// logging per meal, and a shareable grocery list. Plans are cached per day so
// reopening costs nothing; generation is capped at 5 per day.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/fasting_calendar.dart';
import '../../core/hijri.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models/user_profile.dart';
import 'premium_ui.dart';

class PlanMeal {
  final String slot, name;
  final int kcal;
  final double protein, carbs, fat;
  final List<String> items;
  const PlanMeal(this.slot, this.name, this.kcal, this.protein, this.carbs,
      this.fat, this.items);

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'name': name,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'items': items,
      };

  static PlanMeal? fromJson(dynamic j) {
    if (j is! Map) return null;
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final name = '${j['name'] ?? ''}'.trim();
    final kcal = d(j['kcal']).round();
    if (name.isEmpty || kcal <= 0) return null;
    return PlanMeal(
      '${j['slot'] ?? ''}'.trim(),
      name,
      kcal.clamp(30, 2500),
      d(j['protein']),
      d(j['carbs']),
      d(j['fat']),
      [
        for (final i in (j['items'] is List ? j['items'] as List : const []))
          '$i'.trim()
      ].where((s) => s.isNotEmpty).toList(),
    );
  }
}

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});
  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanState();
}

class _MealPlanState extends ConsumerState<MealPlanScreen> {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const _dailyCap = 5;

  List<PlanMeal> _plan = [];
  final Set<int> _logged = {};
  bool _loading = false;
  String? _error;
  String _style = 'balanced';
  int _genToday = 0;

  String get _today => FastingCalendar.dateKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('mealplan_$_today');
    final gen = p.getString('mealplan_gen_day') == _today
        ? (p.getInt('mealplan_gen_count') ?? 0)
        : 0;
    final plan = <PlanMeal>[];
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          final m = PlanMeal.fromJson(j);
          if (m != null) plan.add(m);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _genToday = gen;
      _logged
        ..clear()
        ..addAll((p.getStringList('mealplan_logged_$_today') ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>());
    });
  }

  static String _langName(String c) =>
      const {
        'ar': 'Arabic',
        'en': 'English',
        'fr': 'French',
        'tr': 'Turkish',
        'ur': 'Urdu',
        'ms': 'Malay',
        'id': 'Indonesian',
      }[c] ??
      'English';

  Future<void> _generate(String lang, bool fastingDay) async {
    if (_loading) return;
    if (_genToday >= _dailyCap) {
      setState(() => _error = tLang(lang, 'وصلت إلى حد ٥ خطط اليوم. عُد غدًا بإذن الله.',
          'You have reached today\u2019s limit of 5 plans. Come back tomorrow.'));
      return;
    }
    final isAr = lang == 'ar';
    if (_apiKey.isEmpty) {
      setState(() => _error = isAr
          ? 'مخطط الوجبات غير مفعّل في هذا الإصدار.'
          : 'The meal planner is not enabled in this build.');
      return;
    }
    final profile = ref.read(userProfileProvider);
    final goal = ref.read(caloriesProvider).goal;
    setState(() {
      _loading = true;
      _error = null;
    });

    final slots = fastingDay
        ? 'suhoor, iftar, post-iftar snack'
        : 'breakfast, lunch, dinner, snack';
    final styleHint = const {
          'balanced': 'balanced and varied',
          'protein': 'high-protein',
          'budget': 'budget-friendly with cheap staples (ful, eggs, lentils, rice, chicken thighs, seasonal vegetables)',
          'quick': 'quick: every meal under 15 minutes of work',
          'light': 'light on the stomach and low in fried food',
        }[_style] ??
        'balanced';
    final conds = profile?.healthConditions
            .map((c) => c.nameEn())
            .where((n) => n != 'None')
            .toList() ??
        <String>[];
    final system = [
      'You are a halal nutrition planner. Reply with ONLY one JSON object, no markdown, no commentary.',
      'Schema: {"meals":[{"slot":string,"name":string,"kcal":int,"protein":number,"carbs":number,"fat":number,"items":[string]}]}',
      '"items" are short ingredients with a gram or piece amount, e.g. "Chicken breast 150 g".',
      'Write slot, name and items in ${_langName(lang)}.',
      'Slots, in order: $slots. Total kcal must land within 5% of $goal.',
      if (profile != null)
        'Macro targets for the day: protein ~${profile.proteinGrams.round()} g, carbs ~${profile.carbsGrams.round()} g, fat ~${profile.fatGrams.round()} g.',
      'Style: $styleHint. Prefer foods common in Egypt and the Middle East. Everything must be halal: no pork, no alcohol, no non-halal gelatin.',
      if (profile != null) 'Dietary preference: ${profile.dietPreference.nameEn()}.',
      if (conds.isNotEmpty)
        'Health conditions: ${conds.join(', ')}. Keep it conservative and mention nothing medical.',
      if (fastingDay)
        'This is a fasting day: suhoor should be slow-digesting; iftar starts with dates and water.',
    ].join('\n');

    List<PlanMeal> parsed = [];
    String? err;
    for (final model in const ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant']) {
      try {
        final resp = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({
                'model': model,
                'max_tokens': 1100,
                'temperature': 0.6,
                'response_format': {'type': 'json_object'},
                'messages': [
                  {'role': 'system', 'content': system},
                  {'role': 'user', 'content': 'Plan my day.'},
                ],
              }),
            )
            .timeout(const Duration(seconds: 45));
        if (resp.statusCode != 200) {
          err = 'HTTP ${resp.statusCode}';
          continue;
        }
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        var text = '${(data['choices'] as List).first['message']['content']}';
        final a = text.indexOf('{');
        final b = text.lastIndexOf('}');
        if (a < 0 || b <= a) continue;
        text = text.substring(a, b + 1);
        final obj = jsonDecode(text) as Map<String, dynamic>;
        final meals = <PlanMeal>[];
        for (final j in (obj['meals'] as List? ?? const [])) {
          final m = PlanMeal.fromJson(j);
          if (m != null) meals.add(m);
        }
        if (meals.length >= 2) {
          parsed = meals;
          break;
        }
      } catch (e) {
        err = '$e';
      }
    }

    if (!mounted) return;
    if (parsed.isEmpty) {
      setState(() {
        _loading = false;
        _error = isAr
            ? 'تعذّر إنشاء الخطة الآن. تحقق من الاتصال وحاول مجددًا.'
            : 'Could not build a plan right now. Check your connection and try again.';
      });
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('mealplan_$_today', jsonEncode(parsed.map((m) => m.toJson()).toList()));
    await p.setStringList('mealplan_logged_$_today', const <String>[]);
    await p.setString('mealplan_gen_day', _today);
    await p.setInt('mealplan_gen_count', _genToday + 1);
    if (!mounted) return;
    setState(() {
      _plan = parsed;
      _logged.clear();
      _genToday += 1;
      _loading = false;
    });
  }

  Future<void> _logMeal(int i) async {
    if (_logged.contains(i)) return;
    final m = _plan[i];
    await ref
        .read(caloriesProvider.notifier)
        .addEntry(m.name, m.kcal, proteinG: m.protein, carbsG: m.carbs, fatG: m.fat);
    final p = await SharedPreferences.getInstance();
    setState(() => _logged.add(i));
    await p.setStringList('mealplan_logged_$_today', _logged.map((e) => '$e').toList());
  }

  Future<void> _shareGrocery(bool isAr) async {
    final seen = <String>{};
    final lines = <String>[];
    for (final m in _plan) {
      for (final it in m.items) {
        if (seen.add(it.toLowerCase())) lines.add('• $it');
      }
    }
    final head = isAr ? 'قائمة المشتريات — HalalCalorie' : 'Grocery list — HalalCalorie';
    try {
      await Share.share('$head\n\n${lines.join('\n')}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final goal = ref.watch(caloriesProvider).goal;
    final ramadan = ref.watch(ramadanModeProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);
    final today = DateTime.now();
    final fastingDay = ramadan ||
        HijriDate.fromGregorian(today).isRamadan ||
        FastingCalendar.isSunnahFast(DateTime(today.year, today.month, today.day));
    final total = _plan.fold<int>(0, (a, m) => a + m.kcal);

    final styles = <String, String>{
      'balanced': t('متوازن', 'Balanced'),
      'protein': t('بروتين عالٍ', 'High protein'),
      'budget': t('اقتصادي', 'Budget'),
      'quick': t('سريع', 'Quick'),
      'light': t('خفيف', 'Light'),
    };

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('مخطط وجباتك', 'AI Meal Planner'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: !premium
          ? _locked(th, t)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                PCard(
                  th: th,
                  gold: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const PBadge(Icons.auto_awesome_rounded, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                              fastingDay
                                  ? t('خطة يوم صيام', 'Fasting-day plan')
                                  : t('خطة يومك', 'Plan for your day'),
                              style: pText(th.text, 16.5, w: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(t('هدفك $goal سعرًا', 'Your goal: $goal kcal'),
                              style: pText(th.muted, 12.5, w: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final e in styles.entries)
                        GestureDetector(
                          onTap: () => setState(() => _style = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _style == e.key ? kGold : th.card.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: _style == e.key ? kGold : th.border, width: 0.8),
                            ),
                            child: Text(e.value,
                                style: pText(
                                    _style == e.key ? const Color(0xFF1A0F00) : th.text, 12.5,
                                    w: FontWeight.w800)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    PGoldButton(
                      label: _loading
                          ? t('جارٍ التحضير…', 'Cooking up your plan…')
                          : _plan.isEmpty
                              ? t('أنشئ خطتي', 'Build my plan')
                              : t('خطة جديدة', 'New plan'),
                      icon: Icons.auto_awesome_rounded,
                      onTap: _loading ? null : () => _generate(lang, fastingDay),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        t('${_dailyCap - _genToday} من $_dailyCap محاولات متبقية اليوم',
                            '${_dailyCap - _genToday} of $_dailyCap tries left today'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500)),
                  ]),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator(color: kGold)),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  PCard(
                    th: th,
                    child: Text(_error!, style: pText(AppColors.haramRed, 13, w: FontWeight.w700, h: 1.45)),
                  ),
                ],
                if (_plan.isNotEmpty) ...[
                  PSection(t('وجباتك', 'YOUR MEALS'), th),
                  for (var i = 0; i < _plan.length; i++) ...[
                    _mealCard(i, th, isAr),
                    const SizedBox(height: 10),
                  ],
                  PCard(
                    th: th,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t('المجموع', 'Total'), style: pText(th.muted, 12, w: FontWeight.w700)),
                          Text('$total kcal',
                              style: pText(
                                  (total - goal).abs() <= goal * 0.10
                                      ? AppColors.halalGreen
                                      : AppColors.doubtOrange,
                                  22,
                                  w: FontWeight.w900)),
                        ]),
                      ),
                      PGoldButton(
                        outlined: true,
                        label: t('قائمة المشتريات', 'Grocery list'),
                        icon: Icons.shopping_basket_rounded,
                        onTap: () => _shareGrocery(isAr),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('الأرقام تقديرية من الذكاء الاصطناعي، وليست نصيحة طبية. عدّل الكميات حسب حالتك.',
                        'Numbers are AI estimates, not medical advice. Adjust portions to suit you.'),
                    textAlign: TextAlign.center,
                    style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.45),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _mealCard(int i, PTheme th, bool isAr) {
    final m = _plan[i];
    final done = _logged.contains(i);
    return PCard(
      th: th,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (m.slot.isNotEmpty) PPill(m.slot, kGold),
          const Spacer(),
          Text('${m.kcal} kcal', style: pText(AppColors.halalGreen, 15, w: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        Text(m.name, style: pText(th.text, 15, w: FontWeight.w900, h: 1.3)),
        const SizedBox(height: 6),
        Text(
          'P ${m.protein.round()} g  ·  C ${m.carbs.round()} g  ·  F ${m.fat.round()} g',
          style: pText(th.muted, 12, w: FontWeight.w700),
        ),
        if (m.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(m.items.join(' · '), style: pText(th.muted, 12, w: FontWeight.w500, h: 1.5)),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PGoldButton(
            outlined: done,
            label: done ? (isAr ? 'تم التسجيل' : 'Logged') : (isAr ? 'سجّل هذه الوجبة' : 'Log this meal'),
            icon: done ? Icons.check_rounded : Icons.add_rounded,
            onTap: done ? null : () => _logMeal(i),
          ),
        ),
      ]),
    );
  }

  Widget _locked(PTheme th, String Function(String, String) t) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PCard(
            th: th,
            gold: true,
            child: Column(children: [
              const PBadge(Icons.auto_awesome_rounded, size: 60),
              const SizedBox(height: 14),
              Text(t('يومك كله في ثوانٍ', 'Your whole day, in seconds'),
                  style: pText(th.text, 19, w: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                t('خطة وجبات حلال تطابق سعراتك ومغذياتك — أو سحورك وإفطارك — مع تسجيل بنقرة وقائمة مشتريات.',
                    'A halal meal plan that fits your calories and macros, or your suhoor and iftar, with one-tap logging and a grocery list.'),
                textAlign: TextAlign.center,
                style: pText(th.muted, 13, w: FontWeight.w600, h: 1.55),
              ),
              const SizedBox(height: 16),
              PGoldButton(
                label: t('افتح بريميوم', 'Unlock Premium'),
                icon: Icons.workspace_premium_rounded,
                onTap: () => openPaywall(context),
              ),
            ]),
          ),
          PSection(t('مثال', 'EXAMPLE'), th),
          PLocked(
            locked: true,
            th: th,
            label: t('افتح مع بريميوم', 'Unlock with Premium'),
            onUnlock: () => openPaywall(context),
            child: Column(children: [
              _sample(th, t('الفطور', 'Breakfast'), t('فول بالزيت الحار + بيضة + خبز بلدي', 'Ful with olive oil, egg, baladi bread'), 420),
              const SizedBox(height: 10),
              _sample(th, t('الغداء', 'Lunch'), t('صدر دجاج مشوي + أرز + سلطة', 'Grilled chicken, rice and salad'), 640),
              const SizedBox(height: 10),
              _sample(th, t('العشاء', 'Dinner'), t('زبادي يوناني + تمر + مكسرات', 'Greek yogurt, dates and nuts'), 380),
            ]),
          ),
        ],
      );

  Widget _sample(PTheme th, String slot, String name, int kcal) => PCard(
        th: th,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot, style: pText(kGold, 11.5, w: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(name, style: pText(th.text, 14, w: FontWeight.w800)),
            ]),
          ),
          Text('$kcal kcal', style: pText(AppColors.halalGreen, 14, w: FontWeight.w900)),
        ]),
      );
}
''')

# ───────────────────────────────────────────────────────────
# NEW FILE lib/features/premium/premium_hub_screen.dart
# ───────────────────────────────────────────────────────────
write('lib/features/premium/premium_hub_screen.dart', r'''// premium_hub_screen.dart — HalalCalorie v58 (PATCH_V58_HUB)
// "Premium Studio": the front door to every Premium tool, plus the card that
// sits on the Home tab. Free users see exactly what each tool does and a
// preview of their own data, then one clear upgrade button.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/fasting_calendar.dart';
import '../../core/hijri.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class _Tool {
  final IconData icon;
  final Color color;
  final String route, titleAr, titleEn, subAr, subEn;
  final bool freeTaste;
  const _Tool(this.icon, this.color, this.route, this.titleAr, this.titleEn,
      this.subAr, this.subEn,
      {this.freeTaste = false});
}

const _tools = <_Tool>[
  _Tool(Icons.psychology_alt_rounded, AppColors.sleepPurple, '/coach',
      'المدرّب الذكي', 'AI Coach',
      'يرى أرقام يومك ويجيب عن أي سؤال', 'Sees your day\u2019s numbers and answers anything',
      freeTaste: true),
  _Tool(Icons.auto_awesome_rounded, AppColors.halalGreen, '/meal-plan',
      'مخطط الوجبات', 'AI Meal Planner',
      'يومك كاملًا بسعراتك ومغذياتك + قائمة مشتريات',
      'A full day to your macros, plus a grocery list'),
  _Tool(Icons.insights_rounded, AppColors.waterBlue, '/insights',
      'رؤى متقدمة', 'Insights Pro',
      'اتجاهات ٩٠ يومًا وتوقّع وزنك وخريطة التزامك',
      '90-day trends, weight forecast and consistency map',
      freeTaste: true),
  _Tool(Icons.nightlight_round, kGold, '/fasting', 'مخطط الصيام', 'Fasting Planner',
      'الاثنين والخميس والأيام البيض وعرفة وعاشوراء مع سجل وسلسلة',
      'Mondays, Thursdays, White Days, Arafah, Ashura with a log and streak',
      freeTaste: true),
  _Tool(Icons.notifications_active_rounded, AppColors.doubtOrange, '/notifications',
      'مركز الإشعارات', 'Notification Center',
      'تذكيرات ذكية وأوقات مخصصة وسحور وإفطار',
      'Smart reminders, custom times, suhoor and iftar',
      freeTaste: true),
];

class PremiumHubScreen extends ConsumerWidget {
  const PremiumHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);
    final toRamadan = HijriDate.daysUntilRamadan(DateTime.now());

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('استوديو بريميوم', 'Premium Studio'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          PCard(
            th: th,
            gold: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const PBadge(Icons.workspace_premium_rounded, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        premium
                            ? t('أهلًا بك في بريميوم', 'Welcome to Premium')
                            : t('كل ما تحتاجه للوصول لهدفك', 'Everything to reach your goal'),
                        style: pText(th.text, 17, w: FontWeight.w900, h: 1.25)),
                    const SizedBox(height: 4),
                    Text(
                        premium
                            ? t('أدواتك كلها مفتوحة', 'All your tools are unlocked')
                            : t('جرّب كل أداة مجانًا أولًا', 'Try every tool for free first'),
                        style: pText(th.muted, 12.5, w: FontWeight.w600)),
                  ]),
                ),
              ]),
              if (!premium) ...[
                const SizedBox(height: 14),
                PGoldButton(
                  label: t('ترقية الآن', 'Upgrade now'),
                  icon: Icons.workspace_premium_rounded,
                  onTap: () => openPaywall(context),
                ),
              ],
            ]),
          ),
          if (toRamadan > 0 && toRamadan <= 75) ...[
            const SizedBox(height: 12),
            PCard(
              th: th,
              onTap: () => context.push('/fasting'),
              child: Row(children: [
                const PBadge(Icons.nightlight_round, size: 44, color: AppColors.sleepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t('رمضان بعد $toRamadan يومًا', 'Ramadan in $toRamadan days'),
                        style: pText(th.text, 15, w: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                        t('درّب جسمك بصيام الاثنين والخميس والأيام البيض',
                            'Prepare with Monday, Thursday and White Day fasts'),
                        style: pText(th.muted, 12, w: FontWeight.w600, h: 1.4)),
                  ]),
                ),
              ]),
            ),
          ],
          PSection(t('أدواتك', 'YOUR TOOLS'), th),
          for (final tool in _tools) ...[
            PCard(
              th: th,
              padding: const EdgeInsets.all(14),
              onTap: () => context.push(tool.route),
              child: Row(children: [
                PBadge(tool.icon, size: 46, color: tool.color),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                          child: Text(isAr ? tool.titleAr : tool.titleEn,
                              style: pText(th.text, 15, w: FontWeight.w900))),
                      if (!premium && tool.freeTaste) ...[
                        const SizedBox(width: 8),
                        PPill(t('تجربة مجانية', 'Free taste'), AppColors.halalGreen),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(isAr ? tool.subAr : tool.subEn,
                        style: pText(th.muted, 12, w: FontWeight.w500, h: 1.4)),
                  ]),
                ),
                Icon(isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: th.muted),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          PSection(t('وأيضًا في بريميوم', 'ALSO INCLUDED'), th),
          PCard(
            th: th,
            child: Column(children: [
              _line(th, Icons.qr_code_scanner_rounded, t('ماسحات حلال بلا حدود', 'Unlimited halal scans')),
              _line(th, Icons.photo_camera_rounded, t('تحليل الطعام والجسم بالصورة بلا حدود', 'Unlimited AI food and body photo analysis')),
              _line(th, Icons.monitor_weight_rounded, t('نسبة الدهون وكتلة العضلات', 'Body fat and muscle mass')),
              _line(th, Icons.fitness_center_rounded, t('كل خطط التمرين المميزة', 'Every premium workout plan')),
              _line(th, Icons.terrain_rounded, t('رحلة Ascent كاملة', 'The full Ascent journey')),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _line(PTheme th, IconData i, String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(i, size: 20, color: kGold),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: pText(th.text, 13, w: FontWeight.w700))),
          const Icon(Icons.check_rounded, size: 18, color: AppColors.halalGreen),
        ]),
      );
}

/// Card for the Home tab. Free: a one-line pitch that opens the Studio.
/// Premium: shortcuts, and today's recommended fast when there is one.
class PremiumHomeCard extends ConsumerWidget {
  const PremiumHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final th = PTheme(isDark);
    String t(String ar, String en) => tLang(lang, ar, en);
    final now = DateTime.now();
    final fast = FastingCalendar.upcoming(from: DateTime(now.year, now.month, now.day), days: 2);
    final fastToday = fast.isNotEmpty &&
        fast.first.date.day == now.day &&
        fast.first.date.month == now.month;

    Widget chip(IconData i, String label, String route) => Expanded(
          child: GestureDetector(
            onTap: () => context.push(route),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: th.card.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGold.withOpacity(0.35), width: 0.8),
              ),
              child: Column(children: [
                Icon(i, size: 20, color: kGold),
                const SizedBox(height: 4),
                Text(label, style: pText(th.text, 11, w: FontWeight.w800)),
              ]),
            ),
          ),
        );

    return PCard(
      th: th,
      gold: true,
      padding: const EdgeInsets.all(14),
      onTap: premium ? null : () => context.push('/premium'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PBadge(Icons.workspace_premium_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  premium
                      ? t('استوديو بريميوم', 'Premium Studio')
                      : t('جرّب بريميوم', 'Try Premium'),
                  style: pText(th.text, 15, w: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(
                  premium
                      ? (fastToday
                          ? t('اليوم يوم صيام مستحب', 'Today is a recommended fast')
                          : t('مدرّبك ومخططك وتقاريرك', 'Your coach, planner and reports'))
                      : t('مدرّب ذكي • مخطط وجبات • رؤى • صيام',
                          'AI coach • meal planner • insights • fasting'),
                  style: pText(th.muted, 12, w: FontWeight.w600, h: 1.35)),
            ]),
          ),
          if (!premium) const Icon(Icons.arrow_forward_rounded, color: kGold, size: 20),
        ]),
        if (premium) ...[
          const SizedBox(height: 12),
          Row(children: [
            chip(Icons.psychology_alt_rounded, t('المدرّب', 'Coach'), '/coach'),
            const SizedBox(width: 8),
            chip(Icons.auto_awesome_rounded, t('الخطة', 'Plan'), '/meal-plan'),
            const SizedBox(width: 8),
            chip(Icons.insights_rounded, t('رؤى', 'Insights'), '/insights'),
            const SizedBox(width: 8),
            chip(Icons.nightlight_round, t('صيام', 'Fasting'), '/fasting'),
          ]),
        ],
      ]),
    );
  }
}
''')

# ═══════════════════════════════════════════════════════════
# WIRING
# ═══════════════════════════════════════════════════════════
RT = 'lib/core/router.dart'
edit(RT, sub_once(
    "import '../features/ascent/ascent_screen.dart';\n",
    "import '../features/ascent/ascent_screen.dart';\n"
    "import '../features/premium/premium_hub_screen.dart'; // PATCH_V58\n"
    "import '../features/premium/coach_screen.dart';\n"
    "import '../features/premium/meal_plan_screen.dart';\n"
    "import '../features/premium/insights_screen.dart';\n"
    "import '../features/premium/fasting_planner_screen.dart';\n"
    "import '../features/premium/notification_center_screen.dart';\n",
    marker="premium_hub_screen.dart"), 'premium imports')
edit(RT, sub_once(
    "        _page('/settings', (_, __) => const SettingsScreen()),\n",
    "        _page('/settings', (_, __) => const SettingsScreen()),\n"
    "        _page('/premium', (_, __) => const PremiumHubScreen()),\n"
    "        _page('/coach', (_, __) => const CoachScreen()),\n"
    "        _page('/meal-plan', (_, __) => const MealPlanScreen()),\n"
    "        _page('/insights', (_, __) => const InsightsScreen()),\n"
    "        _page('/fasting', (_, __) => const FastingPlannerScreen()),\n"
    "        _page('/notifications', (_, __) => const NotificationCenterScreen()),\n",
    marker="'/notifications'"), 'premium routes')

# ── main.dart: permission prompt + smart reminders ─────────
MN = 'lib/main.dart'
edit(MN, sub_once(
    "import 'core/revenuecat_service.dart';\n",
    "import 'core/revenuecat_service.dart';\nimport 'core/prayer_provider.dart'; // PATCH_V58\n",
    marker="core/prayer_provider.dart"), 'import prayer provider')
edit(MN, sub_once(
    "  void _armMidnightTimer() {\n",
    "  // PATCH_V58_NOTIF: the permission prompt + the premium smart reminders.\n"
    "  Future<void> _afterOnboarding() async {\n"
    "    await Future.delayed(const Duration(milliseconds: 1500));\n"
    "    try { await NotificationService.askPermissionOnce(); } catch (e) { debugPrint('Notif ask: $e'); }\n"
    "    await _refreshSmart();\n"
    "  }\n\n"
    "  Future<void> _refreshSmart() async {\n"
    "    try {\n"
    "      final times = await ref.read(prayerTimesProvider.future)\n"
    "          .timeout(const Duration(seconds: 8), onTimeout: () => null);\n"
    "      await NotificationService.refreshSmart(\n"
    "          times: times, ramadan: ref.read(ramadanModeProvider));\n"
    "    } catch (e) { debugPrint('Smart notif: $e'); }\n"
    "  }\n\n"
    "  void _armMidnightTimer() {\n",
    marker="_afterOnboarding"), 'notif methods')
edit(MN, sub_once(
    "    if (state == AppLifecycleState.resumed) _rollDayIfNeeded();",
    "    if (state == AppLifecycleState.resumed) { _rollDayIfNeeded(); _refreshSmart(); }",
    marker="_rollDayIfNeeded(); _refreshSmart();"), 'refresh smart on resume')
edit(MN, sub_once(
    "    final lang      = ref.watch(languageProvider);\n",
    "    final lang      = ref.watch(languageProvider);\n"
    "    ref.listen<bool>(onboardingDoneProvider, (prev, next) { if (next) _afterOnboarding(); });\n"
    "    ref.listen<bool>(premiumProvider, (prev, next) { _refreshSmart(); });\n",
    marker="_afterOnboarding(); });"), 'permission + premium listeners')

# ── shell.dart: open the screen a tapped notification points at ──
SH = 'lib/core/shell.dart'
edit(SH, sub_once("import 'providers.dart';\n",
    "import 'providers.dart';\nimport 'notifications.dart'; // PATCH_V58\n",
    marker="import 'notifications.dart';"), 'shell import')
edit(SH, sub_once(
    "  @override\n  void dispose() {\n    _slideIn.dispose();\n    super.dispose();\n  }\n",
    "  // PATCH_V58_NOTIF_TAP\n"
    "  @override\n  void initState() {\n    super.initState();\n"
    "    NotificationService.pendingRoute.addListener(_openNotifRoute);\n"
    "    WidgetsBinding.instance.addPostFrameCallback((_) => _openNotifRoute());\n  }\n\n"
    "  void _openNotifRoute() {\n"
    "    final r = NotificationService.pendingRoute.value;\n"
    "    if (r == null || r.isEmpty || !mounted) return;\n"
    "    NotificationService.pendingRoute.value = null;\n"
    "    const tabPaths = ['/home', '/nutrition', '/fitness', '/ascent', '/health', '/profile'];\n"
    "    if (r == '/ascent' && !ref.read(premiumProvider)) { context.push('/paywall'); return; }\n"
    "    if (tabPaths.contains(r)) { context.go(r); } else { context.push(r); }\n  }\n\n"
    "  @override\n  void dispose() {\n"
    "    NotificationService.pendingRoute.removeListener(_openNotifRoute);\n"
    "    _slideIn.dispose();\n    super.dispose();\n  }\n",
    marker="PATCH_V58_NOTIF_TAP"), 'notification tap routing')

# ── settings: entry points ─────────────────────────────────
ST = 'lib/features/settings/settings_screen.dart'
def tile(route, ar, en, icon):
    return (
"                GestureDetector(\n"
"                  onTap: () => context.push('%s'),\n"
"                  child: Container(\n"
"                    margin: const EdgeInsets.only(bottom: 10),\n"
"                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),\n"
"                    decoration: BoxDecoration(\n"
"                      color: AppColors.accentGold.withOpacity(0.12),\n"
"                      borderRadius: BorderRadius.circular(18),\n"
"                      border: Border.all(color: AppColors.accentGold.withOpacity(0.45), width: 0.8),\n"
"                    ),\n"
"                    child: Row(children: [\n"
"                      const Icon(%s, color: AppColors.accentGold, size: 22),\n"
"                      const SizedBox(width: 12),\n"
"                      Expanded(child: Text(t('%s', '%s'),\n"
"                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,\n"
"                              fontWeight: FontWeight.w800, color: text))),\n"
"                      Icon(Icons.chevron_right_rounded, color: muted),\n"
"                    ]),\n"
"                  ),\n"
"                ),\n") % (route, icon, ar, en)
edit(ST, sub_once(
    "                section(t('الإشعارات', 'NOTIFICATIONS')),\n",
    "                section(t('الإشعارات', 'NOTIFICATIONS')),\n// PATCH_V58_NOTIF_LINK\n"
    + tile('/notifications', 'مركز الإشعارات — اختبار وإصلاح وتذكيرات ذكية',
           'Notification Center — test, fix & smart reminders', 'Icons.notifications_active_rounded'),
    marker="PATCH_V58_NOTIF_LINK"), 'settings: notification center link')
edit(ST, sub_once(
    "                section(t('المظهر', 'APPEARANCE')),\n",
    "// PATCH_V58_STUDIO_LINK\n"
    + tile('/premium', 'استوديو بريميوم — مدرّب • مخطط وجبات • رؤى • صيام',
           'Premium Studio — coach • meal planner • insights • fasting', 'Icons.workspace_premium_rounded')
    + "                section(t('المظهر', 'APPEARANCE')),\n",
    marker="PATCH_V58_STUDIO_LINK"), 'settings: studio link')
edit(ST, sub_once(
    "t('ماسحات غير محدودة • ١٨٠ تمرين • مخطط AI',\n                                    'Unlimited scans • 180 workouts • AI planner')",
    "t('مدرّب AI • مخطط وجبات • رؤى • ماسحات بلا حدود',\n                                    'AI coach • meal planner • insights • unlimited scans')",
    marker="مدرّب AI • مخطط وجبات"), 'settings: honest subtitle')

# ── profile: honest subtitle ───────────────────────────────
edit('lib/features/profile/profile_screen.dart', sub_once(
    "t('ماسحات غير محدودة • ١٨٠ تمرين • مخطط AI • مقاييس دقيقة',\n                               'Unlimited scans • 180 workouts • AI planner • precise body metrics')",
    "t('مدرّب AI • مخطط وجبات • رؤى متقدمة • ماسحات بلا حدود',\n                               'AI coach • meal planner • advanced insights • unlimited scans')",
    marker="مدرّب AI • مخطط وجبات • رؤى متقدمة"), 'profile: honest subtitle')

# ── home: premium card + real workout count ────────────────
HM = 'lib/features/home/home_screen.dart'
edit(HM, sub_once("import '../../core/fx6.dart';\n",
    "import '../../core/fx6.dart';\nimport '../premium/premium_hub_screen.dart'; // PATCH_V58\n",
    marker="premium_hub_screen.dart"), 'home import')
edit(HM, sub_once("// ── RAMADAN HERO ──",
    "// ── PREMIUM STUDIO (PATCH_V58) ──\n_anim(1, const PremiumHomeCard()),\nconst SizedBox(height: 12),\n\n// ── RAMADAN HERO ──",
    marker="PATCH_V58) ──"), 'home: premium card')
edit(HM, sub_once(
    "tLang(lang, '١٨٠ خطة', '180 plans', '180 plans', '180 plan', '180 rancangan', '180 rencana')",
    "tLang(lang, '${kWorkouts.length} خطة', '${kWorkouts.length} plans')",
    marker="${kWorkouts.length} plans"), 'home: real workout count')

# ── paywall: the real feature list ─────────────────────────
def paywall_features(s):
    if 'PATCH_V58_FEATURES' in s: return s
    a = s.find('  List<_Feat> _features(bool isAr) => isAr')
    b = s.find('  Widget _featureRow(_Feat f)')
    if a < 0 or b < 0 or b < a: return None
    new = r"""  // PATCH_V58_FEATURES
  List<_Feat> _features(bool isAr) => isAr
      ? const [
          _Feat(Icons.psychology_alt_rounded,
              'مدرّب ذكي يرى أرقام يومك ويجيب عن أسئلتك'),
          _Feat(Icons.auto_awesome_rounded,
              'مخطط وجبات حلال يطابق سعراتك أو سحورك وإفطارك'),
          _Feat(Icons.insights_rounded,
              'رؤى ٩٠ يومًا، توقّع وزنك، تصدير بياناتك'),
          _Feat(Icons.nightlight_round,
              'مخطط الصيام: سجل وسلسلة وأيام السنّة'),
          _Feat(Icons.notifications_active_rounded,
              'تذكيرات ذكية: السحور والإفطار وحارس السلسلة'),
          _Feat(Icons.photo_camera_rounded,
              'تحليل الطعام والجسم بالصورة — بلا حدود'),
          _Feat(Icons.qr_code_scanner_rounded,
              'ماسحات حلال غير محدودة (مقابل ٣ مجانية/يوم)'),
          _Feat(Icons.monitor_weight_rounded,
              'نسبة الدهون + كتلة العضلات + LBM'),
          _Feat(Icons.fitness_center_rounded,
              'كل خطط التمرين المميزة + رمضان + ما بعد الولادة'),
          _Feat(Icons.terrain_rounded, 'رحلة Ascent كاملة + مراجعة أسبوعية'),
        ]
      : const [
          _Feat(Icons.psychology_alt_rounded,
              'AI coach that sees your day and answers anything'),
          _Feat(Icons.auto_awesome_rounded,
              'Halal meal planner built to your calories, or suhoor + iftar'),
          _Feat(Icons.insights_rounded,
              '90-day insights, weight forecast, data export'),
          _Feat(Icons.nightlight_round,
              'Fasting planner: log, streak and sunnah days'),
          _Feat(Icons.notifications_active_rounded,
              'Smart reminders: suhoor, iftar and streak guard'),
          _Feat(Icons.photo_camera_rounded,
              'Unlimited AI food & body photo analysis (vs 3 free/day)'),
          _Feat(Icons.qr_code_scanner_rounded,
              'Unlimited halal scans (vs 3 free/day)'),
          _Feat(Icons.monitor_weight_rounded,
              'Body fat % + muscle mass + lean body mass'),
          _Feat(Icons.fitness_center_rounded,
              'Every premium workout + Ramadan + postnatal plans'),
          _Feat(Icons.terrain_rounded,
              'Full Ascent journey + weekly review'),
        ];

"""
    return s[:a] + new + s[b:]
edit('lib/features/paywall/paywall_screen.dart', paywall_features, 'paywall: real, bigger feature list')

# ── patch_android.py: icon, permissions, receivers ─────────
def android_patch(s):
    if 'PATCH_V58_NOTIF' in s: return s
    add = r'''

# PATCH_V58_NOTIF ─ make local notifications actually work on Android
# 1. a monochrome status-bar icon (the launcher icon renders as a white square)
_icon_xml = (
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="24dp" android:height="24dp"\n'
    '    android:viewportWidth="24" android:viewportHeight="24">\n'
    '    <path android:fillColor="#FFFFFFFF"\n'
    '        android:pathData="M21,12.79A9,9 0 1,1 11.21,3 7,7 0 0,0 21,12.79z"/>\n'
    '</vector>\n')
_drawable_dir = "android/app/src/main/res/drawable"
os.makedirs(_drawable_dir, exist_ok=True)
with open(_drawable_dir + "/ic_stat_halal.xml", "w", encoding="utf-8") as _f:
    _f.write(_icon_xml)
print("Notification icon written: drawable/ic_stat_halal.xml")

# 2. permissions + receivers (the plugin's own manifest declares them too; an
#    identical explicit declaration merges cleanly and removes any doubt)
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as _f: _m = _f.read()
    _changed = False
    for _perm in ("RECEIVE_BOOT_COMPLETED", "VIBRATE"):
        if "android.permission." + _perm not in _m:
            _m = _m.replace("<application",
                '    <uses-permission android:name="android.permission.' + _perm + '" />\n    <application', 1)
            _changed = True
    if "ScheduledNotificationReceiver" not in _m:
        _recv = (
            '    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />\n'
            '    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">\n'
            '        <intent-filter>\n'
            '            <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
            '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
            '            <action android:name="android.intent.action.QUICKBOOT_POWERON"/>\n'
            '            <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>\n'
            '        </intent-filter>\n'
            '    </receiver>\n')
        _m = _m.replace("</application>", _recv + "    </application>", 1)
        _changed = True
    if _changed:
        with open(manifest_path, "w") as _f: _f.write(_m)
        print("AndroidManifest: notification permissions + receivers added")
    else:
        print("AndroidManifest: notification setup already present")
'''
    return s.rstrip('\n') + '\n' + add
edit('patch_android.py', android_patch, 'android: icon, permissions, receivers')

# ── pubspec ────────────────────────────────────────────────
edit('pubspec.yaml', lambda s: re.sub(r'^version:\s*[\d.]+\+\d+', 'version: 1.16.0+30', s, count=1, flags=re.M) if re.search(r'^version:', s, re.M) else None, 'version -> 1.16.0+30')

print()
balance_check([
    'lib/core/notification_service.dart', 'lib/core/fasting_calendar.dart', 'lib/main.dart',
    'lib/core/shell.dart', 'lib/core/router.dart', 'lib/features/settings/settings_screen.dart',
    'lib/features/home/home_screen.dart', 'lib/features/paywall/paywall_screen.dart',
    'lib/features/profile/profile_screen.dart',
    'lib/features/premium/premium_ui.dart', 'lib/features/premium/notification_center_screen.dart',
    'lib/features/premium/insights_screen.dart', 'lib/features/premium/coach_screen.dart',
    'lib/features/premium/fasting_planner_screen.dart', 'lib/features/premium/meal_plan_screen.dart',
    'lib/features/premium/premium_hub_screen.dart',
])
print('\nDone: %d ok, %d skipped.' % (ok, skip))
if skip: print('Skipped steps mean an anchor moved - send me the dump and I will re-anchor.')
print('Next: git add -A && git commit -m "v58: premium studio + working notifications" && git push')
