#!/usr/bin/env python3
"""
patch_v44_studio_overhaul.py
============================
HalalCalorie v44 — "studio" visual + motion overhaul.

Run from the repo root (the folder containing pubspec.yaml):

    python3 patch_v44_studio_overhaul.py

Safe to run twice. Every edit to an existing file is anchored; if an
anchor is not found the step prints SKIP and the rest still applies.
No new dependencies, so no `flutter pub get` surprises.

WHAT CHANGES
------------
NEW  lib/core/fx.dart
     AuroraBackground  slow drifting light behind a screen
     GlassCard         gradient-edge surface with depth (ready for all screens)
     ShineButton       primary CTA, press-scale + glow + periodic light sweep
     BrandMark         vector crescent-and-leaf logo, crisp at any size
     AppGlyph          6 hand-drawn vector nav icons (replaces ⌂ ◈ ◉ ▲ ♡ ◯)

REWRITTEN
     shell.dart            floating glass nav bar, ONE pill that slides
                           between tabs, icons that lift and fill in
     splash_screen.dart    3-second cinematic: aurora, mark resolves from
                           bloom, ring traces with bright head, light sweep
                           across the logo, wordmark reveals letter by
                           letter, scene eases forward into the app
     paywall_screen.dart   aurora hero, staggered benefits, animated plan
                           cards, pinned CTA with glow. Purchase and restore
                           logic is identical to v43.

EDITED
     motion.dart           page transitions gain a subtle scale
     theme.dart            softer radii, InkSparkle touch ripples
     home_screen.dart      header uses the vector logo, header buttons are
                           real icons with press feedback, cards enter with
                           a springy scale, card corners/shadows upgraded
     all feature screens   corner-radius pass (14 -> 20, 12 -> 16)
     pubspec.yaml          1.2.1+15 -> 1.3.0+16

NOT TOUCHED (needs your art assets, see notes in chat)
     the launcher icon, store screenshots and the PNG illustration sets.
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


print('== v44 studio overhaul ==')

# ───────────────────────── 1. new + rewritten files ─────────────────────────
NEW_FILES = {
  'lib/core/fx.dart': r'''// ════════════════════════════════════════════════════════════════════
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
''',
  'lib/core/shell.dart': r'''// shell.dart — HalalCalorie — floating glass navigation (v44)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'theme.dart';
import 'l10n.dart';
import 'fx.dart';
import 'motion.dart';
import 'providers.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _slideIn.dispose();
    super.dispose();
  }

  static const _tabs = [
    _T('/home', Glyph.home),
    _T('/nutrition', Glyph.nutrition),
    _T('/fitness', Glyph.fitness),
    _T('/ascent', Glyph.ascent),
    _T('/health', Glyph.health),
    _T('/profile', Glyph.profile),
  ];

  int _idx(String loc) {
    if (loc.startsWith('/body') || loc.startsWith('/health')) return 4;
    if (loc.startsWith('/ascent')) return 3;
    if (loc.startsWith('/scanner')) return 1;
    for (int i = 0; i < _tabs.length; i++) {
      if (loc.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _idx(loc);
    final isDark = ref.watch(themeProvider);
    final lang = ref.watch(languageProvider);
    final isRamadan = ref.watch(ramadanModeProvider);

    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _slideIn, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _slideIn, curve: Motion.curve)),
          child: widget.child,
        ),
      ),
      bottomNavigationBar: _FloatingNav(
        tabs: _tabs,
        activeIdx: idx,
        isDark: isDark,
        isRamadan: isRamadan,
        l: L.fromLang(lang),
        onTap: (path) {
          HapticFeedback.selectionClick();
          if (path == '/ascent' && !ref.read(premiumProvider)) {
            context.push('/paywall');
            return;
          }
          context.go(path);
        },
      ),
    );
  }
}

class _FloatingNav extends StatelessWidget {
  final List<_T> tabs;
  final int activeIdx;
  final bool isDark, isRamadan;
  final L l;
  final void Function(String) onTap;
  const _FloatingNav({
    required this.tabs,
    required this.activeIdx,
    required this.isDark,
    required this.isRamadan,
    required this.l,
    required this.onTap,
  });

  String _label(String path) {
    switch (path) {
      case '/home':
        return l.navHome;
      case '/nutrition':
        return l.navNutrition;
      case '/fitness':
        return l.navFitness;
      case '/health':
        return l.navHealth;
      case '/ascent':
        return l.ascentNavLabel;
      default:
        return l.navProfile;
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = tabs.length;
    final accent = isRamadan ? AppColors.ramadanGold : AppColors.halalGreen;
    final inactive = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final bar = isDark ? const Color(0xFF0F1E18) : Colors.white;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: bar,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.55 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              if (isRamadan)
                BoxShadow(
                  color: accent.withOpacity(0.18),
                  blurRadius: 24,
                ),
            ],
          ),
          child: Stack(children: [
            // One pill that slides between tabs instead of one per tab.
            AnimatedAlign(
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutBack,
              alignment: AlignmentDirectional(-1 + 2 * activeIdx / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accent.withOpacity(isDark ? 0.24 : 0.20),
                          accent.withOpacity(isDark ? 0.10 : 0.08),
                        ],
                      ),
                      border: Border.all(
                          color: accent.withOpacity(0.28), width: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: _NavItem(
                      glyph: tabs[i].glyph,
                      label: _label(tabs[i].path),
                      active: i == activeIdx,
                      activeColor: accent,
                      inactiveColor: inactive,
                      onTap: () => onTap(tabs[i].path),
                    ),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Glyph glyph;
  final String label;
  final bool active;
  final Color activeColor, inactiveColor;
  final VoidCallback onTap;
  const _NavItem({
    required this.glyph,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: active ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, v, __) {
          final c = Color.lerp(inactiveColor, activeColor, v.clamp(0.0, 1.0))!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Transform.translate(
                offset: Offset(0, -2.5 * v),
                child: Transform.scale(
                  scale: 1 + 0.14 * v,
                  child: AppGlyph(glyph: glyph, color: c, t: v, size: 24),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: c,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _T {
  final String path;
  final Glyph glyph;
  const _T(this.path, this.glyph);
}
''',
  'lib/features/splash/splash_screen.dart': r'''// ════════════════════════════════════════════════════════════════════
//  splash_screen.dart — v44 cinematic launch
//
//  Aurora light fades up, the vector mark resolves out of a soft bloom
//  while a ring traces around it and a light sweep crosses the crescent.
//  The wordmark then reveals letter by letter, the tagline settles under
//  it, and the whole scene eases forward into the app.
//
//  One controller drives the sequence, so every beat stays in step on any
//  device. Tap to skip.
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000));
  late final AnimationController _exit = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _halo = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
    ..repeat(reverse: true);

  Animation<double> _iv(double a, double b, Curve c) =>
      CurvedAnimation(parent: _seq, curve: Interval(a, b, curve: c));

  late final Animation<double> _markIn = _iv(0.00, 0.38, Motion.curve);
  late final Animation<double> _ring = _iv(0.14, 0.70, Curves.easeInOutCubic);
  late final Animation<double> _sweep = _iv(0.40, 0.68, Curves.easeInOut);
  late final Animation<double> _name = _iv(0.42, 0.86, Curves.linear);
  late final Animation<double> _tag = _iv(0.68, 0.94, Motion.curve);

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _seq.forward();
    _seq.addStatusListener((s) {
      if (s == AnimationStatus.completed) _leave();
    });
  }

  @override
  void dispose() {
    _seq.dispose();
    _exit.dispose();
    _halo.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    HapticFeedback.lightImpact();
    await _exit.forward();
    if (!mounted) return;
    // The router's redirect sends first-run users to onboarding.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l = L.fromLang(ref.watch(languageProvider));
    final isRamadan = ref.watch(ramadanModeProvider);
    final accent = isRamadan ? AppColors.ramadanGold : AppColors.halalGreen;
    final base =
        isRamadan ? const Color(0xFF080615) : const Color(0xFF04100A);
    final auroraColors = isRamadan
        ? const [Color(0xFF5B3FD0), Color(0xFFE8B84B), Color(0xFF2B1B6B)]
        : const [Color(0xFF1E9E52), Color(0xFFDBA75D), Color(0xFF0E6B6B)];

    final exitScale = Tween<double>(begin: 1, end: 1.08)
        .animate(CurvedAnimation(parent: _exit, curve: Curves.easeInCubic));
    final exitFade = Tween<double>(begin: 1, end: 0)
        .animate(CurvedAnimation(parent: _exit, curve: Curves.easeIn));

    return Scaffold(
      backgroundColor: base,
      body: GestureDetector(
        onTap: _leave,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [
          Positioned.fill(
            child: AuroraBackground(
                base: base, colors: auroraColors, intensity: 1.1),
          ),
          Positioned.fill(
            child: DriftingLeaves(
                count: 14, color: accent, speed: 10, opacity: 0.5),
          ),
          FadeTransition(
            opacity: exitFade,
            child: ScaleTransition(
              scale: exitScale,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_seq, _halo]),
                      builder: (_, __) => Opacity(
                        opacity: _markIn.value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 0.72 + 0.28 * _markIn.value,
                          child: SizedBox(
                            width: 190,
                            height: 190,
                            child: CustomPaint(
                              painter: _StagePainter(
                                accent: accent,
                                ring: _ring.value,
                                sweep: _sweep.value,
                                glow: _halo.value,
                              ),
                              child: Center(
                                child: ShaderMask(
                                  blendMode: BlendMode.srcATop,
                                  shaderCallback: (r) => _sweepShader(
                                      r, _sweep.value),
                                  child: const BrandMark(size: 104),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    AnimatedBuilder(
                      animation: _seq,
                      builder: (_, __) =>
                          _Wordmark(text: l.appName, t: _name.value),
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _tag,
                      child: SlideTransition(
                        position: Tween<Offset>(
                                begin: const Offset(0, 0.6), end: Offset.zero)
                            .animate(_tag),
                        child: Text(
                          l.appTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 14,
                            letterSpacing: 0.4,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// A narrow band of white light travelling across the mark.
  Shader _sweepShader(Rect r, double p) {
    final x = -1.4 + 2.8 * p;
    return LinearGradient(
      begin: Alignment(x - 0.45, -0.7),
      end: Alignment(x + 0.45, 0.7),
      colors: [
        Colors.white.withOpacity(0),
        Colors.white.withOpacity(0.75),
        Colors.white.withOpacity(0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(r);
  }
}

/// Letters rise and fade in one after another.
class _Wordmark extends StatelessWidget {
  final String text;
  final double t;
  const _Wordmark({required this.text, required this.t});

  @override
  Widget build(BuildContext context) {
    final n = text.length;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++)
            Builder(builder: (_) {
              final p = ((t - i * 0.045) / 0.42).clamp(0.0, 1.0);
              final e = Curves.easeOutCubic.transform(p);
              return Opacity(
                opacity: e,
                child: Transform.translate(
                  offset: Offset(0, (1 - e) * 16),
                  child: Text(
                    text[i],
                    style: AppFonts.wordmark.copyWith(
                      fontSize: 36,
                      shadows: [
                        Shadow(
                            color: AppColors.halalGreen.withOpacity(0.55),
                            blurRadius: 24),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Soft bloom plus a ring that traces itself with a bright head.
class _StagePainter extends CustomPainter {
  final Color accent;
  final double ring, sweep, glow;
  const _StagePainter({
    required this.accent,
    required this.ring,
    required this.sweep,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;

    // Bloom.
    canvas.drawCircle(
      c,
      r * 1.15,
      Paint()
        ..shader = RadialGradient(colors: [
          accent.withOpacity(0.22 + 0.10 * glow),
          accent.withOpacity(0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 1.15)),
    );

    // Faint full track.
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(0.08),
    );

    if (ring <= 0) return;
    final sweepAngle = 2 * math.pi * ring;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweepAngle,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = accent.withOpacity(0.9),
    );

    // Bright head at the leading edge.
    final a = -math.pi / 2 + sweepAngle;
    final head = c + Offset(math.cos(a) * r, math.sin(a) * r);
    canvas.drawCircle(head, 5.5,
        Paint()..color = accent.withOpacity(0.35 * (1 - ring * 0.6)));
    canvas.drawCircle(head, 2.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.ring != ring || old.sweep != sweep || old.glow != glow;
}
''',
  'lib/features/paywall/paywall_screen.dart': r'''// ============================================================
//  paywall_screen.dart — HalalCalorie v44 premium redesign
//  Purchase / restore logic is unchanged from v43; this file only
//  replaces the presentation: aurora hero, staggered benefits,
//  animated plan cards and a pinned call-to-action.
// ============================================================
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import '../../core/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/providers.dart';
import '../../core/regional_pricing.dart';
import '../../core/revenuecat_service.dart';

const _gold = Color(0xFFDBA75D);
const _goldLight = Color(0xFFF0CF98);

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});
  @override
  ConsumerState<PaywallScreen> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<PaywallScreen> {
  int _selected = 1;
  bool _loading = false;
  bool _restoring = false;
  String? _errorMsg;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  bool get _isAr => ref.read(languageProvider) == 'ar';

  Future<void> _purchase(List<RCOffering> offerings) async {
    if (_loading || offerings.isEmpty) return;
    if (mounted) setState(() { _loading = true; _errorMsg = null; });
    final offering = offerings[_selected.clamp(0, offerings.length - 1)];
    final result = await RevenueCatService.purchase(offering);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      await ref.read(premiumProvider.notifier).onPurchaseSuccess();
      _showSuccess();
    } else if (!result.cancelled) {
      if (mounted) {
        setState(() => _errorMsg =
            result.error ?? 'Purchase failed. Please try again.');
      }
    }
  }

  Future<void> _restore() async {
    if (mounted) setState(() { _restoring = true; _errorMsg = null; });
    final result = await RevenueCatService.restore();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (result.success) {
      await ref.read(premiumProvider.notifier).onPurchaseSuccess();
      _showSuccess();
    } else {
      if (mounted) {
        setState(() =>
            _errorMsg = 'No previous purchases found for this account.');
      }
    }
  }

  void _showSuccess() {
    final isAr = _isAr;
    HapticFeedback.heavyImpact();
    _confetti.play();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            gravity: 0.3,
            colors: const [
              AppColors.brandGreen, AppColors.accentGold,
              AppColors.halalGreen, Colors.white,
              Color(0xFF4CAF50), Color(0xFFFFD700),
            ],
          ),
          AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28)),
            backgroundColor: const Color(0xFF0F1E18),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [_goldLight, _gold],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: [
                      BoxShadow(
                          color: _gold.withOpacity(0.5), blurRadius: 30),
                    ],
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      size: 56, color: Color(0xFF1A0F00)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isAr ? 'تهانينا! أصبحت عضواً بريميوم'
                     : 'Welcome to Premium',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 20,
                    fontWeight: FontWeight.w900, color: _goldLight),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'تم فتح جميع الميزات المميزة — شكراً لدعمك'
                    : 'Every premium feature is unlocked — thank you for your support',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 13,
                    color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 22),
              ShineButton(
                label: isAr ? 'لنبدأ' : "Let's go",
                height: 52,
                onPressed: () {
                  _confetti.stop();
                  Navigator.of(dialogCtx).pop();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    final offerings = ref.watch(rcOfferingsProvider);
    String t(String ar, String en) => isAr ? ar : en;

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFF050E0A),
        body: Stack(children: [
          const Positioned.fill(
            child: AuroraBackground(
              base: Color(0xFF050E0A),
              colors: [Color(0xFF1E9E52), _gold, Color(0xFF0E6B6B)],
              intensity: 0.9,
            ),
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _restoring ? null : _restore,
                    child: _restoring
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white54))
                        : Text(t('استعادة', 'Restore'),
                            style: const TextStyle(
                                fontFamily: 'Aligarh', fontSize: 13,
                                color: Colors.white60)),
                  ),
                ]),
              ),
              Expanded(
                child: offerings.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: _gold, strokeWidth: 3),
                  ),
                  error: (_, __) => _page(const [], lang, isAr, t),
                  data: (list) => _page(list, lang, isAr, t),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _page(List<RCOffering> offerings, String lang, bool isAr,
      String Function(String, String) t) {
    final feats = _features(isAr);
    return Column(children: [
      Expanded(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          children: [
            Reveal(index: 0, child: _hero(t)),
            const SizedBox(height: 26),
            for (var i = 0; i < feats.length; i++)
              Reveal(index: 2 + i, child: _featureRow(feats[i])),
            const SizedBox(height: 22),
            Reveal(
              index: 2 + feats.length,
              child: Text(
                t('اختر خطتك', 'Choose your plan'),
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 16,
                    fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 14),
            Reveal(
              index: 3 + feats.length,
              child: _plansList(offerings, isAr, lang),
            ),
          ],
        ),
      ),
      // Pinned: the price and the button never scroll out of reach.
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF050E0A).withOpacity(0),
              const Color(0xFF050E0A),
            ],
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSize(
            duration: Motion.quick,
            curve: Motion.curve,
            child: _errorMsg == null
                ? const SizedBox(width: double.infinity)
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.haramRed.withOpacity(0.10),
                      border: Border.all(
                          color: AppColors.haramRed.withOpacity(0.35)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(_errorMsg!,
                        style: const TextStyle(
                            fontFamily: 'Aligarh', fontSize: 12,
                            color: AppColors.haramRed)),
                  ),
          ),
          PulseGlow(
            color: _gold,
            minOpacity: 0.10,
            maxOpacity: 0.34,
            blur: 26,
            borderRadius: BorderRadius.circular(22),
            child: ShineButton(
              label: t('ابدأ بريميوم', 'Unlock Premium'),
              icon: Icons.workspace_premium_rounded,
              loading: _loading,
              onPressed: () => _purchase(offerings),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _badge(Icons.verified_rounded, t('١٠٠٪ حلال', '100% Halal')),
            const SizedBox(width: 18),
            _badge(Icons.lock_rounded, t('خصوصية', 'Private')),
            const SizedBox(width: 18),
            _badge(Icons.block_rounded, t('بلا ربا', 'No Riba')),
          ]),
          const SizedBox(height: 6),
          Text(
            t('مدفوعات آمنة • يمكن الإلغاء في أي وقت • لا رسوم خفية',
              'Secure payment • Cancel anytime • No hidden fees'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Aligarh', fontSize: 10.5,
                color: Colors.white38),
          ),
        ]),
      ),
    ]);
  }

  Widget _hero(String Function(String, String) t) {
    return Column(children: [
      const SizedBox(height: 4),
      PulseGlow(
        color: _gold,
        minOpacity: 0.16,
        maxOpacity: 0.46,
        blur: 40,
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              Colors.white.withOpacity(0.10),
              Colors.white.withOpacity(0.02),
            ]),
            border: Border.all(color: _gold.withOpacity(0.5), width: 1),
          ),
          child: const Center(child: BrandMark(size: 70)),
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withOpacity(0.55), width: 0.8),
          color: _gold.withOpacity(0.12),
        ),
        child: Text('PREMIUM',
            style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 2.4,
                color: _goldLight.withOpacity(0.95))),
      ),
      const SizedBox(height: 12),
      Text(t('كل ما تحتاجه لصحتك، حلالاً',
             'Everything for your health, halal'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Bravoon', fontSize: 26, height: 1.2,
              fontWeight: FontWeight.w700, color: Colors.white)),
      const SizedBox(height: 8),
      Text(t('حلال في كل لقمة • خطوة كل يوم',
             'Halal in every bite • a step every day'),
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontFamily: 'Aligarh', fontSize: 13,
              color: Colors.white60)),
    ]);
  }

  List<_Feat> _features(bool isAr) => isAr
      ? const [
          _Feat(Icons.monitor_weight_rounded,
              'نسبة الدهون الدقيقة ٪ + كتلة العضلات + LBM'),
          _Feat(Icons.photo_camera_rounded,
              'تحليل الجسم والطعام بالصورة — AI بلا حدود'),
          _Feat(Icons.qr_code_scanner_rounded,
              'ماسحات حلال غير محدودة (مقابل ٣ مجانية/يوم)'),
          _Feat(Icons.fitness_center_rounded,
              '١٨٠ خطة تمرين + رمضان + ما بعد الولادة'),
          _Feat(Icons.restaurant_menu_rounded,
              'مخطط وجبات AI مخصص لجسمك'),
          _Feat(Icons.biotech_rounded, 'تحليل تركيبة الجسم الكامل'),
          _Feat(Icons.cloud_off_rounded, 'يعمل بدون إنترنت + تاريخ كامل'),
        ]
      : const [
          _Feat(Icons.monitor_weight_rounded,
              'Exact body fat % + muscle mass + lean body mass'),
          _Feat(Icons.photo_camera_rounded,
              'Unlimited AI food & body photo analysis (vs 3 free/day)'),
          _Feat(Icons.qr_code_scanner_rounded,
              'Unlimited halal scans (vs 3 free/day)'),
          _Feat(Icons.fitness_center_rounded,
              '180 workouts + Ramadan + postnatal plans'),
          _Feat(Icons.restaurant_menu_rounded,
              'AI meal planner personalised to your body'),
          _Feat(Icons.biotech_rounded, 'Full body composition analysis'),
          _Feat(Icons.terrain_rounded,
              'Ascent progression, quests + weekly review'),
        ];

  Widget _featureRow(_Feat f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _gold.withOpacity(0.28),
                  _gold.withOpacity(0.08),
                ],
              ),
              border: Border.all(color: _gold.withOpacity(0.35), width: 0.6),
            ),
            child: Icon(f.icon, size: 21, color: _goldLight),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(f.text,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 13.5, height: 1.35,
                    color: Colors.white)),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.check_circle_rounded,
              color: AppColors.halalGreen, size: 19),
        ]),
      );

  Widget _plansList(List<RCOffering> offerings, bool isAr, String lang) {
    final fallback = _fallback(isAr, lang);
    final count = offerings.isNotEmpty ? offerings.length : fallback.length;
    return Column(children: [
      for (var idx = 0; idx < count; idx++)
        Builder(builder: (_) {
          final rc = offerings.isNotEmpty ? offerings[idx] : null;
          final fp = rc == null ? fallback[idx] : null;
          final title = rc != null ? (isAr ? rc.titleAr : rc.titleEn) : fp!.title;
          final price = rc?.priceString ?? fp!.price;
          final per = rc != null ? (isAr ? rc.periodAr : rc.periodEn) : fp!.per;
          final pop = rc?.isPopular ?? fp!.popular;
          final save = rc != null
              ? (isAr ? rc.savingsBadgeAr : rc.savingsBadgeEn)
              : fp!.save;
          return _planCard(
            idx: idx,
            title: title,
            price: price,
            per: per,
            popular: pop,
            save: save,
            lang: lang,
          );
        }),
    ]);
  }

  Widget _planCard({
    required int idx,
    required String title,
    required String price,
    required String per,
    required bool popular,
    required String? save,
    required String lang,
  }) {
    final sel = _selected == idx;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressFx(
        scale: 0.985,
        onTap: () => setState(() { _selected = idx; _errorMsg = null; }),
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: Motion.base,
            curve: Motion.curve,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: sel
                    ? [_gold.withOpacity(0.22), _gold.withOpacity(0.06)]
                    : [Colors.white.withOpacity(0.06),
                       Colors.white.withOpacity(0.02)],
              ),
              border: Border.all(
                color: sel ? _gold : Colors.white.withOpacity(0.12),
                width: sel ? 1.8 : 0.8,
              ),
              boxShadow: sel
                  ? [BoxShadow(color: _gold.withOpacity(0.25), blurRadius: 22)]
                  : const [],
            ),
            child: Row(children: [
              AnimatedContainer(
                duration: Motion.quick,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sel ? _gold : Colors.transparent,
                  border: Border.all(
                      color: sel ? _gold : Colors.white38, width: 1.5),
                ),
                child: AnimatedScale(
                  duration: Motion.quick,
                  curve: Curves.easeOutBack,
                  scale: sel ? 1 : 0,
                  child: const Icon(Icons.check_rounded,
                      size: 16, color: Color(0xFF1A0F00)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          fontFamily: 'Aligarh', fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: sel ? _goldLight : Colors.white)),
                  if (save != null && save.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(save,
                          style: const TextStyle(
                              fontFamily: 'Aligarh', fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentBright)),
                    ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(price,
                    style: const TextStyle(
                        fontFamily: 'Aligarh', fontSize: 17,
                        fontWeight: FontWeight.w900, color: Colors.white)),
                Text(per,
                    style: const TextStyle(
                        fontFamily: 'Aligarh', fontSize: 11,
                        color: Colors.white54)),
              ]),
            ]),
          ),
          if (popular)
            PositionedDirectional(
              top: -10,
              end: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                      colors: [_goldLight, _gold]),
                ),
                child: Text(
                  tLang(lang, 'الأكثر شعبية', 'Most Popular',
                      'Le plus populaire', 'En Popüler',
                      'Paling Popular', 'Paling Populer'),
                  style: const TextStyle(
                      fontFamily: 'Aligarh', fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A0F00)),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  List<_FP> _fallback(bool isAr, String lang) => [
        _FP(
          tLang(lang, 'شهري', 'Monthly', 'Mensuel', 'Aylık', 'Bulanan', 'Bulanan'),
          tLang(lang, '٢.٩٩ \$', '\$2.99', '\$2.99', '\$2.99', '\$2.99', '\$2.99'),
          tLang(lang, '/ شهر', '/ month', '/ mois', '/ ay', '/ bulan', '/ bulan'),
          false, null),
        _FP(
          tLang(lang, 'سنوي', 'Yearly', 'Annuel', 'Yıllık', 'Tahunan', 'Tahunan'),
          tLang(lang, '١٩.٩٩ \$', '\$19.99', '\$19.99', '\$19.99', '\$19.99', '\$19.99'),
          tLang(lang, '/ سنة', '/ year', '/ an', '/ yıl', '/ tahun', '/ tahun'),
          true,
          tLang(lang, 'وفّر ٤٤٪', 'Save 44%', 'Save 44%', 'Save 44%', 'Save 44%', 'Save 44%')),
      ];

  Widget _badge(IconData icon, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppColors.accentBright),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontFamily: 'Aligarh', fontSize: 11.5,
                color: Colors.white60)),
      ]);
}

class _Feat {
  final IconData icon;
  final String text;
  const _Feat(this.icon, this.text);
}

class _FP {
  final String title, price, per;
  final bool popular;
  final String? save;
  const _FP(this.title, this.price, this.per, this.popular, this.save);
}
''',
}
for p, c in NEW_FILES.items():
    write(p, c)

# ───────────────────────── 2. motion.dart: richer page transition ───────────
def motion_patch(s):
    i = s.find('/// Fade-through page transition')
    if i < 0: return None
    if 'begin: 0.985' in s: return s
    return s[:i] + """/// Fade-through page transition: fade, a hair of scale and a short rise.
Widget fadeThrough(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
  return FadeTransition(
    opacity: curved,
    child: ScaleTransition(
      scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    ),
  );
}
"""
edit('lib/core/motion.dart', motion_patch, 'richer page transition')

# ───────────────────────── 3. theme.dart ────────────────────────────────────
def theme_patch(s):
    if 'useMaterial3: true' not in s: return None
    s = s.replace('BorderRadius.circular(8)', 'BorderRadius.circular(14)')
    s = s.replace('BorderRadius.circular(12)', 'BorderRadius.circular(20)')
    if 'InkSparkle' not in s:
        s = s.replace('useMaterial3: true,',
                      'useMaterial3: true,\n    splashFactory: InkSparkle.splashFactory,')
    return s
edit('lib/core/theme.dart', theme_patch, 'softer radii + sparkle ripple')

# ───────────────────────── 4. home_screen.dart ──────────────────────────────
HOME = 'lib/features/home/home_screen.dart'

edit(HOME, sub_once("import '../../core/motion.dart';",
     "import '../../core/motion.dart';\nimport '../../core/fx.dart';"),
     'import fx.dart')

edit(HOME, sub_once("Text(isRamadan ? '🌙' : '🌿', style: const TextStyle(fontSize: 12)),",
     "BrandMark(size: 17, color: Colors.white),"),
     'vector logo in header pill')

OLD_ANIM = """Widget _anim(int i, Widget child) => FadeTransition(
opacity: _fade(i),
child: SlideTransition(position: _slide(i), child: child),
);"""
NEW_ANIM = """Widget _anim(int i, Widget child) => FadeTransition(
opacity: _fade(i),
child: SlideTransition(
position: _slide(i),
child: ScaleTransition(
scale: Tween<double>(begin: 0.94, end: 1.0).animate(CurvedAnimation(
parent: _stagger,
curve: Interval(i * 0.08, (i * 0.08 + 0.6).clamp(0.0, 1.0),
curve: Curves.easeOutBack),
)),
child: child,
),
),
);"""
edit(HOME, sub_once(OLD_ANIM, NEW_ANIM), 'springy card entrance')

NEW_ICONBTN = """class _IconBtn extends StatelessWidget {
  final String icon;
  final bool isDark;
  final bool isText;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.isDark,
    this.isText = false,
    required this.onTap,
  });

  IconData? get _data {
    switch (icon) {
      case '☀':
        return Icons.light_mode_rounded;
      case '☾':
        return Icons.dark_mode_rounded;
      case '⚙':
        return Icons.settings_rounded;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? AppColors.darkText : AppColors.lightText;
    final data = _data;
    return PressFx(
      onTap: onTap,
      scale: 0.88,
      haptics: false,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1B3327), Color(0xFF0F1E18)]
                : const [Color(0xFFFFFFFF), Color(0xFFEAF2EC)],
          ),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.6,
          ),
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (c, a) => RotationTransition(
              turns: Tween<double>(begin: 0.75, end: 1.0).animate(a),
              child: FadeTransition(opacity: a, child: c),
            ),
            child: data != null
                ? Icon(data, key: ValueKey(icon), size: 18, color: fg)
                : Text(
                    icon,
                    key: ValueKey(icon),
                    style: TextStyle(
                      fontFamily: isText ? 'Aligarh' : null,
                      fontSize: isText ? 11.5 : 15,
                      fontWeight: isText ? FontWeight.w800 : null,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
"""
def iconbtn_patch(s):
    i = s.find('class _IconBtn extends StatelessWidget {')
    if i < 0: return None
    if 'light_mode_rounded' in s: return s
    return s[:i] + NEW_ICONBTN
edit(HOME, iconbtn_patch, 'real icon buttons with press feedback')

# ───────────────────────── 5. card depth + radius pass ──────────────────────
CARD = re.compile(r"borderRadius:\s*BorderRadius\.circular\(14\),(\s*)border:\s*Border\.all\(color:\s*border,\s*width:\s*0\.5\),")
SHADOW = ("borderRadius: BorderRadius.circular(22),\\1"
          "border: Border.all(color: border, width: 0.5),\\1"
          "boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 22, offset: Offset(0, 8))],")
def card_patch(s):
    n = CARD.sub(SHADOW, s)
    return n
for p in (HOME, 'lib/features/onboarding/onboarding_screen.dart'):
    edit(p, card_patch, 'cards: bigger corners + soft shadow')

def radius_patch(s):
    s = s.replace('BorderRadius.circular(14)', 'BorderRadius.circular(20)')
    s = s.replace('BorderRadius.circular(12)', 'BorderRadius.circular(16)')
    return s
import glob
SWEEP_SKIP = ('paywall_screen.dart', 'splash_screen.dart')
for fp in sorted(glob.glob(path('lib/features/**/*.dart'), recursive=True)):
    rel = os.path.relpath(fp, ROOT).replace(os.sep, '/')
    if rel.endswith(SWEEP_SKIP): continue
    edit(rel, radius_patch, 'corner-radius pass')

# ───────────────────────── 6. version bump ──────────────────────────────────
edit('pubspec.yaml', sub_once('version: 1.2.1+15', 'version: 1.3.0+16'), 'version 1.3.0+16')

# ───────────────────────── 7. brace sanity check ────────────────────────────
print('\n== sanity: brace balance of every file this patch touched ==')
bad = 0
for p in list(NEW_FILES) + [HOME, 'lib/core/motion.dart', 'lib/core/theme.dart']:
    if not os.path.exists(path(p)): continue
    t = open(path(p), encoding='utf-8').read()
    # strip strings/comments crudely so braces inside text don't count
    t = re.sub(r"//[^\n]*", '', t)
    t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
    t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
    for a, b in ('{}', '()', '[]'):
        if t.count(a) != t.count(b):
            bad += 1
            print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
print('  all balanced' if not bad else '  !! fix the files above before building')

print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git diff --stat  &&  git add -A && git commit -m "v44: studio overhaul" && git push')
