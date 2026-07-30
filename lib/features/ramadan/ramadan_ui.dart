// ════════════════════════════════════════════════════════════════════
//  ramadan_ui.dart — Ramadan mode, rebuilt
//
//  The previous version hardcoded iftar at 18:05, suhoor at 05:12 and a
//  fixed 2025 start date, so the countdown and day counter drifted out
//  of usefulness. This build derives everything live:
//
//   • iftar  = today's Maghrib, suhoor = tomorrow's Fajr (prayer API)
//   • day of Ramadan from the tabular Hijri calendar
//   • the moon is drawn at the month's actual phase
//   • one dial shows how far through the current window you are
//
//  Copy is kept short and practical: what time, how long, what to do.
// ════════════════════════════════════════════════════════════════════

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n.dart';
import '../../core/hijri.dart';
import '../../core/providers.dart';
import '../../core/prayer_provider.dart';

// ════════════════════════════════════════════════════════════════════
// SCHEDULE
// ════════════════════════════════════════════════════════════════════

enum RamadanPhase { fasting, iftarSoon, evening, suhoorSoon }

class RamadanSchedule {
  /// Start of the fast (dawn) and its end (sunset) for the current cycle.
  final DateTime suhoorEnd, iftar;

  /// False when prayer times could not be fetched and defaults are in use.
  final bool fromPrayerTimes;

  const RamadanSchedule({
    required this.suhoorEnd,
    required this.iftar,
    required this.fromPrayerTimes,
  });

  /// Reasonable stand-ins used only until the prayer API answers.
  factory RamadanSchedule.fallback(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return RamadanSchedule(
      suhoorEnd: today.add(const Duration(hours: 4, minutes: 45)),
      iftar: today.add(const Duration(hours: 18, minutes: 30)),
      fromPrayerTimes: false,
    );
  }

  bool isFastingAt(DateTime now) =>
      !now.isBefore(suhoorEnd) && now.isBefore(iftar);

  Duration untilIftar(DateTime now) => iftar.difference(now);

  /// Next dawn — today's if it has not passed, otherwise tomorrow's.
  DateTime nextSuhoorEnd(DateTime now) => now.isBefore(suhoorEnd)
      ? suhoorEnd
      : suhoorEnd.add(const Duration(days: 1));

  Duration untilSuhoorEnd(DateTime now) =>
      nextSuhoorEnd(now).difference(now);

  RamadanPhase phaseAt(DateTime now) {
    if (isFastingAt(now)) {
      final left = untilIftar(now);
      return left.inMinutes <= 20 ? RamadanPhase.iftarSoon : RamadanPhase.fasting;
    }
    final toDawn = untilSuhoorEnd(now);
    if (toDawn.inMinutes <= 60) return RamadanPhase.suhoorSoon;
    return RamadanPhase.evening;
  }

  /// 0-1 progress through whichever window is currently open.
  double progressAt(DateTime now) {
    if (isFastingAt(now)) {
      final total = iftar.difference(suhoorEnd).inSeconds;
      if (total <= 0) return 0;
      return (now.difference(suhoorEnd).inSeconds / total).clamp(0.0, 1.0);
    }
    final start = now.isBefore(suhoorEnd)
        ? iftar.subtract(const Duration(days: 1))
        : iftar;
    final end = nextSuhoorEnd(now);
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (now.difference(start).inSeconds / total).clamp(0.0, 1.0);
  }
}

/// Live schedule: real prayer times when they load, defaults until then.
final ramadanScheduleProvider = Provider<RamadanSchedule>((ref) {
  final now = DateTime.now();
  final times = ref.watch(prayerTimesProvider);
  return times.maybeWhen(
    data: (t) {
      if (t == null) return RamadanSchedule.fallback(now);
      return RamadanSchedule(
        suhoorEnd: t.fajr,
        iftar: t.maghrib,
        fromPrayerTimes: true,
      );
    },
    orElse: () => RamadanSchedule.fallback(now),
  );
});

// ════════════════════════════════════════════════════════════════════
// HERO CARD
// ════════════════════════════════════════════════════════════════════

class RamadanHero extends ConsumerWidget {
  final DateTime now;
  final Animation<double> shimmer;
  final VoidCallback? onLogWater;
  final VoidCallback? onOpenNutrition;
  const RamadanHero({
    super.key,
    required this.now,
    required this.shimmer,
    this.onLogWater,
    this.onOpenNutrition,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final l = L.fromLang(lang);
    final schedule = ref.watch(ramadanScheduleProvider);
    final hijri = HijriDate.fromGregorian(now);
    final phase = schedule.phaseAt(now);
    final theme = _RamadanTheme.forPhase(phase);

    final isFasting =
        phase == RamadanPhase.fasting || phase == RamadanPhase.iftarSoon;
    final remaining =
        isFasting ? schedule.untilIftar(now) : schedule.untilSuhoorEnd(now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.backdrop,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.accent.withOpacity(0.45), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: theme.accent.withOpacity(0.20),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(children: [
          // Sky: drifting stars behind everything.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: shimmer,
                builder: (_, __) => CustomPaint(
                  painter: _NightSkyPainter(
                      phase: shimmer.value, accent: theme.accent),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(children: [
              // ── Row: moon · title · day chip ──
              Row(children: [
                _MoonBadge(hijri: hijri, accent: theme.accent, shimmer: shimmer),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.ramadanKareem,
                            style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: theme.accent)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.dot,
                              boxShadow: [
                                BoxShadow(
                                    color: theme.dot.withOpacity(0.8),
                                    blurRadius: 8)
                              ],
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(theme.statusText(l),
                                style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.72)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ]),
                ),
                _DayChip(hijri: hijri, accent: theme.accent, lang: lang),
              ]),
              const SizedBox(height: 18),

              // ── Countdown dial ──
              _CountdownDial(
                progress: schedule.progressAt(now),
                remaining: remaining,
                accent: theme.accent,
                label: isFasting ? l.iftarIn : l.suhoorIn,
                target: isFasting
                    ? _clock(schedule.iftar, lang)
                    : _clock(schedule.nextSuhoorEnd(now), lang),
                lang: lang,
              ),
              const SizedBox(height: 16),

              // ── Window rows ──
              Row(children: [
                Expanded(
                  child: _WindowTile(
                    glyph: '🌇',
                    label: l.iftar,
                    time: _clock(schedule.iftar, lang),
                    accent: theme.accent,
                    highlight: isFasting,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WindowTile(
                    glyph: '🌄',
                    label: l.suhoor,
                    time: _clock(schedule.nextSuhoorEnd(now), lang),
                    accent: const Color(0xFF8C9EFF),
                    highlight: !isFasting,
                  ),
                ),
              ]),

              if (!schedule.fromPrayerTimes) ...[
                const SizedBox(height: 10),
                Text(l.ramadanTimesEstimated,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 9.5,
                        color: Colors.white.withOpacity(0.45))),
              ],

              const SizedBox(height: 14),

              // ── Practical actions for the current phase ──
              Row(children: [
                Expanded(
                  child: _ActionChip(
                    glyph: isFasting ? '📋' : '💧',
                    label: isFasting ? l.planIftar : l.logWater,
                    accent: theme.accent,
                    onTap: isFasting ? onOpenNutrition : onLogWater,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionChip(
                    glyph: '🍽️',
                    label: l.openNutrition,
                    accent: theme.accent,
                    onTap: onOpenNutrition,
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // ── One short, practical line ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: theme.accent.withOpacity(0.18)),
                ),
                child: Text(theme.tip(l),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 10.5,
                        height: 1.55,
                        color: Colors.white.withOpacity(0.65))),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  static String _clock(DateTime dt, String lang) {
    final hour24 = dt.hour;
    final hour = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    if (lang == 'ar') return '$hour:$minute ${hour24 >= 12 ? 'م' : 'ص'}';
    return '$hour:$minute ${hour24 >= 12 ? 'PM' : 'AM'}';
  }
}

// ── Phase styling and copy ──────────────────────────────────────────
class _RamadanTheme {
  final List<Color> backdrop;
  final Color accent, dot;
  final RamadanPhase phase;
  const _RamadanTheme(this.backdrop, this.accent, this.dot, this.phase);

  factory _RamadanTheme.forPhase(RamadanPhase phase) {
    switch (phase) {
      case RamadanPhase.iftarSoon:
        return const _RamadanTheme(
            [Color(0xFF23100A), Color(0xFF3A160B), Color(0xFF160805)],
            Color(0xFFFF8A47), Color(0xFFFF7043), RamadanPhase.iftarSoon);
      case RamadanPhase.fasting:
        return const _RamadanTheme(
            [Color(0xFF060A20), Color(0xFF0E1440), Color(0xFF05081A)],
            Color(0xFF8FA8FF), Color(0xFF69F0AE), RamadanPhase.fasting);
      case RamadanPhase.suhoorSoon:
        return const _RamadanTheme(
            [Color(0xFF0B0A22), Color(0xFF1B1740), Color(0xFF090818)],
            Color(0xFFB39DFF), Color(0xFFB39DFF), RamadanPhase.suhoorSoon);
      case RamadanPhase.evening:
        return const _RamadanTheme(
            [Color(0xFF120A02), Color(0xFF241505), Color(0xFF0C0602)],
            Color(0xFFF0C040), Color(0xFFFFB300), RamadanPhase.evening);
    }
  }

  String statusText(L l) {
    switch (phase) {
      case RamadanPhase.iftarSoon:
        return l.ramadanIftarSoon;
      case RamadanPhase.fasting:
        return l.ramadanFasting;
      case RamadanPhase.suhoorSoon:
        return l.ramadanSuhoorSoon;
      case RamadanPhase.evening:
        return l.ramadanEvening;
    }
  }

  String tip(L l) {
    switch (phase) {
      case RamadanPhase.iftarSoon:
        return l.ramadanTipIftarSoon;
      case RamadanPhase.fasting:
        return l.ramadanTipFasting;
      case RamadanPhase.suhoorSoon:
        return l.ramadanTipSuhoor;
      case RamadanPhase.evening:
        return l.ramadanTipEvening;
    }
  }
}

// ── Moon drawn at the month's real phase ────────────────────────────
class _MoonBadge extends StatelessWidget {
  final HijriDate hijri;
  final Color accent;
  final Animation<double> shimmer;
  const _MoonBadge(
      {required this.hijri, required this.accent, required this.shimmer});

  @override
  Widget build(BuildContext context) {
    final lit = moonIllumination(hijri.day, daysInMonth: hijri.daysInMonth);
    return AnimatedBuilder(
      animation: shimmer,
      builder: (_, __) => Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.25 + 0.25 * shimmer.value),
              blurRadius: 22,
              spreadRadius: 2,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _MoonPainter(
              illumination: lit,
              waxing: hijri.day <= hijri.daysInMonth / 2,
              accent: accent),
        ),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  final double illumination;
  final bool waxing;
  final Color accent;
  const _MoonPainter(
      {required this.illumination, required this.waxing, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Dark disc.
    canvas.drawCircle(
        center, radius, Paint()..color = const Color(0xFF14172B));

    // Lit portion: the disc minus an offset circle, so the terminator
    // slides from a thin crescent to a full moon as illumination grows.
    final lit = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    if (illumination < 0.98) {
      final shift = radius * 2 * (1 - illumination);
      final shadowCenter = Offset(
          center.dx + (waxing ? -shift : shift), center.dy);
      final shadow = Path()
        ..addOval(Rect.fromCircle(center: shadowCenter, radius: radius));
      final visible =
          Path.combine(PathOperation.difference, lit, shadow);
      canvas.drawPath(visible, Paint()..color = accent);
    } else {
      canvas.drawPath(lit, Paint()..color = accent);
    }

    // Rim.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = accent.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_MoonPainter old) =>
      old.illumination != illumination ||
      old.waxing != waxing ||
      old.accent != accent;
}

// ── Day-of-Ramadan chip ─────────────────────────────────────────────
class _DayChip extends StatelessWidget {
  final HijriDate hijri;
  final Color accent;
  final String lang;
  const _DayChip(
      {required this.hijri, required this.accent, required this.lang});

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(lang);
    final inRamadan = hijri.isRamadan;
    final days = inRamadan ? 0 : HijriDate.daysUntilRamadan(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.5), width: 1.1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(inRamadan ? l.dayLabel : l.inDaysLabel,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 8,
                color: Colors.white.withOpacity(0.45))),
        const SizedBox(height: 2),
        Text(inRamadan ? '${hijri.day}' : '$days',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                height: 1.1,
                fontWeight: FontWeight.w900,
                color: accent)),
        Text(inRamadan ? '/ ${hijri.daysInMonth}' : l.daysShort,
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 7.5,
                color: Colors.white.withOpacity(0.45))),
      ]),
    );
  }
}

// ── Countdown dial ──────────────────────────────────────────────────
class _CountdownDial extends StatelessWidget {
  final double progress;
  final Duration remaining;
  final Color accent;
  final String label, target, lang;
  const _CountdownDial({
    required this.progress,
    required this.remaining,
    required this.accent,
    required this.label,
    required this.target,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    final text = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}'
        : '$minutes:${seconds.toString().padLeft(2, '0')}';
    final unit = hours > 0
        ? (lang == 'ar' ? 'س : د' : 'h : m')
        : (lang == 'ar' ? 'د : ث' : 'm : s');

    return SizedBox(
      width: 176,
      height: 176,
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, value, __) => CustomPaint(
            size: const Size(176, 176),
            painter: _DialPainter(progress: value, accent: accent),
          ),
        ),
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withOpacity(0.55))),
          const SizedBox(height: 2),
          Text(text,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: accent,
                  shadows: [
                    Shadow(color: accent.withOpacity(0.5), blurRadius: 14)
                  ])),
          Text(unit,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 8.5,
                  letterSpacing: 1.5,
                  color: Colors.white.withOpacity(0.35))),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(target,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: accent)),
          ),
        ]),
      ]),
    );
  }
}

class _DialPainter extends CustomPainter {
  final double progress;
  final Color accent;
  const _DialPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = -pi / 2;
    const sweep = 2 * pi;

    canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = Colors.white.withOpacity(0.08)
          ..strokeWidth = 10
          ..style = PaintingStyle.stroke);

    if (progress > 0) {
      canvas.drawArc(
          rect,
          start,
          sweep * progress,
          false,
          Paint()
            ..shader = SweepGradient(
              startAngle: 0,
              endAngle: sweep,
              colors: [accent.withOpacity(0.35), accent],
              transform: const GradientRotation(start),
            ).createShader(rect)
            ..strokeWidth = 10
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke);

      // Leading dot.
      final angle = start + sweep * progress;
      canvas.drawCircle(
          center + Offset(cos(angle) * radius, sin(angle) * radius),
          5.5,
          Paint()..color = accent);
    }

    // Hour ticks.
    final tick = Paint()
      ..color = Colors.white.withOpacity(0.16)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 24; i++) {
      final a = start + sweep * (i / 24);
      final outer = radius - 10;
      final inner = outer - (i % 6 == 0 ? 7 : 4);
      canvas.drawLine(
        center + Offset(cos(a) * outer, sin(a) * outer),
        center + Offset(cos(a) * inner, sin(a) * inner),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.progress != progress || old.accent != accent;
}

// ── Small pieces ────────────────────────────────────────────────────
class _WindowTile extends StatelessWidget {
  final String glyph, label, time;
  final Color accent;
  final bool highlight;
  const _WindowTile({
    required this.glyph,
    required this.label,
    required this.time,
    required this.accent,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: highlight
            ? accent.withOpacity(0.14)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlight
                ? accent.withOpacity(0.55)
                : Colors.white.withOpacity(0.09),
            width: highlight ? 1.4 : 1),
      ),
      child: Row(children: [
        Text(glyph, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 9),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 9.5,
                    color: Colors.white.withOpacity(0.5))),
            Text(time,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: highlight ? accent : Colors.white70)),
          ]),
        ),
      ]),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String glyph, label;
  final Color accent;
  final VoidCallback? onTap;
  const _ActionChip({
    required this.glyph,
    required this.label,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.30)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(glyph, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 7),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _NightSkyPainter extends CustomPainter {
  final double phase;
  final Color accent;
  const _NightSkyPainter({required this.phase, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(913);
    for (var i = 0; i < 34; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      final twinkle = 0.45 + 0.55 * sin(phase * 2 * pi + i * 0.7);
      canvas.drawCircle(
        Offset(dx, dy),
        0.6 + rand.nextDouble() * 1.2,
        Paint()
          ..color = accent.withOpacity(
              (0.12 + rand.nextDouble() * 0.22) * twinkle),
      );
    }
    // Soft glow in the top corner.
    canvas.drawCircle(
      Offset(size.width * 0.88, -20),
      120,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withOpacity(0.14), Colors.transparent],
        ).createShader(
            Rect.fromCircle(center: Offset(size.width * 0.88, -20), radius: 120)),
    );
  }

  @override
  bool shouldRepaint(_NightSkyPainter old) =>
      old.phase != phase || old.accent != accent;
}

// ════════════════════════════════════════════════════════════════════
// COMPACT STRIP — for screens that only need the countdown
// ════════════════════════════════════════════════════════════════════

class RamadanStrip extends ConsumerWidget {
  final DateTime now;
  const RamadanStrip({super.key, required this.now});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final l = L.fromLang(lang);
    final schedule = ref.watch(ramadanScheduleProvider);
    final phase = schedule.phaseAt(now);
    final theme = _RamadanTheme.forPhase(phase);
    final isFasting =
        phase == RamadanPhase.fasting || phase == RamadanPhase.iftarSoon;
    final remaining =
        isFasting ? schedule.untilIftar(now) : schedule.untilSuhoorEnd(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.accent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.accent.withOpacity(0.32)),
      ),
      child: Row(children: [
        Text(isFasting ? '🌙' : '🌇', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(isFasting ? l.iftarIn : l.suhoorIn,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.accent)),
        ),
        Text(
            hours > 0
                ? '$hours${l.isAr ? 'س' : 'h'} $minutes${l.isAr ? 'د' : 'm'}'
                : '$minutes${l.isAr ? 'د' : 'm'}',
            style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: theme.accent)),
      ]),
    );
  }
}
