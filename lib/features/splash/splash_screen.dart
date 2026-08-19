// ════════════════════════════════════════════════════════════════════
//  splash_screen.dart — the first thing anyone sees
//
//  The logo drops in, turns a full circle and settles while leaves
//  drift up from the bottom and down from the top. The name and tagline
//  follow, then the screen hands over to the app.
//
//  The whole sequence is one controller driving several intervals, so
//  the beats stay in step no matter how fast the device is.
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/motion.dart';
import '../../core/providers.dart';
import '../../core/l10n.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _seq;
  late final AnimationController _halo;
  bool _leaving = false;

  // ── Sequence beats, all as fractions of the one controller ──
  late final Animation<double> _logoIn = CurvedAnimation(
      parent: _seq, curve: const Interval(0.00, 0.42, curve: Curves.easeOutBack));
  late final Animation<double> _spin = CurvedAnimation(
      parent: _seq, curve: const Interval(0.10, 0.68, curve: Curves.easeInOutCubic));
  late final Animation<double> _nameIn = CurvedAnimation(
      parent: _seq, curve: const Interval(0.46, 0.78, curve: Motion.curve));
  late final Animation<double> _taglineIn = CurvedAnimation(
      parent: _seq, curve: const Interval(0.58, 0.90, curve: Motion.curve));
  late final Animation<double> _ringIn = CurvedAnimation(
      parent: _seq, curve: const Interval(0.30, 1.00, curve: Motion.curve));

  @override
  void initState() {
    super.initState();
    _seq = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2300))
      ..forward();
    _halo = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat(reverse: true);

    _seq.addStatusListener((status) {
      if (status == AnimationStatus.completed) _leave();
    });
  }

  @override
  void dispose() {
    _seq.dispose();
    _halo.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    HapticFeedback.lightImpact();
    // A short hold on the finished frame reads as intentional rather
    // than as a stutter before the jump.
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    // The router's redirect sends first-run users to onboarding.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    final l = L.fromLang(lang);
    final isRamadan = ref.watch(ramadanModeProvider);

    final backdrop = isRamadan
        ? const [Color(0xFF0B0919), Color(0xFF171338), Color(0xFF090715)]
        : const [Color(0xFF06140C), Color(0xFF0C2A18), Color(0xFF04100A)];
    final accent =
        isRamadan ? AppColors.ramadanGold : AppColors.halalGreen;

    return Scaffold(
      body: GestureDetector(
        // Tapping through is a courtesy for the second launch onwards.
        onTap: _leave,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: backdrop,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(children: [
            // Leaves drifting both ways behind everything.
            Positioned.fill(
              child: DriftingLeaves(
                count: 18,
                color: accent,
                speed: 8,
                opacity: 0.9,
              ),
            ),

            // A soft bloom behind the mark.
            Center(
              child: AnimatedBuilder(
                animation: _halo,
                builder: (_, __) => Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      accent.withOpacity(0.10 + 0.10 * _halo.value),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),

            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Mark: scales in, turns once, settles ──
                  AnimatedBuilder(
                    animation: _seq,
                    builder: (_, child) {
                      final scale = 0.55 + 0.45 * _logoIn.value;
                      return Transform.scale(
                        scale: scale,
                        child: Transform.rotate(
                          angle: _spin.value * 2 * math.pi,
                          child: child,
                        ),
                      );
                    },
                    child: _Mark(accent: accent, ring: _ringIn, halo: _halo),
                  ),
                  const SizedBox(height: 26),

                  // ── Name ──
                  FadeTransition(
                    opacity: _nameIn,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(_nameIn),
                      child: Text(
                        l.appName,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                                color: accent.withOpacity(0.55),
                                blurRadius: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Tagline ──
                  FadeTransition(
                    opacity: _taglineIn,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.7),
                        end: Offset.zero,
                      ).animate(_taglineIn),
                      child: Text(
                        l.appTagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          height: 1.5,
                          color: Colors.white.withOpacity(0.66),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Loading line at the foot ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 54,
              child: FadeTransition(
                opacity: _ringIn,
                child: Center(
                  child: SizedBox(
                    width: 120,
                    child: AnimatedBar(
                      value: 1,
                      duration: const Duration(milliseconds: 2100),
                      color: accent,
                      background: Colors.white.withOpacity(0.10),
                      height: 3,
                      radius: 3,
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The logo plate: the asset when it loads, a drawn crescent-and-leaf
/// fallback when it does not, wrapped in an expanding ring.
class _Mark extends StatelessWidget {
  final Color accent;
  final Animation<double> ring;
  final Animation<double> halo;
  const _Mark({required this.accent, required this.ring, required this.halo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 156,
      child: Stack(alignment: Alignment.center, children: [
        // Expanding ring, drawn rather than imaged so it scales cleanly.
        AnimatedBuilder(
          animation: ring,
          builder: (_, __) => CustomPaint(
            size: const Size(156, 156),
            painter: _RingPainter(progress: ring.value, color: accent),
          ),
        ),
        // Logo plate.
        AnimatedBuilder(
          animation: halo,
          builder: (_, child) => Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.28 + 0.16 * halo.value),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                // A missing asset must never leave a blank splash.
                errorBuilder: (_, __, ___) => _FallbackMark(accent: accent),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _FallbackMark extends StatelessWidget {
  final Color accent;
  const _FallbackMark({required this.accent});

  @override
  Widget build(BuildContext context) => Center(
        child: Text('🌙',
            style: TextStyle(
              fontSize: 46,
              shadows: [Shadow(color: accent.withOpacity(0.6), blurRadius: 16)],
            )),
      );
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Sweeping arc that closes as the sequence completes.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color.withOpacity(0.75)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Eight points of light around the ring, lighting up in turn.
    for (var i = 0; i < 8; i++) {
      final lit = progress > (i / 8);
      if (!lit) continue;
      final angle = -math.pi / 2 + (i / 8) * 2 * math.pi;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * radius, math.sin(angle) * radius),
        2.2,
        Paint()..color = color.withOpacity(0.9),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
