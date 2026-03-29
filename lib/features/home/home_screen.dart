// ============================================================
//  home_screen.dart — HalalCalorie v1.1 — Bilingual + Profile
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import 'prayer_card.dart';
import '../../core/health_service.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/models.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // ── Prayer times (Cairo static) ─────────────────────────
  static const _prayers = [
    {'n': 'الفجر / Fajr',   'na': 'الفجر',   'ne': 'Fajr',   'h': 5,  'm': 12},
    {'n': 'الظهر / Dhuhr',  'na': 'الظهر',   'ne': 'Dhuhr',  'h': 12, 'm': 18},
    {'n': 'العصر / Asr',    'na': 'العصر',   'ne': 'Asr',    'h': 15, 'm': 42},
    {'n': 'المغرب / Maghrib','na': 'المغرب', 'ne': 'Maghrib', 'h': 18, 'm': 5},
    {'n': 'العشاء / Isha',  'na': 'العشاء',  'ne': 'Isha',   'h': 19, 'm': 28},
  ];

  String _nextPrayer(bool isAr) {
    final now = DateTime.now();
    final cur = now.hour * 60 + now.minute;
    for (final p in _prayers) {
      final t = ((p['h'] as num?)?.toInt() ?? 0) * 60 + ((p['m'] as num?)?.toInt() ?? 0);
      if (t > cur) {
        final diff  = t - cur;
        final name  = isAr ? (p['na'] as String? ?? '') : (p['ne'] as String? ?? '');
        final timeStr = '${((p['h'] as num?)?.toInt() ?? 0).toString().padLeft(2,'0')}:${(p['m'] as int).toString().padLeft(2,'0')}';
        if (diff >= 60) return '$name  $timeStr  (${diff ~/ 60}h ${diff % 60}m)';
        return '$name  $timeStr  (${diff}min)';
      }
    }
    return isAr ? 'الفجر غداً' : 'Fajr Tomorrow';
  }


  // ── Daily Hadith (rotates by day-of-year) ───────────────
  Map<String, String> _todayHadith() {
    final dayIdx = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    return kDailyHadiths[dayIdx % kDailyHadiths.length];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang    = ref.watch(languageProvider);
    final isAr    = lang == 'ar';
    final isDark  = ref.watch(themeProvider);
    final gender  = ref.watch(genderProvider);
    final streak  = ref.watch(streakProvider);
    final zakat   = ref.watch(zakatProvider);
    final cals    = ref.watch(caloriesProvider);
    final water   = ref.watch(waterProvider);
    final sleep   = ref.watch(sleepProvider);
    final profile    = ref.watch(userProfileProvider);
    final isSis      = gender == 'sisters';
    final isRamadan  = ref.watch(ramadanModeProvider);
    final workoutMin = ref.watch(workoutMinutesProvider);

    final muted   = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final cardBg  = isDark ? AppColors.darkCard  : Colors.white;
    final calCol  = cals.total > cals.goal
        ? AppColors.haramRed
        : cals.percent > 0.85 ? AppColors.doubtOrange : AppColors.halalGreen;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isSis ? AppColors.barakahGold : AppColors.sunnahGreen,
        title: Text(
          isSis
            ? (isAr ? 'السلام عليكم أختي 👋' : 'Peace be upon you, sister 👋')
            : (isAr ? 'السلام عليكم أخي 👋' : 'Peace be upon you, brother 👋'),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
            onPressed: () => context.push('/settings'),
          ),
          // Dark mode toggle
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggle(),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 42, height: 24,
              decoration: BoxDecoration(
                color: isDark ? AppColors.sunnahGreen : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 250),
                alignment: isDark ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: 18, height: 18,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : AppColors.barakahGold,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text(isDark ? '🌙' : '☀️', style: const TextStyle(fontSize: 9))),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Language toggle
          GestureDetector(
            onTap: () => ref.read(languageProvider.notifier).set(isAr ? 'en' : 'ar'),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(isAr ? 'EN' : 'ع',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 8),
          // Gender badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isSis ? (isAr ? '🧕 للنساء' : '🧕 Sisters') : (isAr ? '🧔 للرجال' : '🧔 Brothers'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Personalized greeting from profile ────────────
          if (profile != null)
            Container(
              margin: const EdgeInsets.only(bottom: 13),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (isSis ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (isSis ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.2)),
              ),
              child: Text(isAr ? profile.greetingAr() : profile.greetingEn(),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: isDark ? AppColors.darkText : AppColors.lightText)),
            ),

          // ── Prayer card ──────────────────────────────────
          _prayerCard(isAr, isDark),
          const SizedBox(height: 13),

          // ── Calorie card ─────────────────────────────────
          GestureDetector(
            onTap: () => context.go('/nutrition'),
            child: _calorieCard(cals, calCol, muted, cardBg, isAr, profile),
          ),
          const SizedBox(height: 13),

          // ── Water + Sleep mini cards ──────────────────────
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => context.go('/health'),
              child: _miniTrack('💧', isAr ? 'الماء' : 'Water',
                  water.cups, water.goal, AppColors.waterBlue, cardBg),
            )),
            const SizedBox(width: 11),
            Expanded(child: GestureDetector(
              onTap: () => context.go('/health'),
              child: _miniTrack('😴', isAr ? 'النوم' : 'Sleep',
                  sleep.hours.toInt(), sleep.goal.toInt(), AppColors.sleepPurple, cardBg),
            )),
          ]),
          const SizedBox(height: 13),

          // ── Daily Hadith ─────────────────────────────────
          _hadithCard(isAr, isDark, cardBg),
          const SizedBox(height: 13),

          // ── Today's Progress Rings ────────────────────────
          _todayRings(cals, water, sleep, workoutMin, isDark, cardBg, muted, isAr),
          const SizedBox(height: 13),

          // ── Streak ───────────────────────────────────────
          _streakCard(streak, isDark, cardBg, isAr),
          const SizedBox(height: 13),

          // ── Body metrics quick peek ───────────────────────
          if (profile != null) ...[
            GestureDetector(
              onTap: () => context.go('/body'),
              child: _bodyMiniCard(profile, isDark, cardBg, isAr),
            ),
            const SizedBox(height: 13),
          ],

          // ── Quick actions ─────────────────────────────────
          Text(isAr ? 'ابدأ الآن' : 'Start Now',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 10),
          _quickAction(context, '📸', isAr ? 'صوّر طعامك 🤖' : 'Photo Your Food 🤖', isAr ? 'AI يحلل السعرات والحلال فوراً' : 'AI calculates calories & halal status instantly', AppColors.sunnahGreen, '/food-photo', cardBg: cardBg, isDark: isDark),
          _quickAction(context, '📷', isAr ? 'امسح باركود' : 'Scan Barcode', isAr ? 'تحقق من الحلال فوراً' : 'Check halal instantly', AppColors.halalGreen, '/scanner', cardBg: cardBg, isDark: isDark),
          _quickAction(context, '🏃', isAr ? 'ابدأ تمرين سني' : 'Start Sunnah Workout', isAr ? 'مشي ولياقة بدون موسيقى' : 'Walking & fitness without music', AppColors.sunnahGreen, '/fitness', cardBg: cardBg, isDark: isDark),
          _quickAction(context, '🌿', isAr ? 'وصفات سنية' : 'Sunnah Recipes', isAr ? 'تمر وعسل وزيت زيتون' : 'Dates, honey & olive oil', AppColors.barakahGold, '/nutrition', cardBg: cardBg, isDark: isDark),
          _quickAction(context, '💪', isAr ? 'مقاييس جسمي' : 'Body Metrics', isAr ? 'BMI، دهون، عضلات، أيض' : 'BMI, fat%, muscle, metabolism', AppColors.sunnahGreen, '/body', cardBg: cardBg, isDark: isDark),
          _quickAction(context, '🩺', isAr ? 'معلومات صحية' : 'Health Info', isAr ? 'مقالات وحاسبات صحية' : 'Articles & health calculators', const Color(0xFF009688), '/health', cardBg: cardBg, isDark: isDark),

          // ── Zakat card ────────────────────────────────────
          if (zakat > 50) ...[
            const SizedBox(height: 13),
            _zakatCard(zakat, isDark, cardBg, isAr),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }


  Widget _hadithCard(bool isAr, bool isDark, Color cardBg) {
    final h = _todayHadith();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A2A1A), const Color(0xFF0E1A0E)]
              : [AppColors.sunnahGreen.withOpacity(0.06), AppColors.sunnahGreen.withOpacity(0.02)],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sunnahGreen.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📖', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(isAr ? 'حديث اليوم' : "Today's Hadith",
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  fontWeight: FontWeight.w700, color: AppColors.sunnahGreen)),
          const Spacer(),
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: AppColors.sunnahGreen, shape: BoxShape.circle),
          ),
        ]),
        const SizedBox(height: 10),
        Text(isAr ? h['ar']! : h['en']!,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: isAr ? 13 : 12,
              height: 1.7, fontStyle: FontStyle.italic,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr),
      ]),
    );
  }

  Widget _todayRings(
    CaloriesState cals, WaterState water, SleepState sleep,
    int workoutMin, bool isDark, Color cardBg, Color muted, bool isAr,
  ) {
    final pCals  = cals.percent.clamp(0.0, 1.0);
    final pWater = water.percent.clamp(0.0, 1.0);
    final pSleep = sleep.percent.clamp(0.0, 1.0);
    final pWork  = workoutMin > 0 ? (workoutMin / 30).clamp(0.0, 1.0) : 0.0;
    final score  = ((pCals + pWater + pSleep + pWork) / 4 * 100).round();

    Widget ring(double pct, Color color, String emoji, String label, String value) {
      return Column(children: [
        SizedBox(width: 62, height: 62, child: Stack(alignment: Alignment.center, children: [
          SizedBox.expand(child: CircularProgressIndicator(
            value: pct, strokeWidth: 7,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(pct >= 1.0 ? AppColors.halalGreen : color),
            strokeCap: StrokeCap.round,
          )),
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            if (pct >= 1.0)
              const Icon(Icons.check, color: AppColors.halalGreen, size: 12),
          ]),
        ])),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isAr ? '🎯 إنجازات اليوم' : '🎯 Today\'s Progress',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: score >= 75 ? AppColors.halalGreen.withOpacity(0.12)
                   : score >= 50 ? AppColors.doubtOrange.withOpacity(0.12)
                   : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$score%', style: TextStyle(
                fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w900,
                color: score >= 75 ? AppColors.halalGreen
                     : score >= 50 ? AppColors.doubtOrange : muted)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          ring(pCals,  AppColors.haramRed,   '🔥', isAr ? 'سعرات' : 'Cals',
              '${cals.total}/${cals.goal}'),
          ring(pWater, AppColors.waterBlue,  '💧', isAr ? 'ماء' : 'Water',
              '${water.cups}/${water.goal}'),
          ring(pSleep, AppColors.sleepPurple,'😴', isAr ? 'نوم' : 'Sleep',
              '${sleep.hours.toInt()}/${sleep.goal.toInt()}h'),
          ring(pWork,  AppColors.sunnahGreen,'🏃', isAr ? 'تمرين' : 'Workout',
              workoutMin > 0 ? '${workoutMin}m' : '—'),
        ]),
      ]),
    );
  }

  Widget _prayerCard(bool isAr, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.sunnahGreen, AppColors.darkGreen]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.sunnahGreen.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        const Text('🕌', style: TextStyle(fontSize: 32)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isAr ? 'الصلاة القادمة' : 'Next Prayer',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white.withOpacity(0.75), fontSize: 12)),
          Text(_nextPrayer(isAr),
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }

  Widget _calorieCard(CaloriesState cals, Color calCol, Color muted, Color cardBg, bool isAr, UserProfile? profile) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('🔥', style: TextStyle(fontSize: 19)),
            const SizedBox(width: 8),
            Text(isAr ? 'سعرات اليوم' : "Today's Calories",
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: AppColors.sunnahGreen.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(isAr ? '+ أضف' : '+ Add',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.sunnahGreen)),
          ),
        ]),
        const SizedBox(height: 9),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${cals.total}',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w900, color: calCol)),
          Text('${isAr ? "الهدف" : "Goal"}: ${cals.goal}',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted)),
        ]),
        const SizedBox(height: 7),
        LinearProgressIndicator(value: cals.percent.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(calCol),
            borderRadius: BorderRadius.circular(8), minHeight: 8),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${isAr ? "متبقي" : "Left"}: ${cals.remaining}',
              style: TextStyle(fontSize: 10, color: muted, fontFamily: 'Cairo')),
          if (profile != null)
            Text('${isAr ? "BMR" : "BMR"}: ${profile.bmrKcal.toInt()}',
                style: TextStyle(fontSize: 10, color: muted, fontFamily: 'Cairo')),
        ]),
      ]),
    );
  }

  Widget _miniTrack(String emoji, String label, int val, int goal, Color color, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          Text('$val/$goal', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 7),
        Align(alignment: Alignment.centerRight, child: Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700))),
        const SizedBox(height: 5),
        LinearProgressIndicator(value: (val / (goal > 0 ? goal : 1)).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
            borderRadius: BorderRadius.circular(6), minHeight: 6),
      ]),
    );
  }

  Widget _streakCard(int streak, bool isDark, Color cardBg, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
      child: Row(children: [
        Text(streak >= 7 ? '🔥' : '⭐', style: const TextStyle(fontSize: 38)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$streak ${isAr ? "يوم متتالي" : "day streak"}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 19, fontWeight: FontWeight.w900)),
          Text(streak >= 7
            ? (isAr ? 'مبارك! الله يبارك فيك 🤲' : 'Blessed! May Allah reward you 🤲')
            : (isAr ? 'استمر في السنة والحلال' : 'Keep up the Sunnah & halal'),
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
              color: isDark ? AppColors.darkMuted : AppColors.lightMuted)),
        ]),
      ]),
    );
  }

  Widget _bodyMiniCard(UserProfile p, bool isDark, Color cardBg, bool isAr) {
    final bmiCol = p.bmi < 18.5 ? AppColors.waterBlue : p.bmi < 25 ? AppColors.halalGreen : p.bmi < 30 ? AppColors.doubtOrange : AppColors.haramRed;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isAr ? '💪 مقاييس جسمك' : '💪 Your Body Metrics',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w700)),
          Text(isAr ? 'التفاصيل ←' : '→ Details',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.sunnahGreen, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _miniMetric('BMI', p.bmi.toStringAsFixed(1), bmiCol, isAr ? p.bmiCategoryAr : p.bmiCategoryEn),
          _miniMetric(isAr ? 'BMR' : 'BMR', '${p.bmrKcal.toInt()}', AppColors.sunnahGreen, 'kcal'),
          _miniMetric(isAr ? 'الهدف' : 'Goal', '${p.calorieGoalKcal.toInt()}', AppColors.haramRed, 'kcal'),
          _miniMetric(isAr ? 'الماء' : 'Water', '${p.waterLiters}L', AppColors.waterBlue, isAr ? '/يوم' : '/day'),
        ]),
      ]),
    );
  }

  Widget _miniMetric(String label, String value, Color color, String sub) {
    return Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.lightMuted)),
      Text(sub, style: TextStyle(fontFamily: 'Cairo', fontSize: 8, color: color.withOpacity(0.7))),
    ]);
  }

  Widget _quickAction(BuildContext ctx, String emoji, String title, String sub, Color color, String route, {Color? cardBg, bool isDark = false}) {
    // Routes outside ShellRoute must be pushed
    final needsPush = route.startsWith('/food-photo') || route.startsWith('/body-photo') || route.startsWith('/paywall');
    return GestureDetector(
      onTap: () => needsPush ? ctx.push(route) : ctx.go(route),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.15 : 0.05), blurRadius: 8)]),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
            Text(sub, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.lightMuted)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? AppColors.darkMuted : AppColors.lightMuted),
        ]),
      ),
    );
  }

  Widget _zakatCard(double zakat, bool isDark, Color cardBg, bool isAr) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.barakahGold.withOpacity(isDark ? 0.08 : 0.1),
        border: Border.all(color: AppColors.barakahGold.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🤲', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 9),
          Text(isAr ? 'زكاة مقترحة' : 'Suggested Zakat',
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Text(
          isAr
            ? 'وفّرت ${zakat.toInt()} جنيه باختيار الحلال\nزكاتك: ${(zakat * 0.025).toStringAsFixed(1)} جنيه (٢.٥٪)'
            : 'You saved ${zakat.toInt()} EGP choosing halal\nYour zakat: ${(zakat * 0.025).toStringAsFixed(1)} EGP (2.5%)',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.lightMuted, height: 1.6)),
        const SizedBox(height: 11),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.barakahGold),
          child: Text(isAr ? 'تبرع الآن' : 'Donate Now',
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        )),
      ]),
    );
  }
}
