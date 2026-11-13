// today_card.dart — HalalCalorie v65 (PATCH_V65_TODAY_CARD)
//
// The centrepiece of the home screen. Replaces the flat calorie-ring card with
// a hero card: a subtle Islamic-star backdrop, a bigger ring with a live
// "remaining" read-out, readable macro tiles, one-tap logging, and a new
// "day rhythm" strip that places every meal you logged on a timeline between
// Fajr and Isha, next to the five prayers. Everything on the strip is plain
// arithmetic on the meals and prayer times the app already has.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/l10n.dart';
import '../../core/fx2.dart';
import '../../core/prayer_service.dart';
import '../../data/models/models.dart';

class TodayCard extends StatelessWidget {
  final int eaten, goal, remaining;
  final double pct;
  final double proteinTotal, carbsTotal, fatTotal;
  final double proteinGoal, carbsGoal, fatGoal;
  final List<MealEntry> entries;
  final PrayerTimes? prayers;
  final DateTime now;
  final Animation<double> ringAnim;
  final Color calCol, card, border, muted, text;
  final bool isAr, isDark, isRamadan;
  final String lang;
  final VoidCallback onLog, onSearch;

  const TodayCard({
    super.key,
    required this.eaten,
    required this.goal,
    required this.remaining,
    required this.pct,
    required this.proteinTotal,
    required this.carbsTotal,
    required this.fatTotal,
    required this.proteinGoal,
    required this.carbsGoal,
    required this.fatGoal,
    required this.entries,
    required this.prayers,
    required this.now,
    required this.ringAnim,
    required this.calCol,
    required this.card,
    required this.border,
    required this.muted,
    required this.text,
    required this.isAr,
    required this.isDark,
    required this.isRamadan,
    required this.lang,
    required this.onLog,
    required this.onSearch,
  });

  String _t(String ar, String en) => tLang(lang, ar, en);

  @override
  Widget build(BuildContext context) {
    final over = eaten > goal;
    final accent = isRamadan ? AppColors.accentGold : AppColors.brandGreen;
    final shown = over ? eaten - goal : remaining;
    final String statusText;
    final IconData statusIcon;
    if (over) {
      statusText = _t('تجاوزت الهدف', 'Over goal');
      statusIcon = Icons.trending_up_rounded;
    } else if (pct > 0.85) {
      statusText = _t('اقتربت من الهدف', 'Almost there');
      statusIcon = Icons.flag_rounded;
    } else if (eaten == 0) {
      statusText = _t('ابدأ يومك', 'Start your day');
      statusIcon = Icons.wb_sunny_rounded;
    } else {
      statusText = _t('على المسار', 'On track');
      statusIcon = Icons.check_circle_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: calCol.withOpacity(0.28), width: 0.8),
        boxShadow: [
          BoxShadow(
              color: calCol.withOpacity(isDark ? 0.14 : 0.12),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF12281D), Color(0xFF0C1A14)]
                  : const [Colors.white, Color(0xFFEFF6F0)],
            ),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                    painter: _StarPainter(text.withOpacity(0.04))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(children: [
                // ── Header ──
                Row(children: [
                  Expanded(
                    child: Text(_t('سعرات اليوم', "Today's calories"),
                        style: TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: text)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: calCol.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statusIcon, size: 14, color: calCol),
                      const SizedBox(width: 5),
                      Text(statusText,
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: calCol)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Ring + remaining ──
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  HeroRing(
                    pct: pct,
                    ringAnim: ringAnim,
                    color: calCol,
                    eaten: eaten,
                    isDark: isDark,
                    muted: muted,
                    label: _t('مأكول', 'kcal eaten'),
                    size: 148,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(over ? _t('فوق الهدف', 'Over goal') : _t('المتبقي', 'Remaining'),
                              style: TextStyle(
                                  fontFamily: 'Aligarh',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: muted)),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: shown.toDouble()),
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => Text('${v.round()}',
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 44,
                                    height: 1.05,
                                    fontWeight: FontWeight.w900,
                                    color: calCol)),
                          ),
                          Text(_t('سعرة حرارية', 'calories'),
                              style: TextStyle(
                                  fontFamily: 'Aligarh',
                                  fontSize: 12,
                                  color: muted)),
                          const SizedBox(height: 10),
                          Text(
                              '${_t("تناولت", "Eaten")} $eaten  ·  ${_t("الهدف", "Goal")} $goal',
                              style: TextStyle(
                                  fontFamily: 'Aligarh',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: text.withOpacity(0.75))),
                        ]),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Macros ──
                Row(children: [
                  Expanded(
                      child: _MacroTile(
                          label: _t('بروتين', 'Protein'),
                          value: proteinTotal,
                          goal: proteinGoal,
                          color: AppColors.halalGreen,
                          text: text,
                          muted: muted)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MacroTile(
                          label: _t('كربوهيدرات', 'Carbs'),
                          value: carbsTotal,
                          goal: carbsGoal,
                          color: AppColors.waterBlue,
                          text: text,
                          muted: muted)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _MacroTile(
                          label: _t('دهون', 'Fat'),
                          value: fatTotal,
                          goal: fatGoal,
                          color: AppColors.accentGold,
                          text: text,
                          muted: muted)),
                ]),

                // ── Prophet's thirds reminder ──
                if (pct >= 0.90)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accent.withOpacity(0.22)),
                      ),
                      child: Text(
                        _t('اترك في معدتك مساحة — ثلث طعام وثلث شراب وثلث فراغ',
                            'Leave room in the stomach: a third food, a third drink, a third air'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 10.5,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.halalGreen : accent),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),

                // ── Actions ──
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onLog,
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isRamadan
                                  ? const [Color(0xFF7A5010), Color(0xFFD4A017)]
                                  : const [Color(0xFF2BB567), Color(0xFF1E9E52)]),
                          boxShadow: [
                            BoxShadow(
                                color: accent.withOpacity(0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.photo_camera_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(_t('سجّل وجبتك', 'Log a meal'),
                                  style: const TextStyle(
                                      fontFamily: 'Aligarh',
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onSearch,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: text.withOpacity(0.06),
                        border: Border.all(color: text.withOpacity(0.12)),
                      ),
                      child: Icon(Icons.search_rounded, color: text, size: 22),
                    ),
                  ),
                ]),

                // ── Day rhythm ──
                const SizedBox(height: 18),
                Divider(height: 1, color: text.withOpacity(0.08)),
                const SizedBox(height: 14),
                _DayRhythm(
                  entries: entries,
                  prayers: prayers,
                  now: now,
                  goal: goal,
                  isAr: isAr,
                  lang: lang,
                  text: text,
                  muted: muted,
                  accent: accent,
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final double value, goal;
  final Color color, text, muted;
  const _MacroTile({
    required this.label,
    required this.value,
    required this.goal,
    required this.color,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final frac = goal > 0 ? (value / goal).clamp(0.0, 1.0).toDouble() : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 4),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${value.round()}',
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: text)),
              Flexible(
                child: Text(' / ${goal.round()} g',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 10.5, color: muted)),
              ),
            ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac,
            minHeight: 6,
            color: color,
            backgroundColor: color.withOpacity(0.14),
          ),
        ),
      ]),
    );
  }
}

class _Mark {
  final String ar, en;
  final DateTime at;
  const _Mark(this.ar, this.en, this.at);
}

/// Today's meals on a timeline from just before Fajr to after Isha, beside the
/// five prayers, with three facts worked out from those timestamps.
class _DayRhythm extends StatelessWidget {
  final List<MealEntry> entries;
  final PrayerTimes? prayers;
  final DateTime now;
  final int goal;
  final bool isAr;
  final String lang;
  final Color text, muted, accent;

  const _DayRhythm({
    required this.entries,
    required this.prayers,
    required this.now,
    required this.goal,
    required this.isAr,
    required this.lang,
    required this.text,
    required this.muted,
    required this.accent,
  });

  String _t(String ar, String en) => tLang(lang, ar, en);

  String _dur(int m) {
    if (m < 60) return isAr ? '$m د' : '$m min';
    final h = m ~/ 60, r = m % 60;
    if (r == 0) return isAr ? '$h س' : '${h}h';
    return isAr ? '$h س $r د' : '${h}h ${r}m';
  }

  List<_Mark> _marks() {
    DateTime hm(int h, int m) =>
        DateTime(now.year, now.month, now.day, h, m);
    DateTime today(DateTime d) => hm(d.hour, d.minute);
    final p = prayers;
    if (p == null) {
      return [
        _Mark('الفجر', 'Fajr', hm(5, 12)),
        _Mark('الظهر', 'Dhuhr', hm(12, 18)),
        _Mark('العصر', 'Asr', hm(15, 42)),
        _Mark('المغرب', 'Maghrib', hm(18, 5)),
        _Mark('العشاء', 'Isha', hm(19, 28)),
      ];
    }
    return [
      _Mark('الفجر', 'Fajr', today(p.fajr)),
      _Mark('الظهر', 'Dhuhr', today(p.dhuhr)),
      _Mark('العصر', 'Asr', today(p.asr)),
      _Mark('المغرب', 'Maghrib', today(p.maghrib)),
      _Mark('العشاء', 'Isha', today(p.isha)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final marks = _marks();
    final start = marks.first.at.subtract(const Duration(minutes: 60));
    final end = marks.last.at.add(const Duration(minutes: 90));
    final total = end.difference(start).inMinutes.toDouble();
    double frac(DateTime d) => total <= 0
        ? 0.0
        : (d.difference(start).inMinutes / total).clamp(0.0, 1.0).toDouble();

    final meals = [...entries]..sort((a, b) => a.time.compareTo(b.time));
    final goalSafe = goal <= 0 ? 2000 : goal;

    // ── Facts ──
    final facts = <String>[];
    if (meals.isNotEmpty) {
      final last = meals.last;
      _Mark best = marks.first;
      var bestSigned = last.time.difference(best.at).inMinutes;
      for (final m in marks) {
        final d = last.time.difference(m.at).inMinutes;
        if (d.abs() < bestSigned.abs()) {
          best = m;
          bestSigned = d;
        }
      }
      final name = isAr ? best.ar : best.en;
      final where = bestSigned.abs() <= 5
          ? _t('عند $name', 'at $name')
          : (bestSigned > 0
              ? _t('بعد $name بـ ${_dur(bestSigned)}',
                  '${_dur(bestSigned)} after $name')
              : _t('قبل $name بـ ${_dur(-bestSigned)}',
                  '${_dur(-bestSigned)} before $name'));
      facts.add('${_t("آخر وجبة", "Last meal")}: $where');

      if (meals.length >= 2) {
        var gap = 0;
        for (var i = 1; i < meals.length; i++) {
          final g = meals[i].time.difference(meals[i - 1].time).inMinutes;
          if (g > gap) gap = g;
        }
        if (gap > 0) {
          facts.add('${_t("أطول فترة بين وجبتين", "Longest gap")}: ${_dur(gap)}');
        }
      }

      final sum = meals.fold<int>(0, (a, m) => a + m.kcal);
      final ishaAt = marks.last.at;
      final late = meals
          .where((m) => !m.time.isBefore(ishaAt))
          .fold<int>(0, (a, m) => a + m.kcal);
      if (sum > 0 && late / sum >= 0.3) {
        final share = (late / sum * 100).round();
        facts.add(_t('$share% من سعراتك بعد العشاء',
            '$share% of your calories after Isha'));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.timeline_rounded, size: 17, color: accent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_t('إيقاع يومك مع الصلوات', 'Your day, between prayers'),
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: text)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accentGold.withOpacity(0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(_t('جديد', 'NEW'),
              style: const TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accentGold)),
        ),
      ]),
      const SizedBox(height: 6),
      SizedBox(
        height: 78,
        child: LayoutBuilder(builder: (_, c) {
          final w = c.maxWidth;
          final xNow = w * frac(now);
          final kids = <Widget>[
            PositionedDirectional(
              start: 0,
              end: 0,
              top: 36,
              height: 6,
              child: Container(
                  decoration: BoxDecoration(
                      color: text.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(3))),
            ),
            PositionedDirectional(
              start: 0,
              top: 36,
              height: 6,
              width: xNow,
              child: Container(
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(3))),
            ),
          ];
          for (final m in marks) {
            final x = w * frac(m.at);
            final lx = (x - 24).clamp(0.0, math.max(0.0, w - 48)).toDouble();
            kids.add(PositionedDirectional(
              start: x - 1,
              top: 29,
              width: 2,
              height: 20,
              child: Container(color: muted.withOpacity(0.55)),
            ));
            kids.add(PositionedDirectional(
              start: lx,
              top: 54,
              width: 48,
              child: Text(isAr ? m.ar : m.en,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 9.5, color: muted)),
            ));
          }
          for (final e in meals) {
            final x = w * frac(e.time);
            final d = (9 + e.kcal / goalSafe * 40).clamp(9.0, 20.0).toDouble();
            kids.add(PositionedDirectional(
              start: x - d / 2,
              top: 39 - d / 2,
              width: d,
              height: d,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentGold,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.85), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.accentGold.withOpacity(0.45),
                        blurRadius: 6),
                  ],
                ),
              ),
            ));
          }
          kids.add(PositionedDirectional(
            start: xNow - 8,
            top: 10,
            child: const Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: AppColors.halalGreen),
          ));
          return Stack(clipBehavior: Clip.none, children: kids);
        }),
      ),
      const SizedBox(height: 4),
      if (facts.isEmpty)
        Text(
            _t('سجّل وجبة لتظهر على خط يومك.',
                'Log a meal and it will appear on your timeline.'),
            style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 11.5, color: muted))
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final f in facts)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: text.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(f,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: text)),
            ),
        ]),
    ]);
  }
}

/// Faint eight-pointed stars (two overlapping squares) tiled across the card.
class _StarPainter extends CustomPainter {
  final Color color;
  const _StarPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const step = 54.0;
    const r = 15.0;
    var row = 0;
    for (var y = 0.0; y < size.height + step; y += step) {
      final shift = row.isOdd ? step / 2 : 0.0;
      for (var x = 0.0; x < size.width + step; x += step) {
        final cx = x + shift;
        for (var k = 0; k < 2; k++) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final a = math.pi / 4 * k + math.pi / 2 * i;
            final dx = cx + r * math.cos(a);
            final dy = y + r * math.sin(a);
            if (i == 0) {
              path.moveTo(dx, dy);
            } else {
              path.lineTo(dx, dy);
            }
          }
          path.close();
          canvas.drawPath(path, p);
        }
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}
