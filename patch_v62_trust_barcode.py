#!/usr/bin/env python3
"""
patch_v62_trust_barcode.py
==========================
HalalCalorie v62 - a smarter, honest barcode scanner + no invented health data.
Run from the repo root (after v61):

    python3 patch_v62_trust_barcode.py

BARCODE
  * halal_engine.dart: a pack with nothing flagged is only called "halal" when
    the ingredient text could actually be read. Rules now cover French, Spanish,
    German, Turkish, Malay/Indonesian and Arabic (before: English only, so
    "saindoux", "domuz yagi", "lemak babi" all came back HALAL), and an
    unreadable list (Russian, Thai, Italian...) is "unknown", never "halal".
  * Open Food Facts lookup also fetches ingredients_text_en, ingredients_lc and
    ingredients_tags (language-neutral) and feeds them to the engine.
  * New barcode_util.dart: GTIN check-digit validation. Camera misreads are
    dropped silently, mistyped manual codes get a hint instead of a lookup.
  * Camera only reads product codes (EAN-13, EAN-8, UPC-A), no stray QR codes.
  * Free limit unchanged: 3 barcode scans a day (an invalid or misread code is
    never counted, because it is rejected before the scan is logged).
  * Result note says when the verdict is "ingredients only, not a certificate"
    or when the list could not be checked.

HEALTH (no invented numbers)
  * Heart rate: no default 72, no random "Measure" button. Shows "--" until the
    person enters a reading (watch / cuff); the reading is kept for the day.
  * Sleep: no assumed 7 h. Unlogged = "--" / "Not logged", and it no longer
    feeds the Ascent rest quest or health score.
  * Body photo: if the AI call fails or returns incomplete data the screen shows
    its error state. The made-up 18% / 28% fallback is gone.
  * health_service.dart: dead 72 bpm / 7 h defaults zeroed.

Also: adds test/halal_engine_test.dart and test/barcode_util_test.dart, and
bumps the version to 1.17.3+34.
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

def rep(old, new, marker):
    """Replace the first `old` with `new`; no-op when `marker` is already present."""
    def f(s):
        if marker in s: return s
        return s.replace(old, new, 1) if old in s else None
    return f

def rx(pattern, repl, marker, flags=re.S):
    def f(s):
        if marker in s: return s
        n, c = re.subn(pattern, repl, s, count=1, flags=flags)
        return n if c else None
    return f

def chain(*fns):
    def f(s):
        for fn in fns:
            r = fn(s)
            if r is None: return None
            s = r
        return s
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

print('== v62 ==')

# ───────────────────────── barcode: engine + validator + tests ─────────────────────────
write('lib/core/halal_engine.dart', r"""// halal_engine.dart — ingredient-level halal analysis (v55)
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
  /// PATCH_V62: false when the ingredient text could not be checked properly
  /// (a language or script the rules do not cover and no language-neutral
  /// tags to fall back on). An unreliable report never says "halal".
  final bool reliable;
  const HalalReport(this.status, this.flags,
      {this.certified = false, this.reliable = true});
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

    // ── PATCH_V62: the same checks for French, Spanish, German, Turkish,
    //    Malay/Indonesian and Arabic labels. Open Food Facts returns the
    //    ingredient text in the product's own language, so English-only
    //    rules let "saindoux" or "domuz yağı" through as halal.
    _Rule(r'\b(?:porcs?|cochons?|jambons?|lardons?|saindoux|couenne|cerdo|puerco|panceta|tocino|porco|presunto|maiale|domuz|babi)(?![a-z])|\bschwein|\bschinken|jam[oó]n|خنزير',
        HalalStatus.haram, 'يحتوي على لحم الخنزير أو أحد مشتقاته',
        'Contains pork or a pork product'),
    _Rule(r'\b(?:vins?|vino|vinho|wein|bi[eè]re|bier|cerveza|cerveja|birra|bira|rhum|şarap|sarap|anggur|arak|likör|licor)(?![a-z])|نبيذ|خمر|بيرة|ويسكي|فودكا',
        HalalStatus.haram, 'يحتوي على كحول أو مشروب كحولي',
        'Contains alcohol or an alcoholic drink'),
    _Rule(r'\b(?:sang|sangre|blut|darah)(?![a-z])',
        HalalStatus.haram, 'الدم محرّم', 'Blood is prohibited'),
    _Rule(r'\b(?:carmin|cochenille|cochinilla|ko[sş]enil)',
        HalalStatus.haram, 'صبغة حمراء مستخرجة من حشرة القرمز (كارمين)',
        'Red dye crushed from cochineal insects (carmine)'),
    _Rule(r'g[eé]latin[ea]?(?![a-z])|\bgelatina|\bjelatin|جيلاتين|جلاتين',
        HalalStatus.doubtful,
        'الجيلاتين غالباً من خنزير أو ذبيحة غير مذكّاة',
        'Gelatin is often pork- or non-halal-slaughter-derived', animal: true),
    _Rule(r'(?<!sans )(?<!sin )\b(?:alcool|alkol|alkohol|etanol)(?![a-z])|كحول',
        HalalStatus.doubtful, 'مصطلح كحولي في قائمة المكونات — راجع الملصق',
        'Alcohol-related term in a non-English label — check it'),
    _Rule(r'\b(?:poulet|poule|b[oœ]uf|agneau|mouton|veau|dinde|canard|viande|volaille|pollo|carne|ternera|cordero|pavo|pato|rindfleisch|h[uü]hnchen|huhn|lamm|fleisch|tavuk|kuzu|ayam|daging|sapi|kambing|bebek)(?![a-z])|لحم|لحوم|دجاج|بقر|ضأن',
        HalalStatus.doubtful,
        'لحوم (قائمة بلغة أخرى) — تأكد من الذبح الحلال',
        'Meat (non-English label) — check it is halal-slaughtered', animal: true),
    _Rule(r'graisse animale|graisse de b[oœ]uf|\bsuif\b|grasa animal|\bsebo\b|tierisches fett|hayvansal ya[gğ]|lemak hewani|شحم',
        HalalStatus.doubtful, 'دهن حيواني — يجب أن يكون من ذبيحة حلال',
        'Animal fat — must come from halal slaughter', animal: true),
    _Rule(r'pr[eé]sure|cuajo|peynir mayas',
        HalalStatus.doubtful, 'إنفحة/إنزيم قد يكون حيواني المصدر',
        'Rennet or enzyme that may be animal-derived', animal: true),
    _Rule(r'vinaigre de vin|vinagre de vino|weinessig',
        HalalStatus.doubtful, 'خل النبيذ — أجازه كثير من العلماء بعد التحوّل',
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

  // Languages the rules above cover. Anything else needs language-neutral
  // tags (en:...) to be judged at all.
  static const Set<String> _supportedLangs = {
    'en', 'fr', 'es', 'de', 'tr', 'id', 'ms', 'ar',
  };
  static final RegExp _otherScript = RegExp(
      r'[\u0400-\u04FF\u0590-\u05FF\u0900-\u097F\u0E00-\u0E7F\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]');
  // Phrases judged on their own, so "vinaigre de vin" is not read as "vin".
  static const List<String> _vinegars = [
    'wine vinegar', 'vinaigre de vin', 'vinagre de vino', 'weinessig',
  ];

  /// Open Food Facts tags ("en:sunflower-oil", "fr:saindoux") as plain words.
  static String _tagWords(List<String> tags) => tags
      .map((t) => t.replaceFirst(RegExp(r'^[a-z]{2,3}:'), '').replaceAll('-', ' ').trim())
      .where((t) => t.isNotEmpty)
      .join(' | ');

  /// [vegan]: true when Open Food Facts says the product is vegan (animal
  /// sources are then ruled out). [certified]: a halal label is on the pack.
  /// [englishText], [lang] and [tags] (PATCH_V62) carry what Open Food Facts
  /// knows beyond the raw text: its English rendering, the text's language
  /// and the canonical ingredient tags. A pack with nothing flagged is only
  /// called halal when the text could actually be checked; otherwise the
  /// report is "unknown" with [HalalReport.reliable] false.
  static HalalReport analyze(String ingredients,
      {bool? vegan,
      bool certified = false,
      String englishText = '',
      String lang = '',
      List<String> tags = const []}) {
    final raw = ingredients.trim();
    final en = englishText.trim();
    final tagWords = _tagWords(tags);
    if (raw.isEmpty && en.isEmpty && tagWords.isEmpty) {
      return HalalReport(
          certified ? HalalStatus.halal : HalalStatus.unknown, const [],
          certified: certified);
    }
    final lower = [raw, en, tagWords]
        .where((s) => s.isNotEmpty)
        .join(' | ')
        .toLowerCase();
    // Wine vinegar is judged on its own, not as wine.
    var forHaram = lower;
    for (final v in _vinegars) {
      forHaram = forHaram.replaceAll(v, ' ');
    }
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

    // Could the text be checked? Known language, an English rendering, enough
    // language-neutral tags - or (no language given) at least not a script the
    // rules know nothing about.
    final lc = lang.trim().toLowerCase();
    final enTags = tags.where((t) => t.startsWith('en:')).length;
    final understood = enTags >= 3 ||
        en.isNotEmpty ||
        (lc.isEmpty
            ? !_otherScript.hasMatch(raw)
            : _supportedLangs.contains(lc));

    HalalStatus status;
    if (flags.any((f) => f.level == HalalStatus.haram)) {
      status = HalalStatus.haram;
    } else if (flags.any((f) => f.level == HalalStatus.doubtful)) {
      status = certified ? HalalStatus.halal : HalalStatus.doubtful;
    } else if (certified) {
      status = HalalStatus.halal;
    } else if (understood) {
      status = HalalStatus.halal; // nothing flagged in a list we can read
    } else {
      status = HalalStatus.unknown; // nothing flagged, but we cannot read it
    }
    return HalalReport(status, flags,
        certified: certified, reliable: understood || certified || flags.isNotEmpty);
  }
}
""")
write('lib/core/barcode_util.dart', r"""// barcode_util.dart — HalalCalorie v62 (PATCH_V62)
// Pure Dart. A camera misread is the usual reason a scan returns the wrong
// product, so a code is only looked up when its GTIN check digit adds up.
class BarcodeUtil {
  BarcodeUtil._();

  /// Digits only, no spaces or separators.
  static String clean(String raw) => raw.replaceAll(RegExp(r'\s+'), '');

  /// True for a well-formed GTIN-8 / GTIN-12 (UPC-A) / GTIN-13 (EAN-13) /
  /// GTIN-14 whose check digit is correct.
  static bool isValid(String raw) {
    final s = clean(raw);
    if (!RegExp(r'^\d+$').hasMatch(s)) return false;
    if (s.length != 8 && s.length != 12 && s.length != 13 && s.length != 14) {
      return false;
    }
    var sum = 0;
    // Weights 3,1,3,1... starting from the digit next to the check digit.
    for (var i = 0; i < s.length - 1; i++) {
      final digit = s.codeUnitAt(s.length - 2 - i) - 48;
      sum += digit * (i.isEven ? 3 : 1);
    }
    final check = (10 - sum % 10) % 10;
    return check == s.codeUnitAt(s.length - 1) - 48;
  }
}
""")
write('test/halal_engine_test.dart', r"""// halal_engine_test.dart - PATCH_V62
// Fixtures for the ingredient engine: English, other languages (the false-halal
// bug), unreadable lists and Open Food Facts tags.
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/halal_engine.dart';
import 'package:halalcalorie/data/models/models.dart';

void main() {
  group('HalalEngine: English', () {
    test('plain list with nothing flagged is halal and reliable', () {
      final r = HalalEngine.analyze('Sugar, wheat flour, palm oil, salt', lang: 'en');
      expect(r.status, HalalStatus.halal);
      expect(r.reliable, isTrue);
    });
    test('pork is haram', () {
      expect(HalalEngine.analyze('Water, pork gelatin, sugar').status, HalalStatus.haram);
    });
    test('gelatin alone is doubtful, halal label rescues it', () {
      expect(HalalEngine.analyze('Sugar, gelatin').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Sugar, gelatin', certified: true).status, HalalStatus.halal);
    });
    test('sugar alcohol and wine vinegar are not haram', () {
      expect(HalalEngine.analyze('sugar alcohol, xylitol').status, isNot(HalalStatus.haram));
      expect(HalalEngine.analyze('wine vinegar, olive oil').status, HalalStatus.doubtful);
    });
    test('empty list is unknown unless certified', () {
      expect(HalalEngine.analyze('').status, HalalStatus.unknown);
      expect(HalalEngine.analyze('', certified: true).status, HalalStatus.halal);
    });
  });

  group('HalalEngine: other languages (the false-halal bug)', () {
    test('French lard and pork', () {
      expect(HalalEngine.analyze('Farine, sucre, saindoux, sel', lang: 'fr').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Jambon cuit, eau', lang: 'fr').status, HalalStatus.haram);
    });
    test('French alcohol is doubtful, "sans alcool" is not flagged', () {
      expect(HalalEngine.analyze('Eau, sucre, alcool', lang: 'fr').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Boisson sans alcool, eau, sucre', lang: 'fr').status, HalalStatus.halal);
    });
    test('French wine vinegar is doubtful, not haram', () {
      expect(HalalEngine.analyze('Vinaigre de vin, huile', lang: 'fr').status, HalalStatus.doubtful);
    });
    test('French gelatin and meat', () {
      expect(HalalEngine.analyze('Sucre, gélatine', lang: 'fr').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Poulet, eau, sel', lang: 'fr').status, HalalStatus.doubtful);
    });
    test('Spanish, German, Turkish, Indonesian pork', () {
      expect(HalalEngine.analyze('Pan, jamón serrano, sal', lang: 'es').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Wasser, Schweinefleisch', lang: 'de').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Şeker, buğday unu, domuz yağı', lang: 'tr').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Gula, tepung, lemak babi', lang: 'id').status, HalalStatus.haram);
    });
    test('wine and beer words', () {
      expect(HalalEngine.analyze('Salsa, vino tinto', lang: 'es').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Wasser, Bier, Malz', lang: 'de').status, HalalStatus.haram);
    });
    test('Arabic labels', () {
      expect(HalalEngine.analyze('سكر، دقيق، جيلاتين', lang: 'ar').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('ماء، لحم الخنزير', lang: 'ar').status, HalalStatus.haram);
      expect(HalalEngine.analyze('سكر، دقيق، ملح', lang: 'ar').status, HalalStatus.halal);
    });
    test('porcini mushrooms are not pork', () {
      expect(HalalEngine.analyze('Porcini mushrooms, olive oil', lang: 'en').status, HalalStatus.halal);
    });
    test('clean French list is halal and reliable', () {
      final r = HalalEngine.analyze('Sucre, farine de blé, huile de palme, sel', lang: 'fr');
      expect(r.status, HalalStatus.halal);
      expect(r.reliable, isTrue);
    });
  });

  group('HalalEngine: unreadable lists never say halal', () {
    test('Russian text without tags is unknown and unreliable', () {
      final r = HalalEngine.analyze('сахар, мука, соль', lang: 'ru');
      expect(r.status, HalalStatus.unknown);
      expect(r.reliable, isFalse);
    });
    test('Italian is not covered, so unknown', () {
      expect(HalalEngine.analyze('zucchero, farina, sale', lang: 'it').status, HalalStatus.unknown);
    });
    test('Cyrillic with no language given is unknown', () {
      expect(HalalEngine.analyze('сахар, мука').status, HalalStatus.unknown);
    });
    test('enough en: tags make an unreadable list judgeable', () {
      final r = HalalEngine.analyze('сахар, мука, соль', lang: 'ru',
          tags: ['en:sugar', 'en:wheat-flour', 'en:salt']);
      expect(r.status, HalalStatus.halal);
      expect(r.reliable, isTrue);
    });
    test('a flag in an unreadable list still counts', () {
      final r = HalalEngine.analyze('сахар, свинина', lang: 'ru', tags: ['en:pork']);
      expect(r.status, HalalStatus.haram);
    });
    test('certified halal label wins over unreadable text', () {
      expect(HalalEngine.analyze('zucchero', lang: 'it', certified: true).status, HalalStatus.halal);
    });
  });

  group('HalalEngine: tags and English rendering', () {
    test('tags alone can be judged', () {
      expect(HalalEngine.analyze('', tags: ['en:pork', 'en:salt']).status, HalalStatus.haram);
    });
    test('English rendering is used when the original is in another language', () {
      final r = HalalEngine.analyze('сахар, свинина', lang: 'ru', englishText: 'sugar, pork');
      expect(r.status, HalalStatus.haram);
    });
    test('E-numbers still work in any language', () {
      expect(HalalEngine.analyze('Sucre, E120', lang: 'fr').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Sucre, E441', lang: 'fr').status, HalalStatus.doubtful);
    });
  });
}
""")
write('test/barcode_util_test.dart', r"""// barcode_util_test.dart - PATCH_V62
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/barcode_util.dart';

void main() {
  group('BarcodeUtil', () {
    test('accepts real EAN-13, UPC-A and EAN-8 codes', () {
      expect(BarcodeUtil.isValid('5449000000996'), isTrue);
      expect(BarcodeUtil.isValid('737628064502'), isTrue);
      expect(BarcodeUtil.isValid('96385074'), isTrue);
      expect(BarcodeUtil.isValid('6221000000041'), isTrue);
    });
    test('rejects a wrong check digit (a misread)', () {
      expect(BarcodeUtil.isValid('5449000000995'), isFalse);
      expect(BarcodeUtil.isValid('737628064503'), isFalse);
      expect(BarcodeUtil.isValid('96385075'), isFalse);
    });
    test('rejects wrong lengths and non-digits', () {
      expect(BarcodeUtil.isValid(''), isFalse);
      expect(BarcodeUtil.isValid('12345'), isFalse);
      expect(BarcodeUtil.isValid('54490000009961'), isFalse);
      expect(BarcodeUtil.isValid('abc4900000996'), isFalse);
      expect(BarcodeUtil.isValid('https://example.com'), isFalse);
    });
    test('ignores surrounding whitespace', () {
      expect(BarcodeUtil.isValid(' 5449000000996 '), isTrue);
      expect(BarcodeUtil.clean(' 5449 000000996\n'), '5449000000996');
    });
  });
}
""")

# ───────────────────────── health: no invented numbers ─────────────────────────
HS_OLD = ("class HealthState { final int steps, stepsGoal, heartRate; final String? mood; final double? quickBmi; "
          "HealthState({this.steps = 0, this.stepsGoal = 10000, this.heartRate = 72, this.mood, this.quickBmi}); }")
HS_NEW = ("class HealthState { final int steps, stepsGoal; final int? heartRate; /* null = nothing entered (PATCH_V62) */ "
          "final String? mood; final double? quickBmi; "
          "HealthState({this.steps = 0, this.stepsGoal = 10000, this.heartRate, this.mood, this.quickBmi}); }")

INIT_OLD = ("  Future<void> _init() async {\n"
            "    final row = await AppDatabase.getTodaySummary(); if (row == null) return;\n"
            "    state = HealthState(steps: (row['steps'] as int?) ?? 0, stepsGoal: state.stepsGoal, heartRate: state.heartRate, mood: row['mood'] as String?);\n"
            "  }")
INIT_NEW = ("  static String _hrDay() { final n = DateTime.now(); return '${n.year}-${n.month}-${n.day}'; }\n"
            "  Future<void> _init() async {\n"
            "    int? hr; // PATCH_V62: only a reading entered today counts - never a default\n"
            "    try {\n"
            "      final sp = await SharedPreferences.getInstance();\n"
            "      if (sp.getString('hr_date') == _hrDay()) hr = sp.getInt('hr_value');\n"
            "    } catch (_) {}\n"
            "    final row = await AppDatabase.getTodaySummary();\n"
            "    state = HealthState(steps: (row?['steps'] as int?) ?? 0, stepsGoal: state.stepsGoal, heartRate: hr, mood: row?['mood'] as String?, quickBmi: state.quickBmi);\n"
            "  }")
SETHR_OLD = "  void setHeartRate(int hr) => state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal, heartRate: hr.clamp(30, 250), mood: state.mood, quickBmi: state.quickBmi);"
SETHR_NEW = ("  Future<void> setHeartRate(int hr) async {\n"
             "    final v = hr.clamp(30, 250).toInt();\n"
             "    state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal, heartRate: v, mood: state.mood, quickBmi: state.quickBmi);\n"
             "    try { final sp = await SharedPreferences.getInstance(); await sp.setString('hr_date', _hrDay()); await sp.setInt('hr_value', v); } catch (_) {}\n"
             "  }\n"
             "  Future<void> clearHeartRate() async {\n"
             "    state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal, heartRate: null, mood: state.mood, quickBmi: state.quickBmi);\n"
             "    try { final sp = await SharedPreferences.getInstance(); await sp.remove('hr_value'); await sp.remove('hr_date'); } catch (_) {}\n"
             "  }")

edit('lib/core/providers.dart', chain(
    rep(HS_OLD, HS_NEW, 'heartRate; /* null = nothing entered'),
    rep(INIT_OLD, INIT_NEW, 'PATCH_V62: only a reading entered today'),
    rep(SETHR_OLD, SETHR_NEW, 'Future<void> clearHeartRate'),
    rep("super(SleepState(hours: 7, goal: 8))", "super(SleepState(hours: 0, goal: 8))", 'SleepState(hours: 0, goal: 8)'),
    rep("    final hrs = logged > 0 ? logged : 7.0;", "    final hrs = logged; // PATCH_V62: 0 = not logged (no assumed 7 h)", 'no assumed 7 h'),
    rep("String qualityAr() { if (hours >= 8) return ",
        "bool get logged => hours > 0; String qualityAr() { if (hours <= 0) return 'غير مسجّل'; if (hours >= 8) return ", 'bool get logged => hours > 0'),
    rep("String qualityEn() { if (hours >= 8) return ",
        "String qualityEn() { if (hours <= 0) return 'Not logged'; if (hours >= 8) return ", "return 'Not logged'"),
), 'heart rate = null until entered; sleep not assumed')

HR_NEW = r"""  Widget _hrCard(HealthState health, bool isAr, bool isDark) {
    // PATCH_V62: no default value and no random "measure" - the number is
    // whatever the person typed in from their watch, cuff or a pulse count.
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final int? hr = health.heartRate;
    final hrCol = hr == null
        ? muted
        : (hr > 100
            ? AppColors.haramRed
            : (hr < 60 ? AppColors.waterBlue : AppColors.halalGreen));
    final hrLbl = hr == null
        ? (isAr ? 'لا توجد قراءة' : 'No reading yet')
        : (isAr
            ? (hr > 100 ? 'مرتفع' : (hr < 60 ? 'منخفض' : 'طبيعي'))
            : (hr > 100 ? 'High' : (hr < 60 ? 'Low' : 'Normal')));
    final double hrPct =
        hr == null ? 0.0 : ((hr - 40) / 120).clamp(0.0, 1.0).toDouble();
    const bigStyle = TextStyle(
        fontFamily: 'Aligarh', fontSize: 42, fontWeight: FontWeight.w900, height: 1.0);

    return _card(hrCol, isDark, Column(children: [
      Row(children: [
        VitalGlyph(kind: VitalKind.pulse, pct: hrPct, color: hrCol, size: 88),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (hr == null)
                        Text('--', style: bigStyle.copyWith(color: hrCol))
                      else
                        CountUp(value: hr, style: bigStyle.copyWith(color: hrCol)),
                      const SizedBox(width: 6),
                      Text(
                          tLang(lang, 'نبضة/دقيقة', 'bpm', 'bpm', 'bpm', 'bpm', 'bpm'),
                          style: TextStyle(
                              fontFamily: 'Aligarh', fontSize: 13, color: muted)),
                    ]),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: hrCol.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(hrLbl,
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: hrCol)),
                ),
                const SizedBox(height: 6),
                Text(
                    hr == null
                        ? tLang(lang, 'أدخل قراءة من ساعتك أو جهاز القياس. ليس جهازاً طبياً.',
                            'Enter a reading from your watch or a pulse count. Not a medical device.')
                        : tLang(lang, 'المعدل الطبيعي: 60-100 · أُدخلت يدوياً',
                            'Normal: 60-100 bpm · entered by you'),
                    style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 11, color: muted)),
              ]),
        ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        if (hr != null) ...[
          Expanded(
            child: _pillBtn('−1', Icons.remove_rounded, hrCol,
                () => ref.read(healthProvider.notifier).setHeartRate(hr - 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _pillBtn('+1', Icons.add_rounded, hrCol,
                () => ref.read(healthProvider.notifier).setHeartRate(hr + 1)),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          flex: 2,
          child: _pillBtn(
              isAr ? 'إدخال قراءة' : 'Enter reading',
              Icons.edit_rounded,
              hr == null ? AppColors.haramRed : hrCol,
              () => _enterHeartRate(isAr),
              filled: true),
        ),
      ]),
    ]));
  }

  Future<void> _enterHeartRate(bool isAr) async {
    final cur = ref.read(healthProvider).heartRate;
    final v = await showDialog<int>(
        context: context,
        builder: (_) => _HrEntryDialog(isAr: isAr, initial: cur));
    if (v != null && mounted) {
      await ref.read(healthProvider.notifier).setHeartRate(v);
    }
  }

"""

HR_DIALOG = r"""

// PATCH_V62: manual heart-rate entry (owns and disposes its controller).
class _HrEntryDialog extends StatefulWidget {
  final bool isAr;
  final int? initial;
  const _HrEntryDialog({required this.isAr, this.initial});
  @override
  State<_HrEntryDialog> createState() => _HrEntryDialogState();
}

class _HrEntryDialogState extends State<_HrEntryDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial?.toString() ?? '');
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_c.text.trim());
    if (v == null || v < 30 || v > 250) {
      setState(() => _err = widget.isAr
          ? 'أدخل رقماً بين 30 و 250'
          : 'Enter a number between 30 and 250');
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    const f = TextStyle(fontFamily: 'Aligarh');
    return AlertDialog(
      title: Text(widget.isAr ? 'قراءة النبض' : 'Heart rate reading', style: f),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
            hintText: widget.isAr ? 'نبضة/دقيقة' : 'beats per minute',
            errorText: _err),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isAr ? 'إلغاء' : 'Cancel', style: f)),
        TextButton(
            onPressed: _save,
            child: Text(widget.isAr ? 'حفظ' : 'Save', style: f)),
      ],
    );
  }
}
"""

def _hr(s):
    if '_HrEntryDialog' in s: return s
    a = s.find('  Widget _hrCard(HealthState health, bool isAr, bool isDark) {')
    b = s.find('  Widget _buildCalc(bool isAr, bool isDark) {')
    if a < 0 or b < 0 or b < a: return None
    c = s.rfind('\n  // ', a, b)          # the section comment above _buildCalc
    end = c + 1 if c > a else b
    return s[:a] + HR_NEW + s[end:] + HR_DIALOG

def _sleep_count(s):
    if 'sleep.logged) CountUp' in s: return s
    pat = r"CountUp\(\s*value: sleep\.hours\.toInt\(\),\s*style: const TextStyle\([^)]*\)\s*\),"
    m = re.search(pat, s)
    if not m: return None
    fallback = ("Text('--', style: const TextStyle(fontFamily: 'Aligarh', fontSize: 42, "
                "fontWeight: FontWeight.w900, height: 1.0, color: c)),")
    return s[:m.start()] + 'if (sleep.logged) ' + m.group(0)[:-1] + ' else ' + fallback + s[m.end():]

edit('lib/features/health/health_screen.dart', chain(
    _hr,
    _sleep_count,
    rep("final IconData face = sleep.hours >= 8",
        "final IconData face = !sleep.logged\n        ? Icons.bedtime_outlined\n        : sleep.hours >= 8", '!sleep.logged\n        ? Icons.bedtime_outlined'),
), 'heart rate: manual entry only; sleep: "--" when not logged')

edit('lib/features/profile/profile_screen.dart',
     lambda s: s if "sleep.logged ?" in s else (s.replace("'${sleep.hours.toInt()}h'", "(sleep.logged ? '${sleep.hours.toInt()}h' : '--')") if "'${sleep.hours.toInt()}h'" in s else None),
     'sleep shows -- when not logged')
edit('lib/features/home/home_screen.dart',
     rep("value: '${sleep.hours.toInt()}', total:", "value: sleep.logged ? '${sleep.hours.toInt()}' : '--', total:", 'sleep.logged ?'),
     'sleep tile shows -- when not logged')

edit('lib/core/health_service.dart', chain(
    rep("static double _heartRate  = 72;", "static double _heartRate  = 0; // PATCH_V62: 0 = no reading (was an invented 72)", 'invented 72'),
    rep("static double _sleepHours = 7;", "static double _sleepHours = 0; // PATCH_V62: 0 = not logged (was an assumed 7)", 'assumed 7'),
), 'dead fake defaults zeroed')

def _drop_fallback(s):
    if '_fallbackBodyResult(' not in s: return s
    n, c = re.subn(r"  static BodyPhotoResult _fallbackBodyResult\(.*?\n  }\n", "", s, count=1, flags=re.S)
    return n if c else None

# body photo: never invent numbers
BODY_OLD = ("      return BodyPhotoResult(\n"
            "        bodyFatPercent: (json['estimatedBodyFatPct'] as num?)?.toDouble() ?? 20.0,")
BODY_NEW = ("      final bf     = (json['estimatedBodyFatPct'] as num?)?.toDouble();\n"
            "      final muscle = (json['estimatedMuscleMassKg'] as num?)?.toDouble();\n"
            "      final typeEn = json['bodyType'] as String?;\n"
            "      if (bf == null || muscle == null || typeEn == null || bf < 3 || bf > 60) {\n"
            "        throw const FormatException('incomplete body analysis');\n"
            "      }\n"
            "      return BodyPhotoResult(\n"
            "        bodyFatPercent: bf,")
edit('lib/core/ai_service.dart', chain(
    _drop_fallback,
    rep(BODY_OLD, BODY_NEW, "throw const FormatException('incomplete body analysis')"),
    rep("        muscleMassKg: (json['estimatedMuscleMassKg'] as num?)?.toDouble() ?? weightKg * 0.4,", "        muscleMassKg: muscle,", 'muscleMassKg: muscle,'),
    rep("        leanBodyMassKg: weightKg * (1 - ((json['estimatedBodyFatPct'] as num?)?.toDouble() ?? 20.0) / 100),", "        leanBodyMassKg: weightKg * (1 - bf / 100),", 'weightKg * (1 - bf / 100)'),
    rx(r"bodyType: json\['bodyTypeAr'\] as String\? \?\? '[^']*',", "bodyType: (json['bodyTypeAr'] as String?) ?? typeEn,", '?? typeEn,'),
    rep("        bodyTypeEn: json['bodyType'] as String? ?? 'mesomorph',", "        bodyTypeEn: typeEn,", 'bodyTypeEn: typeEn,'),
    rep("      return _fallbackBodyResult(isMale, weightKg, language);", "      rethrow; // PATCH_V62: never invent body-composition numbers", 'never invent body-composition'),
), 'body photo: error instead of made-up 18%/28%')

# ───────────────────────── barcode: lookup, scanner screen, camera ─────────────────────────
edit('lib/core/open_food_facts_service.dart', chain(
    rep("'ingredients_analysis_tags,categories_tags,additives_tags',",
        "'ingredients_analysis_tags,categories_tags,additives_tags,'\n        'ingredients_text_en,ingredients_lc,ingredients_tags',", 'ingredients_text_en,ingredients_lc,ingredients_tags'),
    rep("          'ingredients': _str(p['ingredients_text']),\n",
        "          'ingredients': _str(p['ingredients_text']),\n"
        "          'ingredients_en': _str(p['ingredients_text_en']),\n"
        "          'ingredients_lc': _str(p['ingredients_lc']),\n"
        "          'ing_tags': p['ingredients_tags'] is List\n"
        "              ? [for (final e in p['ingredients_tags'] as List) '$e']\n"
        "              : <String>[],\n", "'ing_tags':"),
    rep("fields=code,product_name,brands,nutriscore_grade,ingredients_text,'",
        "fields=code,product_name,brands,nutriscore_grade,ingredients_text,'\n          'ingredients_text_en,ingredients_lc,ingredients_tags,'", "ingredients_text_en,ingredients_lc,ingredients_tags,'"),
    rep("          final rep = HalalEngine.analyze(ing, vegan: vegan, certified: cert);",
        "          final rep = HalalEngine.analyze(ing,\n"
        "              vegan: vegan,\n"
        "              certified: cert,\n"
        "              englishText: _str(raw['ingredients_text_en']),\n"
        "              lang: _str(raw['ingredients_lc']),\n"
        "              tags: raw['ingredients_tags'] is List\n"
        "                  ? [for (final e in raw['ingredients_tags'] as List) '$e']\n"
        "                  : const <String>[]);", "englishText: _str(raw['ingredients_text_en'])"),
), 'fetch language + language-neutral ingredient tags')

NOTES_NEW = ("      notes: (ing.trim().isEmpty && (d['ing_tags'] as List? ?? const []).isEmpty)\n"
             "          ? '📡 Open Food Facts · ' + _t('لا توجد بيانات مكونات — راجع الملصق', 'No ingredient data — check the label')\n"
             "          : (!rep.reliable\n"
             "              ? '📡 Open Food Facts · ' + _t('قائمة المكونات بلغة لا نستطيع فحصها بدقة — اقرأ الملصق', 'Ingredients are in a language we cannot check reliably — read the label')\n"
             "              : (certified\n"
             "                  ? '📡 Open Food Facts'\n"
             "                  : '📡 Open Food Facts · ' + _t('الحكم مبني على قائمة المكونات فقط وليس شهادة حلال', 'Based on the ingredient list only, not a halal certificate'))),\n")
edit('lib/features/scanner/scanner_screen.dart', chain(
    rep("import '../../core/halal_engine.dart';\n", "import '../../core/halal_engine.dart';\nimport '../../core/barcode_util.dart'; // PATCH_V62\n", 'barcode_util.dart'),
    rep("    // 2. Open Food Facts\n",
        "    // PATCH_V62: a code whose check digit does not add up is a misread or a typo.\n"
        "    if (!BarcodeUtil.isValid(barcode)) {\n"
        "      _snack(_t('تأكد من الباركود — الأرقام غير صحيحة', 'Check the barcode — the digits do not add up'),\n"
        "          color: AppColors.doubtOrange);\n"
        "      return;\n"
        "    }\n\n"
        "    // 2. Open Food Facts\n", 'BarcodeUtil.isValid(barcode)'),
    rep("    final rep = HalalEngine.analyze(ing, vegan: vegan ? true : null, certified: certified);",
        "    final rep = HalalEngine.analyze(ing,\n"
        "        vegan: vegan ? true : null,\n"
        "        certified: certified,\n"
        "        englishText: (d['ingredients_en'] ?? '') as String,\n"
        "        lang: (d['ingredients_lc'] ?? '') as String,\n"
        "        tags: [for (final e in (d['ing_tags'] as List? ?? const [])) '$e']);", "englishText: (d['ingredients_en']"),
    rx(r"      notes: ing\.trim\(\)\.isEmpty\n[^\n]*\n[^\n]*Open Food Facts',\n", NOTES_NEW.replace('\\', '\\\\'), 'Based on the ingredient list only'),
), 'check digit, language-aware verdict')

edit('lib/features/scanner/barcode_scanner_widget.dart', chain(
    rep("import '../../core/theme.dart';\n", "import '../../core/theme.dart';\nimport '../../core/barcode_util.dart'; // PATCH_V62\n", 'barcode_util.dart'),
    rep("      detectionSpeed: DetectionSpeed.normal,\n      facing: CameraFacing.back,\n",
        "      detectionSpeed: DetectionSpeed.normal,\n      facing: CameraFacing.back,\n"
        "      // PATCH_V62: product codes only - no stray QR codes or Code128 labels.\n"
        "      formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],\n", 'formats: const [BarcodeFormat.ean13'),
    rep("    final barcode = capture.barcodes.firstOrNull;\n    if (barcode?.rawValue != null) widget.onDetected(barcode!.rawValue!);\n",
        "    // PATCH_V62: only a code whose check digit adds up is reported; a misread frame is ignored.\n"
        "    for (final b in capture.barcodes) {\n"
        "      final v = b.rawValue;\n"
        "      if (v != null && BarcodeUtil.isValid(v)) {\n"
        "        widget.onDetected(BarcodeUtil.clean(v));\n"
        "        return;\n"
        "      }\n"
        "    }\n", 'BarcodeUtil.clean(v)'),
), 'camera: product codes only, check digit')

edit('pubspec.yaml', lambda s: re.sub(r'^version:\s*[\d.]+\+\d+', 'version: 1.17.3+34', s, count=1, flags=re.M) if re.search(r'^version:', s, re.M) else None, 'version 1.17.3+34')

balance_check(['lib/core/halal_engine.dart', 'lib/core/barcode_util.dart', 'lib/core/providers.dart',
               'lib/core/ai_service.dart', 'lib/core/open_food_facts_service.dart', 'lib/core/health_service.dart',
               'lib/features/health/health_screen.dart', 'lib/features/profile/profile_screen.dart',
               'lib/features/home/home_screen.dart', 'lib/features/scanner/scanner_screen.dart',
               'lib/features/scanner/barcode_scanner_widget.dart'])
print('done:', ok, 'ok,', skip, 'skipped')
print('Next: flutter test (or push) -> CI runs the new tests; then check on a device:')
print('  1) Health > Heart Rate shows "--" until you enter a value;  2) Sleep shows "--" until logged;')
print('  3) scan a French/Turkish product and a made-up code (should say "check the barcode").')
