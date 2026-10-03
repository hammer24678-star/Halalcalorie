#!/usr/bin/env python3
"""
patch_v48_scanner_lens.py
=========================
HalalCalorie v48 - Scanner Lens. Run from the repo root:

    python3 patch_v48_scanner_lens.py

Needs v47 applied. Safe to run twice; no new dependencies.

NEW  lib/core/fx5.dart
     ScanViewfinder   dimmed camera with a cut-out frame, breathing corner
                      brackets and a sweeping laser with a glow trail.
                      Idle -> brackets contract while a product is looked up
                      -> locks in the verdict colour with a flash.
     VerdictSeal      the result stamp, drawn in code: halal = ring draws
                      then a check strokes in with a spark burst; haram =
                      cross that shakes in; doubtful = wobbling exclamation;
                      unknown = question mark with an orbiting dot.
     MacroRing        animated ring + counted value for kcal / protein /
                      carbs / fat (replaces the four emoji).
     ScanLoader       barcode bars that ripple while the lookup runs
                      (replaces the stock spinner).
     ShutterGlyph     animated camera icon for the AI Food Analyzer card.
     SheenSweep       a soft light sweep across a card.

EDITED  barcode_scanner_widget.dart
     Torch and camera-flip buttons on the camera.

EDITED  scanner_screen.dart   (scan logic is untouched)
     * result and loader now appear right under the camera. They used to land
       below the demo-product grid, off screen, after a camera scan.
     * haptic tick the moment a code is read
     * quota chip with three dots instead of "Left: 2/3"
     * live hint pill on the camera (align / analyzing / verdict)
     * result card: verdict seal, certificate chips, macro rings, an
       "Added" state on the log button
     * status emoji replaced by painted icons in the grid and history
     * manual entry: numeric keyboard, search key submits
     * staggered entrance on the page

pubspec  1.6.0+19 -> 1.7.0+20
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


print('== v48 scanner lens ==')

# ════════════════════════════════════════════════════════════════════
#  lib/core/fx5.dart
# ════════════════════════════════════════════════════════════════════
NEW_FILES = {'lib/core/fx5.dart': r'''// ════════════════════════════════════════════════════════════════════
//  fx5.dart — Scanner Lens (v48)
//
//    ScanViewfinder  camera overlay: cut-out frame, brackets, laser
//    VerdictSeal     animated halal / doubtful / haram / unknown stamp
//    MacroRing       animated ring with a value in the middle
//    ScanLoader      rippling barcode bars
//    ShutterGlyph    animated camera icon
//    SheenSweep      light sweep across a card
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

double _seg(double p, double a, double b) =>
    ((p - a) / (b - a)).clamp(0.0, 1.0).toDouble();

// ════════════════════════════════════════════════════════════════════
//  ScanViewfinder
// ════════════════════════════════════════════════════════════════════

enum ViewfinderMode { idle, working, locked }

class ScanViewfinder extends StatefulWidget {
  final ViewfinderMode mode;
  final Color color;
  final Color lockColor;
  const ScanViewfinder({
    super.key,
    this.mode = ViewfinderMode.idle,
    this.color = const Color(0xFF78E08E),
    this.lockColor = const Color(0xFF3FB950),
  });

  @override
  State<ScanViewfinder> createState() => _ScanViewfinderState();
}

class _ScanViewfinderState extends State<ScanViewfinder>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1.0,
  );

  @override
  void didUpdateWidget(ScanViewfinder old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode && widget.mode == ViewfinderMode.locked) {
      _flash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0.0,
            end: widget.mode == ViewfinderMode.working ? 1.0 : 0.0,
          ),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          builder: (_, work, __) => AnimatedBuilder(
            animation: Listenable.merge([_c, _flash]),
            builder: (_, __) => SizedBox.expand(
              child: CustomPaint(
                painter: _VfPainter(
                  t: _c.value,
                  flash: _flash.value,
                  work: work,
                  locked: widget.mode == ViewfinderMode.locked,
                  color: widget.color,
                  lockColor: widget.lockColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VfPainter extends CustomPainter {
  final double t, flash, work;
  final bool locked;
  final Color color, lockColor;
  const _VfPainter({
    required this.t,
    required this.flash,
    required this.work,
    required this.locked,
    required this.color,
    required this.lockColor,
  });

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final hw = w * 0.80, hh = h * 0.50;
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w / 2, h / 2), width: hw, height: hh),
      const Radius.circular(18),
    );
    final col = locked ? lockColor : color;

    // dim everything outside the frame
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & s),
      Path()..addRRect(hole),
    );
    c.drawPath(dim, Paint()..color = Colors.black.withOpacity(0.42));

    // lock flash
    if (locked && flash < 1.0) {
      c.drawRRect(
        hole,
        Paint()..color = lockColor.withOpacity(0.30 * (1 - flash)),
      );
    }

    // laser
    if (!locked) {
      c.save();
      c.clipRRect(hole);
      final u = 0.5 - 0.5 * math.cos(2 * math.pi * t);
      final y = hole.top + 6 + (hh - 12) * u;
      final down = math.sin(2 * math.pi * t) >= 0;
      final tt = down ? y - 34 : y;
      final tb = down ? y : y + 34;
      final fade = 1.0 - 0.35 * work;
      c.drawRect(
        Rect.fromLTRB(hole.left, tt, hole.right, tb),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: down
                ? [col.withOpacity(0.0), col.withOpacity(0.32 * fade)]
                : [col.withOpacity(0.32 * fade), col.withOpacity(0.0)],
          ).createShader(Rect.fromLTRB(hole.left, tt, hole.right, tb)),
      );
      final lineRect = Rect.fromLTWH(hole.left, y - 1, hw, 2);
      c.drawLine(
        Offset(hole.left + 8, y),
        Offset(hole.right - 8, y),
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = col.withOpacity(0.55 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      c.drawLine(
        Offset(hole.left + 8, y),
        Offset(hole.right - 8, y),
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [
            col.withOpacity(0.0),
            col.withOpacity(fade),
            col.withOpacity(0.0),
          ], stops: const [0.0, 0.5, 1.0])
              .createShader(lineRect),
      );
      c.restore();
    }

    // corner brackets
    final inset = 2.0 + 8.0 * work + 1.6 * math.sin(2 * math.pi * t * 2);
    final r = hole.outerRect.deflate(inset);
    const L = 30.0, rad = 16.0;
    final br = Path()
      // top-left
      ..moveTo(r.left, r.top + L)
      ..lineTo(r.left, r.top + rad)
      ..arcTo(Rect.fromLTWH(r.left, r.top, rad * 2, rad * 2), math.pi,
          math.pi / 2, false)
      ..lineTo(r.left + L, r.top)
      // top-right
      ..moveTo(r.right - L, r.top)
      ..lineTo(r.right - rad, r.top)
      ..arcTo(Rect.fromLTWH(r.right - rad * 2, r.top, rad * 2, rad * 2),
          -math.pi / 2, math.pi / 2, false)
      ..lineTo(r.right, r.top + L)
      // bottom-right
      ..moveTo(r.right, r.bottom - L)
      ..lineTo(r.right, r.bottom - rad)
      ..arcTo(
          Rect.fromLTWH(
              r.right - rad * 2, r.bottom - rad * 2, rad * 2, rad * 2),
          0,
          math.pi / 2,
          false)
      ..lineTo(r.right - L, r.bottom)
      // bottom-left
      ..moveTo(r.left + L, r.bottom)
      ..lineTo(r.left + rad, r.bottom)
      ..arcTo(Rect.fromLTWH(r.left, r.bottom - rad * 2, rad * 2, rad * 2),
          math.pi / 2, math.pi / 2, false)
      ..lineTo(r.left, r.bottom - L);

    if (locked) {
      c.drawPath(
        br,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = lockColor.withOpacity(0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    c.drawPath(
      br,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = col,
    );
  }

  @override
  bool shouldRepaint(_VfPainter old) =>
      old.t != t ||
      old.flash != flash ||
      old.work != work ||
      old.locked != locked ||
      old.color != color ||
      old.lockColor != lockColor;
}

// ════════════════════════════════════════════════════════════════════
//  VerdictSeal
// ════════════════════════════════════════════════════════════════════

enum SealKind { halal, doubtful, haram, unknown }

class VerdictSeal extends StatefulWidget {
  final SealKind kind;
  final Color color;
  final double size;
  const VerdictSeal({
    super.key,
    required this.kind,
    required this.color,
    this.size = 76,
  });

  @override
  State<VerdictSeal> createState() => _VerdictSealState();
}

class _VerdictSealState extends State<VerdictSeal>
    with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final AnimationController _amb = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _in.dispose();
    _amb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_in, _amb]),
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _SealPainter(
            kind: widget.kind,
            color: widget.color,
            p: _in.value,
            amb: _amb.value,
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  final SealKind kind;
  final Color color;
  final double p, amb;
  const _SealPainter({
    required this.kind,
    required this.color,
    required this.p,
    required this.amb,
  });

  void _stroke(Canvas c, Path path, double g, Paint paint) {
    for (final m in path.computeMetrics()) {
      c.drawPath(m.extractPath(0, m.length * g), paint);
    }
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final ctr = Offset(w / 2, w / 2);
    final R = w * 0.40;

    final disc = Curves.easeOutBack.transform(_seg(p, 0.0, 0.35));
    c.drawCircle(ctr, R * disc, Paint()..color = color.withOpacity(0.14));

    // ambient halo
    final halo = _seg(p, 0.6, 1.0);
    if (halo > 0) {
      c.drawCircle(
        ctr,
        R * (1.0 + 0.28 * amb),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withOpacity(0.28 * (1 - amb) * halo),
      );
    }

    // ring
    final ring = Curves.easeOutCubic.transform(_seg(p, 0.05, 0.55));
    if (ring > 0) {
      c.drawArc(
        Rect.fromCircle(center: ctr, radius: R),
        -math.pi / 2,
        2 * math.pi * ring,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    final g = Curves.easeOutCubic.transform(_seg(p, 0.45, 0.85));
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    switch (kind) {
      case SealKind.halal:
        final check = Path()
          ..moveTo(w * 0.31, w * 0.52)
          ..lineTo(w * 0.45, w * 0.65)
          ..lineTo(w * 0.70, w * 0.37);
        _stroke(c, check, g, mark);
        final u = _seg(p, 0.5, 1.0);
        if (u > 0 && u < 1) {
          for (var i = 0; i < 10; i++) {
            final a = i * 2 * math.pi / 10 + 0.3;
            final rr = R * (1.05 + 0.55 * Curves.easeOut.transform(u));
            c.drawCircle(
              ctr + Offset(math.cos(a) * rr, math.sin(a) * rr),
              2.2 * (1 - u) + 0.4,
              Paint()..color = color.withOpacity(1 - u),
            );
          }
        }
        break;

      case SealKind.haram:
        c.save();
        c.translate(math.sin(g * math.pi * 7) * 3 * (1 - g), 0);
        final x1 = Path()
          ..moveTo(w * 0.36, w * 0.36)
          ..lineTo(w * 0.64, w * 0.64);
        final x2 = Path()
          ..moveTo(w * 0.64, w * 0.36)
          ..lineTo(w * 0.36, w * 0.64);
        _stroke(c, x1, g, mark);
        _stroke(c, x2, g, mark);
        c.restore();
        break;

      case SealKind.doubtful:
        c.save();
        c.translate(ctr.dx, ctr.dy);
        c.rotate(math.sin(g * math.pi * 5) * 0.12 * (1 - g));
        c.translate(-ctr.dx, -ctr.dy);
        final bar = Path()
          ..moveTo(w * 0.5, w * 0.30)
          ..lineTo(w * 0.5, w * 0.54);
        _stroke(c, bar, g, mark);
        if (g > 0.6) {
          c.drawCircle(
            Offset(w * 0.5, w * 0.67),
            2.6 * _seg(g, 0.6, 1.0),
            Paint()..color = color,
          );
        }
        c.restore();
        break;

      case SealKind.unknown:
        final tp = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              color: color.withOpacity(g),
              fontSize: w * 0.42,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, ctr - Offset(tp.width / 2, tp.height / 2));
        if (g > 0.5) {
          final a = 2 * math.pi * amb;
          c.drawCircle(
            ctr + Offset(math.cos(a) * R, math.sin(a) * R),
            2.6,
            Paint()..color = color,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.p != p || old.amb != amb || old.color != color || old.kind != kind;
}

// ════════════════════════════════════════════════════════════════════
//  MacroRing
// ════════════════════════════════════════════════════════════════════

class MacroRing extends StatelessWidget {
  final String value, label;
  final double pct;
  final Color color;
  final double size;
  const MacroRing({
    super.key,
    required this.value,
    required this.label,
    required this.pct,
    required this.color,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(
              begin: 0.0, end: pct.clamp(0.0, 1.0).toDouble()),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutCubic,
          builder: (_, p, __) => CustomPaint(
            painter: _RingPainter(p: p, color: color),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(size * 0.2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: color),
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  final Color color;
  const _RingPainter({required this.p, required this.color});

  @override
  void paint(Canvas c, Size s) {
    const sw = 4.6;
    final rect = Rect.fromCircle(
      center: Offset(s.width / 2, s.height / 2),
      radius: s.width / 2 - sw / 2,
    );
    c.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..color = color.withOpacity(0.16),
    );
    if (p > 0.004) {
      c.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * p,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.p != p || old.color != color;
}

// ════════════════════════════════════════════════════════════════════
//  ScanLoader
// ════════════════════════════════════════════════════════════════════

class ScanLoader extends StatefulWidget {
  final Color color;
  final double width, height;
  const ScanLoader({
    super.key,
    required this.color,
    this.width = 150,
    this.height = 46,
  });

  @override
  State<ScanLoader> createState() => _ScanLoaderState();
}

class _ScanLoaderState extends State<ScanLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _LoaderPainter(t: _c.value, color: widget.color),
        ),
      ),
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final double t;
  final Color color;
  const _LoaderPainter({required this.t, required this.color});

  @override
  void paint(Canvas c, Size s) {
    const n = 21;
    final slot = s.width / n;
    for (var i = 0; i < n; i++) {
      final base = 0.35 + 0.65 * (((i * 7919) % 13) / 12.0);
      final wave = 0.5 + 0.5 * math.sin(2 * math.pi * (t - i / n * 1.3));
      final bh = s.height * (0.18 + 0.82 * base * (0.35 + 0.65 * wave));
      final bw = slot * (i % 3 == 0 ? 0.62 : 0.4);
      final cx = slot * i + slot / 2;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, s.height / 2), width: bw, height: bh),
          Radius.circular(bw / 2),
        ),
        Paint()..color = color.withOpacity(0.30 + 0.70 * wave),
      );
    }
  }

  @override
  bool shouldRepaint(_LoaderPainter old) => old.t != t || old.color != color;
}

// ════════════════════════════════════════════════════════════════════
//  ShutterGlyph
// ════════════════════════════════════════════════════════════════════

class ShutterGlyph extends StatefulWidget {
  final double size;
  const ShutterGlyph({super.key, this.size = 44});

  @override
  State<ShutterGlyph> createState() => _ShutterGlyphState();
}

class _ShutterGlyphState extends State<ShutterGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size.square(widget.size),
          painter: _ShutterPainter(t: _c.value),
        ),
      ),
    );
  }
}

class _ShutterPainter extends CustomPainter {
  final double t;
  const _ShutterPainter({required this.t});

  double _ph(double k) => 2 * math.pi * t * k;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withOpacity(0.92);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.30, w * 0.80, h * 0.54),
      Radius.circular(w * 0.14),
    );
    c.drawRRect(body, Paint()..color = Colors.white.withOpacity(0.16));
    c.drawRRect(body, stroke);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.34, h * 0.19, w * 0.22, h * 0.13),
        Radius.circular(w * 0.05),
      ),
      stroke,
    );

    final ctr = Offset(w * 0.5, h * 0.57);
    final r = w * 0.19;
    c.drawCircle(ctr, r, stroke);
    c.drawCircle(
      ctr,
      r * (0.52 + 0.10 * math.sin(_ph(24))),
      Paint()..color = Colors.white.withOpacity(0.88),
    );

    final u = (t * 24) % 1.0;
    c.drawCircle(
      ctr,
      r * (1.0 + 0.9 * u),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(0.4 * (1 - u)),
    );

    const stars = [Offset(0.84, 0.16), Offset(0.14, 0.14), Offset(0.95, 0.46)];
    for (var i = 0; i < stars.length; i++) {
      final o = Offset(w * stars[i].dx, h * stars[i].dy);
      final a = 0.25 + 0.75 * math.pow(math.sin(_ph(18.0 + i * 6) + i * 2), 2);
      final L = 2.0 + i * 0.4;
      final sp = Paint()
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(a.toDouble());
      c.drawLine(o - Offset(L, 0), o + Offset(L, 0), sp);
      c.drawLine(o - Offset(0, L), o + Offset(0, L), sp);
    }
  }

  @override
  bool shouldRepaint(_ShutterPainter old) => old.t != t;
}

// ════════════════════════════════════════════════════════════════════
//  SheenSweep
// ════════════════════════════════════════════════════════════════════

class SheenSweep extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  const SheenSweep({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  @override
  State<SheenSweep> createState() => _SheenSweepState();
}

class _SheenSweepState extends State<SheenSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final u = Curves.easeInOut
                    .transform((_c.value / 0.4).clamp(0.0, 1.0).toDouble());
                final x0 = -2.2 + 3.6 * u;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(x0, -0.6),
                      end: Alignment(x0 + 0.9, 0.6),
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.20),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ]);
  }
}
'''}
for p, c in NEW_FILES.items():
    write(p, c)


# ════════════════════════════════════════════════════════════════════
#  barcode_scanner_widget.dart  -  torch + flip buttons
# ════════════════════════════════════════════════════════════════════
BARCODE = 'lib/features/scanner/barcode_scanner_widget.dart'

BARCODE_SRC = r'''// barcode_scanner_widget.dart — HalalCalorie v1.0 (v48: torch + flip)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final bool isActive;
  final void Function(String barcode) onDetected;
  const BarcodeScannerWidget({
    super.key, required this.isActive, required this.onDetected});
  @override State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  late MobileScannerController _ctrl;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) widget.onDetected(barcode!.rawValue!);
  }

  Future<void> _toggleTorch() async {
    try {
      await _ctrl.toggleTorch();
      if (mounted) setState(() => _torch = !_torch);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Future<void> _flip() async {
    try {
      await _ctrl.switchCamera();
      if (mounted) setState(() => _torch = false);
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  Widget _roundBtn(IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 38, height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.accentGold.withOpacity(0.92)
              : Colors.black.withOpacity(0.50),
          border: Border.all(
              color: Colors.white.withOpacity(active ? 0.0 : 0.16)),
        ),
        child: Icon(icon, size: 20,
            color: active ? Colors.black : Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();
    return Stack(fit: StackFit.expand, children: [
      MobileScanner(
        controller: _ctrl,
        onDetect: _onDetect,
        errorBuilder: (context, err, _) {
          if (err.errorCode == MobileScannerErrorCode.permissionDenied) {
            return Center(child: Text(
              'Camera permission denied',
              style: const TextStyle(color: AppColors.haramRed, fontFamily: 'Aligarh'),
            ));
          }
          return const Center(child: Text('Camera error',
            style: TextStyle(color: Colors.white)));
        },
      ),
      Positioned(
        top: 12, left: 12,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _roundBtn(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              _torch, _toggleTorch),
          const SizedBox(width: 8),
          _roundBtn(Icons.cameraswitch_rounded, false, _flip),
        ]),
      ),
    ]);
  }
}
'''

def barcode_patch(s):
    if 'toggleTorch' in s: return s
    if 'class BarcodeScannerWidget' not in s: return None
    return BARCODE_SRC
edit(BARCODE, barcode_patch, 'torch + flip buttons')


# ════════════════════════════════════════════════════════════════════
#  scanner_screen.dart
# ════════════════════════════════════════════════════════════════════
SCN = 'lib/features/scanner/scanner_screen.dart'

edit(SCN, sub_once("import 'dart:convert';",
     "import 'dart:convert';\nimport 'package:flutter/services.dart';\n"
     "import '../../core/motion.dart';\nimport '../../core/fx5.dart';"),
     'imports')

edit(SCN, sub_once("  bool _limitDialogOpen = false;",
     "  bool _limitDialogOpen = false;\n  String? _loggedKey; // result already added to the log (v48)"),
     'logged-state field')

edit(SCN, sub_once("    _lastBarcode = barcode;\n    _scan(barcode);",
     "    _lastBarcode = barcode;\n    HapticFeedback.mediumImpact();\n    _scan(barcode);"),
     'haptic on read')

TAIL = r'''  @override
  Widget build(BuildContext context) {
    final scan      = ref.watch(scanProvider);
    final isPremium = ref.watch(premiumProvider);
    final lang      = ref.watch(languageProvider); final isAr      = lang =='ar';
    final isDark    = ref.watch(themeProvider);
    final bg        = isDark ? AppColors.darkCard : Colors.white;
    final muted     = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String t(String ar, String en) => tLang(lang, ar, en);

    final vfMode = _scanning
        ? ViewfinderMode.working
        : (_result != null ? ViewfinderMode.locked : ViewfinderMode.idle);
    final lockCol = _result != null
        ? _statusColor(_result!.status)
        : AppColors.halalGreen;
    String hint;
    if (_scanning) {
      hint = t('جارٍ التحليل…', 'Analyzing…');
    } else if (_result != null) {
      hint = isAr ? _labelAr(_result!.status) : _labelEn(_result!.status);
    } else {
      hint = t('ضع الباركود داخل الإطار', 'Align the barcode inside the frame');
    }

    return Scaffold(
      appBar: AppBar( title: Text(t('الماسح الذكي 📷', 'Smart Scanner 📷')),
        actions: [
          GestureDetector(
            onTap: () => _showHistory(isAr, isDark),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, color: Colors.white),
                const SizedBox(width: 4), Text('${scan.history.length}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily:'Aligarh')),
              ]),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [

        // ── AI Food Photo hero ────────────────────────────
        Reveal(
          index: 0,
          child: PressFx(
            onTap: () => context.push('/food-photo'),
            scale: 0.97,
            child: SheenSweep(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandGreen, AppColors.darkGreen],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: AppColors.brandGreen.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 7),
                  )],
                ),
                child: Row(children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Center(child: ShutterGlyph(size: 44)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [ Text(t('تحليل الطعام بـ AI 🤖', 'AI Food Analyzer 🤖'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 15,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold,
                          borderRadius: BorderRadius.circular(20),
                        ), child: Text(t('جديد!', 'NEW!'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 9,
                                fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Text( t('صوّر أي طعام ← سعرات + بروتين + حكم حلال فوراً', 'Photo any food ← Calories + Protein + Halal status instantly'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 11,
                          color: Colors.white70, height: 1.4),
                    ),
                  ])),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                ]),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── OR divider ───────────────────────────────────
        Reveal(
          index: 1,
          slide: false,
          child: Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(t('أو امسح باركود', 'or scan barcode'), style: TextStyle(fontFamily:'Aligarh', fontSize: 12, color: muted)),
            ),
            const Expanded(child: Divider()),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Camera ────────────────────────────────────────
        AnimatedContainer(
          duration: Motion.base,
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
              color: lockCol.withOpacity(_result != null ? 0.38 : 0.20),
              blurRadius: 22, offset: const Offset(0, 6),
            )],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(fit: StackFit.expand, children: [
              BarcodeScannerWidget(
                isActive: true,
                onDetected: _onCameraBarcode,
              ),
              ScanViewfinder(mode: vfMode, lockColor: lockCol),
              Positioned(top: 12, right: 12,
                  child: _quotaChip(isPremium, scan.todayCount, lang)),
              Positioned(left: 0, right: 0, bottom: 12,
                  child: Center(child: _hintPill(hint, lockCol, _result != null))),
            ]),
          ),
        ),

        // ── Lookup + result sit right under the camera ───
        AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          alignment: Alignment.topCenter,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_scanning) ...[
              const SizedBox(height: 14),
              _loaderCard(bg, lang),
            ],
            if (_result != null && !_scanning) ...[
              const SizedBox(height: 14),
              _resultCard(_result!, isAr, isDark, bg, muted),
            ],
          ]),
        ),

        const SizedBox(height: 14),

        // ── Manual entry ──────────────────────────────────
        Reveal(
          index: 2,
          child: Row(children: [
            Expanded(child: TextField(
              controller: _barcodeCtrl,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) { if (v.trim().isNotEmpty) _scan(v.trim()); },
              decoration: InputDecoration( hintText: t('أدخل الباركود يدوياً...', 'Enter barcode manually...'), hintStyle: const TextStyle(fontFamily:'Aligarh', fontSize: 12),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.brandGreen.withOpacity(0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.brandGreen.withOpacity(0.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.6),
                ),
                prefixIcon: const Icon(Icons.qr_code_2_rounded),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            PressFx(
              onTap: () {
                final v = _barcodeCtrl.text.trim();
                if (v.isNotEmpty) _scan(v);
              },
              scale: 0.92,
              child: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: AppColors.brandGreen.withOpacity(0.35),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )],
                ),
                child: const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Demo products ─────────────────────────────────
        Reveal(
          index: 3,
          child: Row(children: [
            Expanded(child: Text(t('جرّب هذه المنتجات:', 'Try these products:'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 13, fontWeight: FontWeight.w700))),
            PressFx(
              onTap: () {
                final p = kProductsDB[DateTime.now().millisecond % kProductsDB.length];
                _scan(p.barcode);
              },
              scale: 0.94,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.brandGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
                ),
                child: Text(t('📷 مسح عشوائي', '📷 Random Scan'), style: const TextStyle(fontFamily:'Aligarh', fontSize: 12, color: AppColors.brandGreen, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 10),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: kProductsDB.asMap().entries.map((e) {
            final p = e.value;
            return Reveal(
              index: e.key > 7 ? 7 : e.key,
              offset: 0.2,
              child: PressFx(
                onTap: () => _scan(p.barcode),
                scale: 0.95,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _statusColor(p.status).withOpacity(0.22)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    _statusIcon(p.status, 26),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [ Text(p.name, style: const TextStyle(fontFamily:'Aligarh', fontSize: 10,
                            fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis), Text(p.barcode, style: TextStyle(fontFamily:'Aligarh', fontSize: 9, color: muted)),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),
      ]),
    );
  }

  // ── Small pieces ──────────────────────────────────────────
  SealKind _sealKind(HalalStatus s) {
    switch (s) {
      case HalalStatus.halal:    return SealKind.halal;
      case HalalStatus.doubtful: return SealKind.doubtful;
      case HalalStatus.haram:    return SealKind.haram;
      case HalalStatus.unknown:  return SealKind.unknown;
    }
  }

  Widget _statusIcon(HalalStatus s, double size) {
    final c = _statusColor(s);
    IconData ic;
    switch (s) {
      case HalalStatus.halal:    ic = Icons.check_rounded; break;
      case HalalStatus.doubtful: ic = Icons.priority_high_rounded; break;
      case HalalStatus.haram:    ic = Icons.close_rounded; break;
      case HalalStatus.unknown:  ic = Icons.help_outline_rounded; break;
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withOpacity(0.16),
        border: Border.all(color: c.withOpacity(0.5)),
      ),
      child: Icon(ic, size: size * 0.62, color: c),
    );
  }

  Widget _quotaChip(bool isPremium, int used, String lang) {
    final int left = (3 - used).clamp(0, 3).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.50),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: isPremium
        ? [
            const Icon(Icons.all_inclusive_rounded, size: 14, color: AppColors.accentGold),
            const SizedBox(width: 5),
            Text(tLang(lang, 'غير محدود', 'Unlimited', 'Illimité', 'Sınırsız', 'Tanpa Had', 'Tanpa Batas'),
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                  color: Colors.white, fontWeight: FontWeight.w700)),
          ]
        : [
            for (var i = 0; i < 3; i++) ...[
              AnimatedContainer(
                duration: Motion.base,
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < left ? AppColors.halalGreen : Colors.white.withOpacity(0.25),
                ),
              ),
              const SizedBox(width: 4),
            ],
            const SizedBox(width: 2),
            Text('${tLang(lang, "متبقي", "Left")} $left/3',
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                  color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
    );
  }

  Widget _hintPill(String text, Color col, bool strong) {
    return AnimatedSwitcher(
      duration: Motion.quick,
      child: Container(
        key: ValueKey(text),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: strong ? col.withOpacity(0.8) : Colors.white.withOpacity(0.14)),
        ),
        child: Text(text,
          style: TextStyle(fontFamily: 'Aligarh', fontSize: 11,
              fontWeight: FontWeight.w700,
              color: strong ? col : Colors.white)),
      ),
    );
  }

  Widget _loaderCard(Color bg, String lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScanLoader(color: AppColors.brandGreen),
        const SizedBox(height: 12),
        Text(
          tLang(lang, '📡 جارٍ البحث في Open Food Facts…', '📡 Searching Open Food Facts…'),
          style: const TextStyle(
            fontFamily: 'Aligarh', fontSize: 13,
            color: AppColors.brandGreen,
            fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }

  // ── Result card ───────────────────────────────────────────
  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {
    final lang  = ref.read(languageProvider);
    final col   = _statusColor(r.status);
    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);
    String t(String ar, String en) => tLang(lang, ar, en);
    final key    = '${r.barcode}-${r.scannedAt.microsecondsSinceEpoch}';
    final logged = _loggedKey == key;

    return Reveal(
      key: ValueKey(key),
      offset: 0.14,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(bg, col, isDark ? 0.16 : 0.10)!, bg],
          ),
          border: Border.all(color: col.withOpacity(0.5), width: 1.4),
          boxShadow: [BoxShadow(color: col.withOpacity(0.22), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              VerdictSeal(kind: _sealKind(r.status), color: col, size: 78),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w900,
                    fontSize: 22, color: col)),
                const SizedBox(height: 2),
                Text(r.name, style: const TextStyle(fontFamily:'Aligarh', fontSize: 14,
                    fontWeight: FontWeight.w600)),
                if (r.brand != null && r.brand!.isNotEmpty)
                  Text(r.brand!, style: TextStyle(fontFamily:'Aligarh', fontSize: 11, color: muted)),
              ])),
            ]),
            const Divider(height: 22),
            _row(t('الباركود', 'Barcode'), r.barcode),
            if (r.certs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Wrap(spacing: 6, runSpacing: 6, children: r.certs.map((c) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.halalGreen.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.halalGreen.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_rounded, size: 12, color: AppColors.halalGreen),
                      const SizedBox(width: 4),
                      Text(c, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                          fontWeight: FontWeight.w700, color: AppColors.halalGreen)),
                    ]),
                  )).toList()),
                ),
              ),
            if (r.notes != null && r.notes!.isNotEmpty) _row(t('ملاحظات', 'Notes'), r.notes!),
            // ── Nutrition macros (from OFFapi) ──────────────
            if (r.kcal != null) ...[
              const Divider(height: 22),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                MacroRing(value: '${r.kcal}', label: t('سعرة', 'kcal'),
                    pct: r.kcal! / 600.0, color: AppColors.haramRed),
                if (r.proteinG != null)
                  MacroRing(value: '${r.proteinG!.toStringAsFixed(1)}g', label: t('بروتين', 'Prot'),
                      pct: r.proteinG! / 30.0, color: AppColors.halalGreen),
                if (r.carbsG != null)
                  MacroRing(value: '${r.carbsG!.toStringAsFixed(1)}g', label: t('كربوهيد', 'Carbs'),
                      pct: r.carbsG! / 60.0, color: AppColors.waterBlue),
                if (r.fatG != null)
                  MacroRing(value: '${r.fatG!.toStringAsFixed(1)}g', label: t('دهون', 'Fat'),
                      pct: r.fatG! / 40.0, color: AppColors.accentGold),
              ]),
              const SizedBox(height: 6),
              Text(t('لكل ١٠٠ج', 'per 100g'),
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 9, color: muted),
                textAlign: TextAlign.center),
            ],
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setState(() { _result = null; _barcodeCtrl.clear(); _lastBarcode = null; }),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(t('مسح آخر', 'Scan Again'),
                  style: const TextStyle(fontFamily: 'Aligarh')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandGreen,
                  side: const BorderSide(color: AppColors.brandGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )),
              const SizedBox(width: 10),
              if (r.kcal != null)
                Expanded(child: ElevatedButton.icon(
                  onPressed: logged ? null : () {
                    HapticFeedback.mediumImpact();
                    ref.read(caloriesProvider.notifier).addEntry(
                        r.name, r.kcal!);
                    setState(() => _loggedKey = key);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(tLang(lang, '✅ أُضيف للعداد', '✅ Added to tracker', '✅ Ajouté au suivi', '✅ Takibe eklendi', '✅ Ditambah ke penjejak', '✅ Ditambahkan ke pelacak'),
                          style: const TextStyle(fontFamily: 'Aligarh')),
                      backgroundColor: AppColors.brandGreen,
                      duration: const Duration(seconds: 2),
                    ));
                  },
                  icon: Icon(logged ? Icons.check_rounded : Icons.add_rounded,
                      color: Colors.white, size: 16),
                  label: Text(logged ? t('أُضيف', 'Added') : t('أضف للعداد', 'Add to Log'),
                      style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    disabledBackgroundColor: AppColors.brandGreen.withOpacity(0.55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ))
              else
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => context.push('/food-photo'),
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                  label: Text(t('تحليل AI', 'AI Analysis'),
                      style: const TextStyle(fontFamily: 'Aligarh', color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                )),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _row(String label, String val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('$label: ', style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w700, fontSize: 12)), Expanded(child: Text(val, style: const TextStyle(fontFamily:'Aligarh', fontSize: 12, color: AppColors.lightMuted))),
    ]),
  );

  void _showHistory(bool isAr, bool isDark) {
    final history = ref.read(scanProvider).history;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 38, height: 4,
          decoration: BoxDecoration(
            color: AppColors.lightMuted.withOpacity(0.35),
            borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(14), child: Text(tLang(lang, 'سجل الماسحات', 'Scan History', 'Historique des scans', 'Tarama Geçmişi', 'Sejarah Imbasan', 'Riwayat Pemindaian'), style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        if (history.isEmpty) Expanded(child: Center(child: Text(tLang(lang, 'لا توجد ماسحات بعد', 'No scans yet', 'Aucun scan encore', 'Henüz tarama yok', 'Belum ada imbasan', 'Belum ada pemindaian'), style: const TextStyle(fontFamily:'Aligarh', color: AppColors.lightMuted))))
        else
          Expanded(child: ListView(children: history.map((r) => ListTile(
            leading: _statusIcon(r.status, 34), title: Text(r.name, style: const TextStyle(fontFamily:'Aligarh', fontWeight: FontWeight.w600, fontSize: 13)), subtitle: Text(r.brand ??'', style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11)),
            trailing: Text(
              isAr ? _labelAr(r.status) : _labelEn(r.status), style: TextStyle(fontFamily:'Aligarh', fontSize: 11, fontWeight: FontWeight.w700,
                  color: _statusColor(r.status)),
            ),
          )).toList())),
      ]),
    );
  }

  Color _statusColor(HalalStatus s) {
    switch (s) {
      case HalalStatus.halal:    return AppColors.halalGreen;
      case HalalStatus.doubtful: return AppColors.doubtOrange;
      case HalalStatus.haram:    return AppColors.haramRed;
      case HalalStatus.unknown:  return Colors.grey;
    }
  }

  String _labelAr(HalalStatus s) {
    switch (s) { case HalalStatus.halal:    return'حلال ✓'; case HalalStatus.doubtful: return'مشبوه ⚠️'; case HalalStatus.haram:    return'حرام ✕'; case HalalStatus.unknown:  return'غير معروف ?';
    }
  }

  String _labelEn(HalalStatus s) {
    switch (s) { case HalalStatus.halal:    return'Halal ✓'; case HalalStatus.doubtful: return'Doubtful ⚠️'; case HalalStatus.haram:    return'Haram ✕'; case HalalStatus.unknown:  return'Unknown ?';
    }
  }
}
'''

ANCHOR = ("  @override\n  Widget build(BuildContext context) {\n"
          "    final scan      = ref.watch(scanProvider);")

def scanner_patch(s):
    if 'ScanViewfinder(' in s: return s
    i = s.find(ANCHOR)
    if i < 0: return None
    return s[:i] + TAIL
edit(SCN, scanner_patch, 'viewfinder, seal, rings, result under camera')

edit('pubspec.yaml', sub_once('version: 1.6.0+19', 'version: 1.7.0+20'), 'version 1.7.0+20')

print('\n== sanity: brace balance ==')
bad = 0
for p in ['lib/core/fx5.dart', BARCODE, SCN]:
    if not os.path.exists(path(p)): continue
    t = open(path(p), encoding='utf-8').read()
    t = re.sub(r"//[^\n]*", '', t)
    t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
    t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
    for a, b in ('{}', '()', '[]'):
        if t.count(a) != t.count(b):
            bad += 1
            print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
print('  all balanced' if not bad else '  !! fix the files above before building')
print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git add -A && git commit -m "v48: scanner lens" && git push')
