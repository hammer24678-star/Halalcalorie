// ════════════════════════════════════════════════════════════════════
//  fx7.dart — layout kit (v50)
//    SoftAurora    aurora background that fades in under an app bar
//    SegTabs       sliding pill tab bar bound to a TabController
//    SegPick       sliding pill selector for any list of options
//    WaterTile     water glass + progress + minus/plus
//    EmptyState    glowing icon, title, hint, optional action
//    SectionTitle  accent bar + title + optional trailing widget
//    StatTile      icon, big number, label (cards in grids)
// ════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'theme.dart';
import 'motion.dart';
import 'fx.dart';
import 'fx4.dart';

class SoftAurora extends StatelessWidget {
  final Color base;
  final List<Color> colors;
  final double intensity;
  const SoftAurora({
    super.key,
    required this.base,
    required this.colors,
    this.intensity = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00000000), Color(0xFF000000)],
        stops: [0.0, 0.10],
      ).createShader(r),
      child: AuroraBackground(
        base: base,
        colors: colors,
        intensity: intensity,
        seconds: 26,
      ),
    );
  }
}

class SegTabs extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final Color accent, onAccent, textColor, mutedColor;
  const SegTabs({
    super.key,
    required this.controller,
    required this.labels,
    required this.accent,
    required this.onAccent,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: textColor.withOpacity(0.08), width: 0.6),
      ),
      child: AnimatedBuilder(
        animation: controller.animation!,
        builder: (_, __) {
          final v = controller.animation!.value;
          return Stack(children: [
            Align(
              alignment: AlignmentDirectional(
                  n == 1 ? 0.0 : -1.0 + 2.0 * v / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(colors: [
                      Color.lerp(accent, Colors.white, 0.18)!,
                      accent,
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: accent.withOpacity(0.40), blurRadius: 14),
                    ],
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => controller.animateTo(i),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color.lerp(mutedColor, onAccent,
                              (1 - (v - i).abs()).clamp(0.0, 1.0)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

class SegPick extends StatelessWidget {
  final List<String> labels;
  final List<IconData>? icons;
  final int index;
  final ValueChanged<int> onChanged;
  final Color accent, onAccent, textColor;
  final double height;
  const SegPick({
    super.key,
    required this.labels,
    this.icons,
    required this.index,
    required this.onChanged,
    required this.accent,
    required this.onAccent,
    required this.textColor,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: textColor.withOpacity(0.08), width: 0.6),
      ),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutBack,
          alignment: AlignmentDirectional(
              n == 1 ? 0.0 : -1.0 + 2.0 * index / (n - 1), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: LinearGradient(colors: [
                  Color.lerp(accent, Colors.white, 0.18)!,
                  accent,
                ]),
                boxShadow: [
                  BoxShadow(color: accent.withOpacity(0.38), blurRadius: 12),
                ],
              ),
            ),
          ),
        ),
        Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (icons != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 5),
                        child: Icon(icons![i],
                            size: 15,
                            color: i == index
                                ? onAccent
                                : textColor.withOpacity(0.55)),
                      ),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: i == index
                            ? onAccent
                            : textColor.withOpacity(0.6),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color color;
  const _RoundBtn({
    required this.icon,
    required this.onTap,
    required this.filled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return PressFx(
      onTap: onTap,
      scale: 0.86,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                )
              : null,
          color: filled ? null : color.withOpacity(0.14),
          boxShadow: filled
              ? [BoxShadow(color: color.withOpacity(0.45), blurRadius: 12)]
              : const [],
        ),
        child: Icon(icon,
            size: 20, color: filled ? const Color(0xFF05243F) : color),
      ),
    );
  }
}

class WaterTile extends StatelessWidget {
  final int cups, goal;
  final String label;
  final bool isDark;
  final VoidCallback onAdd, onRemove;
  const WaterTile({
    super.key,
    required this.cups,
    required this.goal,
    required this.label,
    required this.isDark,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    const c = AppColors.waterBlue;
    final pct = goal > 0 ? (cups / goal).clamp(0.0, 1.0) : 0.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withOpacity(isDark ? 0.18 : 0.12),
            c.withOpacity(isDark ? 0.05 : 0.04),
          ],
        ),
        border: Border.all(color: c.withOpacity(0.30), width: 0.8),
      ),
      child: Row(children: [
        VitalGlyph(kind: VitalKind.water, pct: pct, color: c, size: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: c)),
                  Text('$cups / $goal  •  ${(pct * 100).toInt()}％',
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 11,
                          color: c.withOpacity(0.85))),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedBar(
                value: pct,
                color: c,
                background: c.withOpacity(0.15),
                height: 9,
                radius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _RoundBtn(
            icon: Icons.remove_rounded, onTap: onRemove, filled: false, color: c),
        const SizedBox(width: 8),
        _RoundBtn(icon: Icons.add_rounded, onTap: onAdd, filled: true, color: c),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Color textColor, mutedColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    required this.textColor,
    required this.mutedColor,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        PulseGlow(
          color: color,
          minOpacity: 0.08,
          maxOpacity: 0.30,
          blur: 30,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.30), color.withOpacity(0.06)],
              ),
              border: Border.all(color: color.withOpacity(0.4), width: 0.8),
            ),
            child: Icon(icon, size: 36, color: color),
          ),
        ),
        const SizedBox(height: 18),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: textColor)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 12.5,
                  height: 1.5,
                  color: mutedColor)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            child: ShineButton(
              label: actionLabel!,
              height: 48,
              onPressed: onAction,
            ),
          ),
        ],
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Color textColor;
  final Color? accent;
  final Widget? trailing;
  const SectionTitle({
    super.key,
    required this.title,
    required this.textColor,
    this.accent,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? AppColors.halalGreen;
    return Row(children: [
      Container(
        width: 4,
        height: 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [a, AppColors.accentGold],
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(title,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: textColor)),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withOpacity(isDark ? 0.16 : 0.10),
            color.withOpacity(isDark ? 0.05 : 0.03),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.28), width: 0.8),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 10.5,
                color: color.withOpacity(0.85))),
      ]),
    );
  }
}
