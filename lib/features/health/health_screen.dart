// health_screen.dart — HalalCalorie v1.0 — Bilingual
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';
import '../../data/models/models.dart';
import '../../core/health_service.dart';

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
    HealthService.stopTracking();
    _tab.dispose();
    _stagger.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _startStepService() async {
    await HealthService.startStepTracking((steps) {
      if (!mounted) return;
      ref.read(healthProvider.notifier).setSteps(steps);
      if (!_stepServiceRunning)
        setState(() => _stepServiceRunning = true);
    });
    if (mounted) setState(() => _stepServiceRunning = true);
  }


  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final lang   = ref.watch(languageProvider);
    final isAr   = lang == 'ar' || lang == 'ur';
    String t(String ar, String en) => tLang(lang, ar, en);

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2A1A), Color(0xFF1A6B3C)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text(t('الصحة والعافية', 'Health & Wellness'),
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggle(),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accentGold,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: t('تتبع', 'Tracking')),
            Tab(text: t('حاسبات', 'Calculators')),
            Tab(text: t('مقالات', 'Articles')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildTrack(isAr, isDark),
          _buildCalc(isAr, isDark),
          _buildArticles(isAr, isDark),
        ],
      ),
    );
  }

  // ── TRACKING TAB ──────────────────────────────────────────
  Widget _buildTrack(bool isAr, bool isDark) {
    final water  = ref.watch(waterProvider);
    final sleep  = ref.watch(sleepProvider);
    final health = ref.watch(healthProvider);

    return ListView(padding: const EdgeInsets.all(14), children: [
      _anim(0, _healthScoreCard(water, sleep, health, isAr, isDark)),
      const SizedBox(height: 16),
      _anim(1, _sectionTitle('💧 ${isAr ? "الماء اليومي" : "Daily Water"}', isDark)),
      _anim(1, _waterCard(water, isAr, isDark)),
      const SizedBox(height: 16),
      _anim(2, _sectionTitle('😴 ${isAr ? "النوم" : "Sleep"}', isDark)),
      _anim(2, _sleepCard(sleep, isAr, isDark)),
      const SizedBox(height: 16),
      _anim(3, _sectionTitle('🚶 ${isAr ? "خطوات اليوم" : "Today Steps"}', isDark)),
      _anim(3, _stepsCard(health, isAr, isDark)),
      const SizedBox(height: 16),
      _anim(4, _sectionTitle('😊 ${isAr ? "مزاجك اليوم" : "Today Mood"}', isDark)),
      _anim(4, _moodCard(health, isAr, isDark)),
      const SizedBox(height: 16),
      _anim(5, _sectionTitle('❤️ ${isAr ? "معدل النبض" : "Heart Rate"}', isDark)),
      _anim(5, _hrCard(health, isAr, isDark)),
      const SizedBox(height: 14),
    ]);
  }

  Widget _healthScoreCard(WaterState water, SleepState sleep,
      HealthState health, bool isAr, bool isDark) {
    final lang = ref.watch(languageProvider);
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    final wScore  = (water.percent  * 25).clamp(0.0, 25.0);
    final slScore = (sleep.percent  * 25).clamp(0.0, 25.0);
    final stScore = ((health.steps / health.stepsGoal) * 25).clamp(0.0, 25.0);
    final mScore  = health.mood != null ? 25.0 : 0.0;
    final total   = (wScore + slScore + stScore + mScore).round();

    Color scoreColor() {
      if (total >= 80) return AppColors.halalGreen;
      if (total >= 50) return AppColors.doubtOrange;
      return AppColors.haramRed;
    }

    final l = L.fromLang(lang);
    String scoreLabel() {
      if (total >= 80) return l.scoreExcellent;
      if (total >= 60) return l.scoreVeryGood;
      if (total >= 40) return l.scoreGood;
      return l.scoreKeepGoing;
    }

    Widget scoreBar(String label, double score, double max, Color col) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted)),
            Text('${score.toInt()}/${max.toInt()}',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
                    fontWeight: FontWeight.w700, color: col)),
          ]),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: (score / max).clamp(0.0, 1.0),
            backgroundColor: col.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(col),
            borderRadius: BorderRadius.circular(4),
            minHeight: 7,
          ),
        ]),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 18, offset: const Offset(0, 5)),
          BoxShadow(color: scoreColor().withOpacity(0.08), blurRadius: 16, spreadRadius: 2),
        ],
      ),

      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Accent strip
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scoreColor(), scoreColor().withOpacity(0.3)]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(l.dailyHealthScore,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(scoreLabel(),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                    color: scoreColor())),
          ])),
          SizedBox(width: 80, height: 80,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox.expand(child: CircularProgressIndicator(
                value: total / 100,
                strokeWidth: 9,
                backgroundColor: scoreColor().withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(scoreColor()),
                strokeCap: StrokeCap.round,
              )),
              Text('$total',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 22,
                      fontWeight: FontWeight.w900, color: scoreColor())),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        scoreBar(l.water,      wScore, 25, AppColors.waterBlue),
        scoreBar(l.sleepLabel, slScore, 25, AppColors.sleepPurple),
        scoreBar(l.stepsLabel, stScore, 25, AppColors.halalGreen),
        scoreBar(l.moodLabel,  mScore, 25, AppColors.accentGold),
      ]),
    );
  }

  Widget _waterCard(WaterState water, bool isAr, bool isDark) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(children: [
            TextSpan(text: '${water.cups}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.waterBlue)),
            TextSpan(text: ' / ${water.goal} ${isAr ? "أكواب" : "cups"}',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
                    color: muted)),
          ])),
          Text('${(water.cups * 0.25).toStringAsFixed(2)} ${isAr ? "لتر" : "L"}',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted)),
        ]),
        Text('${(water.percent * 100).toInt()}%',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                fontSize: 13, color: AppColors.waterBlue)),
      ]),
      const SizedBox(height: 12),
      Wrap(
        spacing: 4, runSpacing: 4,
        children: List.generate(water.goal, (i) => GestureDetector(
          onTap: () => ref.read(waterProvider.notifier).set(i + 1),
          child: Text('💧',
              style: TextStyle(fontSize: 28,
                  color: i < water.cups ? null : Colors.grey.withOpacity(0.35))),
        )),
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
          value: water.percent.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.waterBlue),
          borderRadius: BorderRadius.circular(8),
          minHeight: 10),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => ref.read(waterProvider.notifier).remove(),
          style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.waterBlue,
              side: const BorderSide(color: AppColors.waterBlue)),
          child: Text(tLang(lang, 'كوب -', '- Cup', '- Verre', '- Bardak', '- Cawan', '- Gelas'),
              style: const TextStyle(fontFamily: 'Cairo')),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: () => ref.read(waterProvider.notifier).add(),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.waterBlue),
          child: Text(tLang(lang, '+ كوب', '+ Cup', '+ Verre', '+ Bardak', '+ Cawan', '+ Gelas'),
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        )),
      ]),
    ]));
  }

  Widget _sleepCard(SleepState sleep, bool isAr, bool isDark) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(children: [
            TextSpan(text: '${sleep.hours.toInt()}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sleepPurple)),
            TextSpan(text: ' ${isAr ? "ساعات" : "hours"}',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 14,
                    color: muted)),
          ])),
          Text(isAr ? sleep.qualityAr() : sleep.qualityEn(),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                  color: AppColors.sleepPurple)),
        ]),
        Text(sleep.hours >= 8 ? '😊' : sleep.hours >= 6 ? '😐' : '😞',
            style: const TextStyle(fontSize: 32)),
      ]),
      const SizedBox(height: 12),
      Row(children: [4, 5, 6, 7, 8, 9, 10].map((h) => Expanded(
        child: GestureDetector(
          onTap: () => ref.read(sleepProvider.notifier).set(h.toDouble()),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: sleep.hours >= h
                  ? AppColors.sleepPurple
                  : Colors.grey.shade200,
            ),
            child: Center(child: Text('$h',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sleep.hours >= h ? Colors.white : muted))),
          ),
        ),
      )).toList()),
      const SizedBox(height: 10),
      LinearProgressIndicator(
          value: sleep.percent,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.sleepPurple),
          borderRadius: BorderRadius.circular(8),
          minHeight: 10),
      Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Text(
            '${tLang(lang, 'الهدف', 'Goal')}: '
            '${sleep.goal.toInt()} ${tLang(lang, 'ساعات', 'hours')}',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: muted)),
      ),
    ]));
  }

  Widget _stepsCard(HealthState health, bool isAr, bool isDark) {
    final bg       = isDark ? AppColors.darkCard : Colors.white;
    final pct      = (health.steps / health.stepsGoal).clamp(0.0, 1.0);
    final kcalBurn = (health.steps * 0.04).toInt();
    final distKm   = health.steps * 0.00076;
    final distStr  = distKm >= 1
        ? '${distKm.toStringAsFixed(2)}${isAr?" كم":" km"}'
        : '${(distKm * 1000).toInt()}${isAr?" م":" m"}';

    return _card(bg, Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${health.steps}',
                style: const TextStyle(fontFamily: 'Cairo',
                    fontSize: 36, fontWeight: FontWeight.w900,
                    color: AppColors.halalGreen)),
            const SizedBox(width: 8),
            if (_stepServiceRunning)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.halalGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.halalGreen,
                        shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(tLang(lang, 'مباشر', 'LIVE', 'EN DIRECT', 'CANLI', 'LANGSUNG', 'LANGSUNG'),
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: AppColors.halalGreen)),
                ]))
            else
              GestureDetector(
                onTap: _startStepService,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(tLang(lang, '▶ تشغيل', '▶ Start', '▶ Démarrer', '▶ Başlat', '▶ Mula', '▶ Mulai'),
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: Colors.orange)))),
          ]),
          Text('/ ${health.stepsGoal} ${isAr?"خطوة":"steps"}',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12,
                  color: AppColors.halalGreen.withOpacity(0.7))),
        ])),
        Text(pct >= 1.0?'🏆':pct >= 0.7?'💪':'🚶',
            style: const TextStyle(fontSize: 42)),
      ]),
      const SizedBox(height: 12),
      Stack(children: [
        Container(height: 12, decoration: BoxDecoration(
          color: AppColors.halalGreen.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8))),
        LayoutBuilder(builder: (_, c) => AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          height: 12, width: c.maxWidth * pct,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.halalGreen.withOpacity(0.6),
              AppColors.halalGreen]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(
              color: AppColors.halalGreen.withOpacity(0.35),
              blurRadius: 6)]))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _stepStat('🗺️', distStr,   tLang(lang, 'مسافة', 'Distance', 'Distance', 'Mesafe', 'Jarak', 'Jarak'), AppColors.waterBlue),
        const SizedBox(width: 8),
        _stepStat('🔥', '$kcalBurn', tLang(lang, 'سعرة محروقة', 'kcal burned', 'kcal brûlées', 'kcal yakıldı', 'kcal dibakar', 'kkal terbakar'), AppColors.haramRed),
        const SizedBox(width: 8),
        _stepStat('🎯', '${(pct*100).toInt()}%', tLang(lang, 'من الهدف', 'of goal', 'de l\'objectif', 'hedefe ulaşıldı', 'daripada matlamat', 'dari target'), AppColors.halalGreen),
      ]),
      const SizedBox(height: 12),
      Text(tLang(lang, 'ضبط يدوي:', 'Manual adjust:', 'Ajustement manuel :', 'Manuel ayar:', 'Laraskan manual:', 'Sesuaikan manual:'),
          style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
              color: isDark?AppColors.darkMuted:AppColors.lightMuted)),
      const SizedBox(height: 6),
      Row(children: [1000, 3000, 5000].map((n) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: OutlinedButton(
            onPressed: () =>
                ref.read(healthProvider.notifier).addSteps(n),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.halalGreen,
                side: BorderSide(
                    color: AppColors.halalGreen.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 6)),
            child: Text('+$n', style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 10)),
          ),
        ),
      )).toList()),
    ]));
  }

  Widget _stepStat(String emoji, String val,
      String label, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2))),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          Text(val, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 9, color: color.withOpacity(0.8))),
        ])));

  Widget _moodCard(HealthState health, bool isAr, bool isDark) {
    final bg = isDark ? AppColors.darkCard : Colors.white;
    final moods = isAr
        ? [['😄', 'ممتاز'], ['😊', 'جيد'], ['😐', 'عادي'], ['😔', 'تعبان'], ['😡', 'متوتر']]
        : [['😄', 'Great'], ['😊', 'Good'], ['😐', 'Okay'], ['😔', 'Low'], ['😡', 'Stressed']];

    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: moods.map((m) => GestureDetector(
          onTap: () => ref.read(healthProvider.notifier).setMood(m[1]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: health.mood == m[1]
                  ? AppColors.brandGreen.withOpacity(0.12)
                  : Colors.transparent,
              border: Border.all(
                  color: health.mood == m[1]
                      ? AppColors.brandGreen
                      : Colors.transparent,
                  width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              Text(m[0], style: const TextStyle(fontSize: 28)),
              Text(m[1],
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 9,
                      color: AppColors.lightMuted)),
            ]),
          ),
        )).toList(),
      ),
      if (health.mood != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
              tLang(lang, 'سجلت مزاجك: ${health.mood}', 'Mood recorded: ${health.mood}', 'Mood recorded: ${health.mood}', 'Mood recorded: ${health.mood}', 'Mood recorded: ${health.mood}', 'Mood recorded: ${health.mood}'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandGreen)),
        ),
    ]));
  }

  Widget _hrCard(HealthState health, bool isAr, bool isDark) {
    final bg = isDark ? AppColors.darkCard : Colors.white;
    final hrCol = health.heartRate > 100
        ? AppColors.haramRed
        : health.heartRate < 60
            ? AppColors.waterBlue
            : AppColors.halalGreen;
    final hrLbl = isAr
        ? (health.heartRate > 100 ? 'مرتفع' : health.heartRate < 60 ? 'منخفض' : 'طبيعي')
        : (health.heartRate > 100 ? 'High' : health.heartRate < 60 ? 'Low' : 'Normal');

    return _card(bg, Column(children: [
      Row(children: [
        Column(children: [
          Text('${health.heartRate}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.haramRed)),
          Text(tLang(lang, 'نبضة/دقيقة', 'bpm', 'bpm', 'bpm', 'bpm', 'bpm'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  color: AppColors.lightMuted)),
        ]),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(tLang(lang, 'المعدل الطبيعي: 60-100', 'Normal: 60-100 bpm', 'Normal : 60-100 bpm', 'Normal: 60-100 bpm', 'Normal: 60-100 bpm', 'Normal: 60-100 bpm'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
              value: ((health.heartRate - 40) / 80).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(hrCol),
              borderRadius: BorderRadius.circular(6),
              minHeight: 8),
          const SizedBox(height: 4),
          Text(hrLbl,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  fontWeight: FontWeight.w700, color: hrCol)),
        ])),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => ref.read(healthProvider.notifier)
              .setHeartRate(health.heartRate - 1),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8)),
          child: const Text('-', style: TextStyle(fontSize: 18)),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(
          onPressed: () => ref.read(healthProvider.notifier)
              .setHeartRate(health.heartRate + 1),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8)),
          child: const Text('+', style: TextStyle(fontSize: 18)),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: () => ref.read(healthProvider.notifier)
              .setHeartRate(60 + (DateTime.now().millisecond % 40)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.halalGreen,
              padding: const EdgeInsets.symmetric(vertical: 8)),
          child: Text(tLang(lang, 'قياس', 'Measure', 'Mesurer', 'Ölç', 'Ukur', 'Ukur'),
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  color: Colors.white)),
        )),
      ]),
    ]));
  }

  // ── CALCULATORS TAB ───────────────────────────────────────
  Widget _buildCalc(bool isAr, bool isDark) {
    final health = ref.watch(healthProvider);
    final bg     = isDark ? AppColors.darkCard : Colors.white;
    final bmi    = health.quickBmi;

    return ListView(padding: const EdgeInsets.all(14), children: [
      _sectionTitle(tLang(lang, 'حاسبة BMI', 'BMI Calculator', 'Calculateur IMC', 'VKİ Hesaplayıcı', 'Kalkulator BMI', 'Kalkulator IMT'), isDark),
      _card(bg, Column(children: [
        Row(children: [
          Expanded(child: TextField(
            controller: _weightCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
                labelText: tLang(lang, 'الوزن (كجم)', 'Weight (kg)', 'Poids (kg)', 'Ağırlık (kg)', 'Berat (kg)', 'Berat (kg)'),
                hintText: '70'),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: _heightCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
                labelText: tLang(lang, 'الطول (سم)', 'Height (cm)', 'Taille (cm)', 'Boy (cm)', 'Tinggi (cm)', 'Tinggi (cm)'),
                hintText: '170'),
          )),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final w = double.tryParse(_weightCtrl.text);
            final h = double.tryParse(_heightCtrl.text);
            if (w != null && h != null && w > 0 && h > 0) {
              ref.read(healthProvider.notifier).setBMI(w, h);
            }
          },
          child: Text(tLang(lang, 'احسب BMI', 'Calculate BMI', 'Calculer l\'IMC', 'VKİ Hesapla', 'Kira BMI', 'Hitung IMT'),
              style: const TextStyle(fontFamily: 'Cairo')),
        )),
        if (bmi != null) ...[
          const SizedBox(height: 14),
          Text(bmi.toStringAsFixed(1),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 36,
                  fontWeight: FontWeight.w900, color: _bmiColor(bmi))),
          Text(_bmiLabel(bmi, isAr),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16,
                  fontWeight: FontWeight.w700, color: _bmiColor(bmi))),
        ],
      ])),
      const SizedBox(height: 16),
      _sectionTitle(
          tLang(lang, 'سعرات محروقة في 30 دقيقة', 'Calories Burned in 30 min', 'Calories brûlées en 30 min', '30 dakikada yakılan kalori', 'Kalori Dibakar dalam 30 min', 'Kalori Terbakar dalam 30 menit'),
          isDark),
      _card(bg, Column(children: [
        ...(isAr
            ? [['🚶 مشي', '~140'], ['🏃 جري', '~300'], ['🚴 دراجة', '~250'], ['🏊 سباحة', '~220'], ['🧘 يوجا', '~120'], ['🏋 أثقال', '~180']]
            : [['🚶 Walking', '~140'], ['🏃 Running', '~300'], ['🚴 Cycling', '~250'], ['🏊 Swimming', '~220'], ['🧘 Yoga', '~120'], ['🏋 Weights', '~180']]
        ).map((r) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(r[0], style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
            Text('${r[1]} ${isAr ? "سعرة" : "kcal"}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.haramRed)),
          ]),
        )),
      ])),
      const SizedBox(height: 16),
    ]);
  }

  // ── ARTICLES TAB ──────────────────────────────────────────
  Widget _buildArticles(bool isAr, bool isDark) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    return ListView(padding: const EdgeInsets.all(14), children: [
      Text(tLang(lang, 'مقالات صحية', 'Health Articles', 'Articles santé', 'Sağlık Makaleleri', 'Artikel Kesihatan', 'Artikel Kesehatan'),
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 15,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(tLang(lang, 'اضغط على أي مقال للقراءة', 'Tap any article to read', 'Appuyez sur un article pour lire', 'Okumak için herhangi bir makaleye dokun', 'Ketuk mana-mana artikel untuk baca', 'Ketuk artikel mana saja untuk membaca'),
          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted)),
      const SizedBox(height: 14),
      ...kHealthArticles.map((a) {
        final isOpen   = _expandedArticle == a.id;
        final artColor = Color(a.colorValue);
        return GestureDetector(
          onTap: () => setState(
              () => _expandedArticle = isOpen ? null : a.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06), blurRadius: 10)],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: artColor.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(child: Text(a.icon,
                        style: const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(a.title,
                        style: const TextStyle(fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    Text(a.summary,
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 11, color: muted)),
                  ])),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: AppColors.lightMuted),
                  ),
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: isOpen
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          const Divider(height: 20),
                          Text(a.body,
                              style: TextStyle(fontFamily: 'Cairo',
                                  fontSize: 12, height: 1.8,
                                  color: isDark
                                      ? AppColors.darkText
                                      : AppColors.lightText)),
                        ])
                      : const SizedBox.shrink(),
                ),
              ]),
            ),
          ),
        );
      }),
    ]);
  }

  Widget _sectionTitle(String t, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(
        width: 4, height: 20,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandGreen, AppColors.halalGreen],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(fontFamily: 'Cairo', fontSize: 15,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkText : AppColors.lightText)),
    ]),
  );

  Widget _card(Color bg, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 18, offset: const Offset(0, 4)),
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
