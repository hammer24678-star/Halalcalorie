import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../data/models/models.dart';
import '../../core/ai_service.dart';

// ── Food emoji helper ────────────────────────────────────────
String foodEmoji(String name) {
  final n = name.toLowerCase();
  if (n.contains('date') || n.contains('تمر')) return '🌴';
  if (n.contains('honey') || n.contains('عسل')) return '🍯';
  if (n.contains('olive') || n.contains('زيتون')) return '🫒';
  if (n.contains('chicken') || n.contains('دجاج')) return '🍗';
  if (n.contains('meat') || n.contains('beef') || n.contains('لحم')) return '🥩';
  if (n.contains('fish') || n.contains('سمك') || n.contains('tuna') || n.contains('تونة')) return '🐟';
  if (n.contains('egg') || n.contains('بيض')) return '🥚';
  if (n.contains('milk') || n.contains('حليب')) return '🥛';
  if (n.contains('cheese') || n.contains('جبن')) return '🧀';
  if (n.contains('yogurt') || n.contains('لبن') || n.contains('زبادي')) return '🫙';
  if (n.contains('bread') || n.contains('خبز')) return '🍞';
  if (n.contains('rice') || n.contains('أرز')) return '🍚';
  if (n.contains('pasta') || n.contains('معكرون')) return '🍝';
  if (n.contains('salad') || n.contains('سلطة')) return '🥗';
  if (n.contains('soup') || n.contains('شوربة')) return '🍲';
  if (n.contains('apple') || n.contains('تفاح')) return '🍎';
  if (n.contains('banana') || n.contains('موز')) return '🍌';
  if (n.contains('orange') || n.contains('برتقال')) return '🍊';
  if (n.contains('grape') || n.contains('عنب')) return '🍇';
  if (n.contains('water') || n.contains('ماء')) return '💧';
  if (n.contains('juice') || n.contains('عصير')) return '🧃';
  if (n.contains('coffee') || n.contains('قهوة')) return '☕';
  if (n.contains('tea') || n.contains('شاي')) return '🍵';
  if (n.contains('oat') || n.contains('شوفان')) return '🥣';
  if (n.contains('nut') || n.contains('مكسرات') || n.contains('almond') || n.contains('لوز')) return '🥜';
  if (n.contains('chocolate') || n.contains('شوكولاتة')) return '🍫';
  if (n.contains('cake') || n.contains('كيك')) return '🎂';
  if (n.contains('pizza')) return '🍕';
  if (n.contains('burger') || n.contains('برغر')) return '🍔';
  if (n.contains('sandwich') || n.contains('ساندويتش')) return '🥪';
  if (n.contains('vegetable') || n.contains('خضار') || n.contains('carrot') || n.contains('جزر')) return '🥦';
  if (n.contains('potato') || n.contains('بطاطا')) return '🥔';
  if (n.contains('tomato') || n.contains('طماطم')) return '🍅';
  return '🍽️';
}

class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});
  @override
  ConsumerState<NutritionScreen> createState() => _NutritionState();
}

class _NutritionState extends ConsumerState<NutritionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openAdd(BuildContext ctx, bool isAr, bool isDark, bool isPremium) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddFoodSheet(
        isAr: isAr,
        isDark: isDark,
        isPremium: isPremium,
        onAdd: (name, kcal, p, c, ft) async {
          try {
            await ref.read(caloriesProvider.notifier)
                .addEntry(name, kcal, proteinG: p, carbsG: c, fatG: ft);
            ref.invalidate(weeklyKcalProvider);
            ref.invalidate(weeklyKcalProvider);
          } catch (e) {
            debugPrint("addEntry error: $e");
          }
          if (ctx.mounted) Navigator.pop(ctx);
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Row(children: [
                const Text('✅ ', style: TextStyle(fontSize: 16)),
                Text('$name ${isAr ? "أضيف" : "added"}',
                    style: const TextStyle(fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700)),
              ]),
              backgroundColor: AppColors.sunnahGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ));
          }
        },
      ),
    );
  }

  void _showDetail(BuildContext ctx, MealEntry e,
      bool isAr, bool isDark, bool isPremium) {
    final bg = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : const Color(0xFF9E9E9E);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          // Food icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.sunnahGreen.withOpacity(0.2),
                         AppColors.sunnahGreen.withOpacity(0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text(foodEmoji(e.name),
                style: const TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 12),
          Text(e.name, style: const TextStyle(fontFamily: 'Cairo',
              fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(isAr ? 'القيم الغذائية' : 'Nutritional Values',
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 12, color: muted)),
          const SizedBox(height: 20),
          // 4 macro cards
          Row(children: [
            _macroCard('🔥', '${e.kcal}',
                isAr ? 'سعرة' : 'kcal', AppColors.haramRed),
            const SizedBox(width: 8),
            _macroCard('💪', '${e.proteinG.toStringAsFixed(1)}g',
                isAr ? 'بروتين' : 'Protein', AppColors.halalGreen),
            const SizedBox(width: 8),
            _macroCard('🍚', '${e.carbsG.toStringAsFixed(1)}g',
                isAr ? 'كارب' : 'Carbs', AppColors.waterBlue),
            const SizedBox(width: 8),
            _macroCard('🥑', '${e.fatG.toStringAsFixed(1)}g',
                isAr ? 'دهون' : 'Fat', AppColors.barakahGold),
          ]),
          const SizedBox(height: 16),
          // Premium micronutrients
          if (isPremium)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.barakahGold.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.barakahGold.withOpacity(0.25)),
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.barakahGold, size: 16),
                  const SizedBox(width: 6),
                  Text(isAr ? 'مغذيات دقيقة' : 'Micronutrients',
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.barakahGold)),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                  _microItem('🍊', 'Vit C',
                      '${(e.kcal * 0.1).toInt()}mg'),
                  _microItem('🩸', isAr ? 'حديد' : 'Iron',
                      '${(e.proteinG * 0.18).toStringAsFixed(1)}mg'),
                  _microItem('🥛', isAr ? 'كالسيوم' : 'Ca',
                      '${(e.kcal * 0.55).toInt()}mg'),
                  _microItem('🍌', isAr ? 'بوتاسيوم' : 'K',
                      '${(e.kcal * 1.4).toInt()}mg'),
                ]),
              ]),
            )
          else
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                ctx.push('/paywall');
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.barakahGold.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.barakahGold.withOpacity(0.25)),
                ),
                child: Row(children: [
                  const Text('⭐', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                      isAr
                          ? 'بريميوم: فيتامينات ومعادن لكل وجبة'
                          : 'Premium: Vitamins and minerals per meal',
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 11, color: AppColors.barakahGold))),
                  const Icon(Icons.chevron_right,
                      color: AppColors.barakahGold, size: 16),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () {
                ref.read(caloriesProvider.notifier).removeEntry(e.id);
                Navigator.pop(ctx);
              },
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.haramRed, size: 18),
              label: Text(isAr ? 'حذف' : 'Delete',
                  style: const TextStyle(fontFamily: 'Cairo',
                      color: AppColors.haramRed,
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.haramRed),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunnahGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(isAr ? 'إغلاق' : 'Close',
                  style: const TextStyle(fontFamily: 'Cairo',
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _macroCard(String emoji, String val, String label, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 9, color: color.withOpacity(0.8))),
        ]),
      ));

  Widget _microItem(String emoji, String label, String val) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        Text(val, style: const TextStyle(fontFamily: 'Cairo',
            fontSize: 12, fontWeight: FontWeight.w800,
            color: AppColors.barakahGold)),
        Text(label, style: const TextStyle(fontFamily: 'Cairo',
            fontSize: 9, color: AppColors.lightMuted)),
      ]);

  @override
  Widget build(BuildContext context) {
    final lang    = ref.watch(languageProvider);
    final isAr    = lang == 'ar';
    final isDark  = ref.watch(themeProvider);
    final cals    = ref.watch(caloriesProvider);
    final profile = ref.watch(userProfileProvider);
    final isPremium = ref.watch(premiumProvider);
    final bg      = isDark ? AppColors.darkBg : const Color(0xFFF2F4F7);
    final cardBg  = isDark ? AppColors.darkCard : Colors.white;
    final muted   = isDark ? AppColors.darkMuted : const Color(0xFF9E9E9E);
    final textC   = isDark ? AppColors.darkText : AppColors.lightText;
    String tl(String ar, String en) => isAr ? ar : en;

    final goal  = cals.goal;
    final eaten = cals.total;
    final left  = goal - eaten;
    final pct   = goal > 0 ? (eaten / goal).clamp(0.0, 1.0) : 0.0;
    final calCol = eaten > goal ? AppColors.haramRed
        : eaten > goal * 0.85 ? AppColors.doubtOrange
        : AppColors.sunnahGreen;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAdd(context, isAr, isDark, isPremium),
          backgroundColor: AppColors.sunnahGreen,
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
          label: Text(tl('أضف طعام', 'Add Food'),
              style: const TextStyle(fontFamily: 'Cairo',
                  color: Colors.white, fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ),
        appBar: AppBar(
          title: Text(tl('التغذية', 'Nutrition'),
              style: const TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800, fontSize: 18)),
          backgroundColor: AppColors.sunnahGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 26),
              onPressed: () => _openAdd(context, isAr, isDark, isPremium),
              tooltip: tl('أضف طعام', 'Add Food'),
            ),
          ],
          bottom: TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontFamily: 'Cairo',
                fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(
                fontFamily: 'Cairo', fontSize: 13),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: tl('اليوم', 'Today')),
              Tab(text: tl('الوصفات', 'Recipes')),
              Tab(text: tl('مخطط AI', 'AI Plan')),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            // ══ TODAY TAB ══════════════════════════════════
            RefreshIndicator(
              color: AppColors.sunnahGreen,
              onRefresh: () async {
                ref.invalidate(caloriesProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  // ── Calorie Summary Card ────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sunnahGreen.withOpacity(0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(children: [
                      // Top row: eaten | ring | burned
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryBox(
                              tl('المأكول', 'Eaten'),
                              '$eaten',
                              AppColors.sunnahGreen, isDark),
                          // Calorie ring
                          SizedBox(width: 120, height: 120,
                            child: Stack(alignment: Alignment.center,
                              children: [
                              SizedBox.expand(
                                child: CircularProgressIndicator(
                                  value: pct,
                                  strokeWidth: 11,
                                  backgroundColor:
                                      Colors.grey.shade200,
                                  valueColor:
                                      AlwaysStoppedAnimation(calCol),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(mainAxisSize: MainAxisSize.min,
                                  children: [
                                Text('${left.abs()}',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        color: calCol)),
                                Text(
                                  left < 0
                                      ? tl('تجاوزت!', 'Over!')
                                      : tl('متبقي', 'left'),
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: calCol),
                                ),
                                Text('/ $goal',
                                    style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 9,
                                        color: muted)),
                              ]),
                            ]),
                          ),
                          _summaryBox(
                              tl('المحروق', 'Burned'),
                              '0',
                              AppColors.haramRed, isDark),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      // Macro progress bars
                      _macroRow(
                        tl('بروتين', 'Protein'),
                        cals.proteinTotal,
                        profile?.proteinGrams ?? 50,
                        AppColors.halalGreen,
                      ),
                      const SizedBox(height: 10),
                      _macroRow(
                        tl('كربوهيدرات', 'Carbs'),
                        cals.carbsTotal,
                        (profile?.calorieGoalKcal ?? 2000) / 4,
                        AppColors.waterBlue,
                      ),
                      const SizedBox(height: 10),
                      _macroRow(
                        tl('دهون', 'Fat'),
                        cals.fatTotal,
                        (profile?.calorieGoalKcal ?? 2000) / 9 * 0.3,
                        AppColors.barakahGold,
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // ── Meal Sections ───────────────────────
                  _MealSection(
                    emoji: '🌅',
                    title: tl('الفطور', 'Breakfast'),
                    entries: cals.entries,
                    isAr: isAr,
                    isDark: isDark,
                    cardBg: cardBg,
                    muted: muted,
                    textC: textC,
                    onAdd: () =>
                        _openAdd(context, isAr, isDark, isPremium),
                    onTap: (e) =>
                        _showDetail(context, e, isAr, isDark, isPremium),
                    onDelete: (e) => ref
                        .read(caloriesProvider.notifier)
                        .removeEntry(e.id),
                  ),

                  _MealSection(
                    emoji: '☀️',
                    title: tl('الغداء', 'Lunch'),
                    entries: const [],
                    isAr: isAr,
                    isDark: isDark,
                    cardBg: cardBg,
                    muted: muted,
                    textC: textC,
                    onAdd: () =>
                        _openAdd(context, isAr, isDark, isPremium),
                    onTap: (_) {},
                    onDelete: (_) {},
                  ),

                  _MealSection(
                    emoji: '🌙',
                    title: tl('العشاء', 'Dinner'),
                    entries: const [],
                    isAr: isAr,
                    isDark: isDark,
                    cardBg: cardBg,
                    muted: muted,
                    textC: textC,
                    onAdd: () =>
                        _openAdd(context, isAr, isDark, isPremium),
                    onTap: (_) {},
                    onDelete: (_) {},
                  ),

                  _MealSection(
                    emoji: '🍎',
                    title: tl('وجبات خفيفة', 'Snacks'),
                    entries: const [],
                    isAr: isAr,
                    isDark: isDark,
                    cardBg: cardBg,
                    muted: muted,
                    textC: textC,
                    onAdd: () =>
                        _openAdd(context, isAr, isDark, isPremium),
                    onTap: (_) {},
                    onDelete: (_) {},
                  ),

                  const SizedBox(height: 16),

                  // ── Weekly Chart ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 12)],
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Text('📊',
                            style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(tl('السعرات الأسبوعية',
                                'Weekly Calories'),
                            style: TextStyle(fontFamily: 'Cairo',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textC)),
                      ]),
                      const SizedBox(height: 16),
                      SizedBox(height: 100,
                        child: ref.watch(weeklyKcalProvider).when(
                          loading: () => const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.sunnahGreen)),
                          error: (_, __) => Center(
                              child: Text(
                                  tl('تعذر تحميل البيانات',
                                     'Could not load data'),
                                  style: TextStyle(
                                      fontFamily: 'Cairo',
                                      color: muted))),
                          data: (data) {
                            final today = DateTime.now();
                            final days = isAr
                                ? ['أح','إث','ث','أر','خ','ج','س']
                                : ['Su','Mo','Tu','We','Th','Fr','Sa'];
                            final bars = List.generate(7, (i) {
                              final d = today.subtract(
                                  Duration(days: 6 - i));
                              final key =
                                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                              final found = data.where(
                                  (x) => x['date'] == key).toList();
                              final kcal = found.isNotEmpty
                                  ? (found.first['kcal'] as num)
                                      .toDouble()
                                  : 0.0;
                              final isToday = i == 6;
                              return BarChartGroupData(x: i,
                                  barRods: [
                                BarChartRodData(
                                  toY: kcal,
                                  color: isToday
                                      ? AppColors.sunnahGreen
                                      : AppColors.sunnahGreen
                                          .withOpacity(0.4),
                                  width: 14,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                              ]);
                            });
                            return BarChart(BarChartData(
                              barGroups: bars,
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) => Text(
                                        days[v.toInt()],
                                        style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 9,
                                            color: muted,
                                            fontWeight:
                                                v.toInt() == 6
                                                    ? FontWeight.w800
                                                    : FontWeight.normal)),
                                  ),
                                ),
                                leftTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                              ),
                            ));
                          },
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),

            // ══ RECIPES TAB ════════════════════════════════
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                Row(children: [
                  const Text('🌿', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(tl('وصفات سنية', 'Sunnah Recipes'),
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: textC)),
                    Text(tl('اضغط للإضافة', 'Tap to add'),
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 11, color: muted)),
                  ]),
                ]),
                const SizedBox(height: 14),
                ...kRecipes.map((r) {
                  final emojis = ['🥘','🫒','🥚','🫓','🌿','🍗','🥗','🫙'];
                  final em = emojis[r.id % emojis.length];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8)],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      leading: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.sunnahGreen.withOpacity(0.15),
                              AppColors.sunnahGreen.withOpacity(0.05)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(child: Text(em,
                            style: const TextStyle(fontSize: 26))),
                      ),
                      title: Text(r.nameAr,
                          style: const TextStyle(fontFamily: 'Cairo',
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          _smallChip('🔥 ${r.kcal}',
                              AppColors.haramRed),
                          const SizedBox(width: 4),
                          _smallChip('💪 ${r.proteinG}g',
                              AppColors.halalGreen),
                          const SizedBox(width: 4),
                          _smallChip('⏱ ${r.timeMins}${isAr ? "د" : "m"}',
                              AppColors.waterBlue),
                        ]),
                      ),
                      trailing: GestureDetector(
                        onTap: () {
                          ref.read(caloriesProvider.notifier)
                              .addEntry(r.nameAr, r.kcal,
                                  proteinG: r.proteinG.toDouble(),
                                  carbsG: r.carbsG.toDouble(),
                                  fatG: r.fatG.toDouble());
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${r.nameAr} ${isAr ? "أضيف ✓" : "added ✓"}',
                                  style: const TextStyle(
                                      fontFamily: 'Cairo')),
                              backgroundColor: AppColors.sunnahGreen,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              duration:
                                  const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.sunnahGreen,
                            borderRadius: BorderRadius.circular(19),
                            boxShadow: [BoxShadow(
                                color: AppColors.sunnahGreen
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3))],
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),

            // ══ AI TAB ═════════════════════════════════════
            _AIPlanTab(
                isAr: isAr, isDark: isDark,
                cardBg: cardBg, muted: muted,
                textC: textC, profile: profile,
                isPremium: isPremium),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox(String label, String val,
      Color color, bool isDark) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(val, style: TextStyle(fontFamily: 'Cairo',
            fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontFamily: 'Cairo',
            fontSize: 11, color: color.withOpacity(0.8),
            fontWeight: FontWeight.w600)),
      ]);

  Widget _macroRow(String label, double current,
      double target, Color color) {
    final pct = target > 0
        ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      SizedBox(width: 90,
          child: Text(label, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 11,
              color: AppColors.lightMuted))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: pct, minHeight: 8,
          color: color,
          backgroundColor: color.withOpacity(0.1),
        ),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 42,
          child: Text('${current.toInt()}g',
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: color),
              textAlign: TextAlign.end)),
    ]);
  }

  Widget _smallChip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontFamily: 'Cairo',
        fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

// ══════════════════════════════════════════════════════════════
// MEAL SECTION WIDGET
// ══════════════════════════════════════════════════════════════
class _MealSection extends StatefulWidget {
  final String emoji, title;
  final List<MealEntry> entries;
  final bool isAr, isDark;
  final Color cardBg, muted, textC;
  final VoidCallback onAdd;
  final void Function(MealEntry) onTap;
  final void Function(MealEntry) onDelete;

  const _MealSection({
    required this.emoji, required this.title,
    required this.entries, required this.isAr,
    required this.isDark, required this.cardBg,
    required this.muted, required this.textC,
    required this.onAdd, required this.onTap,
    required this.onDelete,
  });

  @override State<_MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<_MealSection> {
  bool _expanded = true;

  int get _totalKcal => widget.entries.fold(0, (s, e) => s + e.kcal);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Text(widget.emoji,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.title,
                    style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: widget.textC)),
                if (_totalKcal > 0)
                  Text('$_totalKcal kcal',
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.sunnahGreen,
                          fontWeight: FontWeight.w600)),
              ])),
              // Add button
              GestureDetector(
                onTap: widget.onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.sunnahGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.sunnahGreen.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded,
                        color: AppColors.sunnahGreen, size: 16),
                    const SizedBox(width: 3),
                    Text(widget.isAr ? 'أضف' : 'Add',
                        style: const TextStyle(fontFamily: 'Cairo',
                            fontSize: 11,
                            color: AppColors.sunnahGreen,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Icon(_expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: widget.muted, size: 20),
            ]),
          ),
        ),
        // Entries
        if (_expanded) ...[
          if (widget.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 14),
              child: Row(children: [
                const SizedBox(width: 32),
                Text(widget.isAr
                    ? 'لم تسجل وجبات بعد'
                    : 'No foods logged yet',
                    style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 12, color: widget.muted)),
              ]),
            )
          else ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            ...widget.entries.map((e) => Dismissible(
              key: Key('entry_${e.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.haramRed,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_rounded,
                    color: Colors.white),
              ),
              onDismissed: (_) => widget.onDelete(e),
              child: InkWell(
                onTap: () => widget.onTap(e),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    // Food icon
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.sunnahGreen.withOpacity(0.15),
                            AppColors.sunnahGreen.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(
                          foodEmoji(e.name),
                          style: const TextStyle(fontSize: 22))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(e.name, style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.textC)),
                      const SizedBox(height: 3),
                      Row(children: [
                        _miniTag('💪 ${e.proteinG.toInt()}g',
                            widget.muted),
                        const SizedBox(width: 6),
                        _miniTag('🍚 ${e.carbsG.toInt()}g',
                            widget.muted),
                        const SizedBox(width: 6),
                        _miniTag('🥑 ${e.fatG.toInt()}g',
                            widget.muted),
                      ]),
                    ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                      Text('${e.kcal}',
                          style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.sunnahGreen)),
                      Text('kcal', style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 9,
                          color: widget.muted)),
                    ]),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        color: widget.muted, size: 16),
                  ]),
                ),
              ),
            )),
          ],
        ],
      ]),
    );
  }

  Widget _miniTag(String text, Color color) => Text(text,
      style: TextStyle(fontFamily: 'Cairo',
          fontSize: 10, color: color));
}

// ══════════════════════════════════════════════════════════════
// ADD FOOD SHEET
// ══════════════════════════════════════════════════════════════
class _AddFoodSheet extends ConsumerStatefulWidget {
  final bool isAr, isDark, isPremium;
  final Future<void> Function(String, int, double, double, double) onAdd;

  const _AddFoodSheet({
    required this.isAr, required this.isDark,
    required this.isPremium, required this.onAdd,
  });

  @override
  ConsumerState<_AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends ConsumerState<_AddFoodSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl  = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _kcalCtrl    = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl   = TextEditingController();
  final _fatCtrl     = TextEditingController();
  bool _searching    = false;
  bool _adding       = false;
  Map<String, dynamic>? _aiFood;
  String _filter     = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose(); _nameCtrl.dispose();
    _kcalCtrl.dispose(); _proteinCtrl.dispose();
    _carbsCtrl.dispose(); _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() { _searching = true; _aiFood = null; });
    try {
      final lang = ref.read(languageProvider);
      final r = await AIService.lookupFood(q,
          language: lang, isPremium: widget.isPremium);
      if (mounted) setState(() { _searching = false; _aiFood = r; });
    } catch (_) {
      if (mounted) setState(() { _searching = false; });
    }
  }

    Future<void> _doAdd(String name, int kcal,
      double p, double c, double ft) async {
    final n = name.trim();
    if (n.isEmpty || kcal <= 0) return;
    if (!mounted) return;
    setState(() => _adding = true);
    try {
      await widget.onAdd(n, kcal, p, c, ft);
    } catch (e) {
      debugPrint('addEntry error: $e');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr   = widget.isAr;
    final isDark  = widget.isDark;
    final bg      = isDark ? AppColors.darkCard : Colors.white;
    final muted   = isDark ? AppColors.darkMuted : const Color(0xFF9E9E9E);
    String tl(String ar, String en) => isAr ? ar : en;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
        ),
        // Title row
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 20, vertical: 10),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sunnahGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search_rounded,
                  color: AppColors.sunnahGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Text(tl('أضف طعام', 'Add Food'),
                style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: isDark
                        ? AppColors.darkText : AppColors.lightText)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close_rounded),
                color: muted,
                onPressed: () { if (context.mounted) Navigator.pop(context)); },
          ]),
        ),
        // Tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.sunnahGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: AppColors.sunnahGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: const TextStyle(fontFamily: 'Cairo',
                fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: const TextStyle(
                fontFamily: 'Cairo', fontSize: 12),
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.sunnahGreen,
            dividerColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            tabs: [
              Tab(text: tl('🤖 AI', '🤖 AI')),
              Tab(text: tl('⚡ سريع', '⚡ Quick')),
              Tab(text: tl('✏️ يدوي', '✏️ Manual')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Tab content
        SizedBox(
          height: 400,
          child: TabBarView(controller: _tab, children: [
            // ── AI SEARCH ────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Search bar
                Row(children: [
                  Expanded(child: TextField(
                    controller: _searchCtrl,
                    textDirection: isAr
                        ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                        fontFamily: 'Cairo', fontSize: 14),
                    onSubmitted: (_) => _search(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: tl(
                          'تفاحة، دجاج، أرز...',
                          'apple, chicken, rice...'),
                      hintStyle: TextStyle(fontFamily: 'Cairo',
                          fontSize: 13, color: muted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.sunnahGreen),
                      filled: true,
                      fillColor: AppColors.sunnahGreen.withOpacity(0.05),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: AppColors.sunnahGreen,
                              width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                  )),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _searching ? null : _search,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _searching
                            ? Colors.grey
                            : AppColors.sunnahGreen,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: AppColors.sunnahGreen.withOpacity(0.3),
                            blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: _searching
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search_rounded,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                // Popular food chips
                if (_aiFood == null && !_searching) ...[
                  Align(
                    alignment: isAr
                        ? Alignment.centerRight : Alignment.centerLeft,
                    child: Text(tl('شائع:', 'Popular:'),
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 12, color: muted,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8,
                    children: (isAr
                        ? ['🌴 تمر', '🍯 عسل', '🥚 بيض',
                           '🍗 دجاج', '🥛 حليب', '🍚 أرز',
                           '🫒 زيتون', '🌾 شوفان']
                        : ['🌴 Dates', '🍯 Honey', '🥚 Egg',
                           '🍗 Chicken', '🥛 Milk', '🍚 Rice',
                           '🫒 Olive oil', '🌾 Oats'])
                        .map((s) => GestureDetector(
                      onTap: () {
                        _searchCtrl.text = s.substring(2).trim();
                        _search();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.sunnahGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.sunnahGreen
                                  .withOpacity(0.2)),
                        ),
                        child: Text(s, style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 12,
                            color: AppColors.sunnahGreen,
                            fontWeight: FontWeight.w600)),
                      ),
                    )).toList(),
                  ),
                ],
                // AI Result
                if (_aiFood != null)
                  _buildAIResult(_aiFood!, isAr, muted),
              ]),
            ),

            // ── QUICK ADD ────────────────────────────────
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: TextField(
                  onChanged: (v) =>
                      setState(() => _filter = v.toLowerCase()),
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: tl('بحث سريع...', 'Quick search...'),
                    prefixIcon: const Icon(Icons.filter_list_rounded,
                        size: 18, color: AppColors.sunnahGreen),
                    filled: true,
                    fillColor: AppColors.sunnahGreen.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.sunnahGreen)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                  ),
                ),
              ),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: kQuickFoods
                    .where((f) => _filter.isEmpty ||
                        f.name.toLowerCase().contains(_filter))
                    .map((food) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.sunnahGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(child: Text(
                        foodEmoji(food.name),
                        style: const TextStyle(fontSize: 20))),
                  ),
                  title: Text(food.name,
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '💪 ${food.proteinG}g  '
                      '🍚 ${food.carbsG}g  '
                      '🥑 ${food.fatG}g',
                      style: TextStyle(fontFamily: 'Cairo',
                          fontSize: 10, color: muted)),
                  trailing: Row(mainAxisSize: MainAxisSize.min,
                      children: [
                    Column(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                      Text('${food.kcal}',
                          style: const TextStyle(fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.sunnahGreen)),
                      const Text('kcal',
                          style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 8,
                              color: AppColors.lightMuted)),
                    ]),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _doAdd(food.name, food.kcal,
                          food.proteinG, food.carbsG, food.fatG),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.sunnahGreen,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ]),
                )).toList(),
              )),
            ]),

            // ── MANUAL ENTRY ─────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _inputField(
                  controller: _nameCtrl,
                  label: tl('اسم الطعام *', 'Food name *'),
                  icon: Icons.restaurant_rounded,
                  isAr: isAr,
                  isDark: isDark,
                  isText: true,
                ),
                const SizedBox(height: 10),
                _inputField(
                  controller: _kcalCtrl,
                  label: tl('السعرات الحرارية *', 'Calories *'),
                  icon: Icons.local_fire_department_rounded,
                  isAr: false,
                  isDark: isDark,
                  iconColor: AppColors.haramRed,
                  suffix: 'kcal',
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _miniField(
                      _proteinCtrl,
                      tl('بروتين', 'Protein'),
                      AppColors.halalGreen)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniField(
                      _carbsCtrl,
                      tl('كارب', 'Carbs'),
                      AppColors.waterBlue)),
                  const SizedBox(width: 8),
                  Expanded(child: _miniField(
                      _fatCtrl,
                      tl('دهون', 'Fat'),
                      AppColors.barakahGold)),
                ]),
                const SizedBox(height: 8),
                Text(tl('* الحقول الاختيارية بالجرام',
                         '* Optional fields in grams'),
                    style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 10, color: muted)),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _adding ? null : () {
                      final name = _nameCtrl.text.trim();
                      final kcal = int.tryParse(
                          _kcalCtrl.text.trim()) ?? 0;
                      if (name.isEmpty || kcal <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                isAr
                                    ? 'أدخل الاسم والسعرات'
                                    : 'Enter name and calories',
                                style: const TextStyle(
                                    fontFamily: 'Cairo')),
                            backgroundColor: AppColors.haramRed,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        );
                        return;
                      }
                      _doAdd(
                        name, kcal,
                        double.tryParse(_proteinCtrl.text) ?? 0,
                        double.tryParse(_carbsCtrl.text) ?? 0,
                        double.tryParse(_fatCtrl.text) ?? 0,
                      );
                    },
                    icon: _adding
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_rounded,
                            color: Colors.white),
                    label: Text(
                        tl('اضف للعداد', 'Add to Tracker'),
                        style: const TextStyle(fontFamily: 'Cairo',
                            fontSize: 15, color: Colors.white,
                            fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sunnahGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 2,
                      shadowColor:
                          AppColors.sunnahGreen.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildAIResult(Map<String, dynamic> r,
      bool isAr, Color muted) {
    final name = isAr
        ? (r['name_ar'] ?? r['name_en'] ?? '')
        : (r['name_en'] ?? r['name_ar'] ?? '');
    final kcal    = (r['kcal'] ?? 0) as num;
    final protein = (r['protein_g'] ?? 0.0) as num;
    final carbs   = (r['carbs_g'] ?? 0.0) as num;
    final fat     = (r['fat_g'] ?? 0.0) as num;
    final halal   = r['halal'] ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sunnahGreen.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.sunnahGreen.withOpacity(0.2),
            width: 1.5),
      ),
      child: Column(children: [
        // Food header
        Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.sunnahGreen.withOpacity(0.2),
                  AppColors.sunnahGreen.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(
                foodEmoji(name.toString()),
                style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(name.toString(),
                style: const TextStyle(fontFamily: 'Cairo',
                    fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(r['serving_size']?.toString() ?? '100g',
                style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 11, color: muted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: halal == true
                  ? AppColors.halalGreen.withOpacity(0.1)
                  : AppColors.doubtOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: halal == true
                    ? AppColors.halalGreen
                    : AppColors.doubtOrange,
              ),
            ),
            child: Text(
                halal == true
                    ? (isAr ? '✓ حلال' : '✓ Halal')
                    : (isAr ? '⚠️ راجع' : '⚠️ Check'),
                style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 10,
                    color: halal == true
                        ? AppColors.halalGreen
                        : AppColors.doubtOrange,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 14),
        // 4 macro boxes
        Row(children: [
          _aiMacroBox('🔥', '${kcal.round()}',
              isAr ? 'سعرة' : 'kcal', AppColors.haramRed),
          const SizedBox(width: 6),
          _aiMacroBox('💪', '${protein.toStringAsFixed(1)}g',
              isAr ? 'بروتين' : 'Protein', AppColors.halalGreen),
          const SizedBox(width: 6),
          _aiMacroBox('🍚', '${carbs.toStringAsFixed(1)}g',
              isAr ? 'كارب' : 'Carbs', AppColors.waterBlue),
          const SizedBox(width: 6),
          _aiMacroBox('🥑', '${fat.toStringAsFixed(1)}g',
              isAr ? 'دهون' : 'Fat', AppColors.barakahGold),
        ]),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _doAdd(
                name.toString(), kcal.round(),
                protein.toDouble(), carbs.toDouble(),
                fat.toDouble()),
            icon: const Icon(Icons.add_rounded,
                color: Colors.white, size: 20),
            label: Text(
                isAr ? 'اضف هذا الطعام' : 'Add This Food',
                style: const TextStyle(fontFamily: 'Cairo',
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sunnahGreen,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _aiMacroBox(String emoji, String val,
      String label, Color color) =>
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(val, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 13, fontWeight: FontWeight.w900,
              color: color)),
          Text(label, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 8, color: color.withOpacity(0.8))),
        ]),
      ));

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isAr,
    required bool isDark,
    Color? iconColor,
    String? suffix,
    bool isText = false,
  }) =>
      TextField(
        controller: controller,
        textDirection: isText && isAr
            ? TextDirection.rtl : TextDirection.ltr,
        keyboardType: isText
            ? TextInputType.text : TextInputType.number,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Cairo'),
          prefixIcon: Icon(icon,
              color: iconColor ?? AppColors.sunnahGreen, size: 20),
          suffixText: suffix,
          filled: true,
          fillColor: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.sunnahGreen, width: 2)),
        ),
      );

  Widget _miniField(TextEditingController ctrl,
      String label, Color color) =>
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(
            decimal: true),
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontFamily: 'Cairo',
              fontSize: 11, color: color),
          suffixText: 'g',
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: color, width: 2)),
          contentPadding: const EdgeInsets.symmetric(
              vertical: 8, horizontal: 10),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// AI PLAN TAB
// ══════════════════════════════════════════════════════════════
class _AIPlanTab extends ConsumerStatefulWidget {
  final bool isAr, isDark, isPremium;
  final Color cardBg, muted, textC;
  final dynamic profile;

  const _AIPlanTab({
    required this.isAr, required this.isDark,
    required this.isPremium, required this.cardBg,
    required this.muted, required this.textC,
    required this.profile,
  });

  @override ConsumerState<_AIPlanTab> createState() => _AIPlanTabState();
}

class _AIPlanTabState extends ConsumerState<_AIPlanTab> {
  final _ctrl   = TextEditingController();
  bool _loading = false;
  String? _result;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _generate() async {
    setState(() { _loading = true; _result = null; });
    final lang    = ref.read(languageProvider);
    final profile = ref.read(userProfileProvider);
    final goal    = profile?.calorieGoalKcal.toInt() ?? 2000;
    final prompt  = _ctrl.text.trim().isNotEmpty
        ? _ctrl.text.trim()
        : (lang == 'ar'
            ? 'اقترح لي خطة وجبات يومية صحية ومتوازنة ومتنوعة'
            : 'Suggest a balanced, varied, and healthy daily meal plan');
    try {
      final r = await AIService.getMealSuggestion(
        prompt: prompt, calorieGoal: goal,
        dietType: lang == 'ar' ? 'حلال' : 'Halal',
        goal: lang == 'ar' ? 'صحة عامة' : 'General health',
        language: lang,
      );
      if (mounted) setState(() { _loading = false; _result = r; });
    } catch (_) {
      if (mounted) setState(() {
        _loading = false;
        _result = 'error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    String tl(String ar, String en) => isAr ? ar : en;

    if (!widget.isPremium) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.sunnahGreen.withOpacity(0.2),
                         AppColors.sunnahGreen.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Center(
                child: Text('🤖',
                    style: TextStyle(fontSize: 52))),
          ),
          const SizedBox(height: 20),
          Text(tl('مخطط الوجبات الذكي', 'Smart Meal Planner'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: widget.textC)),
          const SizedBox(height: 8),
          Text(
              tl('خطة وجبات يومية مخصصة لجسمك وأهدافك الصحية',
                 'Daily meal plan tailored to your body and health goals'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 13, color: widget.muted, height: 1.6)),
          const SizedBox(height: 8),
          ...([
            tl('✓ خطة مخصصة لسعراتك اليومية',
               '✓ Personalized to your daily calories'),
            tl('✓ وجبات حلال 100%',
               '✓ 100% Halal meals'),
            tl('✓ مستوحاة من السنة النبوية',
               '✓ Inspired by the Sunnah'),
          ]).map((s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(s, style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 12,
                color: AppColors.sunnahGreen)),
          )),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () => context.push('/paywall'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.barakahGold,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 3,
                shadowColor: AppColors.barakahGold.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: Text(tl('🔓 افتح بريميوم', '🔓 Unlock Premium'),
                style: const TextStyle(fontFamily: 'Cairo',
                    fontSize: 16, color: Colors.white,
                    fontWeight: FontWeight.w800)),
          )),
        ]),
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12)],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Text('🤖',
                  style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(tl('مخطط الوجبات الذكي',
                        'Smart Meal Planner'),
                    style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 15, fontWeight: FontWeight.w800,
                        color: widget.textC)),
                if (widget.profile != null)
                  Text(
                      isAr
                          ? 'هدفك: ${widget.profile.calorieGoalKcal.toInt()} kcal'
                          : 'Your goal: ${widget.profile.calorieGoalKcal.toInt()} kcal',
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.sunnahGreen)),
              ])),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _ctrl,
              maxLines: 2,
              textDirection: isAr
                  ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                  fontFamily: 'Cairo', fontSize: 13),
              decoration: InputDecoration(
                hintText: isAr
                    ? 'مثال: رمضان، نباتي، قليل الكربوهيدرات...'
                    : 'e.g. Ramadan, vegetarian, low carb...',
                hintStyle: TextStyle(fontFamily: 'Cairo',
                    fontSize: 12, color: widget.muted),
                filled: true,
                fillColor: AppColors.sunnahGreen.withOpacity(0.04),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.sunnahGreen, width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sunnahGreen,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: _loading
                  ? Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(tl('جاري التوليد...', 'Generating...'),
                          style: const TextStyle(fontFamily: 'Cairo',
                              color: Colors.white)),
                    ])
                  : Text(
                      tl('✨ ولد خطة وجبات', '✨ Generate Meal Plan'),
                      style: const TextStyle(fontFamily: 'Cairo',
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w800)),
            )),
          ]),
        ),
        if (_result != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.sunnahGreen.withOpacity(0.2)),
            ),
            child: _result == 'error'
                ? Center(child: Column(children: [
                    const Text('😔',
                        style: TextStyle(fontSize: 36)),
                    const SizedBox(height: 8),
                    Text(
                        isAr ? 'حدث خطأ، حاول مجدداً'
                            : 'An error occurred, try again',
                        style: TextStyle(fontFamily: 'Cairo',
                            color: widget.muted)),
                  ]))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.sunnahGreen
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('✨',
                          style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Text(tl('خطتك الشخصية', 'Your Personal Plan'),
                        style: const TextStyle(fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.sunnahGreen)),
                  ]),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Text(_result!, style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 13,
                      height: 1.9,
                      color: widget.isDark
                          ? AppColors.darkText
                          : AppColors.lightText)),
                ]),
          ),
        ],
      ],
    );
  }
}
