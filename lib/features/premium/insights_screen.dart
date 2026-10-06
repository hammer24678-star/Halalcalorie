// insights_screen.dart — HalalCalorie v56 (PATCH_V56_INSIGHTS)
// Insights Pro: trends, consistency, macro split, weekday pattern, heatmap,
// weight forecast and CSV export — all computed on-device from the local
// database. Free users get the 7-day basics; the rest is shown blurred over
// their own data so they can see exactly what Premium adds.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database.dart';
import '../../core/l10n.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import 'premium_ui.dart';

class _DayAgg {
  final String key;
  final int kcal;
  final double p, c, f;
  const _DayAgg(this.key, this.kcal, this.p, this.c, this.f);
}

class _WeightPt {
  final DateTime t;
  final double kg;
  const _WeightPt(this.t, this.kg);
}

class _InsightData {
  final List<_DayAgg> all; // up to 90 days of logged days
  final List<_WeightPt> weights;
  final double avgWater, avgSteps, avgSleep;
  final int workoutDays;
  const _InsightData(this.all, this.weights, this.avgWater, this.avgSteps,
      this.avgSleep, this.workoutDays);
}

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<_InsightData> _loadInsights(int rangeDays) async {
  final d = await AppDatabase.db;
  final now = DateTime.now();
  final since90 = _key(now.subtract(const Duration(days: 89)));
  final rows = await d.rawQuery(
    'SELECT date_key, SUM(kcal) AS k, SUM(protein_g) AS p, SUM(carbs_g) AS c, '
    'SUM(fat_g) AS f FROM meal_entries WHERE date_key >= ? '
    'GROUP BY date_key ORDER BY date_key ASC',
    [since90],
  );
  final all = rows
      .map((r) => _DayAgg(
            r['date_key'] as String,
            ((r['k'] as num?) ?? 0).round(),
            ((r['p'] as num?) ?? 0).toDouble(),
            ((r['c'] as num?) ?? 0).toDouble(),
            ((r['f'] as num?) ?? 0).toDouble(),
          ))
      .toList();

  final wRows = await d.query(
    'weight_log',
    where: 'created >= ?',
    whereArgs: [now.subtract(const Duration(days: 120)).toIso8601String()],
    orderBy: 'created ASC',
  );
  final weights = <_WeightPt>[];
  for (final r in wRows) {
    final t = DateTime.tryParse((r['created'] as String?) ?? '');
    final kg = (r['weight_kg'] as num?)?.toDouble();
    if (t != null && kg != null) weights.add(_WeightPt(t, kg));
  }

  final sinceR = _key(now.subtract(Duration(days: rangeDays - 1)));
  var w = 0.0, s = 0.0, sl = 0.0;
  try {
    final r = (await d.rawQuery(
      'SELECT AVG(water_cups) AS w, AVG(steps) AS s, AVG(sleep_hrs) AS sl '
      'FROM daily_summary WHERE date_key >= ? AND '
      '(water_cups > 0 OR steps > 0 OR sleep_hrs > 0)',
      [sinceR],
    ))
        .first;
    w = ((r['w'] as num?) ?? 0).toDouble();
    s = ((r['s'] as num?) ?? 0).toDouble();
    sl = ((r['sl'] as num?) ?? 0).toDouble();
  } catch (_) {}
  var wd = 0;
  try {
    final r = (await d.rawQuery(
      'SELECT COUNT(DISTINCT date_key) AS c FROM workout_log WHERE date_key >= ?',
      [sinceR],
    ))
        .first;
    wd = ((r['c'] as num?) ?? 0).toInt();
  } catch (_) {}
  return _InsightData(all, weights, w, s, sl, wd);
}

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});
  @override
  ConsumerState<InsightsScreen> createState() => _InsightsState();
}

class _InsightsState extends ConsumerState<InsightsScreen> {
  int _range = 7;
  late Future<_InsightData> _future = _loadInsights(_range);

  void _setRange(int r, bool premium) {
    if (r != 7 && !premium) {
      openPaywall(context);
      return;
    }
    setState(() {
      _range = r;
      _future = _loadInsights(r);
    });
  }

  Future<void> _export(bool isAr) async {
    final d = await AppDatabase.db;
    final since = _key(DateTime.now().subtract(const Duration(days: 89)));
    String esc(String s) => '"${s.replaceAll('"', '""')}"';
    final b = StringBuffer('HalalCalorie export (last 90 days)\n\n');
    b.writeln('date,meal,kcal,protein_g,carbs_g,fat_g');
    final meals = await d.query('meal_entries',
        where: 'date_key >= ?',
        whereArgs: [since],
        orderBy: 'date_key ASC, id ASC');
    for (final m in meals) {
      b.writeln('${m['date_key']},${esc('${m['name']}')},${m['kcal']},'
          '${m['protein_g']},${m['carbs_g']},${m['fat_g']}');
    }
    b.writeln('\ndate,weight_kg');
    final ws = await d.query('weight_log', orderBy: 'created ASC');
    for (final w in ws) {
      final t = DateTime.tryParse('${w['created']}');
      b.writeln('${t == null ? w['created'] : _key(t)},${w['weight_kg']}');
    }
    b.writeln('\ndate,workout,minutes');
    final wl = await d.query('workout_log',
        where: 'date_key >= ?', whereArgs: [since], orderBy: 'date_key ASC');
    for (final w in wl) {
      b.writeln('${w['date_key']},${esc('${w['workout_id']}')},${w['minutes']}');
    }
    try {
      await Share.share(b.toString());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isDark = ref.watch(themeProvider);
    final premium = ref.watch(premiumProvider);
    final goal = ref.watch(caloriesProvider).goal;
    final profile = ref.watch(userProfileProvider);
    final th = PTheme(isDark);
    final isAr = lang == 'ar';
    String t(String ar, String en) => tLang(lang, ar, en);
    void unlock() => openPaywall(context);

    return Scaffold(
      backgroundColor: th.bg,
      appBar: AppBar(
        title: Text(t('رؤى متقدمة', 'Insights Pro'),
            style: pText(th.text, 18, w: FontWeight.w900)),
        backgroundColor: th.bg,
        elevation: 0,
        iconTheme: IconThemeData(color: th.text),
      ),
      body: FutureBuilder<_InsightData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: kGold));
          }
          if (!snap.hasData) {
            return Center(
              child: Text(t('تعذّر تحميل البيانات', 'Could not load your data'),
                  style: pText(th.muted, 14)),
            );
          }
          final data = snap.data!;
          final sinceKey =
              _key(DateTime.now().subtract(Duration(days: _range - 1)));
          final days = data.all.where((d) => d.key.compareTo(sinceKey) >= 0).toList();
          final logged = days.length;
          final avgKcal =
              logged == 0 ? 0 : days.fold<int>(0, (a, b) => a + b.kcal) ~/ logged;
          final onTarget = days
              .where((d) => (d.kcal - goal).abs() <= goal * 0.10)
              .length;
          final adherence = logged == 0 ? 0 : (onTarget * 100 / logged).round();
          final avgProtein =
              logged == 0 ? 0.0 : days.fold<double>(0, (a, b) => a + b.p) / logged;

          Widget tile(String label, String value, String sub, Color c) => Expanded(
                child: PCard(
                  th: th,
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: pText(th.muted, 11.5, w: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(value, style: pText(c, 24, w: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(sub, style: pText(th.muted, 11, w: FontWeight.w500)),
                  ]),
                ),
              );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              // Range chips
              Row(children: [
                for (final r in const [7, 30, 90]) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _setRange(r, premium),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _range == r ? kGold : th.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: _range == r ? kGold : th.border, width: 0.8),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(
                            t('$r يوم', '$r days'),
                            style: pText(
                                _range == r ? const Color(0xFF1A0F00) : th.text, 13,
                                w: FontWeight.w800),
                          ),
                          if (r != 7 && !premium) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.lock_rounded, size: 12, color: kGold),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 14),

              // Summary (first row free, second row premium)
              Row(children: [
                tile(t('متوسط السعرات', 'Avg calories'), '$avgKcal',
                    t('الهدف $goal', 'Goal $goal'), AppColors.halalGreen),
                const SizedBox(width: 10),
                tile(t('أيام التسجيل', 'Days logged'), '$logged/$_range',
                    t('في هذه الفترة', 'in this period'), AppColors.waterBlue),
              ]),
              const SizedBox(height: 10),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: Row(children: [
                  tile(t('الالتزام بالهدف', 'On-target days'), '$adherence%',
                      t('ضمن ±١٠٪ من الهدف', 'within ±10% of goal'), kGold),
                  const SizedBox(width: 10),
                  tile(t('متوسط البروتين', 'Avg protein'),
                      '${avgProtein.round()} g',
                      t('يوميًا', 'per day'), AppColors.sleepPurple),
                ]),
              ),

              // Calories chart (free: 7 days)
              PSection(t('السعرات اليومية', 'DAILY CALORIES'), th),
              PCard(
                th: th,
                child: _CalorieBars(
                    days: days, range: _range, goal: goal, th: th, isAr: isAr),
              ),

              // Macro split
              PSection(t('توزيع المغذيات', 'MACRO SPLIT'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(th: th, child: _MacroSplit(days: days, th: th, isAr: isAr)),
              ),

              // Weekday pattern
              PSection(t('نمط أيام الأسبوع', 'WEEKDAY PATTERN'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(
                    th: th,
                    child: _WeekdayPattern(
                        days: data.all, goal: goal, th: th, isAr: isAr)),
              ),

              // Heatmap
              PSection(t('خريطة الالتزام — ١٢ أسبوعًا', 'CONSISTENCY — 12 WEEKS'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(
                    th: th,
                    child: _Heatmap(days: data.all, goal: goal, th: th, isAr: isAr)),
              ),

              // Weight forecast
              PSection(t('توقّع الوزن', 'WEIGHT FORECAST'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: PCard(
                  th: th,
                  child: _WeightForecast(
                    pts: data.weights,
                    target: profile?.targetWeightKg ?? profile?.idealWeightKg,
                    th: th,
                    isAr: isAr,
                  ),
                ),
              ),

              // Habits
              PSection(t('عاداتك', 'HABITS'), th),
              PLocked(
                locked: !premium,
                th: th,
                label: t('افتح مع بريميوم', 'Unlock with Premium'),
                onUnlock: unlock,
                child: Row(children: [
                  tile(t('ماء', 'Water'), data.avgWater.toStringAsFixed(1),
                      t('كوب/يوم', 'cups/day'), AppColors.waterBlue),
                  const SizedBox(width: 10),
                  tile(t('خطوات', 'Steps'), '${data.avgSteps.round()}',
                      t('يوميًا', 'per day'), AppColors.halalGreen),
                  const SizedBox(width: 10),
                  tile(t('تمارين', 'Workouts'), '${data.workoutDays}',
                      t('أيام', 'days'), AppColors.sleepPurple),
                ]),
              ),

              // Export
              const SizedBox(height: 22),
              PGoldButton(
                label: t('تصدير بياناتي (CSV)', 'Export my data (CSV)'),
                icon: Icons.ios_share_rounded,
                onTap: premium ? () => _export(isAr) : unlock,
              ),
              const SizedBox(height: 8),
              Text(
                t('للمشاركة مع أخصائي التغذية أو الطبيب. تُحسب كل الأرقام على جهازك.',
                    'Handy for a dietitian or doctor. Every number is computed on your device.'),
                textAlign: TextAlign.center,
                style: pText(th.muted, 11.5, w: FontWeight.w500, h: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Charts (hand-drawn, no chart package needed) ─────────────────────────

class _CalorieBars extends StatelessWidget {
  final List<_DayAgg> days;
  final int range, goal;
  final PTheme th;
  final bool isAr;
  const _CalorieBars({
    required this.days,
    required this.range,
    required this.goal,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    // Up to 30 daily bars; 90 days collapses into weekly averages.
    final byKey = {for (final d in days) d.key: d.kcal};
    final now = DateTime.now();
    final values = <double>[];
    final labels = <String>[];
    if (range <= 30) {
      for (var i = range - 1; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        values.add((byKey[_key(d)] ?? 0).toDouble());
        labels.add(range <= 7 ? '${d.day}' : (i % 5 == 0 ? '${d.day}' : ''));
      }
    } else {
      for (var w = 12; w >= 0; w--) {
        var sum = 0, n = 0;
        for (var i = 0; i < 7; i++) {
          final d = now.subtract(Duration(days: w * 7 + i));
          final v = byKey[_key(d)];
          if (v != null) {
            sum += v;
            n++;
          }
        }
        values.add(n == 0 ? 0 : sum / n);
        labels.add(w % 3 == 0 ? '${w}w' : '');
      }
    }
    final maxV = math.max(
        goal * 1.25, values.isEmpty ? 0.0 : values.reduce(math.max) * 1.05);
    const h = 130.0;
    return Column(children: [
      SizedBox(
        height: h,
        child: Stack(children: [
          Positioned(
            left: 0,
            right: 0,
            top: h - (goal / maxV) * h,
            child: Row(children: [
              for (var i = 0; i < 40; i++)
                Expanded(
                  child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      color: kGold.withOpacity(i.isEven ? 0.8 : 0.0)),
                ),
            ]),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final v in values)
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: v <= 0 ? 3 : (v / maxV) * h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: v <= 0
                            ? th.border
                            : ((v - goal).abs() <= goal * 0.10
                                ? AppColors.halalGreen
                                : (v > goal ? AppColors.doubtOrange : AppColors.waterBlue)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (final l in labels)
          Expanded(
              child: Text(l,
                  textAlign: TextAlign.center,
                  style: pText(th.muted, 10, w: FontWeight.w600))),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 12, runSpacing: 6, children: [
        _legend(AppColors.halalGreen, isAr ? 'ضمن الهدف' : 'On target'),
        _legend(AppColors.doubtOrange, isAr ? 'فوق الهدف' : 'Over'),
        _legend(AppColors.waterBlue, isAr ? 'تحت الهدف' : 'Under'),
        _legend(kGold, isAr ? 'الهدف' : 'Goal'),
      ]),
    ]);
  }

  Widget _legend(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(s, style: pText(th.muted, 10.5, w: FontWeight.w600)),
      ]);
}

class _MacroSplit extends StatelessWidget {
  final List<_DayAgg> days;
  final PTheme th;
  final bool isAr;
  const _MacroSplit({required this.days, required this.th, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final p = days.fold<double>(0, (a, b) => a + b.p) * 4;
    final c = days.fold<double>(0, (a, b) => a + b.c) * 4;
    final f = days.fold<double>(0, (a, b) => a + b.f) * 9;
    final total = p + c + f;
    if (total <= 0) {
      return Text(isAr ? 'سجّل وجبات لترى التوزيع' : 'Log meals to see your split',
          style: pText(th.muted, 13));
    }
    int pct(double v) => (v * 100 / total).round();
    Widget seg(double v, Color col) => Expanded(
          flex: math.max(1, (v * 1000 / total).round()),
          child: Container(height: 16, color: col),
        );
    Widget keyCol(String label, double v, Color col) => Expanded(
          child: Column(children: [
            Text('${pct(v)}%', style: pText(col, 20, w: FontWeight.w900)),
            Text(label, style: pText(th.muted, 11.5, w: FontWeight.w700)),
          ]),
        );
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Row(children: [
          seg(p, AppColors.halalGreen),
          seg(c, AppColors.waterBlue),
          seg(f, AppColors.doubtOrange),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        keyCol(isAr ? 'بروتين' : 'Protein', p, AppColors.halalGreen),
        keyCol(isAr ? 'كربوهيدرات' : 'Carbs', c, AppColors.waterBlue),
        keyCol(isAr ? 'دهون' : 'Fat', f, AppColors.doubtOrange),
      ]),
    ]);
  }
}

class _WeekdayPattern extends StatelessWidget {
  final List<_DayAgg> days;
  final int goal;
  final PTheme th;
  final bool isAr;
  const _WeekdayPattern({
    required this.days,
    required this.goal,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final sums = List<double>.filled(7, 0);
    final counts = List<int>.filled(7, 0);
    for (final d in days) {
      final t = DateTime.tryParse(d.key);
      if (t == null) continue;
      sums[t.weekday - 1] += d.kcal;
      counts[t.weekday - 1]++;
    }
    final avgs = [
      for (var i = 0; i < 7; i++) counts[i] == 0 ? 0.0 : sums[i] / counts[i]
    ];
    final maxV = math.max(goal * 1.25, avgs.reduce(math.max) * 1.05);
    final names = isAr
        ? const ['اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت', 'أحد']
        : const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    var hi = 0;
    for (var i = 1; i < 7; i++) {
      if (avgs[i] > avgs[hi]) hi = i;
    }
    const h = 90.0;
    return Column(children: [
      SizedBox(
        height: h,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: avgs[i] <= 0 ? 3 : (avgs[i] / maxV) * h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: i == hi && avgs[i] > 0 ? kGold : AppColors.halalGreen.withOpacity(0.75),
                  ),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (final n in names)
          Expanded(
              child: Text(n,
                  textAlign: TextAlign.center,
                  style: pText(th.muted, 10.5, w: FontWeight.w700))),
      ]),
      const SizedBox(height: 10),
      Text(
        avgs[hi] <= 0
            ? (isAr ? 'سجّل أكثر لنرى نمطك' : 'Log a bit more to reveal your pattern')
            : (isAr
                ? 'أعلى استهلاك لك يوم ${names[hi]} (${avgs[hi].round()} سعر)'
                : 'You eat the most on ${names[hi]} (${avgs[hi].round()} kcal avg)'),
        textAlign: TextAlign.center,
        style: pText(th.text, 12.5, w: FontWeight.w700),
      ),
    ]);
  }
}

class _Heatmap extends StatelessWidget {
  final List<_DayAgg> days;
  final int goal;
  final PTheme th;
  final bool isAr;
  const _Heatmap({
    required this.days,
    required this.goal,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    final byKey = {for (final d in days) d.key: d.kcal};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // 12 columns of weeks, the last column ends on today's weekday.
    const weeks = 12;
    final lastWeekStart = today.subtract(Duration(days: today.weekday - 1));
    var loggedDays = 0;
    final cols = <Widget>[];
    for (var w = weeks - 1; w >= 0; w--) {
      final start = lastWeekStart.subtract(Duration(days: w * 7));
      final cells = <Widget>[];
      for (var i = 0; i < 7; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        final v = d.isAfter(today) ? null : byKey[_key(d)];
        if (v != null) loggedDays++;
        Color c;
        if (d.isAfter(today)) {
          c = Colors.transparent;
        } else if (v == null) {
          c = th.border;
        } else {
          final double r = (v / goal).clamp(0.0, 1.0).toDouble();
          c = AppColors.halalGreen.withOpacity(0.25 + r * 0.7);
        }
        cells.add(Container(
          margin: const EdgeInsets.all(2),
          height: 18,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
        ));
      }
      cols.add(Expanded(child: Column(children: cells)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: cols),
      const SizedBox(height: 8),
      Text(
        isAr ? 'سجّلت $loggedDays يومًا خلال ١٢ أسبوعًا' : 'You logged $loggedDays days in 12 weeks',
        style: pText(th.muted, 12, w: FontWeight.w600),
      ),
    ]);
  }
}

class _WeightForecast extends StatelessWidget {
  final List<_WeightPt> pts;
  final double? target;
  final PTheme th;
  final bool isAr;
  const _WeightForecast({
    required this.pts,
    required this.target,
    required this.th,
    required this.isAr,
  });

  @override
  Widget build(BuildContext context) {
    if (pts.length < 3) {
      return Text(
        isAr
            ? 'سجّل وزنك ٣ مرات على الأقل (في الصحة ← الجسم) لنرسم اتجاهك ونتوقّع موعد هدفك.'
            : 'Log your weight at least 3 times (Health → Body) and we will chart your trend and forecast your goal date.',
        style: pText(th.muted, 13, w: FontWeight.w600, h: 1.5),
      );
    }
    final first = pts.first.t;
    final xs = [for (final p in pts) p.t.difference(first).inHours / 24.0];
    final ys = [for (final p in pts) p.kg];
    final n = pts.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var cov = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      cov += (xs[i] - mx) * (ys[i] - my);
      den += (xs[i] - mx) * (xs[i] - mx);
    }
    final slope = den == 0 ? 0.0 : cov / den; // kg per day
    final perWeek = slope * 7;
    final current = ys.last;
    final spanDays = xs.last - xs.first;

    String line;
    if (spanDays < 5 || slope.abs() < 0.004) {
      line = isAr
          ? 'وزنك مستقر تقريبًا (${current.toStringAsFixed(1)} كجم).'
          : 'Your weight is steady at about ${current.toStringAsFixed(1)} kg.';
    } else {
      final dir = perWeek < 0 ? (isAr ? 'تخسر' : 'losing') : (isAr ? 'تزيد' : 'gaining');
      line = isAr
          ? 'وتيرتك: $dir ${perWeek.abs().toStringAsFixed(2)} كجم أسبوعيًا.'
          : 'Your pace: $dir ${perWeek.abs().toStringAsFixed(2)} kg per week.';
      final tg = target;
      if (tg != null) {
        final toGo = tg - current;
        final goingRight = (toGo < 0 && slope < 0) || (toGo > 0 && slope > 0);
        if (goingRight) {
          final daysLeft = (toGo / slope).round();
          if (daysLeft >= 1 && daysLeft <= 730) {
            final date = DateTime.now().add(Duration(days: daysLeft));
            line += isAr
                ? '\nبهذا المعدل تصل إلى ${tg.toStringAsFixed(1)} كجم تقريبًا في ${date.day}/${date.month}/${date.year}.'
                : '\nAt this rate you reach ${tg.toStringAsFixed(1)} kg around ${date.day}/${date.month}/${date.year}.';
          }
        } else if (toGo.abs() > 0.5) {
          line += isAr
              ? '\nالاتجاه الحالي بعيد عن هدفك (${tg.toStringAsFixed(1)} كجم).'
              : '\nThe current trend is heading away from your ${tg.toStringAsFixed(1)} kg goal.';
        }
      }
      if (perWeek < -1.0) {
        line += isAr
            ? '\nهذه وتيرة سريعة — الأفضل غالبًا بين ٠٫٢٥ و١ كجم أسبوعيًا.'
            : '\nThat is quick — roughly 0.25–1 kg a week is the usual guidance.';
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 110,
        width: double.infinity,
        child: CustomPaint(
          painter: _LinePainter(ys, target, AppColors.halalGreen, th.border),
        ),
      ),
      const SizedBox(height: 10),
      Text(line, style: pText(th.text, 13, w: FontWeight.w700, h: 1.5)),
    ]);
  }
}

class _LinePainter extends CustomPainter {
  final List<double> ys;
  final double? target;
  final Color color;
  final Color grid;
  _LinePainter(this.ys, this.target, this.color, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    if (ys.length < 2) return;
    var lo = ys.reduce(math.min);
    var hi = ys.reduce(math.max);
    final tg = target;
    if (tg != null && (tg - lo).abs() < 15 && (tg - hi).abs() < 15) {
      lo = math.min(lo, tg);
      hi = math.max(hi, tg);
    }
    if (hi - lo < 1) {
      hi += 0.5;
      lo -= 0.5;
    }
    double yOf(double v) => size.height - ((v - lo) / (hi - lo)) * (size.height - 12) - 6;
    double xOf(int i) => (i / (ys.length - 1)) * size.width;

    final g = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), g);
    }
    if (tg != null && tg >= lo && tg <= hi) {
      final tp = Paint()
        ..color = kGold
        ..strokeWidth = 1.5;
      for (double x = 0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, yOf(tg)), Offset(math.min(x + 5, size.width), yOf(tg)), tp);
      }
    }
    final path = Path()..moveTo(xOf(0), yOf(ys[0]));
    for (var i = 1; i < ys.length; i++) {
      path.lineTo(xOf(i), yOf(ys[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = color;
    for (var i = 0; i < ys.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(ys[i])), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.ys != ys || old.target != target || old.color != color;
}
