#!/usr/bin/env python3
"""
patch_v45_cinematic.py
======================
HalalCalorie v45 - cinematic update. Run from the repo root:

    python3 patch_v45_cinematic.py

Needs v44 applied first. Safe to run twice; each edit is anchored and
prints SKIP instead of failing if its anchor is missing. No new dependencies.

NEW   lib/core/fx2.dart
      HeroRing       calorie ring with tick dial that lights up, gradient arc
                     with glowing head, breathing core, red overflow arc
      OnboardScene   3 looping hero scenes drawn in code (brand orbit,
                     scan viewfinder with laser + macro arcs, moon + prayer dial)

HOME  new HeroRing. Also fixes a bug already in the app: the calorie number
      was printed with a stray backtick in front of it.
ONBOARDING  scene-based welcome slides with staggered reveals, gradient
      titles, glow progress bar, aurora background, shine CTA button,
      glass badge on every question.
pubspec  1.3.0+16 -> 1.4.0+17
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



print('== v45 cinematic update ==')

NEW_FILES = {'lib/core/fx2.dart': r'''// ════════════════════════════════════════════════════════════════════
//  fx2.dart — cinematic kit (v45)
//
//  HeroRing      the Home calorie ring: tick dial, gradient arc with a
//                glowing head, breathing core, overflow arc past 100%
//  OnboardScene  three looping hero scenes drawn in code:
//                  0 brand orbit, 1 scan viewfinder, 2 moon + prayer dial
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'fx.dart';

// ────────────────────────────────────────────────────────────────────
// HERO RING
// ────────────────────────────────────────────────────────────────────

class HeroRing extends StatefulWidget {
  final double pct;
  final Animation<double> ringAnim;
  final Color color;
  final int eaten;
  final bool isDark;
  final Color muted;
  final String label;
  final double size;

  const HeroRing({
    super.key,
    required this.pct,
    required this.ringAnim,
    required this.color,
    required this.eaten,
    required this.isDark,
    required this.muted,
    required this.label,
    this.size = 132,
  });

  @override
  State<HeroRing> createState() => _HeroRingState();
}

class _HeroRingState extends State<HeroRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.ringAnim, _breath]),
        builder: (_, __) {
          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _HeroRingPainter(
                pct: widget.pct * widget.ringAnim.value,
                color: widget.color,
                isDark: widget.isDark,
                breath: Curves.easeInOut.transform(_breath.value),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: widget.eaten),
                      duration: const Duration(milliseconds: 1100),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Text(
                        '$v',
                        style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 29,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: widget.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroRingPainter extends CustomPainter {
  final double pct, breath;
  final Color color;
  final bool isDark;
  const _HeroRingPainter({
    required this.pct,
    required this.color,
    required this.isDark,
    required this.breath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rArc = size.width / 2 - 16;
    final rect = Rect.fromCircle(center: c, radius: rArc);
    final p = pct.clamp(0.0, 1.0);

    // Bloom behind everything.
    canvas.drawCircle(
      c,
      size.width / 2,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withOpacity(0.10 + 0.07 * breath),
          color.withOpacity(0),
        ]).createShader(Rect.fromCircle(center: c, radius: size.width / 2)),
    );

    // Dial ticks: they light up as the arc passes them.
    const ticks = 60;
    for (var i = 0; i < ticks; i++) {
      final a = -math.pi / 2 + 2 * math.pi * i / ticks;
      final major = i % 5 == 0;
      final r0 = rArc + 9;
      final r1 = r0 + (major ? 5 : 3);
      final lit = (i / ticks) <= p && p > 0;
      canvas.drawLine(
        c + Offset(math.cos(a) * r0, math.sin(a) * r0),
        c + Offset(math.cos(a) * r1, math.sin(a) * r1),
        Paint()
          ..strokeWidth = major ? 1.8 : 1.1
          ..strokeCap = StrokeCap.round
          ..color = lit
              ? color.withOpacity(major ? 0.95 : 0.65)
              : (isDark ? Colors.white : Colors.black)
                  .withOpacity(major ? 0.22 : 0.12),
      );
    }

    // Track.
    canvas.drawCircle(
      c,
      rArc,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.black.withOpacity(0.07),
    );

    // Breathing core.
    final coreR = rArc - 13 + 2.5 * breath;
    canvas.drawCircle(
      c,
      coreR,
      Paint()
        ..shader = RadialGradient(colors: [
          color.withOpacity(0.13),
          color.withOpacity(0.0),
        ]).createShader(Rect.fromCircle(center: c, radius: coreR)),
    );

    if (p > 0.004) {
      final sweep = 2 * math.pi * p;

      // Glow under the arc.
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = color.withOpacity(0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );

      // Gradient arc.
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            startAngle: 0,
            endAngle: sweep,
            colors: [
              color.withOpacity(0.55),
              color,
              Color.lerp(color, Colors.white, 0.38)!,
            ],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect),
      );

      // Glowing head.
      final a = -math.pi / 2 + sweep;
      final head = c + Offset(math.cos(a) * rArc, math.sin(a) * rArc);
      canvas.drawCircle(head, 11, Paint()..color = color.withOpacity(0.30));
      canvas.drawCircle(head, 5.6, Paint()..color = Colors.white);
      canvas.drawCircle(
        head,
        5.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }

    // Past 100%: a thin warning arc runs inside the ring.
    final over = pct - 1.0;
    if (over > 0.004) {
      final ro = rArc - 14;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: ro),
        -math.pi / 2,
        2 * math.pi * over.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..color = AppColors.haramRed,
      );
    }
  }

  @override
  bool shouldRepaint(_HeroRingPainter old) =>
      old.pct != pct ||
      old.breath != breath ||
      old.color != color ||
      old.isDark != isDark;
}

// ────────────────────────────────────────────────────────────────────
// ONBOARDING SCENES
// ────────────────────────────────────────────────────────────────────

class OnboardScene extends StatefulWidget {
  /// 0 brand orbit, 1 scan viewfinder, 2 moon and prayer dial.
  final int kind;
  final Color color;
  final double size;
  const OnboardScene({
    super.key,
    required this.kind,
    required this.color,
    this.size = 236,
  });

  @override
  State<OnboardScene> createState() => _OnboardSceneState();
}

class _OnboardSceneState extends State<OnboardScene>
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
    final s = widget.size;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          return SizedBox(
            width: s,
            height: s,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(
                size: Size(s, s),
                painter: _ScenePainter(widget.kind, _c.value, widget.color),
              ),
              if (widget.kind == 0)
                Transform.translate(
                  offset: Offset(0, 5 * math.sin(2 * math.pi * _c.value)),
                  child: BrandMark(size: s * 0.44),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final int kind;
  final double t;
  final Color col;
  const _ScenePainter(this.kind, this.t, this.col);

  static const _gold = Color(0xFFDBA75D);

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case 0:
        _brand(canvas, size);
        break;
      case 1:
        _scan(canvas, size);
        break;
      default:
        _moon(canvas, size);
    }
  }

  // ── 0: brand orbit ────────────────────────────────────────────────
  void _brand(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final R = s.width / 2;

    canvas.drawCircle(
      c,
      R,
      Paint()
        ..shader = RadialGradient(colors: [
          col.withOpacity(0.30 + 0.06 * math.sin(2 * math.pi * t)),
          col.withOpacity(0),
        ]).createShader(Rect.fromCircle(center: c, radius: R)),
    );

    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        c,
        R * (0.52 + 0.17 * i),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withOpacity(0.07 + 0.03 * i),
      );
    }

    const n = 8;
    for (var i = 0; i < n; i++) {
      final ring = i % 3;
      final rr = R * (0.52 + 0.17 * ring);
      final dir = ring.isEven ? 1.0 : -1.0;
      final dotColor = i.isEven ? col : _gold;
      for (var k = 5; k >= 0; k--) {
        final a = 2 * math.pi * (i / n + dir * t * (ring + 1)) -
            dir * k * 0.075;
        final pos = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
        final fade = 1 - k / 6;
        if (k == 0) {
          canvas.drawCircle(
              pos, 9, Paint()..color = dotColor.withOpacity(0.22));
          canvas.drawCircle(pos, 3.4 + ring * 0.6, Paint()..color = dotColor);
        } else {
          canvas.drawCircle(pos, 2.4 * fade,
              Paint()..color = dotColor.withOpacity(0.35 * fade));
        }
      }
    }
  }

  // ── 1: scan viewfinder ────────────────────────────────────────────
  void _scan(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final R = s.width / 2;
    final p = 0.5 - 0.5 * math.cos(2 * math.pi * t);
    final pulse = 0.5 + 0.5 * math.sin(2 * math.pi * t * 2);

    // Plate.
    final plateR = R * 0.5;
    canvas.drawCircle(
      c,
      plateR,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withOpacity(0.13),
          Colors.white.withOpacity(0.04),
        ]).createShader(Rect.fromCircle(center: c, radius: plateR)),
    );
    canvas.drawCircle(
      c,
      plateR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(0.22),
    );
    canvas.drawCircle(
      c,
      plateR * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(0.08),
    );

    // Food.
    void food(Offset o, double r, Color f) {
      canvas.drawCircle(c + o, r, Paint()..color = f.withOpacity(0.88));
      canvas.drawCircle(c + o + Offset(-r * 0.3, -r * 0.3), r * 0.38,
          Paint()..color = Colors.white.withOpacity(0.22));
    }

    food(Offset(-R * 0.15, -R * 0.06), R * 0.13, const Color(0xFF3FB950));
    food(Offset(R * 0.14, -R * 0.11), R * 0.11, _gold);
    food(Offset(R * 0.03, R * 0.15), R * 0.12, const Color(0xFFE5734F));

    // Macro arcs fill in as the laser passes.
    final colors = [const Color(0xFF3FB950), const Color(0xFF4DA3FF), _gold];
    final arcR = R * 0.68;
    for (var k = 0; k < 3; k++) {
      final start = -math.pi / 2 + k * 2 * math.pi / 3 + 0.12;
      final maxSweep = 2 * math.pi / 3 - 0.24;
      final part = ((p * 1.25) - k * 0.2).clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: arcR),
        start,
        maxSweep * part,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = colors[k].withOpacity(0.95),
      );
    }

    // Frame brackets.
    final side = R * 1.56;
    final frame = Rect.fromCenter(center: c, width: side, height: side);
    final bl = side * 0.2;
    final br = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = col.withOpacity(0.55 + 0.4 * pulse);
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(dx * bl, 0), br);
      canvas.drawLine(o, o + Offset(0, dy * bl), br);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);

    // Laser.
    canvas.save();
    canvas.clipRect(frame);
    final y = frame.top + frame.height * p;
    final band = Rect.fromLTWH(frame.left, y - 22, frame.width, 44);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            col.withOpacity(0),
            col.withOpacity(0.30),
            col.withOpacity(0),
          ],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(frame.left, y),
      Offset(frame.right, y),
      Paint()
        ..strokeWidth = 2
        ..color = Colors.white.withOpacity(0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2),
    );
    canvas.restore();
  }

  // ── 2: moon and prayer dial ───────────────────────────────────────
  void _moon(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final R = s.width / 2;

    canvas.drawCircle(
      c,
      R,
      Paint()
        ..shader = RadialGradient(colors: [
          col.withOpacity(0.26),
          col.withOpacity(0),
        ]).createShader(Rect.fromCircle(center: c, radius: R)),
    );

    // Stars.
    for (var i = 0; i < 16; i++) {
      final a = i * 2.399;
      final rad = R * (0.52 + 0.42 * (((i * 7) % 16) / 16));
      final pos = c + Offset(math.cos(a) * rad, math.sin(a) * rad * 0.9);
      final tw = math.pow(math.sin(math.pi * (t * 2 + i / 16)), 2).toDouble();
      canvas.drawCircle(pos, 1.0 + (i % 3) * 0.6,
          Paint()..color = Colors.white.withOpacity(0.2 + 0.8 * tw));
    }

    // Crescent.
    final mc = c + Offset(-R * 0.04, -R * 0.1);
    final outer = Path()
      ..addOval(Rect.fromCircle(center: mc, radius: R * 0.34));
    final cut = Path()
      ..addOval(Rect.fromCircle(
          center: mc + Offset(R * 0.13, -R * 0.07), radius: R * 0.29));
    final moon = Path.combine(PathOperation.difference, outer, cut);
    canvas.drawPath(
      moon,
      Paint()
        ..color = _gold.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawPath(
      moon,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6DDA8), Color(0xFFDBA75D)],
        ).createShader(Rect.fromCircle(center: mc, radius: R * 0.34)),
    );

    // Prayer dial along the bottom.
    final dialR = R * 0.78;
    final a0 = math.pi * 0.2;
    final a1 = math.pi * 0.8;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: dialR),
      a0,
      a1 - a0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(0.14),
    );
    final active = (t * 5).floor() % 5;
    for (var i = 0; i < 5; i++) {
      final a = a0 + (a1 - a0) * i / 4;
      final pos = c + Offset(math.cos(a) * dialR, math.sin(a) * dialR);
      if (i == active) {
        canvas.drawCircle(pos, 12, Paint()..color = col.withOpacity(0.28));
        canvas.drawCircle(pos, 6, Paint()..color = col);
        canvas.drawCircle(pos, 2.4, Paint()..color = Colors.white);
      } else {
        canvas.drawCircle(
            pos, 4, Paint()..color = Colors.white.withOpacity(0.34));
      }
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) =>
      old.t != t || old.kind != kind || old.col != col;
}
'''}
for p, c in NEW_FILES.items():
    write(p, c)

HOME = 'lib/features/home/home_screen.dart'
ONB  = 'lib/features/onboarding/onboarding_screen.dart'

# ───────────── Home: new calorie hero ring (also removes the stray ` bug) ───
edit(HOME, sub_once("import '../../core/fx.dart';",
     "import '../../core/fx.dart';\nimport '../../core/fx2.dart';"), 'import fx2.dart')

def ring_patch(s):
    if 'HeroRing(' in s: return s
    pat = re.compile(r"// ── Animated ring ──.*?(?=const SizedBox\(width: 20\),)", re.S)
    if not pat.search(s): return None
    new = ("// ── Animated ring ──\n"
           "HeroRing(\n"
           "pct: pct,\n"
           "ringAnim: ringAnim,\n"
           "color: calCol,\n"
           "eaten: eaten,\n"
           "isDark: isDark,\n"
           "muted: muted,\n"
           "label: t('\\u0645\\u0623\\u0643\\u0648\\u0644', 'kcal eaten'),\n"
           "),\n\n")
    return pat.sub(lambda m: new, s, count=1)
edit(HOME, ring_patch, 'HeroRing replaces calorie ring (fixes stray backtick)')

# ───────────── Onboarding ───────────────────────────────────────────────
edit(ONB, sub_once("import '../../core/theme.dart';",
     "import '../../core/theme.dart';\nimport '../../core/fx.dart';\nimport '../../core/fx2.dart';\nimport '../../core/motion.dart';"),
     'imports')

NEW_WELCOME = r"""class _WelcomePage extends StatelessWidget {
  final _WelcomeStep step;
  final bool isDark;
  final String lang;
  const _WelcomePage({required this.step, required this.isDark, required this.lang});

  int get _kind =>
      step.titleEn == 'HalalCalorie' ? 0 : (step.titleEn == 'AI-Powered' ? 1 : 2);

  @override
  Widget build(BuildContext context) {
    final text = isDark ? Colors.white : const Color(0xFF1F2A1F);
    final sub = isDark ? const Color(0xFFA9B4BF) : const Color(0xFF5B6B7D);
    final chips = lang == 'ar' ? step.chips : step.chipsEn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 750),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(scale: v, child: child),
            ),
            child: OnboardScene(kind: _kind, color: step.color, size: 236),
          ),
          const SizedBox(height: 26),
          Reveal(
            index: 1,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) =>
                  LinearGradient(colors: [text, step.color]).createShader(r),
              child: Text(
                lang == 'ar' ? step.title : step.titleEn,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Aligarh', fontSize: 32,
                  fontWeight: FontWeight.w900, color: Colors.white, height: 1.15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Reveal(
            index: 2,
            child: Text(
              lang == 'ar' ? step.subtitle : step.subtitleEn,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 16, height: 1.7, color: sub,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 0; i < chips.length; i++)
                Reveal(
                  index: 3 + i,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          step.color.withOpacity(0.22),
                          step.color.withOpacity(0.06),
                        ],
                      ),
                      border: Border.all(color: step.color.withOpacity(0.38), width: 0.8),
                    ),
                    child: Text(
                      chips[i],
                      style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 13,
                        fontWeight: FontWeight.w700, color: step.color,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

"""
def welcome_patch(s):
    if 'OnboardScene(' in s: return s
    i = s.find('class _WelcomePage extends StatelessWidget {')
    j = s.find('// ═══════════════════════════════════════════════════════════\n//  QUESTION SHELL')
    if i < 0 or j < 0 or j < i: return None
    return s[:i] + NEW_WELCOME + s[j:]
edit(ONB, welcome_patch, 'cinematic welcome scenes')

NEW_BOTTOM = r"""class _BottomBar extends ConsumerWidget {
  final String lang;
  final int page;
  final bool isLast, isQuestion, isDark;
  final VoidCallback onNext;
  const _BottomBar({
    required this.lang,
    required this.page, required this.isLast,
    required this.isQuestion, required this.isDark, required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang  = ref.watch(languageProvider);
    final label = isLast
      ? (tLang(lang, 'ابدأ رحلتك 🌿', 'Start your journey 🌿', 'Commencez votre voyage 🌿', 'Yolculuğuna başla 🌿', 'Mulakan perjalanan anda 🌿', 'Mulailah perjalanan Anda 🌿'))
      : (tLang(lang, 'التالي →', 'Next →', 'Suivant →', 'İleri →', 'Seterusnya →', 'Berikutnya →'));
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 12, 24, MediaQuery.of(context).padding.bottom + 20),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: ShineButton(
          key: ValueKey(isLast),
          label: label,
          onPressed: onNext,
          height: 58,
          colors: isLast
              ? const [Color(0xFFF0CF98), Color(0xFFDBA75D)]
              : const [Color(0xFF1E9E52), Color(0xFF0A6B4A)],
          textColor: isLast ? const Color(0xFF1A0F00) : Colors.white,
        ),
      ),
    );
  }
}

"""
def bottom_patch(s):
    if 'ShineButton(' in s: return s
    i = s.find('class _BottomBar extends ConsumerWidget {')
    j = s.find('class _OrbPainter extends CustomPainter {')
    if i < 0 or j < 0 or j < i: return None
    return s[:i] + NEW_BOTTOM + s[j:]
edit(ONB, bottom_patch, 'shine CTA button')

NEW_ORB = r"""class _OrbPainter extends CustomPainter {
  final double progress, pageProgress;
  final bool isDark;
  const _OrbPainter({
    required this.progress, required this.pageProgress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    void blob(Offset c, double r, Color col, double a) {
      canvas.drawCircle(
        c, r,
        Paint()..shader = RadialGradient(colors: [
          col.withOpacity(a), col.withOpacity(0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final g = Color.lerp(
        const Color(0xFF1E9E52), const Color(0xFF0E6B8A), pageProgress)!;
    const gold = Color(0xFFDBA75D);
    blob(Offset(w * (0.15 + 0.12 * sin(progress * pi)),
        h * (0.18 + 0.05 * cos(progress * pi))), w * 0.85, g,
        isDark ? 0.30 : 0.18);
    blob(Offset(w * (0.88 - 0.12 * cos(progress * pi)),
        h * (0.80 + 0.05 * sin(progress * pi))), w * 0.75, gold,
        isDark ? 0.20 : 0.13);
    blob(Offset(w * 0.5, h * (0.5 + 0.04 * sin(progress * pi))), w * 0.55, g,
        isDark ? 0.10 : 0.06);
  }

  @override
  bool shouldRepaint(_OrbPainter old) =>
    old.progress != progress || old.pageProgress != pageProgress ||
    old.isDark != isDark;
}

class _GlowBar extends StatelessWidget {
  final double value;
  final bool isDark;
  const _GlowBar({required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final track = isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF);
    return SizedBox(
      height: 8,
      child: LayoutBuilder(builder: (_, c) {
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: value),
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Stack(clipBehavior: Clip.none, children: [
            Container(
              height: 6,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: track, borderRadius: BorderRadius.circular(3)),
            ),
            Container(
              height: 6,
              margin: const EdgeInsets.only(top: 1),
              width: c.maxWidth * v.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(colors: [
                  Color(0xFF0A6B4A), Color(0xFF3FB950), Color(0xFFDBA75D),
                ]),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF3FB950).withOpacity(0.5),
                  blurRadius: 10)],
              ),
            ),
          ]),
        );
      }),
    );
  }
}
"""
def orb_patch(s):
    if '_GlowBar extends' in s: return s
    i = s.find('class _OrbPainter extends CustomPainter {')
    if i < 0: return None
    return s[:i] + NEW_ORB
edit(ONB, orb_patch, 'richer aurora background + glow progress bar class')

def topbar_patch(s):
    if '_GlowBar(value' in s: return s
    pat = re.compile(r"ClipRRect\(\s*borderRadius: BorderRadius\.circular\(4\),\s*child: LinearProgressIndicator\(.*?valueColor: const AlwaysStoppedAnimation\(AppColors\.halalGreen\),\s*\),\s*\),", re.S)
    if not pat.search(s): return None
    return pat.sub(lambda m: '_GlowBar(value: pct, isDark: isDark),', s, count=1)
edit(ONB, topbar_patch, 'glowing progress bar')

OLD_EMOJI = "Text(emoji, style: const TextStyle(fontSize: 40)),"
NEW_EMOJI = """TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (_, v, c) => Transform.scale(scale: v, child: c),
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [
                    AppColors.halalGreen.withOpacity(0.28),
                    AppColors.halalGreen.withOpacity(0.06),
                  ],
                ),
                border: Border.all(
                    color: AppColors.halalGreen.withOpacity(0.4), width: 0.8),
              ),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 32))),
            ),
          ),"""
edit(ONB, sub_once(OLD_EMOJI, NEW_EMOJI), 'question header badge')

# ───────────── version + sanity ─────────────────────────────────────────
edit('pubspec.yaml', sub_once('version: 1.3.0+16', 'version: 1.4.0+17'), 'version 1.4.0+17')

print('\n== sanity: brace balance ==')
bad = 0
for p in ['lib/core/fx2.dart', HOME, ONB]:
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
print('Next:  git add -A && git commit -m "v45: cinematic" && git push')
