#!/usr/bin/env python3
"""
patch_v46_living_sky.py
=======================
HalalCalorie v46 - the Living Sky update. Run from the repo root:

    python3 patch_v46_living_sky.py

Needs v44 + v45 applied. Safe to run twice; no new dependencies.

NEW  lib/core/fx3.dart  -  LivingSky
     A hero window at the top of Home that shows the real sky from the
     user's own prayer times. Sky colour glides through night, fajr, sunrise,
     day, golden hour, maghrib, dusk and isha. The sun climbs from sunrise to
     its midday peak and sets at maghrib; the moon crosses the night. Stars
     twinkle in after dusk with an occasional shooting star, clouds drift by
     day, and a mosque skyline with minarets stands in front, its windows
     lighting up when it gets dark. A glass chip counts down to the next
     prayer. Falls back to sensible times until prayer times load.

UPDATED  lib/core/fx2.dart  -  HeroRing
     Reaching 100% of the calorie goal fires a shockwave ring, a burst of
     sparks and a firm haptic tap (ignored while saved data is loading).

EDITED  home_screen.dart  -  greeting becomes the Living Sky.
pubspec  1.4.0+17 -> 1.5.0+18
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



print('== v46 living sky ==')

NEW_FILES = {
'lib/core/fx3.dart': r'''// ════════════════════════════════════════════════════════════════════
//  fx3.dart — LivingSky (v46)
//
//  A window onto the real sky above the user, driven by their actual
//  prayer times. It moves for real:
//    · sky colour glides through night, fajr, sunrise, day, golden hour,
//      maghrib, dusk and isha
//    · the sun climbs from sunrise to its peak at midday and sets at
//      maghrib; the moon crosses the night
//    · stars twinkle in after dusk, with an occasional shooting star
//    · clouds drift by day; a mosque skyline with minarets sits in front,
//      its windows lighting up when it gets dark
//  Everything is painted in code. No images, no packages.
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'prayer_service.dart';

class LivingSky extends StatefulWidget {
  final PrayerTimes? times;
  final double height;
  final double radius;
  const LivingSky({
    super.key,
    required this.times,
    this.height = 236,
    this.radius = 28,
  });

  @override
  State<LivingSky> createState() => _LivingSkyState();
}

class _LivingSkyState extends State<LivingSky>
    with SingleTickerProviderStateMixin {
  static const _loop = 240;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _loop),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _SkyPainter(
                secs: _c.value * _loop,
                now: DateTime.now(),
                times: widget.times,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── schedule + sky colour model ─────────────────────────────────────

class _Sched {
  final double fajr, sunrise, dhuhr, asr, maghrib, isha;
  const _Sched(
      this.fajr, this.sunrise, this.dhuhr, this.asr, this.maghrib, this.isha);

  static const fallback = _Sched(300, 380, 750, 945, 1110, 1190);

  static double _m(DateTime d) => d.hour * 60.0 + d.minute;

  factory _Sched.of(PrayerTimes? t) {
    if (t == null) return fallback;
    final s = _Sched(_m(t.fajr), _m(t.sunrise), _m(t.dhuhr), _m(t.asr),
        _m(t.maghrib), _m(t.isha));
    final ok = s.fajr < s.sunrise &&
        s.sunrise < s.dhuhr &&
        s.dhuhr < s.asr &&
        s.asr < s.maghrib &&
        s.maghrib < s.isha &&
        s.isha < 1439;
    return ok ? s : fallback;
  }
}

class _Key {
  final double m;
  final Color top, bottom;
  final double stars;
  const _Key(this.m, this.top, this.bottom, this.stars);
}

class _Sky {
  final Color top, bottom;
  final double stars;
  const _Sky(this.top, this.bottom, this.stars);
}

List<_Key> _keys(_Sched s) {
  const nightTop = Color(0xFF050B1F);
  const nightBot = Color(0xFF111B3D);
  final k = <_Key>[
    const _Key(0, nightTop, nightBot, 1.0),
    _Key(s.fajr, const Color(0xFF1A1F4D), const Color(0xFF5B4A8C), 0.85),
    _Key((s.fajr + s.sunrise) / 2, const Color(0xFF3B3F86),
        const Color(0xFFE8927C), 0.35),
    _Key(s.sunrise, const Color(0xFF5C8FD6), const Color(0xFFFFC38A), 0.0),
    _Key(s.sunrise + 90, const Color(0xFF3E8BE0), const Color(0xFFAAD4F5), 0.0),
    _Key(s.dhuhr, const Color(0xFF2C7BE5), const Color(0xFF9CCBF7), 0.0),
    _Key(s.asr, const Color(0xFF3A83DA), const Color(0xFFCFDDE8), 0.0),
    _Key(s.maghrib - 40, const Color(0xFF5E7FC4), const Color(0xFFFFC774), 0.0),
    _Key(s.maghrib, const Color(0xFF4B3A8E), const Color(0xFFFF7A59), 0.1),
    _Key(s.maghrib + 30, const Color(0xFF1E2556), const Color(0xFF7C4A8C), 0.5),
    _Key(s.isha, const Color(0xFF0A1030), const Color(0xFF1B2450), 0.95),
    const _Key(1440, nightTop, nightBot, 1.0),
  ];
  k.sort((a, b) => a.m.compareTo(b.m));
  return k;
}

_Sky _sample(List<_Key> k, double m) {
  for (var i = 0; i < k.length - 1; i++) {
    final a = k[i], b = k[i + 1];
    if (m >= a.m && m <= b.m) {
      final d = b.m - a.m;
      final t = d <= 0.01
          ? 1.0
          : Curves.easeInOut.transform(((m - a.m) / d).clamp(0.0, 1.0));
      return _Sky(
        Color.lerp(a.top, b.top, t)!,
        Color.lerp(a.bottom, b.bottom, t)!,
        a.stars + (b.stars - a.stars) * t,
      );
    }
  }
  return _Sky(k.first.top, k.first.bottom, k.first.stars);
}

double _h(double x) {
  final v = math.sin(x * 12.9898) * 43758.5453;
  return v - v.floorToDouble();
}

// ── painter ─────────────────────────────────────────────────────────

class _SkyPainter extends CustomPainter {
  final double secs;
  final DateTime now;
  final PrayerTimes? times;
  const _SkyPainter(
      {required this.secs, required this.now, required this.times});

  @override
  void paint(Canvas canvas, Size size) {
    final sch = _Sched.of(times);
    final m = now.hour * 60.0 + now.minute + now.second / 60.0;
    final sky = _sample(_keys(sch), m);
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky.top, sky.bottom],
        ).createShader(rect),
    );

    _stars(canvas, size, sky);
    _shooting(canvas, size, sky);
    _celestial(canvas, size, sch, m);
    _clouds(canvas, size, sky);

    // Scrim so the greeting text always reads.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.34),
            Colors.black.withOpacity(0.0),
          ],
          stops: const [0.0, 0.62],
        ).createShader(rect),
    );

    final sil = Color.lerp(sky.bottom, const Color(0xFF04070D), 0.82)!;
    canvas.drawPath(
      _hill(size, 0.80, 0.035, 1.3, 0.6),
      Paint()..color = Color.lerp(sky.bottom, sil, 0.45)!.withOpacity(0.9),
    );
    canvas.drawPath(
      _hill(size, 0.85, 0.03, 1.9, 2.2),
      Paint()..color = Color.lerp(sky.bottom, sil, 0.7)!,
    );
    _skyline(canvas, size, sil, sky);
  }

  // stars ------------------------------------------------------------
  void _stars(Canvas c, Size s, _Sky sky) {
    if (sky.stars < 0.02) return;
    for (var i = 0; i < 48; i++) {
      final x = _h(i + 1.0) * s.width;
      final y = _h(i * 2.0 + 7) * s.height * 0.62;
      final tw = 0.55 + 0.45 * math.sin(secs * (0.7 + (i % 5) * 0.35) + i * 1.7);
      final a = (sky.stars * tw).clamp(0.0, 1.0);
      final r = 0.6 + _h(i * 3.0 + 2) * 1.1;
      c.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withOpacity(a));
      if (i % 8 == 0) {
        final L = 3 + r * 2.5;
        final p = Paint()
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(a * 0.7);
        c.drawLine(Offset(x - L, y), Offset(x + L, y), p);
        c.drawLine(Offset(x, y - L), Offset(x, y + L), p);
      }
    }
  }

  void _shooting(Canvas c, Size s, _Sky sky) {
    if (sky.stars < 0.5) return;
    const cycle = 22.0;
    final ph = (secs % cycle) / cycle;
    if (ph > 0.06) return;
    final u = ph / 0.06;
    final n = (secs / cycle).floor();
    final start = Offset(s.width * (0.12 + 0.22 * (n % 3)), s.height * 0.08);
    const dir = Offset(0.88, 0.48);
    final head = start + dir * (u * s.width * 0.55);
    final tail = head - dir * (70.0 * (1 - u * 0.4));
    final a = (1 - u) * sky.stars;
    c.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(tail, head, [
          Colors.white.withOpacity(0),
          Colors.white.withOpacity(a),
        ]),
    );
    c.drawCircle(head, 1.8, Paint()..color = Colors.white.withOpacity(a));
  }

  // sun / moon -------------------------------------------------------
  void _celestial(Canvas c, Size s, _Sched sch, double m) {
    final w = s.width, h = s.height;
    final horizon = h * 0.9;
    final peak = h * 0.22;

    if (m >= sch.sunrise && m <= sch.maghrib) {
      final p = (m - sch.sunrise) / (sch.maghrib - sch.sunrise);
      final elev = math.sin(math.pi * p);
      final pos = Offset(w * (0.12 + 0.76 * p), horizon - (horizon - peak) * elev);
      final low = 1 - elev;
      final core = Color.lerp(const Color(0xFFFFF6D6), const Color(0xFFFF8A3D),
          math.pow(low, 1.6).toDouble())!;
      final gr = h * (0.55 + 0.25 * low);
      c.drawCircle(
        pos,
        gr,
        Paint()
          ..shader = RadialGradient(colors: [
            core.withOpacity(0.55),
            core.withOpacity(0.0),
          ]).createShader(Rect.fromCircle(center: pos, radius: gr)),
      );
      c.drawCircle(pos, h * 0.1, Paint()..color = core.withOpacity(0.35));
      c.drawCircle(pos, h * 0.075, Paint()..color = core);
    } else {
      final span = (sch.sunrise + 1440) - sch.maghrib;
      final adv = m >= sch.maghrib ? m - sch.maghrib : m + 1440 - sch.maghrib;
      final p = (adv / span).clamp(0.0, 1.0);
      final vis = (math.min(p, 1 - p) * 8).clamp(0.0, 1.0);
      final pos = Offset(
          w * (0.12 + 0.76 * p), horizon - (horizon - peak * 1.1) * math.sin(math.pi * p));
      final r = h * 0.07;
      c.drawCircle(
        pos,
        r * 4.2,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFBFD4FF).withOpacity(0.33 * vis),
            const Color(0xFFBFD4FF).withOpacity(0.0),
          ]).createShader(Rect.fromCircle(center: pos, radius: r * 4.2)),
      );
      c.drawCircle(pos, r, Paint()..color = Colors.white.withOpacity(0.10 * vis));
      final outer = Path()..addOval(Rect.fromCircle(center: pos, radius: r));
      final cut = Path()
        ..addOval(Rect.fromCircle(
            center: pos + Offset(r * 0.5, -r * 0.2), radius: r * 0.9));
      c.drawPath(
        Path.combine(PathOperation.difference, outer, cut),
        Paint()..color = const Color(0xFFF6EFD2).withOpacity(vis),
      );
    }
  }

  // clouds -----------------------------------------------------------
  void _clouds(Canvas c, Size s, _Sky sky) {
    final w = s.width, h = s.height;
    final day = (1 - sky.stars).clamp(0.0, 1.0);
    final base = Color.lerp(Colors.white, sky.bottom, 0.25)!;
    final a = 0.10 + 0.5 * day;
    const puffs = [
      [-0.6, 0.10, 0.55],
      [0.0, -0.10, 0.75],
      [0.65, 0.08, 0.60],
      [0.15, 0.12, 0.70],
    ];
    for (var i = 0; i < 5; i++) {
      final x = ((i * 0.27 + secs * (0.004 + 0.0016 * i)) % 1.5 - 0.25) * w;
      final y = h * (0.12 + 0.09 * i);
      final sc = w * (0.16 + 0.03 * (i % 3));
      for (final p in puffs) {
        final ctr = Offset(x + p[0] * sc, y + p[1] * sc);
        final r = sc * p[2];
        c.drawCircle(
          ctr,
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              base.withOpacity(a),
              base.withOpacity(0.0),
            ]).createShader(Rect.fromCircle(center: ctr, radius: r)),
        );
      }
    }
  }

  // hills + skyline --------------------------------------------------
  Path _hill(Size s, double base, double amp, double f, double ph) {
    final p = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width; x += 6) {
      p.lineTo(
          x,
          s.height * base -
              amp * s.height * math.sin(x / s.width * f * math.pi * 2 + ph));
    }
    p
      ..lineTo(s.width, s.height)
      ..close();
    return p;
  }

  void _skyline(Canvas c, Size s, Color sil, _Sky sky) {
    final w = s.width, h = s.height;
    final gy = h * 0.90;
    final cx = w * 0.64;
    final p = Path()..addRect(Rect.fromLTRB(0, gy, w, h));

    const blocks = [
      [0.00, 0.10, 0.07],
      [0.10, 0.17, 0.11],
      [0.17, 0.25, 0.085],
      [0.25, 0.31, 0.13],
    ];
    for (final b in blocks) {
      p.addRect(Rect.fromLTRB(w * b[0], gy - h * b[2], w * b[1], gy));
    }

    // hall
    final hallTop = gy - h * 0.13;
    p.addRect(Rect.fromLTRB(cx - w * 0.15, hallTop, cx + w * 0.15, gy));

    void dome(double x, double r, double hh, double y) {
      p.moveTo(x - r, y);
      p.arcToPoint(Offset(x + r, y),
          radius: Radius.elliptical(r, hh), clockwise: true);
      p.close();
    }

    dome(cx, w * 0.115, h * 0.20, hallTop);
    dome(cx - w * 0.12, w * 0.04, h * 0.085, hallTop);
    dome(cx + w * 0.12, w * 0.04, h * 0.085, hallTop);
    final tip = hallTop - h * 0.20;
    p.addRect(Rect.fromLTRB(cx - 1.2, tip - h * 0.05, cx + 1.2, tip + 2));

    void minaret(double x, double hgt, double wid) {
      p.addRect(Rect.fromLTRB(x - wid / 2, gy - hgt, x + wid / 2, gy));
      p.addRect(Rect.fromLTRB(
          x - wid * 0.95, gy - hgt * 0.72, x + wid * 0.95, gy - hgt * 0.72 + 3));
      p.moveTo(x - wid * 0.75, gy - hgt);
      p.lineTo(x, gy - hgt - h * 0.08);
      p.lineTo(x + wid * 0.75, gy - hgt);
      p.close();
      p.addOval(Rect.fromCircle(center: Offset(x, gy - hgt - h * 0.085), radius: 2));
    }

    minaret(cx - w * 0.20, h * 0.50, w * 0.022);
    minaret(cx + w * 0.20, h * 0.42, w * 0.022);

    c.drawPath(p, Paint()..color = sil);

    // Windows glow once it is dark.
    if (sky.stars > 0.25) {
      final wp = Paint()
        ..color = const Color(0xFFFFD27A).withOpacity(0.9 * sky.stars);
      for (var i = 0; i < 5; i++) {
        final x = cx - w * 0.12 + i * w * 0.06;
        c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 2.5, gy - h * 0.095, 5, 10),
              const Radius.circular(2.5)),
          wp,
        );
      }
      for (final x in [w * 0.13, w * 0.21, w * 0.28]) {
        c.drawRect(Rect.fromLTWH(x - 1.5, gy - h * 0.05, 3, 5), wp);
      }
    }

    // Golden crescent on the dome.
    final cc = Offset(cx, tip - h * 0.075);
    final outer = Path()..addOval(Rect.fromCircle(center: cc, radius: 7));
    final cut = Path()
      ..addOval(Rect.fromCircle(center: cc + const Offset(2.6, -1.2), radius: 6));
    final cres = Path.combine(PathOperation.difference, outer, cut);
    if (sky.stars > 0.3) {
      c.drawCircle(
        cc,
        16,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFD27A).withOpacity(0.5 * sky.stars),
            const Color(0xFFFFD27A).withOpacity(0.0),
          ]).createShader(Rect.fromCircle(center: cc, radius: 16)),
      );
    }
    c.drawPath(cres, Paint()..color = const Color(0xFFF0CF98));
  }

  @override
  bool shouldRepaint(_SkyPainter old) => true;
}
''',
'lib/core/fx2.dart': r'''// ════════════════════════════════════════════════════════════════════
//  fx2.dart — cinematic kit (v45)
//
//  HeroRing      the Home calorie ring: tick dial, gradient arc with a
//                glowing head, breathing core, overflow arc past 100%
//  OnboardScene  three looping hero scenes drawn in code:
//                  0 brand orbit, 1 scan viewfinder, 2 moon + prayer dial
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat(reverse: true);

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  final DateTime _born = DateTime.now();

  @override
  void didUpdateWidget(HeroRing old) {
    super.didUpdateWidget(old);
    // Goal reached: shockwave, sparks and a firm tap. Ignored during the
    // first moments so loading saved data never fires it on app open.
    final settled = DateTime.now().difference(_born).inMilliseconds > 2500;
    if (settled && old.pct < 1.0 && widget.pct >= 1.0) {
      HapticFeedback.mediumImpact();
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.ringAnim, _breath, _burst]),
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
                burst: _burst.value,
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
  final double pct, breath, burst;
  final Color color;
  final bool isDark;
  const _HeroRingPainter({
    required this.pct,
    required this.color,
    required this.isDark,
    required this.breath,
    required this.burst,
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

    _burstFx(canvas, c, rArc);
  }

  void _burstFx(Canvas canvas, Offset c, double rArc) {
    if (burst <= 0 || burst >= 1) return;
    final e = Curves.easeOutCubic.transform(burst);
    final fade = 1 - burst;
    canvas.drawCircle(
      c,
      rArc + 56 * e,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * fade + 0.4
        ..color = color.withOpacity(0.65 * fade),
    );
    const n = 36;
    for (var i = 0; i < n; i++) {
      final jitter = ((i * 37) % 11) / 11.0;
      final a = 2 * math.pi * i / n + jitter * 0.3;
      final speed = 0.55 + 0.9 * jitter;
      final dist = rArc * 0.9 + 60 * speed * e;
      final pos = c +
          Offset(math.cos(a) * dist, math.sin(a) * dist + 26 * burst * burst);
      final col = i % 3 == 0
          ? const Color(0xFFF0CF98)
          : (i % 3 == 1 ? color : Colors.white);
      canvas.drawCircle(pos, (2.6 + 2.2 * jitter) * fade,
          Paint()..color = col.withOpacity(fade));
    }
  }

  @override
  bool shouldRepaint(_HeroRingPainter old) =>
      old.pct != pct ||
      old.burst != burst ||
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
''',
}
for p, c in NEW_FILES.items():
    write(p, c)

HOME = 'lib/features/home/home_screen.dart'

edit(HOME, sub_once("import '../../core/fx2.dart';",
     "import '../../core/fx2.dart';\nimport '../../core/fx3.dart';"), 'import fx3.dart')

HERO = r'''class _HomeHero extends ConsumerWidget {
  final bool isAr, isDark;
  final String lang;
  final int streak;
  final Color card, border;
  const _HomeHero({
    required this.isAr, required this.isDark, required this.lang,
    required this.streak, required this.card, required this.border,
  });

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return tLang(lang, 'ليلة سعيدة', 'Good night', 'Bonne nuit', 'İyi geceler', 'Selamat malam', 'Selamat malam');
    if (h < 12) return tLang(lang, 'صباح الخير', 'Good morning', 'Bonjour', 'Günaydın', 'Selamat pagi', 'Selamat pagi');
    if (h < 17) return tLang(lang, 'مساء الخير', 'Good afternoon', 'Bon après-midi', 'İyi günler', 'Selamat tengah hari', 'Selamat siang');
    return tLang(lang, 'مساء الخير', 'Good evening', 'Bonsoir', 'İyi akşamlar', 'Selamat petang', 'Selamat malam');
  }

  String _dateStr(DateTime now) {
    const wkAr = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const wkEn = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const moAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    const moEn = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final wk = isAr ? wkAr[now.weekday - 1] : wkEn[now.weekday - 1];
    final mo = isAr ? moAr[now.month - 1] : moEn[now.month - 1];
    return isAr ? '$wk، ${now.day} $mo' : '$wk, $mo ${now.day}';
  }

  Widget _glass(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.30),
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 0.7),
          borderRadius: BorderRadius.circular(100),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final times = ref.watch(prayerTimesProvider)
        .maybeWhen(data: (t) => t, orElse: () => null);

    String? nextChip;
    if (times != null) {
      final list = [
        ('الفجر', 'Fajr', times.fajr),
        ('الظهر', 'Dhuhr', times.dhuhr),
        ('العصر', 'Asr', times.asr),
        ('المغرب', 'Maghrib', times.maghrib),
        ('العشاء', 'Isha', times.isha),
      ];
      DateTime? nx;
      var nAr = 'الفجر';
      var nEn = 'Fajr';
      for (final e in list) {
        if (e.$3.isAfter(now)) {
          nx = e.$3;
          nAr = e.$1;
          nEn = e.$2;
          break;
        }
      }
      nx ??= times.fajr.add(const Duration(days: 1));
      final d = nx.difference(now);
      final hs = d.inHours > 0 ? '${d.inHours}h ' : '';
      nextChip = '${isAr ? nAr : nEn} · $hs${d.inMinutes % 60}m';
    }

    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 12)];

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(children: [
          LivingSky(times: times, height: 236, radius: 28),
          PositionedDirectional(
            top: 16, start: 20,
            child: Text(_dateStr(now), style: const TextStyle(
                fontFamily: 'Aligarh', fontSize: 12.5,
                color: Colors.white70, shadows: shadow)),
          ),
          if (streak > 0)
            PositionedDirectional(
              top: 10, end: 12,
              child: _glass(Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  tLang(lang, '$streak يوم تتابع', '$streak day streak',
                      '$streak jours de suite', '$streak gün seri',
                      '$streak hari berturut', '$streak hari berturut'),
                  style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 12.5,
                    fontWeight: FontWeight.w800, color: Color(0xFFF0CF98),
                  ),
                ),
              ])),
            ),
          PositionedDirectional(
            top: 38, start: 20, end: 20,
            child: Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Text(
                _greeting(now),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: lang == 'ar' ? 'LemonBrush' : 'Bravoon',
                  fontWeight: FontWeight.w700,
                  fontSize: 40,
                  height: 1.0,
                  color: Colors.white,
                  shadows: shadow,
                ),
              ),
            ),
          ),
          if (nextChip != null)
            PositionedDirectional(
              bottom: 12, start: 14,
              child: _glass(Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.access_time_rounded,
                    size: 13, color: Colors.white70),
                const SizedBox(width: 6),
                Text(nextChip, style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 12.5,
                    fontWeight: FontWeight.w800, color: Colors.white)),
              ])),
            ),
        ]),
      ),
    );
  }
}

'''

def hero_patch(s):
    if 'LivingSky(' in s: return s
    i = s.find('class _HomeHero extends StatelessWidget {')
    if i < 0: return None
    j = s.find('// \u2550\u2550\u2550', i)
    if j < 0: return None
    return s[:i] + HERO + s[j:]
edit(HOME, hero_patch, 'greeting becomes the Living Sky')

edit('pubspec.yaml', sub_once('version: 1.4.0+17', 'version: 1.5.0+18'), 'version 1.5.0+18')

print('\n== sanity: brace balance ==')
bad = 0
for p in ['lib/core/fx2.dart', 'lib/core/fx3.dart', HOME]:
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
print('Next:  git add -A && git commit -m "v46: living sky" && git push')
