// halal_engine.dart — ingredient-level halal analysis (v55)
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
