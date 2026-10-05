#!/usr/bin/env python3
"""
patch_v56_onboarding_foodphoto.py
=================================
HalalCalorie v56 - Onboarding polish + Food Photo redesign.
Run from the repo root:

    python3 patch_v56_onboarding_foodphoto.py

Needs v48 applied. Safe to run twice; no new dependencies.

NEW  lib/core/fx8.dart
     PaintedGlyph     29 stroke-drawn icons that draw themselves in
                      (replaces every emoji on the onboarding questions)
     GlyphTile        tinted rounded tile around a glyph
     GlyphChip        small pill with a glyph and a label
     RulerPicker      swipe-to-pick ruler with a big live number, tick haptics,
                      snap-to-tick and -/+ nudge buttons
     PageSlideFx      per-page slide + fade driven by the PageController
     FoodCameraHero   animated camera with orbiting food dots and a flash
     PhotoScanOverlay laser sweep, dot grid and detection pings over a photo
     StageText        status line that cycles through the analysis steps

EDITED  onboarding_screen.dart
     * TRANSITION FIX. Every page was wrapped in one shared FadeTransition
       whose controller restarted from 0 in onPageChanged. That callback fires
       when the swipe passes the halfway point, so both pages blanked out
       mid-slide and then faded back in. Removed. Each page now slides and
       fades from its own distance to the PageController (PageSlideFx), so the
       outgoing and incoming pages cross-fade during the slide.
     * six question screens: painted glyphs instead of emoji (header tile,
       gender cards, goal and activity tiles), staggered tile entrance
     * age / height / weight: ruler picker replaces the slider
         age 1 y, height 0.5 cm, weight 0.1 kg
     * language screen globe and the summary page emoji painted too

EDITED  food_photo_screen.dart
     * intro card: animated camera hero, glyph chips, light sweep
     * photo preview: laser sweep + detection pings while it analyzes,
       status pill, clear button
     * pick buttons: painted camera / gallery
     * Analyze Now: shine button
     * loading card: barcode loader + cycling step text
     * result card: verdict seal, animated calorie count, macro-share rings,
       confidence ring, tip and ingredient pills, an Added state on the
       log button (no double-adding)
     * total bar for multi-item meals, tips as numbered steps

pubspec  1.13.0+27 -> 1.14.0+28
"""
import os, re, sys

ROOT = os.getcwd()
if not os.path.exists(os.path.join(ROOT, 'pubspec.yaml')):
    sys.exit('Run this from the repo root (pubspec.yaml not found).')

ok = skip = 0

def path(p): return os.path.join(ROOT, p)

def write(p, content):
    global ok
    os.makedirs(os.path.dirname(path(p)), exist_ok=True)
    with open(path(p), 'w', encoding='utf-8') as f:
        f.write(content)
    ok += 1
    print('  WROTE  ', p)

def edit(p, fn, label):
    """fn(text) -> new text, or None when the anchor is missing."""
    global ok, skip
    if not os.path.exists(path(p)):
        skip += 1; print('  SKIP   ', p, '(missing)', label); return
    with open(path(p), encoding='utf-8') as f:
        s = f.read()
    n = fn(s)
    if n is None:
        skip += 1; print('  SKIP   ', p, '-', label, '(anchor not found)'); return
    if n == s:
        ok += 1; print('  OK     ', p, '-', label, '(already applied)'); return
    with open(path(p), 'w', encoding='utf-8') as f:
        f.write(n)
    ok += 1
    print('  PATCHED', p, '-', label)

def sub_once(old, new):
    def f(s):
        if new in s: return s
        return s.replace(old, new, 1) if old in s else None
    return f

def cut_once(old, gone):
    """Delete `old`. Counts as already applied once `gone` no longer appears."""
    def f(s):
        if old in s: return s.replace(old, '', 1)
        return s if gone not in s else None
    return f

def rx_once(pattern, repl, sentinel):
    def f(s):
        if sentinel in s: return s
        n, c = re.subn(pattern, lambda m: repl, s, count=1)
        return n if c else None
    return f

def line_start_before(s, marker, frm=0):
    """Start index of the banner line that sits directly above `marker`."""
    i = s.find(marker, frm)
    if i < 0: return -1
    return s.rfind('\n', 0, i - 1) + 1

def slice_edit(start, end, new, sentinel, banner_end=False):
    def f(s):
        if sentinel in s: return s
        a = s.find(start)
        if a < 0: return None
        b = line_start_before(s, end, a) if banner_end else s.find(end, a)
        if b < 0 or b <= a: return None
        return s[:a] + new + s[b:]
    return f


print('== v56 onboarding + food photo ==')

# ════════════════════════════════════════════════════════════════════
#  lib/core/fx8.dart
# ════════════════════════════════════════════════════════════════════
write('lib/core/fx8.dart', r'''// ════════════════════════════════════════════════════════════════════
//  fx8.dart — Painted glyphs, ruler, page motion, camera hero (v56)
//
//    PaintedGlyph      stroke-drawn icon set (replaces emoji)
//    GlyphTile         rounded tinted tile around a glyph
//    GlyphChip         small pill with a glyph and a label
//    RulerPicker       swipe-to-pick ruler with a big live number
//    PageSlideFx       per-page slide + fade driven by the PageController
//    FoodCameraHero    animated camera for the Food Photo intro card
//    PhotoScanOverlay  laser sweep + detection pings over a photo
//    StageText         status line that cycles through steps
// ════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

double _seg(double p, double a, double b) =>
    ((p - a) / (b - a)).clamp(0.0, 1.0).toDouble();

// ════════════════════════════════════════════════════════════════════
//  Glyph set
// ════════════════════════════════════════════════════════════════════

enum GlyphKind {
  person, man, woman, target, bolt, cake, ruler, scale, globe, sparkle,
  flame, bars, arrowDown, dumbbell, balance, heart, crescent,
  chair, steps, pulse, trophy,
  camera, gallery, wheat, drop, shield, bulb, alert, check,
}

class _GP {
  final Path path;
  final bool fill; // soft tinted fill under the stroke
  final bool solid; // filled with the full colour, no stroke
  const _GP(this.path, {this.fill = false, this.solid = false});
}

List<_GP> _glyphPaths(GlyphKind k, double s) {
  Offset o(double x, double y) => Offset(x * s, y * s);
  Path line(double x1, double y1, double x2, double y2) =>
      Path()..moveTo(x1 * s, y1 * s)..lineTo(x2 * s, y2 * s);
  Path poly(List<double> p, {bool close = false}) {
    final path = Path()..moveTo(p[0] * s, p[1] * s);
    for (var i = 2; i < p.length; i += 2) {
      path.lineTo(p[i] * s, p[i + 1] * s);
    }
    if (close) path.close();
    return path;
  }

  Path circle(double cx, double cy, double r) =>
      Path()..addOval(Rect.fromCircle(center: o(cx, cy), radius: r * s));
  Path rrect(double l, double t, double w, double h, double r) => Path()
    ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(l * s, t * s, w * s, h * s), Radius.circular(r * s)));
  Path arc(double cx, double cy, double r, double a0, double sweep) => Path()
    ..addArc(Rect.fromCircle(center: o(cx, cy), radius: r * s), a0, sweep);
  Path shoulders(double l, double r2, double top, double bottom) => Path()
    ..moveTo(l * s, bottom * s)
    ..cubicTo(l * s, top * s, r2 * s, top * s, r2 * s, bottom * s);

  switch (k) {
    case GlyphKind.person:
      return [
        _GP(circle(.5, .32, .16), fill: true),
        _GP(shoulders(.20, .80, .58, .90), fill: true),
      ];
    case GlyphKind.man:
      return [
        _GP(circle(.5, .30, .15), fill: true),
        _GP(arc(.5, .30, .19, math.pi * 0.12, math.pi * 0.76)),
        _GP(shoulders(.18, .82, .60, .92), fill: true),
      ];
    case GlyphKind.woman:
      return [
        _GP(
            Path()
              ..moveTo(.5 * s, .08 * s)
              ..cubicTo(.80 * s, .08 * s, .84 * s, .42 * s, .86 * s, .66 * s)
              ..lineTo(.14 * s, .66 * s)
              ..cubicTo(.16 * s, .42 * s, .20 * s, .08 * s, .5 * s, .08 * s)
              ..close(),
            fill: true),
        _GP(circle(.5, .36, .13)),
        _GP(shoulders(.16, .84, .72, .93)),
      ];
    case GlyphKind.target:
      return [
        _GP(circle(.5, .5, .40)),
        _GP(circle(.5, .5, .26)),
        _GP(circle(.5, .5, .10), solid: true),
        _GP(line(.5, .5, .88, .12)),
        _GP(line(.88, .12, .88, .27)),
        _GP(line(.88, .12, .73, .12)),
      ];
    case GlyphKind.bolt:
      return [
        _GP(
            poly([.58, .06, .24, .54, .46, .54, .40, .94, .78, .42, .55, .42],
                close: true),
            fill: true),
      ];
    case GlyphKind.cake:
      return [
        _GP(rrect(.16, .52, .68, .34, .07), fill: true),
        _GP(Path()
          ..moveTo(.16 * s, .60 * s)
          ..quadraticBezierTo(.24 * s, .72 * s, .33 * s, .60 * s)
          ..quadraticBezierTo(.42 * s, .72 * s, .50 * s, .60 * s)
          ..quadraticBezierTo(.58 * s, .72 * s, .67 * s, .60 * s)
          ..quadraticBezierTo(.75 * s, .72 * s, .84 * s, .60 * s)),
        _GP(line(.5, .32, .5, .50)),
        _GP(circle(.5, .22, .055), solid: true),
        _GP(line(.10, .91, .90, .91)),
      ];
    case GlyphKind.ruler:
      final ticks = <_GP>[];
      for (var i = 0; i < 9; i++) {
        final x = .17 + i * .083;
        final len = i % 2 == 0 ? .13 : .07;
        ticks.add(_GP(line(x, .34, x, .34 + len)));
      }
      return [_GP(rrect(.08, .34, .84, .32, .06), fill: true), ...ticks];
    case GlyphKind.scale:
      return [
        _GP(rrect(.14, .16, .72, .70, .18), fill: true),
        _GP(arc(.5, .50, .21, math.pi, math.pi)),
        _GP(line(.5, .50, .61, .34)),
        _GP(circle(.5, .50, .035), solid: true),
      ];
    case GlyphKind.globe:
      return [
        _GP(circle(.5, .5, .38), fill: true),
        _GP(Path()
          ..addOval(Rect.fromCenter(
              center: o(.5, .5), width: .34 * s, height: .76 * s))),
        _GP(line(.12, .5, .88, .5)),
        _GP(Path()
          ..moveTo(.17 * s, .31 * s)
          ..quadraticBezierTo(.5 * s, .41 * s, .83 * s, .31 * s)),
        _GP(Path()
          ..moveTo(.17 * s, .69 * s)
          ..quadraticBezierTo(.5 * s, .59 * s, .83 * s, .69 * s)),
      ];
    case GlyphKind.sparkle:
      return [
        _GP(
            Path()
              ..moveTo(.46 * s, .10 * s)
              ..quadraticBezierTo(.50 * s, .48 * s, .86 * s, .52 * s)
              ..quadraticBezierTo(.50 * s, .56 * s, .46 * s, .94 * s)
              ..quadraticBezierTo(.42 * s, .56 * s, .06 * s, .52 * s)
              ..quadraticBezierTo(.42 * s, .48 * s, .46 * s, .10 * s)
              ..close(),
            fill: true),
        _GP(line(.82, .10, .82, .26)),
        _GP(line(.74, .18, .90, .18)),
        _GP(circle(.84, .80, .04), solid: true),
      ];
    case GlyphKind.flame:
      return [
        _GP(
            Path()
              ..moveTo(.5 * s, .07 * s)
              ..cubicTo(.52 * s, .30 * s, .80 * s, .38 * s, .78 * s, .64 * s)
              ..cubicTo(.76 * s, .82 * s, .64 * s, .93 * s, .5 * s, .93 * s)
              ..cubicTo(.36 * s, .93 * s, .22 * s, .82 * s, .22 * s, .62 * s)
              ..cubicTo(.22 * s, .50 * s, .30 * s, .42 * s, .36 * s, .34 * s)
              ..cubicTo(.38 * s, .46 * s, .44 * s, .50 * s, .46 * s, .50 * s)
              ..cubicTo(.50 * s, .36 * s, .44 * s, .22 * s, .5 * s, .07 * s)
              ..close(),
            fill: true),
        _GP(Path()
          ..moveTo(.5 * s, .66 * s)
          ..cubicTo(.40 * s, .72 * s, .40 * s, .84 * s, .5 * s, .86 * s)
          ..cubicTo(.60 * s, .84 * s, .60 * s, .72 * s, .5 * s, .66 * s)),
      ];
    case GlyphKind.bars:
      return [
        _GP(rrect(.16, .56, .16, .30, .04), fill: true),
        _GP(rrect(.42, .36, .16, .50, .04), fill: true),
        _GP(rrect(.68, .16, .16, .70, .04), fill: true),
        _GP(line(.08, .92, .92, .92)),
      ];
    case GlyphKind.arrowDown:
      return [
        _GP(line(.5, .12, .5, .86)),
        _GP(poly([.24, .60, .5, .86, .76, .60])),
      ];
    case GlyphKind.dumbbell:
      return [
        _GP(line(.32, .5, .68, .5)),
        _GP(rrect(.12, .27, .13, .46, .04), fill: true),
        _GP(rrect(.25, .36, .08, .28, .03), fill: true),
        _GP(rrect(.75, .27, .13, .46, .04), fill: true),
        _GP(rrect(.67, .36, .08, .28, .03), fill: true),
      ];
    case GlyphKind.balance:
      return [
        _GP(line(.18, .26, .82, .26)),
        _GP(line(.5, .14, .5, .84)),
        _GP(line(.30, .86, .70, .86)),
        _GP(line(.18, .26, .08, .54)),
        _GP(line(.18, .26, .28, .54)),
        _GP(arc(.18, .54, .10, 0, math.pi), fill: true),
        _GP(line(.82, .26, .72, .54)),
        _GP(line(.82, .26, .92, .54)),
        _GP(arc(.82, .54, .10, 0, math.pi), fill: true),
      ];
    case GlyphKind.heart:
      return [
        _GP(
            Path()
              ..moveTo(.5 * s, .85 * s)
              ..cubicTo(.06 * s, .56 * s, .16 * s, .14 * s, .5 * s, .34 * s)
              ..cubicTo(.84 * s, .14 * s, .94 * s, .56 * s, .5 * s, .85 * s)
              ..close(),
            fill: true),
      ];
    case GlyphKind.crescent:
      return [
        _GP(
            Path.combine(PathOperation.difference, circle(.44, .52, .36),
                circle(.60, .42, .30)),
            fill: true),
        _GP(line(.78, .14, .78, .34)),
        _GP(line(.68, .24, .88, .24)),
      ];
    case GlyphKind.chair:
      return [
        _GP(line(.30, .12, .30, .56)),
        _GP(rrect(.26, .52, .50, .11, .04), fill: true),
        _GP(line(.34, .63, .34, .90)),
        _GP(line(.70, .63, .70, .90)),
      ];
    case GlyphKind.steps:
      return [
        _GP(Path()..addOval(Rect.fromLTWH(.16 * s, .34 * s, .20 * s, .30 * s)),
            fill: true),
        _GP(circle(.26, .77, .07), fill: true),
        _GP(Path()..addOval(Rect.fromLTWH(.58 * s, .12 * s, .20 * s, .30 * s)),
            fill: true),
        _GP(circle(.68, .55, .07), fill: true),
      ];
    case GlyphKind.pulse:
      return [
        _GP(poly([.06, .54, .28, .54, .38, .26, .52, .82, .62, .42, .70, .54, .94, .54])),
      ];
    case GlyphKind.trophy:
      return [
        _GP(
            Path()
              ..moveTo(.30 * s, .14 * s)
              ..lineTo(.70 * s, .14 * s)
              ..lineTo(.66 * s, .46 * s)
              ..cubicTo(.64 * s, .60 * s, .36 * s, .60 * s, .34 * s, .46 * s)
              ..close(),
            fill: true),
        _GP(Path()
          ..moveTo(.30 * s, .20 * s)
          ..cubicTo(.08 * s, .20 * s, .10 * s, .46 * s, .33 * s, .45 * s)),
        _GP(Path()
          ..moveTo(.70 * s, .20 * s)
          ..cubicTo(.92 * s, .20 * s, .90 * s, .46 * s, .67 * s, .45 * s)),
        _GP(line(.5, .58, .5, .74)),
        _GP(rrect(.34, .74, .32, .11, .03), fill: true),
      ];
    case GlyphKind.camera:
      return [
        _GP(rrect(.10, .28, .80, .56, .12), fill: true),
        _GP(poly([.34, .28, .40, .15, .60, .15, .66, .28])),
        _GP(circle(.5, .56, .19)),
        _GP(circle(.5, .56, .085), solid: true),
        _GP(circle(.80, .40, .03), solid: true),
      ];
    case GlyphKind.gallery:
      return [
        _GP(rrect(.12, .18, .76, .64, .10), fill: true),
        _GP(poly([.16, .72, .38, .46, .52, .62, .64, .50, .84, .72])),
        _GP(circle(.68, .34, .06), solid: true),
      ];
    case GlyphKind.wheat:
      Path leaf(double y, double dir) => Path()
        ..moveTo(.5 * s, (y + .10) * s)
        ..quadraticBezierTo((.5 + dir * .24) * s, (y + .04) * s,
            (.5 + dir * .26) * s, (y - .10) * s)
        ..quadraticBezierTo((.5 + dir * .04) * s, (y - .06) * s, .5 * s,
            (y + .10) * s)
        ..close();
      return [
        _GP(line(.5, .94, .5, .16)),
        _GP(leaf(.46, -1), fill: true),
        _GP(leaf(.46, 1), fill: true),
        _GP(leaf(.64, -1), fill: true),
        _GP(leaf(.64, 1), fill: true),
        _GP(leaf(.82, -1), fill: true),
        _GP(leaf(.82, 1), fill: true),
        _GP(
            Path()
              ..moveTo(.5 * s, .30 * s)
              ..quadraticBezierTo(.38 * s, .20 * s, .5 * s, .05 * s)
              ..quadraticBezierTo(.62 * s, .20 * s, .5 * s, .30 * s)
              ..close(),
            fill: true),
      ];
    case GlyphKind.drop:
      return [
        _GP(
            Path()
              ..moveTo(.5 * s, .07 * s)
              ..cubicTo(.5 * s, .07 * s, .20 * s, .44 * s, .20 * s, .62 * s)
              ..cubicTo(.20 * s, .80 * s, .34 * s, .92 * s, .5 * s, .92 * s)
              ..cubicTo(.66 * s, .92 * s, .80 * s, .80 * s, .80 * s, .62 * s)
              ..cubicTo(.80 * s, .44 * s, .5 * s, .07 * s, .5 * s, .07 * s)
              ..close(),
            fill: true),
        _GP(Path()
          ..moveTo(.35 * s, .62 * s)
          ..quadraticBezierTo(.35 * s, .76 * s, .45 * s, .80 * s)),
      ];
    case GlyphKind.shield:
      return [
        _GP(
            Path()
              ..moveTo(.5 * s, .07 * s)
              ..lineTo(.84 * s, .20 * s)
              ..lineTo(.84 * s, .50 * s)
              ..cubicTo(.84 * s, .72 * s, .66 * s, .86 * s, .5 * s, .93 * s)
              ..cubicTo(.34 * s, .86 * s, .16 * s, .72 * s, .16 * s, .50 * s)
              ..lineTo(.16 * s, .20 * s)
              ..close(),
            fill: true),
        _GP(poly([.34, .50, .46, .62, .68, .38])),
      ];
    case GlyphKind.bulb:
      return [
        _GP(circle(.5, .40, .27), fill: true),
        _GP(line(.40, .76, .60, .76)),
        _GP(line(.43, .87, .57, .87)),
        _GP(poly([.42, .62, .42, .50, .5, .42, .58, .50, .58, .62])),
        _GP(line(.5, .02, .5, .07)),
        _GP(line(.12, .14, .16, .18)),
        _GP(line(.88, .14, .84, .18)),
      ];
    case GlyphKind.alert:
      return [
        _GP(poly([.5, .10, .92, .84, .08, .84], close: true), fill: true),
        _GP(line(.5, .38, .5, .60)),
        _GP(circle(.5, .72, .035), solid: true),
      ];
    case GlyphKind.check:
      return [
        _GP(circle(.5, .5, .40), fill: true),
        _GP(poly([.30, .52, .44, .66, .70, .36])),
      ];
  }
}

class PaintedGlyph extends StatefulWidget {
  final GlyphKind kind;
  final Color color;
  final double size;
  final double? strokeWidth;
  final bool animate;
  const PaintedGlyph({
    super.key,
    required this.kind,
    required this.color,
    this.size = 40,
    this.strokeWidth,
    this.animate = true,
  });

  @override
  State<PaintedGlyph> createState() => _PaintedGlyphState();
}

class _PaintedGlyphState extends State<PaintedGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.animate ? 0.0 : 1.0,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void didUpdateWidget(PaintedGlyph old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      if (widget.animate) {
        _c.forward(from: 0);
      } else {
        _c.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = widget.strokeWidth ?? math.max(1.6, widget.size * 0.07);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _GlyphPainter(
            kind: widget.kind,
            color: widget.color,
            p: _c.value,
            sw: sw,
          ),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final GlyphKind kind;
  final Color color;
  final double p, sw;
  const _GlyphPainter({
    required this.kind,
    required this.color,
    required this.p,
    required this.sw,
  });

  @override
  void paint(Canvas c, Size size) {
    final items = _glyphPaths(kind, size.width);
    final fade = _seg(p, 0.40, 1.0);
    final draw = Curves.easeOutCubic.transform(_seg(p, 0.0, 0.85));

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final soft = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(0.20 * fade);
    final solid = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(fade);

    for (final it in items) {
      if (it.solid) {
        c.drawPath(it.path, solid);
        continue;
      }
      if (it.fill) c.drawPath(it.path, soft);
      if (draw >= 1.0) {
        c.drawPath(it.path, stroke);
      } else {
        for (final m in it.path.computeMetrics()) {
          c.drawPath(m.extractPath(0, m.length * draw), stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.p != p ||
      old.kind != kind ||
      old.color != color ||
      old.sw != sw;
}

// ════════════════════════════════════════════════════════════════════
//  GlyphTile / GlyphChip
// ════════════════════════════════════════════════════════════════════

class GlyphTile extends StatelessWidget {
  final GlyphKind glyph;
  final Color color;
  final double size;
  final bool filled;
  final bool animate;
  const GlyphTile({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 48,
    this.filled = false,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: filled
              ? [color.withOpacity(0.95), color.withOpacity(0.70)]
              : [color.withOpacity(0.26), color.withOpacity(0.06)],
        ),
        border: Border.all(color: color.withOpacity(0.40), width: 0.8),
        boxShadow: filled
            ? [
                BoxShadow(
                    color: color.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 5))
              ]
            : const [],
      ),
      child: Center(
        child: PaintedGlyph(
          kind: glyph,
          color: filled ? Colors.white : color,
          size: size * 0.58,
          animate: animate,
        ),
      ),
    );
  }
}

class GlyphChip extends StatelessWidget {
  final GlyphKind glyph;
  final String text;
  final Color color;
  const GlyphChip({
    super.key,
    required this.glyph,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        PaintedGlyph(kind: glyph, color: color, size: 14, animate: false),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Aligarh',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  RulerPicker
// ════════════════════════════════════════════════════════════════════

class RulerPicker extends StatefulWidget {
  final double value, min, max, step;
  final double gap; // px between ticks
  final int midEvery, majorEvery, labelEvery; // in ticks
  final double nudge;
  final String unit, unitEn;
  final bool isAr, isDark;
  final Color color;
  final ValueChanged<double> onChanged;

  const RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.unitEn,
    required this.color,
    required this.isDark,
    required this.onChanged,
    this.isAr = true,
    this.gap = 12,
    this.midEvery = 1,
    this.majorEvery = 10,
    this.labelEvery = 10,
    this.nudge = 1,
  });

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late final ScrollController _sc;
  late int _lastIdx;

  int get _n => ((widget.max - widget.min) / widget.step).round();
  int _idxOf(double v) =>
      ((v - widget.min) / widget.step).round().clamp(0, _n).toInt();
  double _valOf(int i) => widget.min + i * widget.step;
  int get _decimals => widget.step >= 1 ? 0 : 1;

  @override
  void initState() {
    super.initState();
    _lastIdx = _idxOf(widget.value);
    _sc = ScrollController(initialScrollOffset: _lastIdx * widget.gap);
  }

  @override
  void didUpdateWidget(RulerPicker old) {
    super.didUpdateWidget(old);
    final target = _idxOf(widget.value);
    if (target != _lastIdx && _sc.hasClients) {
      _lastIdx = target;
      _sc.animateTo(
        target * widget.gap,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (!_sc.hasClients) return false;
    if (n is ScrollUpdateNotification) {
      final idx = (_sc.offset / widget.gap).round().clamp(0, _n).toInt();
      if (idx != _lastIdx) {
        _lastIdx = idx;
        HapticFeedback.selectionClick();
        widget.onChanged(_valOf(idx));
      }
    } else if (n is ScrollEndNotification) {
      final target = _lastIdx * widget.gap;
      if ((_sc.offset - target).abs() > 0.5) {
        _sc.animateTo(
          target,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    }
    return false;
  }

  void _bump(double d) {
    HapticFeedback.lightImpact();
    final v = (widget.value + d).clamp(widget.min, widget.max).toDouble();
    widget.onChanged(v);
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    final col = widget.color;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: col.withOpacity(0.12),
          border: Border.all(color: col.withOpacity(0.32)),
        ),
        child: Icon(icon, color: col, size: 22),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final col = widget.color;
    final muted =
        widget.isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D);
    final shown = widget.value.toStringAsFixed(_decimals);
    return Column(children: [
      Row(children: [
        _roundBtn(Icons.remove_rounded, () => _bump(-widget.nudge)),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                shown,
                style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: col,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 8, right: 8),
                child: Text(
                  widget.isAr ? widget.unit : widget.unitEn,
                  style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: col.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
        _roundBtn(Icons.add_rounded, () => _bump(widget.nudge)),
      ]),
      const SizedBox(height: 22),
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: 84,
          child: LayoutBuilder(builder: (context, cons) {
            final vw = cons.maxWidth;
            final total = _n * widget.gap + vw;
            return Stack(children: [
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.16, 0.84, 1.0],
                ).createShader(r),
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScroll,
                  child: SingleChildScrollView(
                    controller: _sc,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size(total, 84),
                        painter: _RulerPainter(
                          n: _n,
                          gap: widget.gap,
                          pad: vw / 2,
                          min: widget.min,
                          step: widget.step,
                          midEvery: widget.midEvery,
                          majorEvery: widget.majorEvery,
                          labelEvery: widget.labelEvery,
                          color: col,
                          muted: muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: vw / 2 - 1.5,
                top: 0,
                height: 52,
                child: IgnorePointer(
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: col,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                            color: col.withOpacity(0.55), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ]);
          }),
        ),
      ),
    ]);
  }
}

class _RulerPainter extends CustomPainter {
  final int n, midEvery, majorEvery, labelEvery;
  final double gap, pad, min, step;
  final Color color, muted;
  const _RulerPainter({
    required this.n,
    required this.gap,
    required this.pad,
    required this.min,
    required this.step,
    required this.midEvery,
    required this.majorEvery,
    required this.labelEvery,
    required this.color,
    required this.muted,
  });

  @override
  void paint(Canvas c, Size s) {
    final minor = Path(), mid = Path(), major = Path();
    for (var i = 0; i <= n; i++) {
      final x = pad + i * gap;
      if (i % majorEvery == 0) {
        major
          ..moveTo(x, 6)
          ..lineTo(x, 46);
      } else if (i % midEvery == 0) {
        mid
          ..moveTo(x, 6)
          ..lineTo(x, 32);
      } else {
        minor
          ..moveTo(x, 6)
          ..lineTo(x, 20);
      }
    }
    Paint pen(double w, Color col) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = col;
    c.drawPath(minor, pen(1.3, muted.withOpacity(0.45)));
    c.drawPath(mid, pen(1.7, muted.withOpacity(0.75)));
    c.drawPath(major, pen(2.6, color.withOpacity(0.92)));

    for (var i = 0; i <= n; i += labelEvery) {
      final v = min + i * step;
      final whole = (v - v.roundToDouble()).abs() < 1e-6;
      final tp = TextPainter(
        text: TextSpan(
          text: whole ? v.round().toString() : v.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: 'Aligarh',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(pad + i * gap - tp.width / 2, 56));
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.n != n ||
      old.gap != gap ||
      old.pad != pad ||
      old.color != color ||
      old.muted != muted;
}

// ════════════════════════════════════════════════════════════════════
//  PageSlideFx
// ════════════════════════════════════════════════════════════════════

class PageSlideFx extends StatelessWidget {
  final PageController controller;
  final int index;
  final Widget child;
  const PageSlideFx({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (_, ch) {
        double? pg;
        try {
          if (controller.hasClients) pg = controller.page;
        } catch (_) {}
        final d = ((pg ?? index.toDouble()) - index)
            .clamp(-1.0, 1.0)
            .toDouble();
        final a = d.abs();
        final dx = -d * 36.0 * (rtl ? -1.0 : 1.0);
        return Opacity(
          opacity: (1.0 - a * 1.15).clamp(0.0, 1.0).toDouble(),
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: Transform.scale(scale: 1.0 - 0.06 * a, child: ch),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  FoodCameraHero
// ════════════════════════════════════════════════════════════════════

class FoodCameraHero extends StatefulWidget {
  final double height;
  const FoodCameraHero({super.key, this.height = 150});

  @override
  State<FoodCameraHero> createState() => _FoodCameraHeroState();
}

class _FoodCameraHeroState extends State<FoodCameraHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(painter: _CamHeroPainter(t: _c.value)),
        ),
      ),
    );
  }
}

class _CamHeroPainter extends CustomPainter {
  final double t;
  const _CamHeroPainter({required this.t});

  static const _food = [
    Color(0xFFF0CF98),
    Color(0xFFFF8A65),
    Color(0xFF81C784),
    Color(0xFF64B5F6),
    Color(0xFFFFF59D),
  ];

  void _orbit(Canvas c, Offset ctr, double u, bool front) {
    for (var i = 0; i < _food.length; i++) {
      final a = 2 * math.pi * (t + i / _food.length);
      final sn = math.sin(a);
      if ((sn >= 0) != front) continue;
      final pos = ctr + Offset(math.cos(a) * 98 * u, sn * 40 * u - 4 * u);
      final r = (4.2 + 1.6 * sn) * u;
      c.drawCircle(
        pos,
        r + 2.2 * u,
        Paint()..color = Colors.white.withOpacity(front ? 0.30 : 0.12),
      );
      c.drawCircle(
        pos,
        r,
        Paint()..color = _food[i].withOpacity(front ? 1.0 : 0.55),
      );
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final u = s.height / 150.0;
    final ctr = Offset(s.width / 2, s.height * 0.54);
    final white = Colors.white;

    // expanding rings behind the camera
    for (var k = 0; k < 3; k++) {
      final ph = (t * 3 + k / 3) % 1.0;
      c.drawCircle(
        ctr,
        (34 + 78 * ph) * u,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * u
          ..color = white.withOpacity(0.20 * (1 - ph)),
      );
    }

    _orbit(c, ctr, u, false);

    // body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: ctr, width: 128 * u, height: 88 * u),
      Radius.circular(24 * u),
    );
    c.drawRRect(body, Paint()..color = white.withOpacity(0.14));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = white.withOpacity(0.95);
    c.drawRRect(body, line);
    final top = body.top;
    c.drawPath(
      Path()
        ..moveTo(ctr.dx - 36 * u, top)
        ..lineTo(ctr.dx - 27 * u, top - 12 * u)
        ..lineTo(ctr.dx + 14 * u, top - 12 * u)
        ..lineTo(ctr.dx + 23 * u, top),
      line,
    );

    // flash window + glow
    final fw = Offset(body.right - 24 * u, top + 15 * u);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: fw, width: 16 * u, height: 9 * u),
        Radius.circular(3 * u),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * u
        ..color = white.withOpacity(0.9),
    );
    final fp = (t * 2) % 1.0;
    final glow = math.pow(math.max(0.0, 1.0 - fp * 6.0), 2).toDouble();
    if (glow > 0) {
      c.drawCircle(
        fw,
        26 * u,
        Paint()
          ..shader = RadialGradient(colors: [
            white.withOpacity(0.55 * glow),
            white.withOpacity(0.0),
          ]).createShader(Rect.fromCircle(center: fw, radius: 26 * u)),
      );
    }

    // lens
    c.drawCircle(ctr + Offset(0, 4 * u), 28 * u, line);
    c.drawCircle(
        ctr + Offset(0, 4 * u), 18 * u, Paint()..color = white.withOpacity(0.18));
    final iris = (10 + 2.2 * math.sin(2 * math.pi * t * 3)) * u;
    c.drawCircle(
        ctr + Offset(0, 4 * u), iris, Paint()..color = white.withOpacity(0.92));
    c.drawCircle(ctr + Offset(-7 * u, -3 * u), 3 * u,
        Paint()..color = white.withOpacity(0.85));

    // viewfinder corners
    final r = body.outerRect.inflate((20 + 2.5 * math.sin(2 * math.pi * t * 2)) * u);
    final L = 17 * u;
    final br = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFF0CF98);
    final bp = Path()
      ..moveTo(r.left, r.top + L)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + L, r.top)
      ..moveTo(r.right - L, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + L)
      ..moveTo(r.right, r.bottom - L)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - L, r.bottom)
      ..moveTo(r.left + L, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - L);
    c.drawPath(bp, br);

    _orbit(c, ctr, u, true);

    // twinkles
    const stars = [Offset(0.18, 0.20), Offset(0.84, 0.16), Offset(0.90, 0.72)];
    for (var i = 0; i < stars.length; i++) {
      final o = Offset(s.width * stars[i].dx, s.height * stars[i].dy);
      final a = 0.2 + 0.8 * math.pow(math.sin(2 * math.pi * t * (2 + i) + i * 2), 2);
      final len = (3.0 + i) * u;
      final sp = Paint()
        ..strokeWidth = 1.4 * u
        ..strokeCap = StrokeCap.round
        ..color = white.withOpacity(a.toDouble());
      c.drawLine(o - Offset(len, 0), o + Offset(len, 0), sp);
      c.drawLine(o - Offset(0, len), o + Offset(0, len), sp);
    }
  }

  @override
  bool shouldRepaint(_CamHeroPainter old) => old.t != t;
}

// ════════════════════════════════════════════════════════════════════
//  PhotoScanOverlay
// ════════════════════════════════════════════════════════════════════

class PhotoScanOverlay extends StatefulWidget {
  final Color color;
  const PhotoScanOverlay({super.key, this.color = const Color(0xFF78E08E)});

  @override
  State<PhotoScanOverlay> createState() => _PhotoScanOverlayState();
}

class _PhotoScanOverlayState extends State<PhotoScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => SizedBox.expand(
            child: CustomPaint(
              painter: _ScanPhotoPainter(t: _c.value, color: widget.color),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanPhotoPainter extends CustomPainter {
  final double t;
  final Color color;
  const _ScanPhotoPainter({required this.t, required this.color});

  static const _pings = [
    Offset(0.26, 0.38),
    Offset(0.68, 0.30),
    Offset(0.50, 0.66),
    Offset(0.78, 0.62),
    Offset(0.32, 0.74),
  ];

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    c.drawRect(Offset.zero & s, Paint()..color = Colors.black.withOpacity(0.28));

    // faint dot grid
    final pts = <Offset>[];
    for (var x = 20.0; x < w; x += 26) {
      for (var y = 20.0; y < h; y += 26) {
        pts.add(Offset(x, y));
      }
    }
    c.drawPoints(
      PointMode.points,
      pts,
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.12),
    );

    // detection pings
    for (var i = 0; i < _pings.length; i++) {
      final ph = (t + i * 0.23) % 1.0;
      final a = math.sin(math.pi * ph);
      final pos = Offset(w * _pings[i].dx, h * _pings[i].dy);
      c.drawCircle(
        pos,
        5 + 15 * ph,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withOpacity(0.75 * a),
      );
      c.drawCircle(pos, 2.6, Paint()..color = color.withOpacity(0.95 * a));
    }

    // laser
    final u = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    final y = 10 + (h - 20) * u;
    final down = math.sin(2 * math.pi * t) >= 0;
    final tt = down ? y - 70 : y;
    final tb = down ? y : y + 70;
    final trail = Rect.fromLTRB(0, tt, w, tb);
    c.drawRect(
      trail,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: down
              ? [color.withOpacity(0.0), color.withOpacity(0.34)]
              : [color.withOpacity(0.34), color.withOpacity(0.0)],
        ).createShader(trail),
    );
    c.drawLine(
      Offset(10, y),
      Offset(w - 10, y),
      Paint()
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = color.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    c.drawLine(
      Offset(0, y),
      Offset(w, y),
      Paint()
        ..strokeWidth = 2.2
        ..shader = LinearGradient(colors: [
          color.withOpacity(0.0),
          color,
          color.withOpacity(0.0),
        ], stops: const [0.0, 0.5, 1.0])
            .createShader(Rect.fromLTWH(0, y - 1, w, 2)),
    );

    // corner brackets
    final inset = 10.0 + 1.6 * math.sin(2 * math.pi * t * 2);
    const L = 26.0;
    final r = Rect.fromLTWH(inset, inset, w - inset * 2, h - inset * 2);
    final bp = Path()
      ..moveTo(r.left, r.top + L)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + L, r.top)
      ..moveTo(r.right - L, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + L)
      ..moveTo(r.right, r.bottom - L)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - L, r.bottom)
      ..moveTo(r.left + L, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - L);
    c.drawPath(
      bp,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_ScanPhotoPainter old) =>
      old.t != t || old.color != color;
}

// ════════════════════════════════════════════════════════════════════
//  StageText
// ════════════════════════════════════════════════════════════════════

class StageText extends StatefulWidget {
  final List<String> lines;
  final TextStyle style;
  final Duration interval;
  const StageText({
    super.key,
    required this.lines,
    required this.style,
    this.interval = const Duration(milliseconds: 1800),
  });

  @override
  State<StageText> createState() => _StageTextState();
}

class _StageTextState extends State<StageText> {
  int _i = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted || widget.lines.isEmpty) return;
      setState(() => _i = (_i + 1) % widget.lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) return const SizedBox.shrink();
    final text = widget.lines[_i % widget.lines.length];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        text,
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: widget.style,
      ),
    );
  }
}
''')


# ════════════════════════════════════════════════════════════════════
#  onboarding_screen.dart
# ════════════════════════════════════════════════════════════════════
ONB = 'lib/features/onboarding/onboarding_screen.dart'

edit(ONB, sub_once(
    "import '../../core/motion.dart';\nimport '../../core/providers.dart';",
    "import '../../core/motion.dart';\nimport '../../core/fx8.dart';\nimport '../../core/providers.dart';"),
    'import fx8')

# ── transition fix: drop the shared fade/slide controller ───────────
edit(ONB, cut_once(
    "  // ── Page transition animations ──────────────────────────\n"
    "  late AnimationController _enterCtrl;\n"
    "  late Animation<double>   _enterFade;\n"
    "  late Animation<Offset>   _enterSlide;\n\n",
    '_enterCtrl'), 'transition fix: fields')

edit(ONB, cut_once(
    "    _enterCtrl = AnimationController(\n"
    "      vsync: this, duration: const Duration(milliseconds: 550));\n"
    "    _enterFade  = CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut);\n"
    "    _enterSlide = Tween<Offset>(\n"
    "      begin: const Offset(0.06, 0), end: Offset.zero)\n"
    "      .animate(CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic));\n\n",
    '_enterCtrl'), 'transition fix: initState setup')

edit(ONB, sub_once(
    "..repeat(reverse: true);\n\n    _enterCtrl.forward();\n  }",
    "..repeat(reverse: true);\n  }"),
    'transition fix: initState forward')

edit(ONB, cut_once("    _enterCtrl.dispose();\n", '_enterCtrl'),
     'transition fix: dispose')

edit(ONB, sub_once(
"""                onPageChanged: (i) {
                  setState(() => _page = i);
                  _enterCtrl.forward(from: 0);
                },
                itemCount: _kTotalPages,
                itemBuilder: (ctx, i) {
                  return FadeTransition(
                    opacity: _enterFade,
                    child: SlideTransition(
                      position: _enterSlide,
                      child: _buildPage(i, isDark, lang),
                    ),
                  );
                },""",
"""                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _kTotalPages,
                itemBuilder: (ctx, i) => PageSlideFx(
                  controller: _pageCtrl,
                  index: i,
                  child: _buildPage(i, isDark, lang),
                ),"""),
    'transition fix: per-page slide + fade')

# ── language page globe ─────────────────────────────────────────────
edit(ONB, rx_once(
    r"child: const (?:Text\('[^']*', style: TextStyle\(fontSize: 72\)\)|EmojiIcon\('[^']*', size: 72\)),",
    "child: const PaintedGlyph(\n"
    "                kind: GlyphKind.globe, color: AppColors.brandGreen, size: 84),",
    'GlyphKind.globe'),
    'language globe')

# ── question headers ────────────────────────────────────────────────
for ttl, glyph in [("من أنت؟", 'person'), ("ما هدفك؟", 'target'),
                   ("مستوى نشاطك؟", 'bolt'), ("كم عمرك؟", 'cake'),
                   ("كم طولك؟", 'ruler'), ("كم وزنك؟", 'scale')]:
    edit(ONB, rx_once(
        r"emoji: '[^']*',(\n\s+)title: '" + re.escape(ttl) + "'",
        "glyph: GlyphKind.%s,\n        title: '%s'" % (glyph, ttl),
        "glyph: GlyphKind.%s,\n        title: '%s'" % (glyph, ttl)),
        'header glyph ' + glyph)

edit(ONB, rx_once(r"emoji: '[^']*', labelAr: 'رجل'",
                  "glyph: GlyphKind.man, labelAr: 'رجل'",
                  "glyph: GlyphKind.man, labelAr"), 'gender card man')
edit(ONB, rx_once(r"emoji: '[^']*', labelAr: 'بنت'",
                  "glyph: GlyphKind.woman, labelAr: 'بنت'",
                  "glyph: GlyphKind.woman, labelAr"), 'gender card woman')

edit(ONB, sub_once("                emoji: goal.emoji(),",
                   "                glyph: _goalGlyph(goal),\n                index: e.key,"),
     'goal tile glyph')
edit(ONB, sub_once("                emoji: act.emoji(),",
                   "                glyph: _activityGlyph(act),\n                index: e.key,"),
     'activity tile glyph')

# ── ruler pickers ───────────────────────────────────────────────────
edit(ONB, sub_once(
    "child: _NumberSlider(\n          value: _age.toDouble(),\n          min: 10, max: 80,",
    "child: RulerPicker(\n          value: _age.toDouble(),\n          min: 10, max: 80, step: 1, gap: 14,\n"
    "          midEvery: 1, majorEvery: 5, labelEvery: 5, nudge: 1,"),
    'age ruler')
edit(ONB, sub_once(
    "child: _NumberSlider(\n          value: _height,\n          min: 140, max: 210,",
    "child: RulerPicker(\n          value: _height,\n          min: 140, max: 210, step: 0.5, gap: 12,\n"
    "          midEvery: 2, majorEvery: 10, labelEvery: 10, nudge: 1,"),
    'height ruler')
edit(ONB, sub_once(
    "child: _NumberSlider(\n          value: _weight,\n          min: 30, max: 180,",
    "child: RulerPicker(\n          value: _weight,\n          min: 30, max: 180, step: 0.1, gap: 7,\n"
    "          midEvery: 5, majorEvery: 10, labelEvery: 10, nudge: 0.5,"),
    'weight ruler')

# ── question shell + gender card ────────────────────────────────────
SHELL = r'''class _QuestionShell extends ConsumerWidget {
  final GlyphKind glyph;
  final String title, titleEn;
  final bool isDark;
  final Widget child;
  const _QuestionShell({
    required this.glyph, required this.title,
    required this.titleEn, required this.isDark, required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 560),
            curve: Curves.easeOutBack,
            builder: (_, v, c) => Transform.scale(scale: v, child: c),
            child: GlyphTile(
              glyph: glyph, color: AppColors.halalGreen, size: 72),
          ),
          const SizedBox(height: 14),
          Reveal(
            index: 1,
            offset: 0.2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isAr ? title : titleEn, style: TextStyle(
                  fontFamily: 'Aligarh', fontSize: 28, fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1F2A1F),
                )),
                Text(isAr ? titleEn : title, style: TextStyle(
                  fontFamily: 'Aligarh', fontSize: 13,
                  color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D),
                )),
              ],
            ),
          ),
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  GENDER CARD
// ═══════════════════════════════════════════════════════════
class _GenderCard extends ConsumerWidget {
  final GlyphKind glyph;
  final String labelAr, labelEn;
  final bool selected, isDark;
  final Color color;
  final VoidCallback onTap;
  const _GenderCard({
    required this.glyph, required this.labelAr, required this.labelEn,
    required this.selected, required this.isDark, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    return Expanded(child: PressFx(
      onTap: onTap,
      scale: 0.96,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        height: 176,
        decoration: BoxDecoration(
          color: selected
            ? color.withOpacity(0.12)
            : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : (isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF)),
            width: selected ? 2 : 0.6,
          ),
          boxShadow: selected
            ? [BoxShadow(color: color.withOpacity(0.22),
                blurRadius: 18, offset: const Offset(0, 6))]
            : const [],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            child: GlyphTile(
              glyph: glyph, color: color, size: 78, filled: selected),
          ),
          const SizedBox(height: 14),
          Text(isAr ? labelAr : labelEn, style: TextStyle(
            fontFamily: 'Aligarh', fontSize: 18, fontWeight: FontWeight.w800,
            color: selected ? color : (isDark ? Colors.white : const Color(0xFF1F2A1F)),
          )),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: selected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
            ),
          ),
        ]),
      ),
    ));
  }
}

'''
edit(ONB, slice_edit(
    'class _QuestionShell extends ConsumerWidget {',
    '//  LANGUAGE CHOICE CARD', SHELL,
    'class _QuestionShell extends ConsumerWidget {\n  final GlyphKind glyph;',
    banner_end=True),
    'question shell + gender cards')

# ── select tile (also drops the old number slider) ──────────────────
SELECT = r'''class _SelectTile extends ConsumerWidget {
  final GlyphKind glyph;
  final String title;
  final String? titleEn;
  final bool selected, isDark;
  final int index;
  final VoidCallback onTap;
  const _SelectTile({
    required this.glyph, required this.title,
    this.titleEn, this.index = 0,
    required this.selected, required this.isDark, required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    return Reveal(
      index: index,
      offset: 0.14,
      child: PressFx(
        onTap: onTap,
        scale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
              ? AppColors.halalGreen.withOpacity(0.10)
              : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                ? AppColors.halalGreen
                : (isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF)),
              width: selected ? 2 : 0.6,
            ),
          ),
          child: Row(children: [
            GlyphTile(
              glyph: glyph, color: AppColors.halalGreen,
              size: 44, filled: selected, animate: false),
            const SizedBox(width: 12),
            Expanded(child: Text((!isAr && titleEn != null) ? titleEn! : title, style: TextStyle(
              fontFamily: 'Aligarh', fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected
                ? AppColors.halalGreen
                : (isDark ? Colors.white : const Color(0xFF1F2A1F)),
            ))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: selected ? AppColors.halalGreen : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                    ? AppColors.halalGreen
                    : (isDark ? const Color(0xFF7D8590) : const Color(0xFFCCCCCC)),
                  width: 2,
                ),
              ),
              child: selected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : null,
            ),
          ]),
        ),
      ),
    );
  }
}

'''
edit(ONB, slice_edit(
    'class _SelectTile extends ConsumerWidget {',
    '//  SUMMARY PAGE', SELECT,
    'class _SelectTile extends ConsumerWidget {\n  final GlyphKind glyph;',
    banner_end=True),
    'select tile (old slider removed)')

# ── summary page ────────────────────────────────────────────────────
edit(ONB, rx_once(r"const (?:Text\('[^']*', style: TextStyle\(fontSize: 44\)\)|EmojiIcon\('[^']*', size: 44\)),",
    "const PaintedGlyph(\n"
    "              kind: GlyphKind.sparkle, color: AppColors.accentGold, size: 54),",
    'GlyphKind.sparkle'), 'summary sparkle')
edit(ONB, rx_once(r"_SummaryTile\('[^']*', t\('الوزن'",
    "_SummaryTile(GlyphKind.scale, t('الوزن'", 'GlyphKind.scale, t'),
    'summary tile weight')
edit(ONB, rx_once(r"_SummaryTile\('[^']*', t\('الطول'",
    "_SummaryTile(GlyphKind.ruler, t('الطول'", 'GlyphKind.ruler, t'),
    'summary tile height')
edit(ONB, rx_once(r"_SummaryTile\('[^']*', t\('العمر'",
    "_SummaryTile(GlyphKind.cake, t('العمر'", 'GlyphKind.cake, t'),
    'summary tile age')
edit(ONB, rx_once(r"_SummaryTile\('[^']*', 'BMI'",
    "_SummaryTile(GlyphKind.bars, 'BMI'", 'GlyphKind.bars, '),
    'summary tile bmi')
edit(ONB, rx_once(r"const (?:Text\('[^']*', style: TextStyle\(fontSize: 36\)\)|EmojiIcon\('[^']*', size: 36\)),",
    "const PaintedGlyph(\n"
    "              kind: GlyphKind.flame, color: Colors.white, size: 40),",
    'GlyphKind.flame'), 'summary flame')
edit(ONB, sub_once(
    "Text(goal.emoji(), style: const TextStyle(fontSize: 28)),",
    "PaintedGlyph(\n"
    "              kind: _goalGlyph(goal), color: AppColors.halalGreen, size: 32),"),
    'summary goal glyph')

SUMTILE = r'''class _SummaryTile extends StatelessWidget {
  final GlyphKind glyph;
  final String label, value;
  final Color color, card, border;
  final bool isDark;
  const _SummaryTile(this.glyph, this.label, this.value,
    this.color, this.card, this.border, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 0.5),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 22, offset: Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlyphTile(glyph: glyph, color: color, size: 28),
        const Spacer(),
        Text(value, style: TextStyle(
          fontFamily: 'Aligarh', fontSize: 18,
          fontWeight: FontWeight.w900, color: color,
        )),
        Text(label, style: TextStyle(
          fontFamily: 'Aligarh', fontSize: 10,
          color: isDark ? const Color(0xFF7D8590) : const Color(0xFF6B7A8D),
        )),
      ]),
    );
  }
}

'''
edit(ONB, slice_edit(
    'class _SummaryTile extends StatelessWidget {',
    '//  TOP BAR', SUMTILE,
    'class _SummaryTile extends StatelessWidget {\n  final GlyphKind glyph;',
    banner_end=True),
    'summary tile')

# ── goal / activity glyph mapping (end of file) ─────────────────────
MAPS = r'''

// ═══════════════════════════════════════════════════════════
//  GLYPH MAPPING (v56)
// ═══════════════════════════════════════════════════════════
GlyphKind _goalGlyph(FitnessGoal g) => switch (g) {
  FitnessGoal.loseWeight    => GlyphKind.arrowDown,
  FitnessGoal.gainMuscle    => GlyphKind.dumbbell,
  FitnessGoal.maintain      => GlyphKind.balance,
  FitnessGoal.improveHealth => GlyphKind.heart,
  FitnessGoal.ramadanPrep   => GlyphKind.crescent,
};

GlyphKind _activityGlyph(ActivityLevel a) => switch (a) {
  ActivityLevel.sedentary        => GlyphKind.chair,
  ActivityLevel.lightlyActive    => GlyphKind.steps,
  ActivityLevel.moderatelyActive => GlyphKind.pulse,
  ActivityLevel.veryActive       => GlyphKind.flame,
  ActivityLevel.extraActive      => GlyphKind.trophy,
};
'''
def maps_patch(s):
    if 'GlyphKind _goalGlyph' in s: return s
    return s.rstrip('\n') + '\n' + MAPS
edit(ONB, maps_patch, 'goal / activity glyph mapping')


# ════════════════════════════════════════════════════════════════════
#  food_photo_screen.dart
# ════════════════════════════════════════════════════════════════════
FP = 'lib/features/scanner/food_photo_screen.dart'

edit(FP, sub_once(
    "import '../../core/fx6.dart';\n",
    "import '../../core/fx6.dart';\n"
    "import 'package:flutter/services.dart' show HapticFeedback;\n"
    "import '../../core/fx5.dart' show SheenSweep, ScanLoader, VerdictSeal, MacroRing, SealKind;\n"
    "import '../../core/fx8.dart';\n"
    "import '../../core/fx.dart' show ShineButton;\n"
    "import '../../core/motion.dart' show Reveal, PressFx, Motion, CountUp;"),
    'imports')

edit(FP, sub_once(
"""  // Shimmer animation for loading
  late AnimationController _shimmer;
  late Animation<double>   _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _shimmerAnim = Tween(begin: 0.3, end: 1.0).animate(_shimmer);
  }

  @override void dispose() { _shimmer.dispose(); super.dispose(); }""",
"""  // Results already added to the log (v56)
  final Set<int> _addedIdx = {};"""),
    'state: added-set replaces shimmer controller')

edit(FP, sub_once("        _image   = File(xf.path);\n",
                  "        _image   = File(xf.path);\n        _addedIdx.clear();\n"),
     'pick: reset added')
edit(FP, sub_once(
    "    if (mounted) setState(() { _state = AnalysisState.analyzing; _error = null; });",
    "    if (mounted) setState(() { _state = AnalysisState.analyzing; _error = null; _addedIdx.clear(); });"),
    'analyze: reset added')
edit(FP, sub_once(
    "    for (final r in _results) {\n      ref.read(caloriesProvider.notifier).addEntry(",
    "    for (var i = 0; i < _results.length; i++) {\n"
    "      if (_addedIdx.contains(i)) continue;\n"
    "      final r = _results[i];\n"
    "      ref.read(caloriesProvider.notifier).addEntry("),
    'add all: skip already added')
edit(FP, sub_once(
    "    final total = _results.fold(0, (s, r) => s + r.kcal);\n    ScaffoldMessenger",
    "    final total = _results.fold(0, (s, r) => s + r.kcal);\n"
    "    setState(() { for (var i = 0; i < _results.length; i++) { _addedIdx.add(i); } });\n"
    "    ScaffoldMessenger"),
    'add all: mark added')

# ── build() + intro, preview, pick buttons, loading ─────────────────
FP_TOP = r'''  @override
  Widget build(BuildContext context) {
    final lang  = ref.watch(languageProvider); final isAr  = lang =='ar';
    final isDark = ref.watch(themeProvider);
    final bg    = isDark ? AppColors.darkCard : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => isAr ? ar : en;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('تحليل الطعام بـ AI', 'AI Food Analyzer')),
          backgroundColor: AppColors.brandGreen,
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
              tooltip: tLang(lang, 'إدخال سريع بالنص', 'Quick Text Entry', 'Saisie rapide', 'Hızlı Metin Girişi', 'Kemasukan Teks Pantas', 'Entri Teks Cepat'),
              onPressed: () => _showQuickEntrySheet(isAr, isDark),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Intro hero / photo preview ───────────────
            AnimatedSize(
              duration: Motion.base,
              curve: Motion.curve,
              alignment: Alignment.topCenter,
              child: _image == null
                  ? _heroBanner(isAr, isDark)
                  : _imagePreview(bg, isAr),
            ),

            const SizedBox(height: 14),

            // ── Pick buttons ──────────────────────────────
            Row(children: [
              Expanded(child: _pickBtn(
                glyph: GlyphKind.camera, label: t('الكاميرا', 'Camera'),
                color: AppColors.brandGreen,
                onTap: () => _pick(ImageSource.camera),
              )),
              const SizedBox(width: 10),
              Expanded(child: _pickBtn(
                glyph: GlyphKind.gallery, label: t('المعرض', 'Gallery'),
                color: AppColors.waterBlue,
                onTap: () => _pick(ImageSource.gallery),
              )),
            ]),

            const SizedBox(height: 12),

            // ── Analyze button ────────────────────────────
            if (_image != null && _state != AnalysisState.analyzing)
              Reveal(
                offset: 0.2,
                child: ShineButton(
                  label: t('تحليل الآن', 'Analyze Now'),
                  icon: Icons.auto_awesome_rounded,
                  onPressed: _analyze,
                  height: 54,
                ),
              ),

            // ── Loading state ─────────────────────────────
            if (_state == AnalysisState.analyzing)
              _loadingCard(isAr, isDark),

            // ── Error state ───────────────────────────────
            if (_state == AnalysisState.error && _error == '__API_KEY_MISSING__')
              _apiKeyBanner(isAr, isDark),
            if (_state == AnalysisState.error && _error != null && _error != '__API_KEY_MISSING__')
              _errorCard(_error!, isAr, isDark),

            // ── Results ───────────────────────────────────
            if (_state == AnalysisState.done && _results.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (_results.length > 1) _totalSummaryBar(_results, isAr, isDark),
              ..._results.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Reveal(
                  index: e.key,
                  offset: 0.08,
                  child: _resultCard(e.value, isAr, isDark, bg, muted,
                      itemIndex: e.key + 1, totalItems: _results.length),
                ),
              )),
              if (_results.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
                    onPressed: _addedIdx.length >= _results.length ? null : _addAllToTracker,
                    icon: Icon(
                      _addedIdx.length >= _results.length
                          ? Icons.check_rounded : Icons.playlist_add,
                      color: Colors.white),
                    label: Text(
                      '${tLang(lang, 'إضافة كل الأطعمة للعداد', 'Add All Foods to Tracker')} '
                      '(${_results.fold(0,(s,r)=>s+r.kcal)} ${tLang(lang, 'سعرة', 'kcal')})',
                      style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      disabledBackgroundColor: AppColors.brandGreen.withOpacity(0.55),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  )),
                ),
            ],

            const SizedBox(height: 20),

            // ── Tips ──────────────────────────────────────
            _tipsCard(isAr, isDark, bg, muted),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Intro hero ────────────────────────────────────────────
  Widget _heroBanner(bool isAr, bool isDark) {
    const r = 24.0;
    return SheenSweep(
      borderRadius: BorderRadius.circular(r),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandGreen, AppColors.darkGreen],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(r),
          boxShadow: [BoxShadow(
            color: AppColors.brandGreen.withOpacity(0.32),
            blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(children: [
          const FoodCameraHero(height: 150),
          const SizedBox(height: 8),
          Text(
            tLang(lang, 'التقط صورة لطعامك\nوسأحلله فوراً', 'Take a photo of your food\nand I’ll analyze it instantly', 'Prenez une photo de votre repas\net analysez-la instantanément', 'Yemeğinizin fotoğrafını çekin\nve anında analiz edeceğim', 'Ambil foto makanan anda\ndan saya akan menganalisisnya', 'Ambil foto makanan Anda\ndan saya akan menganalisisnya'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Aligarh', fontSize: 18,
                fontWeight: FontWeight.w700, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8, runSpacing: 8,
            children: [
              GlyphChip(glyph: GlyphKind.flame, color: Colors.white,
                  text: tLang(lang, 'سعرات', 'Calories', 'Calories', 'Kalori', 'Kalori', 'Kalori')),
              GlyphChip(glyph: GlyphKind.dumbbell, color: Colors.white,
                  text: tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein')),
              GlyphChip(glyph: GlyphKind.wheat, color: Colors.white,
                  text: tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat')),
              GlyphChip(glyph: GlyphKind.shield, color: Colors.white,
                  text: tLang(lang, 'حكم حلال', 'Halal Check', 'Vérification Halal', 'Helal Kontrol', 'Semakan Halal', 'Cek Halal')),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Photo preview with scan overlay ───────────────────────
  Widget _imagePreview(Color bg, bool isAr) {
    final analyzing = _state == AnalysisState.analyzing;
    final done = _state == AnalysisState.done && _results.isNotEmpty;
    return Container(
      height: 270,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(
          color: (analyzing ? AppColors.halalGreen : Colors.black)
              .withOpacity(analyzing ? 0.30 : 0.14),
          blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(fit: StackFit.expand, children: [
          Image.file(_image!, fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) =>
                const Icon(Icons.broken_image, color: Colors.grey, size: 48)),
          AnimatedSwitcher(
            duration: Motion.base,
            child: analyzing
                ? const PhotoScanOverlay(key: ValueKey('scan'))
                : const SizedBox.expand(key: ValueKey('idle')),
          ),
          PositionedDirectional(
            start: 12, bottom: 12,
            child: AnimatedSwitcher(
              duration: Motion.quick,
              child: analyzing
                  ? _photoPill(
                      key: const ValueKey('busy'), busy: true,
                      text: tLang(lang, 'جارٍ التحليل…', 'Analyzing…', 'Analyse en cours…', 'Analiz ediliyor…', 'Menganalisis…', 'Menganalisis…'))
                  : (done
                      ? _photoPill(
                          key: const ValueKey('done'), busy: false,
                          text: tLang(lang, 'تم التحليل', 'Analysis complete', 'Analyse terminée', 'Analiz tamamlandı', 'Analisis selesai', 'Analisis selesai'))
                      : const SizedBox.shrink(key: ValueKey('none'))),
            ),
          ),
          PositionedDirectional(
            top: 10, end: 10,
            child: GestureDetector(
              onTap: analyzing ? null : () => setState(() {
                _image = null; _results = []; _error = null;
                _state = AnalysisState.idle; _addedIdx.clear();
              }),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.50),
                  border: Border.all(color: Colors.white.withOpacity(0.16)),
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _photoPill({Key? key, required bool busy, required String text}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.58),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (busy)
          const ScanLoader(color: AppColors.halalGreen, width: 40, height: 14)
        else
          const PaintedGlyph(kind: GlyphKind.check, color: AppColors.halalGreen, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
            fontWeight: FontWeight.w700, color: Colors.white)),
      ]),
    );
  }

  Widget _pickBtn({required GlyphKind glyph, required String label, required Color color, required VoidCallback onTap}) {
    return PressFx(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [color.withOpacity(0.18), color.withOpacity(0.05)],
          ),
          border: Border.all(color: color.withOpacity(0.38), width: 1.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          PaintedGlyph(kind: glyph, color: color, size: 26),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
              fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }

  Widget _loadingCard(bool isAr, bool isDark) {
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandGreen.withOpacity(0.28)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12)],
      ),
      child: Column(children: [
        const ScanLoader(color: AppColors.brandGreen),
        const SizedBox(height: 14),
        StageText(
          lines: [
            tLang(lang, 'جارٍ التعرّف على الطعام…', 'Identifying the food…', 'Identification du plat…', 'Yemek tanınıyor…', 'Mengenal pasti makanan…', 'Mengenali makanan…'),
            tLang(lang, 'تقدير الحصة والوزن…', 'Estimating portion size…', 'Estimation de la portion…', 'Porsiyon tahmin ediliyor…', 'Menganggar saiz hidangan…', 'Memperkirakan porsi…'),
            tLang(lang, 'حساب السعرات والماكروز…', 'Calculating calories and macros…', 'Calcul des calories et macros…', 'Kalori ve makrolar hesaplanıyor…', 'Mengira kalori dan makro…', 'Menghitung kalori dan makro…'),
            tLang(lang, 'فحص حالة الحلال…', 'Checking halal status…', 'Vérification halal…', 'Helal durumu kontrol ediliyor…', 'Menyemak status halal…', 'Memeriksa status halal…'),
          ],
          style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.brandGreen),
        ),
        const SizedBox(height: 6),
        Text(
          tLang(lang, 'عادةً يستغرق بضع ثوانٍ', 'Usually takes a few seconds', 'Prend généralement quelques secondes', 'Genellikle birkaç saniye sürer', 'Biasanya mengambil beberapa saat', 'Biasanya hanya beberapa detik'),
          style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted),
        ),
      ]),
    );
  }

'''
edit(FP, slice_edit(
    "  @override\n  Widget build(BuildContext context) {\n"
    "    final lang  = ref.watch(languageProvider); final isAr  = lang =='ar';",
    "  Widget _apiKeyBanner(bool isAr, bool isDark) {",
    FP_TOP, 'Widget _heroBanner('),
    'build, hero, preview, pick buttons, loading')

# ── error glyphs ────────────────────────────────────────────────────
edit(FP, rx_once(r"const (?:Text\('[^']*', style: TextStyle\(fontSize: 20\)\)|EmojiIcon\('[^']*', size: 20\)),",
    "const PaintedGlyph(kind: GlyphKind.alert, color: AppColors.doubtOrange, size: 22),",
    'GlyphKind.alert, color: AppColors.doubtOrange'), 'api key banner glyph')
edit(FP, rx_once(r"const (?:Text\('[^']*', style: TextStyle\(fontSize: 22\)\)|EmojiIcon\('[^']*', size: 22\)),",
    "const PaintedGlyph(kind: GlyphKind.alert, color: AppColors.haramRed, size: 24),",
    'GlyphKind.alert, color: AppColors.haramRed'), 'error card glyph')

# ── total bar + result card ─────────────────────────────────────────
FP_RESULT = r'''  // ── Helpers ────────────────────────────────────
  SealKind _sealKind(HalalStatus s) {
    switch (s) {
      case HalalStatus.halal:    return SealKind.halal;
      case HalalStatus.doubtful: return SealKind.doubtful;
      case HalalStatus.haram:    return SealKind.haram;
      case HalalStatus.unknown:  return SealKind.unknown;
    }
  }

  String _g(double v) =>
      v == v.roundToDouble() ? '${v.round()}g' : '${v.toStringAsFixed(1)}g';

  // ── Total summary bar ──────────────────────────
  Widget _totalSummaryBar(List<FoodPhotoResult> items, bool isAr, bool isDark) {
    final totalKcal  = items.fold(0,    (s, r) => s + r.kcal);
    final totalProt  = items.fold(0.0,  (s, r) => s + r.proteinG);
    final totalCarbs = items.fold(0.0,  (s, r) => s + r.carbsG);
    final totalFat   = items.fold(0.0,  (s, r) => s + r.fatG);
    final eP = totalProt * 4, eC = totalCarbs * 4, eF = totalFat * 9;
    final eT = (eP + eC + eF) <= 0 ? 1.0 : (eP + eC + eF);
    return Reveal(
      offset: 0.08,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [
              AppColors.accentGold.withOpacity(0.18),
              AppColors.accentGold.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.accentGold.withOpacity(0.45))),
        child: Column(children: [
          Row(children: [
            const PaintedGlyph(kind: GlyphKind.flame, color: AppColors.accentGold, size: 30),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tLang(lang, 'مجموع الوجبة', 'Meal total', 'Total du repas', 'Öğün toplamı', 'Jumlah hidangan', 'Total hidangan'),
                style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                    color: AppColors.accentGold)),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                CountUp(value: totalKcal,
                  style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w900,
                      fontSize: 30, color: AppColors.accentGold, height: 1.1)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(tLang(lang, 'سعرة', 'kcal'),
                    style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                        color: AppColors.accentGold)),
                ),
              ]),
            ])),
            GlyphChip(
              glyph: GlyphKind.check, color: AppColors.accentGold,
              text: '${items.length} ${isAr ? "صنف" : "items"}'),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            MacroRing(value: _g(totalProt), pct: eP / eT, color: AppColors.halalGreen, size: 60,
                label: tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein')),
            MacroRing(value: _g(totalCarbs), pct: eC / eT, color: AppColors.waterBlue, size: 60,
                label: tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat')),
            MacroRing(value: _g(totalFat), pct: eF / eT, color: AppColors.accentGold, size: 60,
                label: tLang(lang, 'دهون', 'Fat', 'Lipides', 'Yağ', 'Lemak', 'Lemak')),
          ]),
        ]),
      ),
    );
  }

  Widget _resultCard(FoodPhotoResult r, bool isAr, bool isDark, Color bg, Color muted,
      {int itemIndex = 1, int totalItems = 1}) {
    final col     = _statusColor(r.halalStatus);
    final name    = isAr ? r.foodName : r.foodNameEn;
    final label   = isAr ? r.halalStatus.label : r.halalStatus.labelEn;
    final expl    = isAr ? r.halalExplanation : r.halalExplanationEn;
    final tip     = (isAr ? r.tipNote : r.tipNoteEn) ?? '';
    final added   = _addedIdx.contains(itemIndex - 1);
    final conf    = r.confidence.clamp(0.0, 1.0).toDouble();
    final eP = r.proteinG * 4, eC = r.carbsG * 4, eF = r.fatG * 9;
    final eT = (eP + eC + eF) <= 0 ? 1.0 : (eP + eC + eF);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color.lerp(bg, col, isDark ? 0.16 : 0.10)!, bg],
        ),
        border: Border.all(color: col.withOpacity(0.45), width: 1.3),
        boxShadow: [BoxShadow(color: col.withOpacity(0.18), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Verdict + name + confidence ────────────────
          Row(children: [
            VerdictSeal(kind: _sealKind(r.halalStatus), color: col, size: 74),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (totalItems > 1)
                Text('$itemIndex / $totalItems',
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
              Text(name, style: const TextStyle(fontFamily: 'Aligarh',
                  fontWeight: FontWeight.w900, fontSize: 19)),
              Text(label, style: TextStyle(fontFamily: 'Aligarh',
                  fontWeight: FontWeight.w800, fontSize: 14, color: col)),
            ])),
            MacroRing(
              value: '${(conf * 100).round()}%',
              label: tLang(lang, 'دقة', 'conf.', 'conf.', 'conf.', 'conf.', 'conf.'),
              pct: conf, color: AppColors.accentGold, size: 52),
          ]),

          if (expl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(expl, style: TextStyle(fontFamily: 'Aligarh',
                  fontSize: 12, color: muted, height: 1.45)),
            ),

          const Divider(height: 26),

          // ── Calories ───────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const PaintedGlyph(kind: GlyphKind.flame, color: AppColors.haramRed, size: 36),
            const SizedBox(width: 10),
            CountUp(value: r.kcal,
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 54,
                  fontWeight: FontWeight.w900, color: AppColors.haramRed, height: 1)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tLang(lang, 'سعرة حرارية', 'kcal', 'kcal', 'kcal', 'kcal', 'kcal'),
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                    fontWeight: FontWeight.w700, color: muted)),
              if (r.portionSize.isNotEmpty)
                Text(r.portionSize,
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 11, color: muted)),
            ]),
          ]),

          const SizedBox(height: 16),

          // ── Macro share rings ──────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            MacroRing(value: _g(r.proteinG), pct: eP / eT, color: AppColors.halalGreen, size: 64,
                label: tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein', 'Protein', 'Protein')),
            MacroRing(value: _g(r.carbsG), pct: eC / eT, color: AppColors.waterBlue, size: 64,
                label: tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides', 'Karbonhidrat', 'Karbohidrat', 'Karbohidrat')),
            MacroRing(value: _g(r.fatG), pct: eF / eT, color: AppColors.accentGold, size: 64,
                label: tLang(lang, 'دهون', 'Fat', 'Lipides', 'Yağ', 'Lemak', 'Lemak')),
          ]),
          const SizedBox(height: 6),
          Text(
            tLang(lang, 'حصة كل عنصر من السعرات', 'Share of calories from each', 'Part des calories de chacun', 'Kalorideki payı', 'Bahagian kalori', 'Porsi kalori'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 9, color: muted)),

          // ── Practical tip ──────────────────────────────
          if (tip.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.30)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const PaintedGlyph(kind: GlyphKind.bulb, color: AppColors.accentGold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tip, style: TextStyle(fontFamily: 'Aligarh',
                      fontSize: 11, height: 1.5, color: muted))),
                ]),
              ),
            ),

          // ── Ingredients ────────────────────────────────
          if (r.ingredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tLang(lang, 'المكونات الرئيسية', 'Main ingredients', 'Ingrédients principaux', 'Ana malzemeler', 'Bahan-bahan utama', 'Bahan-bahan utama'),
                  style: const TextStyle(fontFamily: 'Aligarh', fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: r.ingredients.map((ing) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.brandGreen.withOpacity(0.32), width: 0.8),
                  ),
                  child: Text(ing, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                      fontWeight: FontWeight.w600, color: AppColors.halalGreen)),
                )).toList()),
              ]),
            ),

          const SizedBox(height: 16),

          // ── Actions ────────────────────────────────────
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: added ? null : () {
                HapticFeedback.mediumImpact();
                _addToTracker(r);
                setState(() => _addedIdx.add(itemIndex - 1));
              },
              icon: Icon(added ? Icons.check_rounded : Icons.add_rounded,
                  color: Colors.white, size: 18),
              label: Text(
                added
                  ? tLang(lang, 'أُضيف', 'Added', 'Ajouté', 'Eklendi', 'Ditambah', 'Ditambahkan')
                  : tLang(lang, 'أضف للعداد', 'Add to Tracker', 'Ajouter au suivi', 'Takibe Ekle', 'Tambah ke Penjejak', 'Tambah ke Pelacak'),
                style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white,
                    fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                disabledBackgroundColor: AppColors.brandGreen.withOpacity(0.55),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _image = null; _results = []; _state = AnalysisState.idle; _addedIdx.clear();
              }),
              icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.brandGreen),
              label: Text(tLang(lang, 'جديد', 'New', 'Nouveau', 'Yeni', 'Baru', 'Baru'),
                style: const TextStyle(fontFamily: 'Aligarh', color: AppColors.brandGreen)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                side: const BorderSide(color: AppColors.brandGreen),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ]),

          const SizedBox(height: 12),
          Text(
            tLang(lang, '* النتائج تقديرية من Claude AI — دقة ٧٠-٩٠٪ حسب وضوح الصورة', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity', '* Results are AI estimates — 70-90% accuracy depending on photo clarity'),
            style: TextStyle(fontFamily: 'Aligarh', fontSize: 9, color: muted, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

'''
edit(FP, slice_edit(
    "  // ── Total summary bar",
    "  // ── Quick Entry sheet launcher", FP_RESULT,
    'SealKind _sealKind(HalalStatus s)'),
    'total bar + result card')

# ── tips ────────────────────────────────────────────────────────────
FP_TIPS = r'''  Widget _tipsCard(bool isAr, bool isDark, Color bg, Color muted) {
    final tips = isAr
        ? ['التقط الصورة من فوق مباشرةً', 'استخدم إضاءة جيدة', 'اجعل الطبق يملأ معظم الصورة', 'تجنب الصور المعتمة أو المضببة', 'الأطعمة المفردة تعطي نتائج أدق']
        : ['Take the photo from directly above', 'Use good lighting', 'Fill the frame with the food', 'Avoid dark or blurry photos', 'Single food items give more accurate results'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF), width: 0.6),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PaintedGlyph(kind: GlyphKind.bulb, color: AppColors.accentGold, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(
            tLang(lang, 'نصائح للحصول على نتائج أدق', 'Tips for better results', 'Conseils pour de meilleurs résultats', 'Daha iyi sonuçlar için ipuçları', 'Petua untuk hasil lebih baik', 'Tips untuk hasil lebih baik'),
            style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
        const SizedBox(height: 12),
        for (var i = 0; i < tips.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentGold.withOpacity(0.16),
                  border: Border.all(color: AppColors.accentGold.withOpacity(0.4), width: 0.8),
                ),
                child: Center(child: Text('${i + 1}', style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 11, fontWeight: FontWeight.w800,
                    color: AppColors.accentGold))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(tips[i], style: TextStyle(fontFamily: 'Aligarh',
                    fontSize: 12, color: muted, height: 1.4)),
              )),
            ]),
          ),
      ]),
    );
  }

'''
edit(FP, slice_edit(
    "  Widget _tipsCard(bool isAr, bool isDark, Color bg, Color muted) {",
    "  Color _statusColor(HalalStatus s) {", FP_TIPS,
    'final tips = isAr\n        ? [\'التقط'),
    'tips card')

edit('pubspec.yaml', sub_once('version: 1.13.0+27', 'version: 1.14.0+28'),
     'version 1.14.0+28')


# ════════════════════════════════════════════════════════════════════
#  sanity
# ════════════════════════════════════════════════════════════════════
print('\n== sanity: brace balance + leftovers ==')
bad = 0
for p in ['lib/core/fx8.dart', ONB, FP]:
    if not os.path.exists(path(p)): continue
    raw = open(path(p), encoding='utf-8').read()
    t = re.sub(r"//[^\n]*", '', raw)
    t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
    t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
    for a, b in ('{}', '()', '[]'):
        if t.count(a) != t.count(b):
            bad += 1
            print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
    if p == ONB:
        for left in ('_enterCtrl', '_enterFade', '_NumberSlider(', "emoji: '"):
            if left in raw:
                bad += 1; print('  LEFTOVER  ', p, left)
    if p == FP:
        for left in ('_shimmerAnim', '_badge(', 'CircularProgressIndicator(color: AppColors.accentGold'):
            if left in raw:
                bad += 1; print('  LEFTOVER  ', p, left)
print('  all clear' if not bad else '  !! fix the items above before building')
print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git add -A && git commit -m "v56: onboarding polish + food photo" && git push')
