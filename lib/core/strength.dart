// ════════════════════════════════════════════════════════════════════
//  strength.dart — strength standards, ranks and lift points
//
//  A lift is scored by how much you move relative to your own
//  bodyweight, not by the raw number on the bar. That keeps the ladder
//  fair across body sizes and between men and women.
//
//  The ladder is nine tiers, each split into three divisions, each
//  holding 0-100 LP:
//
//      Copper I-III → Bronze → Silver → Gold → Platinum →
//      Diamond → Master → Elite → Legend
//
//  Pure data and maths — no Flutter widgets, no providers, so this is
//  cheap to import and straightforward to test.
// ════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart' show Color;

// ════════════════════════════════════════════════════════════════════
// TIERS
// ════════════════════════════════════════════════════════════════════

class StrengthTier {
  final int index;
  final String nameEn, nameAr;
  final Color color;

  /// Legend is the apex and has no divisions.
  final bool hasDivisions;

  const StrengthTier(this.index, this.nameEn, this.nameAr, this.color,
      {this.hasDivisions = true});
}

const kStrengthTiers = <StrengthTier>[
  StrengthTier(0, 'Copper',   'نحاس',  Color(0xFFB06A3B)),
  StrengthTier(1, 'Bronze',   'برونز', Color(0xFFCD7F32)),
  StrengthTier(2, 'Silver',   'فضة',   Color(0xFFA8B3C4)),
  StrengthTier(3, 'Gold',     'ذهب',   Color(0xFFE8B84B)),
  StrengthTier(4, 'Platinum', 'بلاتين', Color(0xFF6FE3D4)),
  StrengthTier(5, 'Diamond',  'ماس',   Color(0xFF63C7FF)),
  StrengthTier(6, 'Master',   'أستاذ', Color(0xFFB98CFF)),
  StrengthTier(7, 'Elite',    'نخبة',  Color(0xFFFF7B54)),
  StrengthTier(8, 'Legend',   'أسطورة', Color(0xFFFF4D6D), hasDivisions: false),
];

/// Divisions per tier, and LP per division.
const int kDivisionsPerTier = 3;
const int kLpPerDivision = 100;

/// Number of tiers on the ladder; kept as a literal so the LP total can
/// stay a compile-time constant.
const int kTierCount = 9;

/// Total LP across the whole ladder. Legend sits at the very top and is
/// a single division, so it contributes one division's worth.
const int kMaxLp =
    ((kTierCount - 1) * kDivisionsPerTier + 1) * kLpPerDivision;

/// Roman numerals for divisions, low to high (III is the strongest).
const _divisionNumerals = ['I', 'II', 'III'];

/// A position on the ladder: tier, division within it, and LP into that
/// division. [totalLp] is the flattened 0..[kMaxLp] value used for maths.
class StrengthRank {
  final int totalLp;
  const StrengthRank(this.totalLp);

  int get _clamped => totalLp.clamp(0, kMaxLp);

  int get _divisionsIn => _clamped ~/ kLpPerDivision;

  StrengthTier get tier {
    final t = (_divisionsIn ~/ kDivisionsPerTier)
        .clamp(0, kStrengthTiers.length - 1);
    return kStrengthTiers[t];
  }

  /// 1-based division inside the tier; always 1 for Legend.
  int get division {
    if (!tier.hasDivisions) return 1;
    return (_divisionsIn % kDivisionsPerTier) + 1;
  }

  /// LP banked inside the current division, 0..[kLpPerDivision].
  int get lp {
    if (_clamped >= kMaxLp) return kLpPerDivision;
    return _clamped % kLpPerDivision;
  }

  double get divisionProgress =>
      (lp / kLpPerDivision).clamp(0.0, 1.0);

  /// 0-1 progress across the entire ladder.
  double get ladderProgress => (_clamped / kMaxLp).clamp(0.0, 1.0);

  bool get isMax => _clamped >= kMaxLp;

  Color get color => tier.color;

  String get divisionNumeral =>
      _divisionNumerals[(division - 1).clamp(0, _divisionNumerals.length - 1)];

  String label({bool arabic = false}) {
    final name = arabic ? tier.nameAr : tier.nameEn;
    if (!tier.hasDivisions) return name;
    return '$name $divisionNumeral';
  }

  /// Short form for tight spaces, e.g. "S II" or "LEG".
  String get shortLabel {
    if (!tier.hasDivisions) return 'LEG';
    return '${tier.nameEn[0].toUpperCase()}$divisionNumeral';
  }

  /// LP still needed to reach the next division, or null at the top.
  int? get lpToNextDivision {
    if (isMax) return null;
    return kLpPerDivision - lp;
  }

  StrengthRank operator +(int extraLp) => StrengthRank(totalLp + extraLp);

  @override
  bool operator ==(Object other) =>
      other is StrengthRank && other.totalLp == totalLp;

  @override
  int get hashCode => totalLp.hashCode;
}

// ════════════════════════════════════════════════════════════════════
// EXERCISES
// ════════════════════════════════════════════════════════════════════

/// How a lift is measured, which decides how it is scored.
enum LiftKind {
  /// External load on a bar or machine, scored as load ÷ bodyweight.
  loaded,

  /// Bodyweight reps, scored on reps completed.
  bodyweight,

  /// Bodyweight plus any added load, scored as (bodyweight + added) ÷ bodyweight.
  weightedBodyweight,

  /// Held for time, scored on seconds.
  timed,
}

class LiftExercise {
  final String id;
  final String nameEn, nameAr;
  final String glyph;
  final LiftKind kind;

  /// Muscle group key, used for grouping in the picker.
  final String group;

  /// Ratio (or reps, or seconds) at which each tier begins, for men.
  /// Nine entries, one per tier, ascending.
  final List<double> maleStandards;

  /// Same, for women.
  final List<double> femaleStandards;

  const LiftExercise({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.glyph,
    required this.kind,
    required this.group,
    required this.maleStandards,
    required this.femaleStandards,
  });

  List<double> standardsFor({required bool isMale}) =>
      isMale ? maleStandards : femaleStandards;

  String name({bool arabic = false}) => arabic ? nameAr : nameEn;
}

// Standards are entry points for Copper, Bronze, Silver, Gold, Platinum,
// Diamond, Master, Elite and Legend. For loaded lifts they are multiples
// of bodyweight; for bodyweight lifts they are reps; for timed holds,
// seconds. They follow the widely published strength-standard bands and
// are deliberately reachable at the bottom and demanding at the top.
const kLiftExercises = <LiftExercise>[
  LiftExercise(
    id: 'squat', nameEn: 'Back Squat', nameAr: 'سكوات', glyph: '🦵',
    kind: LiftKind.loaded, group: 'legs',
    maleStandards:   [0.50, 0.75, 1.10, 1.50, 1.90, 2.30, 2.70, 3.10, 3.50],
    femaleStandards: [0.35, 0.55, 0.80, 1.10, 1.40, 1.70, 2.00, 2.30, 2.60],
  ),
  LiftExercise(
    id: 'deadlift', nameEn: 'Deadlift', nameAr: 'رفعة ميتة', glyph: '🏋️',
    kind: LiftKind.loaded, group: 'back',
    maleStandards:   [0.65, 1.00, 1.40, 1.85, 2.30, 2.75, 3.15, 3.55, 4.00],
    femaleStandards: [0.45, 0.70, 1.00, 1.35, 1.70, 2.05, 2.35, 2.65, 3.00],
  ),
  LiftExercise(
    id: 'bench', nameEn: 'Bench Press', nameAr: 'بنش برس', glyph: '💪',
    kind: LiftKind.loaded, group: 'chest',
    maleStandards:   [0.35, 0.55, 0.80, 1.10, 1.40, 1.70, 2.00, 2.25, 2.50],
    femaleStandards: [0.20, 0.32, 0.48, 0.65, 0.85, 1.05, 1.20, 1.35, 1.50],
  ),
  LiftExercise(
    id: 'ohp', nameEn: 'Overhead Press', nameAr: 'ضغط كتف', glyph: '🙆',
    kind: LiftKind.loaded, group: 'shoulders',
    maleStandards:   [0.25, 0.38, 0.55, 0.72, 0.90, 1.08, 1.25, 1.40, 1.55],
    femaleStandards: [0.15, 0.23, 0.33, 0.45, 0.57, 0.68, 0.80, 0.90, 1.00],
  ),
  LiftExercise(
    id: 'row', nameEn: 'Barbell Row', nameAr: 'تجديف بالبار', glyph: '🚣',
    kind: LiftKind.loaded, group: 'back',
    maleStandards:   [0.35, 0.55, 0.78, 1.02, 1.28, 1.52, 1.75, 1.95, 2.15],
    femaleStandards: [0.22, 0.35, 0.50, 0.68, 0.85, 1.02, 1.18, 1.32, 1.45],
  ),
  LiftExercise(
    id: 'hipthrust', nameEn: 'Hip Thrust', nameAr: 'دفع الورك', glyph: '🍑',
    kind: LiftKind.loaded, group: 'legs',
    maleStandards:   [0.60, 0.95, 1.40, 1.90, 2.40, 2.90, 3.35, 3.75, 4.20],
    femaleStandards: [0.45, 0.75, 1.10, 1.55, 2.00, 2.45, 2.85, 3.20, 3.60],
  ),
  LiftExercise(
    id: 'legpress', nameEn: 'Leg Press', nameAr: 'ضغط الأرجل', glyph: '🦿',
    kind: LiftKind.loaded, group: 'legs',
    maleStandards:   [1.00, 1.60, 2.30, 3.10, 3.90, 4.70, 5.40, 6.00, 6.60],
    femaleStandards: [0.70, 1.15, 1.70, 2.30, 2.90, 3.50, 4.05, 4.55, 5.00],
  ),
  LiftExercise(
    id: 'latpulldown', nameEn: 'Lat Pulldown', nameAr: 'سحب أمامي', glyph: '🪢',
    kind: LiftKind.loaded, group: 'back',
    maleStandards:   [0.35, 0.55, 0.78, 1.00, 1.25, 1.48, 1.68, 1.85, 2.05],
    femaleStandards: [0.25, 0.38, 0.55, 0.72, 0.90, 1.08, 1.22, 1.36, 1.50],
  ),
  LiftExercise(
    id: 'curl', nameEn: 'Barbell Curl', nameAr: 'مرجحة بايسبس', glyph: '💪',
    kind: LiftKind.loaded, group: 'arms',
    maleStandards:   [0.18, 0.28, 0.40, 0.53, 0.66, 0.79, 0.90, 1.00, 1.10],
    femaleStandards: [0.10, 0.16, 0.24, 0.32, 0.40, 0.48, 0.55, 0.62, 0.70],
  ),
  LiftExercise(
    id: 'pullup', nameEn: 'Pull-up', nameAr: 'عقلة', glyph: '🧗',
    kind: LiftKind.weightedBodyweight, group: 'back',
    maleStandards:   [1.00, 1.05, 1.12, 1.22, 1.35, 1.50, 1.65, 1.80, 2.00],
    femaleStandards: [1.00, 1.03, 1.08, 1.15, 1.25, 1.38, 1.50, 1.62, 1.80],
  ),
  LiftExercise(
    id: 'dip', nameEn: 'Dip', nameAr: 'متوازي', glyph: '🤸',
    kind: LiftKind.weightedBodyweight, group: 'chest',
    maleStandards:   [1.00, 1.06, 1.15, 1.28, 1.42, 1.58, 1.75, 1.90, 2.10],
    femaleStandards: [1.00, 1.04, 1.10, 1.18, 1.30, 1.42, 1.55, 1.68, 1.85],
  ),
  LiftExercise(
    id: 'pushup', nameEn: 'Push-up', nameAr: 'ضغط', glyph: '🙇',
    kind: LiftKind.bodyweight, group: 'chest',
    maleStandards:   [5, 12, 22, 34, 46, 58, 70, 85, 100],
    femaleStandards: [3, 8, 15, 24, 34, 44, 55, 68, 80],
  ),
  LiftExercise(
    id: 'plank', nameEn: 'Plank', nameAr: 'بلانك', glyph: '🧘',
    kind: LiftKind.timed, group: 'core',
    maleStandards:   [20, 45, 75, 110, 150, 195, 240, 300, 360],
    femaleStandards: [15, 35, 60, 95, 130, 170, 215, 270, 330],
  ),
];

LiftExercise? liftById(String id) {
  for (final e in kLiftExercises) {
    if (e.id == id) return e;
  }
  return null;
}

/// Muscle groups in picker order.
const kLiftGroups = ['legs', 'chest', 'back', 'shoulders', 'arms', 'core'];

String liftGroupName(String group, {bool arabic = false}) {
  const en = {
    'legs': 'Legs', 'chest': 'Chest', 'back': 'Back',
    'shoulders': 'Shoulders', 'arms': 'Arms', 'core': 'Core',
  };
  const ar = {
    'legs': 'أرجل', 'chest': 'صدر', 'back': 'ظهر',
    'shoulders': 'أكتاف', 'arms': 'ذراعان', 'core': 'وسط',
  };
  return (arabic ? ar[group] : en[group]) ?? group;
}

// ════════════════════════════════════════════════════════════════════
// SCORING
// ════════════════════════════════════════════════════════════════════

/// Estimated one-rep max via the Epley formula.
///
/// Above about 12 reps the estimate stops being trustworthy, so reps are
/// capped rather than extrapolated into fantasy numbers.
double estimateOneRepMax(double weightKg, int reps) {
  if (weightKg <= 0 || reps <= 0) return 0;
  final r = reps.clamp(1, 12);
  if (r == 1) return weightKg;
  return weightKg * (1 + r / 30.0);
}

/// Converts a performance figure into a position on the ladder.
///
/// [value] is whatever the exercise measures: a bodyweight ratio, a rep
/// count, or seconds held.
///
/// The bands run from one tier's standard to the next. The very first
/// tier is the exception: it spans everything from zero up to the second
/// standard, so a beginner below the Copper mark still sees the bar move
/// and the score climbs smoothly across the whole ladder instead of
/// resetting as it crosses the first threshold.
StrengthRank rankForValue(double value, List<double> standards) {
  if (standards.isEmpty || value <= 0) return const StrengthRank(0);

  final tiers = standards.length;
  if (value >= standards.last) return const StrengthRank(kMaxLp);

  const perTier = kDivisionsPerTier * kLpPerDivision;

  for (var t = 0; t < tiers - 1; t++) {
    // The first tier starts at zero rather than at its own standard.
    final low = t == 0 ? 0.0 : standards[t];
    final high = standards[t + 1];
    if (value < low || value >= high) continue;
    final span = high - low;
    final frac = span <= 0 ? 0.0 : ((value - low) / span).clamp(0.0, 1.0);
    return StrengthRank((t * perTier + frac * perTier).round());
  }
  return const StrengthRank(kMaxLp);
}

/// The measured value for a set, in whatever unit the exercise uses.
double liftValue({
  required LiftExercise exercise,
  required double bodyweightKg,
  required double weightKg,
  required int reps,
  int seconds = 0,
}) {
  switch (exercise.kind) {
    case LiftKind.loaded:
      if (bodyweightKg <= 0) return 0;
      return estimateOneRepMax(weightKg, reps) / bodyweightKg;
    case LiftKind.weightedBodyweight:
      if (bodyweightKg <= 0) return 0;
      final total = estimateOneRepMax(bodyweightKg + weightKg, reps);
      return total / bodyweightKg;
    case LiftKind.bodyweight:
      return reps.toDouble();
    case LiftKind.timed:
      return seconds.toDouble();
  }
}

/// Rank for one performed set.
StrengthRank rankForSet({
  required LiftExercise exercise,
  required bool isMale,
  required double bodyweightKg,
  required double weightKg,
  required int reps,
  int seconds = 0,
}) {
  final value = liftValue(
    exercise: exercise,
    bodyweightKg: bodyweightKg,
    weightKg: weightKg,
    reps: reps,
    seconds: seconds,
  );
  return rankForValue(value, exercise.standardsFor(isMale: isMale));
}

/// Overall rank from a set of per-exercise bests.
///
/// Stronger lifts pull harder: bests are sorted high to low and weighted
/// with a decay, so one outstanding lift lifts the overall rank without
/// a long tail of untrained movements dragging it to zero.
StrengthRank overallRank(Iterable<StrengthRank> bests) {
  final scores = bests.map((r) => r.totalLp).where((lp) => lp > 0).toList()
    ..sort((a, b) => b.compareTo(a));
  if (scores.isEmpty) return const StrengthRank(0);

  var weightedSum = 0.0;
  var weightTotal = 0.0;
  var weight = 1.0;
  for (final score in scores.take(8)) {
    weightedSum += score * weight;
    weightTotal += weight;
    weight *= 0.72;
  }
  if (weightTotal <= 0) return const StrengthRank(0);
  return StrengthRank((weightedSum / weightTotal).round());
}

/// Plate breakdown for one side of a barbell, heaviest first.
///
/// Returns an empty list when the target cannot be made from the plates
/// available, so the caller can say so rather than showing a wrong load.
List<double> plateBreakdown(double targetKg, {double barKg = 20}) {
  const plates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25];
  var perSide = (targetKg - barKg) / 2;
  if (perSide <= 0) return const [];
  final out = <double>[];
  for (final plate in plates) {
    while (perSide >= plate - 0.001) {
      out.add(plate);
      perSide -= plate;
      if (out.length > 20) return out; // guard against runaway input
    }
  }
  return perSide.abs() < 0.01 ? out : const [];
}
