// ════════════════════════════════════════════════════════════════════
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
