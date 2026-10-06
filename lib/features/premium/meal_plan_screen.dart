// meal_plan_screen.dart — HalalCalorie v58 (PATCH_V58_MEALPLAN)
// Premium AI day planner. Builds a full halal day that fits the user's calorie
// and macro targets (normal day, or suhoor/iftar on fasting days), one-tap
// logging per meal, and a shareable grocery list. Plans are cached per day so
// reopening costs nothing; generation is capped at 5 per day.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/fasting_calendar.dart';
import '../../core/hijri.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/models/user_profile.dart';
import 'premium_ui.dart';

class PlanMeal {
  final String slot, name;
  final int kcal;
  final double protein, carbs, fat;
  final List<String> items;
  const PlanMeal(this.slot, this.name, this.kcal, this.protein, this.carbs,
      this.fat, this.items);

  Map<String, dynamic> toJson() => {
        'slot': slot,
        'name': name,
        'kcal': kcal,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'items': items,
      };

  static PlanMeal? fromJson(dynamic j) {
    if (j is! Map) return null;
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    final name = '${j['name'] ?? ''}'.trim();
    final kcal = d(j['kcal']).round();
    if (name.isEmpty || kcal <= 0) return null;
    return PlanMeal(
      '${j['slot'] ?? ''}'.trim(),
      name,
      kcal.clamp(30, 2500),
      d(j['protein']),
      d(j['carbs']),
      d(j['fat']),
      [
        for (final i in (j['items'] is List ? j['items'] as List : const []))
          '$i'.trim()
      ].where((s) => s.isNotEmpty).toList(),
    );
  }
}

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});
  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanState();
}

class _MealPlanState extends ConsumerState<MealPlanScreen> {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const _dailyCap = 5;

  List<PlanMeal> _plan = [];
  final Set<int> _logged = {};
  bool _loading = false;
  String? _error;
  String _style = 'balanced';
  int _genToday = 0;

  String get _today => FastingCalendar.dateKey(DateTime.now());

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('mealplan_$_today');
    final gen = p.getString('mealplan_gen_day') == _today
        ? (p.getInt('mealplan_gen_count') ?? 0)
        : 0;
    final plan = <PlanMeal>[];
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          final m = PlanMeal.fromJson(j);
          if (m != null) plan.add(m);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _genToday = gen;
      _logged
        ..clear()
        ..addAll((p.getStringList('mealplan_logged_$_today') ?? const <String>[])
            .map(int.tryParse)
            .whereType<int>());
    });
  }

  static String _langName(String c) =>
      const {
        'ar': 'Arabic',
        'en': 'English',
        'fr': 'French',
        'tr': 'Turkish',
        'ur': 'Urdu',
        'ms': 'Malay',
        'id': 'Indonesian',
      }[c] ??
      'English';

  Future<void> _generate(String lang, bool fastingDay) async {
    if (_loading) return;
    if (_genToday >= _dailyCap) {
      setState(() => _error = tLang(lang, 'وصلت إلى حد ٥ خطط اليوم. عُد غدًا بإذن الله.',
          'You have reached today\u2019s limit of 5 plans. Come back tomorrow.'));
      return;
    }
    final isAr = lang == 'ar';
    if (_apiKey.isEmpty) {
      setState(() => _error = isAr
          ? 'مخطط الوجبات غير مفعّل في هذا الإصدار.'
          : 'The meal planner is not enabled in this build.');
      return;
    }
    final profile = ref.read(userProfileProvider);
    final goal = ref.read(caloriesProvider).goal;
    setState(() {
      _loading = true;
      _error = null;
    });

    final slots = fastingDay
        ? 'suhoor, iftar, post-iftar snack'
        : 'breakfast, lunch, dinner, snack';
    final styleHint = const {
          'balanced': 'balanced and varied',
          'protein': 'high-protein',
          'budget': 'budget-friendly with cheap staples (ful, eggs, lentils, rice, chicken thighs, seasonal vegetables)',
          'quick': 'quick: every meal under 15 minutes of work',
          'light': 'light on the stomach and low in fried food',
        }[_style] ??
        'balanced';
    final conds = profile?.healthConditions
            .map((c) => c.nameEn())
            .where((n) => n != 'None')
            .toList() ??
        <String>[];
    final system = [
      'You are a halal nutrition planner. Reply with ONLY one JSON object, no markdown, no commentary.',
      'Schema: {"meals":[{"slot":string,"name":string,"kcal":int,"protein":number,"carbs":number,"fat":number,"items":[string]}]}',
      '"items" are short ingredients with a gram or piece amount, e.g. "Chicken breast 150 g".',
      'Write slot, name and items in ${_langName(lang)}.',
      'Slots, in order: $slots. Total kcal must land within 5% of $goal.',
      if (profile != null)
        'Macro targets for the day: protein ~${profile.proteinGrams.round()} g, carbs ~${profile.carbsGrams.round()} g, fat ~${profile.fatGrams.round()} g.',
      'Style: $styleHint. Prefer foods common in Egypt and the Middle East. Everything must be halal: no pork, no alcohol, no non-halal gelatin.',
      if (profile != null) 'Dietary preference: ${profile.dietPreference.nameEn()}.',
      if (conds.isNotEmpty)
        'Health conditions: ${conds.join(', ')}. Keep it conservative and mention nothing medical.',
      if (fastingDay)
        'This is a fasting day: suhoor should be slow-digesting; iftar starts with dates and water.',
    ].join('\n');

    List<PlanMeal> parsed = [];
    String? err;
    for (final model in const ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant']) {
      try {
        final resp = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $_apiKey',
              },
              body: jsonEncode({
                'model': model,
                'max_tokens': 1100,
                'temperature': 0.6,
                'response_format': {'type': 'json_object'},
                'messages': [
                  {'role': 'system', 'content': system},
                  {'role': 'user', 'content': 'Plan my day.'},
                ],
              }),
            )
            .timeout(const Duration(seconds: 45));
        if (resp.statusCode != 200) {
          err = 'HTTP ${resp.statusCode}';
          continue;
        }
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        var text = '${(data['choices'] as List).first['message']['content']}';
        final a = text.indexOf('{');
        final b = text.lastIndexOf('}');
        if (a < 0 || b <= a) continue;
        text = text.substring(a, b + 1);
        final obj = jsonDecode(text) as Map<String, dynamic>;
        final meals = <PlanMeal>[];
        for (final j in (obj['meals'] as List? ?? const [])) {
          final m = PlanMeal.fromJson(j);
          if (m != null) meals.add(m);
        }
        if (meals.length >= 2) {
          parsed = meals;
          break;
        }
      } catch (e) {
        err = '$e';
      }
    }

    if (!mounted) return;
    if (parsed.isEmpty) {
      setState(() {
        _loading = false;
        _error = isAr
            ? 'تعذّر إنشاء الخطة الآن. تحقق من الاتصال وحاول مجددًا.'
            : 'Could not build a plan right now. Check your connection and try again.';
      });
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('mealplan_$_today', jsonEncode(parsed.map((m) => m.toJson()).toList()));
    await p.setStringList('mealplan_logged_$_today', const <String>[]);
    await p.setString('mealplan_gen_day', _today);
    await p.setInt('mealplan_gen_count', _genToday + 1);
    if (!mounted) return;
    setState(() {
      _plan = parsed;
      _logged.clear();
      _genToday += 1;
      _loading = false;
    });
  }

  Future<void> _logMeal(int i) async {
    if (_logged.contains(i)) return;
    final m = _plan[i];
    await ref
        .read(caloriesProvider.notifier)
        .addEntry(m.name, m.kcal, proteinG: m.protein, carbsG: m.carbs, fatG: m.fat);
    final p = await SharedPreferences.getInstance();
    setState(() => _logged.add(i));
    await p.setStringList('mealplan_logged_$_today', _logged.map((e) => '$e').toList());
  }

  Future<void> _shareGrocery(bool isAr) async {
    final seen = <String>{};
    final lines = <String>[];
    for (final m in _plan) {
      for (final it in m.items) {
        if (seen.add(it.toLowerCase())) lines.add('• $it');
      }
    }
    final head = isAr ? 'قائمة المشتريات — HalalCalorie' : 'Grocery list — HalalCalorie';
    try {
      await Share.share('$head\n\n${lines.join('\n')}');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final goal = ref.watch(caloriesProvider).goal;
    final ramadan = ref.watch(ramadanModeProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);
    final today = DateTime.now();
    final fastingDay = ramadan ||
        HijriDate.fromGregorian(today).isRamadan ||
        FastingCalendar.isSunnahFast(DateTime(today.year, today.month, today.day));
    final total = _plan.fold<int>(0, (a, m) => a + m.kcal);

    final styles = <String, String>{
      'balanced': t('متوازن', 'Balanced'),
      'protein': t('بروتين عالٍ', 'High protein'),
      'budget': t('اقتصادي', 'Budget'),
      'quick': t('سريع', 'Quick'),
      'light': t('خفيف', 'Light'),
    };

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('مخطط وجباتك', 'AI Meal Planner'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: !premium
          ? _locked(th, t)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              children: [
                PCard(
                  th: th,
                  gold: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const PBadge(Icons.auto_awesome_rounded, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                              fastingDay
                                  ? t('خطة يوم صيام', 'Fasting-day plan')
                                  : t('خطة يومك', 'Plan for your day'),
                              style: pText(th.text, 16.5, w: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(t('هدفك $goal سعرًا', 'Your goal: $goal kcal'),
                              style: pText(th.muted, 12.5, w: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final e in styles.entries)
                        GestureDetector(
                          onTap: () => setState(() => _style = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _style == e.key ? kGold : th.card.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: _style == e.key ? kGold : th.border, width: 0.8),
                            ),
                            child: Text(e.value,
                                style: pText(
                                    _style == e.key ? const Color(0xFF1A0F00) : th.text, 12.5,
                                    w: FontWeight.w800)),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 14),
                    PGoldButton(
                      label: _loading
                          ? t('جارٍ التحضير…', 'Cooking up your plan…')
                          : _plan.isEmpty
                              ? t('أنشئ خطتي', 'Build my plan')
                              : t('خطة جديدة', 'New plan'),
                      icon: Icons.auto_awesome_rounded,
                      onTap: _loading ? null : () => _generate(lang, fastingDay),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        t('${_dailyCap - _genToday} من $_dailyCap محاولات متبقية اليوم',
                            '${_dailyCap - _genToday} of $_dailyCap tries left today'),
                        style: pText(th.muted, 11.5, w: FontWeight.w500)),
                  ]),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator(color: kGold)),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  PCard(
                    th: th,
                    child: Text(_error!, style: pText(AppColors.haramRed, 13, w: FontWeight.w700, h: 1.45)),
                  ),
                ],
                if (_plan.isNotEmpty) ...[
                  PSection(t('وجباتك', 'YOUR MEALS'), th),
                  for (var i = 0; i < _plan.length; i++) ...[
                    _mealCard(i, th, isAr),
                    const SizedBox(height: 10),
                  ],
                  PCard(
                    th: th,
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t('المجموع', 'Total'), style: pText(th.muted, 12, w: FontWeight.w700)),
                          Text('$total kcal',
                              style: pText(
                                  (total - goal).abs() <= goal * 0.10
                                      ? AppColors.halalGreen
                                      : AppColors.doubtOrange,
                                  22,
                                  w: FontWeight.w900)),
                        ]),
                      ),
                      PGoldButton(
                        outlined: true,
                        label: t('قائمة المشتريات', 'Grocery list'),
                        icon: Icons.shopping_basket_rounded,
                        onTap: () => _shareGrocery(isAr),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('الأرقام تقديرية من الذكاء الاصطناعي، وليست نصيحة طبية. عدّل الكميات حسب حالتك.',
                        'Numbers are AI estimates, not medical advice. Adjust portions to suit you.'),
                    textAlign: TextAlign.center,
                    style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.45),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _mealCard(int i, PTheme th, bool isAr) {
    final m = _plan[i];
    final done = _logged.contains(i);
    return PCard(
      th: th,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (m.slot.isNotEmpty) PPill(m.slot, kGold),
          const Spacer(),
          Text('${m.kcal} kcal', style: pText(AppColors.halalGreen, 15, w: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        Text(m.name, style: pText(th.text, 15, w: FontWeight.w900, h: 1.3)),
        const SizedBox(height: 6),
        Text(
          'P ${m.protein.round()} g  ·  C ${m.carbs.round()} g  ·  F ${m.fat.round()} g',
          style: pText(th.muted, 12, w: FontWeight.w700),
        ),
        if (m.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(m.items.join(' · '), style: pText(th.muted, 12, w: FontWeight.w500, h: 1.5)),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PGoldButton(
            outlined: done,
            label: done ? (isAr ? 'تم التسجيل' : 'Logged') : (isAr ? 'سجّل هذه الوجبة' : 'Log this meal'),
            icon: done ? Icons.check_rounded : Icons.add_rounded,
            onTap: done ? null : () => _logMeal(i),
          ),
        ),
      ]),
    );
  }

  Widget _locked(PTheme th, String Function(String, String) t) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          PCard(
            th: th,
            gold: true,
            child: Column(children: [
              const PBadge(Icons.auto_awesome_rounded, size: 60),
              const SizedBox(height: 14),
              Text(t('يومك كله في ثوانٍ', 'Your whole day, in seconds'),
                  style: pText(th.text, 19, w: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                t('خطة وجبات حلال تطابق سعراتك ومغذياتك — أو سحورك وإفطارك — مع تسجيل بنقرة وقائمة مشتريات.',
                    'A halal meal plan that fits your calories and macros, or your suhoor and iftar, with one-tap logging and a grocery list.'),
                textAlign: TextAlign.center,
                style: pText(th.muted, 13, w: FontWeight.w600, h: 1.55),
              ),
              const SizedBox(height: 16),
              PGoldButton(
                label: t('افتح بريميوم', 'Unlock Premium'),
                icon: Icons.workspace_premium_rounded,
                onTap: () => openPaywall(context),
              ),
            ]),
          ),
          PSection(t('مثال', 'EXAMPLE'), th),
          PLocked(
            locked: true,
            th: th,
            label: t('افتح مع بريميوم', 'Unlock with Premium'),
            onUnlock: () => openPaywall(context),
            child: Column(children: [
              _sample(th, t('الفطور', 'Breakfast'), t('فول بالزيت الحار + بيضة + خبز بلدي', 'Ful with olive oil, egg, baladi bread'), 420),
              const SizedBox(height: 10),
              _sample(th, t('الغداء', 'Lunch'), t('صدر دجاج مشوي + أرز + سلطة', 'Grilled chicken, rice and salad'), 640),
              const SizedBox(height: 10),
              _sample(th, t('العشاء', 'Dinner'), t('زبادي يوناني + تمر + مكسرات', 'Greek yogurt, dates and nuts'), 380),
            ]),
          ),
        ],
      );

  Widget _sample(PTheme th, String slot, String name, int kcal) => PCard(
        th: th,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot, style: pText(kGold, 11.5, w: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(name, style: pText(th.text, 14, w: FontWeight.w800)),
            ]),
          ),
          Text('$kcal kcal', style: pText(AppColors.halalGreen, 14, w: FontWeight.w900)),
        ]),
      );
}
