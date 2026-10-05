// ════════════════════════════════════════════════════════════════════
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
