// premium_ui.dart — HalalCalorie v56 (PATCH_V56_PREMIUM_UI)
// Small shared widgets for the Premium Studio screens.
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

const Color kGold = Color(0xFFDBA75D);
const Color kGoldLight = Color(0xFFF0CF98);

class PTheme {
  final bool isDark;
  const PTheme(this.isDark);
  Color get bg => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get card => isDark ? AppColors.darkCard : Colors.white;
  Color get cardAlt => isDark ? AppColors.darkCardAlt : AppColors.lightCardAlt;
  Color get text => isDark ? AppColors.darkText : AppColors.lightText;
  Color get muted => isDark ? AppColors.darkMuted : AppColors.lightMuted;
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;
}

TextStyle pText(Color c, double size, {FontWeight w = FontWeight.w600, double? h}) =>
    TextStyle(fontFamily: 'Aligarh', fontSize: size, fontWeight: w, color: c, height: h);

class PCard extends StatelessWidget {
  final Widget child;
  final PTheme th;
  final bool gold;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const PCard({
    super.key,
    required this.child,
    required this.th,
    this.gold = false,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gold ? null : th.card,
        gradient: gold
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  kGold.withOpacity(th.isDark ? 0.22 : 0.20),
                  kGold.withOpacity(th.isDark ? 0.06 : 0.07),
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: gold ? kGold.withOpacity(0.45) : th.border, width: 0.8),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: box,
      ),
    );
  }
}

class PSection extends StatelessWidget {
  final String label;
  final PTheme th;
  const PSection(this.label, this.th, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
                color: kGold, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Text(label, style: pText(th.muted, 12, w: FontWeight.w800)),
        ]),
      );
}

class PGoldButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool outlined;
  const PGoldButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = outlined ? kGold : const Color(0xFF1A0F00);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: outlined
                ? null
                : const LinearGradient(colors: [kGoldLight, kGold]),
            border: outlined ? Border.all(color: kGold, width: 1) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: pText(fg, 14, w: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const PPill(this.text, this.color, {super.key, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4), width: 0.7),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(text, style: pText(color, 11, w: FontWeight.w800)),
        ]),
      );
}

/// Shows [child] blurred behind a lock when [locked]. Tapping the lock calls
/// [onUnlock]. The content underneath is the person's own data, which is the
/// most honest preview of what Premium adds.
class PLocked extends StatelessWidget {
  final bool locked;
  final Widget child;
  final VoidCallback onUnlock;
  final String label;
  final PTheme th;
  const PLocked({
    super.key,
    required this.locked,
    required this.child,
    required this.onUnlock,
    required this.label,
    required this.th,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return Stack(children: [
      IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Opacity(opacity: 0.55, child: child),
        ),
      ),
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onUnlock,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: th.card.withOpacity(0.92),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: kGold, width: 1),
                boxShadow: [
                  BoxShadow(
                      color: kGold.withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded, size: 16, color: kGold),
                const SizedBox(width: 8),
                Text(label, style: pText(kGold, 13, w: FontWeight.w800)),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

void openPaywall(BuildContext context) => context.push('/paywall');

/// Round gold icon badge used on the hub tiles and headers.
class PBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;
  const PBadge(this.icon, {super.key, this.size = 44, this.color = kGold});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.30), color.withOpacity(0.08)],
          ),
          border: Border.all(color: color.withOpacity(0.4), width: 0.7),
        ),
        child: Icon(icon, size: size * 0.5, color: color),
      );
}
