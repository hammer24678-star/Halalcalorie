import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../data/models/models.dart';

import '../../core/ai_service.dart';

enum MealType { breakfast, lunch, dinner, snack }




// ── Sunnah foods database ────────────────────────────────────
const _kSunnahFoodsData = <String, (String, String, String)>{
  'تمر':         ('🌴', 'من تصبّح بسبع تمرات — النبي ﷺ', 'Eat 7 dates every morning — Prophet ﷺ'),
  'date':         ('🌴', 'من تصبّح بسبع تمرات — النبي ﷺ', 'Eat 7 dates every morning — Prophet ﷺ'),
  'عسل':          ('🍯', 'فيه شفاء للناس — القرآن الكريم', 'In it is healing for people — Quran'),
  'honey':        ('🍯', 'فيه شفاء للناس — القرآن الكريم', 'In it is healing for people — Quran'),
  'زيتون':        ('🫒', 'كلوا الزيت وادهنوا به — النبي ﷺ', 'Eat olive oil — Prophet ﷺ'),
  'olive':        ('🫒', 'كلوا الزيت وادهنوا به — النبي ﷺ', 'Eat olive oil — Prophet ﷺ'),
  'حبة سوداء':  ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ', 'Cure for every disease — Prophet ﷺ'),
  'black seed':   ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ', 'Cure for every disease — Prophet ﷺ'),
  'حليب':         ('🥛', 'فإن اللبن يملأ البطن — النبي ﷺ', 'Milk fills the stomach — Prophet ﷺ'),
  'milk':         ('🥛', 'فإن اللبن يملأ البطن — النبي ﷺ', 'Milk fills the stomach — Prophet ﷺ'),
  'تين':          ('🍑', 'فاكهة الجنة — النبي ﷺ', 'Fruit of paradise — Prophet ﷺ'),
  'fig':          ('🍑', 'فاكهة الجنة — النبي ﷺ', 'Fruit of paradise — Prophet ﷺ'),
  'رمان':         ('🍉', 'ما من رمانة إلا وفيها حبة من الجنة — النبي ﷺ', 'Every pomegranate has a seed from paradise — Prophet ﷺ'),
  'pomegranate':  ('🍉', 'ما من رمانة إلا وفيها حبة من الجنة — النبي ﷺ', 'Every pomegranate has a seed from paradise — Prophet ﷺ'),
  'شعير':         ('🌾', 'عليكم بالشعير — النبي ﷺ', 'Use barley — Prophet ﷺ'),
  'barley':       ('🌾', 'عليكم بالشعير — النبي ﷺ', 'Use barley — Prophet ﷺ'),
};

(String, String, String)? _checkSunnahFood(String name) {
  final n = name.toLowerCase();
  for (final e in _kSunnahFoodsData.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return null;
}

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
    with TickerProviderStateMixin {
  late TabController _tab;
  late AnimationController _stagger;

  // Silky smooth stagger helpers
  Animation<double> _fade(int i) => CurvedAnimation(
      parent: _stagger,
      curve: Interval(
          (i * 0.08).clamp(0.0, 0.7),
          ((i * 0.08) + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutQuart));
  Animation<Offset> _slide(int i) => Tween<Offset>(
      begin: const Offset(0, 0.10), end: Offset.zero
  ).animate(CurvedAnimation(
      parent: _stagger,
      curve: Interval(
          (i * 0.08).clamp(0.0, 0.7),
          ((i * 0.08) + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutQuart)));
  Widget _anim(int i, Widget child) => FadeTransition(
      opacity: _fade(i),
      child: SlideTransition(position: _slide(i), child: child));

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() {
      setState(() {});
      _stagger.forward(from: 0);
    });
    _stagger = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700))
      ..forward();
  }

  @override
  void dispose() {
    _tab.dispose();
    _stagger.dispose();
    super.dispose();
  }




  MealType _mealType(DateTime t) {
    final h = t.hour;
    if (h >= 4  && h < 10) return MealType.breakfast;
    if (h >= 10 && h < 15) return MealType.lunch;
    if (h >= 15 && h < 21) return MealType.dinner;
    return MealType.snack;
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
          } catch (e) {
            debugPrint("addEntry error: $e");
          }
          final messenger = ScaffoldMessenger.of(ctx);
          if (ctx.mounted) Navigator.pop(ctx);
          final sunnah = _checkSunnahFood(name);
          messenger.showSnackBar(SnackBar(
              content: sunnah != null
                ? Column(mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Row(children: [
                      Text(sunnah.$1,
                        style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(isAr ? '🌿 طعام سنة نبوية!' : '🌿 Sunnah Food!',
                        style: const TextStyle(fontFamily: 'Cairo',
                            fontWeight: FontWeight.w800, fontSize: 14,
                            color: Colors.white)),
                    ]),
                    const SizedBox(height: 3),
                    Text(isAr ? sunnah.$2 : sunnah.$3,
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 11, color: Colors.white70, height: 1.3)),
                  ])
                : Row(children: [
                    const Text('✅ ', style: TextStyle(fontSize: 16)),
                    Text('$name ${isAr ? "أضيف" : "added"}',
                        style: const TextStyle(fontFamily: 'Cairo',
                            fontWeight: FontWeight.w700)),
                  ]),
              backgroundColor: sunnah != null
                ? const Color(0xFF8B6914)
                : AppColors.sunnahGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: Duration(seconds: sunnah != null ? 4 : 2),
            ));
        },
      ),
    );
  }

  void _showDetail(BuildContext ctx, MealEntry e,
      bool isAr, bool isDark, bool isPremium) {
    final bg    = isDark ? AppColors.darkCard  : Colors.white;
    final muted = isDark ? AppColors.darkMuted : const Color(0xFF9E9E9E);
    final textC = isDark ? AppColors.darkText  : AppColors.lightText;
    final profile = ref.read(userProfileProvider);
    final goal  = (profile?.calorieGoalKcal ?? 2000).toDouble();
    final pGoal = goal * 0.125;  // protein grams ~25% of kcal /4
    final cGoal = goal * 0.25;   // carb grams ~50% of kcal /4
    final fGoal = goal / 9 * 0.30;
    final pctKcal = goal > 0 ? (e.kcal     / goal ).clamp(0.0,1.0) : 0.0;
    final pctP    = pGoal > 0 ? (e.proteinG / pGoal).clamp(0.0,1.0) : 0.0;
    final pctC    = cGoal > 0 ? (e.carbsG   / cGoal).clamp(0.0,1.0) : 0.0;
    final pctF    = fGoal > 0 ? (e.fatG     / fGoal).clamp(0.0,1.0) : 0.0;

    final tags = <Map<String,dynamic>>[];
    if (e.proteinG >= 20) tags.add({'l':isAr?'بروتين عالٍ':'High Protein','c':AppColors.halalGreen,'e':'💪'});
    if (e.carbsG   <= 10) tags.add({'l':isAr?'كارب منخفض':'Low Carb',    'c':AppColors.waterBlue,'e':'🥗'});
    if (e.fatG     <=  5) tags.add({'l':isAr?'دهون منخفضة':'Low Fat',    'c':AppColors.barakahGold,'e':'✨'});
    if (e.kcal     <= 150) tags.add({'l':isAr?'خفيف':'Light',            'c':AppColors.sunnahGreen,'e':'🌿'});
    if (e.kcal     >= 500) tags.add({'l':isAr?'سعرات عالية':'High Cal',  'c':AppColors.haramRed,'e':'🔥'});

    String islamicNote() {
      final n = e.name.toLowerCase();
      if (n.contains('date')||n.contains('تمر'))
        return isAr?'«أفطروا على تمر» — النبي ﷺ أوصى بالتمر'
                   :'"Break fast with dates" — Prophet ﷺ';
      if (n.contains('honey')||n.contains('عسل'))
        return isAr?'«فيه شفاء للناس» — القرآن الكريم 16:69'
                   :'"In it is healing for people" — Quran 16:69';
      if (n.contains('olive')||n.contains('زيتون'))
        return isAr?'«كلوا الزيت وادهنوا به» — الزيتون مبارك'
                   :'"Eat olive oil" — blessed in the Sunnah';
      if (n.contains('milk')||n.contains('حليب'))
        return isAr?'الحليب غذاء متكامل — ذكره النبي ﷺ'
                   :'Milk is a complete food — praised in Sunnah';
      if (n.contains('fish')||n.contains('سمك'))
        return isAr?'السمك حلال — من أطيب المأكولات الإسلامية'
                   :'Fish is halal — highly recommended in Islam';
      if (n.contains('meat')||n.contains('chicken')||n.contains('لحم')||n.contains('دجاج'))
        return isAr?'تأكد من المصدر الحلال — الذبح الشرعي شرط'
                   :'Verify halal source — Islamic slaughter required';
      return isAr?'«كلوا من طيبات ما رزقناكم» — البقرة 172'
                 :'"Eat of the good things We provided" — 2:172';
    }

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28))),
          child: ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)))),

              // Hero
              Row(children: [
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.sunnahGreen.withOpacity(0.18),
                      AppColors.sunnahGreen.withOpacity(0.04)]),
                    borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Text(foodEmoji(e.name),
                      style: const TextStyle(fontSize: 36)))),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(e.name, style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 19,
                      fontWeight: FontWeight.w900, color: textC)),
                  const SizedBox(height: 6),
                  if (tags.isNotEmpty) Wrap(spacing: 5, runSpacing: 4,
                    children: tags.map((t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (t['c'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: (t['c'] as Color).withOpacity(0.3))),
                      child: Text('${t["e"]} ${t["l"]}',
                          style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 9, fontWeight: FontWeight.w700,
                              color: t['c'] as Color)),
                    )).toList()),
                ])),
              ]),
              const SizedBox(height: 18),

              // Calorie ring
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.sunnahGreen.withOpacity(0.08),
                    AppColors.sunnahGreen.withOpacity(0.02)]),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.sunnahGreen.withOpacity(0.15))),
                child: Row(children: [
                  SizedBox(width: 88, height: 88,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox.expand(child: CircularProgressIndicator(
                        value: pctKcal, strokeWidth: 9,
                        backgroundColor: Colors.grey.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation(
                            AppColors.sunnahGreen),
                        strokeCap: StrokeCap.round)),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${e.kcal}', style: const TextStyle(
                            fontFamily: 'Cairo', fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.sunnahGreen)),
                        Text(isAr?'سعرة':'kcal', style: TextStyle(
                            fontFamily: 'Cairo', fontSize: 9,
                            color: muted)),
                      ]),
                    ])),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${(pctKcal*100).toInt()}%',
                        style: const TextStyle(fontFamily: 'Cairo',
                            fontSize: 32, fontWeight: FontWeight.w900,
                            color: AppColors.sunnahGreen)),
                    Text(isAr?'من هدفك اليومي':'of your daily goal',
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 11, color: muted)),
                    const SizedBox(height: 4),
                    Text('${goal.toInt()} ${isAr?"سعرة كهدف":"kcal goal"}',
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 11,
                            color: muted.withOpacity(0.7))),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),

              // Macros
              Text(isAr?'🔬 المغذيات الكبرى':'🔬 Macronutrients',
                  style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: textC)),
              const SizedBox(height: 10),
              _detailBar(isAr?'بروتين':'Protein', e.proteinG,
                  pGoal, pctP, AppColors.halalGreen,
                  isAr?'💪 يبني العضلات':'💪 Builds muscle', isDark),
              const SizedBox(height: 8),
              _detailBar(isAr?'كربوهيدرات':'Carbs', e.carbsG,
                  cGoal, pctC, AppColors.waterBlue,
                  isAr?'⚡ طاقة سريعة':'⚡ Quick energy', isDark),
              const SizedBox(height: 8),
              _detailBar(isAr?'دهون':'Fat', e.fatG,
                  fGoal, pctF, AppColors.barakahGold,
                  isAr?'🧠 صحة الدماغ':'🧠 Brain health', isDark),
              const SizedBox(height: 16),

              // Micronutrients
              Text(isAr?'🧪 مغذيات دقيقة (تقديرية)'
                       :'🧪 Micronutrients (estimated)',
                  style: TextStyle(fontFamily: 'Cairo',
                      fontSize: 14, fontWeight: FontWeight.w800,
                      color: textC)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.barakahGold.withOpacity(
                      isDark?0.07:0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.barakahGold.withOpacity(0.2))),
                child: Wrap(spacing: 8, runSpacing: 12,
                  children: [
                    _microTile('🍊','Vit C','${(e.kcal*0.10).toInt()}mg',muted),
                    _microTile('🩸',isAr?'حديد':'Iron','${(e.proteinG*0.18).toStringAsFixed(1)}mg',muted),
                    _microTile('🥛',isAr?'كالسيوم':'Ca','${(e.kcal*0.55).toInt()}mg',muted),
                    _microTile('🍌',isAr?'بوتاسيوم':'K','${(e.kcal*1.4).toInt()}mg',muted),
                    _microTile('☀️',isAr?'فيت د':'Vit D','${(e.fatG*0.8).toStringAsFixed(1)}µg',muted),
                    _microTile('🫁',isAr?'ماغنيسيوم':'Mg','${(e.proteinG*1.2).toInt()}mg',muted),
                  ])),
              const SizedBox(height: 16),

              // Islamic note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sunnahGreen.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.sunnahGreen.withOpacity(0.2))),
                child: Row(children: [
                  const Text('📖', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(islamicNote(),
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 12, color: AppColors.sunnahGreen,
                          height: 1.6, fontStyle: FontStyle.italic))),
                ]),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    ref.read(caloriesProvider.notifier).removeEntry(e.id);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.haramRed, size: 18),
                  label: Text(isAr?'حذف':'Delete',
                      style: const TextStyle(fontFamily: 'Cairo',
                          color: AppColors.haramRed,
                          fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.haramRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () {
                    ref.read(caloriesProvider.notifier).addEntry(
                        e.name, e.kcal,
                        proteinG: e.proteinG,
                        carbsG:   e.carbsG,
                        fatG:     e.fatG);
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.add_circle_outline,
                      color: Colors.white, size: 18),
                  label: Text(isAr?'أضف مرة أخرى':'Log Again',
                      style: const TextStyle(fontFamily: 'Cairo',
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sunnahGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailBar(String label, double val, double goal,
      double pct, Color color, String note, bool isDark) {
    final bg = isDark ? AppColors.darkCard : Colors.white;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.08), blurRadius: 10)],
        border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          Text(label, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const Spacer(),
          Text('${val.toStringAsFixed(1)}g / ${goal.toInt()}g',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Text('${(pct*100).toInt()}%',
                style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: color))),
        ]),
        const SizedBox(height: 6),
        Stack(children: [
          Container(height: 8, decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(6))),
          LayoutBuilder(builder: (_, c) => Container(
            height: 8, width: c.maxWidth * pct,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color.withOpacity(0.6), color]),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [BoxShadow(
                  color: color.withOpacity(0.3), blurRadius: 4)]))),
        ]),
        const SizedBox(height: 5),
        Text(note, style: TextStyle(fontFamily: 'Cairo',
            fontSize: 10, color: color.withOpacity(0.75))),
      ]),
    );
  }

  Widget _microTile(String emoji, String label,
      String val, Color muted) =>
      SizedBox(width: 80, child: Column(
          mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(fontFamily: 'Cairo',
            fontSize: 12, fontWeight: FontWeight.w800,
            color: AppColors.barakahGold)),
        Text(label, style: TextStyle(
            fontFamily: 'Cairo', fontSize: 9, color: muted)),
      ]));


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
    final plan    = ref.watch(macroPlanProvider);
    final isPremium  = ref.watch(premiumProvider);
    final burnedKcal = ref.watch(caloriesBurnedTodayProvider).round();
    final bg         = isDark ? AppColors.darkBg : const Color(0xFFF2F4F7);
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
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A6B3C), AppColors.sunnahGreen],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(tl('التغذية', 'Nutrition'),
              style: const TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800, fontSize: 18)),
          backgroundColor: Colors.transparent,
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
                fontWeight: FontWeight.w700, fontSize: 14),
            unselectedLabelStyle: const TextStyle(
                fontFamily: 'Cairo', fontSize: 14),
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
                  // ── Date + Greeting Header ──
                  _anim(0, Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(() {
                              final h = DateTime.now().hour;
                              if (h < 12) return tl('صباح الخير ☀️', 'Good Morning ☀️');
                              if (h < 17) return tl('نهارك سعيد 🌟', 'Good Afternoon 🌟');
                              return tl('مساء الخير 🌙', 'Good Evening 🌙');
                            }(),
                            style: TextStyle(fontFamily: 'Cairo',
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: textC)),
                            Text(
                              DateFormat(isAr ? 'EEEE، d MMMM' : 'EEEE, MMMM d',
                                  isAr ? 'ar' : 'en').format(DateTime.now()),
                              style: TextStyle(fontFamily: 'Cairo',
                                  fontSize: 11, color: muted)),
                          ]),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.sunnahGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.sunnahGreen.withOpacity(0.3)),
                          ),
                          child: Text('🎯 $goal ${tl(" سعرة", "kcal")}',
                            style: const TextStyle(fontFamily: 'Cairo',
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: AppColors.sunnahGreen)),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),

                  // ── Bismillah reminder (shown when no meals yet) ──
                  if (cals.entries.isEmpty)
                    _anim(0, Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.sunnahGreen.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.sunnahGreen.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Text('🌿',
                            style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          tl('بسم الله قبل الأكل، وكل بيمينك 🍽️',
                             'Say Bismillah before eating, eat with your right hand 🍽️'),
                          style: const TextStyle(
                              fontFamily: 'Cairo', fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sunnahGreen, height: 1.4),
                        )),
                      ]),
                    )),


        // ── Calorie Summary Card ────────────────
                  _anim(0, Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: calCol.withOpacity(0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(children: [
                      // Plan badge
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isAr ? plan.nameAr() : plan.nameEn(),
                              style: const TextStyle(fontFamily: 'Cairo',
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: AppColors.sunnahGreen)),
                            Text(plan.emoji(),
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
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
                              '$burnedKcal',
                              AppColors.haramRed, isDark),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      // Macro plan chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: MacroPlan.values.map((p) {
                            final sel = p == plan;
                            return GestureDetector(
                              onTap: () => ref.read(macroPlanProvider.notifier).set(p),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 6, bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sel ? AppColors.sunnahGreen : Colors.transparent,
                                  border: Border.all(
                                    color: sel ? AppColors.sunnahGreen : AppColors.lightMuted.withOpacity(0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${p.emoji()} ${isAr ? p.nameAr() : p.nameEn()}',
                                  style: TextStyle(
                                    fontFamily: 'Cairo', fontSize: 11,
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                                    color: sel ? Colors.white : muted,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Macro progress bars (plan-based goals)
                      _macroRow(
                        tl('بروتين', 'Protein'),
                        cals.proteinTotal,
                        (goal * plan.proteinPct / 100) / 4,
                        AppColors.halalGreen,
                      ),
                      const SizedBox(height: 10),
                      _macroRow(
                        tl('كربوهيدرات', 'Carbs'),
                        cals.carbsTotal,
                        (goal * plan.carbsPct / 100) / 4,
                        AppColors.waterBlue,
                      ),
                      const SizedBox(height: 10),
                      _macroRow(
                        tl('دهون', 'Fat'),
                        cals.fatTotal,
                        (goal * plan.fatPct / 100) / 9,
                        AppColors.barakahGold,
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        const Text('💧', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tl('الماء', 'Water'),
                                  style: TextStyle(fontFamily: 'Cairo',
                                    fontSize: 12, fontWeight: FontWeight.w600,
                                    color: AppColors.waterBlue)),
                                Text('${ref.watch(waterProvider).cups} / ${ref.watch(waterProvider).goal}  •  ${(ref.watch(waterProvider).percent * 100).toInt()}%',
                                  style: TextStyle(fontFamily: 'Cairo',
                                    fontSize: 10,
                                    color: AppColors.waterBlue.withOpacity(0.75))),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: ref.watch(waterProvider).percent,
                                backgroundColor: AppColors.waterBlue.withOpacity(0.12),
                                valueColor: const AlwaysStoppedAnimation(
                                    AppColors.waterBlue),
                                minHeight: 10,
                              ),
                            ),
                          ],
                        )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => ref.read(waterProvider.notifier).add(),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.waterBlue.withOpacity(0.15),
                              shape: BoxShape.circle),
                            child: const Icon(Icons.add,
                                color: AppColors.waterBlue, size: 18)),
                        ),
                      ]),
                    ]),          // end macro Column
                  ),            // end Padding
                  ]),           // end outer Column
                )),             // end Container + _anim

                  const SizedBox(height: 16),

                  // ── Meal Sections ───────────────────────
                  _anim(1, _MealSection(
                    emoji: '🌅',
                    title: tl('الفطور', 'Breakfast'),
                    entries: cals.entries.where((e) => _mealType(e.time) == MealType.breakfast).toList(),
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
                  )),

                  _anim(2, _MealSection(
                    emoji: '☀️',
                    title: tl('الغداء', 'Lunch'),
                    entries: cals.entries.where((e) => _mealType(e.time) == MealType.lunch).toList(),
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
                  )),

                  _anim(3, _MealSection(
                    emoji: '🌙',
                    title: tl('العشاء', 'Dinner'),
                    entries: cals.entries.where((e) => _mealType(e.time) == MealType.dinner).toList(),
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
                  )),

                  _anim(4, _MealSection(
                    emoji: '🍎',
                    title: tl('وجبات خفيفة', 'Snacks'),
                    entries: cals.entries.where((e) => _mealType(e.time) == MealType.snack).toList(),
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
                  )),

                  const SizedBox(height: 16),

                  // ── Weekly Chart ────────────────────────
                  _anim(5, Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sunnahGreen.withOpacity(0.08),
                          blurRadius: 16, offset: const Offset(0, 4)),
                      ],
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
                  )),
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
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(val, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontFamily: 'Cairo',
              fontSize: 10, color: color.withOpacity(0.85),
              fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _macroRow(String label, double current,
      double target, Color color) {
    final pct = target > 0
        ? (current / target).clamp(0.0, 1.0) : 0.0;
    final pctInt = (pct * 100).toInt();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontFamily: 'Cairo',
            fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        Text('${current.toInt()}g / ${target.toInt()}g  •  $pctInt%',
            style: TextStyle(fontFamily: 'Cairo',
                fontSize: 10, color: color.withOpacity(0.75))),
      ]),
      const SizedBox(height: 5),
      Stack(children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        LayoutBuilder(builder: (_, constraints) => AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          height: 10,
          width: constraints.maxWidth * pct,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.centerLeft, end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 4, offset: const Offset(0, 1),
            )],
          ),
        )),
      ]),
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

  Widget _weeklyReportCard(bool isAr, bool isDark, bool isPremium) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final goal  = ref.read(caloriesProvider).goal;
    String t(String ar, String en) => isAr ? ar : en;

    if (!isPremium) {
      return GestureDetector(
        onTap: () => context.push('/paywall'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.barakahGold.withOpacity(0.13),
              AppColors.barakahGold.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.barakahGold.withOpacity(0.45))),
          child: Row(children: [
            const Text('📊', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('تقرير الأسبوع 🔒', 'Weekly Report 🔒'),
                  style: const TextStyle(fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: AppColors.barakahGold)),
                Text(t('متوسط سعرات • التزام • أفضل يوم — بريميوم',
                  'Avg calories • Adherence • Best day — Premium'),
                  style: TextStyle(fontFamily: 'Cairo',
                    fontSize: 11, color: muted)),
              ])),
            const Icon(Icons.arrow_forward_ios,
              size: 13, color: AppColors.barakahGold),
          ]),
        ),
      );
    }

    final entries = ref.watch(caloriesProvider).entries;
    final now     = DateTime.now();
    final Map<String, int> byDay = {};
    for (int i = 0; i < 7; i++) {
      final d   = now.subtract(Duration(days: i));
      final key = '${d.month}/${d.day}';
      byDay[key] = 0;
    }
    for (final e in entries) {
      final daysAgo = now.difference(e.time).inDays;
      if (daysAgo < 7) {
        final key = '${e.time.month}/${e.time.day}';
        byDay[key] = ((byDay[key] ?? 0) + e.kcal).toInt();
      }
    }
    final vals      = byDay.values.toList();
    final avgKcal   = vals.isEmpty ? 0
        : vals.reduce((a, b) => a + b) ~/ vals.length;
    final goodDays  = vals.where(
        (v) => (v - goal).abs() < goal * 0.15).length;
    final adherePct = vals.isEmpty ? 0
        : goodDays * 100 ~/ vals.length;
    final bestDay   = vals.isEmpty ? 0
        : vals.reduce((a, b) => a > b ? a : b);
    final bestKey   = vals.isEmpty ? '-'
        : byDay.entries.firstWhere((e) => e.value == bestDay).key;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.sunnahGreen.withOpacity(0.25)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('تقرير الأسبوع ⭐', 'Weekly Report ⭐'),
            style: const TextStyle(fontFamily: 'Cairo',
              fontWeight: FontWeight.w800, fontSize: 14,
              color: AppColors.sunnahGreen)),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
            _weekStat('🔥', '$avgKcal',
              t('متوسط', 'Avg'), AppColors.haramRed, isDark),
            _weekStat('🎯', '$adherePct%',
              t('التزام', 'Adhere'), AppColors.sunnahGreen, isDark),
            _weekStat('📅', bestKey,
              t('أفضل', 'Best'), AppColors.barakahGold, isDark),
            _weekStat('✅', '$goodDays/${vals.isEmpty ? 7 : vals.length}',
              t('ملتزم', 'OnTarget'), AppColors.waterBlue, isDark),
          ]),
        ]),
    );
  }

  Widget _weekStat(String emoji, String val, String label,
      Color col, bool isDark) =>
    Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      Text(val, style: TextStyle(fontFamily: 'Cairo',
        fontWeight: FontWeight.w800, fontSize: 13, color: col)),
      Text(label, style: TextStyle(fontFamily: 'Cairo',
        fontSize: 9,
        color: isDark ? AppColors.darkMuted : AppColors.lightMuted)),
    ]);
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
    final accentCol = widget.emoji == '🌅'
        ? const Color(0xFFFF8C42)
        : widget.emoji == '☀️'
        ? const Color(0xFFDAA520)
        : widget.emoji == '🌙'
        ? const Color(0xFF6B7FD4)
        : AppColors.halalGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: accentCol.withOpacity(0.10),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
        border: Border(
          left: BorderSide(color: accentCol, width: 3.5),
        ),
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
                    color: accentCol.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: accentCol.withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded,
                        color: accentCol, size: 16),
                    const SizedBox(width: 3),
                    Text(widget.isAr ? 'أضف' : 'Add',
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 11,
                            color: accentCol,
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
        // Bismillah reminder — unique HalalCalorie touch
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.sunnahGreen.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.sunnahGreen.withOpacity(0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🤲', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 8),
            Text(
              tl('قُل بسم الله قبل الأكل', 'Say Bismillah before eating'),
              style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 11,
                color: AppColors.sunnahGreen,
                fontWeight: FontWeight.w700),
            ),
          ]),
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
                onPressed: () { if (context.mounted) Navigator.pop(context); },
            ),
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
                           '🫒 زيتون', '🌾 شوفان', '🍬 حلوى',
                           '🎂 كيك', '🍫 شوكولاتة']
                        : ['🌴 Dates', '🍯 Honey', '🥚 Egg',
                           '🍗 Chicken', '🥛 Milk', '🍚 Rice',
                           '🫒 Olive oil', '🌾 Oats', '🍬 Sweets',
                           '🎂 Cake', '🍫 Chocolate'])
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
                        f.name.toLowerCase().contains(_filter) ||
                        f.nameEn.toLowerCase().contains(_filter))
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
                  title: Text(isAr ? food.name : food.nameEn,
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
                      onTap: () => _showUnitPicker(name: isAr ? food.name : food.nameEn, kcal100: food.kcal.toDouble(), protein100: food.proteinG, carbs100: food.carbsG, fat100: food.fatG),
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

  // ── Unit Picker ─────────────────────────────────────────────────────────────

  /// Smart grams-per-piece lookup based on food name keywords
  double _pieceToGrams(String name) {
    final n = name.toLowerCase();
    if (n.contains('تمر')    || n.contains('date'))     return 7;
    if (n.contains('موز')    || n.contains('banana'))   return 120;
    if (n.contains('تفاح')   || n.contains('apple'))    return 182;
    if (n.contains('برتقال') || n.contains('orange'))   return 131;
    if (n.contains('بيض')    || n.contains('egg'))      return 55;
    if (n.contains('كيوي')   || n.contains('kiwi'))     return 70;
    if (n.contains('خيار')   || n.contains('cucumber')) return 200;
    if (n.contains('طماطم')  || n.contains('tomato'))   return 123;
    if (n.contains('فلفل')   || n.contains('pepper'))   return 90;
    if (n.contains('خوخ')    || n.contains('peach'))    return 150;
    if (n.contains('إجاص')   || n.contains('pear'))     return 166;
    if (n.contains('مانجو')  || n.contains('mango'))    return 200;
    if (n.contains('بطيخ')   || n.contains('watermelon')) return 280;
    return 50;
  }

  /// Smart grams-per-cup lookup (liquids ~240ml, solids ~150g)
  double _cupToGrams(String name) {
    final n = name.toLowerCase();
    if (n.contains('حليب')   || n.contains('milk'))    return 244;
    if (n.contains('عصير')   || n.contains('juice'))   return 248;
    if (n.contains('ماء')    || n.contains('water'))   return 240;
    if (n.contains('شاي')    || n.contains('tea'))     return 240;
    if (n.contains('قهوة')   || n.contains('coffee'))  return 240;
    if (n.contains('زبادي')  || n.contains('yogurt'))  return 245;
    if (n.contains('دبس')    || n.contains('molasses')) return 340;
    return 150;
  }

  /// Opens the unit picker bottom sheet — called instead of _doAdd directly
  void _showUnitPicker({
    required String name,
    required double kcal100,
    required double protein100,
    required double carbs100,
    required double fat100,
  }) {
    final isAr   = widget.isAr;
    final isDark = widget.isDark;
    final amtCtrl = TextEditingController(text: '100');
    int unitIdx   = 0; // 0=g 1=piece 2=cup 3=tbsp 4=tsp 5=ml

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          // ── Config per unit ───────────────────────────────────
          final unitLabels = isAr
              ? ['جرام', 'حبة', 'كوب', 'م.ك', 'م.ص', 'مل']
              : ['g', 'piece', 'cup', 'tbsp', 'tsp', 'ml'];
          final unitDefaults = [100.0, 1.0, 1.0, 1.0, 1.0, 100.0];
          final chipSets = [
            [25, 50, 100, 150, 200, 300],
            [1, 2, 3, 4, 5],
            [0.25, 0.5, 1.0, 1.5, 2.0],
            [1, 2, 3, 4, 5, 6],
            [1, 2, 3, 4, 5],
            [50, 100, 150, 200, 250, 300],
          ];

          // ── Convert selected amount to grams ──────────────────
          double toGrams(int ui, double amt) {
            switch (ui) {
              case 0:  return amt;
              case 1:  return amt * _pieceToGrams(name);
              case 2:  return amt * _cupToGrams(name);
              case 3:  return amt * 15.0;
              case 4:  return amt * 5.0;
              case 5:  return amt;
              default: return amt;
            }
          }

          // ── Live macro calculation ─────────────────────────────
          final raw   = double.tryParse(amtCtrl.text) ?? unitDefaults[unitIdx];
          final grams = toGrams(unitIdx, raw).clamp(0.1, 10000.0);
          final scale = grams / 100.0;
          final kcal  = (kcal100    * scale).round();
          final prot  = protein100  * scale;
          final carb  = carbs100    * scale;
          final fat   = fat100      * scale;

          // ── Theme ─────────────────────────────────────────────
          final bg    = isDark ? AppColors.darkCard  : Colors.white;
          final muted = isDark ? AppColors.darkMuted : const Color(0xFF9E9E9E);
          final textC = isDark ? AppColors.darkText  : AppColors.lightText;
          String tl(String ar, String en) => isAr ? ar : en;

          // ── Step size per unit ────────────────────────────────
          final step = unitIdx == 2
              ? 0.25
              : (unitIdx == 0 || unitIdx == 5 ? 10.0 : 1.0);
          final minV = unitIdx == 2 ? 0.25 : 1.0;

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28))),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Handle bar
                Center(child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),

                // Food row
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.sunnahGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(foodEmoji(name),
                        style: const TextStyle(fontSize: 26)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 15,
                            fontWeight: FontWeight.w800, color: textC),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        '${tl("أساس 100ج — ", "Base 100g — ")}${kcal100.round()} ${tl("سعرة", "kcal")}',
                        style: TextStyle(fontFamily: 'Cairo',
                            fontSize: 10, color: muted)),
                    ])),
                ]),
                const SizedBox(height: 18),

                // ── Unit selector ─────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.sunnahGreen.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.all(4),
                  child: Row(children: List.generate(
                    unitLabels.length, (i) => Expanded(
                      child: GestureDetector(
                        onTap: () {
                          final d = unitDefaults[i];
                          amtCtrl.text = d % 1 == 0
                              ? d.toInt().toString()
                              : d.toString();
                          setS(() => unitIdx = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: unitIdx == i
                                ? AppColors.sunnahGreen
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10)),
                          child: Center(child: Text(unitLabels[i],
                            style: TextStyle(fontFamily: 'Cairo',
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: unitIdx == i
                                  ? Colors.white
                                  : AppColors.sunnahGreen))),
                        ),
                      )),
                  )),
                ),
                const SizedBox(height: 16),

                // ── Amount row: minus / field / plus ──────────────
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _gramBtn(Icons.remove_rounded, () {
                    final v  = double.tryParse(amtCtrl.text)
                        ?? unitDefaults[unitIdx];
                    final nv = (v - step).clamp(minV, 9999.0);
                    amtCtrl.text = nv % 1 == 0
                        ? nv.toInt().toString()
                        : nv.toStringAsFixed(2);
                    setS(() {});
                  }),
                  const SizedBox(width: 14),
                  SizedBox(width: 110, child: TextField(
                    controller: amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.center,
                    onChanged: (_) => setS(() {}),
                    style: const TextStyle(fontFamily: 'Cairo',
                        fontSize: 24, fontWeight: FontWeight.w900),
                    decoration: InputDecoration(
                      suffixText: ' ${unitLabels[unitIdx]}',
                      suffixStyle: TextStyle(fontFamily: 'Cairo',
                          fontSize: 13, color: muted,
                          fontWeight: FontWeight.w600),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.sunnahGreen, width: 1.5)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                            color: AppColors.sunnahGreen.withOpacity(0.4),
                            width: 1.5)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: AppColors.sunnahGreen, width: 2)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                    ),
                  )),
                  const SizedBox(width: 14),
                  _gramBtn(Icons.add_rounded, () {
                    final v  = double.tryParse(amtCtrl.text)
                        ?? unitDefaults[unitIdx];
                    final nv = (v + step).clamp(minV, 9999.0);
                    amtCtrl.text = nv % 1 == 0
                        ? nv.toInt().toString()
                        : nv.toStringAsFixed(2);
                    setS(() {});
                  }),
                ]),
                const SizedBox(height: 10),

                // ── Quick-pick chips ──────────────────────────────
                Wrap(spacing: 6, runSpacing: 6,
                  children: chipSets[unitIdx].map((chip) {
                    final cv    = (chip as num).toDouble();
                    final curV  = double.tryParse(amtCtrl.text) ?? 0;
                    final active = (curV - cv).abs() < 0.001;
                    final lbl   = cv % 1 == 0
                        ? '${cv.toInt()} ${unitLabels[unitIdx]}'
                        : '$cv ${unitLabels[unitIdx]}';
                    return GestureDetector(
                      onTap: () {
                        amtCtrl.text = cv % 1 == 0
                            ? cv.toInt().toString()
                            : cv.toString();
                        setS(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.sunnahGreen
                              : AppColors.sunnahGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.sunnahGreen.withOpacity(0.3))),
                        child: Text(lbl, style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : AppColors.sunnahGreen)),
                      ),
                    );
                  }).toList(),
                ),

                // ── Grams-equivalent badge (hidden for g and ml) ──
                if (unitIdx != 0 && unitIdx != 5) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.barakahGold.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.barakahGold.withOpacity(0.25))),
                    child: Text(
                      '= ${grams.toStringAsFixed(unitIdx == 2 ? 1 : 0)} ${tl("جرام", "g")}',
                      style: const TextStyle(fontFamily: 'Cairo',
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.barakahGold)),
                  ),
                ],
                const SizedBox(height: 14),

                // ── Live macro preview card ────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.sunnahGreen.withOpacity(
                        isDark ? 0.06 : 0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: AppColors.sunnahGreen.withOpacity(0.15))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                    _gramMacro('$kcal',
                        tl('سعرة', 'kcal'),      AppColors.haramRed),
                    _vDivider(),
                    _gramMacro('${prot.toStringAsFixed(1)}g',
                        tl('بروتين', 'Protein'),  AppColors.halalGreen),
                    _vDivider(),
                    _gramMacro('${carb.toStringAsFixed(1)}g',
                        tl('كارب', 'Carbs'),      AppColors.waterBlue),
                    _vDivider(),
                    _gramMacro('${fat.toStringAsFixed(1)}g',
                        tl('دهون', 'Fat'),        AppColors.barakahGold),
                  ]),
                ),
                const SizedBox(height: 18),

                // ── Add button ────────────────────────────────────
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final unitLabel = unitIdx == 0
                        ? '${raw.toInt()}${tl("ج", "g")}'
                        : '${amtCtrl.text} ${unitLabels[unitIdx]}';
                    _doAdd('$name ($unitLabel)', kcal, prot, carb, fat);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sunnahGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                  child: Text(tl('أضف للعداد', 'Add to Tracker'),
                    style: const TextStyle(fontFamily: 'Cairo',
                        fontSize: 15, color: Colors.white,
                        fontWeight: FontWeight.w800)),
                )),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _gramBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: AppColors.sunnahGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
            color: AppColors.sunnahGreen.withOpacity(0.3))),
      child: Icon(icon, color: AppColors.sunnahGreen, size: 22)),
  );

  Widget _gramMacro(String val, String label, Color color) =>
    Column(mainAxisSize: MainAxisSize.min, children: [
      Text(val, style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 1),
      Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 9,
          color: color.withOpacity(0.75))),
    ]);

  Widget _vDivider() => Container(
    width: 1, height: 32,
    color: Colors.grey.withOpacity(0.2));


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
            clipBehavior: Clip.antiAlias,
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
            child: (r['image_url'] as String?)?.isNotEmpty == true
                ? Image.network(
                    r['image_url'] as String,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Text(
                        foodEmoji(name.toString()),
                        style: const TextStyle(fontSize: 28))),
                  )
                : Center(child: Text(
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
            onPressed: () => _showUnitPicker(name: name.toString(), kcal100: kcal.toDouble(), protein100: protein.toDouble(), carbs100: carbs.toDouble(), fat100: fat.toDouble()),
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

  // ── WEEKLY REPORT CARD (PREMIUM) ─────────────────────────
  Widget _weeklyReportCard(bool isAr, bool isDark, bool isPremium) {
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final goal  = ref.read(caloriesProvider).goal;
    String t(String ar, String en) => isAr ? ar : en;

    if (!isPremium) {
      return GestureDetector(
        onTap: () => context.push('/paywall'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.barakahGold.withOpacity(0.13),
              AppColors.barakahGold.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.barakahGold.withOpacity(0.45))),
          child: Row(children: [
            const Text('📊', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('تقرير الأسبوع 🔒', 'Weekly Report 🔒'),
                style: const TextStyle(fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700, fontSize: 13,
                  color: AppColors.barakahGold)),
              Text(t('متوسط السعرات • الالتزام • أفضل يوم — بريميوم',
                'Avg calories • Adherence • Best day — Premium'),
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted)),
            ])),
            const Icon(Icons.arrow_forward_ios, size: 13,
              color: AppColors.barakahGold),
          ]),
        ),
      );
    }

    // Premium: real 7-day data from caloriesProvider
    final entries = ref.watch(caloriesProvider).entries;
    final now  = DateTime.now();
    final Map<String, int> byDay = {};
    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.month}/${d.day}';
      byDay[key] = 0;
    }
    for (final e in entries) {
      final d = e.time;
      final daysAgo = now.difference(d).inDays;
      if (daysAgo < 7) {
        final key = '${d.month}/${d.day}';
        byDay[key] = (byDay[key] ?? 0) + e.kcal;
      }
    }
    final vals     = byDay.values.toList();
    final avgKcal  = vals.isEmpty ? 0 : vals.reduce((a,b)=>a+b) ~/ vals.length;
    final goodDays = vals.where((v) => (v - goal).abs() < goal * 0.15).length;
    final adherePct= vals.isEmpty ? 0 : goodDays * 100 ~/ vals.length;
    final bestDay  = vals.isEmpty ? 0 : vals.reduce((a,b)=>a>b?a:b);
    final bestKey  = vals.isEmpty ? '-'
      : byDay.entries.firstWhere((e)=>e.value==bestDay).key;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sunnahGreen.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            const Text('📊', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(t('تقرير الأسبوع ⭐', 'Weekly Report ⭐'),
              style: const TextStyle(fontFamily: 'Cairo',
                fontWeight: FontWeight.w800, fontSize: 14,
                color: AppColors.sunnahGreen)),
          ]),
          GestureDetector(
            onTap: () {
              final txt = isAr
                ? 'تقرير HalalCalorie 📊\n'
                  'متوسط السعرات: $avgKcal kcal\n'
                  'الالتزام بالهدف: $adherePct%\n'
                  'أيام ملتزمة: $goodDays / ${vals.length}\n\n'
                  'الجسم أمانة — HalalCalorie'
                : 'HalalCalorie Weekly Report 📊\n'
                  'Avg calories: $avgKcal kcal\n'
                  'Goal adherence: $adherePct%\n'
                  'On-target days: $goodDays / ${vals.length}\n\n'
                  'Your body is an amanah — HalalCalorie';
              try { Share.share(txt); }
              catch (_) {
                Clipboard.setData(ClipboardData(text: txt));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(t('نُسخت!', 'Copied!'),
                    style: const TextStyle(fontFamily: 'Cairo')),
                  backgroundColor: AppColors.sunnahGreen,
                  duration: const Duration(seconds: 2)));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.sunnahGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.share_rounded,
                color: AppColors.sunnahGreen, size: 16)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _weekStat('🔥', '$avgKcal', t('متوسط', 'Avg kcal'), AppColors.haramRed, isDark),
          _weekStat('🎯', '$adherePct%', t('الالتزام', 'Adherence'), AppColors.sunnahGreen, isDark),
          _weekStat('📅', bestKey, t('أفضل يوم', 'Best day'), AppColors.barakahGold, isDark),
          _weekStat('✅', '$goodDays/${vals.isEmpty?7:vals.length}',
            t('ملتزمة', 'On-target'), AppColors.waterBlue, isDark),
        ]),
        if (vals.any((v)=>v>0)) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: byDay.entries.map((e) {
                final pct = (e.value / (goal > 0 ? goal : 2000)).clamp(0.0, 1.5);
                final col = (e.value - goal).abs() < goal * 0.15
                  ? AppColors.sunnahGreen
                  : e.value > goal * 1.15
                  ? AppColors.haramRed : AppColors.barakahGold;
                return Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(child: FractionallySizedBox(
                      heightFactor: pct.clamp(0.05, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: col.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(4))),
                    )),
                    const SizedBox(height: 2),
                    Text(e.key.split('/').last,
                      style: TextStyle(fontFamily: 'Cairo',
                        fontSize: 8, color: muted)),
                  ]));
              }).toList()),
          ),
        ],
      ]),
    );
  }

  Widget _weekStat(String emoji, String val, String label, Color col, bool isDark) =>
    Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 16)),
      Text(val, style: TextStyle(fontFamily: 'Cairo',
        fontWeight: FontWeight.w800, fontSize: 13, color: col)),
      Text(label, style: TextStyle(fontFamily: 'Cairo',
        fontSize: 9, color: isDark ? AppColors.darkMuted : AppColors.lightMuted)),
    ]);

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
  String? _genError;

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _generate() async {
    setState(() { _loading = true; _result = null; _genError = null; });
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
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _result = null;
        _genError = e.toString();
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
        if (_genError != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.haramRed.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.haramRed.withOpacity(0.3)),
            ),
            child: Column(children: [
              const Text('⚠️', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 8),
              Text(
                _genError!.contains('API_KEY') || _genError!.contains('401')
                  ? (isAr ? 'مفتاح API غير مُعدّ' : 'API key not configured')
                  : _genError!.contains('timeout')
                  ? (isAr ? 'انتهت مهلة الاتصال، حاول مجدداً' : 'Connection timed out, try again')
                  : (isAr ? 'فشل توليد الخطة، حاول مجدداً' : 'Plan generation failed, try again'),
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13,
                  color: AppColors.haramRed, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        ],
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
                        style: TextStyle(fontSize: 40)),
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
                  GestureDetector(
                    onTap: () async {
                      final txt = '${tl("خطة HalalCalorie", "HalalCalorie Plan")}\n\n'
                        '$_result\n\n'
                        '${tl("الجسم أمانة ﷺ", "Your body is an amanah ﷺ")}';
                      try { await Share.share(txt); }
                      catch (_) {
                        await Clipboard.setData(ClipboardData(text: txt));
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tl('نُسخت الخطة!','Plan copied!'),
                            style: const TextStyle(fontFamily:'Cairo')),
                            backgroundColor: AppColors.sunnahGreen,
                            duration: const Duration(seconds: 2)));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.sunnahGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(9)),
                      child: const Icon(Icons.share_rounded,
                        color: AppColors.sunnahGreen, size: 18)),
                  ),
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
