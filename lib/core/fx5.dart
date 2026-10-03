// ════════════════════════════════════════════════════════════════════
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
