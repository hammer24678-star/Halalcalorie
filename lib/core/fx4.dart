// ════════════════════════════════════════════════════════════════════
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
