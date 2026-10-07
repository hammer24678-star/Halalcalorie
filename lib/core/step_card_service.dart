// step_card_service.dart — HalalCalorie v59 (PATCH_V59_STEPCARD)
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

  /// PATCH_V60: both cards in one call, as raw RGBA (no PNG round trip).
  static Future<Map<String, dynamic>?> previewBoth({
    required int tMs,
    int steps = -1,
    int sinceCelebMs = 99999,
    int sinceStepMs = 99999,
  }) async {
    try {
      return await _ch.invokeMapMethod<String, dynamic>('previewBoth', <String, Object>{
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
