// health_screen.dart — HalalCalorie v1.0 — Bilingual
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';
import '../../core/num_input.dart';
import '../../data/models/models.dart';
import '../../core/health_service.dart';
import '../../data/icon_assets.dart';
import '../../core/fx6.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/fx2.dart';
import '../../core/fx4.dart';
import '../../core/fx7.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});
  @override ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String get lang => ref.read(languageProvider);
  late TabController _tab;
  String? _expandedArticle;
  bool _stepServiceRunning = false;
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  late AnimationController _stagger;
  Animation<double> _fade(int i) => CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.1, (i * 0.1 + 0.5).clamp(0,1), curve: Curves.easeOutQuart));
  Animation<Offset> _slide(int i) => Tween<Offset>(
      begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.1, (i * 0.1 + 0.5).clamp(0,1), curve: Curves.easeOutQuart)));
  Widget _anim(int i, Widget child) => FadeTransition(
      opacity: _fade(i), child: SlideTransition(position: _slide(i), child: child));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      setState(() {});
      _stagger.forward(from: 0);
    });
    _startStepService();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 650))
      ..forward();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    HealthService.onAppStateChange(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tab.dispose();
    _stagger.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _startStepService() async {
    // The tracker outlives this screen; here it may ask for the permission.
    await ref.read(stepTrackerProvider).ensureStarted();
    if (mounted) setState(() => _stepServiceRunning = true);
  }


  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final lang   = ref.watch(languageProvider);
    final isAr   = lang == 'ar' || lang == 'ur';
    String t(String ar, String en) => tLang(lang, ar, en);

    final bg    = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned.fill(
          child: AuroraBackground(
            base: bg,
            colors: const [
              Color(0xFF1E9E52), Color(0xFF6FB3FF), Color(0xFFBC8CFF),
            ],
            intensity: isDark ? 0.50 : 0.26,
            seconds: 24,
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
              child: Row(children: [
                Expanded(
                  child: Text(t('الصحة والعافية', 'Health & Wellness'),
                      style: TextStyle(
                          fontFamily: lang == 'ar' ? 'LemonBrush' : 'Bravoon',
                          fontWeight: FontWeight.w400,
                          fontSize: 28,
                          color: textC)),
                ),
                GlassIconBtn(
                  isDark: isDark,
                  icon: isDark
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  onTap: () => ref.read(themeProvider.notifier).toggle(),
                ),
              ]),
            ),
            SegTabs(
              controller: _tab,
              accent: AppColors.brandGreen,
              onAccent: Colors.white,
              textColor: textC,
              mutedColor: muted,
              labels: [
                t('تتبع', 'Tracking'),
                t('حاسبات', 'Calculators'),
                t('مقالات', 'Articles'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildTrack(isAr, isDark),
                  _buildCalc(isAr, isDark),
                  _buildArticles(isAr, isDark),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── TRACKING TAB ──────────────────────────────────────────
  Widget _buildTrack(bool isAr, bool isDark) {
    final water  = ref.watch(waterProvider);
    final sleep  = ref.watch(sleepProvider);
    final health = ref.watch(healthProvider);
    final textC  = isDark ? AppColors.darkText : AppColors.lightText;

    Widget title(String s, Color c) =>
        SectionTitle(title: s, textColor: textC, accent: c);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        _anim(0, _healthScoreCard(water, sleep, health, isAr, isDark)),
        const SizedBox(height: 22),
        _anim(1, title(isAr ? 'الماء اليومي' : 'Daily Water', AppColors.waterBlue)),
        const SizedBox(height: 12),
        _anim(1, _waterCard(water, isAr, isDark)),
        const SizedBox(height: 22),
        _anim(2, title(isAr ? 'النوم' : 'Sleep', AppColors.sleepPurple)),
        const SizedBox(height: 12),
        _anim(2, _sleepCard(sleep, isAr, isDark)),
        const SizedBox(height: 22),
        _anim(3, title(isAr ? 'خطوات اليوم' : 'Today Steps', AppColors.halalGreen)),
        const SizedBox(height: 12),
        _anim(3, _stepsCard(health, isAr, isDark)),
        const SizedBox(height: 22),
        _anim(4, title(isAr ? 'مزاجك اليومي' : 'Today Mood', AppColors.accentGold)),
        const SizedBox(height: 12),
        _anim(4, _moodCard(health, isAr, isDark)),
        const SizedBox(height: 22),
        _anim(5, title(isAr ? 'معدل النبض' : 'Heart Rate', AppColors.haramRed)),
        const SizedBox(height: 12),
        _anim(5, _hrCard(health, isAr, isDark)),
      ],
    );
  }

  Widget _healthScoreCard(WaterState water, SleepState sleep,
      HealthState health, bool isAr, bool isDark) {
    final lang  = ref.watch(languageProvider);
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;

    final wScore  = (water.percent * 25).clamp(0.0, 25.0);
    final slScore = (sleep.percent * 25).clamp(0.0, 25.0);
    final stScore = ((health.steps / health.stepsGoal) * 25).clamp(0.0, 25.0);
    final mScore  = health.mood != null ? 25.0 : 0.0;
    final total   = (wScore + slScore + stScore + mScore).round();

    final Color sc = total >= 80
        ? AppColors.halalGreen
        : (total >= 50 ? AppColors.doubtOrange : AppColors.haramRed);

    final l = L.fromLang(lang);
    final String scoreLabel = total >= 80
        ? l.scoreExcellent
        : (total >= 60
            ? l.scoreVeryGood
            : (total >= 40 ? l.scoreGood : l.scoreKeepGoing));

    Widget scoreRow(IconData icon, String label, double score, Color col) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(children: [
            Icon(icon, size: 16, color: col),
            const SizedBox(width: 8),
            SizedBox(
              width: 58,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 11, color: muted)),
            ),
            Expanded(
              child: AnimatedBar(
                value: (score / 25).clamp(0.0, 1.0),
                color: col,
                background: col.withOpacity(0.14),
                height: 7,
                radius: 5,
              ),
            ),
            const SizedBox(width: 8),
            Text('${score.toInt()}',
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: col)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF15281E) : Colors.white,
            Color.lerp(isDark ? const Color(0xFF0E1C15) : const Color(0xFFF2F7F3),
                sc, isDark ? 0.10 : 0.07)!,
          ],
        ),
        border: Border.all(color: sc.withOpacity(0.30), width: 0.9),
        boxShadow: [
          BoxShadow(
              color: sc.withOpacity(isDark ? 0.22 : 0.14),
              blurRadius: 28,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(children: [
        Row(children: [
          HeroRing(
            pct: total / 100,
            ringAnim: _stagger,
            color: sc,
            eaten: total,
            isDark: isDark,
            muted: muted,
            label: isAr ? 'من 100' : 'of 100',
            size: 132,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.dailyHealthScore,
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textC)),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: sc.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(scoreLabel,
                        style: TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: sc)),
                  ),
                ]),
          ),
        ]),
        const SizedBox(height: 16),
        scoreRow(Icons.water_drop_rounded, l.water, wScore, AppColors.waterBlue),
        scoreRow(Icons.bedtime_rounded, l.sleepLabel, slScore, AppColors.sleepPurple),
        scoreRow(Icons.directions_walk_rounded, l.stepsLabel, stScore, AppColors.halalGreen),
        scoreRow(Icons.mood_rounded, l.moodLabel, mScore, AppColors.accentGold),
      ]),
    );
  }

  Widget _pillBtn(String label, IconData icon, Color color,
      VoidCallback onTap, {bool filled = false}) {
    return PressFx(
      onTap: onTap,
      scale: 0.95,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: filled
              ? LinearGradient(colors: [Color.lerp(color, Colors.white, 0.2)!, color])
              : null,
          color: filled ? null : color.withOpacity(0.12),
          border: Border.all(
              color: color.withOpacity(filled ? 0.0 : 0.4), width: 0.8),
          boxShadow: filled
              ? [BoxShadow(color: color.withOpacity(0.38), blurRadius: 14)]
              : const [],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 19, color: filled ? Colors.white : color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: filled ? Colors.white : color)),
          ),
        ]),
      ),
    );
  }

  Widget _waterCard(WaterState water, bool isAr, bool isDark) {
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    const c = AppColors.waterBlue;

    return _card(c, isDark, Column(children: [
      Row(children: [
        VitalGlyph(kind: VitalKind.water, pct: water.percent, color: c, size: 88),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      CountUp(
                          value: water.cups,
                          style: const TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              color: c)),
                      const SizedBox(width: 6),
                      Text(
                          '/ ${water.goal} ${isAr ? "أكواب" : "cups"}',
                          style: TextStyle(
                              fontFamily: 'Aligarh', fontSize: 14, color: muted)),
                    ]),
                const SizedBox(height: 4),
                Text(
                    '${(water.cups * 0.25).toStringAsFixed(2)} ${isAr ? "لتر" : "L"}  •  ${(water.percent * 100).toInt()}％',
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: c.withOpacity(0.9))),
              ]),
        ),
      ]),
      const SizedBox(height: 14),
      Wrap(
        spacing: 5,
        runSpacing: 5,
        alignment: WrapAlignment.center,
        children: List.generate(water.goal, (i) {
          final on = i < water.cups;
          return GestureDetector(
            onTap: () => ref.read(waterProvider.notifier).set(i + 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: 34,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: on ? c.withOpacity(0.20) : muted.withOpacity(0.08),
                border: Border.all(
                    color: on ? c.withOpacity(0.55) : Colors.transparent,
                    width: 0.9),
              ),
              child: Icon(Icons.water_drop_rounded,
                  size: on ? 22 : 18,
                  color: on ? c : muted.withOpacity(0.45)),
            ),
          );
        }),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _pillBtn(
              tLang(lang, 'كوب -', '- Cup', '- Verre', '- Bardak', '- Cawan', '- Gelas'),
              Icons.remove_rounded, c,
              () => ref.read(waterProvider.notifier).remove()),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _pillBtn(
              tLang(lang, '+ كوب', '+ Cup', '+ Verre', '+ Bardak', '+ Cawan', '+ Gelas'),
              Icons.add_rounded, c,
              () => ref.read(waterProvider.notifier).add(),
              filled: true),
        ),
      ]),
    ]));
  }

  Widget _sleepCard(SleepState sleep, bool isAr, bool isDark) {
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    const c = AppColors.sleepPurple;
    final IconData face = sleep.hours >= 8
        ? Icons.sentiment_very_satisfied_rounded
        : (sleep.hours >= 6
            ? Icons.sentiment_neutral_rounded
            : Icons.sentiment_very_dissatisfied_rounded);

    return _card(c, isDark, Column(children: [
      Row(children: [
        VitalGlyph(kind: VitalKind.sleep, pct: sleep.percent, color: c, size: 88),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      CountUp(
                          value: sleep.hours.toInt(),
                          style: const TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              color: c)),
                      const SizedBox(width: 6),
                      Text(isAr ? 'ساعات' : 'hours',
                          style: TextStyle(
                              fontFamily: 'Aligarh', fontSize: 14, color: muted)),
                    ]),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(face, size: 20, color: c),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(isAr ? sleep.qualityAr() : sleep.qualityEn(),
                        style: const TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c)),
                  ),
                ]),
              ]),
        ),
      ]),
      const SizedBox(height: 16),
      Row(
        children: [4, 5, 6, 7, 8, 9, 10].map((h) {
          final on = sleep.hours >= h;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(sleepProvider.notifier).set(h.toDouble()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: on
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.lerp(c, Colors.white, 0.25)!, c])
                      : null,
                  color: on ? null : muted.withOpacity(0.10),
                  boxShadow: on
                      ? [BoxShadow(color: c.withOpacity(0.35), blurRadius: 10)]
                      : const [],
                ),
                child: Center(
                  child: Text('$h',
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: on ? Colors.white : muted)),
                ),
              ),
            ),
          );
        }).toList(),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
            '${tLang(lang, 'الهدف', 'Goal')}: '
            '${sleep.goal.toInt()} ${tLang(lang, 'ساعات', 'hours')}',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted)),
      ),
    ]));
  }

  Widget _stepsCard(HealthState health, bool isAr, bool isDark) {
    final muted    = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final pct      = (health.steps / health.stepsGoal).clamp(0.0, 1.0);
    final kcalBurn = (health.steps * 0.04).toInt();
    final distKm   = health.steps * 0.00076;
    final distStr  = distKm >= 1
        ? '${distKm.toStringAsFixed(2)}${isAr ? " كم" : " km"}'
        : '${(distKm * 1000).toInt()}${isAr ? " م" : " m"}';
    const c = AppColors.halalGreen;

    return _card(c, isDark, Column(children: [
      Row(children: [
        HeroRing(
          pct: pct,
          ringAnim: _stagger,
          color: c,
          eaten: health.steps,
          isDark: isDark,
          muted: muted,
          label: '/ ${health.stepsGoal} ${isAr ? "خطوة" : "steps"}',
          size: 150,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(children: [
            if (_stepServiceRunning)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: c.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                      tLang(lang, 'مباشر', 'LIVE', 'EN DIRECT', 'CANLI', 'LANGSUNG', 'LANGSUNG'),
                      style: const TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: c)),
                ]),
              )
            else
              PressFx(
                onTap: _startStepService,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_arrow_rounded,
                        size: 16, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                        tLang(lang, 'تشغيل', 'Start', 'Démarrer', 'Başlat', 'Mula', 'Mulai'),
                        style: const TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange)),
                  ]),
                ),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: StatTile(
                    icon: Icons.map_rounded,
                    value: distStr,
                    label: tLang(lang, 'مسافة', 'Distance', 'Distance', 'Mesafe', 'Jarak', 'Jarak'),
                    color: AppColors.waterBlue,
                    isDark: isDark),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: StatTile(
                    icon: Icons.local_fire_department_rounded,
                    value: '$kcalBurn',
                    label: tLang(lang, 'سعرة', 'kcal', 'kcal', 'kcal', 'kcal', 'kkal'),
                    color: AppColors.haramRed,
                    isDark: isDark),
              ),
            ]),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
            tLang(lang, 'ضبط يدوي', 'Manual adjust', 'Ajustement manuel', 'Manuel ayar', 'Laraskan manual', 'Sesuaikan manual'),
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted)),
      ),
      const SizedBox(height: 8),
      Row(
        children: [1000, 3000, 5000].map((n) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _pillBtn('+$n', Icons.directions_walk_rounded, c,
                () => ref.read(healthProvider.notifier).addSteps(n)),
          ),
        )).toList(),
      ),
    ]));
  }

  Widget _moodCard(HealthState health, bool isAr, bool isDark) {
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final moods = isAr
        ? kMoodFacesAr.map((m) => [m['asset']!, m['label']!]).toList()
        : kMoodFacesEn.map((m) => [m['asset']!, m['label']!]).toList();
    const c = AppColors.accentGold;

    return _card(c, isDark, Column(children: [
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: moods.map((m) {
          final on = health.mood == m[1];
          return GestureDetector(
            onTap: () => ref.read(healthProvider.notifier).setMood(m[1]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: 72,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: on
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.withOpacity(0.28), c.withOpacity(0.06)])
                    : null,
                color: on ? null : muted.withOpacity(0.06),
                border: Border.all(
                    color: on ? c : Colors.transparent, width: 1.4),
                boxShadow: on
                    ? [BoxShadow(color: c.withOpacity(0.30), blurRadius: 14)]
                    : const [],
              ),
              child: Column(children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  scale: on ? 1.18 : 1.0,
                  child: darkSafeAsset(m[0],
                      width: 30,
                      height: 30,
                      isDark: isDark,
                      errorChild: const EmojiIcon('🙂', size: 28)),
                ),
                const SizedBox(height: 5),
                Text(m[1],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 10,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                        color: on ? c : muted)),
              ]),
            ),
          );
        }).toList(),
      ),
      if (health.mood != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
              tLang(lang, 'سجلت مزاجك: ${health.mood}', 'Mood recorded: ${health.mood}'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c)),
        ),
    ]));
  }

  Widget _hrCard(HealthState health, bool isAr, bool isDark) {
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final hrCol = health.heartRate > 100
        ? AppColors.haramRed
        : (health.heartRate < 60 ? AppColors.waterBlue : AppColors.halalGreen);
    final hrLbl = isAr
        ? (health.heartRate > 100 ? 'مرتفع' : (health.heartRate < 60 ? 'منخفض' : 'طبيعي'))
        : (health.heartRate > 100 ? 'High' : (health.heartRate < 60 ? 'Low' : 'Normal'));
    final hrPct = ((health.heartRate - 40) / 120).clamp(0.0, 1.0);

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
                      CountUp(
                          value: health.heartRate,
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              color: hrCol)),
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
                    tLang(lang, 'المعدل الطبيعي: 60-100', 'Normal: 60-100 bpm'),
                    style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 11, color: muted)),
              ]),
        ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
          child: _pillBtn('−1', Icons.remove_rounded, hrCol,
              () => ref.read(healthProvider.notifier)
                  .setHeartRate(health.heartRate - 1)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _pillBtn('+1', Icons.add_rounded, hrCol,
              () => ref.read(healthProvider.notifier)
                  .setHeartRate(health.heartRate + 1)),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _pillBtn(
              tLang(lang, 'قياس', 'Measure', 'Mesurer', 'Ölç', 'Ukur', 'Ukur'),
              Icons.favorite_rounded, hrCol,
              () => ref.read(healthProvider.notifier)
                  .setHeartRate(60 + (DateTime.now().millisecond % 40)),
              filled: true),
        ),
      ]),
    ]));
  }

  // ── CALCULATORS TAB ───────────────────────────────────────
  Widget _buildCalc(bool isAr, bool isDark) {
    final health = ref.watch(healthProvider);
    final bmi    = health.quickBmi;
    final textC  = isDark ? AppColors.darkText : AppColors.lightText;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    const c = AppColors.halalGreen;

    // BMI scale: 15 .. 40 mapped to 0 .. 1
    final double pos = bmi == null ? 0.0 : ((bmi - 15) / 25).clamp(0.0, 1.0);

    final rows = <(IconData, String, String, int)>[
      (Icons.directions_walk_rounded, isAr ? 'مشي' : 'Walking', '~140', 140),
      (Icons.directions_run_rounded, isAr ? 'جري' : 'Running', '~300', 300),
      (Icons.pedal_bike_rounded, isAr ? 'دراجة' : 'Cycling', '~250', 250),
      (Icons.pool_rounded, isAr ? 'سباحة' : 'Swimming', '~220', 220),
      (Icons.self_improvement_rounded, isAr ? 'يوجا' : 'Yoga', '~120', 120),
      (Icons.fitness_center_rounded, isAr ? 'أثقال' : 'Weights', '~180', 180),
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Reveal(
          index: 0,
          child: SectionTitle(
              title: tLang(lang, 'حاسبة BMI', 'BMI Calculator', 'Calculateur IMC', 'VKİ Hesaplayıcı', 'Kalkulator BMI', 'Kalkulator IMT'),
              textColor: textC,
              accent: c),
        ),
        const SizedBox(height: 12),
        Reveal(
          index: 1,
          child: _card(c, isDark, Column(children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                      labelText: tLang(lang, 'الوزن (كجم)', 'Weight (kg)', 'Poids (kg)', 'Ağırlık (kg)', 'Berat (kg)', 'Berat (kg)'),
                      prefixIcon: const Icon(Icons.monitor_weight_rounded, size: 20),
                      hintText: '70'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                      labelText: tLang(lang, 'الطول (سم)', 'Height (cm)', 'Taille (cm)', 'Boy (cm)', 'Tinggi (cm)', 'Tinggi (cm)'),
                      prefixIcon: const Icon(Icons.height_rounded, size: 20),
                      hintText: '170'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            ShineButton(
              label: tLang(lang, 'احسب BMI', 'Calculate BMI', 'Calculer l\'IMC', 'VKİ Hesapla', 'Kira BMI', 'Hitung IMT'),
              icon: Icons.calculate_rounded,
              height: 50,
              colors: const [Color(0xFF3FB950), Color(0xFF1E9E52)],
              textColor: Colors.white,
              onPressed: () {
                FocusScope.of(context).unfocus();
                final w = parseDouble(_weightCtrl.text);
                final h = parseDouble(_heightCtrl.text);
                if (w != null && h != null && w > 0 && h > 0) {
                  ref.read(healthProvider.notifier).setBMI(w, h);
                }
              },
            ),
            if (bmi != null) ...[
              const SizedBox(height: 20),
              CountUp(
                  value: bmi,
                  decimals: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      color: _bmiColor(bmi))),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                    color: _bmiColor(bmi).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_bmiLabel(bmi, isAr),
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _bmiColor(bmi))),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (_, cons) {
                final w = cons.maxWidth;
                return SizedBox(
                  height: 30,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 12,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(colors: [
                            AppColors.waterBlue,
                            AppColors.halalGreen,
                            AppColors.doubtOrange,
                            AppColors.haramRed,
                          ], stops: [0.0, 0.3, 0.6, 1.0]),
                        ),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutBack,
                      left: (w - 20) * pos,
                      top: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: _bmiColor(bmi), width: 3.5),
                          boxShadow: [
                            BoxShadow(
                                color: _bmiColor(bmi).withOpacity(0.5),
                                blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ]),
                );
              }),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (final s in const ['15', '18.5', '25', '30', '40'])
                  Text(s,
                      style: TextStyle(
                          fontFamily: 'Aligarh', fontSize: 10, color: muted)),
              ]),
            ],
          ])),
        ),
        const SizedBox(height: 24),
        Reveal(
          index: 2,
          child: SectionTitle(
              title: tLang(lang, 'سعرات محروقة في 30 دقيقة', 'Calories Burned in 30 min', 'Calories brûlées en 30 min', '30 dakikada yakılan kalori', 'Kalori Dibakar dalam 30 min', 'Kalori Terbakar dalam 30 menit'),
              textColor: textC,
              accent: AppColors.haramRed),
        ),
        const SizedBox(height: 12),
        Reveal(
          index: 3,
          child: _card(AppColors.haramRed, isDark, Column(children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  IconBadge(icon: r.$1, color: AppColors.haramRed, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(r.$2,
                                    style: TextStyle(
                                        fontFamily: 'Aligarh',
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: textC)),
                                Text('${r.$3} ${isAr ? "سعرة" : "kcal"}',
                                    style: const TextStyle(
                                        fontFamily: 'Aligarh',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.haramRed)),
                              ]),
                          const SizedBox(height: 6),
                          AnimatedBar(
                            value: r.$4 / 300,
                            color: AppColors.haramRed,
                            background: AppColors.haramRed.withOpacity(0.12),
                            height: 6,
                            radius: 4,
                          ),
                        ]),
                  ),
                ]),
              ),
          ])),
        ),
      ],
    );
  }

  // ── ARTICLES TAB ──────────────────────────────────────────
  Widget _buildArticles(bool isAr, bool isDark) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    final list  = kHealthArticles.toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        Reveal(
          index: 0,
          child: SectionTitle(
              title: tLang(lang, 'مقالات صحية', 'Health Articles', 'Articles santé', 'Sağlık Makaleleri', 'Artikel Kesihatan', 'Artikel Kesehatan'),
              textColor: textC,
              accent: AppColors.accentGold),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 13, bottom: 14),
          child: Text(
              tLang(lang, 'اضغط على أي مقال للقراءة', 'Tap any article to read', 'Appuyez sur un article pour lire', 'Okumak için herhangi bir makaleye dokun', 'Ketuk mana-mana artikel untuk baca', 'Ketuk artikel mana saja untuk membaca'),
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 11.5, color: muted)),
        ),
        for (var i = 0; i < list.length; i++)
          Reveal(
            index: i < 8 ? i : 8,
            child: _articleCard(list[i], isDark, bg, muted, textC),
          ),
      ],
    );
  }

  Widget _articleCard(HealthArticle a, bool isDark, Color bg, Color muted, Color textC) {
    final isOpen   = _expandedArticle == a.id;
    final artColor = Color(a.colorValue);
    return PressFx(
      scale: 0.985,
      onTap: () => setState(() => _expandedArticle = isOpen ? null : a.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(bg, artColor, isDark ? 0.14 : 0.07)!,
              bg,
            ],
          ),
          border: Border.all(
              color: artColor.withOpacity(isOpen ? 0.55 : 0.26), width: 0.9),
          boxShadow: [
            BoxShadow(
                color: artColor.withOpacity(isOpen ? 0.24 : 0.10),
                blurRadius: isOpen ? 24 : 16,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [artColor.withOpacity(0.32), artColor.withOpacity(0.10)],
                ),
              ),
              child: Center(
                child: a.iconAsset != null
                    ? darkSafeAsset(healthArticleAsset(a.iconAsset!),
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        isDark: isDark,
                        plateColor: Color.alphaBlend(artColor.withOpacity(0.18), bg),
                        errorChild: EmojiIcon(a.icon, size: 22))
                    : EmojiIcon(a.icon, size: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title,
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: textC)),
                const SizedBox(height: 2),
                Text(a.summary,
                    maxLines: isOpen ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 11.5, height: 1.4, color: muted)),
              ]),
            ),
            AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 280),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 26, color: artColor),
            ),
          ]),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isOpen
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: artColor.withOpacity(isDark ? 0.10 : 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(a.body,
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 12.5,
                              height: 1.9,
                              color: textC)),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }

  // ── helpers ───────────────────────────────────────────────
  Widget _card(Color accent, bool isDark, Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          isDark ? const Color(0xFF15281E) : Colors.white,
          Color.lerp(isDark ? const Color(0xFF0E1C15) : const Color(0xFFF2F7F3),
              accent, isDark ? 0.09 : 0.06)!,
        ],
      ),
      border: Border.all(color: accent.withOpacity(0.28), width: 0.9),
      boxShadow: [
        BoxShadow(
            color: accent.withOpacity(isDark ? 0.18 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8)),
      ],
    ),
    child: child,
  );

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.waterBlue;
    if (bmi < 25)   return AppColors.halalGreen;
    if (bmi < 30)   return AppColors.doubtOrange;
    return AppColors.haramRed;
  }

  String _bmiLabel(double bmi, bool isAr) {
    if (isAr) {
      if (bmi < 18.5) return 'نقص وزن';
      if (bmi < 25)   return 'وزن مثالي';
      if (bmi < 30)   return 'زيادة وزن';
      return 'سمنة';
    } else {
      if (bmi < 18.5) return 'Underweight';
      if (bmi < 25)   return 'Normal';
      if (bmi < 30)   return 'Overweight';
      return 'Obese';
    }
  }
}
