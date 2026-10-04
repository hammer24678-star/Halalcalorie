// ════════════════════════════════════════════════════════════════════
//  fx6.dart — small premium controls (v48)
//    PillSwitch    animated toggle with glow and a springy thumb
//    GlassIconBtn  rounded translucent icon button with press feedback
//    AvatarRing    avatar framed by a slowly turning gradient ring
//    IconBadge     gradient tile holding a vector icon
// ════════════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'motion.dart';

class PillSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  const PillSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: value
              ? LinearGradient(colors: [
                  Color.lerp(color, Colors.white, 0.25)!,
                  color,
                ])
              : null,
          color: value ? null : Colors.grey.withOpacity(0.30),
          boxShadow: value
              ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 12)]
              : const [],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          alignment: value
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 4,
                    offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassIconBtn extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback onTap;
  final bool isDark;
  final double size;
  const GlassIconBtn({
    super.key,
    this.icon,
    this.child,
    required this.onTap,
    required this.isDark,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF1F2A1F);
    return PressFx(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.34),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF1B3327), Color(0xFF0F1E18)]
                : const [Color(0xFFFFFFFF), Color(0xFFEAF2EC)],
          ),
          border: Border.all(
            color: isDark ? const Color(0x2B94C9A9) : const Color(0x1F1B2420),
            width: 0.6,
          ),
        ),
        child: Center(
          child: child ?? Icon(icon, size: 20, color: fg),
        ),
      ),
    );
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.30), color.withOpacity(0.08)],
        ),
        border: Border.all(color: color.withOpacity(0.38), width: 0.7),
      ),
      child: Icon(icon, size: size * 0.53, color: color),
    );
  }
}

class AvatarRing extends StatefulWidget {
  final Widget child;
  final double size;
  final List<Color> colors;
  final Color gap;
  const AvatarRing({
    super.key,
    required this.child,
    required this.colors,
    required this.gap,
    this.size = 112,
  });

  @override
  State<AvatarRing> createState() => _AvatarRingState();
}

class _AvatarRingState extends State<AvatarRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(alignment: Alignment.center, children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Transform.rotate(
              angle: 2 * math.pi * _c.value,
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [...widget.colors, widget.colors.first],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.colors.first.withOpacity(0.35),
                      blurRadius: 26,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          width: s - 8,
          height: s - 8,
          decoration: BoxDecoration(color: widget.gap, shape: BoxShape.circle),
        ),
        ClipOval(
          child: SizedBox(width: s - 14, height: s - 14, child: widget.child),
        ),
      ]),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// EMOJI → VECTOR ICON
// ────────────────────────────────────────────────────────────────────

/// Renders a UI-symbol emoji as a crisp vector icon in a fitting colour.
/// Anything not in the table (foods, flags, faces) falls back to plain text,
/// so it is always safe to use in place of `Text(emoji)`.
class EmojiIcon extends StatelessWidget {
  final String emoji;
  final double size;
  final Color? color;
  const EmojiIcon(this.emoji, {super.key, this.size = 22, this.color});

  static const _t = <String, (IconData, Color)>{
    '💪': (Icons.fitness_center_rounded, Color(0xFF3FB950)),
    '✓': (Icons.check_rounded, Color(0xFF3FB950)),
    '✅': (Icons.check_circle_rounded, Color(0xFF3FB950)),
    '⚠': (Icons.warning_amber_rounded, Color(0xFFD1812A)),
    '⭐': (Icons.star_rounded, Color(0xFFDBA75D)),
    '🌟': (Icons.stars_rounded, Color(0xFFDBA75D)),
    '💧': (Icons.water_drop_rounded, Color(0xFF6FB3FF)),
    '🌿': (Icons.eco_rounded, Color(0xFF3FB950)),
    '🌱': (Icons.spa_rounded, Color(0xFF3FB950)),
    '🔥': (Icons.local_fire_department_rounded, Color(0xFFFF8A3D)),
    '🔒': (Icons.lock_rounded, Color(0xFF8BA095)),
    '🔓': (Icons.lock_open_rounded, Color(0xFFDBA75D)),
    '📊': (Icons.bar_chart_rounded, Color(0xFF6FB3FF)),
    '📈': (Icons.trending_up_rounded, Color(0xFF3FB950)),
    '🌙': (Icons.nights_stay_rounded, Color(0xFFDBA75D)),
    '🌘': (Icons.nights_stay_rounded, Color(0xFFDBA75D)),
    '✨': (Icons.auto_awesome_rounded, Color(0xFFF0CF98)),
    '🤖': (Icons.smart_toy_rounded, Color(0xFF6FB3FF)),
    '⚡': (Icons.bolt_rounded, Color(0xFFF2C94C)),
    '💡': (Icons.lightbulb_outline_rounded, Color(0xFFF2C94C)),
    '🏆': (Icons.emoji_events_rounded, Color(0xFFDBA75D)),
    '🏅': (Icons.military_tech_rounded, Color(0xFFDBA75D)),
    '🧬': (Icons.biotech_rounded, Color(0xFFBC8CFF)),
    '🔬': (Icons.science_rounded, Color(0xFFBC8CFF)),
    '🧪': (Icons.science_rounded, Color(0xFFBC8CFF)),
    '🧠': (Icons.psychology_rounded, Color(0xFFBC8CFF)),
    '☀': (Icons.wb_sunny_rounded, Color(0xFFF2C94C)),
    '📖': (Icons.menu_book_rounded, Color(0xFFDBA75D)),
    '📘': (Icons.menu_book_rounded, Color(0xFF6FB3FF)),
    '✏': (Icons.edit_rounded, Color(0xFF3FB950)),
    '🔔': (Icons.notifications_rounded, Color(0xFFD1812A)),
    '🍽': (Icons.restaurant_rounded, Color(0xFFDBA75D)),
    '🎯': (Icons.track_changes_rounded, Color(0xFFEF6A60)),
    '📷': (Icons.photo_camera_rounded, Color(0xFF6FB3FF)),
    '📸': (Icons.photo_camera_rounded, Color(0xFF6FB3FF)),
    '✕': (Icons.close_rounded, Color(0xFF8BA095)),
    '❌': (Icons.cancel_rounded, Color(0xFFEF6A60)),
    '🏃': (Icons.directions_run_rounded, Color(0xFF3FB950)),
    '🚶': (Icons.directions_walk_rounded, Color(0xFF3FB950)),
    '🚴': (Icons.pedal_bike_rounded, Color(0xFF3FB950)),
    '🏊': (Icons.pool_rounded, Color(0xFF6FB3FF)),
    '🧘': (Icons.self_improvement_rounded, Color(0xFFBC8CFF)),
    '🏋': (Icons.fitness_center_rounded, Color(0xFF3FB950)),
    '😴': (Icons.bedtime_rounded, Color(0xFFBC8CFF)),
    '🔍': (Icons.search_rounded, Color(0xFF8BA095)),
    '🦴': (Icons.accessibility_new_rounded, Color(0xFFDBA75D)),
    '🎁': (Icons.card_giftcard_rounded, Color(0xFFEF6A60)),
    '👍': (Icons.thumb_up_rounded, Color(0xFF3FB950)),
    '🤍': (Icons.favorite_border_rounded, Color(0xFF8BA095)),
    '❤': (Icons.favorite_rounded, Color(0xFFEF6A60)),
    '⚖': (Icons.scale_rounded, Color(0xFF6FB3FF)),
    '🌐': (Icons.language_rounded, Color(0xFF6FB3FF)),
    '📡': (Icons.sensors_rounded, Color(0xFF6FB3FF)),
    '🎂': (Icons.cake_rounded, Color(0xFFEF6A60)),
    '🤲': (Icons.volunteer_activism_rounded, Color(0xFFDBA75D)),
    '🖼': (Icons.image_rounded, Color(0xFF8BA095)),
    '📐': (Icons.square_foot_rounded, Color(0xFF6FB3FF)),
    '📏': (Icons.straighten_rounded, Color(0xFF6FB3FF)),
    '⚙': (Icons.settings_rounded, Color(0xFF8BA095)),
    '🗂': (Icons.folder_rounded, Color(0xFFDBA75D)),
    '🕌': (Icons.mosque_rounded, Color(0xFFDBA75D)),
    '☾': (Icons.dark_mode_rounded, Color(0xFFBC8CFF)),
    '😊': (Icons.sentiment_satisfied_alt_rounded, Color(0xFF3FB950)),
    '🙂': (Icons.sentiment_satisfied_rounded, Color(0xFF3FB950)),
    '😐': (Icons.sentiment_neutral_rounded, Color(0xFFD1812A)),
    '😞': (Icons.sentiment_dissatisfied_rounded, Color(0xFFEF6A60)),
    '😔': (Icons.sentiment_dissatisfied_rounded, Color(0xFFEF6A60)),
    '🚫': (Icons.block_rounded, Color(0xFFEF6A60)),
    '🎉': (Icons.celebration_rounded, Color(0xFFF2C94C)),
    '🌇': (Icons.wb_twilight_rounded, Color(0xFFFF8A3D)),
    '🌅': (Icons.wb_twilight_rounded, Color(0xFFFF8A3D)),
    '🌄': (Icons.wb_twilight_rounded, Color(0xFFFF8A3D)),
    '★': (Icons.star_rounded, Color(0xFFDBA75D)),
    '📅': (Icons.event_rounded, Color(0xFF6FB3FF)),
    '📍': (Icons.location_on_rounded, Color(0xFFEF6A60)),
    '🚪': (Icons.logout_rounded, Color(0xFFEF6A60)),
    '🔗': (Icons.link_rounded, Color(0xFF6FB3FF)),
    '⛰': (Icons.terrain_rounded, Color(0xFF8BA095)),
    '💎': (Icons.auto_awesome_rounded, Color(0xFF6FB3FF)),
    '📱': (Icons.smartphone_rounded, Color(0xFF8BA095)),
    '🔄': (Icons.sync_rounded, Color(0xFF6FB3FF)),
    '⬇': (Icons.arrow_downward_rounded, Color(0xFF3FB950)),
    '⬆': (Icons.arrow_upward_rounded, Color(0xFFEF6A60)),
    '🗑': (Icons.delete_rounded, Color(0xFFEF6A60)),
    '🗺': (Icons.map_rounded, Color(0xFF6FB3FF)),
    '📋': (Icons.assignment_rounded, Color(0xFFDBA75D)),
    '🩸': (Icons.bloodtype_rounded, Color(0xFFEF6A60)),
    '🫁': (Icons.air_rounded, Color(0xFF6FB3FF)),
    '🍴': (Icons.restaurant_rounded, Color(0xFF3FB950)),
    '🍀': (Icons.eco_rounded, Color(0xFF3FB950)),
    '🥩': (Icons.set_meal_rounded, Color(0xFFEF6A60)),
    '🍚': (Icons.rice_bowl_rounded, Color(0xFFDBA75D)),
    '🥑': (Icons.eco_rounded, Color(0xFF3FB950)),
    '🌾': (Icons.grass_rounded, Color(0xFFDBA75D)),
    '🧕': (Icons.person_rounded, Color(0xFFDBA75D)),
    '🧔': (Icons.person_rounded, Color(0xFF3FB950)),
    '🧑': (Icons.person_rounded, Color(0xFF3FB950)),
    '🧍': (Icons.accessibility_new_rounded, Color(0xFF3FB950)),
    '👕': (Icons.checkroom_rounded, Color(0xFF6FB3FF)),
  };

  @override
  Widget build(BuildContext context) {
    final key = emoji.replaceAll('\uFE0F', '').trim();
    final m = _t[key];
    if (m == null) {
      return Text(emoji, style: TextStyle(fontSize: size));
    }
    return Icon(m.$1, size: size * 1.04, color: color ?? m.$2);
  }
}
