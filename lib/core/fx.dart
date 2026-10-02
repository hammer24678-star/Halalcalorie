// ════════════════════════════════════════════════════════════════════
//  fx.dart — premium visual kit (v44)
//
//  AuroraBackground  slow drifting light behind a screen
//  GlassCard         layered surface with gradient edge + soft depth
//  ShineButton       primary CTA: press-scale, glow, periodic light sweep
//  BrandMark         vector crescent-and-leaf logo (crisp at any size)
//  AppGlyph          vector icon set used by the navigation bar
//
//  Everything is drawn in code: no PNG fringes, no emoji font variance.
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'motion.dart';
import 'theme.dart';

// ────────────────────────────────────────────────────────────────────
// AURORA
// ────────────────────────────────────────────────────────────────────

/// Fills its parent with slowly drifting coloured light. Put it first in a
/// Stack (wrapped in Positioned.fill). Costs one CustomPaint per frame.
class AuroraBackground extends StatefulWidget {
  final Color base;
  final List<Color> colors;
  final double intensity;
  final int seconds;

  const AuroraBackground({
    super.key,
    required this.base,
    required this.colors,
    this.intensity = 1,
    this.seconds = 16,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
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
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _AuroraPainter(
              t: _c.value,
              base: widget.base,
              colors: widget.colors,
              intensity: widget.intensity,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t, intensity;
  final Color base;
  final List<Color> colors;
  const _AuroraPainter({
    required this.t,
    required this.base,
    required this.colors,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    final n = colors.length;
    final r = math.max(size.width, size.height) * 0.62;
    for (var i = 0; i < n; i++) {
      final a = 2 * math.pi * (t + i / n);
      final center = Offset(
        size.width * (0.5 + 0.38 * math.sin(a + i)),
        size.height * (0.38 + 0.26 * math.cos(a * 1.0 + i * 1.7)),
      );
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            colors[i].withOpacity(0.34 * intensity),
            colors[i].withOpacity(0.0),
          ]).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.base != base || old.intensity != intensity;
}

// ────────────────────────────────────────────────────────────────────
// GLASS CARD
// ────────────────────────────────────────────────────────────────────

/// A surface with a gradient hairline edge, a faint top-down sheen and a
/// soft shadow. Optional [onTap] adds the app's press-scale feedback.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool isDark;
  final Color? accent;
  final bool glow;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    required this.isDark,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.accent,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final edge =
        accent ?? (isDark ? AppColors.halalGreen : AppColors.brandGreen);
    final fill = isDark
        ? const [Color(0xFF15281E), Color(0xFF0E1C15)]
        : const [Color(0xFFFFFFFF), Color(0xFFF2F7F3)];

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            edge.withOpacity(isDark ? 0.42 : 0.26),
            edge.withOpacity(0.04),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (glow ? edge : Colors.black)
                .withOpacity(isDark ? (glow ? 0.30 : 0.40) : 0.08),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius - 1),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: fill,
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap == null) return card;
    return PressFx(onTap: onTap, scale: 0.975, child: card);
  }
}

// ────────────────────────────────────────────────────────────────────
// SHINE BUTTON
// ────────────────────────────────────────────────────────────────────

class ShineButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final List<Color> colors;
  final Color textColor;
  final double height;

  const ShineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.colors = const [Color(0xFFF0CF98), Color(0xFFDBA75D)],
    this.textColor = const Color(0xFF1A0F00),
    this.height = 58,
  });

  @override
  State<ShineButton> createState() => _ShineButtonState();
}

class _ShineButtonState extends State<ShineButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final radius = BorderRadius.circular(widget.height / 2.6);

    return PressFx(
      onTap: enabled ? widget.onPressed : null,
      scale: 0.97,
      child: AnimatedOpacity(
        duration: Motion.quick,
        opacity: widget.onPressed == null ? 0.5 : 1,
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(colors: widget.colors),
            boxShadow: [
              BoxShadow(
                color: widget.colors.last.withOpacity(0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) => CustomPaint(
                    painter: _ShinePainter(_c.value),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: Motion.quick,
                child: widget.loading
                    ? SizedBox(
                        key: const ValueKey('l'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.6, color: widget.textColor),
                      )
                    : Row(
                        key: const ValueKey('t'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon,
                                size: 22, color: widget.textColor),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: widget.textColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ShinePainter extends CustomPainter {
  final double t;
  const _ShinePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // The sweep only runs in the first part of the cycle, then rests.
    const active = 0.42;
    if (t > active) return;
    final p = Curves.easeInOut.transform(t / active);
    final band = size.width * 0.28;
    final x = -band + (size.width + band * 2) * p;
    canvas.save();
    canvas.translate(x, size.height / 2);
    canvas.rotate(0.38);
    final rect = Rect.fromCenter(
        center: Offset.zero, width: band, height: size.height * 3);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(colors: [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(0.42),
          Colors.white.withOpacity(0),
        ]).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.t != t;
}

// ────────────────────────────────────────────────────────────────────
// BRAND MARK
// ────────────────────────────────────────────────────────────────────

/// Crescent with a leaf growing out of it. Solid [color] for monochrome
/// use (app bars, watermarks); null gives the full green-and-gold mark.
class BrandMark extends StatelessWidget {
  final double size;
  final Color? color;
  const BrandMark({super.key, required this.size, this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _BrandPainter(color)),
      );
}

class _BrandPainter extends CustomPainter {
  final Color? color;
  const _BrandPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final full = Offset.zero & size;

    final outer = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.5, s * 0.5), radius: s * 0.42));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: Offset(s * 0.65, s * 0.45), radius: s * 0.35));
    final crescent = Path.combine(PathOperation.difference, outer, cut);

    final crescentPaint = Paint()..isAntiAlias = true;
    if (color != null) {
      crescentPaint.color = color!;
    } else {
      crescentPaint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9BEFAE), Color(0xFF3FB950)],
      ).createShader(full);
    }
    canvas.drawPath(crescent, crescentPaint);

    // Leaf, tilted, sitting in the mouth of the crescent.
    canvas.save();
    canvas.translate(s * 0.62, s * 0.55);
    canvas.rotate(-0.62);
    canvas.scale(s / 100);
    final leaf = Path()
      ..moveTo(0, -24)
      ..quadraticBezierTo(18, -6, 0, 24)
      ..quadraticBezierTo(-18, -6, 0, -24)
      ..close();
    final leftHalf = Path()
      ..moveTo(0, -24)
      ..quadraticBezierTo(-18, -6, 0, 24)
      ..close();
    final leafPaint = Paint()..isAntiAlias = true;
    if (color != null) {
      leafPaint.color = color!.withOpacity(0.85);
    } else {
      leafPaint.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF6DDA8), Color(0xFFDBA75D)],
      ).createShader(const Rect.fromLTWH(-18, -24, 36, 48));
    }
    canvas.drawPath(leaf, leafPaint);
    canvas.drawPath(
        leftHalf, Paint()..color = Colors.black.withOpacity(0.12));
    canvas.restore();

    // Star.
    canvas.drawCircle(
      Offset(s * 0.80, s * 0.22),
      s * 0.035,
      Paint()..color = color ?? const Color(0xFFF6DDA8),
    );
  }

  @override
  bool shouldRepaint(_BrandPainter old) => old.color != color;
}

// ────────────────────────────────────────────────────────────────────
// GLYPHS
// ────────────────────────────────────────────────────────────────────

enum Glyph { home, nutrition, fitness, ascent, health, profile }

/// Stroke icon drawn on a 24-unit grid. [t] (0..1) is how "selected" it is:
/// fills in softly and lifts as it rises.
class AppGlyph extends StatelessWidget {
  final Glyph glyph;
  final Color color;
  final double t;
  final double size;
  const AppGlyph({
    super.key,
    required this.glyph,
    required this.color,
    this.t = 0,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GlyphPainter(glyph, color, t)),
      );
}

class _GlyphPainter extends CustomPainter {
  final Glyph glyph;
  final Color color;
  final double t;
  const _GlyphPainter(this.glyph, this.color, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color.withOpacity(0.20 * t.clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    void shape(Path p, {bool fillIt = false}) {
      if (fillIt && t > 0) canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }

    switch (glyph) {
      case Glyph.home:
        shape(
            Path()
              ..moveTo(3.5, 11)
              ..lineTo(12, 3.5)
              ..lineTo(20.5, 11)
              ..lineTo(20.5, 20)
              ..lineTo(3.5, 20)
              ..close(),
            fillIt: true);
        shape(Path()
          ..moveTo(9.5, 20)
          ..lineTo(9.5, 14.5)
          ..lineTo(14.5, 14.5)
          ..lineTo(14.5, 20));
        break;
      case Glyph.nutrition:
        shape(
            Path()
              ..moveTo(3, 12)
              ..lineTo(21, 12)
              ..arcToPoint(const Offset(3, 12),
                  radius: const Radius.circular(9), clockwise: true)
              ..close(),
            fillIt: true);
        shape(Path()
          ..moveTo(12, 8.5)
          ..quadraticBezierTo(7.5, 7, 9.5, 2.8)
          ..quadraticBezierTo(14.5, 4, 12, 8.5));
        break;
      case Glyph.fitness:
        shape(Path()
          ..moveTo(2, 12)
          ..lineTo(22, 12));
        shape(Path()
          ..moveTo(5.5, 8)
          ..lineTo(5.5, 16));
        shape(Path()
          ..moveTo(8.8, 6)
          ..lineTo(8.8, 18));
        shape(Path()
          ..moveTo(15.2, 6)
          ..lineTo(15.2, 18));
        shape(Path()
          ..moveTo(18.5, 8)
          ..lineTo(18.5, 16));
        break;
      case Glyph.ascent:
        shape(
            Path()
              ..moveTo(2.5, 19.5)
              ..lineTo(9, 8)
              ..lineTo(13, 14.5)
              ..lineTo(15.5, 10.5)
              ..lineTo(21.5, 19.5)
              ..close(),
            fillIt: true);
        shape(Path()
          ..moveTo(9, 8)
          ..lineTo(9, 3)
          ..lineTo(13, 4.6)
          ..lineTo(9, 6.2));
        break;
      case Glyph.health:
        shape(
            Path()
              ..moveTo(12, 20.5)
              ..cubicTo(4, 15, 2.5, 10, 5.5, 6.5)
              ..cubicTo(8, 4, 11, 5, 12, 7.5)
              ..cubicTo(13, 5, 16, 4, 18.5, 6.5)
              ..cubicTo(21.5, 10, 20, 15, 12, 20.5)
              ..close(),
            fillIt: true);
        break;
      case Glyph.profile:
        shape(Path()..addOval(Rect.fromCircle(center: const Offset(12, 8), radius: 4)),
            fillIt: true);
        shape(Path()
          ..moveTo(4.5, 21)
          ..cubicTo(4.5, 16, 8, 14, 12, 14)
          ..cubicTo(16, 14, 19.5, 16, 19.5, 21));
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.t != t;
}
