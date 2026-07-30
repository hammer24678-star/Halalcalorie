// ════════════════════════════════════════════════════════════════════
//  ascent.dart — the Ascent System
//
//  A progression layer over the day's healthy habits: eight daily
//  quests feed a 0-1000 daily score, the score converts to XP, XP
//  raises a level, and levels map onto ranks (E → SS).
//
//  Pure data + math only — no Flutter widgets, no providers, so this
//  file stays cheap to import and easy to unit-test.
// ════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart' show Color;

// ── Palette (kept local so this file has no theme dependency) ───────
class AscentColors {
  static const rankE = Color(0xFF8B949E); // graphite
  static const rankD = Color(0xFF6BCB8B); // jade
  static const rankC = Color(0xFF58A6FF); // azure
  static const rankB = Color(0xFFBC8CFF); // amethyst
  static const rankA = Color(0xFFE8B84B); // gold
  static const rankS = Color(0xFFFF7B54); // ember
  static const rankSS = Color(0xFFFF4D6D); // crimson
  static const system = Color(0xFF4FD1FF); // system-window cyan
  static const systemDim = Color(0xFF1B4B63);
}

// ════════════════════════════════════════════════════════════════════
// RANKS
// ════════════════════════════════════════════════════════════════════

class AscentRank {
  final String letter;
  final int minLevel;
  final Color color;
  final String nameAr, nameEn;
  const AscentRank(this.letter, this.minLevel, this.color,
      this.nameAr, this.nameEn);
}

const kRanks = <AscentRank>[
  AscentRank('E', 1, AscentColors.rankE, 'مبتدئ', 'Novice'),
  AscentRank('D', 5, AscentColors.rankD, 'منتظم', 'Consistent'),
  AscentRank('C', 10, AscentColors.rankC, 'منضبط', 'Disciplined'),
  AscentRank('B', 20, AscentColors.rankB, 'متمكّن', 'Adept'),
  AscentRank('A', 35, AscentColors.rankA, 'متقن', 'Refined'),
  AscentRank('S', 55, AscentColors.rankS, 'راسخ', 'Steadfast'),
  AscentRank('SS', 80, AscentColors.rankSS, 'قمة', 'Summit'),
];

AscentRank rankForLevel(int level) {
  var r = kRanks.first;
  for (final candidate in kRanks) {
    if (level >= candidate.minLevel) r = candidate;
  }
  return r;
}

/// Level after this one that unlocks a new rank letter, or null at the top.
int? nextRankLevel(int level) {
  for (final r in kRanks) {
    if (r.minLevel > level) return r.minLevel;
  }
  return null;
}

// ════════════════════════════════════════════════════════════════════
// XP CURVE
// ════════════════════════════════════════════════════════════════════

const int kMaxLevel = 99;

/// XP needed to go from [level] to [level] + 1.
int xpToAdvance(int level) => 120 + (level - 1) * 45;

/// Total XP required to *reach* [level] from zero.
int xpAtLevelStart(int level) {
  var total = 0;
  for (var i = 1; i < level; i++) {
    total += xpToAdvance(i);
  }
  return total;
}

/// Level implied by a lifetime XP total, clamped to [kMaxLevel].
int levelFromXp(int totalXp) {
  var level = 1;
  var remaining = totalXp;
  while (level < kMaxLevel && remaining >= xpToAdvance(level)) {
    remaining -= xpToAdvance(level);
    level++;
  }
  return level;
}

/// XP banked toward the *current* level.
int xpIntoLevel(int totalXp) {
  final level = levelFromXp(totalXp);
  if (level >= kMaxLevel) return xpToAdvance(kMaxLevel);
  return totalXp - xpAtLevelStart(level);
}

/// 0.0-1.0 progress across the current level.
double levelProgress(int totalXp) {
  final level = levelFromXp(totalXp);
  if (level >= kMaxLevel) return 1.0;
  final need = xpToAdvance(level);
  if (need <= 0) return 1.0;
  return (xpIntoLevel(totalXp) / need).clamp(0.0, 1.0);
}

/// XP a day is worth: score/10, lifted by the chain multiplier, plus a
/// flat bonus for a clean sweep of all eight quests.
int xpForDay({required int score, required int chainDays,
    required bool allQuests}) {
  final base = score / 10.0;
  final bonus = allQuests ? 25 : 0;
  return (base * chainMultiplier(chainDays)).round() + bonus;
}

/// Chain (consecutive qualifying days) ramps to exactly 2× at 30 days.
const int kChainMultiplierDays = 30;

double chainMultiplier(int chainDays) =>
    1.0 + chainDays.clamp(0, kChainMultiplierDays) / kChainMultiplierDays;

// ════════════════════════════════════════════════════════════════════
// QUESTS
// ════════════════════════════════════════════════════════════════════

/// Stable identifiers — these double as the DB column names.
enum QuestId { nourish, hydrate, rest, move, train, stillness, restraint, wholesome }

class QuestMeta {
  final QuestId id;
  final String glyph;
  final Color color;
  final String nameAr, nameEn;
  final String hintAr, hintEn;
  const QuestMeta(this.id, this.glyph, this.color,
      this.nameAr, this.nameEn, this.hintAr, this.hintEn);
}

const kQuests = <QuestMeta>[
  QuestMeta(QuestId.nourish, '🍲', Color(0xFF3FB950),
      'تغذية', 'Nourish',
      'ابلغ نطاق سعراتك اليومي', 'Land inside your calorie range'),
  QuestMeta(QuestId.hydrate, '💧', Color(0xFF58A6FF),
      'ترطيب', 'Hydrate',
      'أكمل أكواب الماء', 'Finish your water cups'),
  QuestMeta(QuestId.rest, '😴', Color(0xFFBC8CFF),
      'راحة', 'Rest',
      'نم بقدر هدفك', 'Sleep to your target'),
  QuestMeta(QuestId.move, '👣', Color(0xFF6BCB8B),
      'حركة', 'Move',
      'اقطع خطواتك اليومية', 'Cover your daily steps'),
  QuestMeta(QuestId.train, '🏋️', Color(0xFFFF7B54),
      'تدريب', 'Train',
      '٣٠ دقيقة تمرين', '30 minutes of training'),
  QuestMeta(QuestId.stillness, '🕊️', Color(0xFF4FD1FF),
      'سكينة', 'Stillness',
      'دقائق هادئة بلا شاشة', 'A few quiet, screen-free minutes'),
  QuestMeta(QuestId.restraint, '🌘', Color(0xFFE8B84B),
      'إمساك', 'Restraint',
      'يوم صيام', 'A day of fasting'),
  QuestMeta(QuestId.wholesome, '🌿', Color(0xFF9BD17C),
      'طيبات', 'Wholesome',
      'سجّل طعاماً كاملاً غير مصنّع', 'Log a whole, unprocessed food'),
];

QuestMeta questMeta(QuestId id) => kQuests.firstWhere((q) => q.id == id);

/// Every quest caps at this many points → 8 × 125 = 1000.
const int kQuestMax = 125;

// ════════════════════════════════════════════════════════════════════
// STATE
// ════════════════════════════════════════════════════════════════════

class AscentState {
  /// Points per quest, each 0..[kQuestMax].
  final Map<QuestId, int> quests;

  /// Lifetime XP across every logged day.
  final int totalXp;

  /// Consecutive qualifying days ending today (or yesterday).
  final int chain;

  /// Best daily score in the last 7 days.
  final int weekBest;

  /// True while the first sync is still in flight.
  final bool loading;

  const AscentState({
    this.quests = const {},
    this.totalXp = 0,
    this.chain = 0,
    this.weekBest = 0,
    this.loading = true,
  });

  int points(QuestId id) => quests[id] ?? 0;
  bool isDone(QuestId id) => points(id) >= kQuestMax;

  /// Today's 0-1000 score.
  int get score =>
      kQuests.fold(0, (sum, q) => sum + points(q.id).clamp(0, kQuestMax));

  int get questsDone => kQuests.where((q) => isDone(q.id)).length;
  bool get allQuestsDone => questsDone == kQuests.length;

  int get level => levelFromXp(totalXp);
  AscentRank get rank => rankForLevel(level);
  double get progress => levelProgress(totalXp);
  int get xpInLevel => xpIntoLevel(totalXp);
  int get xpNeeded => level >= kMaxLevel ? xpToAdvance(kMaxLevel) : xpToAdvance(level);

  /// XP today's activity is currently worth.
  int get todayXp =>
      xpForDay(score: score, chainDays: chain, allQuests: allQuestsDone);

  Color get color => rank.color;

  /// A short read on the day, used under the level ring.
  String gradeAr() {
    if (score >= 900) return 'يوم كامل';
    if (score >= 700) return 'يوم قوي';
    if (score >= 500) return 'في الطريق';
    if (score >= 300) return 'بداية';
    return 'لم يبدأ بعد';
  }

  String gradeEn() {
    if (score >= 900) return 'Complete day';
    if (score >= 700) return 'Strong day';
    if (score >= 500) return 'On track';
    if (score >= 300) return 'Getting going';
    return 'Not started';
  }

  AscentState copyWith({
    Map<QuestId, int>? quests,
    int? totalXp,
    int? chain,
    int? weekBest,
    bool? loading,
  }) =>
      AscentState(
        quests: quests ?? this.quests,
        totalXp: totalXp ?? this.totalXp,
        chain: chain ?? this.chain,
        weekBest: weekBest ?? this.weekBest,
        loading: loading ?? this.loading,
      );
}

// ════════════════════════════════════════════════════════════════════
// TITLES  (earned, permanent, shown on the profile)
// ════════════════════════════════════════════════════════════════════

class AscentTitle {
  final int id;
  final String glyph;
  final String nameAr, nameEn;
  final String descAr, descEn;
  const AscentTitle({
    required this.id,
    required this.glyph,
    required this.nameAr,
    required this.nameEn,
    required this.descAr,
    required this.descEn,
  });
}

const kTitles = <AscentTitle>[
  AscentTitle(id: 1, glyph: '🌱', nameAr: 'البداية', nameEn: 'Awakened',
      descAr: 'سجّل يومك الأول', descEn: 'Log your first day'),
  AscentTitle(id: 2, glyph: '🔗', nameAr: 'سلسلة السبعة', nameEn: 'Chain of Seven',
      descAr: 'سلسلة ٧ أيام', descEn: 'A 7-day chain'),
  AscentTitle(id: 3, glyph: '🌘', nameAr: 'أول إمساك', nameEn: 'First Restraint',
      descAr: 'أول يوم صيام', descEn: 'Your first fasting day'),
  AscentTitle(id: 4, glyph: '⛰️', nameAr: 'الثابت', nameEn: 'Unmoved',
      descAr: '٧ أيام صيام', descEn: '7 fasting days'),
  AscentTitle(id: 5, glyph: '🌿', nameAr: 'الطيّب', nameEn: 'Wholesome',
      descAr: 'سجّل ٣ أطعمة كاملة', descEn: 'Log 3 whole foods'),
  AscentTitle(id: 6, glyph: '💧', nameAr: 'حافظ الماء', nameEn: 'Tide Keeper',
      descAr: 'أكمل هدف الماء ٣ أيام', descEn: 'Hit your water goal 3 days'),
  AscentTitle(id: 7, glyph: '🏋️', nameAr: 'إرادة الحديد', nameEn: 'Iron Will',
      descAr: '٣٠ دقيقة تدريب', descEn: '30 minutes of training'),
  AscentTitle(id: 8, glyph: '🔥', nameAr: 'المتّقد', nameEn: 'Kindled',
      descAr: '٣ تدريبات في أسبوع', descEn: '3 sessions in one week'),
  AscentTitle(id: 9, glyph: '🌟', nameAr: 'خمس مئة', nameEn: 'Five Hundred',
      descAr: 'نقاط اليوم ≥ ٥٠٠', descEn: 'Daily score of 500'),
  AscentTitle(id: 10, glyph: '🌠', nameAr: 'سبع مئة', nameEn: 'Seven Hundred',
      descAr: 'نقاط اليوم ≥ ٧٠٠', descEn: 'Daily score of 700'),
  AscentTitle(id: 11, glyph: '✨', nameAr: 'متألق', nameEn: 'Radiant',
      descAr: 'نقاط اليوم ≥ ٩٠٠', descEn: 'Daily score of 900'),
  AscentTitle(id: 12, glyph: '🕊️', nameAr: 'سكينة', nameEn: 'Still Mind',
      descAr: 'أول وقفة سكينة', descEn: 'Your first stillness check-in'),
  AscentTitle(id: 13, glyph: '📘', nameAr: 'العزم', nameEn: 'Resolve',
      descAr: '٢٨ يوماً و٤ أيام صيام', descEn: '28 days and 4 fasts'),
  AscentTitle(id: 14, glyph: '💎', nameAr: 'المئة', nameEn: 'Centurion',
      descAr: 'سلسلة ١٠٠ يوم', descEn: 'A 100-day chain'),
  AscentTitle(id: 15, glyph: '◈', nameAr: 'اليوم الكامل', nameEn: 'Perfect Day',
      descAr: 'أكمل المهام الثماني في يوم', descEn: 'All eight quests in one day'),
  AscentTitle(id: 16, glyph: '🌅', nameAr: 'المبكّر', nameEn: 'Dawn Riser',
      descAr: 'تدريب قبل السادسة صباحاً', descEn: 'Train before 6 AM'),
  AscentTitle(id: 17, glyph: '⚡', nameAr: 'الزخم', nameEn: 'Momentum',
      descAr: 'سلسلة ١٤ يوماً', descEn: 'A 14-day chain'),
  AscentTitle(id: 18, glyph: '🎖️', nameAr: 'دورة كاملة', nameEn: 'Full Cycle',
      descAr: 'سلسلة ٣٠ يوماً', descEn: 'A 30-day chain'),
  AscentTitle(id: 19, glyph: '🌍', nameAr: 'المسافر', nameEn: 'Wayfarer',
      descAr: 'استخدم التطبيق بثلاث لغات', descEn: 'Use the app in three languages'),
  AscentTitle(id: 20, glyph: '👑', nameAr: 'الأعلى', nameEn: 'Ascendant',
      descAr: 'كل المهام مع سلسلة ١٠٠ يوم', descEn: 'Every quest on a 100-day chain'),
  AscentTitle(id: 21, glyph: '🔰', nameAr: 'رتبة C', nameEn: 'Rank C',
      descAr: 'ابلغ المستوى ١٠', descEn: 'Reach level 10'),
  AscentTitle(id: 22, glyph: '🏵️', nameAr: 'رتبة B', nameEn: 'Rank B',
      descAr: 'ابلغ المستوى ٢٠', descEn: 'Reach level 20'),
  AscentTitle(id: 23, glyph: '🎗️', nameAr: 'رتبة A', nameEn: 'Rank A',
      descAr: 'ابلغ المستوى ٣٥', descEn: 'Reach level 35'),
  AscentTitle(id: 24, glyph: '🏆', nameAr: 'رتبة S', nameEn: 'Rank S',
      descAr: 'ابلغ المستوى ٥٥', descEn: 'Reach level 55'),
];
