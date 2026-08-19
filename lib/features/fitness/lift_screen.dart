// ════════════════════════════════════════════════════════════════════
//  lift_screen.dart — ranked lifting
//
//  Every exercise carries its own rank, earned by what you actually
//  lift relative to your bodyweight. Log a set and the app estimates
//  your one-rep max, places it on the ladder, and tells you how much
//  more it takes to reach the next division.
//
//  Two screens live here: the hub listing every exercise with its rank,
//  and the detail screen where sets are logged.
// ════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';

// ════════════════════════════════════════════════════════════════════
// SHARED PIECES
// ════════════════════════════════════════════════════════════════════

/// The rank shield: tier colour, division numeral, LP underneath.
class RankBadge extends StatelessWidget {
  final StrengthRank rank;
  final double size;
  final bool showLp;
  final bool arabic;

  const RankBadge({
    super.key,
    required this.rank,
    this.size = 64,
    this.showLp = false,
    this.arabic = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = rank.color;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: Size(size, size),
            painter: _ShieldPainter(
                color: color, progress: rank.divisionProgress),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              rank.tier.hasDivisions
                  ? rank.tier.nameEn[0].toUpperCase()
                  : '★',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: size * 0.34,
                height: 1,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            if (rank.tier.hasDivisions)
              Text(
                rank.divisionNumeral,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: size * 0.17,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: color.withOpacity(0.85),
                ),
              ),
          ]),
        ]),
      ),
      if (showLp) ...[
        const SizedBox(height: 4),
        Text('${rank.lp} LP',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: size * 0.15,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    ]);
  }
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  final double progress;
  const _ShieldPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;

    // Hexagonal plate.
    final plate = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? plate.moveTo(p.dx, p.dy) : plate.lineTo(p.dx, p.dy);
    }
    plate.close();

    canvas.drawPath(plate, Paint()..color = color.withOpacity(0.13));
    canvas.drawPath(
      plate,
      Paint()
        ..color = color.withOpacity(0.55)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );

    // Progress toward the next division, drawn just inside the plate.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - 4),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ShieldPainter old) =>
      old.color != color || old.progress != progress;
}

/// Compact rank pill, e.g. "Silver II · 42 LP".
class RankChip extends StatelessWidget {
  final StrengthRank rank;
  final bool arabic;
  final bool showLp;
  const RankChip(
      {super.key, required this.rank, this.arabic = false, this.showLp = true});

  @override
  Widget build(BuildContext context) {
    final label = rank.label(arabic: arabic);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: rank.color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rank.color.withOpacity(0.45)),
      ),
      child: Text(
        showLp ? '$label · ${rank.lp} LP' : label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: rank.color,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// HUB
// ════════════════════════════════════════════════════════════════════

class LiftScreen extends ConsumerStatefulWidget {
  const LiftScreen({super.key});
  @override
  ConsumerState<LiftScreen> createState() => _LiftScreenState();
}

class _LiftScreenState extends ConsumerState<LiftScreen> {
  late final ConfettiController _confetti = ConfettiController(
      duration: const Duration(milliseconds: 1200));
  bool _promotionShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(liftLogProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _maybeCelebratePromotion() {
    final notifier = ref.read(liftLogProvider.notifier);
    final to = notifier.pendingPromotionTo;
    final from = notifier.pendingPromotionFrom;
    if (to == null || from == null || _promotionShown || !mounted) return;
    _promotionShown = true;
    notifier.consumePromotion();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _confetti.play();
      showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _PromotionDialog(
            from: from, to: to, lang: ref.read(languageProvider)),
      ).then((_) => _promotionShown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final l = L.fromLang(lang);
    final isDark = ref.watch(themeProvider);
    final log = ref.watch(liftLogProvider);
    final bodyweight = ref.watch(rankingBodyweightProvider);
    _maybeCelebratePromotion();

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    final overall = log.overall;

    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(l.liftTitle,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        ),
        body: Stack(children: [
          RefreshIndicator(
            color: overall.color,
            onRefresh: () => ref.read(liftLogProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
              children: [
                // ── Overall rank ──
                Reveal(
                  index: 0,
                  child: _OverallCard(
                    rank: overall,
                    lang: lang,
                    card: card,
                    border: border,
                    text: text,
                    muted: muted,
                    todaySets: log.todaySets,
                    todayVolume: log.todayVolumeKg,
                    ranked: log.bests.length,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Bodyweight is required to rank a lift ──
                if (bodyweight <= 0)
                  Reveal(
                    index: 1,
                    child: _NeedsBodyweight(
                        lang: lang, card: card, onTap: () => context.go('/body')),
                  ),

                // ── Exercises by muscle group ──
                ...() {
                  final widgets = <Widget>[];
                  var i = 2;
                  for (final group in kLiftGroups) {
                    final items = kLiftExercises
                        .where((e) => e.group == group)
                        .toList();
                    if (items.isEmpty) continue;
                    widgets.add(Reveal(
                      index: i++,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                        child: Text(
                          liftGroupName(group, arabic: l.isAr).toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            color: muted,
                          ),
                        ),
                      ),
                    ));
                    for (final exercise in items) {
                      widgets.add(Reveal(
                        index: i++,
                        child: _ExerciseRow(
                          exercise: exercise,
                          rank: log.rankFor(exercise.id),
                          logged: log.bests.containsKey(exercise.id),
                          best: log.bestSets[exercise.id],
                          lang: lang,
                          card: card,
                          border: border,
                          text: text,
                          muted: muted,
                          onTap: () => context.push('/lift/${exercise.id}'),
                        ),
                      ));
                    }
                  }
                  return widgets;
                }(),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 16,
              minBlastForce: 6,
              gravity: 0.25,
              shouldLoop: false,
              colors: [overall.color, AppColors.accentGold, Colors.white],
            ),
          ),
        ]),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  final StrengthRank rank;
  final String lang;
  final Color card, border, text, muted;
  final int todaySets, ranked;
  final double todayVolume;

  const _OverallCard({
    required this.rank,
    required this.lang,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.todaySets,
    required this.todayVolume,
    required this.ranked,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final toNext = rank.lpToNextDivision;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rank.color.withOpacity(0.32), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: rank.color.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        Row(children: [
          PulseGlow(
            color: rank.color,
            maxOpacity: 0.30,
            borderRadius: BorderRadius.circular(16),
            child: RankBadge(rank: rank, size: 76, arabic: l.isAr),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.overallRankLabel,
                      style: TextStyle(
                          fontFamily: 'Cairo', fontSize: 11, color: muted)),
                  const SizedBox(height: 2),
                  Text(rank.label(arabic: l.isAr),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: rank.color)),
                  const SizedBox(height: 8),
                  AnimatedBar(
                    value: rank.divisionProgress,
                    color: rank.color,
                    background: border,
                    height: 7,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    toNext == null
                        ? l.maxRankReached
                        : '$toNext LP ${l.toNextDivision}',
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 10.5, color: muted),
                  ),
                ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _stat('$todaySets', l.setsToday, muted, text),
          _divider(border),
          _stat('${todayVolume.round()} kg', l.volumeToday, muted, text),
          _divider(border),
          _stat('$ranked/${kLiftExercises.length}', l.liftsRanked, muted, text),
        ]),
      ]),
    );
  }

  Widget _stat(String value, String label, Color muted, Color text) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: text)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 9.5, color: muted)),
        ]),
      );

  Widget _divider(Color border) =>
      Container(width: 1, height: 30, color: border);
}

class _NeedsBodyweight extends StatelessWidget {
  final String lang;
  final Color card;
  final VoidCallback onTap;
  const _NeedsBodyweight(
      {required this.lang, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    return PressFx(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.doubtOrange.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.doubtOrange.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Text('⚖️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.needBodyweight,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: AppColors.doubtOrange)),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 12, color: AppColors.doubtOrange),
        ]),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final LiftExercise exercise;
  final StrengthRank rank;
  final bool logged;
  final LiftSet? best;
  final String lang;
  final Color card, border, text, muted;
  final VoidCallback onTap;

  const _ExerciseRow({
    required this.exercise,
    required this.rank,
    required this.logged,
    required this.best,
    required this.lang,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    return PressFx(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: logged ? rank.color.withOpacity(0.30) : border,
            width: logged ? 1.1 : 0.8,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (logged ? rank.color : muted).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(exercise.glyph,
                    style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise.name(arabic: l.isAr),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: text)),
                  const SizedBox(height: 4),
                  if (logged) ...[
                    AnimatedBar(
                      value: rank.divisionProgress,
                      color: rank.color,
                      background: border,
                      height: 4,
                      radius: 3,
                    ),
                    const SizedBox(height: 4),
                    Text(_bestLine(l),
                        style: TextStyle(
                            fontFamily: 'Cairo', fontSize: 9.5, color: muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ] else
                    Text(l.notRankedYet,
                        style: TextStyle(
                            fontFamily: 'Cairo', fontSize: 10, color: muted)),
                ]),
          ),
          const SizedBox(width: 8),
          if (logged)
            RankChip(rank: rank, arabic: l.isAr)
          else
            Icon(Icons.add_circle_outline, size: 20, color: muted),
        ]),
      ),
    );
  }

  String _bestLine(L l) {
    final b = best;
    if (b == null) return '';
    switch (exercise.kind) {
      case LiftKind.timed:
        return '${l.bestLabel}: ${b.seconds}s';
      case LiftKind.bodyweight:
        return '${l.bestLabel}: ${b.reps} ${l.repsLabel}';
      case LiftKind.loaded:
      case LiftKind.weightedBodyweight:
        return '${l.bestLabel}: ${b.weightKg.toStringAsFixed(1)} kg '
            '× ${b.reps}';
    }
  }
}

class _PromotionDialog extends StatelessWidget {
  final StrengthRank from, to;
  final String lang;
  const _PromotionDialog(
      {required this.from, required this.to, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1119),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: to.color.withOpacity(0.5), width: 1.4),
          boxShadow: [
            BoxShadow(color: to.color.withOpacity(0.3), blurRadius: 40),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.rankUp,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                  color: to.color)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Opacity(
                opacity: 0.45,
                child: RankBadge(rank: from, size: 56, arabic: l.isAr)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Icon(Icons.arrow_forward_rounded,
                  color: to.color, size: 22),
            ),
            PopIn(child: RankBadge(rank: to, size: 76, arabic: l.isAr)),
          ]),
          const SizedBox(height: 18),
          Text(to.label(arabic: l.isAr),
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: to.color)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: to.color,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(l.continueLabel,
                  style: const TextStyle(
                      fontFamily: 'Cairo', fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DETAIL — log sets, see the rank move
// ════════════════════════════════════════════════════════════════════

class LiftDetailScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  const LiftDetailScreen({super.key, required this.exerciseId});
  @override
  ConsumerState<LiftDetailScreen> createState() => _LiftDetailScreenState();
}

class _LiftDetailScreenState extends ConsumerState<LiftDetailScreen> {
  double _weight = 20;
  int _reps = 5;
  int _seconds = 45;
  bool _saving = false;

  // Rest timer
  Timer? _restTimer;
  int _restLeft = 0;
  int _restTotal = 0;

  @override
  void initState() {
    super.initState();
    // Start from the last set for this exercise, so repeating a session
    // is a couple of taps rather than a full re-entry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final log = ref.read(liftLogProvider);
      final last = log.recent.where((s) => s.exerciseId == widget.exerciseId);
      if (last.isEmpty) return;
      final s = last.first;
      if (!mounted) return;
      setState(() {
        if (s.weightKg > 0) _weight = s.weightKg;
        if (s.reps > 0) _reps = s.reps;
        if (s.seconds > 0) _seconds = s.seconds;
      });
    });
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restTotal = seconds;
      _restLeft = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _restLeft--);
      if (_restLeft <= 0) {
        timer.cancel();
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _stopRest() {
    _restTimer?.cancel();
    if (mounted) setState(() => _restLeft = 0);
  }

  Future<void> _log(LiftExercise exercise, double bodyweight) async {
    if (_saving) return;
    setState(() => _saving = true);
    final profile = ref.read(userProfileProvider);
    final isMale = profile?.isMale ?? (ref.read(genderProvider) != 'sisters');

    final isPr = await ref.read(liftLogProvider.notifier).logSet(
          exercise: exercise,
          isMale: isMale,
          bodyweightKg: bodyweight,
          weightKg: exercise.kind == LiftKind.bodyweight ||
                  exercise.kind == LiftKind.timed
              ? 0
              : _weight,
          reps: exercise.kind == LiftKind.timed ? 1 : _reps,
          seconds: exercise.kind == LiftKind.timed ? _seconds : 0,
        );

    // A logged set is training minutes too, so the day's quest moves.
    await ref.read(workoutMinutesProvider.notifier).add(exercise.id, 2);
    ref.read(ascentProvider.notifier).refresh();

    if (!mounted) return;
    setState(() => _saving = false);
    HapticFeedback.mediumImpact();
    _startRest(exercise.kind == LiftKind.timed ? 60 : 90);

    final l = L.fromLang(ref.read(languageProvider));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isPr ? '🏆 ${l.newPersonalBest}' : '✓ ${l.setLogged}',
          style: const TextStyle(
              fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
      backgroundColor:
          isPr ? AppColors.accentGold : AppColors.brandGreen,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isPr ? 3 : 2),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final exercise = liftById(widget.exerciseId);
    final lang = ref.watch(languageProvider);
    final l = L.fromLang(lang);
    final isDark = ref.watch(themeProvider);

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
            child: Text(l.notFound,
                style: const TextStyle(fontFamily: 'Cairo'))),
      );
    }

    final log = ref.watch(liftLogProvider);
    final bodyweight = ref.watch(rankingBodyweightProvider);
    final profile = ref.watch(userProfileProvider);
    final isMale = profile?.isMale ?? (ref.watch(genderProvider) != 'sisters');
    final historyAsync = ref.watch(liftHistoryProvider(exercise.id));

    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;

    final currentRank = log.rankFor(exercise.id);

    // What this set would be worth if logged right now.
    final previewRank = bodyweight <= 0
        ? const StrengthRank(0)
        : rankForSet(
            exercise: exercise,
            isMale: isMale,
            bodyweightKg: bodyweight,
            weightKg: exercise.kind == LiftKind.bodyweight ||
                    exercise.kind == LiftKind.timed
                ? 0
                : _weight,
            reps: exercise.kind == LiftKind.timed ? 1 : _reps,
            seconds: exercise.kind == LiftKind.timed ? _seconds : 0,
          );
    final wouldBePr = previewRank.totalLp > currentRank.totalLp;

    return Directionality(
      textDirection: l.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(exercise.name(arabic: l.isAr),
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: RankChip(rank: currentRank, arabic: l.isAr)),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
          children: [
            // ── Current standing ──
            Reveal(
              index: 0,
              child: _StandingCard(
                exercise: exercise,
                rank: currentRank,
                best: log.bestSets[exercise.id],
                lang: lang,
                card: card,
                border: border,
                text: text,
                muted: muted,
              ),
            ),
            const SizedBox(height: 12),

            // ── Rest timer, only while it runs ──
            if (_restLeft > 0) ...[
              _RestTimerCard(
                left: _restLeft,
                total: _restTotal,
                lang: lang,
                card: card,
                border: border,
                text: text,
                muted: muted,
                onSkip: _stopRest,
                onAdd: () => _startRest(_restLeft + 30),
              ),
              const SizedBox(height: 12),
            ],

            // ── Entry ──
            Reveal(
              index: 1,
              child: _EntryCard(
                exercise: exercise,
                weight: _weight,
                reps: _reps,
                seconds: _seconds,
                preview: previewRank,
                wouldBePr: wouldBePr,
                bodyweight: bodyweight,
                saving: _saving,
                lang: lang,
                card: card,
                border: border,
                text: text,
                muted: muted,
                onWeight: (v) => setState(() => _weight = v),
                onReps: (v) => setState(() => _reps = v),
                onSeconds: (v) => setState(() => _seconds = v),
                onLog: bodyweight <= 0
                    ? null
                    : () => _log(exercise, bodyweight),
              ),
            ),
            const SizedBox(height: 12),

            // ── What each tier asks for ──
            Reveal(
              index: 2,
              child: _StandardsCard(
                exercise: exercise,
                isMale: isMale,
                bodyweight: bodyweight,
                current: currentRank,
                lang: lang,
                card: card,
                border: border,
                text: text,
                muted: muted,
              ),
            ),
            const SizedBox(height: 12),

            // ── History ──
            Reveal(
              index: 3,
              child: historyAsync.when(
                loading: () => _HistorySkeleton(card: card, border: border),
                error: (_, __) => const SizedBox.shrink(),
                data: (sets) => _HistoryCard(
                  exercise: exercise,
                  sets: sets,
                  lang: lang,
                  card: card,
                  border: border,
                  text: text,
                  muted: muted,
                  onDelete: (id) =>
                      ref.read(liftLogProvider.notifier).removeSet(id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingCard extends StatelessWidget {
  final LiftExercise exercise;
  final StrengthRank rank;
  final LiftSet? best;
  final String lang;
  final Color card, border, text, muted;

  const _StandingCard({
    required this.exercise,
    required this.rank,
    required this.best,
    required this.lang,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final toNext = rank.lpToNextDivision;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rank.color.withOpacity(0.3), width: 1.2),
      ),
      child: Column(children: [
        RankBadge(rank: rank, size: 92, arabic: l.isAr),
        const SizedBox(height: 10),
        Text(rank.label(arabic: l.isAr),
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: rank.color)),
        const SizedBox(height: 12),
        AnimatedBar(
          value: rank.divisionProgress,
          color: rank.color,
          background: border,
          height: 8,
        ),
        const SizedBox(height: 6),
        Text(
          toNext == null ? l.maxRankReached : '$toNext LP ${l.toNextDivision}',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: muted),
        ),
        if (best != null) ...[
          const SizedBox(height: 14),
          Container(height: 1, color: border),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🏆', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(_bestText(l),
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: text)),
          ]),
        ],
      ]),
    );
  }

  String _bestText(L l) {
    final b = best!;
    switch (exercise.kind) {
      case LiftKind.timed:
        return '${l.bestLabel}: ${b.seconds}s';
      case LiftKind.bodyweight:
        return '${l.bestLabel}: ${b.reps} ${l.repsLabel}';
      case LiftKind.loaded:
      case LiftKind.weightedBodyweight:
        final e1rm = estimateOneRepMax(
            exercise.kind == LiftKind.weightedBodyweight
                ? b.bodyweightKg + b.weightKg
                : b.weightKg,
            b.reps);
        return '${l.bestLabel}: ${b.weightKg.toStringAsFixed(1)} kg × ${b.reps}'
            '  ·  1RM ≈ ${e1rm.round()} kg';
    }
  }
}

class _RestTimerCard extends StatelessWidget {
  final int left, total;
  final String lang;
  final Color card, border, text, muted;
  final VoidCallback onSkip, onAdd;

  const _RestTimerCard({
    required this.left,
    required this.total,
    required this.lang,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.onSkip,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final progress = total <= 0 ? 0.0 : (total - left) / total;
    final minutes = left ~/ 60;
    final seconds = left % 60;
    return PulseGlow(
      color: AppColors.waterBlue,
      maxOpacity: 0.22,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.waterBlue.withOpacity(0.45)),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.restTimer,
                style: TextStyle(
                    fontFamily: 'Cairo', fontSize: 10.5, color: muted)),
            Text('$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 30,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: AppColors.waterBlue)),
          ]),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedBar(
              value: progress,
              color: AppColors.waterBlue,
              background: border,
              height: 7,
              duration: Motion.quick,
            ),
          ),
          const SizedBox(width: 12),
          PressFx(
            onTap: onAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.waterBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('+30',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.waterBlue)),
            ),
          ),
          const SizedBox(width: 6),
          PressFx(
            onTap: onSkip,
            child: Icon(Icons.close_rounded, size: 20, color: muted),
          ),
        ]),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final LiftExercise exercise;
  final double weight;
  final int reps, seconds;
  final StrengthRank preview;
  final bool wouldBePr, saving;
  final double bodyweight;
  final String lang;
  final Color card, border, text, muted;
  final ValueChanged<double> onWeight;
  final ValueChanged<int> onReps;
  final ValueChanged<int> onSeconds;
  final VoidCallback? onLog;

  const _EntryCard({
    required this.exercise,
    required this.weight,
    required this.reps,
    required this.seconds,
    required this.preview,
    required this.wouldBePr,
    required this.bodyweight,
    required this.saving,
    required this.lang,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.onWeight,
    required this.onReps,
    required this.onSeconds,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final needsWeight = exercise.kind == LiftKind.loaded ||
        exercise.kind == LiftKind.weightedBodyweight;
    final isTimed = exercise.kind == LiftKind.timed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.logASet,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: text)),
        const SizedBox(height: 14),

        if (needsWeight) ...[
          _Stepper(
            label: exercise.kind == LiftKind.weightedBodyweight
                ? l.addedWeight
                : l.weightLabel,
            value: weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1),
            unit: 'kg',
            color: AppColors.brandGreen,
            border: border,
            text: text,
            muted: muted,
            onMinus: () => onWeight((weight - 2.5).clamp(0, 500)),
            onPlus: () => onWeight((weight + 2.5).clamp(0, 500)),
            onLongMinus: () => onWeight((weight - 10).clamp(0, 500)),
            onLongPlus: () => onWeight((weight + 10).clamp(0, 500)),
          ),
          const SizedBox(height: 10),
        ],

        if (isTimed)
          _Stepper(
            label: l.holdLabel,
            value: '$seconds',
            unit: 's',
            color: AppColors.sleepPurple,
            border: border,
            text: text,
            muted: muted,
            onMinus: () => onSeconds((seconds - 5).clamp(5, 900)),
            onPlus: () => onSeconds((seconds + 5).clamp(5, 900)),
            onLongMinus: () => onSeconds((seconds - 30).clamp(5, 900)),
            onLongPlus: () => onSeconds((seconds + 30).clamp(5, 900)),
          )
        else
          _Stepper(
            label: l.repsLabel,
            value: '$reps',
            unit: '',
            color: AppColors.waterBlue,
            border: border,
            text: text,
            muted: muted,
            onMinus: () => onReps((reps - 1).clamp(1, 200)),
            onPlus: () => onReps((reps + 1).clamp(1, 200)),
            onLongMinus: () => onReps((reps - 5).clamp(1, 200)),
            onLongPlus: () => onReps((reps + 5).clamp(1, 200)),
          ),

        // ── What this set is worth, before committing to it ──
        const SizedBox(height: 14),
        AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: preview.color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: preview.color.withOpacity(0.35)),
          ),
          child: Row(children: [
            RankBadge(rank: preview, size: 46, arabic: l.isAr),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.thisSetWouldRank,
                        style: TextStyle(
                            fontFamily: 'Cairo', fontSize: 10, color: muted)),
                    Text(preview.label(arabic: l.isAr),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: preview.color)),
                    if (needsWeight && bodyweight > 0)
                      Text(
                        '1RM ≈ ${estimateOneRepMax(exercise.kind == LiftKind.weightedBodyweight ? bodyweight + weight : weight, reps).round()} kg'
                        '  ·  ${(estimateOneRepMax(exercise.kind == LiftKind.weightedBodyweight ? bodyweight + weight : weight, reps) / bodyweight).toStringAsFixed(2)}× ${l.bodyweightShort}',
                        style: TextStyle(
                            fontFamily: 'Cairo', fontSize: 9.5, color: muted),
                      ),
                  ]),
            ),
            if (wouldBePr)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: PopIn(
                  child: Text('🏆', style: TextStyle(fontSize: 22)),
                ),
              ),
          ]),
        ),

        // ── Plate maths for barbell work ──
        if (exercise.kind == LiftKind.loaded && weight > 20) ...[
          const SizedBox(height: 10),
          _PlateRow(target: weight, lang: lang, muted: muted, border: border),
        ],

        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: saving ? null : onLog,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(onLog == null ? l.needBodyweightShort : l.logSetCta,
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  onLog == null ? muted : AppColors.brandGreen,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Minus / value / plus row. Long-press the buttons for a bigger jump.
class _Stepper extends StatelessWidget {
  final String label, value, unit;
  final Color color, border, text, muted;
  final VoidCallback onMinus, onPlus, onLongMinus, onLongPlus;

  const _Stepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.border,
    required this.text,
    required this.muted,
    required this.onMinus,
    required this.onPlus,
    required this.onLongMinus,
    required this.onLongPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 74,
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: muted)),
      ),
      _btn(Icons.remove_rounded, onMinus, onLongMinus),
      Expanded(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: text)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(unit,
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 12, color: muted)),
              ],
            ],
          ),
        ),
      ),
      _btn(Icons.add_rounded, onPlus, onLongPlus),
    ]);
  }

  Widget _btn(IconData icon, VoidCallback onTap, VoidCallback onLong) =>
      PressFx(
        onTap: onTap,
        onLongPress: onLong,
        scale: 0.88,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      );
}

/// Plates per side for a 20 kg bar.
class _PlateRow extends StatelessWidget {
  final double target;
  final String lang;
  final Color muted, border;
  const _PlateRow({
    required this.target,
    required this.lang,
    required this.muted,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final plates = plateBreakdown(target);
    if (plates.isEmpty) {
      return Text(l.platesNotExact,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 9.5, color: muted));
    }
    return Row(children: [
      Text('${l.perSide}  ',
          style: TextStyle(fontFamily: 'Cairo', fontSize: 9.5, color: muted)),
      Expanded(
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: plates
              .map((p) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                        p % 1 == 0
                            ? '${p.toInt()}'
                            : p.toStringAsFixed(2).replaceAll('0', ''),
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: muted)),
                  ))
              .toList(),
        ),
      ),
    ]);
  }
}

/// What each tier asks of you, with the reachable ones marked.
class _StandardsCard extends StatelessWidget {
  final LiftExercise exercise;
  final bool isMale;
  final double bodyweight;
  final StrengthRank current;
  final String lang;
  final Color card, border, text, muted;

  const _StandardsCard({
    required this.exercise,
    required this.isMale,
    required this.bodyweight,
    required this.current,
    required this.lang,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final standards = exercise.standardsFor(isMale: isMale);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.standardsTitle,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: text)),
        const SizedBox(height: 4),
        Text(l.standardsHint,
            style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: muted)),
        const SizedBox(height: 12),
        ...List.generate(kStrengthTiers.length, (i) {
          final tier = kStrengthTiers[i];
          final reached = current.tier.index >= i;
          final value = standards[i];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: reached ? tier.color : border,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(l.isAr ? tier.nameAr : tier.nameEn,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        fontWeight:
                            reached ? FontWeight.w800 : FontWeight.w500,
                        color: reached ? tier.color : muted)),
              ),
              Text(_requirement(value, l),
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: reached ? text : muted)),
              if (reached) ...[
                const SizedBox(width: 6),
                Icon(Icons.check_rounded, size: 13, color: tier.color),
              ],
            ]),
          );
        }),
      ]),
    );
  }

  String _requirement(double value, L l) {
    switch (exercise.kind) {
      case LiftKind.timed:
        return '${value.round()}s';
      case LiftKind.bodyweight:
        return '${value.round()} ${l.repsLabel}';
      case LiftKind.loaded:
        if (bodyweight <= 0) return '${value.toStringAsFixed(2)}×';
        return '${(value * bodyweight).round()} kg';
      case LiftKind.weightedBodyweight:
        if (bodyweight <= 0) return '${value.toStringAsFixed(2)}×';
        final added = (value - 1) * bodyweight;
        return added <= 0.5
            ? l.bodyweightOnly
            : '+${added.round()} kg';
    }
  }
}

class _HistoryCard extends StatelessWidget {
  final LiftExercise exercise;
  final List<LiftSet> sets;
  final String lang;
  final Color card, border, text, muted;
  final ValueChanged<int> onDelete;

  const _HistoryCard({
    required this.exercise,
    required this.sets,
    required this.lang,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    if (sets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Center(
          child: Text(l.noSetsYet,
              style:
                  TextStyle(fontFamily: 'Cairo', fontSize: 12, color: muted)),
        ),
      );
    }

    final bestLp = sets.map((s) => s.lp).reduce(math.max);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l.historyTitle,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: text)),
          const Spacer(),
          Text('${sets.length}',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: muted)),
        ]),
        const SizedBox(height: 10),
        ...sets.take(15).map((s) {
          final rank = s.rank;
          final isBest = s.lp == bestLp;
          return Dismissible(
            key: ValueKey(s.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.haramRed, size: 20),
            ),
            onDismissed: (_) => onDelete(s.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                if (isBest)
                  const Text('🏆', style: TextStyle(fontSize: 12))
                else
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: rank.color.withOpacity(0.5)),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_line(s, l),
                      style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight:
                              isBest ? FontWeight.w800 : FontWeight.w500,
                          color: text)),
                ),
                Text(_when(s.time, l),
                    style: TextStyle(
                        fontFamily: 'Cairo', fontSize: 9.5, color: muted)),
                const SizedBox(width: 8),
                RankChip(rank: rank, arabic: l.isAr, showLp: false),
              ]),
            ),
          );
        }),
      ]),
    );
  }

  String _line(LiftSet s, L l) {
    switch (exercise.kind) {
      case LiftKind.timed:
        return '${s.seconds}s';
      case LiftKind.bodyweight:
        return '${s.reps} ${l.repsLabel}';
      case LiftKind.loaded:
      case LiftKind.weightedBodyweight:
        return '${s.weightKg.toStringAsFixed(s.weightKg % 1 == 0 ? 0 : 1)} kg'
            ' × ${s.reps}';
    }
  }

  String _when(DateTime t, L l) {
    final days = DateTime.now().difference(t).inDays;
    if (days == 0) return l.todayLabel;
    if (days == 1) return l.yesterdayLabel;
    return '${days}d';
  }
}

class _HistorySkeleton extends StatelessWidget {
  final Color card, border;
  const _HistorySkeleton({required this.card, required this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Shimmer(
              width: double.infinity,
              height: 14,
              base: border,
              highlight: card,
            ),
          ),
        ),
      ),
    );
  }
}
