// health_screen.dart — HalalCalorie v1.0 — Bilingual
import 'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'../../core/theme.dart'; import'../../core/providers.dart'; import'../../data/models/models.dart';

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});
  @override ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String? _expandedArticle;
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final lang   = ref.watch(languageProvider); final isAr   = lang =='ar';
    String t(String ar, String en) => isAr ? ar : en;

    return Scaffold(
      appBar: AppBar( title: Text(t('الصحة والعافية 🩺', 'Health & Wellness 🩺')),
        actions: [
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggle(),
            child: Padding(padding: const EdgeInsets.only(left: 14),
              child: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round, color: Colors.white)),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.barakahGold, labelStyle: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 11), unselectedLabelStyle: const TextStyle(fontFamily:'Cairo', fontSize: 11),
          labelColor: Colors.white, unselectedLabelColor: Colors.white70,
          tabs: [ Tab(text: t('تتبع','Tracking')), Tab(text: t('حاسبات','Calculators')), Tab(text: t('مقالات','Articles')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_buildTrack(isAr, isDark), _buildCalc(isAr, isDark), _buildArticles(isAr, isDark)],
      ),
    );
  }

  // ── TRACKING ──────────────────────────────────────────────
  Widget _buildTrack(bool isAr, bool isDark) {
    final snapshot   = ref.watch(healthSnapshotProvider);
    final hasPerms   = ref.watch(healthPermissionProvider);

    // Auto-sync real data when available
    snapshot.whenData((data) {
      if (data.isReal) {
        if (data.steps > 0)
          Future.microtask(() =>
            ref.read(healthProvider.notifier).setSteps(data.steps));
        if (data.heartRate > 0)
          Future.microtask(() =>
            ref.read(healthProvider.notifier).setHeartRate(data.heartRate));
        if (data.sleepHours > 0)
          Future.microtask(() =>
            ref.read(sleepProvider.notifier).set(data.sleepHours));
      }
    });
    final water  = ref.watch(waterProvider);
    final sleep  = ref.watch(sleepProvider);
    final health = ref.watch(healthProvider);
    String t(String ar, String en) => isAr ? ar : en;
    return ListView(padding: const EdgeInsets.all(14), children: [
      // ── Connect to Health banner ──────────────────────
      if (!hasPerms)
        GestureDetector(
          onTap: () async {
            final granted = await ref.read(healthPermissionProvider.notifier).request();
            if (granted && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isAr
                    ? 'تم الاتصال بـ Google Fit! ✓'
                    : 'Connected to Google Fit! ✓',
                    style: const TextStyle(fontFamily: 'Cairo')),
                backgroundColor: AppColors.sunnahGreen,
                behavior: SnackBarBehavior.floating,
              ));
              ref.invalidate(healthSnapshotProvider);
            }
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.gradientGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                color: AppColors.sunnahGreen.withOpacity(0.3),
                blurRadius: 12, offset: const Offset(0, 4),
              )],
            ),
            child: Row(children: [
              const Text('📱', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? 'اربط مع Google Fit' : 'Connect to Google Fit',
                    style: const TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w800, fontSize: 14,
                        color: Colors.white),
                  ),
                  Text(
                    isAr
                        ? 'خطوات حقيقية • معدل نبض • نوم تلقائي'
                        : 'Real steps • Heart rate • Auto sleep tracking',
                    style: const TextStyle(fontFamily: 'Cairo',
                        fontSize: 11, color: Colors.white70),
                  ),
                ],
              )),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ]),
          ),
        )
      else
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.sunnahGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sunnahGreen.withOpacity(0.3)),
          ),
          child: Row(children: [
            const Text('✅', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              isAr ? 'متصل بـ Google Fit — بيانات حقيقية' : 'Connected to Google Fit — Live data',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12,
                  color: AppColors.sunnahGreen, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => ref.invalidate(healthSnapshotProvider),
              child: const Icon(Icons.refresh, color: AppColors.sunnahGreen, size: 18),
            ),
          ]),
        ),
      _healthScoreCard(water, sleep, health, isAr, isDark),
      const SizedBox(height: 16), _sectionTitle('💧 ${t("الماء اليومي","Daily Water")}', isDark),
      _waterCard(water, isAr, isDark),
      const SizedBox(height: 16), _sectionTitle('😴 ${t("النوم","Sleep")}', isDark),
      _sleepCard(sleep, isAr, isDark),
      const SizedBox(height: 16), _sectionTitle('🚶 ${t("خطوات اليوم","Today\'s Steps")}', isDark),
      _stepsCard(health, isAr, isDark),
      const SizedBox(height: 16), _sectionTitle('😊 ${t("مزاجك اليوم","Today\'s Mood")}', isDark),
      _moodCard(health, isAr, isDark),
      const SizedBox(height: 16), _sectionTitle('❤️ ${t("معدل النبض","Heart Rate")}', isDark),
      _hrCard(health, isAr, isDark),
      const SizedBox(height: 14),
    ]);
  }


  // ── DAILY HEALTH SCORE ────────────────────────────────────
  Widget _healthScoreCard(WaterState water, SleepState sleep,
      HealthState health, bool isAr, bool isDark) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => isAr ? ar : en;

    // Score components (0-25 each = 100 max)
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

    String scoreLabel() {
      if (isAr) { if (total >= 80) return'ممتاز 🌟'; if (total >= 60) return'جيد جداً 👍'; if (total >= 40) return'جيد 😊'; return'يحتاج تحسيناً 💪';
      } else { if (total >= 80) return'Excellent 🌟'; if (total >= 60) return'Very Good 👍'; if (total >= 40) return'Good 😊'; return'Keep improving 💪';
      }
    }

    Widget scoreBar(String label, double score, double max, Color col) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(label, style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted)), Text('${score.toInt()}/${max.toInt()}', style: TextStyle( fontFamily:'Cairo', fontSize: 10, fontWeight: FontWeight.w700, color: col)),
          ]),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: (score / max).clamp(0.0, 1.0),
            backgroundColor: col.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation(col),
            borderRadius: BorderRadius.circular(4), minHeight: 7,
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(t('💯 نقاط صحتك اليوم', '💯 Your Daily Health Score'), style: const TextStyle(fontFamily:'Cairo', fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(scoreLabel(), style: TextStyle( fontFamily:'Cairo', fontSize: 12, color: scoreColor())),
          ])),
          SizedBox(width: 80, height: 80, child: Stack(alignment: Alignment.center, children: [
            SizedBox.expand(child: CircularProgressIndicator(
              value: total / 100, strokeWidth: 9,
              backgroundColor: scoreColor().withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(scoreColor()),
              strokeCap: StrokeCap.round,
            )), Text('$total', style: TextStyle(fontFamily: 'Cairo', fontSize: 22,
                fontWeight: FontWeight.w900, color: scoreColor())),
          ])),
        ]),
        const SizedBox(height: 14), scoreBar(t('💧 الماء', '💧 Water'),          wScore,  25, AppColors.waterBlue), scoreBar(t('😴 النوم', '😴 Sleep'),          slScore, 25, AppColors.sleepPurple), scoreBar(t('🚶 الخطوات', '🚶 Steps'),       stScore, 25, AppColors.halalGreen), scoreBar(t('😊 المزاج', '😊 Mood'),          mScore,  25, AppColors.barakahGold),
      ]),
    );
  }

  Widget _waterCard(WaterState water, bool isAr, bool isDark) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => isAr ? ar : en;
    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(children: [ TextSpan(text:'${water.cups}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.waterBlue)), TextSpan(text:' / ${water.goal} ${t("أكواب","cups")}', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: muted)),
          ])), Text('${(water.cups * 0.25).toStringAsFixed(2)} ${t("لتر","L")}', style: TextStyle(fontFamily:'Cairo', fontSize: 12, color: muted)),
        ]), Text('${(water.percent * 100).toInt()}%', style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.waterBlue)),
      ]),
      const SizedBox(height: 12),
      Wrap(spacing: 4, runSpacing: 4, children: List.generate(water.goal, (i) => GestureDetector(
        onTap: () => ref.read(waterProvider.notifier).set(i + 1), child: Text('💧', style: TextStyle(fontSize: 28, color: i < water.cups ? null : Colors.grey.withOpacity(0.35))),
      ))),
      const SizedBox(height: 12),
      LinearProgressIndicator(value: water.percent.clamp(0.0, 1.0), backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.waterBlue), borderRadius: BorderRadius.circular(8), minHeight: 10),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => ref.read(waterProvider.notifier).remove(),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.waterBlue, side: const BorderSide(color: AppColors.waterBlue)), child: Text(t('− كوب','− Cup'), style: const TextStyle(fontFamily: 'Cairo')),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: () => ref.read(waterProvider.notifier).add(),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.waterBlue), child: Text(t('+ كوب 💧','+ Cup 💧'), style: const TextStyle(fontFamily: 'Cairo', color: Colors.white)),
        )),
      ]),
    ]));
  }

  Widget _sleepCard(SleepState sleep, bool isAr, bool isDark) {
    // Show real sleep data indicator
    final snapshot = ref.watch(healthSnapshotProvider);
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => isAr ? ar : en;
    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RichText(text: TextSpan(children: [ TextSpan(text:'${sleep.hours.toInt()}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.sleepPurple)), TextSpan(text:' ${t("ساعات","hours")}', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: muted)),
          ])),
          Text(isAr ? sleep.qualityAr() : sleep.qualityEn(), style: const TextStyle(fontFamily:'Cairo', fontSize: 13, color: AppColors.sleepPurple)),
        ]), Text(sleep.hours >= 8 ?'😊' : sleep.hours >= 6 ? '😐' : '😞', style: const TextStyle(fontSize: 32)),
      ]),
      const SizedBox(height: 12),
      Row(children: [4, 5, 6, 7, 8, 9, 10].map((h) => Expanded(child: GestureDetector(
        onTap: () => ref.read(sleepProvider.notifier).set(h.toDouble()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: sleep.hours >= h ? AppColors.sleepPurple : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ), child: Center(child: Text('$h', style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
              fontWeight: FontWeight.w700, color: sleep.hours >= h ? Colors.white : muted))),
        ),
      ))).toList()),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: sleep.percent, backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.sleepPurple), borderRadius: BorderRadius.circular(8), minHeight: 10),
      Padding(padding: const EdgeInsets.only(top: 5), child: Text(t('الهدف: ${sleep.goal.toInt()} ساعات', 'Goal: ${sleep.goal.toInt()} hours'), textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 10, color: muted))),
    ]));
  }

  Widget _stepsCard(HealthState health, bool isAr, bool isDark) {
    final bg  = isDark ? AppColors.darkCard : Colors.white;
    final pct = (health.steps / health.stepsGoal).clamp(0.0, 1.0);
    String t(String ar, String en) => isAr ? ar : en;
    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${health.steps}', style: const TextStyle(
              fontFamily: 'Cairo', fontSize: 28,
              fontWeight: FontWeight.w900, color: AppColors.halalGreen)),
          const SizedBox(width: 6),
          ref.watch(healthSnapshotProvider).maybeWhen(
            data: (snap) => snap.isReal && snap.steps > 0
                ? Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.halalGreen,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('LIVE',
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 8, color: Colors.white,
                            fontWeight: FontWeight.w800)),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ]), Text('${t("خطوة من","steps of")} ${health.stepsGoal}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.lightMuted)),
        ]), Text(pct >= 1 ?'🏆' : pct >= 0.7 ? '💪' : '🚶', style: const TextStyle(fontSize: 36)),
      ]),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.halalGreen), borderRadius: BorderRadius.circular(8), minHeight: 10),
      const SizedBox(height: 12),
      Row(children: [500, 1000, 2000].map((n) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: OutlinedButton(
          onPressed: () => ref.read(healthProvider.notifier).addSteps(n),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.halalGreen,
              side: const BorderSide(color: AppColors.halalGreen), padding: const EdgeInsets.symmetric(vertical: 8)), child: Text('+$n', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
        ),
      ))).toList()),
    ]));
  }

  Widget _moodCard(HealthState health, bool isAr, bool isDark) {
    final bg = isDark ? AppColors.darkCard : Colors.white;
    final moods = isAr ? [['😄','ممتاز'], ['😊','جيد'], ['😐','عادي'], ['😔','تعبان'], ['😡','متوتر']] : [['😄','Great'], ['😊','Good'],  ['😐','Okay'], ['😔','Low'],    ['😡','Stressed']];
    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: moods.map((m) => GestureDetector(
        onTap: () => ref.read(healthProvider.notifier).setMood(m[1]),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: health.mood == m[1] ? AppColors.sunnahGreen.withOpacity(0.12) : Colors.transparent,
            border: Border.all(color: health.mood == m[1] ? AppColors.sunnahGreen : Colors.transparent, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(m[0], style: const TextStyle(fontSize: 28)), Text(m[1], style: const TextStyle(fontFamily:'Cairo', fontSize: 9, color: AppColors.lightMuted)),
          ]),
        ),
      )).toList()),
      if (health.mood != null)
        Padding(padding: const EdgeInsets.only(top: 10), child: Text(isAr ?'سجّلت مزاجك: ${health.mood} ✓' : 'Mood recorded: ${health.mood} ✓',
              textAlign: TextAlign.center, style: const TextStyle(fontFamily:'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sunnahGreen))),
    ]));
  }

  Widget _hrCard(HealthState health, bool isAr, bool isDark) {
    final bg     = isDark ? AppColors.darkCard : Colors.white;
    final hrCol  = health.heartRate > 100 ? AppColors.haramRed : health.heartRate < 60 ? AppColors.waterBlue : AppColors.halalGreen;
    final hrLbl  = isAr ? (health.heartRate > 100 ?'مرتفع' : health.heartRate < 60 ? 'منخفض' : 'طبيعي ✓') : (health.heartRate > 100 ?'High' : health.heartRate < 60 ? 'Low' : 'Normal ✓');
    return _card(bg, Column(children: [
      Row(children: [
        Column(children: [ Column(children: [
            Text('${health.heartRate}',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 32,
                    fontWeight: FontWeight.w900, color: AppColors.haramRed)),
            ref.watch(healthSnapshotProvider).maybeWhen(
              data: (snap) => snap.isReal && snap.heartRate > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.haramRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('LIVE',
                          style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 8, color: AppColors.haramRed,
                              fontWeight: FontWeight.w800)),
                    )
                  : const Text('manual',
                      style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 8, color: AppColors.lightMuted)),
              orElse: () => const SizedBox.shrink(),
            ),
          ]), Text(isAr ?'نبضة/دقيقة' : 'bpm', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.lightMuted)),
        ]),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(isAr ?'المعدل الطبيعي: 60-100' : 'Normal: 60-100 bpm', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: ((health.heartRate - 40) / 80).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation(hrCol),
              borderRadius: BorderRadius.circular(6), minHeight: 8),
          const SizedBox(height: 4), Text(hrLbl, style: TextStyle(fontFamily:'Cairo', fontSize: 11, fontWeight: FontWeight.w700, color: hrCol)),
        ])),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: () => ref.read(healthProvider.notifier).setHeartRate(health.heartRate - 1),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)), child: const Text('−', style: TextStyle(fontSize: 18)),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton(
          onPressed: () => ref.read(healthProvider.notifier).setHeartRate(health.heartRate + 1),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)), child: const Text('+', style: TextStyle(fontSize: 18)),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton(
          onPressed: () => ref.read(healthProvider.notifier).setHeartRate(60 + (DateTime.now().millisecond % 40)),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.halalGreen, padding: const EdgeInsets.symmetric(vertical: 8)), child: Text(isAr ?'🔄 قياس' : '🔄 Measure', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white)),
        )),
      ]),
    ]));
  }

  // ── CALCULATORS ───────────────────────────────────────────
  Widget _buildCalc(bool isAr, bool isDark) {
    final health = ref.watch(healthProvider);
    final bg     = isDark ? AppColors.darkCard : Colors.white;
    final bmi    = health.quickBmi;
    String t(String ar, String en) => isAr ? ar : en;

    return ListView(padding: const EdgeInsets.all(14), children: [ _sectionTitle('⚖️ ${t("حاسبة BMI","BMI Calculator")}', isDark),
      _card(bg, Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _weightCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('الوزن (كجم)','Weight (kg)'), hintText: '70'),
            textDirection: TextDirection.ltr,
          )),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _heightCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('الطول (سم)','Height (cm)'), hintText: '170'),
            textDirection: TextDirection.ltr,
          )),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            final w = double.tryParse(_weightCtrl.text);
            final h = double.tryParse(_heightCtrl.text);
            if (w != null && h != null && w > 0 && h > 0) ref.read(healthProvider.notifier).setBMI(w, h);
          }, child: Text(t('احسب BMI','Calculate BMI'), style: const TextStyle(fontFamily: 'Cairo')),
        )),
        if (bmi != null) ...[
          const SizedBox(height: 14),
          Text(bmi.toStringAsFixed(1), textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 36, fontWeight: FontWeight.w900, color: _bmiColor(bmi))),
          Text(_bmiLabel(bmi, isAr), textAlign: TextAlign.center, style: TextStyle(fontFamily:'Cairo', fontSize: 16, fontWeight: FontWeight.w700, color: _bmiColor(bmi))),
        ],
      ])),
      const SizedBox(height: 16), _sectionTitle('🏃 ${t("سعرات محروقة في ٣٠ دقيقة","Calories Burned in 30 min")}', isDark),
      _card(bg, Column(children: [
        ...(isAr ? [['🚶 مشي','~140'], ['🏃 جري','~300'], ['🚴 دراجة','~250'], ['🏊 سباحة','~220'], ['🧘 يوجا','~120'], ['🏋️ أثقال','~180']] : [['🚶 Walking','~140'], ['🏃 Running','~300'], ['🚴 Cycling','~250'], ['🏊 Swimming','~220'], ['🧘 Yoga','~120'], ['🏋️ Weights','~180']]
        ).map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text(r[0], style: const TextStyle(fontFamily:'Cairo', fontSize: 13)), Text('${r[1]} ${t("سعرة","kcal")}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.haramRed)),
          ]))),
      ])),
      const SizedBox(height: 16),
    ]);
  }

  // ── ARTICLES ─────────────────────────────────────────────
  Widget _buildArticles(bool isAr, bool isDark) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => isAr ? ar : en;

    return ListView(padding: const EdgeInsets.all(14), children: [ Text(t('مقالات صحية إسلامية','Islamic Health Articles'), style: const TextStyle(fontFamily:'Cairo', fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4), Text(t('اضغط على أي مقال للقراءة','Tap any article to read'), style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted)),
      const SizedBox(height: 14),
      ...kHealthArticles.map((a) {
        final isOpen    = _expandedArticle == a.id;
        final artColor  = Color(a.colorValue);
        return GestureDetector(
          onTap: () => setState(() => _expandedArticle = isOpen ? null : a.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
            child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(color: artColor.withOpacity(0.18), borderRadius: BorderRadius.circular(11)),
                  child: Center(child: Text(a.icon, style: const TextStyle(fontSize: 20)))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(a.title, style: const TextStyle(fontFamily:'Cairo', fontWeight: FontWeight.w700, fontSize: 13)), Text(a.summary, style: TextStyle(fontFamily:'Cairo', fontSize: 11, color: muted)),
                ])),
                AnimatedRotation(turns: isOpen ? 0.5 : 0, duration: const Duration(milliseconds: 250),
                  child: const Icon(Icons.keyboard_arrow_down, color: AppColors.lightMuted)),
              ]),
              AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
                child: isOpen ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Divider(height: 20), Text(a.body, style: TextStyle(fontFamily:'Cairo', fontSize: 12, height: 1.8,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
                ]) : const SizedBox.shrink()),
            ])),
          ),
        );
      }),
    ]);
  }

  Widget _sectionTitle(String t, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: TextStyle(fontFamily:'Cairo', fontSize: 15, fontWeight: FontWeight.w700,
      color: isDark ? AppColors.darkText : AppColors.lightText)),
  );

  Widget _card(Color bg, Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
    child: child,
  );

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.waterBlue;
    if (bmi < 25)   return AppColors.halalGreen;
    if (bmi < 30)   return AppColors.doubtOrange;
    return AppColors.haramRed;
  }

  String _bmiLabel(double bmi, bool isAr) {
    if (isAr) { if (bmi < 18.5) return'نقص وزن'; if (bmi < 25)   return'وزن مثالي ✓'; if (bmi < 30)   return'زيادة وزن'; return'سمنة';
    } else { if (bmi < 18.5) return'Underweight'; if (bmi < 25)   return'Normal ✓'; if (bmi < 30)   return'Overweight'; return'Obese';
    }
  }
}
