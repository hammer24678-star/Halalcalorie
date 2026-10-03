#!/usr/bin/env python3
"""
patch_v47_living_vitals.py
==========================
HalalCalorie v47 - Living Vitals. Run from the repo root:

    python3 patch_v47_living_vitals.py

Needs v44-v46 applied. Safe to run twice; no new dependencies.

NEW  lib/core/fx4.dart  -  VitalGlyph
     The four Home stat tiles stop being emoji with a thin bar and become
     living icons, all painted in code:
       Water    a glass that fills with a rolling liquid surface and rising
                bubbles; adding a cup makes the surface splash
       Sleep    a crescent moon that fills with light as you log hours,
                with twinkling stars and a glow at the goal
       Streak   a flickering flame that grows with your streak, with embers
       Workout  a progress ring around a scrolling heartbeat line
     Tiles also get a soft tinted gradient, coloured glow and press feedback.

EDITED  home_screen.dart  -  _Stat rebuilt around VitalGlyph (same API).
pubspec  1.5.0+18 -> 1.6.0+19
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



print('== v47 living vitals ==')

NEW_FILES = {'lib/core/fx4.dart': r'''// ════════════════════════════════════════════════════════════════════
//  fx4.dart — VitalGlyph (v47)
//
//  Living icons for the Home stats row, all painted in code:
//    water   glass that fills with a rolling liquid surface, rising
//            bubbles, and a splash whenever a cup is added
//    sleep   crescent moon that fills up with light, twinkling stars
//    flame   flickering flame that grows with the streak, rising embers
//    pulse   progress ring around a scrolling heartbeat line
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VitalKind { water, sleep, flame, pulse }

class VitalGlyph extends StatefulWidget {
  final VitalKind kind;
  final double pct;
  final Color color;
  final double size;
  const VitalGlyph({
    super.key,
    required this.kind,
    required this.pct,
    required this.color,
    this.size = 46,
  });

  @override
  State<VitalGlyph> createState() => _VitalGlyphState();
}

class _VitalGlyphState extends State<VitalGlyph>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();

  late final AnimationController _splash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1.0,
  );

  @override
  void didUpdateWidget(VitalGlyph old) {
    super.didUpdateWidget(old);
    if (old.pct != widget.pct && widget.kind == VitalKind.water) {
      _splash.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _splash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.pct.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, p, __) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_c, _splash]),
          builder: (_, __) => CustomPaint(
            size: Size.square(widget.size),
            painter: _VitalPainter(
              kind: widget.kind,
              p: p,
              t: _c.value,
              splash: _splash.value,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _VitalPainter extends CustomPainter {
  final VitalKind kind;
  final double p, t, splash;
  final Color color;
  const _VitalPainter({
    required this.kind,
    required this.p,
    required this.t,
    required this.splash,
    required this.color,
  });

  // `k` whole cycles per 60-second loop, so every motion repeats seamlessly.
  double _ph(double k) => 2 * math.pi * t * k;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case VitalKind.water:
        _water(canvas, size);
        break;
      case VitalKind.sleep:
        _sleep(canvas, size);
        break;
      case VitalKind.flame:
        _flame(canvas, size);
        break;
      case VitalKind.pulse:
        _pulse(canvas, size);
        break;
    }
  }

  // ── water ───────────────────────────────────────────────────────────
  void _water(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final glass = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.04, w * 0.64, h * 0.92),
      Radius.circular(w * 0.2),
    );
    c.drawRRect(glass, Paint()..color = color.withOpacity(0.10));

    c.save();
    c.clipRRect(glass);
    final level = h * 0.96 - h * 0.86 * p;
    final amp = 1.4 + 4.2 * (1 - Curves.easeOut.transform(splash));

    for (var layer = 0; layer < 2; layer++) {
      final path = Path()..moveTo(0, h);
      for (double x = 0; x <= w + 2; x += 2) {
        final y = level +
            amp * (layer == 0 ? 1.0 : 0.7) *
                math.sin(x / w * 2 * math.pi * 1.3 +
                    _ph(layer == 0 ? 18 : -14) + layer * 1.8);
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      c.drawPath(
        path,
        Paint()
          ..color = layer == 0
              ? color.withOpacity(0.55)
              : Color.lerp(color, Colors.white, 0.12)!.withOpacity(0.88),
      );
    }

    if (p > 0.12) {
      for (var i = 0; i < 3; i++) {
        final u = (t * 20 + i / 3) % 1.0;
        final by = h * 0.94 - u * (h * 0.94 - level);
        if (by > level + 2) {
          c.drawCircle(
            Offset(w * (0.38 + 0.12 * i), by),
            1.2 + i * 0.4,
            Paint()..color = Colors.white.withOpacity(0.55 * (1 - u)),
          );
        }
      }
    }
    c.restore();

    c.drawRRect(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withOpacity(0.85),
    );
    c.drawLine(
      Offset(w * 0.28, h * 0.18),
      Offset(w * 0.28, h * 0.46),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.35),
    );
  }

  // ── sleep ───────────────────────────────────────────────────────────
  void _sleep(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final ctr = Offset(w * 0.46, h * 0.52);
    final r = w * 0.36;
    final outer = Path()..addOval(Rect.fromCircle(center: ctr, radius: r));
    final cut = Path()
      ..addOval(Rect.fromCircle(
          center: ctr + Offset(r * 0.52, -r * 0.3), radius: r * 0.86));
    final moon = Path.combine(PathOperation.difference, outer, cut);

    if (p >= 0.99) {
      c.drawPath(
        moon,
        Paint()
          ..color = color.withOpacity(0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    c.drawPath(moon, Paint()..color = color.withOpacity(0.20));

    c.save();
    c.clipRect(Rect.fromLTRB(0, h * (1 - p), w, h));
    c.drawPath(
      moon,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.45)!, color],
        ).createShader(Rect.fromCircle(center: ctr, radius: r)),
    );
    c.restore();

    const stars = [
      Offset(0.80, 0.26),
      Offset(0.88, 0.56),
      Offset(0.70, 0.12),
    ];
    for (var i = 0; i < stars.length; i++) {
      final o = Offset(w * stars[i].dx, h * stars[i].dy);
      final a = 0.35 + 0.65 * math.pow(math.sin(_ph(10.0 + i * 3) + i), 2);
      final L = 2.2 + i * 0.4;
      final sp = Paint()
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(a.toDouble());
      c.drawLine(o - Offset(L, 0), o + Offset(L, 0), sp);
      c.drawLine(o - Offset(0, L), o + Offset(0, L), sp);
    }
  }

  // ── flame ───────────────────────────────────────────────────────────
  Path _flamePath(double w, double h, double sway, double top) {
    final cx = w / 2;
    final base = h * 0.94;
    return Path()
      ..moveTo(cx + sway * 0.6, top)
      ..cubicTo(cx + w * 0.10 + sway, h * 0.30, cx + w * 0.34, h * 0.46,
          cx + w * 0.30, h * 0.70)
      ..cubicTo(cx + w * 0.28, base, cx - w * 0.28, base, cx - w * 0.30,
          h * 0.70)
      ..cubicTo(cx - w * 0.34, h * 0.46, cx - w * 0.10 + sway, h * 0.30,
          cx + sway * 0.6, top);
  }

  void _flame(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final lit = p > 0.001;
    final k = lit ? 0.62 + 0.38 * p : 0.52;
    final sway = 1.7 * math.sin(_ph(120)) + 0.9 * math.sin(_ph(210) + 1.3);
    final top = h * 0.06 + 1.6 * math.sin(_ph(150));

    c.save();
    c.translate(w / 2, h * 0.94);
    c.scale(k);
    c.translate(-w / 2, -h * 0.94);

    if (lit) {
      c.drawCircle(
        Offset(w / 2, h * 0.66),
        w * 0.62,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withOpacity(0.30),
            color.withOpacity(0.0),
          ]).createShader(
              Rect.fromCircle(center: Offset(w / 2, h * 0.66), radius: w * 0.62)),
      );
    }

    final body = _flamePath(w, h, sway, top);
    c.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: lit
              ? [const Color(0xFFFFB02E), color]
              : [color.withOpacity(0.35), color.withOpacity(0.25)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    if (lit) {
      c.save();
      c.translate(w / 2, h * 0.94);
      c.scale(0.55);
      c.translate(-w / 2, -h * 0.94);
      c.drawPath(
        _flamePath(w, h, sway * 1.2, top + h * 0.1),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF1B8), Color(0xFFFFB02E)],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      c.restore();
    }
    c.restore();

    if (lit) {
      for (var i = 0; i < 3; i++) {
        final u = (t * 40 + i / 3) % 1.0;
        c.drawCircle(
          Offset(w / 2 + math.sin(u * 6 + i * 2) * w * 0.14, h * 0.62 - u * h * 0.58),
          1.5 * (1 - u) + 0.2,
          Paint()..color = const Color(0xFFFFD27A).withOpacity(1 - u),
        );
      }
    }
  }

  // ── pulse ───────────────────────────────────────────────────────────
  static const _beat = [
    [0.00, 0.00],
    [0.28, 0.00],
    [0.33, -0.12],
    [0.38, 0.00],
    [0.44, 0.00],
    [0.47, 0.22],
    [0.52, -1.00],
    [0.57, 0.40],
    [0.60, 0.00],
    [0.70, 0.00],
    [0.76, -0.22],
    [0.84, 0.00],
    [1.00, 0.00],
  ];

  double _ecg(double u) {
    for (var i = 0; i < _beat.length - 1; i++) {
      final a = _beat[i], b = _beat[i + 1];
      if (u >= a[0] && u <= b[0]) {
        final f = (u - a[0]) / (b[0] - a[0]);
        return a[1] + (b[1] - a[1]) * f;
      }
    }
    return 0;
  }

  void _pulse(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final ctr = Offset(w / 2, h / 2);
    final R = w / 2 - 3;
    final rect = Rect.fromCircle(center: ctr, radius: R);

    c.drawCircle(
      ctr,
      R,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.4
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
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    final inner = R - 6;
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: ctr, radius: inner)));
    final line = Path();
    final x0 = ctr.dx - inner;
    final span = inner * 2;
    final amp = inner * 0.62;
    for (var i = 0; i <= 28; i++) {
      final fx = i / 28;
      final u = ((fx * 1.5 - t * 45) % 1.0 + 1.0) % 1.0;
      final pt = Offset(x0 + span * fx, ctr.dy + _ecg(u) * amp);
      if (i == 0) {
        line.moveTo(pt.dx, pt.dy);
      } else {
        line.lineTo(pt.dx, pt.dy);
      }
    }
    final lr = Rect.fromLTWH(x0, 0, span, h);
    c.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [
          color.withOpacity(0.0),
          color.withOpacity(p > 0 ? 1.0 : 0.5),
          color.withOpacity(p > 0 ? 1.0 : 0.5),
        ], stops: const [0.0, 0.55, 1.0]).createShader(lr),
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_VitalPainter old) =>
      old.p != p || old.t != t || old.splash != splash || old.color != color;
}
'''}
for p, c in NEW_FILES.items():
    write(p, c)

HOME = 'lib/features/home/home_screen.dart'
edit(HOME, sub_once("import '../../core/fx3.dart';",
     "import '../../core/fx3.dart';\nimport '../../core/fx4.dart';"), 'import fx4.dart')

STAT = r'''class _Stat extends StatelessWidget {
  final String emoji, value, total, label;
  final Color color, card, border, muted;
  final double pct;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Stat({
    required this.emoji, required this.value, required this.total,
    required this.label, required this.color, required this.pct,
    required this.isDark, required this.card, required this.border,
    required this.muted, required this.onTap, this.onLongPress,
  });

  VitalKind? get _kind {
    switch (emoji) {
      case '💧': return VitalKind.water;
      case '😴': return VitalKind.sleep;
      case '🔥': return VitalKind.flame;
      case '🏃': return VitalKind.pulse;
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    return Expanded(
      child: PressFx(
        onTap: onTap,
        onLongPress: onLongPress == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onLongPress!();
              },
        scale: 0.94,
        haptics: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [card, Color.lerp(card, color, isDark ? 0.10 : 0.07)!],
            ),
            border: Border.all(
                color: Color.lerp(border, color, 0.35)!, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDark ? 0.14 : 0.10),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            kind != null
                ? VitalGlyph(kind: kind, pct: pct, color: color, size: 46)
                : Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 17,
                    fontWeight: FontWeight.w900, color: color,
                  ),
                ),
                TextSpan(
                  text: total,
                  style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 10, color: muted),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 10, color: muted)),
          ]),
        ),
      ),
    );
  }
}

'''

def stat_patch(s):
    if 'VitalGlyph(' in s: return s
    i = s.find('class _Stat extends StatefulWidget {')
    if i < 0: return None
    j = s.find('// \u2550\u2550\u2550', i)
    if j < 0: return None
    return s[:i] + STAT + s[j:]
edit(HOME, stat_patch, 'stat tiles become living vitals')

edit('pubspec.yaml', sub_once('version: 1.5.0+18', 'version: 1.6.0+19'), 'version 1.6.0+19')

print('\n== sanity: brace balance ==')
bad = 0
for p in ['lib/core/fx4.dart', HOME]:
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
print('Next:  git add -A && git commit -m "v47: living vitals" && git push')
