// ════════════════════════════════════════════════════════════════════
//  ascent_screen.dart — the Ascent System
//
//  Presents the day as a set of quests inside a "system panel": level
//  ring, rank letter, XP bar, chain multiplier, weekly review and the
//  title shelf.
// ════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import '../../core/theme.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';

class AscentScreen extends ConsumerStatefulWidget {
  const AscentScreen({super.key});
  @override
  ConsumerState<AscentScreen> createState() => _AscentScreenState();
}

class _AscentScreenState extends ConsumerState<AscentScreen>
    with TickerProviderStateMixin {
  late final AnimationController _stagger;
  late final AnimationController _pulse;
  late final ConfettiController _confetti;
  bool _levelUpShown = false;

  Widget _anim(int i, Widget child) {
    final animation = CurvedAnimation(
      parent: _stagger,
      curve: Interval((i * 0.09).clamp(0.0, 0.7),
          ((i * 0.09) + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);
    _confetti =
        ConfettiController(duration: const Duration(milliseconds: 1400));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(ascentProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _stagger.dispose();
    _pulse.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _maybeCelebrate() {
    final level = ref.read(ascentProvider.notifier).pendingLevelUp;
    if (level == null || _levelUpShown || !mounted) return;
    _levelUpShown = true;
    ref.read(ascentProvider.notifier).consumeLevelUp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _confetti.play();
      showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (_) => _LevelUpDialog(
            level: level,
            rank: rankForLevel(level),
            lang: ref.read(languageProvider)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumProvider);
    final lang = ref.watch(languageProvider);
    final l = L.fromLang(lang);
    final isDark = ref.watch(themeProvider);
    final isRamadan = ref.watch(ramadanModeProvider);
    final dir = l.isRtl ? TextDirection.rtl : TextDirection.ltr;

    if (!isPremium) {
      return Directionality(
        textDirection: dir,
        child: _AscentLocked(lang: lang, isDark: isDark),
      );
    }

    final ascent = ref.watch(ascentProvider);
    final titles = ref.watch(titleProvider);
    final weekAsync = ref.watch(ascentWeekProvider);
    _maybeCelebrate();

    final palette = _Palette.of(isDark: isDark, isRamadan: isRamadan);
    final accent = isRamadan ? AppColors.ramadanGold : ascent.color;

    return Directionality(
      textDirection: dir,
      child: Scaffold(
        backgroundColor: palette.bg,
        body: Stack(children: [
          // Faint star-field so the panels read as floating overlays.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => CustomPaint(
                  painter: _StarFieldPainter(
                      phase: _pulse.value,
                      color: accent,
                      intensity: isDark ? 1.0 : 0.3),
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: accent,
              onRefresh: () => ref.read(ascentProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 32),
                children: [
                  _anim(0,
                      _Header(lang: lang, ascent: ascent, palette: palette)),
                  const SizedBox(height: 14),
                  _anim(
                      1,
                      _SystemPanel(
                        ascent: ascent, palette: palette,
                        accent: accent, lang: lang, pulse: _pulse,
                      )),
                  const SizedBox(height: 14),
                  _anim(
                      2,
                      _QuestBoard(
                        ascent: ascent, palette: palette, lang: lang,
                        onStillness: () {
                          HapticFeedback.mediumImpact();
                          ref.read(ascentProvider.notifier).toggleStillness();
                        },
                        onQuestTap: _routeForQuest,
                      )),
                  const SizedBox(height: 14),
                  _anim(
                      3,
                      weekAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (week) => _WeeklyReview(
                            week: week, lang: lang,
                            palette: palette, accent: accent),
                      )),
                  const SizedBox(height: 14),
                  _anim(
                      4,
                      _TitleShelf(
                          earned: titles.earned,
                          lang: lang,
                          palette: palette)),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 22,
              maxBlastForce: 18,
              minBlastForce: 6,
              gravity: 0.25,
              shouldLoop: false,
              colors: const [
                AscentColors.system,
                AppColors.accentGold,
                AppColors.halalGreen,
                AppColors.sleepPurple,
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _routeForQuest(QuestId id) {
    switch (id) {
      case QuestId.nourish:
      case QuestId.wholesome:
        context.go('/nutrition');
        break;
      case QuestId.hydrate:
      case QuestId.rest:
      case QuestId.move:
        context.go('/health');
        break;
      case QuestId.train:
        context.go('/fitness');
        break;
      case QuestId.restraint:
        context.go('/home');
        break;
      case QuestId.stillness:
        break; // has its own tap target
    }
  }
}

// ════════════════════════════════════════════════════════════════════
// PALETTE
// ════════════════════════════════════════════════════════════════════
class _Palette {
  final Color bg, panel, panelAlt, border, text, muted;
  const _Palette(this.bg, this.panel, this.panelAlt, this.border, this.text,
      this.muted);

  factory _Palette.of({required bool isDark, required bool isRamadan}) {
    if (isRamadan) {
      return isDark
          ? const _Palette(
              AppColors.ramadanNight, AppColors.ramadanCard,
              AppColors.ramadanCardAlt, AppColors.ramadanBorder,
              AppColors.ramadanText, AppColors.ramadanMuted)
          : const _Palette(
              AppColors.ramadanDay, AppColors.ramadanDayCard,
              Color(0xFFFFF8E8), Color(0xFFD4A043),
              AppColors.ramadanDayText, AppColors.ramadanDayMuted);
    }
    return isDark
        ? const _Palette(
            AppColors.darkBg, AppColors.darkCard, AppColors.darkCardAlt,
            AppColors.darkBorder, AppColors.darkText, AppColors.darkMuted)
        : const _Palette(
            AppColors.lightBg, Colors.white, AppColors.lightCard,
            AppColors.lightBorder, AppColors.lightText, AppColors.lightMuted);
  }
}

// ════════════════════════════════════════════════════════════════════
// HEADER
// ════════════════════════════════════════════════════════════════════
class _Header extends StatelessWidget {
  final String lang;
  final AscentState ascent;
  final _Palette palette;
  const _Header(
      {required this.lang, required this.ascent, required this.palette});

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: ascent.color.withOpacity(0.55), width: 1.2),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(ascent.rank.letter,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: ascent.color)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.ascentTitle,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: palette.text)),
          Text(l.isAr ? ascent.rank.nameAr : ascent.rank.nameEn,
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 11, color: palette.muted)),
        ]),
      ),
      if (ascent.chain > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.doubtOrange.withOpacity(0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.doubtOrange.withOpacity(0.4)),
          ),
          child: Text(
              '🔥 ${ascent.chain}  ×${chainMultiplier(ascent.chain).toStringAsFixed(2)}',
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.doubtOrange)),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// SYSTEM PANEL — level ring, XP bar, today's score
// ════════════════════════════════════════════════════════════════════
class _SystemPanel extends StatelessWidget {
  final AscentState ascent;
  final _Palette palette;
  final Color accent;
  final String lang;
  final Animation<double> pulse;
  const _SystemPanel({
    required this.ascent,
    required this.palette,
    required this.accent,
    required this.lang,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final capped = ascent.level >= kMaxLevel;
    return _Bracketed(
      accent: accent,
      panel: palette.panel,
      pulse: pulse,
      child: Column(children: [
        Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(l.systemLabel,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: accent)),
          const Spacer(),
          Text('${l.todayLabel}  +${ascent.todayXp} XP',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.muted)),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: 188,
          height: 188,
          child: Stack(alignment: Alignment.center, children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ascent.progress),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => CustomPaint(
                size: const Size(188, 188),
                painter: _LevelRingPainter(
                  progress: value,
                  scorePct: (ascent.score / 1000).clamp(0.0, 1.0),
                  accent: accent,
                  track: palette.border,
                ),
              ),
            ),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(l.levelShort,
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w700,
                      color: palette.muted)),
              Text('${ascent.level}',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 56,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: accent)),
              Text(
                  capped
                      ? l.maxLevel
                      : '${ascent.xpInLevel} / ${ascent.xpNeeded} XP',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.muted)),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Text(l.dailyScore,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.muted)),
          const Spacer(),
          Text('${ascent.score} / 1000',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: palette.text)),
        ]),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
                begin: 0, end: (ascent.score / 1000).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => LinearProgressIndicator(
              value: value,
              minHeight: 9,
              backgroundColor: palette.border.withOpacity(0.6),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Text(l.isAr ? ascent.gradeAr() : ascent.gradeEn(),
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accent)),
          const Spacer(),
          Text('${ascent.questsDone} / ${kQuests.length}  ${l.questsLabel}',
              style: TextStyle(
                  fontFamily: 'Cairo', fontSize: 11, color: palette.muted)),
        ]),
      ]),
    );
  }
}

/// Panel chrome: rounded surface, tinted border, glowing corner brackets.
class _Bracketed extends StatelessWidget {
  final Widget child;
  final Color accent, panel;
  final Animation<double>? pulse;
  final EdgeInsets padding;
  const _Bracketed({
    required this.child,
    required this.accent,
    required this.panel,
    this.pulse,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withOpacity(0.28), width: 1.1),
      ),
      child: child,
    );
    if (pulse == null) {
      return CustomPaint(
          painter: _BracketPainter(accent: accent, glow: 0.5), child: body);
    }
    return AnimatedBuilder(
      animation: pulse!,
      builder: (_, inner) => CustomPaint(
        painter: _BracketPainter(accent: accent, glow: 0.35 + 0.5 * pulse!.value),
        child: inner,
      ),
      child: body,
    );
  }
}

class _BracketPainter extends CustomPainter {
  final Color accent;
  final double glow;
  const _BracketPainter({required this.accent, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 20.0;
    const inset = 2.0;
    final paint = Paint()
      ..color = accent.withOpacity(glow.clamp(0.0, 1.0))
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Top-left
    canvas.drawLine(const Offset(inset, inset + arm),
        const Offset(inset, inset), paint);
    canvas.drawLine(const Offset(inset, inset),
        const Offset(inset + arm, inset), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - inset - arm, inset),
        Offset(size.width - inset, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(size.width - inset, inset + arm), paint);
    // Bottom-left
    canvas.drawLine(Offset(inset, size.height - inset - arm),
        Offset(inset, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset),
        Offset(inset + arm, size.height - inset), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - inset - arm, size.height - inset),
        Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset),
        Offset(size.width - inset, size.height - inset - arm), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) =>
      old.glow != glow || old.accent != accent;
}

/// Two concentric arcs: outer = level progress, inner = today's score.
class _LevelRingPainter extends CustomPainter {
  final double progress, scorePct;
  final Color accent, track;
  const _LevelRingPainter({
    required this.progress,
    required this.scorePct,
    required this.accent,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const gap = 0.22;
    final sweep = 2 * pi - gap * 2;
    final start = -pi / 2 + gap;

    void arc(double radius, double value, Color color, double width) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
          rect,
          start,
          sweep,
          false,
          Paint()
            ..color = track.withOpacity(0.55)
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);
      if (value <= 0) return;
      canvas.drawArc(
          rect,
          start,
          sweep * value.clamp(0.0, 1.0),
          false,
          Paint()
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6));
    }

    arc(size.width / 2 - 10, progress, accent, 12);
    arc(size.width / 2 - 28, scorePct, accent.withOpacity(0.45), 5);

    // Tick marks around the outer ring for the "system readout" feel.
    final tick = Paint()
      ..color = accent.withOpacity(0.35)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 36; i++) {
      final a = start + sweep * (i / 35);
      final r1 = size.width / 2 - 2;
      final r2 = r1 - (i % 5 == 0 ? 6 : 3);
      canvas.drawLine(
        center + Offset(cos(a) * r1, sin(a) * r1),
        center + Offset(cos(a) * r2, sin(a) * r2),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) =>
      old.progress != progress ||
      old.scorePct != scorePct ||
      old.accent != accent;
}

// ════════════════════════════════════════════════════════════════════
// QUEST BOARD
// ════════════════════════════════════════════════════════════════════
class _QuestBoard extends StatelessWidget {
  final AscentState ascent;
  final _Palette palette;
  final String lang;
  final VoidCallback onStillness;
  final void Function(QuestId) onQuestTap;
  const _QuestBoard({
    required this.ascent,
    required this.palette,
    required this.lang,
    required this.onStillness,
    required this.onQuestTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.9),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l.dailyQuests,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: palette.text)),
          const Spacer(),
          Text('${ascent.questsDone}/${kQuests.length}',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: palette.muted)),
        ]),
        const SizedBox(height: 4),
        Text(l.dailyQuestsHint,
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 10.5, color: palette.muted)),
        const SizedBox(height: 12),
        ...kQuests.map((quest) => _QuestRow(
              meta: quest,
              points: ascent.points(quest.id),
              done: ascent.isDone(quest.id),
              palette: palette,
              lang: lang,
              onTap: quest.id == QuestId.stillness
                  ? onStillness
                  : () => onQuestTap(quest.id),
              interactive: quest.id == QuestId.stillness,
            )),
      ]),
    );
  }
}

class _QuestRow extends StatelessWidget {
  final QuestMeta meta;
  final int points;
  final bool done, interactive;
  final _Palette palette;
  final String lang;
  final VoidCallback onTap;
  const _QuestRow({
    required this.meta,
    required this.points,
    required this.done,
    required this.interactive,
    required this.palette,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final pct = (points / kQuestMax).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: meta.color.withOpacity(done ? 0.20 : 0.08),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: done ? meta.color.withOpacity(0.6) : Colors.transparent),
            ),
            child: Center(
                child: Text(meta.glyph, style: const TextStyle(fontSize: 19))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(l.isAr ? meta.nameAr : meta.nameEn,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: done ? meta.color : palette.text)),
                if (interactive && !done) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.touch_app_rounded,
                      size: 13, color: palette.muted),
                ],
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: palette.border.withOpacity(0.55),
                    valueColor: AlwaysStoppedAnimation(meta.color),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(l.isAr ? meta.hintAr : meta.hintEn,
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 9.5, color: palette.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            child: done
                ? Icon(Icons.check_circle_rounded,
                    key: const ValueKey(true), color: meta.color, size: 22)
                : Text('$points',
                    key: const ValueKey(false),
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: palette.muted)),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// WEEKLY REVIEW
// ════════════════════════════════════════════════════════════════════
class _WeeklyReview extends StatelessWidget {
  final List<Map<String, dynamic>> week;
  final String lang;
  final _Palette palette;
  final Color accent;
  const _WeeklyReview({
    required this.week,
    required this.lang,
    required this.palette,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    // Index the rows by date so gaps render as empty columns.
    final byDate = <String, int>{};
    var xpTotal = 0;
    for (final row in week) {
      final key = row['date_key'] as String? ?? '';
      byDate[key] = (row['score'] as int?) ?? 0;
      xpTotal += (row['xp'] as int?) ?? 0;
    }
    final days = <DateTime>[
      for (var i = 6; i >= 0; i--)
        DateTime.now().subtract(Duration(days: i)),
    ];
    final scores = days.map((d) => byDate[_key(d)] ?? 0).toList();
    final logged = scores.where((s) => s > 0).toList();
    final avg = logged.isEmpty
        ? 0
        : logged.reduce((a, b) => a + b) ~/ logged.length;
    final best = scores.isEmpty ? 0 : scores.reduce(max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.9),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l.weeklyReview,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: palette.text)),
          const Spacer(),
          Text('+$xpTotal XP',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accent)),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final score = scores[i];
            final pct = (score / 1000).clamp(0.0, 1.0);
            final isToday = i == 6;
            return Column(children: [
              Text(score > 0 ? '$score' : '·',
                  style: TextStyle(
                      fontFamily: 'Cairo', fontSize: 8, color: palette.muted)),
              const SizedBox(height: 3),
              Container(
                width: 26,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.panelAlt,
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: pct),
                  duration: Duration(milliseconds: 500 + i * 60),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => Container(
                    height: 64 * value,
                    decoration: BoxDecoration(
                      color: score > 0
                          ? (isToday ? accent : accent.withOpacity(0.6))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(l.weekDaysShort[days[i].weekday % 7],
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 9,
                      fontWeight: isToday ? FontWeight.w900 : FontWeight.w400,
                      color: isToday ? accent : palette.muted)),
            ]);
          }),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _stat(l.averageLabel, '$avg', palette),
          const SizedBox(width: 18),
          _stat(l.bestLabel, '$best', palette),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value, _Palette palette) => Row(children: [
        Text('$label ',
            style: TextStyle(
                fontFamily: 'Cairo', fontSize: 10, color: palette.muted)),
        Text(value,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: palette.text)),
      ]);

  static String _key(DateTime d) => '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

// ════════════════════════════════════════════════════════════════════
// TITLE SHELF
// ════════════════════════════════════════════════════════════════════
class _TitleShelf extends StatelessWidget {
  final Set<int> earned;
  final String lang;
  final _Palette palette;
  const _TitleShelf(
      {required this.earned, required this.lang, required this.palette});

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final count = kTitles.where((t) => earned.contains(t.id)).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border, width: 0.9),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(l.titlesLabel,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: palette.text)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count/${kTitles.length}',
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGold)),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kTitles.map((title) {
            final done = earned.contains(title.id);
            return Tooltip(
              message: l.isAr ? title.descAr : title.descEn,
              child: AnimatedOpacity(
                opacity: done ? 1 : 0.3,
                duration: const Duration(milliseconds: 350),
                child: Container(
                  width: 70,
                  padding:
                      const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.accentGold.withOpacity(0.1)
                        : palette.panelAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: done
                            ? AppColors.accentGold.withOpacity(0.5)
                            : Colors.transparent),
                  ),
                  child: Column(children: [
                    Text(title.glyph, style: const TextStyle(fontSize: 21)),
                    const SizedBox(height: 4),
                    Text(l.isAr ? title.nameAr : title.nameEn,
                        style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color:
                                done ? AppColors.accentGold : palette.muted),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// LEVEL-UP DIALOG
// ════════════════════════════════════════════════════════════════════
class _LevelUpDialog extends StatelessWidget {
  final int level;
  final AscentRank rank;
  final String lang;
  const _LevelUpDialog(
      {required this.level, required this.rank, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: _Bracketed(
        accent: rank.color,
        panel: const Color(0xFF0C1119),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.levelUp,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                  color: rank.color)),
          const SizedBox(height: 10),
          Text('$level',
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 76,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: rank.color.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                '${l.rankLabel} ${rank.letter} · '
                '${l.isAr ? rank.nameAr : rank.nameEn}',
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: rank.color)),
          ),
          const SizedBox(height: 18),
          Text(l.levelUpNote,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11.5,
                  height: 1.6,
                  color: AppColors.darkMuted)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: rank.color,
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
// PREMIUM GATE
// ════════════════════════════════════════════════════════════════════
class _AscentLocked extends StatelessWidget {
  final String lang;
  final bool isDark;
  const _AscentLocked({required this.lang, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final text = isDark ? AppColors.darkText : AppColors.lightText;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Bracketed(
              accent: AscentColors.system,
              panel: isDark ? AppColors.darkCard : AppColors.lightCard,
              child: Column(children: [
                Text('◈',
                    style: TextStyle(
                        fontSize: 48, color: AscentColors.system)),
                const SizedBox(height: 14),
                Text(l.ascentLockedTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: text)),
                const SizedBox(height: 10),
                Text(l.ascentLockedBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        height: 1.7,
                        color: AppColors.lightMuted)),
              ]),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: kQuests
                  .map((q) => Chip(
                        label: Text(
                            '${q.glyph} ${l.isAr ? q.nameAr : q.nameEn}',
                            style: const TextStyle(
                                fontFamily: 'Cairo', fontSize: 11)),
                        backgroundColor: q.color.withOpacity(0.10),
                        side: BorderSide(color: q.color.withOpacity(0.3)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/paywall'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AscentColors.system,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(l.upgradeCta,
                    style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// STAR FIELD
// ════════════════════════════════════════════════════════════════════
class _StarFieldPainter extends CustomPainter {
  final double phase, intensity;
  final Color color;
  const _StarFieldPainter(
      {required this.phase, required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    // Fixed seed keeps the field stable between frames.
    final rand = Random(20260729);
    for (var i = 0; i < 46; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final base = 0.10 + rand.nextDouble() * 0.22;
      final twinkle = 0.6 + 0.4 * sin(phase * 2 * pi + i);
      canvas.drawCircle(
        Offset(dx, dy),
        0.7 + rand.nextDouble() * 1.3,
        Paint()..color = color.withOpacity(base * twinkle * intensity),
      );
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter old) =>
      old.phase != phase || old.color != color;
}
