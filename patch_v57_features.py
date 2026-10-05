#!/usr/bin/env python3
"""
patch_v57_features.py
=====================
HalalCalorie v57 - FEATURES. Run from the repo root (after v56):

    python3 patch_v57_features.py

Safe to run twice. No new dependencies. Database goes 8 -> 9 (additive:
one new column + one new table, nothing is dropped).

WORKOUT PLAYER  rebuilt. Get-ready countdown, timed AND rep-based steps (rep
                steps wait for "Set done" instead of freezing), rest periods
                (0/10/15/20/30 s, +15 s, skippable), pause / previous / skip,
                haptic + sound cues, real elapsed time (the old one always
                logged the nominal minutes), MET-based calories from your
                weight, confetti summary with streak and vs-last-time, quit
                dialog that can save partial progress.
WORKOUT LOG     every session is saved (new workout_sessions table). Fitness
                tab shows "Your week": sessions / minutes / kcal + 7-day bars,
                and a History sheet. Calories-burned now uses real kcal.
SCANNER         ingredient-level halal engine (pork, alcohol, blood, carmine,
                gelatin, rennet, animal fat, meat, glycerin, emulsifiers, ~35
                E-numbers...) that says WHY. Vegan products clear animal
                doubts; a halal label on the pack is honoured.
                Nutri-Score, NOVA, vegan/vegetarian, allergens, sugar/salt/fat
                traffic lights, product photo.
                Portion slider scales macros and logs the real amount.
                Healthier halal-safe alternatives from the same category.
                Photograph an ingredient label -> AI reads it -> halal check.
                Scan history is saved across launches; favourites (star) with
                a one-tap strip; last good lookup cached for offline use;
                no more fake "unknown product" when you are simply offline.
pubspec         -> 1.15.0+29
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
    with open(path(p), 'w', encoding='utf-8') as f:
        f.write(content)
    ok += 1
    print('  WROTE  ', p)

def edit(p, fn, label):
    """fn(text) -> new text, or None when the anchor is missing."""
    global ok, skip
    if not os.path.exists(path(p)):
        skip += 1; print('  SKIP   ', p, '(missing)', label); return
    with open(path(p), encoding='utf-8') as f:
        s = f.read()
    n = fn(s)
    if n is None:
        skip += 1; print('  SKIP   ', p, '-', label, '(anchor not found)'); return
    if n == s:
        ok += 1; print('  OK     ', p, '-', label, '(already applied)'); return
    with open(path(p), 'w', encoding='utf-8') as f:
        f.write(n)
    ok += 1
    print('  PATCHED', p, '-', label)

def sub_once(old, new):
    def f(s):
        if new in s: return s
        return s.replace(old, new, 1) if old in s else None
    return f

def cut_once(old, gone):
    """Delete `old`. Counts as already applied once `gone` no longer appears."""
    def f(s):
        if old in s: return s.replace(old, '', 1)
        return s if gone not in s else None
    return f

def rx_once(pattern, repl, sentinel):
    def f(s):
        if sentinel in s: return s
        n, c = re.subn(pattern, lambda m: repl, s, count=1)
        return n if c else None
    return f

def line_start_before(s, marker, frm=0):
    """Start index of the banner line that sits directly above `marker`."""
    i = s.find(marker, frm)
    if i < 0: return -1
    return s.rfind('\n', 0, i - 1) + 1

def slice_edit(start, end, new, sentinel, banner_end=False):
    def f(s):
        if sentinel in s: return s
        a = s.find(start)
        if a < 0: return None
        b = line_start_before(s, end, a) if banner_end else s.find(end, a)
        if b < 0 or b <= a: return None
        return s[:a] + new + s[b:]
    return f



print('== v57 features ==')

HE = 'lib/core/halal_engine.dart'
SS = 'lib/core/scan_store.dart'
WP = 'lib/features/fitness/workout_player_pro.dart'
write(HE, r'''// halal_engine.dart — ingredient-level halal analysis (v55)
// Pure Dart, no Flutter. Reads an ingredient list and explains *why* a
// product is halal / doubtful / haram instead of only giving a verdict.
// This is an automated aid, not a fatwa — the UI says so.
import '../data/models/models.dart';

class IngredientFlag {
  final String term;          // text that matched
  final HalalStatus level;    // haram | doubtful
  final String whyAr, whyEn;
  final bool animal;          // resolved when the product is known vegan
  const IngredientFlag({
    required this.term, required this.level,
    required this.whyAr, required this.whyEn, this.animal = false,
  });

  Map<String, dynamic> toJson() => {
        't': term, 'l': level.index, 'ar': whyAr, 'en': whyEn, 'a': animal,
      };

  factory IngredientFlag.fromJson(Map<String, dynamic> j) => IngredientFlag(
        term: (j['t'] ?? '') as String,
        level: HalalStatus.values[((j['l'] ?? 1) as int)
            .clamp(0, HalalStatus.values.length - 1)],
        whyAr: (j['ar'] ?? '') as String,
        whyEn: (j['en'] ?? '') as String,
        animal: (j['a'] ?? false) as bool,
      );
}

class HalalReport {
  final HalalStatus status;
  final List<IngredientFlag> flags;
  final bool certified; // carries a halal label on Open Food Facts
  const HalalReport(this.status, this.flags, {this.certified = false});
}

class _Rule {
  final RegExp re;
  final HalalStatus level;
  final String whyAr, whyEn;
  final bool animal;
  _Rule(String pattern, this.level, this.whyAr, this.whyEn, {this.animal = false})
      : re = RegExp(pattern);
}

class _E {
  final String name;
  final HalalStatus level;
  final bool animal;
  const _E(this.name, this.level, this.animal);
}

class HalalEngine {
  static final List<_Rule> _rules = [
    // ── haram ───────────────────────────────────────────
    _Rule(r'\bpork\b|porcine|\bpigs?\b|\bswine\b|bacon|\bham\b|prosciutto|pancetta|\blard\b|gammon',
        HalalStatus.haram, 'يحتوي على لحم الخنزير أو أحد مشتقاته',
        'Contains pork or a pork product'),
    _Rule(r'(?<!sugar )(?<!fatty )(?<!non-)(?<!cetyl )(?<!stearyl )(?<!benzyl )\balcohol(?!-free| free)|ethanol|\bwine\b|\bbeer\b|\brum\b|whisky|whiskey|brandy|liqueur|vodka|\bsake\b|\bmirin\b|cognac|sherry',
        HalalStatus.haram, 'يحتوي على كحول أو مشروب كحولي',
        'Contains alcohol or an alcoholic drink'),
    _Rule(r'\bblood(?! orange)', HalalStatus.haram,
        'الدم محرّم', 'Blood is prohibited'),
    _Rule(r'carmine|cochineal',
        HalalStatus.haram, 'صبغة حمراء مستخرجة من حشرة القرمز (كارمين)',
        'Red dye crushed from cochineal insects (carmine)'),
    // ── doubtful ────────────────────────────────────────
    _Rule(r'gelatin', HalalStatus.doubtful,
        'الجيلاتين غالباً من خنزير أو ذبيحة غير مذكّاة',
        'Gelatin is often pork- or non-halal-slaughter-derived', animal: true),
    _Rule(r'rennet|pepsin|\blipase', HalalStatus.doubtful,
        'إنفحة/إنزيم قد يكون حيواني المصدر',
        'Rennet or enzyme that may be animal-derived', animal: true),
    _Rule(r'animal fat|animal oil|tallow|suet|\bdripping', HalalStatus.doubtful,
        'دهن حيواني — يجب أن يكون من ذبيحة حلال',
        'Animal fat — must come from halal slaughter', animal: true),
    _Rule(r'\b(beef|chicken|lamb|mutton|turkey|duck|veal|goat|poultry|meat)\b',
        HalalStatus.doubtful,
        'لحوم — تأكد من الذبح الحلال',
        'Meat — check it is halal-slaughtered', animal: true),
    _Rule(r'\bcollagen|\bbone\b', HalalStatus.doubtful,
        'مصدر حيواني غير محدد', 'Unspecified animal source', animal: true),
    _Rule(r'isinglass|cysteine', HalalStatus.doubtful,
        'مشتق حيواني (سمك/ريش/شعر) — المصدر غير معروف',
        'Animal-derived aid (fish / feathers / hair) — source unknown', animal: true),
    _Rule(r'shellac|confectioner.?s glaze', HalalStatus.doubtful,
        'إفراز حشرة — مختلف فيه بين العلماء',
        'Insect secretion — scholars differ', animal: true),
    _Rule(r'glycerol|glycerin', HalalStatus.doubtful,
        'الجلسرين قد يكون حيوانياً أو نباتياً',
        'Glycerin can be animal or plant derived', animal: true),
    _Rule(r'mono-? ?and ?di-?glycerides?|monoglycerides?|diglycerides?',
        HalalStatus.doubtful,
        'مستحلب قد يكون من دهن حيواني',
        'Emulsifier that can come from animal fat', animal: true),
    _Rule(r'natural flavou?rs?', HalalStatus.doubtful,
        'النكهة الطبيعية قد تُذاب في كحول',
        'Natural flavour may use alcohol as a carrier'),
    _Rule(r'vanilla extract', HalalStatus.doubtful,
        'مستخلص الفانيلا عادةً في كحول',
        'Vanilla extract is usually alcohol-based'),
    _Rule(r'wine vinegar', HalalStatus.doubtful,
        'خل النبيذ — أجازه كثير من العلماء بعد التحوّل',
        'Wine vinegar — many scholars permit it after transformation'),
  ];

  static const Map<String, _E> _eTable = {
    'e120': _E('Carmine', HalalStatus.haram, true),
    'e441': _E('Gelatin', HalalStatus.doubtful, true),
    'e542': _E('Bone phosphate', HalalStatus.doubtful, true),
    'e904': _E('Shellac', HalalStatus.doubtful, true),
    'e920': _E('L-cysteine', HalalStatus.doubtful, true),
    'e422': _E('Glycerol', HalalStatus.doubtful, true),
    'e470a': _E('Fatty acid salts', HalalStatus.doubtful, true),
    'e470b': _E('Fatty acid salts', HalalStatus.doubtful, true),
    'e471': _E('Mono- & diglycerides', HalalStatus.doubtful, true),
    'e472a': _E('Mono-/diglyceride esters', HalalStatus.doubtful, true),
    'e472b': _E('Mono-/diglyceride esters', HalalStatus.doubtful, true),
    'e472c': _E('Mono-/diglyceride esters', HalalStatus.doubtful, true),
    'e472e': _E('Mono-/diglyceride esters', HalalStatus.doubtful, true),
    'e473': _E('Sucrose esters', HalalStatus.doubtful, true),
    'e474': _E('Sucroglycerides', HalalStatus.doubtful, true),
    'e475': _E('Polyglycerol esters', HalalStatus.doubtful, true),
    'e476': _E('PGPR', HalalStatus.doubtful, true),
    'e477': _E('Propylene glycol esters', HalalStatus.doubtful, true),
    'e481': _E('Sodium stearoyl lactylate', HalalStatus.doubtful, true),
    'e482': _E('Calcium stearoyl lactylate', HalalStatus.doubtful, true),
    'e491': _E('Sorbitan monostearate', HalalStatus.doubtful, true),
    'e492': _E('Sorbitan tristearate', HalalStatus.doubtful, true),
    'e493': _E('Sorbitan monolaurate', HalalStatus.doubtful, true),
    'e494': _E('Sorbitan monooleate', HalalStatus.doubtful, true),
    'e495': _E('Sorbitan monopalmitate', HalalStatus.doubtful, true),
    'e570': _E('Stearic acid', HalalStatus.doubtful, true),
    'e572': _E('Magnesium stearate', HalalStatus.doubtful, true),
    'e627': _E('Disodium guanylate', HalalStatus.doubtful, true),
    'e631': _E('Disodium inosinate', HalalStatus.doubtful, true),
    'e635': _E('Disodium ribonucleotides', HalalStatus.doubtful, true),
    'e913': _E('Lanolin', HalalStatus.doubtful, true),
    'e1105': _E('Lysozyme', HalalStatus.doubtful, true),
    'e1510': _E('Ethanol', HalalStatus.doubtful, false),
  };

  static final RegExp _eRe = RegExp(r'\be-?(\d{3,4}[a-f]?)\b');

  /// [vegan]: true when Open Food Facts says the product is vegan (animal
  /// sources are then ruled out). [certified]: a halal label is on the pack.
  static HalalReport analyze(String ingredients,
      {bool? vegan, bool certified = false}) {
    final raw = ingredients.trim();
    if (raw.isEmpty) {
      return HalalReport(
          certified ? HalalStatus.halal : HalalStatus.unknown, const [],
          certified: certified);
    }
    final lower = raw.toLowerCase();
    // "wine vinegar" is judged on its own, not as wine.
    final forHaram = lower.replaceAll('wine vinegar', ' ');
    final flags = <IngredientFlag>[];
    final seen = <String>{};

    for (final r in _rules) {
      final src = r.level == HalalStatus.haram ? forHaram : lower;
      final m = r.re.firstMatch(src);
      if (m == null) continue;
      if (!seen.add(r.whyEn)) continue;
      flags.add(IngredientFlag(
        term: m.group(0)!.trim(), level: r.level,
        whyAr: r.whyAr, whyEn: r.whyEn, animal: r.animal));
    }

    for (final m in _eRe.allMatches(lower)) {
      final code = 'e${m.group(1)}';
      final e = _eTable[code];
      if (e == null) continue;
      final why = e.level == HalalStatus.haram
          ? 'Red dye crushed from cochineal insects (carmine)'
          : '${e.name} (${code.toUpperCase()}) can be animal-derived — source unknown';
      final whyAr = e.level == HalalStatus.haram
          ? 'صبغة حمراء مستخرجة من حشرة القرمز (كارمين)'
          : '${e.name} (${code.toUpperCase()}) قد يكون حيواني المصدر — المصدر غير معروف';
      // Same finding already reported by the name rules (e.g. gelatin + E441).
      final dup = flags.any((f) =>
          f.whyEn == why ||
          (e.name == 'Gelatin' && f.whyEn.startsWith('Gelatin')) ||
          (e.name == 'Carmine' && f.whyEn.contains('carmine')) ||
          (e.name == 'Glycerol' && f.whyEn.startsWith('Glycerin')) ||
          (e.name.startsWith('Mono- &') && f.whyEn.startsWith('Emulsifier')));
      if (dup || !seen.add(why)) continue;
      flags.add(IngredientFlag(
        term: code.toUpperCase(), level: e.level,
        whyAr: whyAr, whyEn: why, animal: e.animal));
    }

    if (vegan == true) {
      flags.removeWhere((f) => f.animal && f.level == HalalStatus.doubtful);
    }

    flags.sort((a, b) => a.level.index == b.level.index
        ? 0
        : (a.level == HalalStatus.haram ? -1 : 1));

    HalalStatus status = HalalStatus.halal;
    if (flags.any((f) => f.level == HalalStatus.haram)) {
      status = HalalStatus.haram;
    } else if (flags.any((f) => f.level == HalalStatus.doubtful)) {
      status = certified ? HalalStatus.halal : HalalStatus.doubtful;
    }
    return HalalReport(status, flags, certified: certified);
  }
}
''')
write(SS, r'''// scan_store.dart — persistent scan history, favourites and offline cache (v55)
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/models.dart';

class ScanStore {
  static const _kHistory = 'scan_history_v2';
  static const _kFavs    = 'scan_favs_v1';
  static const _kCache   = 'scan_cache_v1';
  static const _cacheMax = 80;

  static Map<String, dynamic> toJson(ScanResult r) => {
        'b': r.barcode, 'n': r.name, 'br': r.brand,
        's': r.status.index, 'c': r.certs, 'no': r.notes,
        'at': r.scannedAt.toIso8601String(),
        'k': r.kcal, 'p': r.proteinG, 'ca': r.carbsG, 'f': r.fatG,
        'd': r.details,
      };

  static ScanResult fromJson(Map<String, dynamic> j) => ScanResult(
        barcode: (j['b'] ?? '') as String,
        name: (j['n'] ?? '') as String,
        brand: j['br'] as String?,
        status: HalalStatus.values[((j['s'] ?? 3) as int)
            .clamp(0, HalalStatus.values.length - 1)],
        certs: ((j['c'] ?? const []) as List).map((e) => '$e').toList(),
        notes: j['no'] as String?,
        scannedAt: DateTime.tryParse((j['at'] ?? '') as String),
        kcal: (j['k'] as num?)?.toInt(),
        proteinG: (j['p'] as num?)?.toDouble(),
        carbsG: (j['ca'] as num?)?.toDouble(),
        fatG: (j['f'] as num?)?.toDouble(),
        details: j['d'] == null
            ? null
            : Map<String, dynamic>.from(j['d'] as Map),
      );

  // ── History ────────────────────────────────────────────
  static Future<List<ScanResult>> loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kHistory);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          if (e is Map) fromJson(Map<String, dynamic>.from(e))
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHistory(List<ScanResult> h) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kHistory, jsonEncode([for (final r in h.take(100)) toJson(r)]));
    } catch (_) {}
  }

  // ── Offline cache (barcode → last good lookup) ─────────
  static Future<ScanResult?> cacheGet(String barcode) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final e = m[barcode];
      if (e is! Map) return null;
      return fromJson(Map<String, dynamic>.from(e));
    } catch (_) {
      return null;
    }
  }

  static Future<void> cachePut(ScanResult r) async {
    try {
      final p = await SharedPreferences.getInstance();
      Map<String, dynamic> m = {};
      final raw = p.getString(_kCache);
      if (raw != null) m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      m.remove(r.barcode);
      m[r.barcode] = toJson(r);
      while (m.length > _cacheMax) {
        m.remove(m.keys.first);
      }
      await p.setString(_kCache, jsonEncode(m));
    } catch (_) {}
  }

  // ── Favourites ─────────────────────────────────────────
  static Future<Set<String>> loadFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_kFavs) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavs(Set<String> s) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kFavs, s.toList());
    } catch (_) {}
  }
}

class ScanFavsNotifier extends StateNotifier<Set<String>> {
  ScanFavsNotifier() : super(const {}) {
    ScanStore.loadFavs().then((s) {
      if (mounted) state = {...state, ...s};
    });
  }
  bool has(String barcode) => state.contains(barcode);
  void toggle(String barcode) {
    final n = {...state};
    if (!n.remove(barcode)) n.add(barcode);
    state = n;
    ScanStore.saveFavs(n);
  }
}

final scanFavsProvider =
    StateNotifierProvider<ScanFavsNotifier, Set<String>>(
        (ref) => ScanFavsNotifier());
''')
write(WP, r'''// workout_player_pro.dart — HalalCalorie v57
// Workout player rebuilt: get-ready countdown, timed + rep steps, rest
// periods, haptic/sound cues, pause / back / skip, real elapsed time,
// MET-based calories, saved sessions, weekly stats + history.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';
import '../../core/database.dart';
import '../../core/fx6.dart' show GlassIconBtn, EmojiIcon;
import '../../data/models/models.dart';
import '../../data/icon_assets.dart';

enum _Ph { ready, countdown, work, rest, done }

const Map<String, double> _kMet = {
  'walking': 3.5, 'strength': 5.0, 'cardio': 8.0, 'gentle': 2.5,
  'ramadan': 3.0, 'breathing': 1.5, 'family': 4.0, 'postnatal': 2.5,
};

// ══════════════════════════════════════════════════════════════════
//  Player
// ══════════════════════════════════════════════════════════════════
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  final String workoutId;
  const WorkoutPlayerScreen({super.key, required this.workoutId});
  @override
  ConsumerState<WorkoutPlayerScreen> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends ConsumerState<WorkoutPlayerScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  _Ph _ph = _Ph.ready;
  bool _paused = false;
  bool _sound = true;
  bool _saved = false;
  int _i = 0;            // current step
  int _left = 0;         // seconds left (countdown / timed work / rest)
  int _stepElapsed = 0;
  int _workSec = 0, _restSec = 0, _stepsDone = 0;
  int _restLen = 15;
  double _kcalFinal = 0;
  Map<String, dynamic>? _last;
  late final AnimationController _pulse;
  late final AnimationController _confetti;

  Workout get _w => kWorkouts.firstWhere((w) => w.id == widget.workoutId,
      orElse: () => kWorkouts.first);

  List<WorkoutStep> get _steps {
    final w = _w;
    if (w.steps.isNotEmpty) return w.steps;
    // Workouts with no step list play as one timed block.
    return [
      WorkoutStep(
          nameAr: w.titleAr, nameEn: w.titleEn,
          durationSec: w.durationMin * 60, reps: 0),
    ];
  }

  WorkoutStep get _step => _steps[_i.clamp(0, _steps.length - 1)];
  bool get _timed => _step.durationSec > 0;
  bool get _isLast => _i >= _steps.length - 1;

  int get _estSeconds {
    var s = 0;
    for (final st in _steps) {
      s += st.durationSec > 0 ? st.durationSec : math.max(20, st.reps * 3);
    }
    return s + _restLen * math.max(0, _steps.length - 1);
  }

  double get _bodyKg {
    final kg = ref.read(rankingBodyweightProvider);
    return kg > 20 ? kg : 70;
  }

  double get _met => _kMet[_w.category] ?? 4.0;

  double _kcalFor(int work, int rest) =>
      (_met * _bodyKg * work + 1.5 * _bodyKg * rest) / 3600.0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _confetti = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    AppDatabase.getLastSession(widget.workoutId).then((m) {
      if (mounted) setState(() => _last = m);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _confetti.dispose();
    super.dispose();
  }

  // ── cues ───────────────────────────────────────────────
  void _cue(int level) {
    if (level == 0) {
      HapticFeedback.selectionClick();
    } else if (level == 1) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    if (_sound && level > 0) SystemSound.play(SystemSoundType.click);
  }

  // ── flow ───────────────────────────────────────────────
  void _start() {
    setState(() {
      _ph = _Ph.countdown;
      _left = 3;
      _paused = false;
    });
    _cue(1);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer t) {
    if (!mounted || _paused) return;
    setState(() {
      switch (_ph) {
        case _Ph.countdown:
          _left--;
          if (_left <= 0) {
            _beginWork(0);
          } else {
            _cue(0);
          }
          break;
        case _Ph.work:
          _workSec++;
          _stepElapsed++;
          if (_timed) {
            _left = _step.durationSec - _stepElapsed;
            if (_left <= 0) {
              _completeStep();
            } else if (_left <= 3) {
              _cue(0);
            }
          }
          break;
        case _Ph.rest:
          _restSec++;
          _left--;
          if (_left <= 0) {
            _beginWork(_i + 1);
          } else if (_left <= 3) {
            _cue(0);
          }
          break;
        default:
          break;
      }
    });
  }

  void _beginWork(int i) {
    _i = i.clamp(0, _steps.length - 1);
    _ph = _Ph.work;
    _stepElapsed = 0;
    _left = _timed ? _step.durationSec : 0;
    _cue(2);
  }

  void _completeStep() {
    _stepsDone++;
    if (_isLast) {
      _finish();
    } else if (_restLen > 0) {
      _ph = _Ph.rest;
      _left = _restLen;
      _cue(1);
    } else {
      _beginWork(_i + 1);
    }
  }

  void _skip() {
    setState(() {
      if (_ph == _Ph.rest) {
        _beginWork(_i + 1);
      } else if (_ph == _Ph.work) {
        if (_isLast) {
          _finish();
        } else {
          _beginWork(_i + 1);
        }
      }
    });
  }

  void _prev() {
    setState(() {
      if (_ph == _Ph.rest) {
        _beginWork(_i);
      } else if (_ph == _Ph.work) {
        _beginWork(_stepElapsed > 3 || _i == 0 ? _i : _i - 1);
      }
    });
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    HapticFeedback.selectionClick();
  }

  void _finish() {
    _timer?.cancel();
    _ph = _Ph.done;
    _paused = false;
    _kcalFinal = _kcalFor(_workSec, _restSec);
    _confetti.forward(from: 0);
    HapticFeedback.heavyImpact();
    _save(completed: true);
  }

  Future<void> _save({required bool completed}) async {
    if (_saved) return;
    _saved = true;
    final w = _w;
    final secs = _workSec + _restSec;
    if (secs < 5) return;
    final kcal = _kcalFor(_workSec, _restSec);
    final mins = (secs / 60).round().clamp(1, 600).toInt();
    final minN = ref.read(workoutMinutesProvider.notifier);
    final streakN = ref.read(streakProvider.notifier);
    try {
      await minN.add(w.id, mins, kcal: kcal);
      await AppDatabase.logSession(
        workoutId: w.id, seconds: secs, kcal: kcal,
        stepsDone: _stepsDone, stepsTotal: _steps.length,
      );
      if (completed || secs >= 120) await streakN.increment();
      if (mounted) {
        ref.invalidate(caloriesBurnedTodayProvider);
        ref.invalidate(workoutStatsProvider);
      }
    } catch (_) {}
  }

  Future<bool> _confirmQuit() async {
    if (_ph == _Ph.ready || _ph == _Ph.done) return true;
    final wasPaused = _paused;
    setState(() => _paused = true);
    final lang = ref.read(languageProvider);
    String t(String ar, String en) => tLang(lang, ar, en);
    final canSave = _workSec >= 30 || _stepsDone > 0;
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('إنهاء التمرين؟', 'End workout?'),
            style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800)),
        content: Text(
            canSave
                ? t('يمكنك حفظ ما أنجزته حتى الآن.', 'You can save what you have done so far.')
                : t('لم تنجز شيئاً بعد.', 'You have not done anything yet.'),
            style: const TextStyle(fontFamily: 'Aligarh')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, 'stay'),
              child: Text(t('أكمل', 'Keep going'),
                  style: const TextStyle(fontFamily: 'Aligarh'))),
          TextButton(
              onPressed: () => Navigator.pop(c, 'discard'),
              child: Text(t('تجاهل', 'Discard'),
                  style: const TextStyle(fontFamily: 'Aligarh', color: AppColors.haramRed))),
          if (canSave)
            ElevatedButton(
                onPressed: () => Navigator.pop(c, 'save'),
                child: Text(t('احفظ وأنهِ', 'Save & finish'),
                    style: const TextStyle(fontFamily: 'Aligarh'))),
        ],
      ),
    );
    if (r == 'save') {
      _timer?.cancel();
      await _save(completed: false);
      return true;
    }
    if (r == 'discard') {
      _timer?.cancel();
      return true;
    }
    if (mounted) setState(() => _paused = wasPaused);
    return false;
  }

  String _fmt(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    final isDark = ref.watch(themeProvider);
    final isSis = ref.watch(genderProvider) == 'sisters';
    final ram = ref.watch(ramadanModeProvider) && !isSis;
    String t(String ar, String en) => tLang(lang, ar, en);

    final Color bg = ram
        ? (isDark ? AppColors.ramadanNight : AppColors.ramadanDay)
        : (isDark ? AppColors.darkBg : AppColors.lightBg);
    final Color textC = ram
        ? (isDark ? AppColors.ramadanText : AppColors.ramadanDayText)
        : (isDark ? AppColors.darkText : AppColors.lightText);
    final Color muted = ram
        ? (isDark ? AppColors.ramadanMuted : AppColors.ramadanDayMuted)
        : (isDark ? AppColors.darkMuted : AppColors.lightMuted);
    final Color accent = ram
        ? (isDark ? AppColors.ramadanGold : AppColors.ramadanGoldDim)
        : (isSis ? AppColors.accentGold : AppColors.brandGreen);
    final Color phaseCol = _ph == _Ph.rest
        ? AppColors.waterBlue
        : (_ph == _Ph.countdown ? AppColors.accentGold : accent);

    final w = _w;
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: WillPopScope(
        onWillPop: _confirmQuit,
        child: Scaffold(
          backgroundColor: bg,
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.55),
                radius: 1.15,
                colors: [phaseCol.withOpacity(isDark ? 0.22 : 0.14), bg],
              ),
            ),
            child: SafeArea(
              child: Column(children: [
                _topBar(w, isAr, isDark, textC, muted, phaseCol),
                if (_ph != _Ph.ready && _ph != _Ph.done)
                  _stepBars(accent, textC),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    child: KeyedSubtree(
                      key: ValueKey('$_ph-${_ph == _Ph.work ? _i : 0}'),
                      child: _ph == _Ph.ready
                          ? _readyView(w, t, isAr, isDark, textC, muted, accent)
                          : _ph == _Ph.done
                              ? _doneView(w, t, isAr, textC, muted, accent)
                              : _liveView(w, t, isAr, isDark, textC, muted, accent, phaseCol, isSis),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(Workout w, bool isAr, bool isDark, Color textC, Color muted, Color col) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(children: [
        GlassIconBtn(
          icon: Icons.close_rounded, isDark: isDark,
          onTap: () async {
            if (await _confirmQuit() && mounted) context.pop();
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(isAr ? w.titleAr : w.titleEn,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
                  fontWeight: FontWeight.w800, color: textC)),
        ),
        GlassIconBtn(
          icon: _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          isDark: isDark,
          onTap: () => setState(() => _sound = !_sound),
        ),
      ]),
    );
  }

  Widget _stepBars(Color accent, Color textC) {
    final n = _steps.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 2),
      child: Row(children: [
        for (var k = 0; k < n; k++) ...[
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: k < _i || (k == _i && _ph == _Ph.rest)
                    ? accent
                    : (k == _i ? accent.withOpacity(0.55) : textC.withOpacity(0.12)),
              ),
            ),
          ),
          if (k < n - 1) const SizedBox(width: 3),
        ],
      ]),
    );
  }

  // ── READY ────────────────────────────────────────────────
  Widget _readyView(Workout w, String Function(String, String) t, bool isAr,
      bool isDark, Color textC, Color muted, Color accent) {
    final estMin = (_estSeconds / 60).ceil();
    final estKcal = _kcalFor((_estSeconds - _restLen * (_steps.length - 1)).clamp(0, 99999).toInt(),
        _restLen * (_steps.length - 1));
    Widget stat(IconData ic, String v, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: textC.withOpacity(0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: textC.withOpacity(0.08)),
            ),
            child: Column(children: [
              Icon(ic, size: 20, color: accent),
              const SizedBox(height: 6),
              Text(v, style: TextStyle(fontFamily: 'Aligarh', fontSize: 18,
                  fontWeight: FontWeight.w900, color: textC)),
              Text(l, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
            ]),
          ),
        );
    final last = _last;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      children: [
        Center(child: _plate(w, isDark, accent, 132)),
        const SizedBox(height: 16),
        Text(isAr ? w.descAr : w.descEn,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 13, height: 1.5, color: muted)),
        const SizedBox(height: 18),
        Row(children: [
          stat(Icons.format_list_numbered_rounded, '${_steps.length}', t('تمارين', 'Exercises')),
          const SizedBox(width: 10),
          stat(Icons.timer_rounded, '$estMin', t('دقيقة', 'Minutes')),
          const SizedBox(width: 10),
          stat(Icons.local_fire_department_rounded, '~${estKcal.round()}', t('سعرة', 'kcal')),
        ]),
        const SizedBox(height: 18),
        Text(t('الراحة بين التمارين', 'Rest between exercises'),
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                fontWeight: FontWeight.w800, color: muted)),
        const SizedBox(height: 8),
        Row(children: [
          for (final r in const [0, 10, 15, 20, 30]) ...[
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _restLen = r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _restLen == r ? accent : textC.withOpacity(0.06),
                  ),
                  child: Text(r == 0 ? t('بدون', 'Off') : '${r}s',
                      style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _restLen == r
                              ? (isDark && accent == AppColors.accentGold ? AppColors.ramadanInk : Colors.white)
                              : muted)),
                ),
              ),
            ),
            if (r != 30) const SizedBox(width: 6),
          ],
        ]),
        if (last != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t('آخر مرة: ${(((last['seconds'] as num?) ?? 0) / 60).round()} دقيقة · ${((last['kcal'] as num?) ?? 0).round()} سعرة',
                      'Last time: ${(((last['seconds'] as num?) ?? 0) / 60).round()} min · ${((last['kcal'] as num?) ?? 0).round()} kcal'),
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: textC)),
              ),
            ]),
          ),
        ],
        if (w.note != null) ...[
          const SizedBox(height: 12),
          Text(isAr ? w.note! : (w.noteEn ?? w.note!),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 11.5, height: 1.6,
                  fontStyle: FontStyle.italic, color: AppColors.accentGold)),
        ],
        const SizedBox(height: 22),
        _bigButton(t('ابدأ التمرين', 'Start workout'), Icons.play_arrow_rounded, accent, _start),
      ],
    );
  }

  Widget _bigButton(String label, IconData ic, Color col, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [col, Color.lerp(col, Colors.black, 0.22)!]),
          boxShadow: [BoxShadow(color: col.withOpacity(0.38), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ic, color: Colors.white, size: 26),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 17,
              fontWeight: FontWeight.w900, color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _plate(Workout w, bool isDark, Color accent, double size) {
    final isSis = ref.read(genderProvider) == 'sisters';
    final iconPath = workoutIconAsset(w.id, isSis);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withOpacity(isDark ? 0.12 : 0.10),
        border: Border.all(color: accent.withOpacity(0.28)),
      ),
      child: Center(
        child: iconPath != null
            ? darkSafeAsset(iconPath,
                width: size * 0.62, height: size * 0.62, fit: BoxFit.contain,
                isDark: isDark, errorChild: EmojiIcon(w.emoji, size: size * 0.4))
            : EmojiIcon(w.emoji, size: size * 0.4),
      ),
    );
  }

  // ── LIVE (countdown / work / rest) ───────────────────────
  Widget _liveView(Workout w, String Function(String, String) t, bool isAr,
      bool isDark, Color textC, Color muted, Color accent, Color phaseCol, bool isSis) {
    final st = _step;
    final next = _isLast ? null : _steps[_i + 1];
    final isCount = _ph == _Ph.countdown;
    final isRest = _ph == _Ph.rest;

    double prog;
    String big, small;
    if (isCount) {
      prog = (3 - _left) / 3.0;
      big = '$_left';
      small = t('استعد', 'Get ready');
    } else if (isRest) {
      prog = _restLen == 0 ? 1 : 1 - _left / _restLen;
      big = _fmt(_left);
      small = t('راحة', 'Rest');
    } else if (_timed) {
      prog = _stepElapsed / st.durationSec;
      big = _fmt(_left);
      small = t('متبقي', 'left');
    } else {
      prog = 1;
      big = '${st.reps}';
      small = t('مرة', 'reps');
    }

    final shownStep = isRest ? (next ?? st) : st;
    final title = isCount
        ? t('سنبدأ بـ ${isAr ? st.nameAr : st.nameEn}', 'First up: ${isAr ? st.nameAr : st.nameEn}')
        : (isRest
            ? t('التالي: ${isAr ? shownStep.nameAr : shownStep.nameEn}',
                'Up next: ${isAr ? shownStep.nameAr : shownStep.nameEn}')
            : (isAr ? st.nameAr : st.nameEn));
    final instr = (isRest ? shownStep : st);
    final instrText = isAr ? instr.instructionAr : (instr.instructionEn ?? instr.instructionAr);

    return Column(children: [
      const SizedBox(height: 6),
      Text(
        isCount ? t('تجهّز', 'GET READY')
            : isRest ? t('استرح', 'REST')
            : t('تمرين ${_i + 1} من ${_steps.length}', 'EXERCISE ${_i + 1} OF ${_steps.length}'),
        style: TextStyle(fontFamily: 'Aligarh', fontSize: 11.5, letterSpacing: 1.2,
            fontWeight: FontWeight.w800, color: phaseCol)),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Text(title, textAlign: TextAlign.center, maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 22,
                fontWeight: FontWeight.w900, color: textC, height: 1.2)),
      ),
      const SizedBox(height: 4),
      if (instrText != null && instrText.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(instrText, textAlign: TextAlign.center, maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 12.5, height: 1.5, color: muted)),
        ),
      Expanded(
        child: Center(
          child: SizedBox(
            width: 250, height: 250,
            child: Stack(alignment: Alignment.center, children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  size: const Size(250, 250),
                  painter: _RingPainter(
                    progress: prog.clamp(0.0, 1.0).toDouble(),
                    color: phaseCol,
                    track: textC.withOpacity(0.10),
                    glow: _paused ? 0 : _pulse.value,
                  ),
                ),
              ),
              if (!isCount && !isRest)
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(34),
                    child: Opacity(opacity: 0.16, child: _plate(w, isDark, phaseCol, 180)),
                  ),
                ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(big, style: TextStyle(fontFamily: 'Aligarh',
                    fontSize: isCount ? 84 : 60, fontWeight: FontWeight.w900,
                    color: textC, height: 1.0)),
                const SizedBox(height: 4),
                Text(_paused ? t('متوقف', 'Paused') : small,
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _paused ? AppColors.accentGold : muted)),
              ]),
            ]),
          ),
        ),
      ),
      if (next != null && !isRest && !isCount)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.skip_next_rounded, size: 16, color: muted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                  t('التالي: ${isAr ? next.nameAr : next.nameEn}',
                      'Next: ${isAr ? next.nameAr : next.nameEn}'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
        child: Column(children: [
          if (_ph == _Ph.work && !_timed) ...[
            _bigButton(t('أنهيت المجموعة', 'Set done'), Icons.check_rounded, accent,
                () => setState(_completeStep)),
            const SizedBox(height: 12),
          ],
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _roundBtn(Icons.skip_previous_rounded, textC, 52, _ph == _Ph.countdown ? null : _prev),
            const SizedBox(width: 18),
            _roundBtn(_paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                phaseCol, 72, _togglePause, filled: true),
            const SizedBox(width: 18),
            _roundBtn(Icons.skip_next_rounded, textC, 52, _ph == _Ph.countdown ? null : _skip),
          ]),
          if (isRest) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setState(() => _left += 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.waterBlue.withOpacity(0.14),
                  border: Border.all(color: AppColors.waterBlue.withOpacity(0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded, size: 16, color: AppColors.waterBlue),
                  const SizedBox(width: 4),
                  Text('15 ${t("ثانية", "sec")}',
                      style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12.5,
                          fontWeight: FontWeight.w800, color: AppColors.waterBlue)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }

  Widget _roundBtn(IconData ic, Color col, double size, VoidCallback? onTap,
      {bool filled = false}) {
    final off = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: off ? 0.3 : 1,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? col : col.withOpacity(0.10),
            border: filled ? null : Border.all(color: col.withOpacity(0.25)),
            boxShadow: filled
                ? [BoxShadow(color: col.withOpacity(0.40), blurRadius: 18, offset: const Offset(0, 6))]
                : null,
          ),
          child: Icon(ic, size: size * 0.5, color: filled ? Colors.white : col),
        ),
      ),
    );
  }

  // ── DONE ─────────────────────────────────────────────────
  Widget _doneView(Workout w, String Function(String, String) t, bool isAr,
      Color textC, Color muted, Color accent) {
    final secs = _workSec + _restSec;
    final mins = (secs / 60).ceil().clamp(1, 999).toInt();
    final streak = ref.watch(streakProvider);
    final last = _last;
    String? delta;
    if (last != null) {
      final prev = ((last['seconds'] as num?) ?? 0).toInt();
      final d = ((secs - prev) / 60).round();
      if (d != 0) {
        delta = d > 0
            ? t('أطول بـ $d دقيقة من آخر مرة', '$d min longer than last time')
            : t('أقصر بـ ${-d} دقيقة من آخر مرة', '${-d} min shorter than last time');
      } else {
        delta = t('نفس مدة آخر مرة', 'Same length as last time');
      }
    }
    Widget tile(IconData ic, String v, String l, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.withOpacity(0.25)),
            ),
            child: Column(children: [
              Icon(ic, size: 22, color: c),
              const SizedBox(height: 6),
              Text(v, style: TextStyle(fontFamily: 'Aligarh', fontSize: 22,
                  fontWeight: FontWeight.w900, color: textC)),
              Text(l, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5, color: muted)),
            ]),
          ),
        );
    return Stack(children: [
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _confetti,
            builder: (_, __) => CustomPaint(painter: _ConfettiPainter(_confetti.value)),
          ),
        ),
      ),
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Center(
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [accent, Color.lerp(accent, Colors.black, 0.25)!]),
                boxShadow: [BoxShadow(color: accent.withOpacity(0.45), blurRadius: 28)],
              ),
              child: const Icon(Icons.emoji_events_rounded, size: 52, color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('أحسنت!', 'Well done!'), textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 28,
                  fontWeight: FontWeight.w900, color: accent)),
          const SizedBox(height: 4),
          Text(isAr ? w.titleAr : w.titleEn, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 14, color: muted)),
          const SizedBox(height: 22),
          Row(children: [
            tile(Icons.timer_rounded, '$mins', t('دقيقة', 'Minutes'), AppColors.waterBlue),
            const SizedBox(width: 10),
            tile(Icons.local_fire_department_rounded, '${_kcalFinal.round()}', t('سعرة', 'kcal'), AppColors.haramRed),
            const SizedBox(width: 10),
            tile(Icons.check_circle_rounded, '$_stepsDone/${_steps.length}', t('تمارين', 'Exercises'), AppColors.halalGreen),
          ]),
          const SizedBox(height: 14),
          if (streak > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.local_fire_department_rounded, color: AppColors.accentGold),
                const SizedBox(width: 8),
                Text(t('سلسلتك $streak يوم', 'Your streak: $streak days'),
                    style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14,
                        fontWeight: FontWeight.w800, color: AppColors.accentGold)),
              ]),
            ),
          if (delta != null) ...[
            const SizedBox(height: 10),
            Text(delta, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
          ],
          const SizedBox(height: 22),
          _bigButton(t('رجوع للتمارين', 'Back to workouts'), Icons.check_rounded, accent,
              () => context.pop()),
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _timer?.cancel();
                  _ph = _Ph.ready; _i = 0; _workSec = 0; _restSec = 0;
                  _stepsDone = 0; _saved = false; _left = 0; _stepElapsed = 0;
                });
                AppDatabase.getLastSession(widget.workoutId).then((m) {
                  if (mounted) setState(() => _last = m);
                });
              },
              icon: Icon(Icons.replay_rounded, size: 18, color: muted),
              label: Text(t('تمرين مرة أخرى', 'Go again'),
                  style: TextStyle(fontFamily: 'Aligarh', color: muted)),
            ),
          ),
        ],
      ),
    ]);
  }
}

// ── painters ─────────────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final double progress, glow;
  final Color color, track;
  _RingPainter({required this.progress, required this.color,
      required this.track, required this.glow});
  @override
  void paint(Canvas c, Size s) {
    const stroke = 14.0;
    final r = Rect.fromLTWH(stroke, stroke, s.width - stroke * 2, s.height - stroke * 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    c.drawArc(r, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final glowP = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 6 * glow
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.16 + 0.12 * glow)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    c.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, glowP);
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    c.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.progress != progress || o.glow != glow || o.color != color;
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);
  static const _cols = [
    Color(0xFF3FB950), Color(0xFFDBA75D), Color(0xFF6FB3FF),
    Color(0xFFBC8CFF), Color(0xFFEF6A60),
  ];
  @override
  void paint(Canvas c, Size s) {
    if (t <= 0 || t >= 1) return;
    final rnd = math.Random(7);
    for (var i = 0; i < 60; i++) {
      final x0 = rnd.nextDouble() * s.width;
      final speed = 0.6 + rnd.nextDouble() * 0.9;
      final drift = (rnd.nextDouble() - 0.5) * 80;
      final spin = rnd.nextDouble() * 6;
      final y = -20 + (s.height * 0.9) * (t * speed);
      final x = x0 + drift * t;
      final p = Paint()..color = _cols[i % _cols.length].withOpacity((1 - t).clamp(0.0, 1.0).toDouble());
      c.save();
      c.translate(x, y);
      c.rotate(spin * t * 6);
      c.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -2, 8, 4), const Radius.circular(1.5)), p);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}

// ══════════════════════════════════════════════════════════════════
//  Weekly stats + history (shown on the Fitness screen)
// ══════════════════════════════════════════════════════════════════
class WorkoutStats {
  final Map<String, Map<String, num>> byDay; // date_key → {s, k, c}
  final List<Map<String, dynamic>> sessions;
  const WorkoutStats(this.byDay, this.sessions);
}

final workoutStatsProvider = FutureProvider.autoDispose<WorkoutStats>((ref) async {
  ref.watch(workoutMinutesProvider);
  final rows = await AppDatabase.getDailyWorkoutStats(7);
  final sessions = await AppDatabase.getSessions(limit: 40);
  return WorkoutStats({
    for (final r in rows)
      '${r['date_key']}': {
        's': (r['s'] as num?) ?? 0,
        'k': (r['k'] as num?) ?? 0,
        'c': (r['c'] as num?) ?? 0,
      }
  }, sessions);
});

String _dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';

class WorkoutStatsCard extends ConsumerWidget {
  final Color card, textC, muted, accent;
  final bool isAr, isDark;
  const WorkoutStatsCard({
    super.key, required this.card, required this.textC, required this.muted,
    required this.accent, required this.isAr, required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(workoutStatsProvider);
    return data.maybeWhen(
      data: (s) {
        if (s.sessions.isEmpty) return const SizedBox.shrink();
        String t(String ar, String en) => isAr ? ar : en;
        final today = DateTime.now();
        final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
        num sumS = 0, sumK = 0, sumC = 0, maxS = 1;
        for (final d in days) {
          final m = s.byDay[_dayKey(d)];
          if (m == null) continue;
          sumS += m['s']!; sumK += m['k']!; sumC += m['c']!;
          if (m['s']! > maxS) maxS = m['s']!;
        }
        const arD = ['إث', 'ث', 'أر', 'خ', 'ج', 'س', 'ح'];
        const enD = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withOpacity(0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.insights_rounded, color: accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t('أسبوعك', 'Your week'),
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 15,
                        fontWeight: FontWeight.w900, color: textC)),
              ),
              GestureDetector(
                onTap: () => showWorkoutHistory(context, s.sessions, isAr, isDark, textC, muted, accent, card),
                child: Text(t('السجل', 'History'),
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                        fontWeight: FontWeight.w800, color: accent)),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _mini('${sumC.round()}', t('جلسات', 'Sessions'), textC, muted),
              _mini('${(sumS / 60).round()}', t('دقيقة', 'Minutes'), textC, muted),
              _mini('${sumK.round()}', t('سعرة', 'kcal'), textC, muted),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 64,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in days) ...[
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        height: 4 + 38 * ((s.byDay[_dayKey(d)]?['s'] ?? 0) / maxS),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: s.byDay[_dayKey(d)] == null
                              ? textC.withOpacity(0.10)
                              : accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(isAr ? arD[d.weekday - 1] : enD[d.weekday - 1],
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
                    ]),
                  ),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
          ]),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _mini(String v, String l, Color textC, Color muted) => Expanded(
        child: Column(children: [
          Text(v, style: TextStyle(fontFamily: 'Aligarh', fontSize: 20,
              fontWeight: FontWeight.w900, color: textC)),
          Text(l, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5, color: muted)),
        ]),
      );
}

void showWorkoutHistory(BuildContext context, List<Map<String, dynamic>> sessions,
    bool isAr, bool isDark, Color textC, Color muted, Color accent, Color card) {
  String t(String ar, String en) => isAr ? ar : en;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      height: MediaQuery.of(ctx).size.height * 0.7,
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: muted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Icon(Icons.history_rounded, color: accent),
            const SizedBox(width: 10),
            Text(t('سجل التمارين', 'Workout history'),
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 17,
                    fontWeight: FontWeight.w900, color: textC)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: sessions.length,
            itemBuilder: (_, i) {
              final r = sessions[i];
              final id = '${r['workout_id']}';
              final w = kWorkouts.where((x) => x.id == id).toList();
              final title = w.isEmpty ? id : (isAr ? w.first.titleAr : w.first.titleEn);
              final dt = DateTime.tryParse('${r['created']}') ?? DateTime.now();
              final mins = (((r['seconds'] as num?) ?? 0) / 60).round();
              final done = (r['steps_done'] as num?)?.toInt() ?? 0;
              final total = (r['steps_total'] as num?)?.toInt() ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: textC.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.14)),
                    child: Icon(Icons.fitness_center_rounded, size: 18, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,
                              fontWeight: FontWeight.w800, color: textC)),
                      Text('${dt.day}/${dt.month}  ${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}'
                          '  ·  $done/$total',
                          style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5, color: muted)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('$mins ${t("د", "min")}',
                        style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                            fontWeight: FontWeight.w900, color: textC)),
                    Text('${((r['kcal'] as num?) ?? 0).round()} kcal',
                        style: const TextStyle(fontFamily: 'Aligarh', fontSize: 10.5,
                            color: AppColors.haramRed)),
                  ]),
                ]),
              );
            },
          ),
        ),
      ]),
    ),
  );
}
''')

# ── models: ScanResult.details ───────────────────────────────────────
MD = 'lib/data/models/models.dart'
edit(MD, sub_once("  final double? proteinG, carbsG, fatG;\n  ScanResult({",
    "  final double? proteinG, carbsG, fatG;\n  /// v57: ingredient flags, Nutri-Score, portion size, etc. (JSON-safe)\n  final Map<String, dynamic>? details;\n  ScanResult({"),
    'ScanResult.details field')
edit(MD, sub_once("    this.kcal, this.proteinG, this.carbsG, this.fatG,\n  }) : scannedAt",
    "    this.kcal, this.proteinG, this.carbsG, this.fatG, this.details,\n  }) : scannedAt"),
    'ScanResult.details ctor')

# ── Open Food Facts service ──────────────────────────────────────────
OFF = 'lib/core/open_food_facts_service.dart'
OFF_EXTRA = r'''  // ── v55: rich barcode lookup ─────────────────────────────────
  // Same endpoint as above plus the fields the smart scanner needs.
  // [failed] = network/server problem (caller may use the offline cache);
  // data == null && !failed = the product really isn't in the database.
  static Future<({Map<String, dynamic>? data, bool failed})> lookupBarcodeFull(
      String barcode) async {
    if (barcode.trim().isEmpty) return (data: null, failed: false);
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/${barcode.trim()}.json'
        '?fields=product_name,product_name_ar,brands,nutriments,ingredients_text,'
        'image_front_small_url,image_url,serving_size,serving_quantity,quantity,'
        'nutriscore_grade,nova_group,allergens_tags,labels_tags,'
        'ingredients_analysis_tags,categories_tags,additives_tags',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 404) return (data: null, failed: false);
      if (resp.statusCode != 200) return (data: null, failed: true);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['status'] != 1) return (data: null, failed: false);

      final p = body['product'] as Map<String, dynamic>;
      final n = (p['nutriments'] ?? {}) as Map<String, dynamic>;
      final nameEn = _str(p['product_name']);
      final nameAr = _str(p['product_name_ar']);
      List<String> tags(dynamic v) => v is List
          ? [for (final e in v) '$e'.replaceFirst(RegExp(r'^[a-z]{2}:'), '')]
          : <String>[];

      double? servingG = _num(p, 'serving_quantity')?.toDouble();
      if (servingG == null) {
        final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b')
            .firstMatch(_str(p['serving_size']).toLowerCase());
        if (m != null) {
          servingG = double.tryParse(m.group(1)!.replaceAll(',', '.'));
        }
      }
      final nova = _num(p, 'nova_group')?.toInt();
      final grade = _str(p['nutriscore_grade']).toLowerCase();

      return (
        failed: false,
        data: {
          'name': nameAr.isNotEmpty ? nameAr : nameEn,
          'brand': _str(p['brands']),
          'kcal': (_num(n, 'energy-kcal_100g') ??
                  ((_num(n, 'energy_100g') ?? 0) / 4.184))
              .round(),
          'protein_g': (_num(n, 'proteins_100g') ?? 0).toDouble(),
          'carbs_g': (_num(n, 'carbohydrates_100g') ?? 0).toDouble(),
          'fat_g': (_num(n, 'fat_100g') ?? 0).toDouble(),
          'sugar_g': _num(n, 'sugars_100g')?.toDouble(),
          'salt_g': _num(n, 'salt_100g')?.toDouble(),
          'satfat_g': _num(n, 'saturated-fat_100g')?.toDouble(),
          'fiber_g': _num(n, 'fiber_100g')?.toDouble(),
          'ingredients': _str(p['ingredients_text']),
          'image_url': _str(p['image_front_small_url'])
              .ifEmpty(() => _str(p['image_url'])),
          'serving_g': servingG,
          'quantity': _str(p['quantity']),
          'nutri': ['a', 'b', 'c', 'd', 'e'].contains(grade) ? grade : '',
          'nova': (nova != null && nova >= 1 && nova <= 4) ? nova : null,
          'allergens': tags(p['allergens_tags']),
          'labels': tags(p['labels_tags']),
          'analysis': tags(p['ingredients_analysis_tags']),
          'categories': p['categories_tags'] is List
              ? [for (final e in p['categories_tags'] as List) '$e']
              : <String>[],
        },
      );
    } catch (_) {
      return (data: null, failed: true);
    }
  }

  // ── v55: better products from the same category ──────────────
  // Nutri-Score A/B products in [categoryTag] whose ingredient list passes
  // the halal check. Returns at most [limit] entries.
  static Future<List<Map<String, dynamic>>> alternatives({
    required String categoryTag,
    String? excludeCode,
    int limit = 4,
  }) async {
    if (categoryTag.isEmpty) return const [];
    Future<List<Map<String, dynamic>>> one(String grade) async {
      try {
        final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/search'
          '?categories_tags=${Uri.encodeComponent(categoryTag)}'
          '&nutrition_grades_tags=$grade&sort_by=unique_scans_n&page_size=20'
          '&fields=code,product_name,brands,nutriscore_grade,ingredients_text,'
          'ingredients_analysis_tags,labels_tags,nutriments',
        );
        final resp = await http
            .get(uri, headers: {'User-Agent': _ua})
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) return const [];
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = body['products'] as List<dynamic>? ?? const [];
        final out = <Map<String, dynamic>>[];
        for (final raw in list) {
          if (raw is! Map<String, dynamic>) continue;
          final code = _str(raw['code']);
          final name = _str(raw['product_name']);
          if (code.isEmpty || name.isEmpty || code == excludeCode) continue;
          final ing = _str(raw['ingredients_text']);
          if (ing.isEmpty) continue; // can't verify → don't recommend
          final analysis = raw['ingredients_analysis_tags'];
          final vegan = analysis is List && analysis.contains('en:vegan');
          final labels = raw['labels_tags'];
          final cert = labels is List &&
              labels.any((e) => '$e'.toLowerCase().contains('halal'));
          final rep = HalalEngine.analyze(ing, vegan: vegan, certified: cert);
          if (rep.status != HalalStatus.halal) continue;
          final nut = (raw['nutriments'] ?? {}) as Map<String, dynamic>;
          out.add({
            'code': code,
            'name': name,
            'brand': _str(raw['brands']),
            'grade': grade,
            'kcal': (_num(nut, 'energy-kcal_100g') ?? 0).round(),
          });
        }
        return out;
      } catch (_) {
        return const [];
      }
    }

    final res = await Future.wait([one('a'), one('b')]);
    return [...res[0], ...res[1]].take(limit).toList();
  }

'''
edit(OFF, sub_once("import 'package:http/http.dart' as http;\n",
    "import 'package:http/http.dart' as http;\nimport '../data/models/models.dart';\nimport 'halal_engine.dart';\n"),
    'imports')
edit(OFF, sub_once("  // ── Helpers ─────────────────────────────────────────────────\n  static String _str",
    OFF_EXTRA + "  // ── Helpers ─────────────────────────────────────────────────\n  static String _str"),
    'rich lookup + alternatives')

# ── AI service: read an ingredient label ─────────────────────────────
AI = 'lib/core/ai_service.dart'
edit(AI, sub_once("    int maxTokens = 1024,\n  }) async {\n    if (_apiKey.isEmpty) throw const ApiKeyMissingException();\n    final b64",
    "    int maxTokens = 1024,\n    bool rawText = false,\n  }) async {\n    if (_apiKey.isEmpty) throw const ApiKeyMissingException();\n    final b64"),
    '_callVision rawText param')
edit(AI, sub_once("    final raw  = _extractGroq(data);\n    final arrMatch",
    "    final raw  = _extractGroq(data);\n    if (rawText) return raw;\n    final arrMatch"),
    '_callVision rawText return')
READ_LABEL = r'''  // ════════════════════════════════════════════════
  //  INGREDIENT LABEL READER (v57)
  // ════════════════════════════════════════════════
  static Future<String> readIngredientLabel({
    required String imagePath,
    required String language,
  }) async {
    const system = 'You read food packaging. Return ONLY JSON like '
        '{"ingredients":"<the complete ingredient list exactly as printed, '
        'comma separated, original language; empty string if no ingredient '
        'list is visible>"}';
    final raw = await _callVision(
      imagePath: imagePath,
      systemPrompt: system,
      userPrompt: 'Read the ingredient list on this package.',
      maxTokens: 800,
      rawText: true,
    );
    final obj = RegExp(r'\{[\s\S]*\}').firstMatch(raw)?.group(0) ?? '';
    try {
      final j = jsonDecode(obj);
      if (j is Map) return ('${j['ingredients'] ?? ''}').trim();
    } catch (_) {}
    final m = RegExp(r'"ingredients"\s*:\s*"([^"]*)"').firstMatch(raw);
    return (m?.group(1) ?? '').trim();
  }

'''
edit(AI, sub_once("  // ════════════════════════════════════════════════\n  //  FOOD PHOTO ANALYSIS",
    READ_LABEL + "  // ════════════════════════════════════════════════\n  //  FOOD PHOTO ANALYSIS"),
    'readIngredientLabel')

# ── database: v9 ─────────────────────────────────────────────────────
DB = 'lib/core/database.dart'
edit(DB, sub_once("      version: 8,", "      version: 9,"), 'db version 9')
edit(DB, sub_once("    if (oldV < 7) await _migrateLegacyProgress(db);\n",
    "    if (oldV < 7) await _migrateLegacyProgress(db);\n"
    "    if (oldV < 9) {\n"
    "      // v9: real calories per workout (older rows stay NULL = minutes x 5)\n"
    "      try {\n"
    "        await db.execute('ALTER TABLE workout_log ADD COLUMN kcal REAL');\n"
    "      } catch (_) {}\n"
    "    }\n"),
    'migration v9')
edit(DB, sub_once("      'minutes INTEGER NOT NULL,'\n",
    "      'minutes INTEGER NOT NULL,'\n      'kcal REAL,'\n"), 'workout_log.kcal column')
edit(DB, sub_once("      'ON lift_sets(exercise_id)'\n    );\n",
    "      'ON lift_sets(exercise_id)'\n    );\n"
    "    // ── Workout sessions — one row per finished / saved session ──\n"
    "    await db.execute(\n"
    "      'CREATE TABLE IF NOT EXISTS workout_sessions ('\n"
    "      'id INTEGER PRIMARY KEY AUTOINCREMENT,'\n"
    "      'workout_id TEXT NOT NULL,'\n"
    "      'seconds INTEGER DEFAULT 0,'\n"
    "      'kcal REAL DEFAULT 0,'\n"
    "      'steps_done INTEGER DEFAULT 0,'\n"
    "      'steps_total INTEGER DEFAULT 0,'\n"
    "      'date_key TEXT NOT NULL,'\n"
    "      'created TEXT NOT NULL)'\n"
    "    );\n"),
    'workout_sessions table')
edit(DB, sub_once(
    "  static Future<void> logWorkout(String workoutId, int minutes) async {\n    final d = await db;\n    await d.insert('workout_log', {'workout_id':workoutId,'minutes':minutes,'date_key':_today(),'created':DateTime.now().toIso8601String()});\n  }",
    "  static Future<void> logWorkout(String workoutId, int minutes, {double? kcal}) async {\n    final d = await db;\n    await d.insert('workout_log', {'workout_id':workoutId,'minutes':minutes,'kcal':kcal,'date_key':_today(),'created':DateTime.now().toIso8601String()});\n  }"),
    'logWorkout kcal')
edit(DB, sub_once(
    "    final rows = await d.rawQuery(\n        'SELECT SUM(minutes) as total FROM workout_log WHERE date_key=?',\n        [_today()]);\n    final mins = (rows.first['total'] as int?) ?? 0;\n    return mins * 5.0;",
    "    // v57: real kcal when the session recorded it, else 5 kcal per minute\n    final rows = await d.rawQuery(\n        'SELECT SUM(COALESCE(kcal, minutes * 5.0)) as total FROM workout_log WHERE date_key=?',\n        [_today()]);\n    return (rows.first['total'] as num?)?.toDouble() ?? 0.0;"),
    'burned kcal uses real kcal')
DB_HELPERS = r'''  // ── v57: workout sessions ───────────────────────────────────
  static Future<void> logSession({
    required String workoutId,
    required int seconds,
    required double kcal,
    required int stepsDone,
    required int stepsTotal,
  }) async {
    final d = await db;
    await d.insert('workout_sessions', {
      'workout_id': workoutId, 'seconds': seconds, 'kcal': kcal,
      'steps_done': stepsDone, 'steps_total': stepsTotal,
      'date_key': _today(), 'created': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getSessions({int limit = 40}) async {
    final d = await db;
    return d.query('workout_sessions', orderBy: 'id DESC', limit: limit);
  }

  static Future<Map<String, dynamic>?> getLastSession(String workoutId) async {
    final d = await db;
    final rows = await d.query('workout_sessions',
        where: 'workout_id=?', whereArgs: [workoutId], orderBy: 'id DESC', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<List<Map<String, dynamic>>> getDailyWorkoutStats(int days) async {
    final d = await db;
    return d.rawQuery(
      'SELECT date_key, SUM(seconds) AS s, SUM(kcal) AS k, COUNT(*) AS c '
      'FROM workout_sessions WHERE date_key >= ? GROUP BY date_key',
      [_daysAgoKey(days - 1)]);
  }

'''
edit(DB, sub_once("  // ── Ascent helpers ──────────────────────────────────────────\n",
    DB_HELPERS + "  // ── Ascent helpers ──────────────────────────────────────────\n"),
    'session helpers')

# ── providers ────────────────────────────────────────────────────────
PV = 'lib/core/providers.dart'
edit(PV, sub_once("import 'package:package_info_plus/package_info_plus.dart';\n",
    "import 'package:package_info_plus/package_info_plus.dart';\nimport 'scan_store.dart';\n"),
    'import scan_store')
edit(PV, sub_once(
    "  Future<void> add(String workoutId, int minutes) async { await AppDatabase.logWorkout(workoutId, minutes); state = state + minutes; }",
    "  Future<void> add(String workoutId, int minutes, {double? kcal}) async { await AppDatabase.logWorkout(workoutId, minutes, kcal: kcal); state = state + minutes; }"),
    'WorkoutMinutes.add kcal')
edit(PV, sub_once(
    "  ScanNotifier() : super(ScanState(history: [], todayCount: 0)) { _load(); }\n",
    "  ScanNotifier() : super(ScanState(history: [], todayCount: 0)) { _load(); _loadHistory(); }\n\n"
    "  // v57: history survives app restarts\n"
    "  Future<void> _loadHistory() async {\n"
    "    final h = await ScanStore.loadHistory();\n"
    "    if (h.isNotEmpty && state.history.isEmpty) {\n"
    "      state = ScanState(history: h, todayCount: state.todayCount);\n"
    "    }\n"
    "  }\n"),
    'ScanNotifier loads history')
edit(PV, sub_once(
    "    state = ScanState(history: [r, ...state.history.take(49)], todayCount: newCount);\n",
    "    state = ScanState(history: [r, ...state.history.take(99)], todayCount: newCount);\n    ScanStore.saveHistory(state.history);\n"),
    'ScanNotifier saves history')

# ── scanner screen ───────────────────────────────────────────────────
SC = 'lib/features/scanner/scanner_screen.dart'
edit(SC, sub_once("import '../../core/fx5.dart';\n",
    "import '../../core/fx5.dart';\n"
    "import '../../core/ai_service.dart';\n"
    "import '../../core/halal_engine.dart';\n"
    "import '../../core/scan_store.dart';\n"
    "import '../../core/open_food_facts_service.dart';\n"
    "import 'package:image_picker/image_picker.dart';\n"),
    'imports')
edit(SC, sub_once("  String? _loggedKey; // result already added to the log (v48)\n",
    "  String? _loggedKey; // result already added to the log (v48)\n"
    "  double _grams = 100;                    // portion on the result card (v57)\n"
    "  List<Map<String, dynamic>>? _alts;      // healthier halal-safe picks\n"
    "  bool _altsLoading = false;\n"
    "  bool _labelBusy = false;\n"),
    'v57 state')
SLICE1 = r'''  // ── v55: smart scanner core ───────────────────────────
  String _t(String ar, String en) => tLang(ref.read(languageProvider), ar, en);

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Aligarh')),
      backgroundColor: color ?? AppColors.brandGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  // One entry point for showing a result: resets the portion + alternatives.
  void _showResult(ScanResult r) {
    final d = r.details ?? const <String, dynamic>{};
    final sg = (d['serving_g'] as num?)?.toDouble();
    setState(() {
      _result = r;
      _grams = (sg != null && sg >= 5 && sg <= 500) ? sg.roundToDouble() : 100;
      _alts = null;
      _altsLoading = false;
      _scanning = false;
    });
    _loadAlternatives(r);
  }

  Future<void> _loadAlternatives(ScanResult r) async {
    final d = r.details;
    if (d == null) return;
    final nutri = (d['nutri'] ?? '') as String;
    final worth = nutri == 'c' || nutri == 'd' || nutri == 'e' ||
        r.status == HalalStatus.haram || r.status == HalalStatus.doubtful;
    final cats = [for (final c in (d['categories'] as List? ?? const [])) '$c'];
    if (!worth || cats.isEmpty) return;
    final key = r.barcode;
    if (mounted) setState(() => _altsLoading = true);
    final alts = await OpenFoodFactsService.alternatives(
        categoryTag: cats.last, excludeCode: r.barcode);
    if (!mounted || _result?.barcode != key) return;
    setState(() { _alts = alts; _altsLoading = false; });
  }

  // Open Food Facts sends numbers, numeric strings or null depending on the product.
  static num? _numOf(dynamic v) =>
      v is num ? v : (v is String ? num.tryParse(v) : null);

  Map<String, dynamic> _detailsOf(HalalReport rep, Map<String, dynamic> d,
      {required bool vegan, required bool certified}) {
    final analysis = [for (final a in (d['analysis'] as List? ?? const [])) '$a'];
    return {
      'flags': [for (final f in rep.flags) f.toJson()],
      'ingredients': d['ingredients'] ?? '',
      'image': d['image_url'] ?? '',
      'serving_g': d['serving_g'],
      'quantity': d['quantity'] ?? '',
      'nutri': d['nutri'] ?? '',
      'nova': d['nova'],
      'sugar': d['sugar_g'], 'salt': d['salt_g'],
      'satfat': d['satfat_g'], 'fiber': d['fiber_g'],
      'fat': d['fat_g'],
      'allergens': d['allergens'] ?? const [],
      'categories': d['categories'] ?? const [],
      'vegan': vegan,
      'vegetarian': analysis.contains('vegetarian') || vegan,
      'certified': certified,
    };
  }

  ScanResult _fromOff(String barcode, Map<String, dynamic> d) {
    final ing = (d['ingredients'] ?? '') as String;
    final labels = [for (final l in (d['labels'] as List? ?? const [])) '$l'.toLowerCase()];
    final analysis = [for (final a in (d['analysis'] as List? ?? const [])) '$a'];
    final certified = labels.any((l) => l.contains('halal'));
    final vegan = analysis.contains('vegan');
    final rep = HalalEngine.analyze(ing, vegan: vegan ? true : null, certified: certified);
    final kcal = (_numOf(d['kcal']) ?? 0).round();
    final prot = (_numOf(d['protein_g']) ?? 0).toDouble();
    final carbs = (_numOf(d['carbs_g']) ?? 0).toDouble();
    final fat = (_numOf(d['fat_g']) ?? 0).toDouble();
    final name = (d['name'] ?? '') as String;
    return ScanResult(
      barcode: barcode,
      name: name.isEmpty ? _t('منتج مجهول', 'Unknown product') : name,
      brand: (d['brand'] ?? '') as String,
      status: rep.status,
      certs: certified ? [_t('علامة حلال على العبوة', 'Halal label on pack')] : const [],
      kcal: kcal > 0 ? kcal : null,
      proteinG: prot > 0 ? prot : null,
      carbsG: carbs > 0 ? carbs : null,
      fatG: fat > 0 ? fat : null,
      notes: ing.trim().isEmpty
          ? '📡 Open Food Facts · ' + _t('لا توجد بيانات مكونات — راجع الملصق', 'No ingredient data — check the label')
          : '📡 Open Food Facts',
      details: _detailsOf(rep, d, vegan: vegan, certified: certified),
    );
  }

  // ── Unknown product fallback ───────────────────────────
  void _unknownProduct(String barcode, bool isAr) {
    final r = ScanResult(
      barcode: barcode,
      name:   tLang(lang, 'منتج غير معروف', 'Unknown Product', 'Produit inconnu', 'Bilinmeyen Ürün', 'Produk Tidak Diketahui', 'Produk Tidak Diketahui'),
      brand:  tLang(lang, 'غير معروف', 'Unknown', 'Inconnu', 'Bilinmiyor', 'Tidak diketahui', 'Tidak diketahui'),
      status: HalalStatus.unknown,
      notes:  tLang(lang, 'لا توجد بيانات — صوّر الملصق أو جرّب تحليل AI', 'No data — photograph the label or try AI Analysis', 'Pas de données — essayez l\'analyse IA', 'Veri yok — AI Analizini deneyin', 'Tiada data — cuba Analisis AI', 'Tidak ada data — coba Analisis AI'),
      details: const {'flags': [], 'unknown': true},
    );
    ref.read(scanProvider.notifier).addScan(r);
    if (mounted) _showResult(r);
  }

  // The camera reports the same barcode on every frame it stays in view. Each
  // report used to count as a scan: one product burned the 3 free scans and
  // stacked limit dialogs. Ignore repeats until a different code shows up or
  // the person taps "Scan again". (_scan itself enforces the limit.)
  void _onCameraBarcode(String barcode) {
    if (_scanning || barcode == _lastBarcode) return;
    _lastBarcode = barcode;
    HapticFeedback.mediumImpact();
    _scan(barcode);
  }

  // ── Main scan: local DB → Open Food Facts → offline cache ──
  Future<void> _scan(String barcode) async {
    if (_scanning) return;
    barcode = barcode.trim();
    ref.read(scanProvider.notifier).refreshDay(); // app may have stayed open past midnight
    final scan      = ref.read(scanProvider);
    final isPremium = ref.read(premiumProvider);
    final isAr      = ref.read(languageProvider) == 'ar';
    if (!isPremium && scan.todayCount >= 3) { _showLimitDialog(isAr); return; }

    // 1. Local DB lookup (instant)
    final local = kProductsDB.cast<ScanResult?>().firstWhere(
        (p) => p!.barcode == barcode, orElse: () => null);
    if (local != null) {
      ref.read(scanProvider.notifier).addScan(local);
      _showResult(local);
      return;
    }

    // 2. Open Food Facts
    setState(() { _scanning = true; _result = null; });
    final res = await OpenFoodFactsService.lookupBarcodeFull(barcode);
    if (!mounted) return;
    if (res.data != null) {
      final r = _fromOff(barcode, res.data!);
      ScanStore.cachePut(r);
      ref.read(scanProvider.notifier).addScan(r);
      _showResult(r);
      return;
    }

    // 3. No connection → last good copy of this product, if we have one
    if (res.failed) {
      final cached = await ScanStore.cacheGet(barcode);
      if (!mounted) return;
      if (cached != null) {
        final r = ScanResult(
          barcode: cached.barcode, name: cached.name, brand: cached.brand,
          status: cached.status, certs: cached.certs,
          notes: '📴 ' + _t('نسخة محفوظة (بدون إنترنت)', 'Saved copy (offline)'),
          kcal: cached.kcal, proteinG: cached.proteinG,
          carbsG: cached.carbsG, fatG: cached.fatG, details: cached.details,
        );
        ref.read(scanProvider.notifier).addScan(r);
        _showResult(r);
        return;
      }
      setState(() => _scanning = false);
      _lastBarcode = null; // let the camera retry
      _snack(_t('لا يوجد اتصال — حاول مجدداً', 'No connection — try again'),
          color: AppColors.doubtOrange);
      return;
    }
    _unknownProduct(barcode, isAr);
  }

  // ── Photograph an ingredient label → AI reads it → halal engine ──
  Future<void> _readLabel() async {
    if (_labelBusy) return;
    final isPremium = ref.read(premiumProvider);
    if (!isPremium && ref.read(aiPhotoScanProvider) >= 3) {
      if (mounted) context.push('/paywall');
      return;
    }
    try {
      final x = await ImagePicker().pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
      if (x == null || !mounted) return;
      setState(() => _labelBusy = true);
      final txt = await AIService.readIngredientLabel(
          imagePath: x.path, language: ref.read(languageProvider));
      if (!mounted) return;
      if (txt.trim().isEmpty) {
        _snack(_t('لم أجد قائمة مكونات في الصورة', 'No ingredient list found in the photo'),
            color: AppColors.doubtOrange);
        return;
      }
      await ref.read(aiPhotoScanProvider.notifier).increment();
      final rep = HalalEngine.analyze(txt);
      final prev = _result;
      final r = ScanResult(
        barcode: prev != null && !prev.barcode.startsWith('label-')
            ? prev.barcode
            : 'label-${DateTime.now().millisecondsSinceEpoch}',
        name: prev != null && prev.name.isNotEmpty && prev.status != HalalStatus.unknown
            ? prev.name
            : _t('منتج من صورة الملصق', 'Product from label photo'),
        brand: prev?.brand,
        status: rep.status,
        notes: '📝 ' + _t('قرأها الذكاء الاصطناعي من الملصق', 'Read from the label by AI'),
        kcal: prev?.kcal, proteinG: prev?.proteinG,
        carbsG: prev?.carbsG, fatG: prev?.fatG,
        details: {
          ...?prev?.details,
          'flags': [for (final f in rep.flags) f.toJson()],
          'ingredients': txt,
          'fromLabel': true,
        },
      );
      _showResult(r);
    } catch (_) {
      _snack(_t('تعذّرت قراءة الملصق', 'Could not read the label'),
          color: AppColors.haramRed);
    } finally {
      if (mounted) setState(() => _labelBusy = false);
    }
  }

'''
SLICE2 = r'''  // ── Result card ───────────────────────────────────────────
  static const Map<String, Color> _gradeColors = {
    'a': Color(0xFF038141), 'b': Color(0xFF85BB2F), 'c': Color(0xFFFECB02),
    'd': Color(0xFFEE8100), 'e': Color(0xFFE63E11),
  };

  Color _lvl(double v, double lo, double hi) => v <= lo
      ? AppColors.halalGreen
      : (v <= hi ? AppColors.accentGold : AppColors.haramRed);

  Widget _pill(String text, Color c, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: c.withOpacity(0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: c.withOpacity(0.45)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 4)],
      Text(text, style: TextStyle(fontFamily: 'Aligarh', fontSize: 11,
          fontWeight: FontWeight.w700, color: c)),
    ]),
  );

  Widget _sectionTitle(String text, Color muted) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(text, style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
          fontWeight: FontWeight.w800, color: muted, letterSpacing: 0.3)),
    ),
  );

  Widget _flagTile(IngredientFlag f, bool isAr, Color muted) {
    final c = f.level == HalalStatus.haram ? AppColors.haramRed : AppColors.doubtOrange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.16)),
          child: Icon(f.level == HalalStatus.haram
              ? Icons.close_rounded : Icons.priority_high_rounded, size: 14, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.term, style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
              fontWeight: FontWeight.w800, color: c)),
          Text(isAr ? f.whyAr : f.whyEn, style: TextStyle(fontFamily: 'Aligarh',
              fontSize: 11, height: 1.4, color: muted)),
        ])),
      ]),
    );
  }

  Widget _altTile(Map<String, dynamic> a, Color bg, Color muted) {
    final g = ((a['grade'] ?? '') as String).toLowerCase();
    final gc = _gradeColors[g] ?? Colors.grey;
    final brand = (a['brand'] ?? '') as String;
    return PressFx(
      onTap: () => _scan('${a['code']}'),
      scale: 0.97,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.halalGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.halalGreen.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26, alignment: Alignment.center,
            decoration: BoxDecoration(color: gc, shape: BoxShape.circle),
            child: Text(g.toUpperCase(), style: const TextStyle(fontFamily: 'Aligarh',
                fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                    fontWeight: FontWeight.w700)),
            if (brand.isNotEmpty)
              Text(brand, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 18, color: muted),
        ]),
      ),
    );
  }

  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {
    final lang  = ref.read(languageProvider);
    final col   = _statusColor(r.status);
    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);
    String t(String ar, String en) => tLang(lang, ar, en);
    final key    = '${r.barcode}-${r.scannedAt.microsecondsSinceEpoch}';
    final logged = _loggedKey == key;

    final d = r.details ?? const <String, dynamic>{};
    final flags = [
      for (final e in (d['flags'] as List? ?? const []))
        if (e is Map) IngredientFlag.fromJson(Map<String, dynamic>.from(e))
    ];
    final fav = ref.watch(scanFavsProvider).contains(r.barcode);
    final img = (d['image'] ?? '') as String;
    final qty = (d['quantity'] ?? '') as String;
    final ingredients = (d['ingredients'] ?? '') as String;
    final nutri = (d['nutri'] ?? '') as String;
    final nova = (d['nova'] as num?)?.toInt();
    final allergens = [for (final a in (d['allergens'] as List? ?? const [])) '$a'];
    final vegan = d['vegan'] == true;
    final vegetarian = d['vegetarian'] == true;
    final certified = d['certified'] == true || r.certs.isNotEmpty;
    final isLabelOnly = r.barcode.startsWith('label-');
    final needsLabel = ingredients.trim().isEmpty || r.status == HalalStatus.unknown;

    final g = _grams;
    final k = g / 100.0;
    final kcalS = r.kcal == null ? null : (r.kcal! * k).round();
    final protS = r.proteinG == null ? null : r.proteinG! * k;
    final carbS = r.carbsG == null ? null : r.carbsG! * k;
    final fatS  = r.fatG == null ? null : r.fatG! * k;
    final sg = (d['serving_g'] as num?)?.toDouble();

    const novaAr = {1: 'غير مصنّع', 2: 'مكوّن طهي', 3: 'مصنّع', 4: 'فائق التصنيع'};
    const novaEn = {1: 'Unprocessed', 2: 'Culinary', 3: 'Processed', 4: 'Ultra-processed'};

    final traffic = <Widget>[];
    void addT(String name, num? v, double lo, double hi) {
      if (v == null) return;
      traffic.add(_pill('$name ${v.toStringAsFixed(1)}g', _lvl(v.toDouble(), lo, hi)));
    }
    addT(t('دهون', 'Fat'), (d['fat'] as num?), 3, 17.5);
    addT(t('مشبعة', 'Sat. fat'), (d['satfat'] as num?), 1.5, 5);
    addT(t('سكر', 'Sugar'), (d['sugar'] as num?), 5, 22.5);
    addT(t('ملح', 'Salt'), (d['salt'] as num?), 0.3, 1.5);

    return Reveal(
      key: ValueKey(key),
      offset: 0.14,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(bg, col, isDark ? 0.16 : 0.10)!, bg],
          ),
          border: Border.all(color: col.withOpacity(0.5), width: 1.4),
          boxShadow: [BoxShadow(color: col.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Verdict ─────────────────────────────────────
            Row(children: [
              VerdictSeal(kind: _sealKind(r.status), color: col, size: 78),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w900,
                    fontSize: 24, color: col)),
                const SizedBox(height: 2),
                Text(
                  r.status == HalalStatus.halal
                      ? t('لم نجد مكونات محرّمة أو مشبوهة', 'No haram or doubtful ingredients found')
                      : r.status == HalalStatus.haram
                          ? t('يحتوي على مكوّن محرّم', 'Contains a haram ingredient')
                          : r.status == HalalStatus.doubtful
                              ? t('بعض المكوّنات تحتاج تحقّق', 'Some ingredients need checking')
                              : t('لا نملك قائمة المكوّنات', 'No ingredient list available'),
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, height: 1.4, color: muted)),
              ])),
              if (!isLabelOnly)
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ref.read(scanFavsProvider.notifier).toggle(r.barcode);
                  },
                  icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: fav ? AppColors.accentGold : muted, size: 28),
                ),
            ]),
            const Divider(height: 24),

            // ── Product ─────────────────────────────────────
            Row(children: [
              if (img.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(img, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.name, style: const TextStyle(fontFamily:'Aligarh', fontSize: 15,
                    fontWeight: FontWeight.w700)),
                if ((r.brand ?? '').isNotEmpty || qty.isNotEmpty)
                  Text([if ((r.brand ?? '').isNotEmpty) r.brand!, if (qty.isNotEmpty) qty].join(' · '),
                      style: TextStyle(fontFamily:'Aligarh', fontSize: 11, color: muted)),
                if (!isLabelOnly)
                  Text(r.barcode, style: TextStyle(fontFamily:'Aligarh', fontSize: 10, color: muted)),
              ])),
            ]),

            // ── Badges ──────────────────────────────────────
            if (nutri.isNotEmpty || nova != null || vegan || vegetarian || certified || allergens.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (certified)
                  _pill(r.certs.isNotEmpty ? r.certs.first : t('علامة حلال', 'Halal label'),
                      AppColors.halalGreen, icon: Icons.verified_rounded),
                if (nutri.isNotEmpty)
                  _pill('Nutri-Score ${nutri.toUpperCase()}',
                      _gradeColors[nutri] ?? Colors.grey, icon: Icons.favorite_rounded),
                if (nova != null)
                  _pill('NOVA $nova · ${isAr ? novaAr[nova] : novaEn[nova]}',
                      nova >= 4 ? AppColors.haramRed : (nova == 3 ? AppColors.accentGold : AppColors.halalGreen)),
                if (vegan) _pill(t('نباتي', 'Vegan'), AppColors.halalGreen, icon: Icons.eco_rounded)
                else if (vegetarian) _pill(t('نباتي جزئياً', 'Vegetarian'), AppColors.halalGreen, icon: Icons.eco_rounded),
                for (final a in allergens.take(6))
                  _pill(a, AppColors.doubtOrange, icon: Icons.warning_amber_rounded),
              ]),
            ],

            // ── Why this verdict ────────────────────────────
            _sectionTitle(t('سبب الحكم', 'WHY THIS VERDICT'), muted),
            if (flags.isEmpty)
              Row(children: [
                Icon(needsLabel ? Icons.help_outline_rounded : Icons.check_circle_rounded,
                    size: 18, color: needsLabel ? Colors.grey : AppColors.halalGreen),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  needsLabel
                      ? t('لا توجد قائمة مكوّنات — صوّر الملصق ليقرأها الذكاء الاصطناعي',
                          'No ingredient list — photograph the label and AI will read it')
                      : t('فحصنا المكوّنات والإضافات (E) ولم نجد ما يثير الشك',
                          'We checked the ingredients and E-numbers — nothing raised a flag'),
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, height: 1.4, color: muted))),
              ])
            else
              for (final f in flags) _flagTile(f, isAr, muted),
            if (ingredients.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  dense: true,
                  title: Text(t('المكوّنات كما على العبوة', 'Ingredients as printed'),
                      style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
                  children: [Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(ingredients, style: TextStyle(fontFamily: 'Aligarh',
                        fontSize: 11, height: 1.5, color: muted)),
                  )],
                ),
              ),
            if (r.notes != null && r.notes!.isNotEmpty && flags.isEmpty && !needsLabel)
              Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text(r.notes!, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted))),

            // ── Nutrition + portion ─────────────────────────
            if (r.kcal != null) ...[
              _sectionTitle(t('القيمة الغذائية', 'NUTRITION'), muted),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                MacroRing(value: '$kcalS', label: t('سعرة', 'kcal'),
                    pct: kcalS! / 600.0, color: AppColors.haramRed),
                if (protS != null)
                  MacroRing(value: '${protS.toStringAsFixed(1)}g', label: t('بروتين', 'Prot'),
                      pct: protS / 30.0, color: AppColors.halalGreen),
                if (carbS != null)
                  MacroRing(value: '${carbS.toStringAsFixed(1)}g', label: t('كربوهيد', 'Carbs'),
                      pct: carbS / 60.0, color: AppColors.waterBlue),
                if (fatS != null)
                  MacroRing(value: '${fatS.toStringAsFixed(1)}g', label: t('دهون', 'Fat'),
                      pct: fatS / 40.0, color: AppColors.accentGold),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text(t('الكمية', 'Portion'), style: TextStyle(fontFamily: 'Aligarh', fontSize: 12, color: muted)),
                const Spacer(),
                Text('${g.round()} g', style: const TextStyle(fontFamily: 'Aligarh',
                    fontSize: 15, fontWeight: FontWeight.w900)),
              ]),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(trackHeight: 4),
                child: Slider(
                  value: g.clamp(10.0, 500.0).toDouble(),
                  min: 10, max: 500, divisions: 49,
                  activeColor: AppColors.brandGreen,
                  onChanged: (v) => setState(() => _grams = v.roundToDouble()),
                ),
              ),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final q in <double>[
                  if (sg != null && sg >= 5 && sg <= 500) sg.roundToDouble(),
                  50, 100, 200,
                ].toSet())
                  PressFx(
                    onTap: () => setState(() => _grams = q),
                    scale: 0.94,
                    child: _pill(
                        sg != null && q == sg.roundToDouble() && q != 100 && q != 50 && q != 200
                            ? '${t("حصة", "Serving")} ${q.round()}g'
                            : '${q.round()}g',
                        q == g ? AppColors.brandGreen : muted),
                  ),
              ]),
              if (traffic.isNotEmpty) ...[
                _sectionTitle(t('لكل ١٠٠ غ', 'PER 100 G'), muted),
                Wrap(spacing: 6, runSpacing: 6, children: traffic),
              ],
            ],

            // ── Better alternatives ─────────────────────────
            if (_altsLoading) ...[
              _sectionTitle(t('بدائل أفضل', 'BETTER PICKS'), muted),
              Row(children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandGreen)),
                const SizedBox(width: 10),
                Text(t('أبحث عن بدائل حلال وأصحّ…', 'Looking for healthier halal-safe options…'),
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted)),
              ]),
            ] else if (_alts != null && _alts!.isNotEmpty) ...[
              _sectionTitle(t('بدائل أصحّ وحلال', 'HEALTHIER HALAL-SAFE PICKS'), muted),
              for (final a in _alts!) _altTile(a, bg, muted),
            ],

            const SizedBox(height: 12),
            Text(
              t('فحص آلي مساعد وليس فتوى — تحقّق من شعار الحلال على العبوة.',
                  'Automated aid, not a fatwa — verify with the halal logo on the pack.'),
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 9.5, color: muted, height: 1.4)),
            const SizedBox(height: 12),

            // ── Actions ─────────────────────────────────────
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _result = null; _alts = null; _altsLoading = false;
                  _barcodeCtrl.clear(); _lastBarcode = null;
                }),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(t('مسح آخر', 'Scan Again'),
                  style: const TextStyle(fontFamily: 'Aligarh')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandGreen,
                  side: const BorderSide(color: AppColors.brandGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 10),
              if (r.kcal != null)
                Expanded(child: ElevatedButton.icon(
                  onPressed: logged ? null : () {
                    HapticFeedback.mediumImpact();
                    ref.read(caloriesProvider.notifier).addEntry(
                        g.round() == 100 ? r.name : '${r.name} (${g.round()}g)',
                        kcalS!,
                        proteinG: protS ?? 0, carbsG: carbS ?? 0, fatG: fatS ?? 0);
                    setState(() => _loggedKey = key);
                    _snack(tLang(lang, '✅ أُضيف للعداد', '✅ Added to tracker', '✅ Ajouté au suivi', '✅ Takibe eklendi', '✅ Ditambah ke penjejak', '✅ Ditambahkan ke pelacak'));
                  },
                  icon: Icon(logged ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.white, size: 16),
                  label: Text(logged ? t('أُضيف', 'Added') : t('أضف للعداد', 'Add to Log'),
                      style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    disabledBackgroundColor: AppColors.brandGreen.withOpacity(0.55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ))
              else
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => context.push('/food-photo'),
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  label: Text(t('تحليل AI', 'AI Analysis'),
                      style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
            ]),
            if (needsLabel && !isLabelOnly) ...[
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _labelBusy ? null : _readLabel,
                icon: _labelBusy
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.document_scanner_rounded, size: 16),
                label: Text(t('صوّر ملصق المكوّنات (AI)', 'Photograph ingredient label (AI)'),
                    style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentGold,
                  side: BorderSide(color: AppColors.accentGold.withOpacity(0.7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
            ],
          ]),
        ),
      ),
    );
  }

'''
SLICE3 = r'''  void _showHistory(bool isAr, bool isDark) {
    final lang = ref.read(languageProvider);
    String t(String ar, String en) => tLang(lang, ar, en);
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    bool onlyFav = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => SizedBox(
        height: MediaQuery.of(sheetCtx).size.height * 0.72,
        child: Consumer(builder: (cctx, w, _) {
          final all = w.watch(scanProvider).history;
          final favs = w.watch(scanFavsProvider);
          return StatefulBuilder(builder: (c2, setS) {
            final list = onlyFav ? all.where((r) => favs.contains(r.barcode)).toList() : all;
            return Column(children: [
              const SizedBox(height: 8),
              Container(width: 38, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightMuted.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(children: [
                  Expanded(child: Text(tLang(lang, 'سجل الماسحات', 'Scan History', 'Historique des scans', 'Tarama Geçmişi', 'Sejarah Imbasan', 'Riwayat Pemindaian'),
                      style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w700, fontSize: 16))),
                  PressFx(
                    onTap: () => setS(() => onlyFav = false),
                    scale: 0.94,
                    child: _pill(t('الكل', 'All'), !onlyFav ? AppColors.brandGreen : muted)),
                  const SizedBox(width: 6),
                  PressFx(
                    onTap: () => setS(() => onlyFav = true),
                    scale: 0.94,
                    child: _pill(t('المفضلة', 'Favourites'), onlyFav ? AppColors.accentGold : muted,
                        icon: Icons.star_rounded)),
                ]),
              ),
              if (list.isEmpty)
                Expanded(child: Center(child: Text(
                    onlyFav ? t('لا توجد منتجات مفضلة', 'No favourites yet')
                        : tLang(lang, 'لا توجد ماسحات بعد', 'No scans yet', 'Aucun scan encore', 'Henüz tarama yok', 'Belum ada imbasan', 'Belum ada pemindaian'),
                    style: TextStyle(fontFamily:'Aligarh', color: muted))))
              else
                Expanded(child: ListView(children: list.map((r) {
                  final isFav = favs.contains(r.barcode);
                  return ListTile(
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _lastBarcode = r.barcode;
                      _showResult(r);
                    },
                    leading: _statusIcon(r.status, 34),
                    title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(
                        '${r.brand ?? ''}${(r.brand ?? '').isNotEmpty ? ' · ' : ''}${isAr ? _labelAr(r.status) : _labelEn(r.status)}',
                        style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: _statusColor(r.status))),
                    trailing: r.barcode.startsWith('label-') ? null : IconButton(
                      icon: Icon(isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: isFav ? AppColors.accentGold : muted),
                      onPressed: () => ref.read(scanFavsProvider.notifier).toggle(r.barcode),
                    ),
                  );
                }).toList())),
            ]);
          });
        }),
      ),
    );
  }

'''
edit(SC, slice_edit("  // ── Halal ingredient check", "  void _showLimitDialog(bool isAr) {",
    SLICE1, '// ── v57: smart scanner core'), 'smart scan core')
edit(SC, slice_edit("  // ── Result card ───", "  Widget _row(String label, String val)",
    SLICE2, 'static const Map<String, Color> _gradeColors'), 'result card')
edit(SC, slice_edit("  void _showHistory(bool isAr, bool isDark) {", "  Color _statusColor(HalalStatus s) {",
    SLICE3, 'bool onlyFav = false;'), 'history sheet')
FAV_STRIP = r'''        // ── Favourites (v57) ──────────────────────────────
        Builder(builder: (_) {
          final favs = ref.watch(scanFavsProvider);
          final seen = <String>{};
          final items = [
            for (final r in scan.history)
              if (favs.contains(r.barcode) && seen.add(r.barcode)) r
          ];
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.star_rounded, size: 16, color: AppColors.accentGold),
              const SizedBox(width: 6),
              Text(t('المفضلة', 'Favourites'), style: const TextStyle(fontFamily: 'Aligarh',
                  fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final r in items)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: PressFx(
                      onTap: () { _lastBarcode = r.barcode; _showResult(r); },
                      scale: 0.95,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _statusColor(r.status).withOpacity(0.35)),
                        ),
                        child: Row(children: [
                          _statusIcon(r.status, 24),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
          ]);
        }),

'''
edit(SC, sub_once("        // ── Demo products ─────────────────────────────────",
    FAV_STRIP + "        // ── Demo products ─────────────────────────────────"),
    'favourites strip')

# ── fitness screen: new player + stats card ──────────────────────────
FS = 'lib/features/fitness/fitness_screen.dart'
def fit_player(s):
    if "workout_player_pro.dart" in s: return s
    k = s.find("//  WorkoutPlayerScreen — Step-by-step exercise timer")
    if k < 0: return None
    a = line_start_before(s, "//  WorkoutPlayerScreen — Step-by-step exercise timer")
    s = s[:a].rstrip() + "\n"
    imp = "import '../../core/fx7.dart' show EmptyState;\n"
    if imp not in s: return None
    return s.replace(imp, imp + "import 'workout_player_pro.dart';\nexport 'workout_player_pro.dart' show WorkoutPlayerScreen;\n", 1)
edit(FS, fit_player, 'old player removed, new player wired')
edit(FS, sub_once(
    "                      if (ram || isSis)\n                        Reveal(\n                          index: 1,",
    "                      WorkoutStatsCard(\n                        card: card, textC: textC, muted: muted,\n                        accent: accent, isAr: isAr, isDark: isDark),\n                      if (ram || isSis)\n                        Reveal(\n                          index: 1,"),
    'weekly stats card')

def ver(s):
    if 'version: 1.15.0+29' in s: return s
    n = re.sub(r"^version: \d+\.\d+\.\d+\+\d+", 'version: 1.15.0+29', s, count=1, flags=re.M)
    return n if n != s else None
edit('pubspec.yaml', ver, 'version 1.15.0+29')

print('\n== sanity ==')
bad = 0
for p in [HE, SS, WP, OFF, AI, DB, PV, SC, FS, MD]:
    if not os.path.exists(path(p)): continue
    t = open(path(p), encoding='utf-8').read()
    t = re.sub(r"//[^\n]*", '', t)
    t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
    t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
    for a, b in ('{}', '()', '[]'):
        if t.count(a) != t.count(b):
            bad += 1; print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
print('  all balanced' if not bad else '  !! fix the files above before building')
print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git add -A && git commit -m "v57: workout + smart scanner" && git push')
