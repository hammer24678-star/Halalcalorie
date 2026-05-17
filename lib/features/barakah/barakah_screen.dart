// barakah_screen.dart — HalalCalorie Build 38
// The Barakah Engine: 8-pillar score, dhikr check-in,
// Friday weekly report, 20-badge shelf.
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';

class BarakahScreen extends ConsumerStatefulWidget {
  const BarakahScreen({super.key});
  @override ConsumerState<BarakahScreen> createState() => _BarakahState();
}

class _BarakahState extends ConsumerState<BarakahScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _stagger;
  Animation<double> _fade(int i) => CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.10, (i * 0.10 + 0.55).clamp(0, 1),
          curve: Curves.easeOutCubic));
  Animation<Offset> _slide(int i) => Tween<Offset>(
      begin: const Offset(0, 0.14), end: Offset.zero).animate(CurvedAnimation(
      parent: _stagger,
      curve: Interval(i * 0.10, (i * 0.10 + 0.55).clamp(0, 1),
          curve: Curves.easeOutCubic)));
  Widget _anim(int i, Widget child) => FadeTransition(
      opacity: _fade(i),
      child: SlideTransition(position: _slide(i), child: child));

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    // Trigger a fresh sync whenever the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(barakahProvider.notifier).refresh();
    });
  }

  @override
  void dispose() { _stagger.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final barakah  = ref.watch(barakahProvider);
    final badges   = ref.watch(badgeProvider);
    final lang     = ref.watch(languageProvider);
    final isAr     = lang == 'ar' || lang == 'ur';
    final isDark   = ref.watch(themeProvider);
    final isRamadan= ref.watch(ramadanModeProvider);
    final l        = L.fromLang(lang);
    final weekAsync= ref.watch(barakahWeekProvider);

    final bg    = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final card  = isDark ? AppColors.darkCard  : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final text  = isDark ? AppColors.darkText  : AppColors.lightText;
    final border= isDark ? AppColors.darkBorder: AppColors.lightBorder;

    final scoreColor  = barakah.tierColor();
    final isFriday    = DateTime.now().weekday == DateTime.friday;

    // ── pillar data ─────────────────────────────────────────────────
    final pillars = [
      _Pillar(l.pillarNutrition, '🍽️', barakah.nutrition,  AppColors.halalGreen),
      _Pillar(l.pillarHydration, '💧', barakah.hydration,  AppColors.waterBlue),
      _Pillar(l.pillarSleep,     '😴', barakah.sleep,      AppColors.sleepPurple),
      _Pillar(l.pillarMovement,  '👟', barakah.movement,   AppColors.sunnahGreen),
      _Pillar(l.pillarFasting,   '🌙', barakah.fasting,    AppColors.barakahGold),
      _Pillar(l.pillarSunnahFood,'🍯', barakah.sunnahFood, AppColors.doubtOrange),
      _Pillar(l.pillarWorkout,   '💪', barakah.workout,    AppColors.haramRed),
      _Pillar(l.pillarDhikr,     '🤲', barakah.dhikr,      AppColors.barakahGold),
    ];

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isRamadan
                    ? [AppColors.ramadanNight, AppColors.ramadanCard]
                    : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          title: Text(l.barakahTitle,
              style: TextStyle(
                  fontFamily: 'Cairo', fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isRamadan ? AppColors.ramadanGold : AppColors.barakahGold)),
          subtitle: Text(l.barakahSubtitle,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 11,
                  color: isRamadan ? AppColors.ramadanMuted : Colors.white54)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [

            // ── [0] SCORE HERO ──────────────────────────────────────
            _anim(0, _ScoreHero(
              score: barakah.score,
              tierLabel: isAr ? barakah.tierAr() : barakah.tierEn(),
              scoreColor: scoreColor,
              isDark: isDark,
              card: card, border: border, muted: muted,
            )),
            const SizedBox(height: 14),

            // ── [1] FRIDAY REPORT (only on Fridays) ─────────────────
            if (isFriday) ...[
              _anim(1, weekAsync.when(
                loading: () => const SizedBox.shrink(),
                error:   (_, __) => const SizedBox.shrink(),
                data: (week) => _FridayReport(
                  week: week, lang: lang, isAr: isAr,
                  isDark: isDark, card: card, border: border,
                  muted: muted, text: text, scoreColor: scoreColor,
                ),
              )),
              const SizedBox(height: 14),
            ],

            // ── [2] DHIKR CHECK-IN ──────────────────────────────────
            _anim(2, _DhikrCard(
              done: barakah.dhikr > 0,
              label:    barakah.dhikr > 0 ? l.dhikrDone : l.dhikrTap,
              isDark: isDark, card: card, border: border,
              scoreColor: scoreColor,
              onTap: () {
                HapticFeedback.mediumImpact();
                ref.read(barakahProvider.notifier).toggleDhikr();
              },
            )),
            const SizedBox(height: 14),

            // ── [3] PILLARS GRID ────────────────────────────────────
            _anim(3, _PillarsGrid(
              pillars: pillars, isDark: isDark,
              card: card, border: border, muted: muted, text: text,
            )),
            const SizedBox(height: 14),

            // ── [4] BADGE SHELF ─────────────────────────────────────
            _anim(4, _BadgeShelf(
              earned: badges.earned,
              isAr: isAr, isDark: isDark,
              card: card, border: border, muted: muted, text: text,
              label: l.badgesTitle,
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// SCORE HERO
// ════════════════════════════════════════════════════════════════════
class _ScoreHero extends StatefulWidget {
  final int score; final String tierLabel; final Color scoreColor;
  final bool isDark; final Color card, border, muted;
  const _ScoreHero({required this.score, required this.tierLabel,
    required this.scoreColor, required this.isDark,
    required this.card, required this.border, required this.muted});
  @override State<_ScoreHero> createState() => _ScoreHeroState();
}

class _ScoreHeroState extends State<_ScoreHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fill;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fill = Tween<double>(begin: 0, end: widget.score / 1000)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_ScoreHero old) {
    super.didUpdateWidget(old);
    if (old.score != widget.score) {
      _fill = Tween<double>(
          begin: old.score / 1000, end: widget.score / 1000)
          .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: widget.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.scoreColor.withOpacity(0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: widget.scoreColor.withOpacity(widget.isDark ? 0.18 : 0.1),
              blurRadius: 28, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(children: [
        SizedBox(width: 180, height: 180, child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _fill,
              builder: (_, __) => CustomPaint(
                size: const Size(180, 180),
                painter: _ArcPainter(
                    value: _fill.value,
                    color: widget.scoreColor,
                    isDark: widget.isDark),
              ),
            ),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedBuilder(
                animation: _fill,
                builder: (_, __) => Text(
                  '${(_fill.value * 1000).toInt()}',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: widget.scoreColor, height: 1),
                ),
              ),
              Text('/ 1000', style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 13,
                  color: widget.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(widget.tierLabel, style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 14,
                  fontWeight: FontWeight.w700, color: widget.scoreColor)),
            ]),
          ],
        )),
      ]),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double value; final Color color; final bool isDark;
  const _ArcPainter({required this.value, required this.color,
    required this.isDark});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2; final cy = size.height / 2;
    final r  = size.width / 2 - 12;
    final bg = Paint()
      ..color = isDark ? const Color(0xFF21262D) : const Color(0xFFE8E8E8)
      ..strokeWidth = 14 ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fg = Paint()
      ..color = color ..strokeWidth = 14 ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -pi / 2 + 0.15, 2 * pi - 0.30, false, bg);
    if (value > 0)
      canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          -pi / 2 + 0.15, (2 * pi - 0.30) * value, false, fg);
  }
  @override bool shouldRepaint(_ArcPainter o) =>
      o.value != value || o.color != color;
}

// ════════════════════════════════════════════════════════════════════
// FRIDAY REPORT
// ════════════════════════════════════════════════════════════════════
class _FridayReport extends StatelessWidget {
  final List<Map<String,dynamic>> week;
  final String lang; final bool isAr, isDark;
  final Color card, border, muted, text, scoreColor;
  const _FridayReport({required this.week, required this.lang,
    required this.isAr, required this.isDark, required this.card,
    required this.border, required this.muted, required this.text,
    required this.scoreColor});

  @override
  Widget build(BuildContext context) {
    final l    = L.fromLang(lang);
    final days = ['S','M','T','W','T','F','S'];
    final avg  = week.isEmpty ? 0
        : week.fold(0, (s, r) => s + (r['score'] as int? ?? 0)) ~/ week.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.barakahGold.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: AppColors.barakahGold.withOpacity(0.08),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📊', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(l.weeklyReport, style: const TextStyle(fontFamily: 'Cairo',
              fontWeight: FontWeight.w800, fontSize: 14,
              color: AppColors.barakahGold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.barakahGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20)),
            child: Text('⌀ $avg', style: const TextStyle(
                fontFamily: 'Cairo', fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.barakahGold)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            final row  = i < week.length ? week[i] : null;
            final score= (row?['score'] as int? ?? 0);
            final pct  = score / 1000.0;
            return Column(children: [
              Text(days[i], style: TextStyle(fontFamily: 'Cairo',
                  fontSize: 9, color: muted)),
              const SizedBox(height: 4),
              Container(
                width: 30, height: 60,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF21262D) : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  height: 60 * pct,
                  decoration: BoxDecoration(
                    color: score > 0 ? scoreColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 4),
              Text(score > 0 ? '$score' : '-',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 8, color: muted)),
            ]);
          }),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DHIKR CHECK-IN CARD
// ════════════════════════════════════════════════════════════════════
class _DhikrCard extends StatelessWidget {
  final bool done; final String label;
  final bool isDark; final Color card, border, scoreColor;
  final VoidCallback onTap;
  const _DhikrCard({required this.done, required this.label,
    required this.isDark, required this.card, required this.border,
    required this.scoreColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: done
              ? AppColors.barakahGold.withOpacity(isDark ? 0.15 : 0.1)
              : card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: done
                  ? AppColors.barakahGold.withOpacity(0.6)
                  : border,
              width: done ? 1.5 : 0.8),
          boxShadow: done ? [BoxShadow(
              color: AppColors.barakahGold.withOpacity(0.18),
              blurRadius: 18, offset: const Offset(0, 5))] : [],
        ),
        child: Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(done ? '✅' : '🤲',
                key: ValueKey(done),
                style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label,
            style: TextStyle(fontFamily: 'Cairo',
                fontSize: 14, fontWeight: FontWeight.w700,
                color: done ? AppColors.barakahGold
                    : (isDark ? AppColors.darkText : AppColors.lightText)))),
          Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              color: done ? AppColors.barakahGold : AppColors.darkMuted, size: 22),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// PILLARS GRID
// ════════════════════════════════════════════════════════════════════
class _Pillar { final String name; final String emoji;
  final int value; final Color color;
  const _Pillar(this.name, this.emoji, this.value, this.color);
}

class _PillarsGrid extends StatelessWidget {
  final List<_Pillar> pillars; final bool isDark;
  final Color card, border, muted, text;
  const _PillarsGrid({required this.pillars, required this.isDark,
    required this.card, required this.border,
    required this.muted, required this.text});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, mainAxisSpacing: 10,
          crossAxisSpacing: 10, childAspectRatio: 0.85),
      itemCount: pillars.length,
      itemBuilder: (_, i) {
        final p   = pillars[i];
        final pct = (p.value / 125).clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: card, borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: p.value > 0
                    ? p.color.withOpacity(0.3)
                    : border, width: 0.8),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(p.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct, minHeight: 5,
                backgroundColor: isDark ? const Color(0xFF21262D)
                    : const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation(p.color),
              ),
            ),
            const SizedBox(height: 4),
            Text(p.name,
              style: TextStyle(fontFamily: 'Cairo', fontSize: 8,
                  color: muted, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            Text('${p.value}', style: TextStyle(fontFamily: 'Cairo',
                fontSize: 10, fontWeight: FontWeight.w900,
                color: p.value > 0 ? p.color : muted)),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// BADGE SHELF
// ════════════════════════════════════════════════════════════════════
class _BadgeShelf extends StatelessWidget {
  final Set<int> earned; final bool isAr, isDark;
  final Color card, border, muted, text; final String label;
  const _BadgeShelf({required this.earned, required this.isAr,
    required this.isDark, required this.card, required this.border,
    required this.muted, required this.text, required this.label});
  @override
  Widget build(BuildContext context) {
    final earnedCount = kBadges.where((b) => earned.contains(b.id)).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🏅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontFamily: 'Cairo',
              fontWeight: FontWeight.w800, fontSize: 14, color: text))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.barakahGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: Text('$earnedCount/${kBadges.length}',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.barakahGold)),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: kBadges.map((b) {
          final done = earned.contains(b.id);
          return AnimatedOpacity(
            opacity: done ? 1.0 : 0.28,
            duration: const Duration(milliseconds: 400),
            child: Tooltip(
              message: isAr ? b.descAr : b.descEn,
              child: Container(
                width: 68,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.barakahGold.withOpacity(0.1)
                      : (isDark ? const Color(0xFF1A1F26) : const Color(0xFFF0F0F0)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: done
                          ? AppColors.barakahGold.withOpacity(0.5)
                          : Colors.transparent)),
                child: Column(children: [
                  Text(b.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 3),
                  Text(isAr ? b.nameAr : b.nameEn,
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: done ? AppColors.barakahGold : muted),
                    textAlign: TextAlign.center,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (done) const Icon(Icons.check_circle_rounded,
                      color: AppColors.barakahGold, size: 10),
                ]),
              ),
            ),
          );
        }).toList()),
      ]),
    );
  }
}
