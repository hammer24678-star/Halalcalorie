// ════════════════════════════════════════════════════════════════════
//  achievements_card.dart — PATCH_V54_ACHIEVEMENTS
//  40 badges in 5 groups. Every threshold reads a provider that already
//  exists; earned badges are remembered so they never un-earn (e.g. a
//  "drank 12 cups" badge stays after midnight resets the counter).
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/fx6.dart';

class _Ach {
  final String id;
  final IconData icon;
  final String ar, en, descAr, descEn;
  final int cur, goal;
  const _Ach(this.id, this.icon, this.ar, this.en, this.descAr, this.descEn,
      this.cur, this.goal);
  bool get met => cur >= goal;
}

class _Cat {
  final String id, ar, en;
  final IconData icon;
  final List<_Ach> items;
  const _Cat(this.id, this.ar, this.en, this.icon, this.items);
}

class AchievementsCard extends ConsumerStatefulWidget {
  final bool isPremium, isAr, isDark;
  const AchievementsCard({
    super.key,
    required this.isPremium,
    required this.isAr,
    required this.isDark,
  });
  @override
  ConsumerState<AchievementsCard> createState() => _AchievementsCardState();
}

class _AchievementsCardState extends ConsumerState<AchievementsCard> {
  static const _kKey = 'ach_earned_v54';
  Set<String> _saved = <String>{};
  String _cat = 'all';
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList(_kKey) ?? <String>[];
      if (mounted) setState(() => _saved = l.toSet());
    } catch (_) {}
  }

  void _persist(Set<String> ids) {
    if (_syncing) return;
    _syncing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final p = await SharedPreferences.getInstance();
        final old = p.getStringList(_kKey) ?? <String>[];
        final merged = <String>{...old, ..._saved, ...ids};
        await p.setStringList(_kKey, merged.toList());
        if (mounted) setState(() => _saved = merged);
      } catch (_) {}
      _syncing = false;
    });
  }

  List<_Cat> _build() {
    final ach = ref.watch(achievementProvider);
    final fast = ref.watch(fastingProvider);
    final streak = ref.watch(streakProvider);
    final water = ref.watch(waterProvider);
    final sleep = ref.watch(sleepProvider);
    final wMin = ref.watch(workoutMinutesProvider);
    final burned = ref.watch(caloriesBurnedTodayProvider).round();
    final lifts = ref.watch(liftLogProvider).bests.length;
    final weights = ref.watch(weightLogProvider).length;
    final chain = ref.watch(ascentProvider).chain;
    final days = ach.totalDaysLogged;
    final fasts = fast.lifetimeCount;
    final foods = ach.wholeFoodsLogged;
    final sleepX10 = (sleep.hours * 10).round();
    final sleepGoalX10 = (sleep.goal * 10).round();
    final resolve = ((days / 28.0) < (fasts / 4.0) ? days / 28.0 : fasts / 4.0);
    final int resolveCur = (resolve * 100).floor().clamp(0, 100).toInt();

    _Ach a(String id, IconData ic, String ar, String en, String dAr, String dEn,
            int cur, int goal) =>
        _Ach(id, ic, ar, en, dAr, dEn, cur, goal);

    return [
      _Cat('log', 'الاستمرارية', 'Consistency', Icons.calendar_month_rounded, [
        a('d1', Icons.eco_rounded, 'البداية', 'Awakened', 'سجّل أول يوم', 'Log your first day', days, 1),
        a('d3', Icons.directions_walk_rounded, 'الخطوة الأولى', 'First Steps', 'سجّل ٣ أيام', 'Log 3 days', days, 3),
        a('d7', Icons.link_rounded, 'أسبوع كامل', 'Chain of Seven', 'سجّل ٧ أيام', 'Log 7 days', days, 7),
        a('d14', Icons.date_range_rounded, 'أسبوعان', 'Fortnight', 'سجّل ١٤ يوماً', 'Log 14 days', days, 14),
        a('d30', Icons.auto_awesome_rounded, 'المتقن', 'Refined', 'سجّل ٣٠ يوماً', 'Log 30 days', days, 30),
        a('d60', Icons.park_rounded, 'الراسخ', 'Rooted', 'سجّل ٦٠ يوماً', 'Log 60 days', days, 60),
        a('d100', Icons.emoji_events_rounded, 'المئة', 'Centurion', 'سجّل ١٠٠ يوم', 'Log 100 days', days, 100),
        a('d365', Icons.workspace_premium_rounded, 'سنة كاملة', 'Full Year', 'سجّل ٣٦٥ يوماً', 'Log 365 days', days, 365),
      ]),
      _Cat('streak', 'السلسلة', 'Streak', Icons.local_fire_department_rounded, [
        a('s3', Icons.local_fire_department_rounded, 'الثلاثية', 'Hat-trick', 'سلسلة ٣ أيام', '3-day streak', streak, 3),
        a('s7', Icons.whatshot_rounded, 'أسبوع ناري', 'Week of Fire', 'سلسلة ٧ أيام', '7-day streak', streak, 7),
        a('s14', Icons.trending_up_rounded, 'المثابر', 'Persistent', 'سلسلة ١٤ يوماً', '14-day streak', streak, 14),
        a('s21', Icons.loop_rounded, 'العادة', 'Habit', 'سلسلة ٢١ يوماً', '21-day streak', streak, 21),
        a('s30', Icons.calendar_month_rounded, 'شهر كامل', 'Month Strong', 'سلسلة ٣٠ يوماً', '30-day streak', streak, 30),
        a('s60', Icons.shield_rounded, 'الصامد', 'Steadfast', 'سلسلة ٦٠ يوماً', '60-day streak', streak, 60),
        a('s100', Icons.diamond_rounded, 'الماسة', 'Unbreakable', 'سلسلة ١٠٠ يوم', '100-day streak', streak, 100),
        a('s200', Icons.military_tech_rounded, 'الأسطورة', 'Legend', 'سلسلة ٢٠٠ يوم', '200-day streak', streak, 200),
      ]),
      _Cat('faith', 'الصيام والطيبات', 'Faith & Food', Icons.nights_stay_rounded, [
        a('f1', Icons.nights_stay_rounded, 'أول إمساك', 'First Restraint', 'سجّل أول صيام سنّة', 'Log your first sunnah fast', fasts, 1),
        a('f7', Icons.terrain_rounded, 'الثابت', 'Unmoved', 'سجّل ٧ أيام صيام', 'Log 7 fasting days', fasts, 7),
        a('f15', Icons.brightness_3_rounded, 'الصائم', 'The Faster', 'سجّل ١٥ يوم صيام', 'Log 15 fasting days', fasts, 15),
        a('f30', Icons.auto_stories_rounded, 'الصيام الثلاثون', 'Thirty Fasts', 'سجّل ٣٠ يوم صيام', 'Log 30 fasting days', fasts, 30),
        a('w3', Icons.spa_rounded, 'الطيّب', 'Wholesome', 'سجّل ٣ أطعمة طيبة', 'Log 3 wholesome foods', foods, 3),
        a('w15', Icons.local_florist_rounded, 'البستان', 'Orchard', 'سجّل ١٥ طعاماً طيباً', 'Log 15 wholesome foods', foods, 15),
        a('w50', Icons.eco_rounded, 'الطيبات', 'Pure Provisions', 'سجّل ٥٠ طعاماً طيباً', 'Log 50 wholesome foods', foods, 50),
        a('resolve', Icons.menu_book_rounded, 'العزم', 'Resolve', '٢٨ يوم تسجيل + ٤ أيام صيام', '28 logged days + 4 fasts', resolveCur, 100),
      ]),
      _Cat('fit', 'اللياقة', 'Fitness', Icons.fitness_center_rounded, [
        a('m15', Icons.directions_run_rounded, 'الإحماء', 'Warm-up', '١٥ دقيقة تمرين في يوم', '15 workout minutes in a day', wMin, 15),
        a('m30', Icons.check_circle_rounded, 'هدف اليوم', 'Daily Goal', '٣٠ دقيقة تمرين في يوم', '30 workout minutes in a day', wMin, 30),
        a('m60', Icons.timer_rounded, 'ساعة القوة', 'Power Hour', '٦٠ دقيقة تمرين في يوم', '60 workout minutes in a day', wMin, 60),
        a('b300', Icons.local_fire_department_rounded, 'الفرن', 'Furnace', 'احرق ٣٠٠ سعرة في يوم', 'Burn 300 kcal in a day', burned, 300),
        a('l1', Icons.fitness_center_rounded, 'أول رفعة', 'First Lift', 'صنّف تمرين رفع واحد', 'Rank 1 lift', lifts, 1),
        a('l5', Icons.accessibility_new_rounded, 'الرافع', 'Lifter', 'صنّف ٥ تمارين رفع', 'Rank 5 lifts', lifts, 5),
        a('l10', Icons.hardware_rounded, 'إرادة الحديد', 'Iron Will', 'صنّف ١٠ تمارين رفع', 'Rank 10 lifts', lifts, 10),
        a('l20', Icons.bolt_rounded, 'سيد القوة', 'Strength Master', 'صنّف ٢٠ تمرين رفع', 'Rank 20 lifts', lifts, 20),
      ]),
      _Cat('health', 'الصحة', 'Health', Icons.favorite_rounded, [
        a('wa4', Icons.water_drop_rounded, 'الرشفة', 'First Sips', 'اشرب ٤ أكواب في يوم', 'Drink 4 cups in a day', water.cups, 4),
        a('wag', Icons.opacity_rounded, 'السقّاء', 'Hydrated', 'أكمل هدف الماء اليومي', 'Reach your daily water goal', water.cups, water.goal < 1 ? 8 : water.goal),
        a('wa12', Icons.waves_rounded, 'النهر', 'River', 'اشرب ١٢ كوباً في يوم', 'Drink 12 cups in a day', water.cups, 12),
        a('sl7', Icons.bedtime_rounded, 'نوم هانئ', 'Good Sleep', 'نم ٧ ساعات', 'Sleep 7 hours', sleepX10, 70),
        a('slg', Icons.nights_stay_rounded, 'راحة كاملة', 'Fully Rested', 'أكمل هدف النوم', 'Reach your sleep goal', sleepX10, sleepGoalX10 < 1 ? 80 : sleepGoalX10),
        a('wt1', Icons.monitor_weight_rounded, 'الميزان', 'On the Scale', 'سجّل وزنك مرة', 'Log your weight once', weights, 1),
        a('wt10', Icons.show_chart_rounded, 'المتابع', 'Tracker', 'سجّل وزنك ١٠ مرات', 'Log your weight 10 times', weights, 10),
        a('ac7', Icons.terrain_rounded, 'الصعود', 'Ascent', 'سلسلة صعود ٧ أيام', '7-day ascent chain', chain, 7),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr, isDark = widget.isDark;
    final cats = _build();
    final all = [for (final c in cats) ...c.items];
    final metNow = {for (final x in all) if (x.met) x.id};
    if (metNow.difference(_saved).isNotEmpty) _persist(metNow);
    bool earned(_Ach x) => x.met || _saved.contains(x.id);
    final total = all.length;
    final got = all.where(earned).length;

    final card = isDark ? const Color(0xFF0F1E18) : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    String t(String ar, String en) => isAr ? ar : en;

    final shown = _cat == 'all'
        ? all
        : cats.firstWhere((c) => c.id == _cat, orElse: () => cats.first).items;

    Widget chip(String id, String label, int n, int of) {
      final sel = _cat == id;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _cat = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: sel ? AppColors.accentGold : textC.withOpacity(0.06),
            border: Border.all(
                color: sel ? Colors.transparent : textC.withOpacity(0.10),
                width: 0.8),
          ),
          child: Text('$label  $n/$of',
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: sel ? const Color(0xFF1A0F00) : muted)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border, width: 0.6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.07),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(
              icon: Icons.military_tech_rounded,
              color: AppColors.accentGold,
              size: 34),
          const SizedBox(width: 10),
          Expanded(
              child: Text(t('إنجازاتك', 'Your achievements'),
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: textC))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text('$got/$total',
                style: const TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGold)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : got / total,
            minHeight: 6,
            backgroundColor: textC.withOpacity(0.08),
            valueColor: const AlwaysStoppedAnimation(AppColors.accentGold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              chip('all', t('الكل', 'All'), got, total),
              for (final c in cats) ...[
                const SizedBox(width: 8),
                chip(c.id, isAr ? c.ar : c.en, c.items.where(earned).length,
                    c.items.length),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (ctx, box) {
          const gap = 8.0;
          final w = (box.maxWidth - gap * 3) / 4;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final x in shown)
                _BadgeTile(
                  a: x,
                  earned: earned(x),
                  width: w,
                  isAr: isAr,
                  isDark: isDark,
                  muted: muted,
                  onTap: () => _details(ctx, x, earned(x), isAr, isDark,
                      textC, muted, card),
                ),
            ],
          );
        }),
        if (!widget.isPremium) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Center(
                child: Text(
                    t('ترقّ لفتح كل الإنجازات', 'Upgrade to unlock all badges'),
                    style: const TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 11.5,
                        color: AppColors.accentGold))),
          ),
        ],
      ]),
    );
  }

  void _details(BuildContext ctx, _Ach x, bool earned, bool isAr, bool isDark,
      Color textC, Color muted, Color card) {
    final cur = x.cur > x.goal ? x.goal : x.cur;
    final frac = x.goal == 0 ? 0.0 : cur / x.goal;
    showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        decoration: BoxDecoration(
          color: card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: muted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: earned
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF0CF98), Color(0xFFDBA75D)])
                  : null,
              color: earned ? null : muted.withOpacity(0.16),
            ),
            child: Icon(x.icon,
                size: 32,
                color: earned ? const Color(0xFF1A0F00) : muted),
          ),
          const SizedBox(height: 12),
          Text(isAr ? x.ar : x.en,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: textC)),
          const SizedBox(height: 6),
          Text(isAr ? x.descAr : x.descEn,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Aligarh', fontSize: 13, color: muted)),
          const SizedBox(height: 16),
          if (earned)
            Text(isAr ? 'تم الإنجاز' : 'Unlocked',
                style: const TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.accentGold))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: textC.withOpacity(0.08),
                valueColor:
                    const AlwaysStoppedAnimation(AppColors.accentGold),
              ),
            ),
            const SizedBox(height: 8),
            Text(x.id == 'resolve' ? '$cur%' : '$cur / ${x.goal}',
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: muted)),
          ],
        ]),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final _Ach a;
  final bool earned, isAr, isDark;
  final double width;
  final Color muted;
  final VoidCallback onTap;
  const _BadgeTile({
    required this.a,
    required this.earned,
    required this.width,
    required this.isAr,
    required this.isDark,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cur = a.cur > a.goal ? a.goal : a.cur;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: earned
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                      AppColors.accentGold.withOpacity(0.20),
                      AppColors.accentGold.withOpacity(0.05)
                    ])
              : null,
          color: earned
              ? null
              : (isDark ? const Color(0xFF16231C) : const Color(0xFFF1F3F2)),
          border: Border.all(
              color: earned
                  ? AppColors.accentGold.withOpacity(0.5)
                  : Colors.transparent),
          boxShadow: earned
              ? [
                  BoxShadow(
                      color: AppColors.accentGold.withOpacity(0.22),
                      blurRadius: 14)
                ]
              : const [],
        ),
        child: Column(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: earned
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF0CF98), Color(0xFFDBA75D)])
                  : null,
              color: earned ? null : muted.withOpacity(0.14),
            ),
            child: Icon(earned ? a.icon : Icons.lock_rounded,
                size: earned ? 21 : 16,
                color: earned
                    ? const Color(0xFF1A0F00)
                    : muted.withOpacity(0.7)),
          ),
          const SizedBox(height: 6),
          Text(isAr ? a.ar : a.en,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: earned ? AppColors.accentGold : muted)),
          if (!earned && a.id != 'resolve')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('$cur/${a.goal}',
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 8.5,
                      color: muted.withOpacity(0.8))),
            ),
        ]),
      ),
    );
  }
}
