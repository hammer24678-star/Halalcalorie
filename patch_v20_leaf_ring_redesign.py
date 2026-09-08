#!/usr/bin/env python3
"""
patch_v20_leaf_ring_redesign.py — replace the ugly leaf ring
==============================================================

WHAT THIS DOES
  Rewrites lib/features/nutrition/widgets/leaf_progress_ring.dart from
  scratch. The old painter (PATCH_LEAF_RING_AND_WORKOUT_ASSETS) drew the
  full leaf outline + midrib + side veins even at 0% progress, which at
  rest reads as a bare skeleton/branch diagram rather than a leaf — that's
  the "ugly" ring on the Nutrition "Today" tab.

  New design, same file, same public API (LeafProgressRing with the same
  constructor args), so NOTHING else needs to change — nutrition_screen.dart
  keeps calling it exactly as before:
    - A clean circular track + gradient progress arc (matches the style
      already used for the Home screen's calorie ring), with a soft glow
      and a breathing end-cap dot.
    - A small leaf badge sitting at the top of the ring (a crescent in
      Ramadan mode) — the only "leaf" left in the design, as a marker
      instead of the whole shape.
    - Protein / carbs / fat as three small dots along the *lower* arc,
      sized by how full each macro is — a compact legend instead of dots
      scattered down a central spine.
    - Progress past 100% of goal gets a thin second ring just outside the
      main one, instead of silently clamping.

  Motion is unchanged in spirit: smooth fill sweep on change, a slow
  breathing pulse on the end-cap and macro dots, nothing spins or bounces
  at rest.

SAFETY
  Whole-file replace, gated on a marker check (same idempotent pattern as
  patch_leaf_ring_and_workout_assets.py's write_new_file): refuses to
  touch the file unless it still contains the OLD marker (confirms this
  is the file we expect to replace), and skips if the NEW marker is
  already present (already applied). Run from the project root.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []


def _log(label, status):
    LEDGER.append((label, status))


def replace_file(rel_path, new_content, label, old_marker, new_marker):
    p = ROOT / rel_path
    if not p.exists():
        raise SystemExit(f"ERROR ({label}): {rel_path} not found under {ROOT}")
    existing = p.read_text(encoding="utf-8")
    if new_marker in existing:
        _log(label, "SKIPPED-ALREADY")
        return
    if old_marker not in existing:
        raise SystemExit(
            f"ERROR ({label}): {rel_path} doesn't contain the expected "
            f"marker {old_marker!r} -- refusing to overwrite unknown content."
        )
    p.write_text(new_content, encoding="utf-8")
    _log(label, "REPLACED")


LEAF_WIDGET = "lib/features/nutrition/widgets/leaf_progress_ring.dart"
OLD_MARKER = "PATCH_LEAF_RING_AND_WORKOUT_ASSETS"
NEW_MARKER = "PATCH_V20_RING_REDESIGN"

LEAF_WIDGET_SOURCE = r'''// leaf_progress_ring.dart
// PATCH_V20_RING_REDESIGN
//
// v20 rework of the Nutrition "Today" ring. The original leaf silhouette
// (PATCH_LEAF_RING_AND_WORKOUT_ASSETS) drew its full outline + midrib
// veins even at 0% progress, which at rest read as a bare skeleton/branch
// diagram rather than a leaf. Same public API as before (so
// nutrition_screen.dart needs zero changes), new painter: a clean track +
// gradient arc that glows and sweeps clockwise from 12 o'clock, a small
// leaf badge sitting at the top as the only "leaf" left in the design,
// and three small macro dots (protein/carbs/fat) along the lower arc
// instead of dots scattered down a central spine. Progress past 100% of
// goal gets a thin overflow ring just outside the main one.
//
// Motion stays restrained: smooth fill sweep on change, a slow breathing
// pulse on the end-cap + macro dots, nothing spins or bounces at rest.
//
// Usage unchanged — see nutrition_screen.dart:
//   LeafProgressRing(
//     size: 120,
//     progress: pct,
//     proteinPct: proteinRatio,
//     carbsPct: carbsRatio,
//     fatPct: fatRatio,
//     progressColor: calCol,
//     isDark: isDark,
//     isRamadan: isRamadan,
//     child: <the existing center Column of text>,
//   )

import 'dart:math' as math;
import 'package:flutter/material.dart';

class LeafProgressRing extends StatefulWidget {
  final double size;
  final double progress;   // eaten / goal, NOT clamped by caller
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
  late final AnimationController _pulseCtrl; // idle glow pulse + macro-dot breathing, loops forever
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
              painter: _RingPainter(
                progress: animatedProgress.clamp(0.0, 1.4),
                proteinPct: widget.proteinPct.clamp(0.0, 1.4),
                carbsPct: widget.carbsPct.clamp(0.0, 1.4),
                fatPct: widget.fatPct.clamp(0.0, 1.4),
                color: widget.progressColor,
                isDark: widget.isDark,
                isRamadan: widget.isRamadan,
                t: _pulseCtrl.value, // 0..1 looping, drives glow + breathing
              ),
              child: Center(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double proteinPct;
  final double carbsPct;
  final double fatPct;
  final Color color;
  final bool isDark;
  final bool isRamadan;
  final double t;

  static const _proteinColor = Color(0xFF00A86B); // halalGreen
  static const _carbsColor = Color(0xFF2196F3); // waterBlue
  static const _fatColor = Color(0xFFD4A017); // barakahGold
  static const _startAngle = -math.pi / 2; // 12 o'clock

  _RingPainter({
    required this.progress,
    required this.proteinPct,
    required this.carbsPct,
    required this.fatPct,
    required this.color,
    required this.isDark,
    required this.isRamadan,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2 - 13;
    const trackWidth = 10.0;

    // ── Track ────────────────────────────────────────────────
    final trackColor = isRamadan
        ? const Color(0xFFD4A017).withOpacity(isDark ? 0.16 : 0.13)
        : (isDark ? const Color(0xFF1E3324) : const Color(0xFFE4EFE7));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = trackColor
        ..strokeWidth = trackWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final pct = progress.clamp(0.0, 1.0);
    final rect = Rect.fromCircle(center: center, radius: r);

    if (pct > 0) {
      final sweep = 2 * math.pi * pct;

      // Soft glow behind the arc
      canvas.drawArc(
        rect,
        _startAngle,
        sweep,
        false,
        Paint()
          ..color = color.withOpacity(0.28)
          ..strokeWidth = trackWidth + 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Gradient arc
      canvas.drawArc(
        rect,
        _startAngle,
        sweep,
        false,
        Paint()
          ..shader = SweepGradient(
            startAngle: _startAngle,
            endAngle: _startAngle + sweep,
            colors: [color.withOpacity(0.62), color],
          ).createShader(rect)
          ..strokeWidth = trackWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );

      // Breathing end-cap dot
      final endAngle = _startAngle + sweep;
      final endPoint =
          center + Offset(math.cos(endAngle), math.sin(endAngle)) * r;
      final pulse = 1.0 + 0.14 * math.sin(t * 2 * math.pi);
      canvas.drawCircle(endPoint, (trackWidth / 2 + 2) * pulse,
          Paint()..color = Colors.white.withOpacity(0.92));
      canvas.drawCircle(
          endPoint, trackWidth / 2 * pulse * 0.72, Paint()..color = color);
    }

    // ── Overflow ring: a thin second arc just outside the track for
    // anything past 100% of goal, instead of silently clamping. ─────
    if (progress > 1.0) {
      final overflow = (progress - 1.0).clamp(0.0, 0.4) / 0.4;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r + trackWidth / 2 + 6),
        _startAngle,
        2 * math.pi * overflow,
        false,
        Paint()
          ..color = color.withOpacity(0.7)
          ..strokeWidth = 3.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }

    _drawTopBadge(canvas, center, r);
    _drawMacroDots(canvas, center, r, trackWidth);
  }

  // Small badge sitting on the track at 12 o'clock: a leaf normally, a
  // crescent in Ramadan mode. This is the only "leaf" left in the
  // design — a marker, not the whole shape.
  void _drawTopBadge(Canvas canvas, Offset center, double r) {
    final top = center - Offset(0, r);
    final badgeColor = isRamadan ? const Color(0xFFD4A017) : color;
    final backing = isDark ? const Color(0xFF10201A) : Colors.white;

    canvas.drawCircle(
      top,
      9.5,
      Paint()
        ..color = Colors.black.withOpacity(isDark ? 0.35 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(top, 9, Paint()..color = backing);

    if (isRamadan) {
      canvas.drawCircle(top, 5, Paint()..color = badgeColor);
      canvas.drawCircle(top.translate(2.2, -1.2), 4.2, Paint()..color = backing);
    } else {
      const s = 6.5;
      final leaf = Path()
        ..moveTo(top.dx, top.dy - s)
        ..quadraticBezierTo(
            top.dx + s * 0.85, top.dy - s * 0.15, top.dx, top.dy + s * 0.9)
        ..quadraticBezierTo(
            top.dx - s * 0.85, top.dy - s * 0.15, top.dx, top.dy - s)
        ..close();
      canvas.drawPath(leaf, Paint()..color = badgeColor);
      canvas.drawLine(
        Offset(top.dx, top.dy - s * 0.1),
        Offset(top.dx, top.dy + s * 0.75),
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..strokeWidth = 1,
      );
    }
  }

  // Protein / carbs / fat as three small dots along the lower arc,
  // sized by how full each macro is — a compact legend instead of a
  // vein diagram running down the middle.
  void _drawMacroDots(
      Canvas canvas, Offset center, double r, double trackWidth) {
    final dotRadius = r + trackWidth / 2 + 7;
    final breathe = 1.0 + 0.05 * math.sin(t * 2 * math.pi);
    const angles = [2 * math.pi / 3, math.pi / 2, math.pi / 3]; // left, bottom, right
    final pcts = [proteinPct, carbsPct, fatPct];
    final colors = [_proteinColor, _carbsColor, _fatColor];

    for (var i = 0; i < 3; i++) {
      final pos =
          center + Offset(math.cos(angles[i]), math.sin(angles[i])) * dotRadius;
      final clamped = pcts[i].clamp(0.0, 1.0);
      final radius = (2.6 + clamped * 2.6) * breathe;
      canvas.drawCircle(pos, radius, Paint()..color = colors[i].withOpacity(0.95));
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
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
'''


def main():
    print("=" * 70)
    print("Nutrition ring: v20 redesign (leaf silhouette -> clean glow ring)")
    print("=" * 70)
    replace_file(LEAF_WIDGET, LEAF_WIDGET_SOURCE,
                 "leaf_progress_ring.dart full rewrite", OLD_MARKER, NEW_MARKER)

    print()
    print("=" * 70)
    for label, status in LEDGER:
        print(f"  {status:16s} {label}")
    print("=" * 70)
    print("Public API (LeafProgressRing + all its named params) is unchanged,")
    print("so nutrition_screen.dart needs no edits — just rebuild.")


if __name__ == "__main__":
    main()
