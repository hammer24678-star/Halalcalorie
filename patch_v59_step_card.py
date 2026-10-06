#!/usr/bin/env python3
"""
patch_v59_step_card.py
======================
HalalCalorie v59 - LIVE STEP CARD in the notification shade.
Run from the repo root (after v58):

    python3 patch_v59_step_card.py

Safe to run twice. No new Flutter dependencies.

WHAT YOU GET
  * An animated, branded step card in the notification shade (collapsed + expanded)
    drawn with your logo and the app font. Counts with the hardware step sensor in a
    foreground service, so it keeps going with the app closed.
  * Themes: Green / White / Random (8 colourways, shuffle daily / each start / manual)
    / Auto (follows app dark-light, gold in Ramadan). 6 accent colours.
  * Styles: Orbit (logo in a progress ring), Stride (squircle + thick bar), Zen.
  * Alive: glowing ring + orbiting comet, shimmer on the bar, floating sparkles,
    footprints, count-up numbers, ripple on every step, confetti + notification at goal.
    Animates only while the screen is on; respects "remove animations".
  * Settings > Step Card: live preview (same native renderer as the real card), goal,
    stride, kcal/step, what to show, animation level, status-bar icon, lock screen,
    start after reboot, permission/health checks.
  * The card always shows the same number as the Health tab (app pushes its count).

NEW FILES   lib/core/step_card_service.dart, lib/features/health/step_card_screen.dart,
            android_extra/** (Kotlin + layouts, copied into android/ by patch_android.py in CI)
EDITS       router (/step-card), settings (tile), providers (push steps), main (bootstrap),
            patch_android.py (copy Kotlin, manifest service/permissions, MainActivity)
pubspec -> 1.17.0+31

PLAY CONSOLE: the card is a foreground service of type "health". Declare it in
App content > Foreground service permissions (purpose: live step counter, user-visible).
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
    old = open(path(p), encoding='utf-8').read() if os.path.exists(path(p)) else None
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
                bad += 1; print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
    print('  all balanced' if not bad else '  !! fix the files above before building')

print('== v59 ==')

write('lib/core/step_card_service.dart', r'''// step_card_service.dart — HalalCalorie v59 (PATCH_V59_STEPCARD)
//
// The live step card in the notification shade. The card itself is drawn and
// kept alive by a native foreground service (StepCardService.kt) that counts
// steps with the hardware sensor, so it keeps ticking when the app is closed.
// This file owns the settings, pushes them across, and feeds the app's own
// step number to the card so both always agree.
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database.dart';
import 'l10n.dart';
import 'notification_service.dart';

class StepCardConfig {
  final Map<String, Object> _m;
  const StepCardConfig._(this._m);

  static const Map<String, Object> defaults = {
    'enabled': false,
    'theme': 'green', // green | white | random | auto
    'style': 'orbit', // orbit | stride | zen
    'accent': 'default',
    'shuffle': 'day', // day | launch | manual
    'goal': 10000,
    'anim': 2, // 0 off, 1 calm, 2 lively, 3 max
    'kcalPerStep': 0.04, // matches the Health tab
    'strideCm': 76.0, // 0.00076 km per step, matches the Health tab
    'particles': true,
    'shimmer': true,
    'footprints': true,
    'celebrate': true,
    'showKcal': true,
    'showDist': true,
    'showPct': true,
    'showWeek': true,
    'showMsg': true,
    'arabicDigits': false,
    'statusIcon': true,
    'lock': 'full', // full | hide
    'bootStart': true,
  };

  factory StepCardConfig.defaultConfig() => StepCardConfig._(Map<String, Object>.of(defaults));

  bool b(String k) => (_m[k] as bool?) ?? (defaults[k] as bool);
  int i(String k) => (_m[k] as int?) ?? (defaults[k] as int);
  double d(String k) => ((_m[k] as num?) ?? (defaults[k] as num)).toDouble();
  String s(String k) => (_m[k] as String?) ?? (defaults[k] as String);

  StepCardConfig set(String k, Object v) =>
      StepCardConfig._(<String, Object>{..._m, k: v});

  Map<String, Object> toMap() => Map<String, Object>.of(_m);

  static Future<StepCardConfig> load() async {
    final p = await SharedPreferences.getInstance();
    final m = <String, Object>{};
    defaults.forEach((k, def) {
      final key = 'sc_$k';
      Object? v;
      if (def is bool) {
        v = p.getBool(key);
      } else if (def is int) {
        v = p.getInt(key);
      } else if (def is double) {
        v = p.getDouble(key);
      } else if (def is String) {
        v = p.getString(key);
      }
      m[k] = v ?? def;
    });
    return StepCardConfig._(m);
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    for (final e in _m.entries) {
      final key = 'sc_${e.key}';
      final v = e.value;
      if (v is bool) {
        await p.setBool(key, v);
      } else if (v is int) {
        await p.setInt(key, v);
      } else if (v is double) {
        await p.setDouble(key, v);
      } else if (v is String) {
        await p.setString(key, v);
      }
    }
  }
}

enum StepCardEnable { ok, needActivity, needActivityForever, failed }

class StepCardService {
  static const MethodChannel _ch = MethodChannel('hc/stepcard');
  static final ValueNotifier<StepCardConfig> config =
      ValueNotifier<StepCardConfig>(StepCardConfig.defaultConfig());

  static bool _inited = false;
  static bool _isDark = true;
  static bool _ramadan = false;
  static String _lang = 'ar';
  static Timer? _ctxTimer;
  static Timer? _pushTimer;
  static int _pendingSteps = -1;
  static int _lastPushed = -1;

  // ── setup ─────────────────────────────────────────────────
  static Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'route') {
        await consumeRoute();
      }
      return null;
    });
    config.value = await StepCardConfig.load();
  }

  /// Runs at launch (and after onboarding). Existing users who already granted
  /// the activity permission get the card switched on once; they can turn it
  /// off in Settings and it stays off.
  static Future<void> bootstrap() async {
    await init();
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool('sc_decided') ?? false)) {
      var granted = false;
      try {
        final s = await Permission.activityRecognition.status;
        granted = s.isGranted || s.isLimited;
      } catch (_) {}
      if (!granted) return; // decided later, once the permission exists
      await p.setBool('sc_decided', true);
      config.value = config.value.set('enabled', true);
      await config.value.save();
    }
    await apply();
    unawaited(seedHistory());
    await consumeRoute();
  }

  static Future<void> onResume() async {
    if (!_inited) return;
    await consumeRoute();
    if (config.value.b('enabled')) {
      // Re-asserts the service (and clears a swipe-away) every time the app opens.
      await apply();
    }
  }

  static Future<void> consumeRoute() async {
    try {
      final r = await _ch.invokeMethod<String>('consumeRoute');
      if (r != null && r.isNotEmpty) NotificationService.pendingRoute.value = r;
    } catch (_) {}
  }

  /// Called on every rebuild of the app shell; cheap unless something changed.
  static void setAppContext({required bool isDark, required String lang, required bool ramadan}) {
    if (isDark == _isDark && lang == _lang && ramadan == _ramadan) return;
    _isDark = isDark;
    _lang = lang;
    _ramadan = ramadan;
    if (!_inited || !config.value.b('enabled')) return;
    _ctxTimer?.cancel();
    _ctxTimer = Timer(const Duration(milliseconds: 500), () => apply());
  }

  // ── pushing ───────────────────────────────────────────────
  static Map<String, Object> _payload(StepCardConfig c) {
    final m = c.toMap();
    StepCardConfig.defaults.forEach((k, def) {
      final v = m[k];
      if (def is double && v is num) m[k] = v.toDouble();
      if (def is int && v is num) m[k] = v.toInt();
    });
    m['lang'] = _lang;
    m['dark'] = _isDark;
    m['ramadan'] = _ramadan;
    m['strings'] = _stringsJson(_lang);
    return m;
  }

  /// Sends the settings to the native side and starts or stops the service.
  static Future<void> apply() async {
    final c = config.value;
    try {
      await _ch.invokeMethod('configure', _payload(c));
      if (c.b('enabled')) {
        await _ch.invokeMethod('start');
      } else {
        await _ch.invokeMethod('stop');
      }
    } catch (e) {
      debugPrint('StepCard apply: $e');
    }
  }

  static Future<void> update(StepCardConfig c) async {
    config.value = c;
    await c.save();
    await apply();
  }

  static Future<void> set(String key, Object value) => update(config.value.set(key, value));

  /// The app's step number, so the card always matches the Health tab.
  static void pushSteps(int steps) {
    if (!_inited || !config.value.b('enabled')) return;
    _pendingSteps = steps;
    if (_pushTimer != null) return;
    _pushTimer = Timer(const Duration(milliseconds: 1200), () async {
      _pushTimer = null;
      final n = _pendingSteps;
      if (n < 0 || n == _lastPushed) return;
      _lastPushed = n;
      try {
        await _ch.invokeMethod('pushSteps', n);
      } catch (_) {}
    });
  }

  /// Gives the weekly chart something to show on day one, from the app database.
  static Future<void> seedHistory() async {
    try {
      final d = await AppDatabase.db;
      final rows = await d.query('daily_summary',
          columns: ['date_key', 'steps'], orderBy: 'date_key DESC', limit: 9);
      final parts = <String>[];
      for (final r in rows) {
        final k = r['date_key'];
        final v = r['steps'];
        if (k is String && v is int && v > 0) parts.add('$k:$v');
      }
      if (parts.isNotEmpty) await _ch.invokeMethod('seedHistory', parts.join(','));
    } catch (_) {}
  }

  // ── enabling ──────────────────────────────────────────────
  static Future<StepCardEnable> enable() async {
    await init();
    try {
      var s = await Permission.activityRecognition.status;
      if (!(s.isGranted || s.isLimited)) {
        s = await Permission.activityRecognition.request();
      }
      if (!(s.isGranted || s.isLimited)) {
        return s.isPermanentlyDenied
            ? StepCardEnable.needActivityForever
            : StepCardEnable.needActivity;
      }
      try {
        await NotificationService.requestPermissions();
      } catch (_) {}
      final p = await SharedPreferences.getInstance();
      await p.setBool('sc_decided', true);
      await update(config.value.set('enabled', true));
      return StepCardEnable.ok;
    } catch (_) {
      return StepCardEnable.failed;
    }
  }

  static Future<void> disable() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('sc_decided', true);
    await update(config.value.set('enabled', false));
  }

  // ── status, preview, tests ────────────────────────────────
  static Future<Map<String, dynamic>> status() async {
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('status');
      return r ?? <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<Uint8List?> preview({
    required bool expanded,
    required int tMs,
    int steps = -1,
    int sinceCelebMs = 99999,
    int sinceStepMs = 99999,
  }) async {
    try {
      return await _ch.invokeMethod<Uint8List>('preview', <String, Object>{
        'expanded': expanded,
        't': tMs,
        'steps': steps,
        'sinceCelebMs': sinceCelebMs,
        'sinceStepMs': sinceStepMs,
      });
    } catch (_) {
      return null;
    }
  }

  static Future<void> shuffleNow() async {
    try {
      await _ch.invokeMethod('shuffle');
    } catch (_) {}
  }

  static Future<bool> testGoal() async {
    try {
      return (await _ch.invokeMethod<bool>('testGoal')) ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── localised strings for the card ────────────────────────
  static String _stringsJson(String l) {
    String t(String ar, String en, [String fr = '', String tr = '', String ms = '', String id = '', String ur = '']) =>
        tLang(l, ar, en, fr, tr, ms, id, ur);
    final m = <String, String>{
      'today': t('خطوات اليوم', "TODAY'S STEPS", "PAS D'AUJOURD'HUI", 'BUGÜNKÜ ADIMLAR', 'LANGKAH HARI INI', 'LANGKAH HARI INI', 'آج کے قدم'),
      'steps': t('خطوة', 'steps', 'pas', 'adım', 'langkah', 'langkah', 'قدم'),
      'kcal': t('سعرة', 'kcal', 'kcal', 'kcal', 'kcal', 'kkal', 'kcal'),
      'km': t('كم', 'km', 'km', 'km', 'km', 'km', 'کلومیٹر'),
      'toGo': t('{n} متبقية', '{n} to go', '{n} restants', '{n} kaldı', '{n} lagi', '{n} lagi', '{n} باقی'),
      'goalDone': t('تم تحقيق الهدف', 'Goal reached', 'Objectif atteint', 'Hedefe ulaşıldı', 'Sasaran tercapai', 'Target tercapai', 'ہدف مکمل'),
      'm0': t('كل خطوة تُحسب', 'Every step counts', 'Chaque pas compte', 'Her adım sayılır', 'Setiap langkah bermakna', 'Setiap langkah berarti', 'ہر قدم اہم ہے'),
      'm1': t('بداية رائعة، واصل', 'Great start, keep moving', 'Bon début, continue', 'Harika başlangıç, devam', 'Permulaan hebat, teruskan', 'Awal yang bagus, lanjutkan', 'شاندار آغاز، جاری رکھیں'),
      'm2': t('اقتربت من المنتصف', 'Halfway there', 'Presque à mi-chemin', 'Yolun yarısı geride', 'Separuh jalan', 'Setengah jalan', 'آدھا راستہ طے'),
      'm3': t('اقتربت من الهدف!', 'Almost there!', 'Presque arrivé !', 'Neredeyse tamam!', 'Hampir sampai!', 'Hampir sampai!', 'تقریباً پہنچ گئے!'),
      'celebTitle': t('🎉 حققت هدف اليوم!', '🎉 Daily goal reached!', "🎉 Objectif du jour atteint !", '🎉 Günlük hedef tamam!', '🎉 Sasaran harian tercapai!', '🎉 Target harian tercapai!', '🎉 آج کا ہدف مکمل!'),
      'celebBody': t('{n} خطوة اليوم — بارك الله فيك', '{n} steps today — well done', "{n} pas aujourd'hui — bravo", 'Bugün {n} adım — aferin', '{n} langkah hari ini — syabas', '{n} langkah hari ini — kerja bagus', 'آج {n} قدم — شاباش'),
    };
    final sb = StringBuffer('{');
    var first = true;
    m.forEach((k, v) {
      if (!first) sb.write(',');
      first = false;
      sb.write('"$k":"${v.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"');
    });
    sb.write('}');
    return sb.toString();
  }
}
''')

write('lib/features/health/step_card_screen.dart', r'''// step_card_screen.dart — HalalCalorie v59 (PATCH_V59_STEPCARD)
// Settings for the live step card. The preview at the top is rendered by the
// same native code that draws the real notification, so what you tune here is
// exactly what appears in the shade.
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import '../../core/l10n.dart';
import '../../core/notification_service.dart';
import '../../core/providers.dart';
import '../../core/step_card_service.dart';
import '../../core/theme.dart';
import '../premium/premium_ui.dart';

class StepCardScreen extends ConsumerStatefulWidget {
  const StepCardScreen({super.key});
  @override
  ConsumerState<StepCardScreen> createState() => _StepCardScreenState();
}

class _StepCardScreenState extends ConsumerState<StepCardScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> _status = <String, dynamic>{};
  final Stopwatch _clock = Stopwatch()..start();
  double _demo = -1; // preview progress 0..1.2, negative = live steps
  int _walkAt = 0;
  int _celebAt = 0;
  double _stride = 76;
  double _kcal = 0.04;
  String? _note;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    StepCardService.init().then((_) {
      if (!mounted) return;
      final c = StepCardService.config.value;
      setState(() {
        _stride = c.d('strideCm');
        _kcal = c.d('kcalPerStep');
      });
      _refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final s = await StepCardService.status();
    if (mounted) setState(() => _status = s);
  }

  int get _now => _clock.elapsedMilliseconds;

  Future<void> _toggleMaster(bool v, String Function(String, String) t) async {
    if (!v) {
      await StepCardService.disable();
      await _refresh();
      return;
    }
    final r = await StepCardService.enable();
    if (!mounted) return;
    switch (r) {
      case StepCardEnable.ok:
        setState(() => _note = null);
        break;
      case StepCardEnable.needActivity:
        setState(() => _note = t(
            'يلزم إذن «النشاط البدني» لعدّ الخطوات.',
            'The Physical activity permission is needed to count steps.'));
        break;
      case StepCardEnable.needActivityForever:
        setState(() => _note = t(
            'الإذن مرفوض نهائيًا. فعّله من إعدادات التطبيق.',
            'Permission was refused for good. Turn it on in app settings.'));
        await openAppSettings();
        break;
      case StepCardEnable.failed:
        setState(() => _note = t('تعذّر التشغيل. حاول مرة أخرى.', 'Could not start. Try again.'));
        break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final th = PTheme(isDark);
    String t(String ar, String en) => tLang(lang, ar, en);

    return ValueListenableBuilder<StepCardConfig>(
      valueListenable: StepCardService.config,
      builder: (context, cfg, _) {
        final on = cfg.b('enabled');
        final goal = cfg.i('goal');
        final theme = cfg.s('theme');
        final demoSteps = _demo >= 0 ? (goal * _demo).round() : -1;

        Widget row({
          required IconData icon,
          required String title,
          String? sub,
          required Widget trailing,
          Color color = AppColors.halalGreen,
        }) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                PBadge(icon, size: 38, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: pText(th.text, 14, w: FontWeight.w800)),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(sub, style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.35)),
                    ],
                  ]),
                ),
                trailing,
              ]),
            );

        Widget sw(IconData icon, String title, String? sub, String key,
                {bool enabled = true}) =>
            row(
              icon: icon,
              title: title,
              sub: sub,
              trailing: Switch(
                value: cfg.b(key),
                activeColor: AppColors.halalGreen,
                onChanged: enabled ? (v) => StepCardService.set(key, v) : null,
              ),
            );

        Widget chips(String key, List<List<String>> opts, {bool enabled = true}) {
          final cur = cfg.s(key);
          return Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in opts)
                  GestureDetector(
                    onTap: enabled ? () => StepCardService.set(key, o[0]) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: cur == o[0]
                            ? AppColors.halalGreen.withOpacity(0.18)
                            : th.cardAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: cur == o[0] ? AppColors.halalGreen : th.border,
                            width: cur == o[0] ? 1.4 : 0.8),
                      ),
                      child: Text(o[1],
                          style: pText(cur == o[0] ? AppColors.halalGreen : th.text, 13,
                              w: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          );
        }

        Widget divider() => Divider(height: 1, color: th.border);

        // ── status ────────────────────────────────────────
        final perm = _status['permission'] == true;
        final notif = _status['notifications'] != false;
        final running = _status['running'] == true;
        final sensor = _status['sensor'] != false;
        final err = (_status['error'] as String?) ?? '';

        Widget statusLine(bool ok, String good, String bad, VoidCallback? fix, String fixLabel) =>
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    size: 18, color: ok ? AppColors.halalGreen : AppColors.doubtOrange),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(ok ? good : bad,
                        style: pText(th.text, 12.5, w: FontWeight.w600))),
                if (!ok && fix != null)
                  GestureDetector(
                    onTap: fix,
                    child: Text(fixLabel, style: pText(kGold, 12.5, w: FontWeight.w900)),
                  ),
              ]),
            );

        return Scaffold(
          backgroundColor: th.bg,
          appBar: AppBar(
            title: Text(t('بطاقة الخطوات', 'Step Card'),
                style: pText(th.text, 18, w: FontWeight.w900)),
            backgroundColor: th.bg,
            elevation: 0,
            iconTheme: IconThemeData(color: th.text),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
            children: [
              // ── live preview ───────────────────────────
              _PreviewBox(
                isDark: isDark,
                clock: _clock,
                demoSteps: demoSteps,
                walkAt: _walkAt,
                celebAt: _celebAt,
                configTick: cfg.toMap().toString(),
                note: t('معاينة حيّة — هي نفسها بطاقة الإشعارات',
                    'Live preview — the very card that appears in your shade'),
                th: th,
              ),
              const SizedBox(height: 10),
              PCard(
                th: th,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(t('تجربة التقدّم', 'Try progress'),
                        style: pText(th.text, 13.5, w: FontWeight.w800)),
                    const Spacer(),
                    Text(_demo < 0 ? t('مباشر', 'Live') : '${(_demo * 100).round()}%',
                        style: pText(kGold, 13, w: FontWeight.w900)),
                  ]),
                  Slider(
                    value: _demo < 0 ? 0 : _demo.clamp(0.0, 1.2).toDouble(),
                    min: 0,
                    max: 1.2,
                    activeColor: AppColors.halalGreen,
                    onChanged: (v) => setState(() => _demo = v),
                  ),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _MiniBtn(t('خطوة!', 'Walk!'), Icons.directions_walk_rounded, th,
                        () => setState(() => _walkAt = _now)),
                    _MiniBtn(t('احتفال بالهدف', 'Goal party'), Icons.celebration_rounded, th, () {
                      setState(() {
                        _demo = 1.0;
                        _celebAt = _now;
                      });
                    }),
                    _MiniBtn(t('مباشر', 'Live'), Icons.sensors_rounded, th,
                        () => setState(() => _demo = -1)),
                  ]),
                  const SizedBox(height: 6),
                ]),
              ),

              // ── master + status ────────────────────────
              PSection(t('التشغيل', 'POWER'), th),
              PCard(
                th: th,
                gold: on,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  row(
                    icon: Icons.directions_walk_rounded,
                    title: t('بطاقة الخطوات الحيّة', 'Live step card'),
                    sub: t('عدّاد خطوات متحرك في شريط الإشعارات يعمل حتى والتطبيق مغلق',
                        'An animated step counter in your notification shade, even with the app closed'),
                    trailing: Switch(
                      value: on,
                      activeColor: AppColors.halalGreen,
                      onChanged: (v) => _toggleMaster(v, t),
                    ),
                  ),
                  if (on) ...[
                    divider(),
                    const SizedBox(height: 4),
                    statusLine(perm, t('إذن النشاط البدني مفعّل', 'Physical activity allowed'),
                        t('إذن النشاط البدني ناقص', 'Physical activity permission missing'),
                        () => _toggleMaster(true, t), t('سماح', 'Allow')),
                    statusLine(notif, t('الإشعارات مفعّلة', 'Notifications allowed'),
                        t('الإشعارات محظورة من النظام', 'Notifications blocked by the system'),
                        () async {
                      final ok = await NotificationService.requestPermissions();
                      if (!ok) await NotificationService.openSystemSettings();
                      await _refresh();
                    }, t('إصلاح', 'Fix')),
                    statusLine(running, t('البطاقة تعمل الآن', 'Card is running'),
                        t('البطاقة غير شغّالة', 'Card is not running'), () async {
                      await StepCardService.apply();
                      await Future<void>.delayed(const Duration(milliseconds: 600));
                      await _refresh();
                    }, t('تشغيل', 'Start')),
                    if (!sensor)
                      statusLine(false, '', t('لا يوجد حساس خطوات؛ يُستخدم عدّاد التطبيق فقط',
                          'No step sensor on this phone; the app counter is used'), null, ''),
                    if (err.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
                        child: Text(err, style: pText(th.muted, 10.5, w: FontWeight.w500)),
                      ),
                    const SizedBox(height: 6),
                  ],
                ]),
              ),
              if (_note != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
                  child: Text(_note!, style: pText(AppColors.doubtOrange, 12.5, w: FontWeight.w700)),
                ),

              // ── theme ──────────────────────────────────
              PSection(t('السمة', 'THEME'), th),
              PCard(
                th: th,
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  chips('theme', [
                    ['green', t('أخضر', 'Green')],
                    ['white', t('أبيض', 'White')],
                    ['random', t('عشوائي', 'Random')],
                    ['auto', t('تلقائي', 'Auto')],
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                        theme == 'random'
                            ? t('ألوان جديدة تُختار لك — ليلية وفاتحة', 'A fresh colourway picked for you — dark and light')
                            : theme == 'auto'
                                ? t('يتبع وضع التطبيق (داكن/فاتح) ويتحول للذهبي في رمضان',
                                    'Follows the app mode (dark/light) and turns gold in Ramadan')
                                : t('ثابت على هذه السمة', 'Stays on this theme'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500)),
                  ),
                  if (theme == 'random') ...[
                    divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                      child: Text(t('تبديل اللون', 'Shuffle'),
                          style: pText(th.text, 13, w: FontWeight.w800)),
                    ),
                    chips('shuffle', [
                      ['day', t('كل يوم', 'Every day')],
                      ['launch', t('كل تشغيل', 'Every start')],
                      ['manual', t('يدويًا', 'Manual')],
                    ]),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: PGoldButton(
                        label: t('بدّل الآن', 'Shuffle now'),
                        icon: Icons.shuffle_rounded,
                        outlined: true,
                        onTap: () async {
                          await StepCardService.shuffleNow();
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ] else ...[
                    divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Text(t('لون التمييز', 'Accent'),
                          style: pText(th.text, 13, w: FontWeight.w800)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Wrap(spacing: 12, runSpacing: 10, children: [
                        for (final a in _accents)
                          GestureDetector(
                            onTap: () => StepCardService.set('accent', a.key),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: a.value,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: cfg.s('accent') == a.key ? th.text : Colors.transparent,
                                    width: 2.4),
                              ),
                              child: cfg.s('accent') == a.key
                                  ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                                  : null,
                            ),
                          ),
                      ]),
                    ),
                  ],
                ]),
              ),

              // ── style ──────────────────────────────────
              PSection(t('التصميم', 'STYLE'), th),
              PCard(
                th: th,
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  chips('style', [
                    ['orbit', t('حلقة', 'Orbit')],
                    ['stride', t('انسيابي', 'Stride')],
                    ['zen', t('هادئ', 'Zen')],
                  ]),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Text(
                        cfg.s('style') == 'orbit'
                            ? t('الشعار داخل حلقة تقدّم متوهجة', 'Your logo inside a glowing progress ring')
                            : cfg.s('style') == 'stride'
                                ? t('شعار مربع وشريط تقدّم سميك', 'Squircle logo with a thick progress bar')
                                : t('رقم ضخم ونظيف بلا زخارف', 'One huge number, nothing else'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500)),
                  ),
                ]),
              ),

              // ── content ────────────────────────────────
              PSection(t('ما يظهر', 'WHAT IT SHOWS'), th),
              PCard(
                th: th,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  sw(Icons.local_fire_department_rounded, t('السعرات', 'Calories'), null, 'showKcal'),
                  divider(),
                  sw(Icons.route_rounded, t('المسافة', 'Distance'), null, 'showDist'),
                  divider(),
                  sw(Icons.track_changes_rounded, t('نسبة الهدف', 'Goal percent'), null, 'showPct'),
                  divider(),
                  sw(Icons.bar_chart_rounded, t('رسم الأسبوع', 'Weekly chart'),
                      t('يظهر عند توسيع الإشعار', 'Shown when the card is expanded'), 'showWeek'),
                  divider(),
                  sw(Icons.chat_bubble_outline_rounded, t('رسائل التشجيع', 'Encouragement line'), null, 'showMsg'),
                  divider(),
                  sw(Icons.pin_rounded, t('أرقام عربية ٠١٢', 'Arabic-Indic digits ٠١٢'), null, 'arabicDigits'),
                ]),
              ),

              // ── animation ──────────────────────────────
              PSection(t('الحركة', 'ANIMATION'), th),
              PCard(
                th: th,
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final o in <List<Object>>[
                        [0, t('بدون', 'Off')],
                        [1, t('هادئ', 'Calm')],
                        [2, t('حيّ', 'Lively')],
                        [3, t('أقصى', 'Max')],
                      ])
                        GestureDetector(
                          onTap: () => StepCardService.set('anim', o[0] as int),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: cfg.i('anim') == o[0]
                                  ? AppColors.halalGreen.withOpacity(0.18)
                                  : th.cardAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: cfg.i('anim') == o[0] ? AppColors.halalGreen : th.border,
                                  width: cfg.i('anim') == o[0] ? 1.4 : 0.8),
                            ),
                            child: Text(o[1] as String,
                                style: pText(
                                    cfg.i('anim') == o[0] ? AppColors.halalGreen : th.text, 13,
                                    w: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Text(
                        t('تتحرك البطاقة فقط والشاشة مضاءة لتوفير البطارية. تحترم إعداد «إزالة الحركة» في النظام.',
                            'The card only animates while the screen is on, to save battery. It respects the system "remove animations" setting.'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.4)),
                  ),
                  divider(),
                  sw(Icons.auto_awesome_rounded, t('شرارات متطايرة', 'Floating sparkles'), null, 'particles',
                      enabled: cfg.i('anim') > 0),
                  divider(),
                  sw(Icons.waves_rounded, t('لمعان شريط التقدّم', 'Progress shimmer'), null, 'shimmer',
                      enabled: cfg.i('anim') > 0),
                  divider(),
                  sw(Icons.directions_walk_rounded, t('آثار الأقدام', 'Footprints'), null, 'footprints',
                      enabled: cfg.i('anim') > 0),
                  divider(),
                  sw(Icons.celebration_rounded, t('إشعار عند بلوغ الهدف', 'Goal celebration'),
                      t('إشعار قصير مع قصاصات ملونة على البطاقة', 'A short notification plus confetti on the card'),
                      'celebrate'),
                ]),
              ),

              // ── goal & body ────────────────────────────
              PSection(t('الهدف والجسم', 'GOAL & BODY'), th),
              PCard(
                th: th,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  row(
                    icon: Icons.flag_rounded,
                    title: t('هدف الخطوات اليومي', 'Daily step goal'),
                    color: kGold,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      _RoundBtn(Icons.remove_rounded, th,
                          () => StepCardService.set('goal', (goal - 500).clamp(1000, 50000))),
                      SizedBox(
                        width: 70,
                        child: Text('$goal',
                            textAlign: TextAlign.center,
                            style: pText(th.text, 15, w: FontWeight.w900)),
                      ),
                      _RoundBtn(Icons.add_rounded, th,
                          () => StepCardService.set('goal', (goal + 500).clamp(1000, 50000))),
                    ]),
                  ),
                  divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(children: [
                      Text(t('طول الخطوة', 'Stride length'),
                          style: pText(th.text, 13.5, w: FontWeight.w800)),
                      const Spacer(),
                      Text('${_stride.round()} cm', style: pText(kGold, 13, w: FontWeight.w900)),
                    ]),
                  ),
                  Slider(
                    value: _stride.clamp(50.0, 110.0).toDouble(),
                    min: 50,
                    max: 110,
                    divisions: 60,
                    activeColor: AppColors.halalGreen,
                    onChanged: (v) => setState(() => _stride = v),
                    onChangeEnd: (v) => StepCardService.set('strideCm', v.roundToDouble()),
                  ),
                  divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Row(children: [
                      Text(t('سعرات الخطوة', 'Calories per step'),
                          style: pText(th.text, 13.5, w: FontWeight.w800)),
                      const Spacer(),
                      Text(_kcal.toStringAsFixed(3), style: pText(kGold, 13, w: FontWeight.w900)),
                    ]),
                  ),
                  Slider(
                    value: _kcal.clamp(0.02, 0.08).toDouble(),
                    min: 0.02,
                    max: 0.08,
                    divisions: 60,
                    activeColor: AppColors.halalGreen,
                    onChanged: (v) => setState(() => _kcal = v),
                    onChangeEnd: (v) => StepCardService.set('kcalPerStep', double.parse(v.toStringAsFixed(3))),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _stride = 76;
                            _kcal = 0.04;
                          });
                          StepCardService.update(cfg.set('strideCm', 76.0).set('kcalPerStep', 0.04));
                        },
                        child: Text(t('مطابقة تبويب الصحة (٧٦ سم، ٠٫٠٤)', 'Match the Health tab (76 cm, 0.04)'),
                            style: pText(kGold, 12, w: FontWeight.w800)),
                      ),
                    ),
                  ),
                ]),
              ),

              // ── notification behaviour ─────────────────
              PSection(t('سلوك الإشعار', 'NOTIFICATION'), th),
              PCard(
                th: th,
                padding: EdgeInsets.zero,
                child: Column(children: [
                  sw(Icons.notifications_none_rounded, t('أيقونة في شريط الحالة', 'Status-bar icon'),
                      t('أوقفها لإخفاء الأيقونة والإبقاء على البطاقة', 'Turn off to hide the icon but keep the card'),
                      'statusIcon'),
                  divider(),
                  row(
                    icon: Icons.lock_outline_rounded,
                    title: t('على شاشة القفل', 'On the lock screen'),
                    trailing: DropdownButton<String>(
                      value: cfg.s('lock'),
                      underline: const SizedBox.shrink(),
                      dropdownColor: th.card,
                      style: pText(th.text, 13, w: FontWeight.w800),
                      items: [
                        DropdownMenuItem(value: 'full', child: Text(t('إظهار', 'Show'))),
                        DropdownMenuItem(value: 'hide', child: Text(t('إخفاء', 'Hide'))),
                      ],
                      onChanged: (v) {
                        if (v != null) StepCardService.set('lock', v);
                      },
                    ),
                  ),
                  divider(),
                  sw(Icons.restart_alt_rounded, t('التشغيل بعد إعادة التشغيل', 'Start after reboot'), null, 'bootStart'),
                  divider(),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: PGoldButton(
                      label: t('جرّب إشعار الهدف', 'Test goal notification'),
                      icon: Icons.bolt_rounded,
                      outlined: true,
                      onTap: () async {
                        final ok = await StepCardService.testGoal();
                        if (mounted) {
                          setState(() => _note = ok
                              ? null
                              : t('شغّل البطاقة أولًا لتجربة الإشعار.', 'Turn the card on first to test it.'));
                        }
                      },
                    ),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 0),
                child: Text(
                    t('اسحب البطاقة جانبًا لإخفائها؛ تعود عند فتح التطبيق. بعض الهواتف توقف الخدمات في الخلفية — استثنِ التطبيق من توفير البطارية.',
                        'Swipe the card away to hide it; it returns when you open the app. Some phones stop background services — exempt the app from battery optimisation.'),
                    style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.45)),
              ),
            ],
          ),
        );
      },
    );
  }

  static final List<MapEntry<String, Color>> _accents = <MapEntry<String, Color>>[
    const MapEntry('default', AppColors.halalGreen),
    const MapEntry('mint', Color(0xFF5EEAD4)),
    const MapEntry('gold', Color(0xFFDBA75D)),
    const MapEntry('ocean', Color(0xFF6FB3FF)),
    const MapEntry('violet', Color(0xFFBC8CFF)),
    const MapEntry('rose', Color(0xFFFF7BAC)),
    const MapEntry('sunset', Color(0xFFFF8A5B)),
  ];
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final PTheme th;
  final VoidCallback onTap;
  const _MiniBtn(this.label, this.icon, this.th, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: th.cardAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: th.border, width: 0.8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: kGold),
            const SizedBox(width: 6),
            Text(label, style: pText(th.text, 12.5, w: FontWeight.w800)),
          ]),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final PTheme th;
  final VoidCallback onTap;
  const _RoundBtn(this.icon, this.th, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: th.cardAlt,
            shape: BoxShape.circle,
            border: Border.all(color: th.border, width: 0.8),
          ),
          child: Icon(icon, size: 18, color: th.text),
        ),
      );
}

/// Polls the native renderer a few times a second and shows what it draws.
class _PreviewBox extends StatefulWidget {
  final bool isDark;
  final Stopwatch clock;
  final int demoSteps;
  final int walkAt;
  final int celebAt;
  final String configTick;
  final String note;
  final PTheme th;
  const _PreviewBox({
    required this.isDark,
    required this.clock,
    required this.demoSteps,
    required this.walkAt,
    required this.celebAt,
    required this.configTick,
    required this.note,
    required this.th,
  });
  @override
  State<_PreviewBox> createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<_PreviewBox> with WidgetsBindingObserver {
  Timer? _timer;
  bool _busy = false;
  bool _active = true;
  Uint8List? _small;
  Uint8List? _big;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(milliseconds: 220), (_) => _tick());
    _tick();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
  }

  Future<void> _tick() async {
    if (_busy || !_active || !mounted) return;
    _busy = true;
    try {
      final now = widget.clock.elapsedMilliseconds;
      final since = widget.walkAt == 0 ? 99999 : now - widget.walkAt;
      final celeb = widget.celebAt == 0 ? 99999 : now - widget.celebAt;
      final s = await StepCardService.preview(
          expanded: false, tMs: now, steps: widget.demoSteps, sinceCelebMs: celeb, sinceStepMs: since);
      final b = await StepCardService.preview(
          expanded: true, tMs: now, steps: widget.demoSteps, sinceCelebMs: celeb, sinceStepMs: since);
      if (mounted) setState(() { _small = s ?? _small; _big = b ?? _big; });
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = widget.th;
    final shade = widget.isDark ? const Color(0xFF1C1F24) : const Color(0xFFE6E9ED);
    Widget img(Uint8List? b) => b == null
        ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        : Image.memory(b, gaplessPlayback: true, fit: BoxFit.fitWidth, filterQuality: FilterQuality.medium);
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: shade,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: th.border, width: 0.8),
        ),
        child: Column(children: [
          img(_small),
          const SizedBox(height: 10),
          img(_big),
        ]),
      ),
      const SizedBox(height: 8),
      Text(widget.note, style: pText(th.muted, 11.5, w: FontWeight.w500)),
    ]);
  }
}
''')

write('android_extra/kotlin/StepCardCore.kt', r'''package com.ihsanstudio.halalcalorie

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

// ─────────────────────────────────────────────────────────────
//  StepCardCore.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  Config + palettes + the persistent step state behind the
//  live step card in the notification shade.
// ─────────────────────────────────────────────────────────────

class CardConfig(p: SharedPreferences) {
    val enabled = p.getBoolean("enabled", false)
    val theme = p.getString("theme", "green") ?: "green"        // green | white | random | auto
    val style = p.getString("style", "orbit") ?: "orbit"        // orbit | stride | zen
    val accent = p.getString("accent", "default") ?: "default"
    val goal = num(p, "goal", 10000f).toInt().coerceIn(1000, 100000)
    val kcalPerStep = num(p, "kcalPerStep", 0.04f).coerceIn(0.005f, 0.2f)
    val strideCm = num(p, "strideCm", 76f).coerceIn(30f, 150f)
    val anim = num(p, "anim", 2f).toInt().coerceIn(0, 3)        // 0 off, 1 calm, 2 lively, 3 max
    val particles = p.getBoolean("particles", true)
    val shimmer = p.getBoolean("shimmer", true)
    val footprints = p.getBoolean("footprints", true)
    val celebrate = p.getBoolean("celebrate", true)
    val showKcal = p.getBoolean("showKcal", true)
    val showDist = p.getBoolean("showDist", true)
    val showPct = p.getBoolean("showPct", true)
    val showWeek = p.getBoolean("showWeek", true)
    val showMsg = p.getBoolean("showMsg", true)
    val arabicDigits = p.getBoolean("arabicDigits", false)
    val statusIcon = p.getBoolean("statusIcon", true)
    val lock = p.getString("lock", "full") ?: "full"            // full | hide
    val bootStart = p.getBoolean("bootStart", true)
    val lang = p.getString("lang", "ar") ?: "ar"
    val dark = p.getBoolean("dark", true)
    val ramadan = p.getBoolean("ramadan", false)
    val shuffle = p.getString("shuffle", "day") ?: "day"        // day | launch | manual
    private val strings: JSONObject = try {
        JSONObject(p.getString("strings", "{}") ?: "{}")
    } catch (e: Exception) { JSONObject() }

    val rtl: Boolean get() = lang == "ar" || lang == "ur"
    val strideKm: Float get() = strideCm / 100000f

    fun s(key: String, def: String): String {
        val v = strings.optString(key, "")
        return if (v.isEmpty()) def else v
    }

    companion object {
        const val FILE = "hc_step_card"
        /** Reads a number whatever numeric type Dart happened to send. */
        fun num(p: SharedPreferences, key: String, def: Float): Float = when (val v = p.all[key]) {
            is Float -> v
            is Int -> v.toFloat()
            is Long -> v.toFloat()
            is Double -> v.toFloat()
            else -> def
        }
        fun load(ctx: Context): CardConfig =
            CardConfig(ctx.getSharedPreferences(FILE, Context.MODE_PRIVATE))
    }
}

class Pal(
    val name: String,
    val bgTop: Int, val bgBottom: Int,
    val glow1: Int, val glow2: Int,
    val accent: Int, val accent2: Int,
    val text: Int, val sub: Int,
    val track: Int, val chip: Int, val plate: Int,
    val border: Int, val spark: Int,
    val light: Boolean
)

object Palettes {
    private fun c(hex: Long) = hex.toInt()

    val GREEN = Pal("green",
        c(0xFF06201A), c(0xFF0F4030), c(0xFF3FB950), c(0xFF78E08E),
        c(0xFF3FD07A), c(0xFF9CF2B8), c(0xFFFFFFFF), c(0xB8E3F4E9),
        c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF0B2A20), c(0x40A7F3C4), c(0xFFD8FFE6), false)

    val WHITE = Pal("white",
        c(0xFFFFFFFF), c(0xFFE6F4E9), c(0xFF9BE3B0), c(0xFFD4F5DD),
        c(0xFF1F9D4A), c(0xFF52D17C), c(0xFF10241A), c(0xFF5C6B62),
        c(0x1F10241A), c(0x14238636), c(0xFFFFFFFF), c(0x33238636), c(0xFF52D17C), true)

    val RAMADAN = Pal("ramadan",
        c(0xFF0B0919), c(0xFF241A52), c(0xFF6B4FD8), c(0xFFE8B84B),
        c(0xFFE8B84B), c(0xFFF6DD94), c(0xFFF3ECD6), c(0xB8D9C79B),
        c(0x33E8B84B), c(0x22E8B84B), c(0xFF150F2C), c(0x55E8B84B), c(0xFFFFE9A8), false)

    private val POOL = listOf(
        Pal("ocean",
            c(0xFF061B2E), c(0xFF0B3A5C), c(0xFF2F8CFF), c(0xFF6FB3FF),
            c(0xFF6FB3FF), c(0xFFB5DBFF), c(0xFFFFFFFF), c(0xB8D6E8FA),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF081F33), c(0x406FB3FF), c(0xFFD6EBFF), false),
        Pal("violet",
            c(0xFF14082B), c(0xFF2E1A5C), c(0xFF7B4DFF), c(0xFFBC8CFF),
            c(0xFFBC8CFF), c(0xFFE3CFFF), c(0xFFFFFFFF), c(0xB8E6DAF8),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF180B33), c(0x40BC8CFF), c(0xFFEBDDFF), false),
        Pal("sunset",
            c(0xFF2B0B12), c(0xFF5C2230), c(0xFFFF6B4A), c(0xFFFFB36B),
            c(0xFFFF8A5B), c(0xFFFFC796), c(0xFFFFFFFF), c(0xB8F8DCD2),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF30101A), c(0x40FF8A5B), c(0xFFFFE0CC), false),
        Pal("gold",
            c(0xFF1F1606), c(0xFF40300D), c(0xFFDBA75D), c(0xFFF0CF98),
            c(0xFFDBA75D), c(0xFFF4DBA8), c(0xFFFFF6E3), c(0xB8EAD9B4),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF261B08), c(0x40DBA75D), c(0xFFFFEFC9), false),
        Pal("rose",
            c(0xFF2A0A1E), c(0xFF55203F), c(0xFFFF5C9A), c(0xFFFFA3C7),
            c(0xFFFF7BAC), c(0xFFFFC0D8), c(0xFFFFFFFF), c(0xB8F5D7E4),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF300E24), c(0x40FF7BAC), c(0xFFFFD9E8), false),
        Pal("aurora",
            c(0xFF04161F), c(0xFF0C3F3C), c(0xFF22D3BE), c(0xFF8CF0E0),
            c(0xFF5EEAD4), c(0xFFB2F6EA), c(0xFFFFFFFF), c(0xB8D3F2EC),
            c(0x33FFFFFF), c(0x22FFFFFF), c(0xFF062229), c(0x405EEAD4), c(0xFFD4FBF3), false),
        Pal("sky",
            c(0xFFF5FAFF), c(0xFFD9ECFF), c(0xFF8EC5FF), c(0xFFCBE4FF),
            c(0xFF1E7BE0), c(0xFF5AA9FF), c(0xFF0E2238), c(0xFF55677C),
            c(0x1F0E2238), c(0x141E7BE0), c(0xFFFFFFFF), c(0x331E7BE0), c(0xFF5AA9FF), true),
        Pal("blush",
            c(0xFFFFF8FA), c(0xFFFFE1EB), c(0xFFFFA9C6), c(0xFFFFD3E2),
            c(0xFFD81B60), c(0xFFFF6FA0), c(0xFF3A0F20), c(0xFF7A5463),
            c(0x1F3A0F20), c(0x14D81B60), c(0xFFFFFFFF), c(0x33D81B60), c(0xFFFF6FA0), true)
    )

    fun poolSize() = POOL.size

    // name -> (dark-card pair, light-card pair)
    private val ACCENTS: Map<String, Pair<IntArray, IntArray>> = mapOf(
        "mint" to Pair(intArrayOf(c(0xFF5EEAD4), c(0xFFB2F6EA)), intArrayOf(c(0xFF0E9F8A), c(0xFF3CCFB8))),
        "gold" to Pair(intArrayOf(c(0xFFDBA75D), c(0xFFF4DBA8)), intArrayOf(c(0xFFB27A1C), c(0xFFE0A94C))),
        "ocean" to Pair(intArrayOf(c(0xFF6FB3FF), c(0xFFB5DBFF)), intArrayOf(c(0xFF1E7BE0), c(0xFF5AA9FF))),
        "violet" to Pair(intArrayOf(c(0xFFBC8CFF), c(0xFFE3CFFF)), intArrayOf(c(0xFF7B3FE4), c(0xFFA878FF))),
        "rose" to Pair(intArrayOf(c(0xFFFF7BAC), c(0xFFFFC0D8)), intArrayOf(c(0xFFD81B60), c(0xFFFF6FA0))),
        "sunset" to Pair(intArrayOf(c(0xFFFF8A5B), c(0xFFFFC796)), intArrayOf(c(0xFFE0561F), c(0xFFFF9A63)))
    )

    private fun recolor(base: Pal, accentKey: String): Pal {
        val pair = ACCENTS[accentKey] ?: return base
        val a = if (base.light) pair.second else pair.first
        return Pal(base.name + "-" + accentKey,
            base.bgTop, base.bgBottom, a[0], a[1], a[0], a[1],
            base.text, base.sub, base.track, base.chip, base.plate, base.border, a[1], base.light)
    }

    fun resolve(cfg: CardConfig, randIdx: Int): Pal {
        val base: Pal = when (cfg.theme) {
            "white" -> WHITE
            "random" -> POOL[((randIdx % POOL.size) + POOL.size) % POOL.size]
            "auto" -> if (cfg.ramadan) RAMADAN else if (cfg.dark) GREEN else WHITE
            else -> GREEN
        }
        // The accent override only applies to the two house themes.
        return if (cfg.theme == "green" || cfg.theme == "white" || cfg.theme == "auto")
            recolor(base, cfg.accent) else base
    }

    fun withAlpha(color: Int, a: Float): Int =
        Color.argb((Color.alpha(color) * a.coerceIn(0f, 1f)).toInt(),
            Color.red(color), Color.green(color), Color.blue(color))
}

/** Today's steps, persisted so the card survives the app (and the service) being killed. */
object StepState {
    private const val FILE = "hc_step_state"
    private lateinit var sp: SharedPreferences
    private var ready = false
    private var lastPersist = 0L
    private var dirtyEvents = 0

    var day = ""
    var base = 0
    var baseSensor = -1L
    var lastSensor = -1L
    var useDetector = false
    var lastStepAt = 0L
    var celebDay = ""
    var celebAt = 0L
    var randIdx = 0
    var randDay = ""
    var error = ""
    private val hist = LinkedHashMap<String, Int>()

    fun dayKey(cal: Calendar = Calendar.getInstance()): String {
        val m = cal.get(Calendar.MONTH) + 1
        val d = cal.get(Calendar.DAY_OF_MONTH)
        return cal.get(Calendar.YEAR).toString() + "-" + (if (m < 10) "0$m" else "$m") + "-" + (if (d < 10) "0$d" else "$d")
    }

    @Synchronized fun init(ctx: Context) {
        if (ready) return
        sp = ctx.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        day = sp.getString("day", "") ?: ""
        base = sp.getInt("base", 0)
        baseSensor = sp.getLong("baseSensor", -1L)
        lastSensor = sp.getLong("lastSensor", -1L)
        lastStepAt = 0L
        celebDay = sp.getString("celebDay", "") ?: ""
        celebAt = sp.getLong("celebAt", 0L)
        randIdx = sp.getInt("randIdx", 0)
        randDay = sp.getString("randDay", "") ?: ""
        error = sp.getString("error", "") ?: ""
        hist.clear()
        (sp.getString("hist", "") ?: "").split(",").forEach {
            val i = it.lastIndexOf(':')
            if (i > 0) {
                val n = it.substring(i + 1).toIntOrNull()
                if (n != null) hist[it.substring(0, i)] = n
            }
        }
        ready = true
        rollIfNeeded()
    }

    @Synchronized fun steps(): Int {
        val delta = if (!useDetector && baseSensor >= 0 && lastSensor >= baseSensor) (lastSensor - baseSensor) else 0L
        return (base + delta).coerceIn(0L, 999999L).toInt()
    }

    /** Rolls to a new day if the date changed. Returns true when it did. */
    @Synchronized fun rollIfNeeded(): Boolean {
        val today = dayKey()
        if (day == today) return false
        if (day.isNotEmpty()) hist[day] = steps()
        day = today
        base = 0
        baseSensor = if (lastSensor >= 0) lastSensor else -1L
        trimHist()
        persist(true)
        return true
    }

    /** A hardware step-counter reading. Returns true when the step total changed. */
    @Synchronized fun onSensor(v: Long): Boolean {
        rollIfNeeded()
        val before = steps()
        if (baseSensor < 0) baseSensor = v
        if (v < baseSensor) baseSensor = 0L          // the counter restarts at boot
        lastSensor = v
        val after = steps()
        if (after != before) {
            lastStepAt = System.currentTimeMillis()
            hist[day] = after
            dirtyEvents++
            persist(false)
        }
        return after != before
    }

    @Synchronized fun onDetector(): Boolean {
        rollIfNeeded()
        useDetector = true
        base += 1
        lastStepAt = System.currentTimeMillis()
        hist[day] = steps()
        dirtyEvents++
        persist(false)
        return true
    }

    /** The app's own number wins: the card must read exactly what the app shows. */
    @Synchronized fun push(n: Int) {
        rollIfNeeded()
        val v = n.coerceIn(0, 999999)
        val before = steps()
        base = v
        baseSensor = if (lastSensor >= 0) lastSensor else -1L
        if (v > before) lastStepAt = System.currentTimeMillis()
        hist[day] = v
        persist(true)
    }

    /** Seeds days the card never saw (from the app database). Never overwrites. */
    @Synchronized fun seedHistory(csv: String) {
        csv.split(",").forEach {
            val i = it.lastIndexOf(':')
            if (i > 0) {
                val k = it.substring(0, i)
                val n = it.substring(i + 1).toIntOrNull()
                if (n != null && k != day && !hist.containsKey(k)) hist[k] = n
            }
        }
        trimHist()
        persist(true)
    }

    /** The last 7 days ending today, oldest first. */
    @Synchronized fun week(): IntArray {
        val out = IntArray(7)
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -6)
        for (i in 0 until 7) {
            val k = dayKey(cal)
            out[i] = if (k == day) steps() else (hist[k] ?: 0)
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return out
    }

    @Synchronized fun markCelebrated(now: Long) {
        celebDay = day
        celebAt = now
        persist(true)
    }

    @Synchronized fun shuffle(poolSize: Int) {
        var n = (Math.random() * poolSize).toInt() % poolSize
        if (n == randIdx) n = (n + 1) % poolSize
        randIdx = n
        randDay = dayKey()
        persist(true)
    }

    @Synchronized fun recordError(e: String) {
        error = e
        persist(true)
    }

    private fun trimHist() {
        while (hist.size > 21) {
            val first = hist.keys.minOrNull() ?: break
            hist.remove(first)
        }
    }

    @Synchronized fun persist(force: Boolean) {
        if (!ready) return
        val now = System.currentTimeMillis()
        if (!force && dirtyEvents < 15 && now - lastPersist < 30000L) return
        dirtyEvents = 0
        lastPersist = now
        val sb = StringBuilder()
        for ((k, v) in hist) { if (sb.isNotEmpty()) sb.append(','); sb.append(k).append(':').append(v) }
        sp.edit()
            .putString("day", day).putInt("base", base)
            .putLong("baseSensor", baseSensor).putLong("lastSensor", lastSensor)
            .putString("celebDay", celebDay).putLong("celebAt", celebAt)
            .putInt("randIdx", randIdx).putString("randDay", randDay)
            .putString("error", error)
            .putString("hist", sb.toString())
            .apply()
    }

    fun narrowDay(offsetFromToday: Int, lang: String): String {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, offsetFromToday)
        return try {
            SimpleDateFormat("EEEEE", Locale(lang)).format(Date(cal.timeInMillis))
        } catch (e: Exception) { "" }
    }
}
''')

write('android_extra/kotlin/StepCardRenderer.kt', r'''package com.ihsanstudio.halalcalorie

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient
import android.graphics.Typeface
import java.util.Locale

// ─────────────────────────────────────────────────────────────
//  StepCardRenderer.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  Draws the whole card into a Bitmap, so the notification shade
//  shows exactly the same polished artwork the settings preview does.
//  Everything is a pure function of (config, palette, time, steps).
// ─────────────────────────────────────────────────────────────

class RenderState(
    val cfg: CardConfig,
    val pal: Pal,
    val shown: Float,          // the animated (counting-up) step number
    val steps: Int,            // the true step count
    val t: Float,              // seconds, drives every animation
    val sinceStepMs: Long,
    val sinceCelebMs: Long,
    val week: IntArray,
    val anim: Int              // effective animation level 0..3
)

class StepCardRenderer(private val ctx: Context) {
    companion object {
        const val W = 900
        const val H_SMALL = 156
        const val GOLD1 = 0xFFFFC94D.toInt()
        const val GOLD2 = 0xFFFFF0B8.toInt()
    }

    private val fontBold: Typeface = loadFont("AligarhArabicFREEPERSONALUSE-Bold.otf", Typeface.DEFAULT_BOLD)
    private val fontHeavy: Typeface = loadFont("AligarhArabicFREEPERSONALUSE-ExtraBold.otf", fontBold)
    private var logo: Bitmap? = loadLogo()

    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }
    private val tp = Paint(Paint.ANTI_ALIAS_FLAG)
    private val bmpPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val path = Path()
    private val rect = RectF()

    // per-frame working state
    private lateinit var c: Canvas
    private lateinit var st: RenderState
    private var h = H_SMALL
    private var rtl = false
    private var acc = 0
    private var acc2 = 0
    private var done = false
    private var pct = 0f

    private fun loadFont(file: String, fallback: Typeface): Typeface = try {
        Typeface.createFromAsset(ctx.assets, "flutter_assets/assets/fonts/$file")
    } catch (e: Exception) { fallback }

    private fun loadLogo(): Bitmap? = try {
        ctx.assets.open("flutter_assets/assets/logo.png").use { ins ->
            val raw = BitmapFactory.decodeStream(ins)
            if (raw == null) null else {
                val side = minOf(raw.width, raw.height)
                val target = 256
                val sq = Bitmap.createBitmap(raw, (raw.width - side) / 2, (raw.height - side) / 2, side, side)
                if (side > target) Bitmap.createScaledBitmap(sq, target, target, true) else sq
            }
        }
    } catch (e: Exception) { null }

    fun heightFor(expanded: Boolean, cfg: CardConfig): Int =
        if (!expanded) H_SMALL else if (cfg.showWeek) 560 else 420

    // ── public ────────────────────────────────────────────────
    fun render(expanded: Boolean, state: RenderState, reuse: Bitmap?): Bitmap {
        val hh = heightFor(expanded, state.cfg)
        val bmp = if (reuse != null && reuse.width == W && reuse.height == hh && reuse.isMutable) reuse
                  else Bitmap.createBitmap(W, hh, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(Color.TRANSPARENT)
        c = Canvas(bmp)
        st = state
        h = hh
        rtl = state.cfg.rtl
        pct = (state.steps.toFloat() / state.cfg.goal).coerceIn(0f, 1f)
        done = state.steps >= state.cfg.goal
        acc = if (done) GOLD1 else state.pal.accent
        acc2 = if (done) GOLD2 else state.pal.accent2

        drawBackground()
        if (state.anim >= 1) drawAmbient()
        if (state.sinceCelebMs in 0..9000L) drawConfetti()

        if (expanded) layoutExpanded() else layoutCollapsed()
        drawBorder()
        return bmp
    }

    fun describe(state: RenderState): String {
        val cfg = state.cfg
        val sb = StringBuilder()
        sb.append(fmtInt(state.steps)).append(' ').append(cfg.s("steps", "steps"))
        if (cfg.showKcal) sb.append(", ").append(fmtInt((state.steps * cfg.kcalPerStep).toInt())).append(' ').append(cfg.s("kcal", "kcal"))
        if (cfg.showDist) sb.append(", ").append(fmtDec(state.steps * cfg.strideKm)).append(' ').append(cfg.s("km", "km"))
        sb.append(", ").append((state.steps * 100 / cfg.goal)).append("%")
        return sb.toString()
    }

    // ── formatting ────────────────────────────────────────────
    private fun digits(s: String): String {
        if (!st.cfg.arabicDigits) return s
        val sb = StringBuilder()
        for (ch in s) {
            sb.append(when (ch) {
                in '0'..'9' -> ('\u0660' + (ch - '0'))
                ',' -> '\u066C'
                '.' -> '\u066B'
                else -> ch
            })
        }
        return sb.toString()
    }
    private fun fmtInt(n: Int): String = digits(String.format(Locale.US, "%,d", n))
    private fun fmtDec(x: Float): String = digits(String.format(Locale.US, "%.1f", x))

    // ── drawing helpers ───────────────────────────────────────
    /** Run [block] in LTR coordinates; mirrored for right-to-left languages. */
    private inline fun gfx(block: () -> Unit) {
        c.save()
        if (rtl) { c.translate(W.toFloat(), 0f); c.scale(-1f, 1f) }
        block()
        c.restore()
    }

    /** align: 0 = start edge, 1 = end edge, 2 = centre — all in LTR coordinates. Returns the text width. */
    private fun text(s: String, x: Float, y: Float, size: Float, color: Int,
                     align: Int = 0, maxW: Float = 0f, heavy: Boolean = false): Float {
        tp.typeface = if (heavy) fontHeavy else fontBold
        tp.textSize = size
        tp.color = color
        tp.shader = null
        var w = tp.measureText(s)
        if (maxW > 0f && w > maxW) { tp.textSize = size * maxW / w; w = tp.measureText(s) }
        val ax = if (rtl) W - x else x
        tp.textAlign = when (align) {
            2 -> Paint.Align.CENTER
            1 -> if (rtl) Paint.Align.LEFT else Paint.Align.RIGHT
            else -> if (rtl) Paint.Align.RIGHT else Paint.Align.LEFT
        }
        c.drawText(s, ax, y, tp)
        return w
    }

    private fun measure(s: String, size: Float, heavy: Boolean = false): Float {
        tp.typeface = if (heavy) fontHeavy else fontBold
        tp.textSize = size
        return tp.measureText(s)
    }

    private fun rnd(i: Int, k: Int): Float {
        val x = Math.sin(i * 127.1 + k * 311.7) * 43758.5453
        return (x - Math.floor(x)).toFloat()
    }

    private fun glow(x: Float, y: Float, r: Float, color: Int, a: Float) {
        fill.shader = RadialGradient(x, y, r, Palettes.withAlpha(color, a), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawCircle(x, y, r, fill)
        fill.shader = null
    }

    // ── background, ambience, border ──────────────────────────
    private fun drawBackground() {
        val p = st.pal
        val radius = if (h <= H_SMALL) 46f else 58f
        rect.set(0f, 0f, W.toFloat(), h.toFloat())
        path.reset()
        path.addRoundRect(rect, radius, radius, Path.Direction.CW)
        c.save()
        c.clipPath(path)
        fill.shader = LinearGradient(0f, 0f, W * 0.7f, h.toFloat(), p.bgTop, p.bgBottom, Shader.TileMode.CLAMP)
        c.drawRect(rect, fill)
        fill.shader = null
        val t = if (st.anim >= 1) st.t else 0f
        val big = h * 1.15f
        glow(W * (0.18f + 0.10f * Math.sin(t * 0.45).toFloat()), h * (0.30f + 0.10f * Math.cos(t * 0.35).toFloat()),
             big, if (done) GOLD1 else p.glow1, if (p.light) 0.30f else 0.34f)
        glow(W * (0.88f + 0.06f * Math.cos(t * 0.40).toFloat()), h * (0.85f + 0.08f * Math.sin(t * 0.30).toFloat()),
             big * 0.9f, if (done) GOLD2 else p.glow2, if (p.light) 0.35f else 0.20f)
        // soft top sheen
        fill.shader = LinearGradient(0f, 0f, 0f, h * 0.55f,
            Palettes.withAlpha(Color.WHITE, if (p.light) 0.55f else 0.10f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawRect(0f, 0f, W.toFloat(), h * 0.55f, fill)
        fill.shader = null
        c.restore()
    }

    private fun drawBorder() {
        val radius = if (h <= H_SMALL) 46f else 58f
        rect.set(1.5f, 1.5f, W - 1.5f, h - 1.5f)
        line.shader = null
        line.strokeWidth = 3f
        line.color = Palettes.withAlpha(if (done) GOLD1 else st.pal.border, if (done) 0.55f else 1f)
        c.drawRoundRect(rect, radius, radius, line)
    }

    private fun drawAmbient() {
        val cfg = st.cfg
        val p = st.pal
        if (cfg.style != "zen" && cfg.particles) {
            val n = intArrayOf(0, 7, 13, 20)[st.anim.coerceIn(0, 3)]
            for (i in 0 until n) {
                val speed = 0.035f + 0.05f * rnd(i, 1)
                val u = (st.t * speed + rnd(i, 2)) % 1f
                val x = rnd(i, 3) * W
                val y = h * (1.05f - 1.1f * u)
                val r = 2.2f + 3.6f * rnd(i, 4)
                val tw = 0.5f + 0.5f * Math.sin(st.t * (1.2 + rnd(i, 5) * 1.8) + i).toFloat()
                val edge = Math.sin(Math.PI * u).toFloat()
                fill.color = Palettes.withAlpha(p.spark, (0.10f + 0.38f * tw) * edge * (if (p.light) 0.8f else 1f))
                c.drawCircle(x, y, r, fill)
            }
        }
        if (cfg.footprints && cfg.style != "zen" && st.anim >= 1) {
            val n = 6
            for (i in 0 until n) {
                val u = (st.t * 0.10f + i / n.toFloat()) % 1f
                val side = if (i % 2 == 0) 1f else -1f
                val x = W * (0.50f + 0.46f * u)
                val y = h * (0.92f - 0.80f * u) + side * 26f
                val a = Math.sin(Math.PI * u).toFloat() * (if (p.light) 0.10f else 0.13f)
                footprint(x, y, 30f, -28f, Palettes.withAlpha(if (p.light) p.accent else Color.WHITE, a), side < 0f)
            }
        }
    }

    private fun drawConfetti() {
        val s = st.sinceCelebMs / 1000f
        val colors = intArrayOf(GOLD1, GOLD2, st.pal.accent2, 0xFFFF7BAC.toInt(), 0xFF6FB3FF.toInt(), Color.WHITE)
        val fade = (1f - ((st.sinceCelebMs - 6500f) / 2500f)).coerceIn(0f, 1f)
        for (i in 0 until 46) {
            val x0 = rnd(i, 7) * W
            val sway = 38f * Math.sin(s * (2.0 + rnd(i, 8) * 3.0) + i).toFloat()
            val fall = 150f + 230f * rnd(i, 9)
            val y = -30f + s * fall - 160f * rnd(i, 10)
            if (y < -20f || y > h + 20f) continue
            fill.color = Palettes.withAlpha(colors[i % colors.size], 0.95f * fade)
            c.save()
            c.translate(x0 + sway, y)
            c.rotate(s * (180f + 300f * rnd(i, 11)) + i * 17f)
            val w = 8f + 9f * rnd(i, 12)
            c.drawRect(-w / 2, -w / 4, w / 2, w / 4, fill)
            c.restore()
        }
    }

    // ── icons (unit boxes centred on cx, cy) ──────────────────
    private fun footprint(cx: Float, cy: Float, size: Float, rot: Float, color: Int, flip: Boolean) {
        c.save()
        c.translate(cx, cy)
        c.rotate(rot)
        if (flip) c.scale(-1f, 1f)
        fill.color = color
        rect.set(-0.24f * size, -0.02f * size, 0.24f * size, 0.62f * size)
        c.drawOval(rect, fill)
        c.drawCircle(-0.26f * size, -0.28f * size, 0.10f * size, fill)
        c.drawCircle(-0.09f * size, -0.40f * size, 0.10f * size, fill)
        c.drawCircle(0.09f * size, -0.42f * size, 0.10f * size, fill)
        c.drawCircle(0.26f * size, -0.32f * size, 0.09f * size, fill)
        c.restore()
    }

    private fun iconFlame(cx: Float, cy: Float, s: Float, color: Int) {
        c.save()
        c.translate(cx - s / 2, cy - s / 2)
        c.scale(s, s)
        path.reset()
        path.moveTo(0.50f, 0.00f)
        path.cubicTo(0.56f, 0.24f, 0.90f, 0.38f, 0.88f, 0.68f)
        path.cubicTo(0.86f, 0.88f, 0.68f, 1.00f, 0.50f, 1.00f)
        path.cubicTo(0.32f, 1.00f, 0.14f, 0.88f, 0.12f, 0.68f)
        path.cubicTo(0.10f, 0.52f, 0.24f, 0.42f, 0.30f, 0.26f)
        path.cubicTo(0.38f, 0.38f, 0.42f, 0.42f, 0.46f, 0.44f)
        path.cubicTo(0.50f, 0.30f, 0.44f, 0.14f, 0.50f, 0.00f)
        path.close()
        fill.color = color
        c.drawPath(path, fill)
        fill.color = Palettes.withAlpha(Color.WHITE, 0.45f)
        c.drawCircle(0.5f, 0.74f, 0.17f, fill)
        c.restore()
    }

    private fun iconRoute(cx: Float, cy: Float, s: Float, color: Int) {
        c.save()
        c.translate(cx - s / 2, cy - s / 2)
        c.scale(s, s)
        path.reset()
        path.moveTo(0.22f, 0.80f)
        path.cubicTo(0.22f, 0.40f, 0.78f, 0.62f, 0.78f, 0.22f)
        line.shader = null
        line.color = color
        line.strokeWidth = 0.11f
        c.drawPath(path, line)
        fill.color = color
        c.drawCircle(0.22f, 0.80f, 0.13f, fill)
        c.drawCircle(0.78f, 0.22f, 0.13f, fill)
        c.restore()
    }

    private fun iconTarget(cx: Float, cy: Float, s: Float, color: Int) {
        line.shader = null
        line.color = color
        line.strokeWidth = s * 0.12f
        c.drawCircle(cx, cy, s * 0.40f, line)
        fill.color = color
        c.drawCircle(cx, cy, s * 0.16f, fill)
    }

    private fun iconFlag(cx: Float, cy: Float, s: Float, color: Int) {
        c.save()
        c.translate(cx - s / 2, cy - s / 2)
        c.scale(s, s)
        line.shader = null
        line.color = color
        line.strokeWidth = 0.10f
        c.drawLine(0.24f, 0.08f, 0.24f, 0.96f, line)
        path.reset()
        path.moveTo(0.26f, 0.10f)
        path.cubicTo(0.46f, 0.00f, 0.60f, 0.22f, 0.86f, 0.12f)
        path.lineTo(0.86f, 0.56f)
        path.cubicTo(0.60f, 0.66f, 0.46f, 0.44f, 0.26f, 0.54f)
        path.close()
        fill.color = color
        c.drawPath(path, fill)
        c.restore()
    }

    // ── emblem: the logo, framed ──────────────────────────────
    private fun drawLogoIn(cx: Float, cy: Float, r: Float, squircle: Boolean) {
        val bob = if (st.anim >= 1) (1f + 0.025f * Math.sin(st.t * 2.2).toFloat()) else 1f
        c.save()
        c.translate(cx, cy)
        c.scale(bob, bob)
        path.reset()
        if (squircle) { rect.set(-r, -r, r, r); path.addRoundRect(rect, r * 0.42f, r * 0.42f, Path.Direction.CW) }
        else path.addCircle(0f, 0f, r, Path.Direction.CW)
        c.clipPath(path)
        fill.color = st.pal.plate
        c.drawRect(-r, -r, r, r, fill)
        val lg = logo
        if (lg != null) {
            rect.set(-r, -r, r, r)
            c.drawBitmap(lg, null, rect, bmpPaint)
        } else {
            footprint(0f, -r * 0.1f, r * 1.1f, -18f, acc, false)
        }
        // glassy highlight
        fill.shader = LinearGradient(0f, -r, 0f, r * 0.2f, Palettes.withAlpha(Color.WHITE, 0.20f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
        c.drawRect(-r, -r, r, r, fill)
        fill.shader = null
        c.restore()
    }

    /** kind 0 = ring + logo, 1 = squircle plate, 2 = small calm ring. */
    private fun drawEmblem(cx: Float, cy: Float, r: Float, kind: Int) {
        gfx {
            val t = if (st.anim >= 1) st.t else 0f
            val pulse = 0.5f + 0.5f * Math.sin(t * 2.4).toFloat()
            glow(cx, cy, r * 1.9f, acc, (if (st.pal.light) 0.16f else 0.20f) + 0.12f * pulse)
            if (kind == 1) {
                drawLogoIn(cx, cy, r, true)
                line.shader = null
                line.strokeWidth = 3f
                line.color = Palettes.withAlpha(acc2, 0.55f)
                rect.set(cx - r, cy - r, cx + r, cy + r)
                c.drawRoundRect(rect, r * 0.42f, r * 0.42f, line)
                return@gfx
            }
            val stroke = r * (if (kind == 0) 0.17f else 0.14f)
            val ringR = if (kind == 0) r else r
            val inner = ringR - stroke * 1.15f
            // track
            line.shader = null
            line.strokeWidth = stroke
            line.color = st.pal.track
            c.drawCircle(cx, cy, ringR, line)
            // progress
            val sweep = 360f * pct
            rect.set(cx - ringR, cy - ringR, cx + ringR, cy + ringR)
            if (sweep > 0.5f) {
                c.save()
                c.rotate(-90f, cx, cy)
                val sg = SweepGradient(cx, cy, intArrayOf(acc2, acc, acc), floatArrayOf(0f, (pct).coerceAtLeast(0.02f), 1f))
                line.shader = sg
                line.strokeWidth = stroke
                c.drawArc(rect, 0f, sweep, false, line)
                line.shader = null
                c.restore()
                // glowing head
                val ang = Math.toRadians((-90f + sweep).toDouble())
                val hx = cx + ringR * Math.cos(ang).toFloat()
                val hy = cy + ringR * Math.sin(ang).toFloat()
                glow(hx, hy, stroke * (1.5f + 0.5f * pulse), Color.WHITE, 0.55f)
                fill.color = Color.WHITE
                c.drawCircle(hx, hy, stroke * 0.30f, fill)
            }
            // a walker orbiting the ring
            if (st.anim >= 2 && !done && kind == 0) {
                for (k in 0 until 5) {
                    val a = Math.toRadians((st.t * 55f - k * 7f).toDouble())
                    val ox = cx + (ringR + stroke * 0.95f) * Math.cos(a).toFloat()
                    val oy = cy + (ringR + stroke * 0.95f) * Math.sin(a).toFloat()
                    fill.color = Palettes.withAlpha(acc2, 0.85f - k * 0.17f)
                    c.drawCircle(ox, oy, stroke * (0.26f - k * 0.035f), fill)
                }
            }
            // ripple when a step just landed
            if (st.anim >= 1 && st.sinceStepMs in 0..1100L) {
                val e = st.sinceStepMs / 1100f
                line.strokeWidth = 4f
                line.color = Palettes.withAlpha(acc2, (1f - e) * 0.8f)
                c.drawCircle(cx, cy, ringR + stroke + e * r * 0.55f, line)
            }
            drawLogoIn(cx, cy, inner, false)
        }
    }

    // ── progress bar ──────────────────────────────────────────
    private fun drawBar(x: Float, y: Float, w: Float, bh: Float) {
        gfx {
            val rad = bh / 2
            rect.set(x, y, x + w, y + bh)
            fill.shader = null
            fill.color = st.pal.track
            c.drawRoundRect(rect, rad, rad, fill)
            val fw = (w * pct).coerceAtLeast(if (pct > 0f) bh else 0f)
            if (fw > 0f) {
                rect.set(x, y, x + fw, y + bh)
                c.save()
                path.reset(); path.addRoundRect(rect, rad, rad, Path.Direction.CW)
                c.clipPath(path)
                fill.shader = LinearGradient(x, 0f, x + w, 0f, acc2, acc, Shader.TileMode.CLAMP)
                c.drawRect(rect, fill)
                fill.shader = null
                if (st.cfg.shimmer && st.anim >= 1) {
                    val band = bh * 5f
                    val u = (st.t * 0.42f) % 1.6f - 0.3f
                    val sx = x + (fw + band) * u - band * 0.5f
                    fill.shader = LinearGradient(sx, 0f, sx + band, 0f,
                        intArrayOf(Color.TRANSPARENT, Palettes.withAlpha(Color.WHITE, 0.75f), Color.TRANSPARENT),
                        floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP)
                    c.drawRect(rect, fill)
                    fill.shader = null
                }
                // top gloss
                fill.shader = LinearGradient(0f, y, 0f, y + bh, Palettes.withAlpha(Color.WHITE, 0.35f), Color.TRANSPARENT, Shader.TileMode.CLAMP)
                c.drawRect(x, y, x + fw, y + bh * 0.55f, fill)
                fill.shader = null
                c.restore()
                // glowing head
                val pulse = 0.5f + 0.5f * Math.sin((if (st.anim >= 1) st.t else 0f) * 3.0).toFloat()
                glow(x + fw - rad, y + rad, bh * (1.2f + 0.5f * pulse), acc2, 0.55f)
            }
            // milestones
            for (m in 1..3) {
                val mx = x + w * m / 4f
                val passed = pct >= m / 4f
                fill.color = if (passed) Palettes.withAlpha(Color.WHITE, 0.85f) else Palettes.withAlpha(st.pal.text, 0.22f)
                c.drawCircle(mx, y + rad, bh * 0.11f, fill)
            }
        }
    }

    // ── layouts ───────────────────────────────────────────────
    private fun numberText(): String = fmtInt(Math.round(st.shown))

    private fun bumpScale(): Float {
        if (st.anim < 1 || st.sinceStepMs !in 0..700L) return 1f
        val e = st.sinceStepMs / 700f
        return 1f + 0.07f * (1f - e) * (1f - e)
    }

    private fun drawBig(s: String, x: Float, y: Float, size: Float, maxW: Float) {
        val sc = bumpScale()
        val ax = if (rtl) W - x else x
        c.save()
        c.scale(sc, sc, ax, y)
        text(s, x, y, size, if (done) GOLD2 else st.pal.text, 0, maxW, true)
        c.restore()
    }

    private fun statValues(): List<Triple<Int, String, String>> {
        val cfg = st.cfg
        val out = ArrayList<Triple<Int, String, String>>()
        if (cfg.showKcal) out.add(Triple(0, fmtInt((st.steps * cfg.kcalPerStep).toInt()), cfg.s("kcal", "kcal")))
        if (cfg.showDist) out.add(Triple(1, fmtDec(st.steps * cfg.strideKm), cfg.s("km", "km")))
        if (cfg.showPct) out.add(Triple(2, digits((st.steps * 100 / cfg.goal).toString()), "%"))
        return out
    }

    private fun statIcon(kind: Int, cx: Float, cy: Float, s: Float, color: Int) {
        gfx {
            when (kind) {
                0 -> iconFlame(cx, cy, s, color)
                1 -> iconRoute(cx, cy, s, color)
                else -> iconTarget(cx, cy, s, color)
            }
        }
    }

    private fun message(): String {
        val cfg = st.cfg
        if (done) return cfg.s("goalDone", "Goal reached")
        val left = cfg.goal - st.steps
        val key = when {
            pct < 0.25f -> "m0"
            pct < 0.5f -> "m1"
            pct < 0.75f -> "m2"
            else -> "m3"
        }
        // Alternate between the encouragement and the remaining count.
        val showLeft = ((st.t / 6f).toInt() % 2 == 1) && st.anim >= 1
        return if (showLeft) cfg.s("toGo", "{n} to go").replace("{n}", fmtInt(left))
               else cfg.s(key, "Keep going")
    }

    private fun layoutCollapsed() {
        val cfg = st.cfg
        when (cfg.style) {
            "stride" -> drawEmblem(78f, 78f, 50f, 1)
            "zen" -> drawEmblem(62f, 70f, 36f, 2)
            else -> drawEmblem(84f, 78f, 56f, 0)
        }
        val tx = when (cfg.style) { "stride" -> 156f; "zen" -> 124f; else -> 172f }
        val statsW = if (cfg.style == "zen") 120f else 250f
        text(cfg.s("today", "TODAY"), tx, 40f, 24f, st.pal.sub, 0, 300f)
        drawBig(numberText(), tx, 104f, if (cfg.style == "zen") 78f else 72f, W - tx - statsW - 20f)
        // right-hand stats
        val vals = statValues()
        if (cfg.style == "zen") {
            val pv = digits((st.steps * 100 / cfg.goal).toString()) + "%"
            text(pv, W - 40f, 100f, 46f, acc2, 1, 0f, true)
        } else if (vals.isNotEmpty()) {
            val rows = vals.filter { it.first != 2 }.take(2)
            var yy = if (rows.size == 1) 88f else 62f
            for (r in rows) {
                val label = r.second + " " + r.third
                val wv = text(label, W - 44f, yy + 10f, 30f, st.pal.text, 1, statsW - 44f, false)
                statIcon(r.first, W - 44f - wv - 24f, yy, 28f, acc)
                yy += 44f
            }
        }
        drawBar(tx, 124f, W - tx - 44f, 14f)
    }

    private fun layoutExpanded() {
        val cfg = st.cfg
        val style = cfg.style
        val vals = statValues()
        // emblem
        when (style) {
            "stride" -> drawEmblem(130f, 130f, 92f, 1)
            "zen" -> drawEmblem(82f, 84f, 44f, 2)
            else -> drawEmblem(150f, 150f, 100f, 0)
        }
        val tx = when (style) { "stride" -> 258f; "zen" -> 150f; else -> 296f }
        val zen = style == "zen"
        if (zen) {
            text(cfg.s("today", "TODAY"), tx, 96f, 30f, st.pal.sub, 0, 400f)
            drawBig(numberText(), 40f, 270f, 176f, W - 80f)
        } else {
            text(cfg.s("today", "TODAY"), tx, 74f, 30f, st.pal.sub, 0, 560f)
            drawBig(numberText(), tx, 190f, 124f, W - tx - 36f)
        }
        // stats
        val rowY = if (zen) 0f else if (style == "stride") 232f else 214f
        if (!zen && vals.isNotEmpty()) {
            var x = tx
            for (v in vals) {
                val label = v.second + (if (v.third == "%") "" else " " + v.third)
                val tw = measure(label, 32f)
                val chipW = tw + 64f
                if (style == "orbit") {
                    gfx {
                        rect.set(x, rowY, x + chipW, rowY + 62f)
                        fill.color = st.pal.chip
                        c.drawRoundRect(rect, 31f, 31f, fill)
                    }
                    statIcon(v.first, x + 30f, rowY + 31f, 30f, acc)
                    text(label, x + 52f, rowY + 43f, 32f, st.pal.text)
                    x += chipW + 14f
                } else {
                    statIcon(v.first, x + 16f, rowY + 22f, 32f, acc)
                    text(label, x + 40f, rowY + 33f, 32f, st.pal.text)
                    x += tw + 40f + 28f
                }
            }
        }
        if (zen) {
            val pv = digits((st.steps * 100 / cfg.goal).toString()) + "%"
            text(pv, W - 40f, 96f, 48f, acc2, 1, 0f, true)
        }
        // bar
        val barY = 312f
        val barH = if (style == "stride") 34f else if (zen) 14f else 26f
        drawBar(40f, barY, W - 80f, barH)
        if (cfg.showMsg) {
            text(message(), 40f, barY + barH + 50f, 31f, st.pal.sub, 0, 560f)
        }
        // goal flag
        val goalLabel = fmtInt(cfg.goal)
        val gw = measure(goalLabel, 30f)
        gfx { iconFlag(W - 40f - gw - 26f, barY + barH + 38f, 28f, if (done) GOLD1 else st.pal.sub) }
        text(goalLabel, W - 40f, barY + barH + 50f, 30f, if (done) GOLD2 else st.pal.sub, 1)
        if (cfg.showWeek) drawWeek(barY + barH + 78f)
    }

    private fun drawWeek(top: Float) {
        val cfg = st.cfg
        val wk = st.week
        var mx = cfg.goal
        for (v in wk) if (v > mx) mx = v
        val baseline = top + 92f
        val bw = 66f
        val gap = (W - 80f - bw * 7f) / 6f
        gfx {
            // goal line
            val gy = baseline - 92f * cfg.goal / mx
            line.shader = null
            line.strokeWidth = 2f
            line.color = Palettes.withAlpha(st.pal.text, 0.14f)
            c.drawLine(40f, gy, W - 40f, gy, line)
            for (i in 0 until 7) {
                val x = 40f + i * (bw + gap)
                val hv = (92f * wk[i] / mx).coerceAtLeast(if (wk[i] > 0) 8f else 5f)
                val isToday = i == 6
                rect.set(x, baseline - hv, x + bw, baseline)
                if (isToday) {
                    fill.shader = LinearGradient(0f, baseline - hv, 0f, baseline, acc2, acc, Shader.TileMode.CLAMP)
                } else {
                    fill.shader = null
                    fill.color = if (wk[i] >= cfg.goal) Palettes.withAlpha(GOLD1, 0.85f) else Palettes.withAlpha(st.pal.text, 0.20f)
                }
                c.drawRoundRect(rect, 14f, 14f, fill)
                fill.shader = null
            }
        }
        for (i in 0 until 7) {
            val x = 40f + i * (bw + gap)
            val letter = StepState.narrowDay(i - 6, cfg.lang)
            text(letter, x + bw / 2, baseline + 36f, 26f, if (i == 6) st.pal.text else st.pal.sub, 2)
        }
    }
}
''')

write('android_extra/kotlin/StepCardService.kt', r'''package com.ihsanstudio.halalcalorie

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import android.widget.RemoteViews

// ─────────────────────────────────────────────────────────────
//  StepCardService.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  The live step card: a foreground service that counts steps with
//  the hardware sensor and keeps an animated card in the shade.
//  Animation only runs while the screen is on.
// ─────────────────────────────────────────────────────────────

class StepCardService : Service(), SensorEventListener {

    companion object {
        const val ACTION_START = "com.ihsanstudio.halalcalorie.STEPCARD_START"
        const val ACTION_STOP = "com.ihsanstudio.halalcalorie.STEPCARD_STOP"
        const val ACTION_REFRESH = "com.ihsanstudio.halalcalorie.STEPCARD_REFRESH"
        const val ACTION_DISMISSED = "com.ihsanstudio.halalcalorie.STEPCARD_DISMISSED"
        const val NOTIF_ID = 4201
        const val GOAL_ID = 4202
        const val CH_LOW = "hc_step_card_low"
        const val CH_MIN = "hc_step_card_min"
        const val CH_GOAL = "hc_step_goal"

        @Volatile var running = false
        @Volatile var instance: StepCardService? = null

        fun hasActivityPermission(ctx: Context): Boolean =
            Build.VERSION.SDK_INT < 29 ||
                ctx.checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

        fun start(ctx: Context) {
            val i = Intent(ctx, StepCardService::class.java).setAction(ACTION_START)
            try {
                if (Build.VERSION.SDK_INT >= 26) ctx.startForegroundService(i) else ctx.startService(i)
            } catch (e: Exception) {
                StepState.init(ctx)
                StepState.recordError("start: " + e.javaClass.simpleName)
            }
        }

        fun stop(ctx: Context) {
            val i = instance
            if (i != null) i.shutDown()
            else try { ctx.stopService(Intent(ctx, StepCardService::class.java)) } catch (e: Exception) {}
        }

        fun refresh(ctx: Context) {
            val i = instance ?: return
            i.reload()
        }
    }

    private lateinit var thread: HandlerThread
    private lateinit var bg: Handler
    private lateinit var nm: NotificationManager
    private lateinit var sm: SensorManager
    private lateinit var renderer: StepCardRenderer
    private lateinit var cfg: CardConfig
    private var smallBmp: Bitmap? = null
    private var bigBmp: Bitmap? = null
    private var shown = 0f
    private var startNs = System.nanoTime()
    private var screenOn = true
    private var dismissed = false
    private var registered = false
    private var lastPosted = 0L

    private val ticker = object : Runnable {
        override fun run() {
            frame()
            val ms = frameInterval()
            if (ms > 0 && screenOn && !dismissed) bg.postDelayed(this, ms)
        }
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> { screenOn = false; bg.removeCallbacks(ticker); bg.post { frame() } }
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> { screenOn = true; kick() }
            }
        }
    }

    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            // The user swiped the card away: respect it until the app is opened again.
            dismissed = true
            bg.removeCallbacks(ticker)
        }
    }

    // ── lifecycle ─────────────────────────────────────────────
    override fun onCreate() {
        super.onCreate()
        instance = this
        thread = HandlerThread("hc-step-card").also { it.start() }
        bg = Handler(thread.looper)
        nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        StepState.init(applicationContext)
        cfg = CardConfig.load(this)
        renderer = StepCardRenderer(applicationContext)
        createChannels()
        screenOn = (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
        val f = IntentFilter()
        f.addAction(Intent.ACTION_SCREEN_ON)
        f.addAction(Intent.ACTION_SCREEN_OFF)
        f.addAction(Intent.ACTION_USER_PRESENT)
        registerReceiver(screenReceiver, f)
        val d = IntentFilter(ACTION_DISMISSED)
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(dismissReceiver, d, Context.RECEIVER_NOT_EXPORTED)
        else registerReceiver(dismissReceiver, d)
        if (cfg.theme == "random" && cfg.shuffle == "launch") StepState.shuffle(Palettes.poolSize())
        shown = StepState.steps().toFloat()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) { shutDown(); return START_NOT_STICKY }
        cfg = CardConfig.load(this)
        if (!cfg.enabled || !hasActivityPermission(this)) {
            // Must still satisfy startForeground when started via startForegroundService.
            try { promote(buildNotification(true)) } catch (e: Exception) {}
            shutDown()
            return START_NOT_STICKY
        }
        dismissed = false
        StepState.rollIfNeeded()
        try {
            promote(buildNotification(true))
            StepState.recordError("")
        } catch (e: Exception) {
            StepState.recordError("fgs: " + e.javaClass.simpleName)
            stopSelf()
            return START_NOT_STICKY
        }
        running = true
        registerSensor()
        kick()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        instance = null
        try { sm.unregisterListener(this) } catch (e: Exception) {}
        try { unregisterReceiver(screenReceiver) } catch (e: Exception) {}
        try { unregisterReceiver(dismissReceiver) } catch (e: Exception) {}
        StepState.persist(true)
        bg.removeCallbacksAndMessages(null)
        thread.quitSafely()
        super.onDestroy()
    }

    fun shutDown() {
        running = false
        try { bg.removeCallbacksAndMessages(null) } catch (e: Exception) {}
        try { stopForeground(true) } catch (e: Exception) {}
        try { nm.cancel(NOTIF_ID) } catch (e: Exception) {}
        stopSelf()
    }

    /** Called when the app changed a setting or pushed new steps. */
    fun reload() {
        bg.post {
            cfg = CardConfig.load(this)
            if (!cfg.enabled) { shutDown(); return@post }
            dismissed = false
            if (cfg.theme == "random" && cfg.shuffle == "day" && StepState.randDay != StepState.dayKey()) {
                StepState.shuffle(Palettes.poolSize())
            }
            kick()
        }
    }

    fun onPushed() { bg.post { frame() } }

    // ── sensor ────────────────────────────────────────────────
    private fun registerSensor() {
        if (registered) return
        var s = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        var detector = false
        if (s == null) { s = sm.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR); detector = true }
        if (s == null) return
        StepState.useDetector = detector
        registered = try { sm.registerListener(this, s, SensorManager.SENSOR_DELAY_NORMAL, 0, bg) } catch (e: Exception) { false }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    override fun onSensorChanged(e: SensorEvent) {
        val changed = if (e.sensor.type == Sensor.TYPE_STEP_COUNTER) StepState.onSensor(e.values[0].toLong())
                      else StepState.onDetector()
        if (changed) {
            checkGoal()
            // With animation off (or the screen off) a step is the only reason to repaint.
            if (!screenOn || frameInterval() <= 0L) frame() else if (!dismissed) { bg.removeCallbacks(ticker); bg.post(ticker) }
        }
    }

    // ── frames ────────────────────────────────────────────────
    private fun reducedMotion(): Boolean = try {
        Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
    } catch (e: Exception) { false }

    private fun animLevel(): Int = if (reducedMotion() || !screenOn) 0 else cfg.anim

    private fun frameInterval(): Long = when (animLevel()) { 1 -> 1000L; 2 -> 500L; 3 -> 340L; else -> 0L }

    private fun kick() {
        bg.removeCallbacks(ticker)
        bg.post(ticker)
    }

    private fun checkGoal() {
        val steps = StepState.steps()
        if (steps >= cfg.goal && StepState.celebDay != StepState.dayKey()) {
            StepState.markCelebrated(System.currentTimeMillis())
            if (cfg.celebrate) postGoalNotification(steps)
        }
    }

    private fun buildState(): RenderState {
        val steps = StepState.steps()
        val level = animLevel()
        // count up towards the real number instead of jumping
        shown = if (level == 0 || Math.abs(steps - shown) < 1f) steps.toFloat() else shown + (steps - shown) * 0.35f
        val now = System.currentTimeMillis()
        val sinceStep = if (StepState.lastStepAt == 0L) 99999L else now - StepState.lastStepAt
        val sinceCeleb = if (StepState.celebDay == StepState.dayKey()) now - StepState.celebAt else 99999L
        val t = (System.nanoTime() - startNs) / 1_000_000_000f
        return StepRenderHelper.state(cfg, StepState.randIdx, shown, steps, t, sinceStep, sinceCeleb, StepState.week(), level)
    }

    private fun frame() {
        if (dismissed || !running) return
        try {
            if (StepState.rollIfNeeded()) shown = 0f
            if (cfg.theme == "random" && cfg.shuffle == "day" && StepState.randDay != StepState.dayKey()) {
                StepState.shuffle(Palettes.poolSize())
            }
            nm.notify(NOTIF_ID, buildNotification(false))
        } catch (e: Exception) { /* a dropped frame is fine */ }
    }

    private fun promote(n: Notification) {
        if (Build.VERSION.SDK_INT >= 34) {
            // FOREGROUND_SERVICE_TYPE_HEALTH
            startForeground(NOTIF_ID, n, 0x00000100)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    // ── notification ──────────────────────────────────────────
    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val low = NotificationChannel(CH_LOW, "HalalCalorie · Step card", NotificationManager.IMPORTANCE_LOW)
        low.setShowBadge(false)
        low.description = "Live step counter"
        val min = NotificationChannel(CH_MIN, "HalalCalorie · Step card (no status-bar icon)", NotificationManager.IMPORTANCE_MIN)
        min.setShowBadge(false)
        val goal = NotificationChannel(CH_GOAL, "HalalCalorie · Daily goal", NotificationManager.IMPORTANCE_DEFAULT)
        goal.enableVibration(true)
        nm.createNotificationChannel(low)
        nm.createNotificationChannel(min)
        nm.createNotificationChannel(goal)
    }

    private fun res(name: String, type: String): Int = resources.getIdentifier(name, type, packageName)

    private fun contentIntent(): PendingIntent {
        val i = Intent(this, MainActivity::class.java)
        i.putExtra("hc_route", "/health")
        i.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getActivity(this, 7, i, flags)
    }

    private fun deleteIntent(): PendingIntent {
        val i = Intent(ACTION_DISMISSED).setPackage(packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(this, 8, i, flags)
    }

    private fun views(layout: String, bmp: Bitmap, desc: String): RemoteViews {
        val rv = RemoteViews(packageName, res(layout, "layout"))
        val id = res("hc_card_img", "id")
        rv.setImageViewBitmap(id, bmp)
        rv.setContentDescription(id, desc)
        return rv
    }

    private val lock = Any()

    private fun buildNotification(first: Boolean): Notification = synchronized(lock) {
        val state = buildState()
        smallBmp = renderer.render(false, state, smallBmp)
        bigBmp = renderer.render(true, state, bigBmp)
        val desc = renderer.describe(state)
        val small = views("hc_step_card_small", smallBmp!!, desc)
        val big = views("hc_step_card_big", bigBmp!!, desc)

        val channel = if (cfg.statusIcon) CH_LOW else CH_MIN
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel) else Notification.Builder(this)
        val icon = res("ic_stat_halal", "drawable")
        b.setSmallIcon(if (icon != 0) icon else android.R.drawable.ic_menu_compass)
        b.setCustomContentView(small)
        b.setCustomBigContentView(big)
        b.setStyle(Notification.DecoratedCustomViewStyle())
        b.setContentIntent(contentIntent())
        b.setDeleteIntent(deleteIntent())
        b.setOngoing(true)
        b.setOnlyAlertOnce(true)
        b.setShowWhen(false)
        b.setLocalOnly(true)
        b.setColor(state.pal.accent)
        b.setCategory(Notification.CATEGORY_STATUS)
        b.setVisibility(if (cfg.lock == "hide") Notification.VISIBILITY_SECRET else Notification.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT < 26) b.setPriority(if (cfg.statusIcon) Notification.PRIORITY_LOW else Notification.PRIORITY_MIN)
        if (Build.VERSION.SDK_INT >= 31) b.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
        b.build()
    }

    private fun postGoalNotification(steps: Int) {
        try {
            val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CH_GOAL) else Notification.Builder(this)
            val icon = res("ic_stat_halal", "drawable")
            b.setSmallIcon(if (icon != 0) icon else android.R.drawable.ic_menu_compass)
            b.setContentTitle(cfg.s("celebTitle", "Goal reached!"))
            b.setContentText(cfg.s("celebBody", "{n} steps today — well done").replace("{n}", String.format(java.util.Locale.US, "%,d", steps)))
            b.setContentIntent(contentIntent())
            b.setAutoCancel(true)
            b.setColor(Palettes.resolve(cfg, StepState.randIdx).accent)
            b.setTimeoutAfter(6L * 60L * 60L * 1000L)
            if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_DEFAULT)
            nm.notify(GOAL_ID, b.build())
        } catch (e: Exception) {}
    }

    /** Posts the goal notification on demand (the settings "test" button). */
    fun testGoal() {
        bg.post {
            StepState.markCelebrated(System.currentTimeMillis())
            postGoalNotification(cfg.goal)
            kick()
        }
    }
}

/** Keeps the RenderState construction in one place for the service and the in-app preview. */
object StepRenderHelper {
    fun state(cfg: CardConfig, randIdx: Int, shown: Float, steps: Int, t: Float,
              sinceStepMs: Long, sinceCelebMs: Long, week: IntArray, anim: Int): RenderState =
        RenderState(cfg, Palettes.resolve(cfg, randIdx), shown, steps, t, sinceStepMs, sinceCelebMs, week, anim)
}
''')

write('android_extra/kotlin/StepCardBridge.kt', r'''package com.ihsanstudio.halalcalorie

import android.app.Activity
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

// ─────────────────────────────────────────────────────────────
//  StepCardBridge.kt — HalalCalorie v59 (PATCH_V59_STEPCARD)
//  Dart <-> native. The in-app preview asks the very same renderer
//  that draws the notification for frames, so what you tune is what
//  you get in the shade.
// ─────────────────────────────────────────────────────────────

object StepCardBridge {
    private const val CHANNEL = "hc/stepcard"
    private var channel: MethodChannel? = null
    private var pendingRoute: String? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var previewRenderer: StepCardRenderer? = null
    private var previewBmp: Bitmap? = null

    fun register(activity: Activity, messenger: BinaryMessenger) {
        val ctx = activity.applicationContext
        StepState.init(ctx)
        val ch = MethodChannel(messenger, CHANNEL)
        channel = ch
        captureIntent(activity.intent)
        ch.setMethodCallHandler { call, result -> handle(activity, ctx, call, result) }
    }

    fun captureIntent(intent: Intent?) {
        val r = intent?.getStringExtra("hc_route") ?: return
        pendingRoute = r
        intent.removeExtra("hc_route")
        try { channel?.invokeMethod("route", r) } catch (e: Exception) {}
    }

    private fun handle(activity: Activity, ctx: Context, call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "configure" -> {
                    val map = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val e = ctx.getSharedPreferences(CardConfig.FILE, Context.MODE_PRIVATE).edit()
                    for ((k, v) in map) {
                        val key = k as? String ?: continue
                        when (v) {
                            is Boolean -> e.putBoolean(key, v)
                            is Int -> e.putInt(key, v)
                            is Long -> e.putInt(key, v.toInt())
                            is Double -> e.putFloat(key, v.toFloat())
                            is String -> e.putString(key, v)
                            else -> {}
                        }
                    }
                    e.apply()
                    val cfg = CardConfig.load(ctx)
                    if (cfg.theme == "random" && cfg.shuffle == "day" && StepState.randDay != StepState.dayKey()) {
                        StepState.shuffle(Palettes.poolSize())
                    }
                    StepCardService.refresh(ctx)
                    result.success(true)
                }
                "start" -> {
                    val cfg = CardConfig.load(ctx)
                    if (!StepCardService.hasActivityPermission(ctx)) { result.success(false); return }
                    if (cfg.enabled) StepCardService.start(ctx)
                    result.success(true)
                }
                "stop" -> { StepCardService.stop(ctx); result.success(true) }
                "pushSteps" -> {
                    val n = (call.arguments as? Number)?.toInt() ?: 0
                    StepState.push(n)
                    StepCardService.instance?.onPushed()
                    result.success(true)
                }
                "seedHistory" -> {
                    StepState.seedHistory(call.arguments as? String ?: "")
                    result.success(true)
                }
                "shuffle" -> {
                    StepState.shuffle(Palettes.poolSize())
                    StepCardService.refresh(ctx)
                    result.success(true)
                }
                "testGoal" -> {
                    val s = StepCardService.instance
                    if (s != null) s.testGoal() else StepState.markCelebrated(System.currentTimeMillis())
                    result.success(s != null)
                }
                "status" -> {
                    val sm = ctx.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                    val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null ||
                        sm.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR) != null
                    val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val notifOn = if (Build.VERSION.SDK_INT >= 24) nm.areNotificationsEnabled() else true
                    result.success(hashMapOf<String, Any>(
                        "running" to StepCardService.running,
                        "sensor" to sensor,
                        "permission" to StepCardService.hasActivityPermission(ctx),
                        "notifications" to notifOn,
                        "error" to StepState.error,
                        "steps" to StepState.steps()))
                }
                "consumeRoute" -> {
                    val r = pendingRoute
                    pendingRoute = null
                    result.success(r)
                }
                "preview" -> {
                    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                    val expanded = args["expanded"] as? Boolean ?: true
                    val tMs = (args["t"] as? Number)?.toDouble() ?: 0.0
                    val fake = (args["steps"] as? Number)?.toInt() ?: -1
                    val sinceCeleb = (args["sinceCelebMs"] as? Number)?.toLong() ?: 99999L
                    val sinceStep = (args["sinceStepMs"] as? Number)?.toLong() ?: 99999L
                    io.execute {
                        try {
                            val bytes = renderPreview(ctx, expanded, tMs, fake, sinceCeleb, sinceStep)
                            main.post { result.success(bytes) }
                        } catch (e: Exception) {
                            main.post { result.error("preview", e.toString(), null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("stepcard", e.toString(), null)
        }
    }

    @Synchronized
    private fun renderPreview(ctx: Context, expanded: Boolean, tMs: Double, fake: Int,
                              sinceCeleb: Long, sinceStep: Long): ByteArray {
        val r = previewRenderer ?: StepCardRenderer(ctx).also { previewRenderer = it }
        val cfg = CardConfig.load(ctx)
        val steps = if (fake >= 0) fake else StepState.steps()
        val week = StepState.week()
        if (fake >= 0) week[6] = fake
        val anim = if (cfg.anim == 0) 0 else cfg.anim
        val state = StepRenderHelper.state(cfg, StepState.randIdx, steps.toFloat(), steps,
            (tMs / 1000.0).toFloat(), sinceStep, sinceCeleb, week, anim)
        previewBmp = r.render(expanded, state, previewBmp)
        val out = ByteArrayOutputStream()
        previewBmp!!.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }
}

class StepCardBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        try {
            val cfg = CardConfig.load(context)
            if (cfg.enabled && cfg.bootStart && StepCardService.hasActivityPermission(context)) {
                StepCardService.start(context)
            }
        } catch (e: Exception) {}
    }
}
''')

write('android_extra/kotlin/MainActivity.kt', r'''package com.ihsanstudio.halalcalorie

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        StepCardBridge.register(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        StepCardBridge.captureIntent(intent)
    }
}
''')

write('android_extra/res/layout/hc_step_card_small.xml', r'''<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content">
    <ImageView
        android:id="@+id/hc_card_img"
        android:layout_width="match_parent"
        android:layout_height="52dp"
        android:scaleType="fitCenter"
        android:contentDescription="@null" />
</FrameLayout>
''')

write('android_extra/res/layout/hc_step_card_big.xml', r'''<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:paddingTop="2dp"
    android:paddingBottom="4dp">
    <ImageView
        android:id="@+id/hc_card_img"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:adjustViewBounds="true"
        android:maxHeight="236dp"
        android:scaleType="fitCenter"
        android:contentDescription="@null" />
</FrameLayout>
''')

# ═══════════════ WIRING ═══════════════
RT = 'lib/core/router.dart'
edit(RT, sub_once(
    "import '../features/premium/notification_center_screen.dart';\n",
    "import '../features/premium/notification_center_screen.dart';\nimport '../features/health/step_card_screen.dart'; // PATCH_V59\n",
    marker='step_card_screen.dart'), 'router import')
edit(RT, sub_once(
    "        _page('/notifications', (_, __) => const NotificationCenterScreen()),\n",
    "        _page('/notifications', (_, __) => const NotificationCenterScreen()),\n"
    "        _page('/step-card', (_, __) => const StepCardScreen()),\n",
    marker="'/step-card'"), 'router route')

PV = 'lib/core/providers.dart'
edit(PV, sub_once(
    "import 'package:package_info_plus/package_info_plus.dart';\n",
    "import 'package:package_info_plus/package_info_plus.dart';\nimport 'step_card_service.dart'; // PATCH_V59\n",
    marker="import 'step_card_service.dart'"), 'providers import')
edit(PV, sub_once(
    "await AppDatabase.upsertSummary(steps: n.clamp(0, 99999)); }",
    "await AppDatabase.upsertSummary(steps: n.clamp(0, 99999)); StepCardService.pushSteps(n.clamp(0, 99999)); }",
    marker='StepCardService.pushSteps'), 'providers: push steps to the card')

MN = 'lib/main.dart'
edit(MN, sub_once(
    "import 'core/prayer_provider.dart'; // PATCH_V58\n",
    "import 'core/prayer_provider.dart'; // PATCH_V58\nimport 'core/step_card_service.dart'; // PATCH_V59\n",
    marker="import 'core/step_card_service.dart'"), 'main import')
edit(MN, sub_once(
    "      ref.read(stepTrackerProvider).ensureStarted(askPermissions: false).catchError((_) {});\n",
    "      ref.read(stepTrackerProvider).ensureStarted(askPermissions: false).catchError((_) {});\n"
    "      StepCardService.bootstrap().catchError((_) {}); // PATCH_V59\n",
    marker='StepCardService.bootstrap().catchError'), 'main: bootstrap')
edit(MN, sub_once(
    "    if (state == AppLifecycleState.resumed) { _rollDayIfNeeded(); _refreshSmart(); }",
    "    if (state == AppLifecycleState.resumed) { _rollDayIfNeeded(); _refreshSmart(); StepCardService.onResume(); }",
    marker='StepCardService.onResume'), 'main: resume')
edit(MN, sub_once(
    "    ref.listen<bool>(onboardingDoneProvider, (prev, next) { if (next) _afterOnboarding(); });\n",
    "    StepCardService.setAppContext(isDark: isDark, lang: lang, ramadan: isRamadan); // PATCH_V59\n"
    "    ref.listen<bool>(onboardingDoneProvider, (prev, next) { if (next) _afterOnboarding(); });\n",
    marker='StepCardService.setAppContext'), 'main: app context')
edit(MN, sub_once(
    "    try { await NotificationService.askPermissionOnce(); } catch (e) { debugPrint('Notif ask: $e'); }\n",
    "    try { await NotificationService.askPermissionOnce(); } catch (e) { debugPrint('Notif ask: $e'); }\n"
    "    try { await StepCardService.bootstrap(); } catch (e) { debugPrint('StepCard: $e'); } // PATCH_V59\n",
    marker='StepCardService.bootstrap(); } catch'), 'main: after onboarding')

ST = 'lib/features/settings/settings_screen.dart'
tile = (
"                GestureDetector(\n"
"                  onTap: () => context.push('/step-card'),\n"
"                  child: Container(\n"
"                    margin: const EdgeInsets.only(bottom: 10),\n"
"                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),\n"
"                    decoration: BoxDecoration(\n"
"                      color: AppColors.halalGreen.withOpacity(0.12),\n"
"                      borderRadius: BorderRadius.circular(18),\n"
"                      border: Border.all(color: AppColors.halalGreen.withOpacity(0.45), width: 0.8),\n"
"                    ),\n"
"                    child: Row(children: [\n"
"                      const Icon(Icons.directions_walk_rounded, color: AppColors.halalGreen, size: 22),\n"
"                      const SizedBox(width: 12),\n"
"                      Expanded(child: Text(t('بطاقة الخطوات الحيّة — ألوان وحركة وإعدادات', 'Live Step Card — themes, animation & settings'),\n"
"                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,\n"
"                              fontWeight: FontWeight.w800, color: text))),\n"
"                      Icon(Icons.chevron_right_rounded, color: muted),\n"
"                    ]),\n"
"                  ),\n"
"                ),\n")
edit(ST, sub_once(
    "// PATCH_V58_NOTIF_LINK\n",
    "// PATCH_V59_STEPCARD_LINK\n" + tile + "// PATCH_V58_NOTIF_LINK\n",
    marker='PATCH_V59_STEPCARD_LINK'), 'settings: step card link')

# ── patch_android.py: copy Kotlin + layouts, manifest, MainActivity ──
def android_patch(s):
    if 'PATCH_V59_STEPCARD' in s: return s
    add = r"""

# PATCH_V59_STEPCARD ─ live step card: Kotlin sources, layouts, service, permissions
import shutil as _sh
_kt_dst = "android/app/src/main/kotlin/com.ihsanstudio.halalcalorie"
os.makedirs(_kt_dst, exist_ok=True)
if os.path.isdir("android_extra/kotlin"):
    for _n in os.listdir("android_extra/kotlin"):
        _sh.copy("android_extra/kotlin/" + _n, _kt_dst + "/" + _n)   # includes the new MainActivity.kt
    print("StepCard: Kotlin sources copied")
_lay_dst = "android/app/src/main/res/layout"
os.makedirs(_lay_dst, exist_ok=True)
if os.path.isdir("android_extra/res/layout"):
    for _n in os.listdir("android_extra/res/layout"):
        _sh.copy("android_extra/res/layout/" + _n, _lay_dst + "/" + _n)
    print("StepCard: layouts copied")
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as _f: _m = _f.read()
    _ch = False
    for _perm in ("FOREGROUND_SERVICE", "FOREGROUND_SERVICE_HEALTH"):
        if 'android.permission.' + _perm + '"' not in _m:
            _m = _m.replace("<application",
                '    <uses-permission android:name="android.permission.' + _perm + '" />\n    <application', 1)
            _ch = True
    if "StepCardService" not in _m:
        _svc = (
            '    <service android:name="com.ihsanstudio.halalcalorie.StepCardService" android:exported="false" android:foregroundServiceType="health" />\n'
            '    <receiver android:name="com.ihsanstudio.halalcalorie.StepCardBootReceiver" android:exported="true">\n'
            '        <intent-filter>\n'
            '            <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
            '            <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>\n'
            '        </intent-filter>\n'
            '    </receiver>\n')
        _m = _m.replace("</application>", _svc + "    </application>", 1)
        _ch = True
    if _ch:
        with open(manifest_path, "w") as _f: _f.write(_m)
        print("AndroidManifest: step card service + permissions added")
    else:
        print("AndroidManifest: step card already present")
"""
    return s.rstrip('\n') + '\n' + add
edit('patch_android.py', android_patch, 'android: step card service')

edit('pubspec.yaml', lambda s: re.sub(r'^version:\s*[\d.]+\+\d+', 'version: 1.17.0+31', s, count=1, flags=re.M) if re.search(r'^version:', s, re.M) else None, 'version -> 1.17.0+31')

print()
balance_check([
    'lib/core/step_card_service.dart', 'lib/features/health/step_card_screen.dart',
    'lib/main.dart', 'lib/core/router.dart', 'lib/core/providers.dart',
    'lib/features/settings/settings_screen.dart',
])
print('\nDone: %d ok, %d skipped.' % (ok, skip))
if skip: print('Skipped steps mean an anchor moved - send me the dump and I will re-anchor.')
print('Next: git add -A && git commit -m "v59: live step card" && git push')
