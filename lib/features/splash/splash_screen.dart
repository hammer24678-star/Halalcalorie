// ════════════════════════════════════════════════════════════════════
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
