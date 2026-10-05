// fitness_screen.dart
// PATCH_V25_PLAYER_HEALTH — HalalCalorie v1.0
// 23 workouts, category tabs, Ramadan mode, step-by-step player
import 'dart:async'; import'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'../../core/theme.dart'; import'../../core/providers.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import 'lift_screen.dart'; import'../../data/models/models.dart'; import '../../data/muscle_assets.dart'; import '../../data/icon_assets.dart';
import '../../core/fx6.dart';
import 'dart:math' as math;
import '../../core/fx.dart' show AuroraBackground;
import '../../core/fx7.dart' show EmptyState;

// ══════════════════════════════════════════════════
//  FitnessScreen
// ══════════════════════════════════════════════════
class FitnessScreen extends ConsumerStatefulWidget {
  const FitnessScreen({super.key});
  @override ConsumerState<FitnessScreen> createState() => _FitnessState();
}

class _FitnessState extends ConsumerState<FitnessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab; String _filter ='all';
  late AnimationController _stagger;
  Animation<double> _fade(int i) => CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.09, (i * 0.09 + 0.5).clamp(0,1), curve: Curves.easeOutQuart));
  Animation<Offset> _slide(int i) => Tween<Offset>(
      begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.09, (i * 0.09 + 0.5).clamp(0,1), curve: Curves.easeOutQuart)));
  Widget _anim(int i, Widget child) => FadeTransition(
      opacity: _fade(i), child: SlideTransition(position: _slide(i), child: child));
 static const _cats = ['all','walking','strength','cardio','gentle','ramadan','breathing','family','postnatal'];

  @override void initState() {
    super.initState();
    _tab = TabController(length: _cats.length, vsync: this);
    _tab.addListener(() => setState(() => _filter = _cats[_tab.index]));
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
  }
  @override void dispose() { _tab.dispose(); _stagger.dispose(); super.dispose(); }

  List<Workout> _filtered(String gender, bool isRamadan, bool isPremium) { var list = kWorkouts.where((w) => w.gender =='both'|| w.gender == gender).toList();
    if (isRamadan) {
      // Put Ramadan workouts first
      list.sort((a, b) { final aR = a.category =='ramadan'? 0 : 1; final bR = b.category =='ramadan'? 0 : 1;
        return aR.compareTo(bR);
      });
    } if (_filter !='all') list = list.where((w) => w.category == _filter).toList();
    return list;
  }

  // PATCH_V53_FITNESS
  @override
  Widget build(BuildContext context) {
    final gender     = ref.watch(genderProvider);
    final lang       = ref.watch(languageProvider);
    final isAr       = lang == 'ar' || lang == 'ur';
    final isDark     = ref.watch(themeProvider);
    final isPremium  = ref.watch(premiumProvider);
    final isRamadan  = ref.watch(ramadanModeProvider);
    final workoutMin = ref.watch(workoutMinutesProvider);
    final streak     = ref.watch(streakProvider);
    final burned     = ref.watch(caloriesBurnedTodayProvider);
    final Set<String> weekDays = ref.watch(workoutWeekProvider)
        .maybeWhen(data: (d) => d, orElse: () => <String>{});
    final isSis = gender == 'sisters';
    final ram   = isRamadan && !isSis;
    final l     = L.fromLang(lang);
    String t(String ar, String en) => l.t(ar, en);

    final Color bg, card, textC, muted, accent, onAccent;
    if (ram) {
      bg       = isDark ? AppColors.ramadanNight : AppColors.ramadanDay;
      card     = isDark ? AppColors.ramadanCard : AppColors.ramadanDayCard;
      textC    = isDark ? AppColors.ramadanText : AppColors.ramadanDayText;
      muted    = isDark ? AppColors.ramadanMuted : AppColors.ramadanDayMuted;
      accent   = isDark ? AppColors.ramadanGold : AppColors.ramadanGoldDim;
      onAccent = AppColors.ramadanInk;
    } else {
      bg       = isDark ? AppColors.darkBg : AppColors.lightBg;
      card     = isDark ? AppColors.darkCard : Colors.white;
      textC    = isDark ? AppColors.darkText : AppColors.lightText;
      muted    = isDark ? AppColors.darkMuted : AppColors.lightMuted;
      accent   = isSis ? AppColors.accentGold : AppColors.brandGreen;
      onAccent = isSis ? AppColors.ramadanInk : Colors.white;
    }
    final pal = _FitPal(
        isDark: isDark, ram: ram, isSis: isSis, isAr: isAr,
        bg: bg, card: card, text: textC, muted: muted,
        accent: accent, onAccent: onAccent);

    final auroraColors = ram
        ? const [Color(0xFFE8B84B), Color(0xFF5B3FD0), Color(0xFF2B1B6B)]
        : isSis
            ? const [Color(0xFFDBA75D), Color(0xFFD9779B), Color(0xFF8B5E1A)]
            : const [Color(0xFF1E9E52), Color(0xFFDBA75D), Color(0xFF0E6B6B)];

    // ── data ────────────────────────────────────────
    final base = kWorkouts
        .where((w) => w.gender == 'both' || w.gender == gender)
        .toList();
    int countOf(String c) =>
        c == 'all' ? base.length : base.where((w) => w.category == c).length;
    final cats = [for (final c in _cats) if (c == 'all' || countOf(c) > 0) c];
    final filter = cats.contains(_filter) ? _filter : 'all';
    final ordered = isRamadan
        ? [
            ...base.where((w) => w.category == 'ramadan'),
            ...base.where((w) => w.category != 'ramadan'),
          ]
        : base;
    final list = filter == 'all'
        ? ordered
        : ordered.where((w) => w.category == filter).toList();

    final catLabels = <String, String>{
      'all':       t('الكل', 'All'),
      'walking':   t('مشي', 'Walk'),
      'strength':  t('قوة', 'Strength'),
      'cardio':    t('كارديو', 'Cardio'),
      'gentle':    t('لطيف', 'Gentle'),
      'ramadan':   t('رمضان', 'Ramadan'),
      'breathing': t('تنفس', 'Breathe'),
      'family':    t('عائلة', 'Family'),
      'postnatal': t('بعد الولادة', 'Postnatal'),
    };
    final counts = <String, int>{for (final c in cats) c: countOf(c)};

    // ── recommendation (always one, picked from this user's pool) ──
    final hour = DateTime.now().hour;
    final free = base.where((w) => !w.isPremium).toList();
    Workout? pick(bool Function(Workout) test) {
      for (final w in free) {
        if (test(w)) return w;
      }
      return null;
    }
    Workout? rec;
    if (ram) {
      rec = pick((w) => w.category == 'ramadan');
    } else if (hour >= 5 && hour < 8) {
      rec = pick((w) => w.id == 'w6');
    } else if (hour >= 16 && hour < 20) {
      rec = pick((w) => w.category == 'strength');
    } else if (hour >= 21) {
      rec = pick((w) => w.category == 'breathing');
    }
    rec ??= pick((w) => w.category == 'walking');
    rec ??= free.isNotEmpty ? free.first : (base.isNotEmpty ? base.first : null);
    final recW = rec;
    final done = workoutMin >= _kFitGoalMin;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(children: [
          Positioned.fill(
            child: AuroraBackground(
              base: bg,
              colors: auroraColors,
              intensity: isDark ? 0.50 : 0.26,
              seconds: 24,
            ),
          ),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: accent,
              onRefresh: () async {
                ref.invalidate(workoutWeekProvider);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(children: [
                      Reveal(
                        index: 0,
                        child: _FitHeader(
                          pal: pal,
                          title: l.fitnessTitle,
                          subtitle: t('اجعل كل يوم أقوى من الذي قبله',
                              'Make each day stronger than the last'),
                          font: lang == 'ar' ? 'LemonBrush' : 'Bravoon',
                          streak: streak,
                          onTrophy: () => context.push('/lift'),
                        ),
                      ),
                      if (ram || isSis)
                        Reveal(
                          index: 1,
                          child: _FitModeBanner(
                            pal: pal,
                            text: isSis && isRamadan
                                ? t('وضع النساء + رمضان — تمارين محتشمة وخفيفة',
                                    'Women + Ramadan — modest and light sessions')
                                : ram
                                    ? l.ramadanModeLabel
                                    : t('وضع النساء — تمارين محتشمة',
                                        'Women mode — modest sessions'),
                          ),
                        ),
                      Reveal(
                        index: 1,
                        child: _FitActivity(
                          pal: pal,
                          minutes: workoutMin,
                          burned: burned,
                          streak: streak,
                          week: weekDays,
                          t: t,
                        ),
                      ),
                      Reveal(
                        index: 2,
                        child: _FitStrength(pal: pal, l: l),
                      ),
                      if (recW != null)
                        Reveal(
                          index: 3,
                          child: _FitHero(
                            w: recW,
                            pal: pal,
                            done: done,
                            iconPath: workoutIconAsset(recW.id, isSis),
                            onTap: () => context.push('/workout/${recW.id}'),
                            t: t,
                          ),
                        ),
                      const SizedBox(height: 8),
                    ]),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _FitPinned(
                      height: 56,
                      bg: bg,
                      child: _FitChips(
                        pal: pal,
                        cats: cats,
                        selected: filter,
                        counts: counts,
                        labels: catLabels,
                        onPick: (c) => setState(() => _filter = c),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _FitSection(
                      pal: pal,
                      title: t('التمارين', 'Workouts'),
                      count: list.length,
                    ),
                  ),
                  if (list.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: t('لا تمارين في هذه الفئة',
                              'No workouts in this category'),
                          color: accent,
                          textColor: textC,
                          mutedColor: muted,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 206,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final w = list[i];
                            final locked = w.isPremium && !isPremium;
                            return Reveal(
                              key: ValueKey('${filter}_${w.id}'),
                              index: math.min(i, 8),
                              child: _FitCard(
                                w: w,
                                pal: pal,
                                locked: locked,
                                iconPath: workoutIconAsset(w.id, isSis),
                                onTap: () {
                                  if (locked) {
                                    ctx.push('/paywall');
                                  } else {
                                    ctx.push('/workout/${w.id}');
                                  }
                                },
                                t: t,
                              ),
                            );
                          },
                          childCount: list.length,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
                      child: isPremium
                          ? const SizedBox.shrink()
                          : _FitUpsell(
                              pal: pal,
                              count: kWorkouts.where((w) => w.isPremium).length,
                              onTap: () => context.push('/paywall'),
                              t: t,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Color _hexColor(String hex) { final h = hex.replaceAll('#', ''); return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00A86B);
  }
}

// ══════════════════════════════════════════════════
//  PATCH_V53_FITNESS — building blocks for the Fitness screen
// ══════════════════════════════════════════════════
const int _kFitGoalMin = 30;

Color _fitHex(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF00A86B);
}

String _fitKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, "0")}-${d.day.toString().padLeft(2, "0")}';

IconData _fitCatIcon(String c) {
  switch (c) {
    case 'walking':   return Icons.directions_walk_rounded;
    case 'strength':  return Icons.fitness_center_rounded;
    case 'cardio':    return Icons.bolt_rounded;
    case 'gentle':    return Icons.accessibility_new_rounded;
    case 'ramadan':   return Icons.nightlight_round;
    case 'breathing': return Icons.spa_rounded;
    case 'family':    return Icons.groups_rounded;
    case 'postnatal': return Icons.child_friendly_rounded;
    default:          return Icons.apps_rounded;
  }
}

class _FitPal {
  final bool isDark, ram, isSis, isAr;
  final Color bg, card, text, muted, accent, onAccent;
  const _FitPal({
    required this.isDark, required this.ram, required this.isSis,
    required this.isAr, required this.bg, required this.card,
    required this.text, required this.muted, required this.accent,
    required this.onAccent,
  });
  Color get hair  => text.withOpacity(isDark ? 0.10 : 0.08);
  Color get track => text.withOpacity(isDark ? 0.10 : 0.09);
  List<Color> get heroColors => ram
      ? [AppColors.ramadanNight, AppColors.ramadanCardAlt]
      : isSis
          ? [const Color(0xFFB8860B), const Color(0xFFDAA520)]
          : [const Color(0xFF0F3D24), const Color(0xFF2E9C40)];
  Color get glow => ram
      ? AppColors.ramadanGold
      : isSis ? AppColors.accentGold : AppColors.brandGreen;
}

// ── header ───────────────────────────────────────
class _FitHeader extends StatelessWidget {
  final _FitPal pal;
  final String title, subtitle, font;
  final int streak;
  final VoidCallback onTrophy;
  const _FitHeader({
    required this.pal, required this.title, required this.subtitle,
    required this.font, required this.streak, required this.onTrophy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 16, 6),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: font,
                      fontWeight: FontWeight.w400,
                      fontSize: 34,
                      height: 1.05,
                      color: pal.text)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 12, color: pal.muted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: pal.accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: pal.accent.withOpacity(0.32)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const EmojiIcon('🔥', size: 15),
            const SizedBox(width: 5),
            Text('$streak',
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: pal.text)),
          ]),
        ),
        const SizedBox(width: 8),
        GlassIconBtn(
          icon: Icons.emoji_events_rounded,
          onTap: onTrophy,
          isDark: pal.isDark,
        ),
      ]),
    );
  }
}

class _FitModeBanner extends StatelessWidget {
  final _FitPal pal;
  final String text;
  const _FitModeBanner({required this.pal, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: pal.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.accent.withOpacity(0.28), width: 0.8),
      ),
      child: Row(children: [
        Text(pal.isSis ? '🧕' : '🌙', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: pal.accent)),
        ),
      ]),
    );
  }
}

// ── today's activity: ring + stats + week strip ──
class _FitRingPainter extends CustomPainter {
  final double progress;
  final Color color, track;
  const _FitRingPainter(this.progress, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 9;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = track);
    final p = progress.clamp(0.0, 1.0).toDouble();
    if (p <= 0.002) return;
    final sweep = 2 * math.pi * p;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: math.max(sweep, 0.01),
            colors: [color.withOpacity(0.50), color],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect));
    final a = -math.pi / 2 + sweep;
    final head = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
    canvas.drawCircle(
        head,
        10,
        Paint()
          ..color = color.withOpacity(0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
    canvas.drawCircle(head, 4.2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_FitRingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

class _FitActivity extends StatelessWidget {
  final _FitPal pal;
  final int minutes, streak;
  final double burned;
  final Set<String> week;
  final String Function(String, String) t;
  const _FitActivity({
    required this.pal, required this.minutes, required this.burned,
    required this.streak, required this.week, required this.t,
  });

  Widget _mini(IconData icon, Color c, String v, String label) {
    return Expanded(
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: c.withOpacity(0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: c),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(v,
                  maxLines: 1,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: pal.text)),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 10, color: pal.muted)),
            ],
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final done = minutes >= _kFitGoalMin;
    final double prog = math.min(1.0, minutes / _kFitGoalMin);
    final left = _kFitGoalMin - minutes;
    final today = DateTime.now();
    final dayAr = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    final dayEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            pal.card,
            Color.lerp(pal.card, pal.accent, pal.isDark ? 0.09 : 0.05)!,
          ],
        ),
        border: Border.all(color: pal.accent.withOpacity(0.26), width: 0.9),
        boxShadow: [
          BoxShadow(
              color: pal.accent.withOpacity(pal.isDark ? 0.18 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(alignment: Alignment.center, children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: prog),
                duration: Motion.lazy,
                curve: Motion.curve,
                builder: (_, v, __) => CustomPaint(
                  size: const Size(108, 108),
                  painter: _FitRingPainter(v, pal.accent, pal.track),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                if (done)
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: pal.accent),
                CountUp(
                  value: minutes,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: pal.text),
                ),
                Text('/ $_kFitGoalMin ${t("د", "min")}',
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 10.5,
                        color: pal.muted)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('نشاط اليوم', "Today's activity"),
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: pal.text)),
                const SizedBox(height: 3),
                Text(
                    done
                        ? t('أنجزت هدف اليوم، بارك الله فيك',
                            'Daily goal reached — well done')
                        : t('باقي $left دقيقة على هدفك',
                            '$left min left to your goal'),
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 11.5,
                        height: 1.35,
                        color: pal.muted)),
                const SizedBox(height: 14),
                Row(children: [
                  _mini(Icons.local_fire_department_rounded,
                      AppColors.doubtOrange, '${burned.round()}',
                      t('سعرة محروقة', 'kcal burned')),
                  const SizedBox(width: 8),
                  _mini(Icons.bolt_rounded, pal.accent, '$streak',
                      t('أيام متتالية', 'day streak')),
                ]),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(height: 0.8, color: pal.hair),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final d = today.subtract(Duration(days: 6 - i));
            final on = week.contains(_fitKey(d));
            final isToday = i == 6;
            final label = pal.isAr ? dayAr[d.weekday - 1] : dayEn[d.weekday - 1];
            return Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? pal.accent : Colors.transparent,
                  border: on
                      ? null
                      : Border.all(
                          color: isToday ? pal.accent : pal.hair,
                          width: isToday ? 1.6 : 1.0),
                  boxShadow: on
                      ? [
                          BoxShadow(
                              color: pal.accent.withOpacity(0.45),
                              blurRadius: 10)
                        ]
                      : const <BoxShadow>[],
                ),
                child: on
                    ? Icon(Icons.check_rounded, size: 15, color: pal.onAccent)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                      color: isToday ? pal.accent : pal.muted)),
            ]);
          }),
        ),
      ]),
    );
  }
}

// ── ranked lifting entry ─────────────────────────
class _FitStrength extends ConsumerWidget {
  final _FitPal pal;
  final L l;
  const _FitStrength({required this.pal, required this.l});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(liftLogProvider);
    final rank = log.overall;
    final ranked = log.bests.length;
    return PressFx(
      onTap: () => context.push('/lift'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: rank.color.withOpacity(0.40), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: rank.color.withOpacity(0.16),
                blurRadius: 22,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          RankBadge(rank: rank, size: 58, arabic: l.isAr),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.strengthCardTitle,
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: pal.text)),
                const SizedBox(height: 4),
                Text(
                    ranked == 0
                        ? l.notRankedYet
                        : '${rank.label(arabic: l.isAr)} · '
                            '$ranked/${kLiftExercises.length} '
                            '${l.liftsRanked}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: pal.muted)),
                const SizedBox(height: 10),
                AnimatedBar(
                  value: rank.divisionProgress,
                  color: rank.color,
                  background: pal.track,
                  height: 7,
                  radius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: rank.color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
                pal.isAr
                    ? Icons.arrow_back_ios_new_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 14,
                color: rank.color),
          ),
        ]),
      ),
    );
  }
}

// ── recommended hero ─────────────────────────────
class _FitHero extends StatelessWidget {
  final Workout w;
  final _FitPal pal;
  final bool done;
  final String? iconPath;
  final VoidCallback onTap;
  final String Function(String, String) t;
  const _FitHero({
    required this.w, required this.pal, required this.done,
    required this.iconPath, required this.onTap, required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final colors = pal.heroColors;
    final disc = Color.alphaBlend(
        Colors.white.withOpacity(0.16), Color.lerp(colors[0], colors[1], 0.55)!);
    final playInk = pal.ram ? AppColors.ramadanNight : const Color(0xFF145C32);
    final Widget icon = iconPath != null
        ? darkSafeAsset(iconPath!,
            width: 72,
            height: 72,
            fit: BoxFit.contain,
            isDark: pal.isDark,
            plateColor: disc,
            errorChild: EmojiIcon(w.emoji, size: 46))
        : EmojiIcon(w.emoji, size: 46);

    Widget meta(IconData ic, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          Text(s,
              style: const TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70)),
        ]);

    return PressFx(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        height: 152,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: pal.glow.withOpacity(0.40),
                blurRadius: 28,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(children: [
          PositionedDirectional(
            end: -34,
            top: -46,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06)),
            ),
          ),
          PositionedDirectional(
            start: -24,
            bottom: -56,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                          done
                              ? t('✨ أحسنت! جلسة إضافية؟', '✨ Goal done! Bonus session?')
                              : t('⚡ موصى به الآن', '⚡ Recommended now'),
                          style: const TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                    const SizedBox(height: 10),
                    Text(pal.isAr ? w.titleAr : w.titleEn,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        meta(Icons.timer_outlined,
                            '${w.durationMin} ${t("دقيقة", "min")}'),
                        meta(Icons.signal_cellular_alt_rounded,
                            pal.isAr ? w.level : w.levelEn),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: disc,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.30), width: 1.2),
                      ),
                      child: ClipOval(child: Center(child: icon)),
                    ),
                  ),
                  PositionedDirectional(
                    end: -6,
                    bottom: -6,
                    child: PulseGlow(
                      color: Colors.white,
                      minOpacity: 0.10,
                      maxOpacity: 0.45,
                      blur: 16,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 10,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            color: playInk, size: 26),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── pinned filter chips ──────────────────────────
class _FitPinned extends SliverPersistentHeaderDelegate {
  final double height;
  final Color bg;
  final Widget child;
  const _FitPinned(
      {required this.height, required this.bg, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: overlaps ? bg.withOpacity(0.94) : Colors.transparent,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _FitPinned old) => true;
}

class _FitChips extends StatelessWidget {
  final _FitPal pal;
  final List<String> cats;
  final String selected;
  final Map<String, int> counts;
  final Map<String, String> labels;
  final ValueChanged<String> onPick;
  const _FitChips({
    required this.pal, required this.cats, required this.selected,
    required this.counts, required this.labels, required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cats[i];
          final sel = c == selected;
          final fg = sel ? pal.onAccent : pal.text.withOpacity(0.82);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onPick(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: sel
                    ? LinearGradient(colors: [
                        Color.lerp(pal.accent, Colors.white, 0.18)!,
                        pal.accent,
                      ])
                    : null,
                color: sel ? null : pal.text.withOpacity(0.06),
                border: Border.all(
                    color: sel ? Colors.transparent : pal.hair, width: 0.8),
                boxShadow: sel
                    ? [
                        BoxShadow(
                            color: pal.accent.withOpacity(0.38),
                            blurRadius: 14,
                            offset: const Offset(0, 4)),
                      ]
                    : const <BoxShadow>[],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_fitCatIcon(c),
                    size: 16, color: sel ? pal.onAccent : pal.muted),
                const SizedBox(width: 6),
                Text(labels[c] ?? c,
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: fg)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: sel
                        ? pal.onAccent.withOpacity(0.18)
                        : pal.text.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${counts[c] ?? 0}',
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: fg)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _FitSection extends StatelessWidget {
  final _FitPal pal;
  final String title;
  final int count;
  const _FitSection(
      {required this.pal, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Row(children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [pal.accent, AppColors.accentGold],
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: pal.text)),
        ),
        Text('$count',
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: pal.muted)),
      ]),
    );
  }
}

// ── workout card ─────────────────────────────────
class _FitCard extends StatelessWidget {
  final Workout w;
  final _FitPal pal;
  final bool locked;
  final String? iconPath;
  final VoidCallback onTap;
  final String Function(String, String) t;
  const _FitCard({
    required this.w, required this.pal, required this.locked,
    required this.iconPath, required this.onTap, required this.t,
  });

  Widget _meta(IconData ic, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 14, color: pal.muted),
        const SizedBox(width: 4),
        Text(s,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pal.muted)),
      ]);

  @override
  Widget build(BuildContext context) {
    final lc = _fitHex(w.levelColor);
    final zone = Color.alphaBlend(
        pal.accent.withOpacity(pal.isDark ? 0.09 : 0.06), pal.card);
    return PressFx(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: locked
                  ? pal.hair
                  : pal.accent.withOpacity(pal.isDark ? 0.30 : 0.20),
              width: 1.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(pal.isDark ? 0.30 : 0.07),
                blurRadius: 18,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 112,
            color: zone,
            child: Stack(children: [
              Center(
                child: iconPath != null
                    ? darkSafeAsset(iconPath!,
                        width: 84,
                        height: 84,
                        fit: BoxFit.contain,
                        isDark: pal.isDark,
                        plateColor: zone,
                        errorChild: EmojiIcon(w.emoji, size: 48))
                    : EmojiIcon(w.emoji, size: 48),
              ),
              PositionedDirectional(
                top: 10,
                start: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lc.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: lc, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(pal.isAr ? w.level : w.levelEn,
                        style: TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: lc)),
                  ]),
                ),
              ),
              if (locked)
                PositionedDirectional(
                  top: 10,
                  end: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.gradientGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_rounded, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text('PRO',
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                    ]),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pal.isAr ? w.titleAr : w.titleEn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                          height: 1.25,
                          color: pal.text)),
                  const Spacer(),
                  Row(children: [
                    _meta(Icons.timer_outlined,
                        '${w.durationMin}${t("د", "m")}'),
                    const Spacer(),
                    if (w.steps.isNotEmpty)
                      _meta(Icons.format_list_numbered_rounded,
                          '${w.steps.length}'),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── premium upsell ───────────────────────────────
class _FitUpsell extends StatelessWidget {
  final _FitPal pal;
  final int count;
  final VoidCallback onTap;
  final String Function(String, String) t;
  const _FitUpsell({
    required this.pal, required this.count, required this.onTap,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return PressFx(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: pal.ram
                ? [AppColors.ramadanCardAlt, AppColors.ramadanCard]
                : const [Color(0xFF1A6B3C), AppColors.brandGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: pal.glow.withOpacity(0.30),
                blurRadius: 18,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('$count خطة متقدمة', '$count advanced plans'),
                    style: const TextStyle(
                        fontFamily: 'Aligarh',
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                    t('HIIT • كارديو • تناسق • قوة كاملة',
                        'HIIT • Cardio • Toning • Full strength'),
                    style: const TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 11,
                        color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.accentGold,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(t('ترقية', 'Upgrade'),
                style: const TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 12.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}


// ══════════════════════════════════════════════════
//  WorkoutPlayerScreen — Step-by-step exercise timer
// ══════════════════════════════════════════════════
class WorkoutPlayerScreen extends ConsumerStatefulWidget {
  final String workoutId;
  const WorkoutPlayerScreen({super.key, required this.workoutId});
  @override ConsumerState<WorkoutPlayerScreen> createState() => _WorkoutPlayerState();
}

class _WorkoutPlayerState extends ConsumerState<WorkoutPlayerScreen>
    with SingleTickerProviderStateMixin {
  Timer?  _timer;
  int     _elapsed   = 0;
  int     _stepIndex = 0;
  bool    _running   = false;
  bool    _done      = false;
  late AnimationController _pulse;

  Workout? get _workout =>
      kWorkouts.firstWhere((w) => w.id == widget.workoutId, orElse: () => kWorkouts.first);

  bool get _hasSteps => (_workout?.steps.isNotEmpty) ?? false;

  List<WorkoutStep> get _steps => _workout?.steps ?? [];
  WorkoutStep?      get _currentStep =>
      _hasSteps && _stepIndex < _steps.length ? _steps[_stepIndex] : null;

  int get _stepDuration => _currentStep?.durationSec ?? 30;
  int get _totalSeconds  => (_workout?.durationMin ?? 10) * 60;

  int get _overallElapsed {
    if (!_hasSteps) return _elapsed;
    int total = 0;
    for (int i = 0; i < _stepIndex && i < _steps.length; i++) {
      total += _steps[i].durationSec > 0 ? _steps[i].durationSec : 30;
    }
    return total + _elapsed;
  }

  double get _overallProgress =>
      _totalSeconds > 0 ? (_overallElapsed / _totalSeconds).clamp(0.0, 1.0) : 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900), lowerBound: 0.95, upperBound: 1.0)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_done) return;
    setState(() => _running = !_running);
    if (_running) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _elapsed++;
          // Step-based progression
          if (_hasSteps && _currentStep != null) {
            if (_currentStep!.durationSec > 0 && _elapsed >= _currentStep!.durationSec) {
              _nextStep();
            }
          } else if (_elapsed >= _totalSeconds) {
            _finish();
          }
        });
      });
    } else {
      _timer?.cancel();
    }
  }

  void _nextStep() {
    if (_stepIndex < _steps.length - 1) {
      _stepIndex++;
      _elapsed = 0;
    } else {
      _finish();
    }
  }

  void _finish() {
    _timer?.cancel();
    _running = false;
    _done    = true;
    final w = _workout;
    if (w != null) {
      ref.read(streakProvider.notifier).increment();
      ref.read(workoutMinutesProvider.notifier).add(w.id, w.durationMin);
    }
  }

  String _fmt(int secs) { final m = (secs ~/ 60).toString().padLeft(2,'0'); final s = (secs % 60).toString().padLeft(2,'0'); return'$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final w     = _workout;
    final lang      = ref.watch(languageProvider);
    final isAr      = lang == 'ar' || lang == 'ur';
    final isDark    = ref.watch(themeProvider); if (w == null) return const Scaffold(body: Center(child: Text('Not found')));
            final isSis = ref.watch(genderProvider) == 'sisters';
    final isRamadan = ref.watch(ramadanModeProvider);

    final bg   = isDark ? AppColors.darkBg   : AppColors.lightBg;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    String t(String ar, String en) => tLang(lang, ar, en);

    final step = _currentStep;
    final rem  = _hasSteps
        ? (step?.durationSec ?? 30) - _elapsed
        : (_totalSeconds - _elapsed);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: Text(isAr ? w.titleAr : w.titleEn, style: const TextStyle(fontFamily:'Aligarh', fontSize: 14,
                  fontWeight: FontWeight.w700)),
          backgroundColor: isRamadan ? AppColors.ramadanCard : AppColors.brandGreen,
        ),
        body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [

          // ── Overall progress bar ──────────────────────────
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(t('التقدم الكلي', 'Overall Progress'), style: TextStyle(fontFamily:'Aligarh', fontSize: 11, color: muted)), Text('${(_overallProgress * 100).toInt()}％', style: TextStyle(fontFamily:'Aligarh', fontSize: 11,
                        fontWeight: FontWeight.w700, color: AppColors.brandGreen)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                value: _overallProgress, minHeight: 7,
                backgroundColor: AppColors.brandGreen.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(AppColors.brandGreen),
              )),
            ]),
          ),

          // ── Illustration (PATCH_V25: solid plate, no checkerboard)
          Builder(builder: (_) {
            final iconPath = workoutIconAsset(w.id, isSis);
            return Container(
              width: 140, height: 140,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A2E22)
                    : const Color(0xFFE8F5EC),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: (isRamadan ? AppColors.ramadanGold : AppColors.brandGreen)
                      .withOpacity(0.25),
                ),
              ),
              child: Center(
                // PATCH_V30_DARKSAFE_PLATE_COLOR: plate matches this container's own
                // flat 0xFF1A2E22 fill exactly, so it truly disappears.
                child: iconPath != null
                    ? darkSafeAsset(iconPath,
                        width: 100, height: 100, fit: BoxFit.contain,
                        isDark: isDark,
                        plateColor: const Color(0xFF1A2E22),
                        errorChild: EmojiIcon(w.emoji, size: 56))
                    : EmojiIcon(w.emoji, size: 56),
              ),
            );
          }),

          // Step name
          if (_hasSteps && step != null && !_done)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                key: ValueKey(_stepIndex),
                isAr ? step.nameAr : step.nameEn,
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 18,
                    fontWeight: FontWeight.w800, color: text, height: 1.3),
              ),
            ),
          if (!_hasSteps)
            Text(isAr ? w.titleAr : w.titleEn, textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 16,
                    fontWeight: FontWeight.w700, color: text)),

          // Step instruction
          if (_hasSteps && step?.instructionAr != null && !_done) ...[
            const SizedBox(height: 8),
            Text(isAr ? step!.instructionAr! : (step!.instructionEn ?? step.instructionAr!),
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 13,
                    color: muted, height: 1.5)),
          ],

          const SizedBox(height: 24),

          // ── Circle timer ──────────────────────────────────
          SizedBox(width: 200, height: 200, child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(
              value: _done ? 1.0 : _overallProgress,
              strokeWidth: 10,
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(
                  _done ? AppColors.accentGold : AppColors.brandGreen),
              strokeCap: StrokeCap.round,
            )),
            if (_hasSteps && step != null && !_done)
              SizedBox.expand(child: Padding(
                padding: const EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  value: step.durationSec > 0
                      ? (_elapsed / step.durationSec).clamp(0.0, 1.0)
                      : 0,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation(AppColors.accentGold),
                  strokeCap: StrokeCap.round,
                ),
              )),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_done) const EmojiIcon('🎉', size: 44)
              else ...[
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Transform.scale(
                    scale: _running ? _pulse.value : 1.0,
                    child: Text(
                      _hasSteps && step?.durationSec == 0 ?'${step?.reps ?? 0}\n${t("مرة","reps")}': _fmt(rem.clamp(0, 9999)),
                      textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 36,
                          fontWeight: FontWeight.w900, color: text, height: 1.1),
                    ),
                  ),
                ), Text(_hasSteps ? t('للخطوة','for step') : t('متبقي','remaining'), style: TextStyle(fontFamily:'Aligarh', fontSize: 12, color: muted)),
              ],
            ]),
          ])),

          const SizedBox(height: 24),

          // ── Step progress dots ────────────────────────────
          if (_hasSteps && !_done)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < _steps.length; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _stepIndex ? 24 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: i < _stepIndex
                        ? AppColors.halalGreen
                        : i == _stepIndex
                            ? AppColors.brandGreen
                            : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (i < _steps.length - 1) const SizedBox(width: 4),
              ],
            ]),

          const SizedBox(height: 24),

          // ── Coaching note ─────────────────────────────────
          if (w.note != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentGold.withOpacity(isDark ? 0.1 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentGold.withOpacity(0.3)),
              ),
              child: Text( '💡 ${isAr ? w.note! : (w.noteEn ?? w.note!)}',
                textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 12,
                    color: AppColors.accentGold, fontStyle: FontStyle.italic, height: 1.6),
              ),
            ),

          const SizedBox(height: 20),

          // ── Done screen ───────────────────────────────────
          if (_done) ...[
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
              ),
              child: Column(children: [ const EmojiIcon('🌟', size: 52),
                const SizedBox(height: 12), Text(t('أحسنت!', 'Well done!'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 22,
                        fontWeight: FontWeight.w900, color: AppColors.brandGreen)),
                const SizedBox(height: 6), Text(t('أتممت ${w.durationMin} دقيقة من ${isAr ? w.titleAr : w.titleEn}', 'Completed ${w.durationMin} min of ${isAr ? w.titleAr : w.titleEn}'),
                    textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 13, color: muted, height: 1.5)),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () => context.pop(), child: Text(t('رجوع للتمارين', 'Back to Workouts'), style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
          ] else ...[
            // ── Controls ──────────────────────────────────
            Row(children: [
              Expanded(child: ElevatedButton(
                onPressed: _toggle,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text( _running ? t('⏸ إيقاف', '⏸ Pause') : t('▶ ابدأ', '▶ Start'), style: const TextStyle(fontFamily:'Aligarh',
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              )),
              const SizedBox(width: 12),
              if (_hasSteps && _stepIndex < _steps.length - 1)
                Expanded(child: OutlinedButton(
                  onPressed: () => setState(() { _nextStep(); }),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(t('⏭ التالي', '⏭ Next'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 14)),
                ))
              else
                Expanded(child: OutlinedButton(
                  onPressed: () { _timer?.cancel(); _finish(); setState(() {}); },
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(t('✓ أكملت', '✓ Done'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 14)),
                )),
            ]),
          ],

          const SizedBox(height: 20),
        ])),
      ),
    );
  }
}

