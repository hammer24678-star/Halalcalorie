// leaf_progress_ring.dart
// PATCH_LEAF_RING_AND_WORKOUT_ASSETS
//
// Replaces the plain CircularProgressIndicator ring on the Nutrition
// "Today" tab with a detailed, animated leaf. The leaf fills from its
// stem upward as calories are logged, carries three small "droplet"
// markers along its midrib for protein / carbs / fat, and re-skins
// itself for light mode, dark mode, and Ramadan mode without needing
// three separate assets (everything is drawn, not imaged, so it stays
// crisp at any size and costs ~0 extra app size).
//
// Motion is intentionally restrained for a screen people check many
// times a day: a smooth fill sweep when the numbers change, a slow
// gloss sweep, and a very small breathing scale. Nothing spins or
// bounces on idle. All of it is easy to turn up in _LeafPainter /
// the AnimationController durations below if a punchier feel is
// wanted later.
//
// Usage (see nutrition_screen.dart hunk in the patch script):
//   LeafProgressRing(
//     size: 132,
//     progress: pct,                 // 0..1+ (over-goal allowed)
//     proteinPct: proteinRatio,      // 0..1+
//     carbsPct: carbsRatio,
//     fatPct: fatRatio,
//     progressColor: calCol,         // reuses existing over/under logic
//     isDark: isDark,
//     isRamadan: isRamadan,
//     child: <the existing center Column of text>,
//   )

import 'dart:math' as math;
import 'package:flutter/material.dart';

class LeafProgressRing extends StatefulWidget {
  final double size;
  final double progress;   // eaten / goal, NOT clamped by caller — clamp happens for drawing only
  final double proteinPct; // consumed / goal per macro
  final double carbsPct;
  final double fatPct;
  final Color progressColor;
  final bool isDark;
  final bool isRamadan;
  final Widget child;

  const LeafProgressRing({
    super.key,
    required this.progress,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.progressColor,
    required this.isDark,
    required this.isRamadan,
    required this.child,
    this.size = 132,
  });

  @override
  State<LeafProgressRing> createState() => _LeafProgressRingState();
}

class _LeafProgressRingState extends State<LeafProgressRing>
    with TickerProviderStateMixin {
  late final AnimationController _fillCtrl;
  late final Animation<double> _fill;
  late final AnimationController _pulseCtrl; // idle shimmer + breathing, loops forever
  late final AnimationController _introCtrl; // one-shot scale-in on first mount

  double _lastProgress = 0;

  @override
  void initState() {
    super.initState();
    _lastProgress = widget.progress;

    _fillCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fill = CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _fillCtrl.value = 1;
    _introCtrl.forward();
  }

  @override
  void didUpdateWidget(covariant LeafProgressRing old) {
    super.didUpdateWidget(old);
    if ((old.progress - widget.progress).abs() > 0.0001 ||
        (old.proteinPct - widget.proteinPct).abs() > 0.0001 ||
        (old.carbsPct - widget.carbsPct).abs() > 0.0001 ||
        (old.fatPct - widget.fatPct).abs() > 0.0001) {
      _lastProgress = old.progress;
      _fillCtrl
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    _pulseCtrl.dispose();
    _introCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fill, _pulseCtrl, _introCtrl]),
      builder: (context, _) {
        final animatedProgress = _lastProgress +
            (widget.progress - _lastProgress) * _fill.value;
        final introScale = Curves.elasticOut.transform(_introCtrl.value);

        return Transform.scale(
          scale: 0.85 + 0.15 * introScale,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _LeafPainter(
                progress: animatedProgress.clamp(0.0, 1.4),
                proteinPct: widget.proteinPct.clamp(0.0, 1.4),
                carbsPct: widget.carbsPct.clamp(0.0, 1.4),
                fatPct: widget.fatPct.clamp(0.0, 1.4),
                color: widget.progressColor,
                isDark: widget.isDark,
                isRamadan: widget.isRamadan,
                t: _pulseCtrl.value, // 0..1 looping, drives shimmer + breathing
              ),
              child: Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

class _LeafPainter extends CustomPainter {
  final double progress;
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final Color color;
  final bool isDark;
  final bool isRamadan;
  final double t;

  _LeafPainter({
    required this.progress,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.color,
    required this.isDark,
    required this.isRamadan,
    required this.t,
  });

  // Builds the leaf silhouette: pointed tip at top, small stem notch at
  // the bottom, widest a little below center — a simple almond/olive-leaf
  // outline made of four cubic curves (mirrored left/right).
  Path _leafPath(Size s) {
    final w = s.width, h = s.height;
    final cx = w / 2;
    final top = Offset(cx, h * 0.03);
    final bottom = Offset(cx, h * 0.98);
    final leftWide = Offset(w * 0.04, h * 0.56);
    final rightWide = Offset(w * 0.96, h * 0.56);

    final path = Path()..moveTo(top.dx, top.dy);
    // Right half: tip -> widest point -> stem
    path.cubicTo(
      cx + w * 0.30, h * 0.10,
      rightWide.dx, h * 0.32,
      rightWide.dx, rightWide.dy,
    );
    path.cubicTo(
      rightWide.dx, h * 0.78,
      cx + w * 0.18, h * 0.94,
      bottom.dx, bottom.dy,
    );
    // Left half: stem -> widest point -> tip
    path.cubicTo(
      cx - w * 0.18, h * 0.94,
      leftWide.dx, h * 0.78,
      leftWide.dx, leftWide.dy,
    );
    path.cubicTo(
      leftWide.dx, h * 0.32,
      cx - w * 0.30, h * 0.10,
      top.dx, top.dy,
    );
    path.close();
    return path;
  }

  // Central vein + side veins, drawn as a stroke path clipped to the leaf.
  Path _veinPath(Size s) {
    final w = s.width, h = s.height;
    final cx = w / 2;
    final p = Path()
      ..moveTo(cx, h * 0.96)
      ..cubicTo(cx, h * 0.7, cx, h * 0.4, cx, h * 0.06);

    const sideCount = 4;
    for (var i = 1; i <= sideCount; i++) {
      final f = i / (sideCount + 1);
      final y = h * (0.88 - f * 0.68);
      final spread = w * (0.30 - f * 0.10);
      // right vein
      p.moveTo(cx, y);
      p.quadraticBezierTo(cx + spread * 0.6, y - h * 0.04, cx + spread, y - h * 0.11);
      // left vein
      p.moveTo(cx, y);
      p.quadraticBezierTo(cx - spread * 0.6, y - h * 0.04, cx - spread, y - h * 0.11);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final leaf = _leafPath(size);
    final bounds = leaf.getBounds();

    // ── Palette ──────────────────────────────────────────────
    final Color emptyTop;
    final Color emptyBottom;
    final Color outline;
    final Color glow;
    if (isRamadan) {
      emptyTop = isDark ? const Color(0xFF241605) : const Color(0xFFFBF1D9);
      emptyBottom = isDark ? const Color(0xFF1A0F00) : const Color(0xFFF3E0AE);
      outline = const Color(0xFFD4A017); // barakahGold
      glow = const Color(0xFFD4A017);
    } else {
      emptyTop = isDark ? const Color(0xFF122318) : const Color(0xFFEFF8F1);
      emptyBottom = isDark ? const Color(0xFF0D1A11) : const Color(0xFFE1F3E6);
      outline = isDark ? const Color(0xFF00A86B) : const Color(0xFF0A6B4A);
      glow = color; // green / orange / red depending on eaten-vs-goal
    }

    // ── Soft drop shadow / glow behind the whole leaf ───────────
    final shadowPaint = Paint()
      ..color = glow.withOpacity(isDark ? 0.35 : 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(leaf.shift(const Offset(0, 3)), shadowPaint);

    // ── Empty leaf base (unfilled background) ───────────────────
    final basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [emptyTop, emptyBottom],
      ).createShader(bounds);
    canvas.drawPath(leaf, basePaint);

    // ── Progress fill, clipped to the leaf, rising from the stem ───
    canvas.save();
    canvas.clipPath(leaf);
    final fillFrac = progress.clamp(0.0, 1.0);
    final fillHeight = bounds.height * fillFrac;
    final fillRect = Rect.fromLTRB(
      bounds.left - 4,
      bounds.bottom - fillHeight,
      bounds.right + 4,
      bounds.bottom + 4,
    );
    final over = progress > 1.0;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: over
            ? [color, color.withOpacity(0.75)]
            : isRamadan
                ? [const Color(0xFFD4A017), const Color(0xFFFFD873)]
                : [const Color(0xFF0A6B4A), const Color(0xFF3FCE8E)],
      ).createShader(fillRect);
    canvas.drawRect(fillRect, fillPaint);

    // Waterline highlight at the top edge of the fill
    if (fillFrac > 0.01 && fillFrac < 1.0) {
      final lineY = bounds.bottom - fillHeight;
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(bounds.left - 4, lineY),
        Offset(bounds.right + 4, lineY),
        linePaint,
      );
    }

    // Diagonal gloss sweep (very slow, subtle — the "premium" touch)
    final sweep = (t * 2) % 2.0; // 0..2 loop
    final sweepDx = bounds.width * (sweep - 0.5);
    final glossPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(isDark ? 0.10 : 0.16),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.35, 0.5, 0.65],
      ).createShader(bounds.shift(Offset(sweepDx, 0)));
    canvas.drawRect(bounds.inflate(6), glossPaint);

    // Ramadan: a faint crescent + sparkles inside the leaf silhouette
    if (isRamadan) {
      final crescentCenter = Offset(bounds.center.dx + bounds.width * 0.14,
          bounds.top + bounds.height * 0.22);
      final r = bounds.width * 0.11;
      final crescentPaint = Paint()
        ..color = Colors.white.withOpacity(isDark ? 0.16 : 0.35);
      canvas.drawCircle(crescentCenter, r, crescentPaint);
      final cutPaint = Paint()
        ..color = (isDark ? emptyTop : emptyTop).withOpacity(1);
      canvas.drawCircle(
          crescentCenter.translate(r * 0.55, -r * 0.15), r * 0.85, cutPaint);

      final twinkle = (math.sin(t * 2 * math.pi) + 1) / 2;
      final starPaint = Paint()
        ..color = Colors.white.withOpacity(0.25 + 0.35 * twinkle);
      canvas.drawCircle(
          Offset(bounds.left + bounds.width * 0.22, bounds.top + bounds.height * 0.42),
          1.6,
          starPaint);
      canvas.drawCircle(
          Offset(bounds.left + bounds.width * 0.30, bounds.top + bounds.height * 0.58),
          1.1,
          starPaint);
    }

    canvas.restore(); // end clip to leaf

    // ── Veins (drawn above the fill, clipped to leaf again) ─────
    canvas.save();
    canvas.clipPath(leaf);
    final veinPaint = Paint()
      ..color = outline.withOpacity(isDark ? 0.55 : 0.4)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(_veinPath(size), veinPaint);
    canvas.restore();

    // ── Leaf outline ─────────────────────────────────────────────
    final outlinePaint = Paint()
      ..color = outline
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(leaf, outlinePaint);

    // ── Macro droplets along the midrib: protein / carbs / fat ───
    final cx = bounds.center.dx;
    final breathe = 1.0 + 0.06 * math.sin(t * 2 * math.pi);
    _drawDroplet(canvas, Offset(cx, bounds.top + bounds.height * 0.30),
        proteinPct, const Color(0xFF00A86B), breathe); // halalGreen
    _drawDroplet(canvas, Offset(cx, bounds.top + bounds.height * 0.52),
        carbsPct, const Color(0xFF2196F3), breathe); // waterBlue
    _drawDroplet(canvas, Offset(cx, bounds.top + bounds.height * 0.74),
        fatPct, const Color(0xFFD4A017), breathe); // barakahGold
  }

  void _drawDroplet(Canvas canvas, Offset center, double pct, Color c, double breathe) {
    final clamped = pct.clamp(0.0, 1.0);
    final r = (2.4 + clamped * 3.4) * breathe;
    final paint = Paint()..color = c.withOpacity(0.95);
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, r, paint);
    canvas.drawCircle(center, r, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _LeafPainter old) {
    return old.progress != progress ||
        old.proteinPct != proteinPct ||
        old.carbsPct != carbsPct ||
        old.fatPct != fatPct ||
        old.color != color ||
        old.isDark != isDark ||
        old.isRamadan != isRamadan ||
        old.t != t;
  }
}
