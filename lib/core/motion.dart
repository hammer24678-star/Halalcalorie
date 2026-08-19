// ════════════════════════════════════════════════════════════════════
//  motion.dart — the app's shared animation vocabulary
//
//  One place for timings, curves and the handful of motions used across
//  every screen, so animation stays consistent instead of each screen
//  inventing its own controller and easing.
//
//  Everything here is self-driving: drop a [Reveal] or [CountUp] in and
//  it animates itself, no controller plumbing at the call site.
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared timings. Keeping these in one place is what makes the app feel
/// like a single product rather than a pile of screens.
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const quick = Duration(milliseconds: 260);
  static const base = Duration(milliseconds: 380);
  static const slow = Duration(milliseconds: 620);
  static const lazy = Duration(milliseconds: 900);

  /// Gap between staggered children.
  static const stagger = Duration(milliseconds: 55);

  /// Standard easing: decisive out, gentle settle.
  static const curve = Curves.easeOutCubic;
  static const emphasis = Curves.easeOutBack;
  static const smooth = Curves.easeInOutCubic;
}

// ════════════════════════════════════════════════════════════════════
// ENTRANCE
// ════════════════════════════════════════════════════════════════════

/// Fades and lifts a child into place, offset by [index] so a column of
/// them cascades. Runs once when first built.
class Reveal extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;

  /// How far the child travels, as a fraction of its own height.
  final double offset;

  /// Set false to skip the slide and fade only.
  final bool slide;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = Motion.slow,
    this.offset = 0.10,
    this.slide = true,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _anim =
      CurvedAnimation(parent: _ctrl, curve: Motion.curve);

  @override
  void initState() {
    super.initState();
    final delay = Motion.stagger * widget.index;
    if (delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faded = FadeTransition(opacity: _anim, child: widget.child);
    if (!widget.slide) return faded;
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, widget.offset),
        end: Offset.zero,
      ).animate(_anim),
      child: faded,
    );
  }
}

/// Wraps each child of a list in a [Reveal] with an increasing index.
List<Widget> revealAll(List<Widget> children, {int from = 0}) => [
      for (var i = 0; i < children.length; i++)
        Reveal(index: from + i, child: children[i]),
    ];

// ════════════════════════════════════════════════════════════════════
// TOUCH
// ════════════════════════════════════════════════════════════════════

/// Scales down while pressed, so every tappable surface answers back.
class PressFx extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// How far it shrinks; 1.0 is no movement.
  final double scale;
  final bool haptics;
  final BorderRadius? borderRadius;

  const PressFx({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.haptics = true,
    this.borderRadius,
  });

  @override
  State<PressFx> createState() => _PressFxState();
}

class _PressFxState extends State<PressFx> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value || !mounted) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptics) HapticFeedback.lightImpact();
              widget.onTap?.call();
            }
          : null,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              if (widget.haptics) HapticFeedback.mediumImpact();
              widget.onLongPress!.call();
            },
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _down && enabled ? widget.scale : 1.0,
        duration: Motion.fast,
        curve: Motion.curve,
        child: widget.child,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// NUMBERS
// ════════════════════════════════════════════════════════════════════

/// Counts from the previous value to the new one whenever it changes, so
/// figures land rather than snap.
class CountUp extends StatelessWidget {
  final num value;
  final int decimals;
  final TextStyle? style;
  final String prefix, suffix;
  final Duration duration;
  final TextAlign? textAlign;

  const CountUp({
    super.key,
    required this.value,
    this.decimals = 0,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = Motion.lazy,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Motion.curve,
      builder: (_, v, __) => Text(
        '$prefix${v.toStringAsFixed(decimals)}$suffix',
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// A progress bar that eases to its value instead of jumping.
class AnimatedBar extends StatelessWidget {
  final double value;
  final Color color, background;
  final double height, radius;
  final Duration duration;

  const AnimatedBar({
    super.key,
    required this.value,
    required this.color,
    required this.background,
    this.height = 8,
    this.radius = 6,
    this.duration = Motion.lazy,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: duration,
        curve: Motion.curve,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: background,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// ATTENTION
// ════════════════════════════════════════════════════════════════════

/// A slow breathing glow, for things that are live or waiting on you.
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double minOpacity, maxOpacity, blur, spread;
  final bool enabled;
  final BorderRadius? borderRadius;

  const PulseGlow({
    super.key,
    required this.child,
    required this.color,
    this.minOpacity = 0.12,
    this.maxOpacity = 0.38,
    this.blur = 18,
    this.spread = 1,
    this.enabled = true,
    this.borderRadius,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, inner) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        final opacity =
            widget.minOpacity + (widget.maxOpacity - widget.minOpacity) * t;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            shape: widget.borderRadius == null
                ? BoxShape.circle
                : BoxShape.rectangle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(opacity),
                blurRadius: widget.blur,
                spreadRadius: widget.spread,
              ),
            ],
          ),
          child: inner,
        );
      },
      child: widget.child,
    );
  }
}

/// Sweeping highlight for loading placeholders.
class Shimmer extends StatefulWidget {
  final double width, height, radius;
  final Color base, highlight;

  const Shimmer({
    super.key,
    required this.width,
    required this.height,
    required this.base,
    required this.highlight,
    this.radius = 8,
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 - 2 * _ctrl.value, 0),
            end: Alignment(1 - 2 * _ctrl.value, 0),
            colors: [widget.base, widget.highlight, widget.base],
            stops: const [0.25, 0.5, 0.75],
          ),
        ),
      ),
    );
  }
}

/// A short celebratory bounce, played once when [trigger] changes.
class PopIn extends StatefulWidget {
  final Widget child;
  final Object? trigger;
  const PopIn({super.key, required this.child, this.trigger});

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Motion.slow,
  )..forward();

  @override
  void didUpdateWidget(PopIn old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
      ),
      child: widget.child,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// DECOR
// ════════════════════════════════════════════════════════════════════

/// Leaves drifting across the background. Used by the splash, and by any
/// screen that wants a little life behind its content.
class DriftingLeaves extends StatefulWidget {
  final int count;
  final Color color;

  /// Seconds for one leaf to cross the full height.
  final double speed;

  /// Leaves rise from the bottom as well as falling from the top.
  final bool bidirectional;
  final double opacity;

  const DriftingLeaves({
    super.key,
    this.count = 14,
    required this.color,
    this.speed = 9,
    this.bidirectional = true,
    this.opacity = 1,
  });

  @override
  State<DriftingLeaves> createState() => _DriftingLeavesState();
}

class _DriftingLeavesState extends State<DriftingLeaves>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.speed * 1000).round()),
  )..repeat();

  late final List<_Leaf> _leaves = List.generate(
    widget.count,
    (i) => _Leaf.seeded(i, widget.bidirectional),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _LeafPainter(
            leaves: _leaves,
            t: _ctrl.value,
            color: widget.color,
            opacity: widget.opacity,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Leaf {
  final double x, phase, scale, drift, spin;
  final bool rising;
  const _Leaf(this.x, this.phase, this.scale, this.drift, this.spin,
      this.rising);

  /// Deterministic per index, so the field is stable between rebuilds.
  factory _Leaf.seeded(int i, bool bidirectional) {
    final rand = math.Random(i * 7919 + 13);
    return _Leaf(
      rand.nextDouble(),
      rand.nextDouble(),
      0.6 + rand.nextDouble() * 0.9,
      (rand.nextDouble() - 0.5) * 0.22,
      (rand.nextDouble() - 0.5) * 4,
      bidirectional && i.isOdd,
    );
  }
}

class _LeafPainter extends CustomPainter {
  final List<_Leaf> leaves;
  final double t, opacity;
  final Color color;
  const _LeafPainter({
    required this.leaves,
    required this.t,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final leaf in leaves) {
      final progress = (t + leaf.phase) % 1.0;
      // Rising leaves travel bottom-to-top, falling ones top-to-bottom.
      final y = leaf.rising
          ? size.height * (1 - progress)
          : size.height * progress;
      final sway = math.sin(progress * math.pi * 3 + leaf.phase * 6);
      final x = size.width * (leaf.x + leaf.drift * sway);

      // Fade in and out at the edges so nothing pops.
      final edge = math.min(progress, 1 - progress) * 4;
      final alpha = (edge.clamp(0.0, 1.0)) * 0.55 * opacity;
      if (alpha <= 0.01) continue;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * leaf.spin + leaf.phase * 6);
      canvas.scale(leaf.scale);
      _drawLeaf(canvas, color.withOpacity(alpha));
      canvas.restore();
    }
  }

  /// A simple two-arc leaf with a centre vein.
  void _drawLeaf(Canvas canvas, Color c) {
    final path = Path()
      ..moveTo(0, -7)
      ..quadraticBezierTo(6, -2, 0, 7)
      ..quadraticBezierTo(-6, -2, 0, -7)
      ..close();
    canvas.drawPath(path, Paint()..color = c);
    canvas.drawLine(
      const Offset(0, -6),
      const Offset(0, 6),
      Paint()
        ..color = c.withOpacity(c.opacity * 0.5)
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool shouldRepaint(_LeafPainter old) =>
      old.t != t || old.color != color || old.opacity != opacity;
}

// ════════════════════════════════════════════════════════════════════
// ROUTES
// ════════════════════════════════════════════════════════════════════

/// Fade-through page transition, matching the shell's tab motion.
Widget fadeThrough(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondary,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Motion.curve),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Motion.curve)),
      child: child,
    ),
  );
}
