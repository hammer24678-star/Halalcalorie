// ============================================================
//  body_screen.dart — HalalCalorie v1.0
//  Full body metrics: BMI, body fat%, muscle mass, LBM,
//  BMR, TDEE, macro targets, ideal weight, water needs
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/models.dart';

class BodyScreen extends ConsumerStatefulWidget {
  const BodyScreen({super.key});
  @override ConsumerState<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends ConsumerState<BodyScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  // Edit mode
  bool _editing = false;
  late TextEditingController _wCtrl, _hCtrl, _waistCtrl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
    final p = ref.read(userProfileProvider);
    _wCtrl     = TextEditingController(text: p?.weightKg.toString() ?? '70');
    _hCtrl     = TextEditingController(text: p?.heightCm.toString() ?? '170');
    _waistCtrl = TextEditingController(text: p?.waistCm?.toString() ?? '');
  }

  @override void dispose() { _tab.dispose(); _wCtrl.dispose(); _hCtrl.dispose(); _waistCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final profile  = ref.watch(userProfileProvider);
    final isPremium = ref.watch(premiumProvider);
    final lang     = ref.watch(languageProvider);
    final isDark   = ref.watch(themeProvider);
    final isAr     = lang == 'ar';

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(isAr ? 'تحليل الجسم 💪' : 'Body Analysis 💪')),
        body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('💪', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            isAr ? 'أكمل إعداد ملفك الشخصي أولاً' : 'Complete your profile setup first',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(
            isAr
              ? 'أدخل طولك ووزنك وعمرك لحساب مقاييس جسمك'
              : 'Enter your height, weight and age to calculate precise body metrics',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.lightMuted, height: 1.6)),
          const SizedBox(height: 28),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () {
              // Push onboarding modally so user can return
              ref.read(onboardingDoneProvider.notifier).reset().then((_) {
                if (context.mounted) context.go('/onboarding');
              });
            },
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: Text(isAr ? 'إعداد الملف الشخصي' : 'Setup My Profile',
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontWeight: FontWeight.w700)),
          )),
        ]))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'مقاييس جسمي 💪' : 'My Body Metrics 💪'),
        actions: [
          IconButton(
            icon: Icon(_editing ? Icons.check : Icons.edit_outlined, color: Colors.white),
            onPressed: _editing ? () => _saveEdits(profile) : () => setState(() => _editing = true),
          ),
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggle(),
            child: Padding(padding: const EdgeInsets.only(left: 14, right: 14),
              child: Icon(isDark ? Icons.wb_sunny : Icons.nightlight_round, color: Colors.white)),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.barakahGold,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
          labelColor: Colors.white, unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: isAr ? 'نظرة عامة' : 'Overview'),
            Tab(text: isAr ? 'تفاصيل' : 'Details'),
            Tab(text: isAr ? 'التغذية' : 'Nutrition'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildOverview(profile, isPremium, isAr, isDark),
          _buildDetails(profile, isPremium, isAr, isDark),
          _buildNutrition(profile, isPremium, isAr, isDark),
        ],
      ),
    );
  }

  // ── OVERVIEW TAB ─────────────────────────────────────────
  Widget _buildOverview(UserProfile p, bool isPremium, bool isAr, bool isDark) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC  = isDark ? AppColors.darkText  : AppColors.lightText;

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Edit panel
      if (_editing) _editPanel(p, isAr, isDark),

      // Profile summary hero
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: p.isMale
              ? [AppColors.sunnahGreen, AppColors.darkGreen]
              : [AppColors.barakahGold, const Color(0xFFB8860B)],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.sunnahGreen.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(children: [
          Text(p.isMale ? '🧔' : '🧕', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text('${p.weightKg.toStringAsFixed(1)} kg  •  ${p.heightCm.toInt()} cm  •  ${p.age} ${isAr ? "سنة" : "yrs"}',
              style: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _heroStat(isAr ? 'BMI' : 'BMI', p.bmi.toStringAsFixed(1), _bmiColor(p.bmi), subtitle: isAr ? p.bmiCategoryAr : p.bmiCategoryEn),
            _heroStat(isAr ? 'BMR' : 'BMR', '${p.bmrKcal.toInt()}', Colors.white70, subtitle: 'kcal'),
            _heroStat(isAr ? 'TDEE' : 'TDEE', '${p.tdeeKcal.toInt()}', Colors.white70, subtitle: 'kcal'),
          ]),
        ]),
      ),

      const SizedBox(height: 14),

      // Key stats grid
      GridView.count(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2, mainAxisSpacing: 11, crossAxisSpacing: 11, childAspectRatio: 1.6,
        children: [
          _metricCard(isAr ? 'وزنك الحالي' : 'Current Weight', '${p.weightKg.toStringAsFixed(1)} kg', '⚖️', AppColors.sunnahGreen, cardBg),
          _metricCard(isAr ? 'الوزن المثالي' : 'Ideal Weight', '${p.idealWeightKg.toStringAsFixed(1)} kg', '🎯', AppColors.barakahGold, cardBg),
          _metricCard(isAr ? 'هدف السعرات' : 'Calorie Goal', '${p.calorieGoalKcal.toInt()} kcal', '🔥', AppColors.haramRed, cardBg),
          _metricCard(isAr ? 'الماء اليومي' : 'Daily Water', '${p.waterLiters} L', '💧', AppColors.waterBlue, cardBg),
        ],
      ),

      const SizedBox(height: 14),

      // BMI Scale visual
      _bmiScaleCard(p, isAr, isDark, cardBg, textC, muted),

      const SizedBox(height: 14),

      // Weight difference
      if (p.weightDifferenceKg.abs() > 0.5)
        _weightDiffCard(p, isAr, isDark, cardBg, muted),

      const SizedBox(height: 14),

      // Weight trend chart
      const SizedBox(height: 14),
      _weightChartCard(isAr, isDark, cardBg, muted, textC),

      // AI Body Photo button
      const SizedBox(height: 14),
      _bodyPhotoCard(isAr, isDark, isPremium),
      const SizedBox(height: 14),

      // Premium teaser for body fat
      if (!isPremium) _premiumTeaserCard(isAr, isDark),
    ]);
  }

  // ── DETAILS TAB ─────────────────────────────────────────
  Widget _buildDetails(UserProfile p, bool isPremium, bool isAr, bool isDark) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC  = isDark ? AppColors.darkText  : AppColors.lightText;

    return ListView(padding: const EdgeInsets.all(14), children: [
      if (!isPremium) _premiumBanner(isAr),

      _sectionTitle(isAr ? '🧬 تركيب الجسم' : '🧬 Body Composition', textC),
      _detailRow(
        isAr ? 'نسبة الدهون (Deurenberg)' : 'Body Fat % (Deurenberg)',
        isPremium ? '${p.bodyFatPercent.toStringAsFixed(1)}%' : '🔒 Premium',
        isPremium ? _bfColor(p.bodyFatPercent, p.isMale) : Colors.grey,
        isPremium ? p.bodyFatCategory : (isAr ? 'افتح بريميوم' : 'Unlock Premium'),
        cardBg, textC, muted,
      ),
      _detailRow(
        isAr ? 'كتلة العضلات (تقدير)' : 'Muscle Mass (estimate)',
        isPremium ? '${p.muscleMassKg.toStringAsFixed(1)} kg' : '🔒 Premium',
        isPremium ? AppColors.halalGreen : Colors.grey,
        isPremium ? '' : '',
        cardBg, textC, muted,
      ),
      _detailRow(
        isAr ? 'الكتلة النحيفة LBM' : 'Lean Body Mass (LBM)',
        isPremium ? '${p.leanBodyMassKg.toStringAsFixed(1)} kg' : '🔒 Premium',
        isPremium ? AppColors.waterBlue : Colors.grey,
        '', cardBg, textC, muted,
      ),
      _detailRow(
        isAr ? 'كتلة العظام (تقدير)' : 'Bone Mass (estimate)',
        '${p.boneMassKg.toStringAsFixed(1)} kg',
        AppColors.barakahGold,
        '', cardBg, textC, muted,
      ),

      const SizedBox(height: 16),
      _sectionTitle(isAr ? '⚡ الأيض والطاقة' : '⚡ Metabolism & Energy', textC),
      _detailRow(isAr ? 'معدل الأيض الأساسي (BMR)' : 'Basal Metabolic Rate (BMR)',
          '${p.bmrKcal.toInt()} kcal', AppColors.sunnahGreen,
          isAr ? 'طاقة الراحة الأساسية' : 'Energy at complete rest', cardBg, textC, muted),
      _detailRow(isAr ? 'إجمالي حرق اليوم (TDEE)' : 'Total Daily Energy (TDEE)',
          '${p.tdeeKcal.toInt()} kcal', AppColors.haramRed,
          isAr ? 'مع مستوى نشاطك' : 'With your activity level', cardBg, textC, muted),
      _detailRow(isAr ? 'هدف السعرات الموصى به' : 'Recommended Calorie Goal',
          '${p.calorieGoalKcal.toInt()} kcal', AppColors.barakahGold,
          isAr ? 'مُعدّل حسب هدفك' : 'Adjusted for your goal', cardBg, textC, muted),

      const SizedBox(height: 16),
      _sectionTitle(isAr ? '📊 المقاييس المرجعية' : '📊 Reference Metrics', textC),
      _detailRow(isAr ? 'الوزن المثالي (Devine)' : 'Ideal Weight (Devine)',
          '${p.idealWeightKg.toStringAsFixed(1)} kg', AppColors.sunnahGreen, '', cardBg, textC, muted),
      _detailRow(isAr ? 'الفرق عن الوزن المثالي' : 'Difference from Ideal',
          '${p.weightDifferenceKg.abs().toStringAsFixed(1)} kg ${p.weightDifferenceKg > 0 ? "زيادة" : "نقصان"}',
          p.weightDifferenceKg.abs() < 2 ? AppColors.halalGreen : AppColors.doubtOrange, '', cardBg, textC, muted),

      const SizedBox(height: 16),

      // What is BMI info box
      _infoExpandable(
        isAr ? 'ما هو مؤشر كتلة الجسم BMI؟' : 'What is BMI?',
        isAr
          ? 'مؤشر كتلة الجسم = الوزن ÷ الطول² (بالمتر)\n'
            '• أقل من 18.5 = نقص وزن\n• 18.5-24.9 = وزن مثالي\n• 25-29.9 = زيادة وزن\n• ٣٠+ = سمنة\n\n'
            '⚠️ BMI لا يميّز بين الدهون والعضلات. الرياضيون قد يظهرون بـ BMI مرتفع رغم لياقتهم.'
          : 'BMI = Weight ÷ Height² (in meters)\n'
            '• Below 18.5 = Underweight\n• 18.5-24.9 = Normal\n• 25-29.9 = Overweight\n• 30+ = Obese\n\n'
            '⚠️ BMI does not distinguish fat from muscle. Athletes may show high BMI despite being fit.',
        isDark, cardBg, muted,
      ),
      const SizedBox(height: 14),
    ]);
  }

  // ── NUTRITION TAB ────────────────────────────────────────
  Widget _buildNutrition(UserProfile p, bool isPremium, bool isAr, bool isDark) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC  = isDark ? AppColors.darkText  : AppColors.lightText;

    return ListView(padding: const EdgeInsets.all(14), children: [
      // Calorie breakdown
      _sectionTitle(isAr ? '🔥 توزيع السعرات' : '🔥 Calorie Distribution', textC),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
        child: Column(children: [
          _macroRow(isAr ? '🍚 كربوهيدرات' : '🍚 Carbohydrates', p.carbsGrams, p.calorieGoalKcal / 4, AppColors.waterBlue, isAr),
          const SizedBox(height: 12),
          _macroRow(isAr ? '🥩 بروتين' : '🥩 Protein', p.proteinGrams, p.proteinGrams * 1.2, AppColors.halalGreen, isAr),
          const SizedBox(height: 12),
          _macroRow(isAr ? '🧈 دهون صحية' : '🧈 Healthy Fats', p.fatGrams, p.calorieGoalKcal / 9 * 0.4, AppColors.barakahGold, isAr),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.sunnahGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(isAr ? 'الهدف اليومي الإجمالي' : 'Total Daily Goal',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${p.calorieGoalKcal.toInt()} kcal',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.sunnahGreen)),
            ]),
          ),
        ]),
      ),

      const SizedBox(height: 16),
      _sectionTitle(isAr ? '💧 الترطيب والماء' : '💧 Hydration', textC),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.waterLiters} L / ${isAr ? "يوم" : "day"}',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.waterBlue)),
              Text('≈ ${p.waterCupsGoal} ${isAr ? "كوب" : "cups"} (250 ml)',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted)),
            ]),
            const Text('💧', style: TextStyle(fontSize: 40)),
          ]),
          const SizedBox(height: 10),
          Text(isAr
            ? 'الحساب: ${p.weightKg.toStringAsFixed(0)} كجم × 0.033 = ${p.waterLiters} لتر/يوم\n${p.activityLevel == ActivityLevel.veryActive || p.activityLevel == ActivityLevel.extraActive ? "مع إضافة ٠.٥ لتر للنشاط العالي" : ""}'
            : 'Calculation: ${p.weightKg.toStringAsFixed(0)} kg × 0.033 = ${p.waterLiters} L/day\n${p.activityLevel == ActivityLevel.veryActive || p.activityLevel == ActivityLevel.extraActive ? "With +0.5L for high activity" : ""}',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted, height: 1.5)),
        ]),
      ),

      const SizedBox(height: 16),
      _sectionTitle(isAr ? '🥩 البروتين والعضلات' : '🥩 Protein & Muscle', textC),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isAr ? 'البروتين اليومي المُوصى به:' : 'Recommended daily protein:',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: muted)),
            Text('${p.proteinGrams.toInt()} g',
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.halalGreen)),
          ]),
          const SizedBox(height: 10),
          Text(
            isAr
              ? isPremium
                ? 'الكتلة النحيفة: ${p.leanBodyMassKg.toStringAsFixed(1)} كجم\nالمعدل: ×${p.primaryGoal == FitnessGoal.gainMuscle ? "2.0" : "1.6"} جرام/كجم'
                : 'افتح بريميوم لرؤية تفاصيل الكتلة النحيفة والعضلات'
              : isPremium
                ? 'Lean body mass: ${p.leanBodyMassKg.toStringAsFixed(1)} kg\nRate: ×${p.primaryGoal == FitnessGoal.gainMuscle ? "2.0" : "1.6"} g/kg'
                : 'Unlock Premium for lean mass & muscle details',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isPremium ? muted : AppColors.barakahGold, height: 1.5),
          ),
          const SizedBox(height: 10),
          // Sunnah protein sources
          Text(isAr ? '✨ مصادر البروتين الحلالية والسنية:' : '✨ Halal & Sunnah protein sources:',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sunnahGreen)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: (isAr
            ? ['دجاج مشوي', 'لحم حلال', 'بيض', 'عدس', 'فاصوليا', 'سمك', 'حليب', 'تمر', 'لبن']
            : ['Grilled chicken', 'Halal meat', 'Eggs', 'Lentils', 'Beans', 'Fish', 'Milk', 'Dates', 'Yogurt']
          ).map((s) => Chip(label: Text(s, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.white)), backgroundColor: AppColors.sunnahGreen, padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList()),
        ]),
      ),

      const SizedBox(height: 16),
      if (!isPremium) _premiumTeaserCard(isAr, isDark),
      const SizedBox(height: 14),
    ]);
  }

  // ── Edit panel ───────────────────────────────────────────
  Widget _editPanel(UserProfile p, bool isAr, bool isDark) {
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sunnahGreen, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAr ? '✏️ تحديث بياناتك' : '✏️ Update Your Data',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.sunnahGreen)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _editField(_wCtrl, isAr ? 'الوزن كجم' : 'Weight kg')),
          const SizedBox(width: 10),
          Expanded(child: _editField(_hCtrl, isAr ? 'الطول سم' : 'Height cm')),
          const SizedBox(width: 10),
          Expanded(child: _editField(_waistCtrl, isAr ? 'الخصر سم' : 'Waist cm')),
        ]),
      ]),
    );
  }

  Widget _editField(TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.sunnahGreen, width: 2)),
      ),
    );
  }

  Future<void> _saveEdits(UserProfile p) async {
    final w = double.tryParse(_wCtrl.text) ?? p.weightKg;
    final h = double.tryParse(_hCtrl.text) ?? p.heightCm;
    final waist = double.tryParse(_waistCtrl.text);
    final updated = p.copyWith(weightKg: w, heightCm: h, waistCm: waist);
    await ref.read(userProfileProvider.notifier).save(updated);
    ref.read(caloriesProvider.notifier).syncWithProfile(updated);
    ref.read(weightLogProvider.notifier).add(w);
    if (mounted) setState(() => _editing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(languageProvider) == 'ar' ? 'تم تحديث البيانات ✓' : 'Data Updated ✓',
            style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.sunnahGreen,
      ));
    }
  }

  // ── Reusable widgets ─────────────────────────────────────
  Widget _heroStat(String label, String value, Color color, {String subtitle = ''}) {
    return Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white70)),
      if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: Colors.white54)),
    ]);
  }

  Widget _metricCard(String label, String value, String emoji, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.lightMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _bmiScaleCard(UserProfile p, bool isAr, bool isDark, Color bg, Color textC, Color muted) {
    final bmiPct = ((p.bmi - 10) / 35).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isAr ? 'مؤشر كتلة الجسم' : 'Body Mass Index',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 14, color: textC)),
          Text('BMI: ${p.bmi.toStringAsFixed(1)}',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 18, color: _bmiColor(p.bmi))),
        ]),
        const SizedBox(height: 12),
        Stack(children: [
          Container(height: 14, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft, end: Alignment.centerRight,
              colors: [AppColors.waterBlue, AppColors.halalGreen, AppColors.doubtOrange, AppColors.haramRed],
              stops: [0.0, 0.35, 0.60, 1.0],
            ),
          )),
          Positioned(
            left: bmiPct * (MediaQuery.of(context).size.width - 56),
            top: -3,
            child: Container(width: 4, height: 20, decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4)],
            )),
          ),
        ]),
        const SizedBox(height: 5),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isAr ? 'نقص' : 'Under', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
          Text(isAr ? 'مثالي' : 'Normal', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
          Text(isAr ? 'زيادة' : 'Over', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
          Text(isAr ? 'سمنة' : 'Obese', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _bmiColor(p.bmi).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(_bmiAdvice(p, isAr),
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: textC, height: 1.6)),
        ),
      ]),
    );
  }

  Widget _weightDiffCard(UserProfile p, bool isAr, bool isDark, Color bg, Color muted) {
    final diff   = p.weightDifferenceKg;
    final isOver = diff > 0;
    final color  = isOver ? AppColors.doubtOrange : AppColors.waterBlue;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(children: [
        Text(isOver ? '⬇️' : '⬆️', style: const TextStyle(fontSize: 30)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isAr
            ? '${diff.abs().toStringAsFixed(1)} كجم ${isOver ? "للوصول للمثالي" : "للوصول للمثالي"}'
            : '${diff.abs().toStringAsFixed(1)} kg to ideal weight',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: color, fontSize: 14)),
          Text(isAr
            ? isOver ? 'يُنصح بعجز ٥٠٠ سعرة يومياً' : 'يُنصح بفائض ٣٠٠ سعرة يومياً'
            : isOver ? '500 kcal deficit recommended daily' : '300 kcal surplus recommended daily',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted)),
        ])),
      ]),
    );
  }

  // ── Body Photo Analysis Card (v1.0) ─────────────────────

  // ── WEIGHT TREND CHART ──────────────────────────────────
  Widget _weightChartCard(bool isAr, bool isDark, Color cardBg, Color muted, Color textC) {
    final log = ref.watch(weightLogProvider);
    if (log.isEmpty) {
      return GestureDetector(
        onTap: () => _showAddWeightDialog(isAr),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
          ),
          child: Column(children: [
            Text(isAr ? '📈 منحنى الوزن' : '📈 Weight Trend',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                    fontSize: 14, color: textC)),
            const SizedBox(height: 16),
            Icon(Icons.add_chart, size: 48, color: AppColors.sunnahGreen.withOpacity(0.5)),
            const SizedBox(height: 8),
            Text(isAr ? 'اضغط لتسجيل وزنك اليوم' : 'Tap to log your weight today',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted)),
          ]),
        ),
      );
    }

    final spots = log.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.weightKg)).toList();
    final minW = log.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    final maxW = log.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).clamp(1.0, 100.0);
    final first = log.first.weightKg;
    final last  = log.last.weightKg;
    final diff  = last - first;
    final trendColor = diff <= 0 ? AppColors.halalGreen : AppColors.haramRed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(isAr ? '📈 منحنى الوزن' : '📈 Weight Trend',
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                  fontSize: 14, color: textC))),
          Text(
            '${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(1)} kg',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                fontSize: 14, color: trendColor),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _showAddWeightDialog(isAr),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.sunnahGreen, borderRadius: BorderRadius.circular(20)),
              child: Text(isAr ? '+ سجّل' : '+ Log',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        SizedBox(height: 130, child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false,
                horizontalInterval: range / 3,
                getDrawingHorizontalLine: (_) => FlLine(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 36,
                getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0),
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: muted)),
              )),
              topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minY: minW - range * 0.15,
            maxY: maxW + range * 0.15,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true, curveSmoothness: 0.35,
                color: AppColors.sunnahGreen,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 4, color: AppColors.sunnahGreen,
                    strokeWidth: 2, strokeColor: Colors.white),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.sunnahGreen.withOpacity(0.08),
                ),
              ),
            ],
          ),
        )),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(isAr ? 'بداية: ${first.toStringAsFixed(1)} kg' : 'Start: ${first.toStringAsFixed(1)} kg',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: muted)),
          Text(isAr ? 'الآن: ${last.toStringAsFixed(1)} kg' : 'Now: ${last.toStringAsFixed(1)} kg',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 10,
                  fontWeight: FontWeight.w700, color: textC)),
        ]),
      ]),
    );
  }

  void _showAddWeightDialog(bool isAr) {
    final ctrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(isAr ? 'سجّل وزنك' : 'Log Your Weight',
          style: const TextStyle(fontFamily: 'Cairo')),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          hintText: isAr ? 'الوزن بالكيلوجرام' : 'Weight in kg',
          suffixText: 'kg',
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () { if (context.mounted) Navigator.pop(context); },
          child: Text(isAr ? 'إلغاء' : 'Cancel',
              style: const TextStyle(fontFamily: 'Cairo')),
        ),
        ElevatedButton(
          onPressed: () async {
            final kg = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
            if (kg == null || kg < 20 || kg > 300) return;
            await ref.read(weightLogProvider.notifier).add(kg);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(isAr ? 'حفظ' : 'Save',
              style: const TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    ));
  }

  Widget _bodyPhotoCard(bool isAr, bool isDark, bool isPremium) {
    return GestureDetector(
      onTap: () => context.push('/body-photo'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (isPremium ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.15),
              (isPremium ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.05),
            ],
          ),
          border: Border.all(
            color: (isPremium ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.6),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: (isPremium ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Center(child: Text('📸', style: TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(
                isAr ? 'تحليل الجسم بالصورة 🤖' : 'AI Body Photo Analysis 🤖',
                style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13,
                  color: isPremium ? AppColors.barakahGold : AppColors.sunnahGreen,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isPremium ? AppColors.barakahGold : AppColors.sunnahGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPremium ? (isAr ? '⭐ متاح' : '⭐ Ready') : (isAr ? 'جديد!' : 'NEW!'),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 9,
                      fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ]),
            const SizedBox(height: 3),
            Text(
              isAr
                ? 'صورة واحدة ← نسبة الدهون + كتلة العضلات + نوع الجسم'
                : 'One photo ← Body fat % + Muscle mass + Body type',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  color: AppColors.lightMuted, height: 1.4),
            ),
            if (!isPremium)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  isAr ? '🔒 يتطلب بريميوم' : '🔒 Requires Premium',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 10,
                      color: AppColors.barakahGold, fontWeight: FontWeight.w700),
                ),
              ),
          ])),
          Icon(Icons.arrow_forward_ios, size: 14,
              color: isPremium ? AppColors.barakahGold : AppColors.sunnahGreen),
        ]),
      ),
    );
  }

  Widget _premiumTeaserCard(bool isAr, bool isDark) {
    return GestureDetector(
      onTap: () => context.push('/paywall'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.barakahGold.withOpacity(0.15), AppColors.barakahGold.withOpacity(0.05)]),
          border: Border.all(color: AppColors.barakahGold, width: 1.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(children: [
          Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAr ? 'افتح بريميوم' : 'Unlock Premium',
                  style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.barakahGold)),
              Text(isAr ? 'لرؤية: نسبة الدهون الدقيقة • كتلة العضلات • الكتلة النحيفة' : 'See: Exact body fat % • Muscle mass • Lean body mass',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.lightMuted)),
            ])),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.barakahGold),
          ]),
        ]),
      ),
    );
  }

  Widget _premiumBanner(bool isAr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.barakahGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.barakahGold.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Text('🔒', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(
          isAr ? 'بعض المقاييس تتطلب بريميوم — اضغط ⭐ لفتحها' : 'Some metrics require Premium — Tap ⭐ to unlock',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.barakahGold),
        )),
        GestureDetector(
          onTap: () => context.push('/paywall'),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.barakahGold, borderRadius: BorderRadius.circular(20)),
            child: Text(isAr ? 'ترقية' : 'Upgrade',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700))),
        ),
      ]),
    );
  }

  Widget _macroRow(String label, double grams, double max, Color color, bool isAr) {
    final pct = (grams / (max > 0 ? max : 1)).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
        Text('${grams.toInt()} g', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w900, color: color)),
      ]),
      const SizedBox(height: 5),
      LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(color), borderRadius: BorderRadius.circular(6), minHeight: 8),
      Text('${(grams * _calPerGram(label)).toInt()} kcal',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.lightMuted)),
    ]);
  }

  double _calPerGram(String label) {
    if (label.contains('كربو') || label.contains('Carb')) return 4;
    if (label.contains('بروتين') || label.contains('Protein')) return 4;
    return 9; // fat
  }

  Widget _sectionTitle(String t, Color textC) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(t, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700, color: textC)),
  );

  Widget _detailRow(String label, String value, Color valueColor, String sub, Color bg, Color textC, Color muted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: textC)),
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: muted)),
        ])),
        Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: valueColor)),
      ]),
    );
  }

  Widget _infoExpandable(String title, String body, bool isDark, Color bg, Color muted) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title, style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkText : AppColors.lightText)),
      backgroundColor: bg,
      collapsedBackgroundColor: bg,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
          child: Text(body, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, height: 1.7, color: muted)),
        ),
      ],
    );
  }

  // ── Color helpers ─────────────────────────────────────────
  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.waterBlue;
    if (bmi < 25)   return AppColors.halalGreen;
    if (bmi < 30)   return AppColors.doubtOrange;
    return AppColors.haramRed;
  }

  Color _bfColor(double bf, bool isMale) {
    if (isMale) {
      if (bf < 14) return AppColors.halalGreen;
      if (bf < 25) return AppColors.doubtOrange;
      return AppColors.haramRed;
    } else {
      if (bf < 21) return AppColors.halalGreen;
      if (bf < 32) return AppColors.doubtOrange;
      return AppColors.haramRed;
    }
  }

  String _bmiAdvice(UserProfile p, bool isAr) {
    final bmi = p.bmi;
    if (isAr) {
      if (bmi < 18.5) return '⚠️ وزنك أقل من المثالي. زِد السعرات الصحية والبروتين. تناول تمراً وعسلاً وحليباً.';
      if (bmi < 25)   return '✅ وزنك مثالي! حافظ على نمطك الصحي والسنة النبوية في الأكل.';
      if (bmi < 30)   return '⚠️ وزنك أعلى من المثالي. قلّل ٥٠٠ سعرة يومياً وزِد المشي. صِم الاثنين والخميس.';
      return '❌ يُنصح بمراجعة طبيب أو أخصائي تغذية. الصيام المتقطع مفيد جداً.';
    } else {
      if (bmi < 18.5) return '⚠️ Underweight. Increase healthy calories & protein. Try dates, honey & milk.';
      if (bmi < 25)   return '✅ Ideal weight! Maintain your healthy lifestyle and Sunnah eating habits.';
      if (bmi < 30)   return '⚠️ Slightly overweight. Reduce 500 kcal/day & increase walking. Try Monday/Thursday fasting.';
      return '❌ Consult a doctor or nutritionist. Intermittent fasting is highly beneficial.';
    }
  }
}
