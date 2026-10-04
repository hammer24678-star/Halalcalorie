#!/usr/bin/env python3
"""
patch_v49_core_screens.py
=========================
HalalCalorie v49 - Login, Settings and Profile rebuilt, plus app-wide icons.
Run from the repo root (needs v44-v48 applied):

    python3 patch_v49_core_screens.py

Safe to run twice. No new dependencies.

NEW  lib/core/fx6.dart
     PillSwitch, GlassIconBtn, IconBadge, AvatarRing, and EmojiIcon: ~100
     UI-symbol emoji (fire, water, lock, star, trophy ...) are drawn as crisp
     vector icons instead of emoji. Unmapped emoji (foods, flags) fall back to
     plain text, so swapping it in is always safe.

LOGIN      living aurora + drifting leaves, orbiting brand hero, staggered
           reveals, Google button, language switch, trust chips. Now
           localised (it was Arabic only). Sign-in logic unchanged.
SETTINGS   rebuilt: premium banner, grouped glass sections, icon badges,
           animated switches. Also fixes a bug: every section header was
           swallowed by a stray comment and never displayed.
PROFILE    rebuilt: spinning gradient avatar ring, living vitals (flame,
           water glass, moon), lifetime stats, body metrics, painted
           achievement badges, premium upsell, grouped account list.
ALL SCREENS  Text(emoji, style: TextStyle(fontSize: N)) becomes EmojiIcon.
pubspec    1.7.0+20 -> 1.8.0+21
"""
import os, re, sys, glob

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

def add_import(p, line):
    """Insert an import line after the last existing import (idempotent)."""
    def f(s):
        if line in s: return s
        idx = [m.end() for m in re.finditer(r"^import [^\n]*\n", s, re.M)]
        if not idx: return None
        i = idx[-1]
        return s[:i] + line + "\n" + s[i:]
    edit(p, f, 'import ' + line.split('/')[-1].rstrip("';"))

def rel_core(p, name):
    d = os.path.dirname(p)
    r = os.path.relpath('lib/core/' + name, d).replace(os.sep, '/')
    return "import '%s';" % r

def replace_region(s, start_marker, end_marker, new, start_back=None):
    i = s.find(start_marker)
    if i < 0: return None
    if start_back:
        j = s.rfind(start_back, 0, i)
        if j >= 0: i = j
    j = s.find(end_marker, i + len(start_marker))
    if j < 0: return None
    return s[:i] + new + s[j:]

def balance_check(paths):
    bad = 0
    for p in paths:
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

print('== v49 core screens ==')
write('lib/core/fx6.dart', r'''// ════════════════════════════════════════════════════════════════════
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
    '💡': (Icons.lightbulb_rounded, Color(0xFFF2C94C)),
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
    '⚖': (Icons.balance_rounded, Color(0xFF6FB3FF)),
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
    '💎': (Icons.diamond_rounded, Color(0xFF6FB3FF)),
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
''')
write('lib/features/auth/login_screen.dart', r'''// ============================================================
//  login_screen.dart — HalalCalorie v48 (studio redesign)
//  Same sign-in / guest logic as before. Now: living aurora,
//  orbiting brand hero, staggered reveals, shine-free white
//  Google button, language switch, trust chips.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/l10n.dart';
import '../../core/motion.dart';
import '../../core/fx.dart';
import '../../core/fx2.dart';
import '../../core/fx6.dart';
import '../../core/providers.dart';
import '../../core/auth_provider.dart';

String _nextLoginLang(String current) {
  const langs = ['ar', 'en', 'fr', 'tr', 'ur', 'ms', 'id'];
  final i = langs.indexOf(current);
  return langs[(i + 1) % langs.length];
}

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authNotifierProvider);
    final lang = ref.watch(languageProvider);
    final isAr = lang == 'ar' || lang == 'ur';
    String t(String ar, String en) => tLang(lang, ar, en);

    const base = Color(0xFF04100A);

    Widget chip(IconData icon, String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.07),
            border: Border.all(color: Colors.white.withOpacity(0.16), width: 0.7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: AppColors.halalGreen),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Aligarh', fontSize: 12, color: Colors.white70)),
          ]),
        );

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: base,
        body: Stack(children: [
          const Positioned.fill(
            child: AuroraBackground(
              base: base,
              colors: [Color(0xFF1E9E52), Color(0xFFDBA75D), Color(0xFF0E6B6B)],
              intensity: 1.0,
            ),
          ),
          Positioned.fill(
            child: DriftingLeaves(
                count: 12, color: AppColors.halalGreen, speed: 10, opacity: 0.45),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GlassIconBtn(
                      isDark: true,
                      size: 40,
                      onTap: () => ref
                          .read(languageProvider.notifier)
                          .set(_nextLoginLang(lang)),
                      child: Text(
                        lang == 'ar' ? 'ع' : lang.toUpperCase(),
                        style: const TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Reveal(
                  index: 0,
                  child: const OnboardScene(
                      kind: 0, color: AppColors.halalGreen, size: 230),
                ),
                const SizedBox(height: 18),
                Reveal(
                  index: 1,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Colors.white, Color(0xFFF0CF98)],
                    ).createShader(r),
                    child: Text(
                      isAr ? 'هلال كالوري' : 'HalalCalorie',
                      style: const TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Reveal(
                  index: 2,
                  child: Text(
                    t('تتبع سعراتك • حلال ١٠٠٪', 'Track your calories • 100% halal'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.65),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Reveal(
                  index: 3,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      chip(Icons.verified_rounded, t('حلال', 'Halal')),
                      chip(Icons.lock_rounded, t('خاص', 'Private')),
                      chip(Icons.auto_awesome_rounded, t('ماسح ذكي', 'AI scanner')),
                    ],
                  ),
                ),
                const Spacer(),
                Reveal(
                  index: 4,
                  child: PressFx(
                    onTap: isLoading
                        ? null
                        : () async {
                            final ok = await ref
                                .read(authNotifierProvider.notifier)
                                .signInWithGoogle();
                            if (ok && context.mounted) context.go('/home');
                          },
                    scale: 0.97,
                    child: Container(
                      height: 58,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: isLoading
                              ? const SizedBox(
                                  key: ValueKey('l'),
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.6,
                                      color: AppColors.brandGreen),
                                )
                              : Row(
                                  key: const ValueKey('t'),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ShaderMask(
                                      blendMode: BlendMode.srcIn,
                                      shaderCallback: (r) => const SweepGradient(
                                        colors: [
                                          Color(0xFF4285F4),
                                          Color(0xFF34A853),
                                          Color(0xFFFBBC05),
                                          Color(0xFFEA4335),
                                          Color(0xFF4285F4),
                                        ],
                                      ).createShader(r),
                                      child: const Text('G',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      t('تسجيل الدخول بـ Google',
                                          'Continue with Google'),
                                      style: const TextStyle(
                                        fontFamily: 'Aligarh',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1F2A1F),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Reveal(
                  index: 5,
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.go('/onboarding');
                    },
                    child: Text(
                      t('متابعة بدون حساب', 'Continue without an account'),
                      style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                Reveal(
                  index: 6,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shield_rounded,
                          size: 12, color: Colors.white.withOpacity(0.35)),
                      const SizedBox(width: 5),
                      Text(
                        t('بياناتك محفوظة وآمنة تماماً',
                            'Your data stays private and secure'),
                        style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
''')

# ── Settings ───────────────────────────────────────────────────────
SET = 'lib/features/settings/settings_screen.dart'
SET_BUILD = r'''  @override
  Widget build(BuildContext context) {
    final lang    = ref.watch(languageProvider);
    final isAr    = lang == 'ar';
    final isDark  = ref.watch(themeProvider);
    final isPrem  = ref.watch(premiumProvider);
    final ramadan = ref.watch(ramadanModeProvider);
    final notifsOn = ref.watch(notificationsEnabledProvider);

    final bg     = isDark ? AppColors.darkBg    : AppColors.lightBg;
    final card   = isDark ? const Color(0xFF0F1E18) : Colors.white;
    final text   = isDark ? AppColors.darkText  : AppColors.lightText;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = ramadan ? AppColors.accentGold : AppColors.brandGreen;

    String t(String ar, String en) => tLang(lang, ar, en);

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
      child: Row(children: [
        Container(
          width: 4, height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.halalGreen, accent]),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            fontFamily: 'Aligarh', fontSize: 12, fontWeight: FontWeight.w800,
            letterSpacing: 1.3, color: muted)),
      ]),
    );

    Widget row({
      required IconData icon, required Color color, required String title,
      String? subtitle, Widget? trailing, VoidCallback? onTap,
      Color? titleColor, bool last = false,
    }) => Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                  fontFamily: 'Aligarh', fontWeight: FontWeight.w700,
                  fontSize: 14, color: titleColor ?? text)),
              if (subtitle != null && subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle, style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 11.5, color: muted)),
                ),
            ])),
            if (trailing != null) ...[const SizedBox(width: 8), trailing],
          ]),
        ),
      ),
      if (!last)
        Divider(height: 1, indent: 64, endIndent: 14, color: border),
    ]);

    Widget tog({
      required IconData icon, required Color color, required String title,
      String? subtitle, required bool value,
      required void Function(bool) onChanged, bool last = false,
    }) => row(
      icon: icon, color: color, title: title, subtitle: subtitle, last: last,
      trailing: PillSwitch(value: value, onChanged: onChanged, color: accent),
      onTap: () => onChanged(!value),
    );

    Widget chev() => Icon(Icons.chevron_right_rounded, size: 22, color: muted);
    Widget ext()  => Icon(Icons.open_in_new_rounded, size: 16, color: muted);

    int gi = 2;
    Widget group(List<Widget> rows) => Reveal(
      index: gi++,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border, width: 0.6),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.06),
            blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: rows),
          ),
        ),
      ),
    );

    final macro = ref.watch(macroPlanProvider);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(children: [
          Positioned.fill(
            child: AuroraBackground(
              base: bg,
              colors: [accent, AppColors.accentGold, const Color(0xFF0E6B6B)],
              intensity: isDark ? 0.55 : 0.32,
              seconds: 22,
            ),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Reveal(
                  index: 0,
                  child: Row(children: [
                    GlassIconBtn(
                      icon: Icons.arrow_back_ios_new_rounded,
                      isDark: isDark,
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 14),
                    Text(t('الإعدادات', 'Settings'), style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 26,
                        fontWeight: FontWeight.w900, color: text)),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Premium banner ─────────────────────────────
                Reveal(
                  index: 1,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: isPrem
                            ? const [Color(0xFF3A2A0A), Color(0xFF1B1405)]
                            : const [Color(0xFF0E3B26), Color(0xFF07160F)],
                      ),
                      border: Border.all(
                          color: AppColors.accentGold.withOpacity(0.45),
                          width: 0.9),
                      boxShadow: [BoxShadow(
                          color: AppColors.accentGold.withOpacity(0.18),
                          blurRadius: 26, offset: const Offset(0, 10))],
                    ),
                    child: Column(children: [
                      Row(children: [
                        const BrandMark(size: 46),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(
                            isPrem
                                ? t('عضو بريميوم', 'Premium member')
                                : t('افتح كل شيء', 'Unlock everything'),
                            style: const TextStyle(
                                fontFamily: 'Aligarh', fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFF0CF98))),
                          const SizedBox(height: 3),
                          Text(
                            isPrem
                                ? t('شكراً لدعمك — كل الميزات مفتوحة',
                                    'Thank you — every feature is unlocked')
                                : t('ماسحات غير محدودة • ١٨٠ تمرين • مخطط AI',
                                    'Unlimited scans • 180 workouts • AI planner'),
                            style: const TextStyle(
                                fontFamily: 'Aligarh', fontSize: 12,
                                height: 1.4, color: Colors.white70)),
                        ])),
                        if (isPrem)
                          const Icon(Icons.verified_rounded,
                              color: AppColors.halalGreen, size: 26),
                      ]),
                      if (!isPrem) ...[
                        const SizedBox(height: 14),
                        ShineButton(
                          label: t('ترقية الآن', 'Upgrade now'),
                          icon: Icons.workspace_premium_rounded,
                          height: 50,
                          onPressed: () => context.push('/paywall'),
                        ),
                      ],
                    ]),
                  ),
                ),

                // ── APPEARANCE ─────────────────────────────────
                section(t('المظهر', 'APPEARANCE')),
                group([
                  tog(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: isDark ? const Color(0xFF7F8CFF) : AppColors.accentGold,
                    title: isDark ? t('الوضع الليلي', 'Dark mode')
                                  : t('الوضع النهاري', 'Light mode'),
                    subtitle: isDark ? t('تبديل للضوء', 'Switch to light')
                                     : t('تبديل للظلام', 'Switch to dark'),
                    value: isDark,
                    onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                  ),
                  row(
                    icon: Icons.translate_rounded, color: AppColors.waterBlue,
                    title: t('اللغة', 'Language'),
                    subtitle: _langLabel(lang),
                    trailing: Icon(Icons.expand_more_rounded, size: 22, color: muted),
                    onTap: () => _showLangPicker(context),
                  ),
                  row(
                    icon: Icons.donut_large_rounded, color: AppColors.halalGreen,
                    title: t('خطة الماكرو', 'Macro plan'),
                    subtitle: isAr ? macro.nameAr() : macro.nameEn(),
                    trailing: Icon(Icons.expand_more_rounded, size: 22, color: muted),
                    onTap: () => _showMacroPicker(context),
                    last: true,
                  ),
                ]),

                // ── RAMADAN ────────────────────────────────────
                section(t('رمضان المبارك', 'RAMADAN')),
                group([
                  tog(
                    icon: Icons.nights_stay_rounded, color: AppColors.accentGold,
                    title: t('وضع رمضان', 'Ramadan mode'),
                    subtitle: t('يُعدّل التمارين والتغذية للصائم',
                                'Adjusts workouts & nutrition for fasting'),
                    value: ramadan, last: !ramadan,
                    onChanged: (_) => ref.read(ramadanModeProvider.notifier).toggle(),
                  ),
                  if (ramadan)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.accentGold.withOpacity(0.4)),
                        ),
                        child: Text(
                          t('وضع رمضان فعّال — تمارين خفيفة أولاً • وصفات مناسبة للصائم • لافتة رمضان في الرئيسية',
                            'Ramadan mode active — light workouts first • fasting-friendly recipes • Ramadan banner on home'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11.5,
                              color: AppColors.accentGold, height: 1.5),
                        ),
                      ),
                    ),
                ]),

                // ── NOTIFICATIONS ──────────────────────────────
                section(t('الإشعارات', 'NOTIFICATIONS')),
                group([
                  tog(
                    icon: Icons.notifications_rounded, color: AppColors.doubtOrange,
                    title: t('تفعيل الإشعارات', 'Enable notifications'),
                    subtitle: t('ذكريات الماء والتمرين والوجبات',
                                'Water, workout & meal reminders'),
                    value: notifsOn, last: !notifsOn,
                    onChanged: (v) async {
                      await ref.read(notificationsEnabledProvider.notifier).toggle();
                      try {
                        if (v) {
                          await NotificationService.requestPermissions();
                          await NotificationService.rescheduleAll(isAr: isAr);
                        } else {
                          await NotificationService.cancelAll();
                        }
                      } catch (_) {}
                    },
                  ),
                  if (notifsOn) ...[
                    tog(
                      icon: Icons.water_drop_rounded, color: AppColors.waterBlue,
                      title: t('تذكير الماء', 'Water reminder'),
                      subtitle: t('كل ساعتين', 'Every 2 hours'),
                      value: _notifWater,
                      onChanged: (v) async {
                        setState(() => _notifWater = v);
                        await _saveNotifPref('notif_water', v);
                        try { await NotificationService.scheduleWaterReminder(isAr: isAr); } catch (_) {}
                      },
                    ),
                    tog(
                      icon: Icons.fitness_center_rounded, color: AppColors.halalGreen,
                      title: t('تذكير التمرين', 'Workout reminder'),
                      subtitle: t('يومياً ٥:٣٠ م', 'Daily at 5:30 PM'),
                      value: _notifWorkout,
                      onChanged: (v) async {
                        setState(() => _notifWorkout = v);
                        await _saveNotifPref('notif_workout', v);
                        try { await NotificationService.scheduleWorkoutReminder(isAr: isAr); } catch (_) {}
                      },
                    ),
                    tog(
                      icon: Icons.restaurant_rounded, color: AppColors.accentGold,
                      title: t('تذكير الوجبة', 'Meal reminder'),
                      subtitle: t('ثلاث مرات يومياً', 'Three times daily'),
                      value: _notifMeal, last: false,
                      onChanged: (v) async {
                        setState(() => _notifMeal = v);
                        await _saveNotifPref('notif_meals', v);
                        try { await NotificationService.scheduleMealReminder(isAr: isAr); } catch (_) {}
                      },
                    ),
                    row(
                      icon: Icons.tune_rounded, color: muted,
                      title: t('إعدادات متقدمة', 'More options'),
                      trailing: chev(), last: true,
                      onTap: () => _showNotifSettings(context),
                    ),
                  ],
                ]),

                // ── HEALTH GOALS ───────────────────────────────
                section(t('الأهداف الصحية', 'HEALTH GOALS')),
                group([
                  row(
                    icon: Icons.water_drop_rounded, color: AppColors.waterBlue,
                    title: t('هدف الماء اليومي', 'Daily water goal'),
                    subtitle: '${ref.watch(waterProvider).goal} ${t("كوب", "cups")}',
                    trailing: chev(),
                    onTap: () => _editWaterGoal(context, isAr),
                  ),
                  row(
                    icon: Icons.bedtime_rounded, color: AppColors.sleepPurple,
                    title: t('هدف النوم', 'Sleep goal'),
                    subtitle: '${ref.watch(sleepProvider).goal.toStringAsFixed(1)} ${t("ساعة", "hrs")}',
                    trailing: chev(), last: true,
                    onTap: () => _editSleepGoal(context, isAr),
                  ),
                ]),

                // ── DATA ───────────────────────────────────────
                section(t('البيانات', 'DATA')),
                group([
                  row(
                    icon: Icons.edit_rounded, color: AppColors.halalGreen,
                    title: t('تعديل ملفي الشخصي', 'Edit my profile'),
                    subtitle: t('الطول، الوزن، العمر، الهدف', 'Height, weight, age, goal'),
                    trailing: chev(),
                    onTap: () { context.pop(); context.go('/body'); },
                  ),
                  row(
                    icon: Icons.delete_outline_rounded, color: AppColors.haramRed,
                    title: t('مسح سجل اليوم', "Clear today's data"),
                    subtitle: t('الوجبات والخطوات والماء', 'Meals, steps, water'),
                    titleColor: AppColors.haramRed, trailing: chev(), last: true,
                    onTap: () => _confirmClearDay(context, isAr),
                  ),
                ]),

                // ── ABOUT ──────────────────────────────────────
                section(t('حول التطبيق', 'ABOUT')),
                group([
                  row(
                    icon: Icons.info_outline_rounded, color: AppColors.waterBlue,
                    title: t('إصدار التطبيق', 'App version'),
                    subtitle: 'HalalCalorie ${ref.watch(appVersionProvider).maybeWhen(
                        data: (v) => v, orElse: () => '')}'.trim(),
                  ),
                  row(
                    icon: Icons.lock_outline_rounded, color: AppColors.halalGreen,
                    title: t('سياسة الخصوصية', 'Privacy policy'),
                    subtitle: t('بياناتك خاصة — لا نبيعها أبداً',
                                'Your data is private — we never sell it'),
                    trailing: ext(),
                  ),
                  row(
                    icon: Icons.star_rounded, color: AppColors.accentGold,
                    title: t('تقييم التطبيق', 'Rate the app'),
                    subtitle: t('يساعدنا تقييم 5 نجوم كثيراً', 'A 5-star review helps us a lot'),
                    trailing: ext(), last: true,
                  ),
                ]),

                const SizedBox(height: 30),
                Center(child: Column(children: [
                  BrandMark(size: 36, color: muted.withOpacity(0.7)),
                  const SizedBox(height: 10),
                  Text(
                    t('صُنع بعناية — بياناتك تبقى على جهازك',
                      'Made with care — your data stays on your device'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                        color: muted, height: 1.8),
                  ),
                ])),
              ],
            ),
          ),
        ]),
      ),
    );
  }

'''
def set_patch(s):
    if 'PillSwitch(' in s: return s
    return replace_region(s, 'Widget build(BuildContext context) { final isAr',
                          '  // \u2500\u2500 Language helpers', SET_BUILD, start_back='  @override')
edit(SET, set_patch, 'rebuilt build()')
for n in ('motion.dart', 'fx.dart', 'fx6.dart'):
    add_import(SET, rel_core(SET, n))

# ── Profile ────────────────────────────────────────────────────────
PRO = 'lib/features/profile/profile_screen.dart'
PRO_BUILD = r'''  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang      = ref.watch(languageProvider);
    final isAr      = lang == 'ar' || lang == 'ur';
    final gender    = ref.watch(genderProvider);
    final streak    = ref.watch(streakProvider);
    final water     = ref.watch(waterProvider);
    final sleep     = ref.watch(sleepProvider);
    final isPremium = ref.watch(premiumProvider);
    final planAsync = ref.watch(planNameProvider);
    final planName  = planAsync.valueOrNull ?? 'free';
    final city      = ref.watch(cityProvider);
    final isDark    = ref.watch(themeProvider);
    final profile   = ref.watch(userProfileProvider);
    final isSis     = gender == 'sisters' || profile?.gender == 'sisters';
    final workoutMin = ref.watch(workoutMinutesProvider);

    final bg     = isDark ? AppColors.darkBg : AppColors.lightBg;
    final card   = isDark ? const Color(0xFF0F1E18) : Colors.white;
    final textC  = isDark ? AppColors.darkText  : AppColors.lightText;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accent = isSis ? AppColors.accentGold : AppColors.halalGreen;

    final plan = ref.watch(macroPlanProvider);
    final l = L.fromLang(lang);
    String t(String ar, String en) => l.t(ar, en);

    BoxDecoration cardDeco([Color? edge]) => BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: edge ?? border, width: edge == null ? 0.6 : 0.9),
      boxShadow: [BoxShadow(
        color: (edge ?? Colors.black).withOpacity(isDark ? 0.30 : 0.07),
        blurRadius: 24, offset: const Offset(0, 8))],
    );

    final planLabel = isAr
        ? (planName == 'lifetime' ? 'بريميوم مدى الحياة'
           : planName == 'yearly'  ? 'بريميوم سنوي'
           : planName == 'monthly' ? 'بريميوم شهري' : 'بريميوم')
        : (planName == 'lifetime' ? 'Lifetime Premium'
           : planName == 'yearly'  ? 'Yearly Premium'
           : planName == 'monthly' ? 'Monthly Premium' : 'Premium');

    Widget infoChip(IconData icon, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: accent.withOpacity(0.10),
        border: Border.all(color: accent.withOpacity(0.30), width: 0.7),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: accent),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
            fontWeight: FontWeight.w700, color: textC)),
      ]),
    );

    Widget vital(VitalKind kind, double pct, Color color, String value, String label) =>
      Expanded(child: Container(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [card, Color.lerp(card, color, isDark ? 0.10 : 0.07)!]),
          border: Border.all(color: Color.lerp(border, color, 0.35)!, width: 0.8),
          boxShadow: [BoxShadow(color: color.withOpacity(isDark ? 0.14 : 0.10),
              blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          VitalGlyph(kind: kind, pct: pct, color: color, size: 48),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontFamily: 'Aligarh', fontSize: 17,
              fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10.5,
              color: muted)),
        ]),
      ));

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned.fill(
          child: AuroraBackground(
            base: bg,
            colors: [accent, AppColors.accentGold, const Color(0xFF0E6B6B)],
            intensity: isDark ? 0.55 : 0.30,
            seconds: 22,
          ),
        ),
        SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              // ── Top bar ───────────────────────────────────
              Reveal(index: 0, child: Row(children: [
                Expanded(child: Text(l.myProfile, style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 26,
                    fontWeight: FontWeight.w900, color: textC))),
                GlassIconBtn(
                  isDark: isDark,
                  onTap: () => ref.read(languageProvider.notifier).set(_nextLang(lang)),
                  child: Text(_langLabel(lang), style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 13,
                      fontWeight: FontWeight.w800, color: textC)),
                ),
                const SizedBox(width: 8),
                GlassIconBtn(
                  isDark: isDark,
                  icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  onTap: () => ref.read(themeProvider.notifier).toggle(),
                ),
              ])),
              const SizedBox(height: 18),

              // ── Hero ──────────────────────────────────────
              Reveal(index: 1, child: Column(children: [
                AvatarRing(
                  size: 124,
                  gap: bg,
                  colors: [accent, AppColors.accentGold, AppColors.waterBlue],
                  child: Container(
                    color: accent.withOpacity(0.14),
                    child: Image.asset(
                      isSis ? kAvatarSisters : kAvatarBrothers,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_rounded, size: 56, color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(isSis ? l.womanLabel : l.manLabel, style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 22,
                    fontWeight: FontWeight.w900, color: textC)),
                const SizedBox(height: 2),
                Text(isSis ? l.sistersMode : l.menMode, style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 12.5, color: muted)),
                if (profile != null) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    infoChip(Icons.cake_rounded, '${profile.age} ${l.yrsLabel}'),
                    infoChip(Icons.height_rounded, '${profile.heightCm.toInt()} cm'),
                    infoChip(Icons.monitor_weight_rounded,
                        '${profile.weightKg.toStringAsFixed(1)} kg'),
                  ]),
                  const SizedBox(height: 10),
                  Text(isAr ? profile.primaryGoal.nameAr() : profile.primaryGoal.nameEn(),
                      style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                          color: accent, fontWeight: FontWeight.w800)),
                ],
                if (isPremium) ...[
                  const SizedBox(height: 12),
                  PressFx(
                    onTap: () => ref.read(premiumProvider.notifier).refresh(),
                    scale: 0.95,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                            colors: [Color(0xFFF0CF98), Color(0xFFDBA75D)]),
                        boxShadow: [BoxShadow(
                            color: AppColors.accentGold.withOpacity(0.4),
                            blurRadius: 18)],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.workspace_premium_rounded,
                            size: 16, color: Color(0xFF1A0F00)),
                        const SizedBox(width: 6),
                        Text(planLabel, style: const TextStyle(
                            fontFamily: 'Aligarh', fontSize: 12.5,
                            fontWeight: FontWeight.w900, color: Color(0xFF1A0F00))),
                      ]),
                    ),
                  ),
                ],
              ])),
              const SizedBox(height: 20),

              // ── Vitals ────────────────────────────────────
              Reveal(index: 2, child: Row(children: [
                vital(VitalKind.flame, (streak / 30).clamp(0.0, 1.0),
                    AppColors.haramRed, '$streak', t('تتابع', 'Streak')),
                const SizedBox(width: 10),
                vital(VitalKind.water, water.percent, AppColors.waterBlue,
                    '${water.cups}/${water.goal}', t('الماء', 'Water')),
                const SizedBox(width: 10),
                vital(VitalKind.sleep, sleep.percent, AppColors.sleepPurple,
                    '${sleep.hours.toInt()}h', t('النوم', 'Sleep')),
              ])),
              const SizedBox(height: 14),

              // ── Lifetime stats ────────────────────────────
              Reveal(index: 3, child: Container(
                padding: const EdgeInsets.all(16),
                decoration: cardDeco(),
                child: Column(children: [
                  Row(children: [
                    const IconBadge(icon: Icons.emoji_events_rounded,
                        color: AppColors.accentGold, size: 34),
                    const SizedBox(width: 10),
                    Text(t('إحصائياتك الكلية', 'Lifetime stats'), style: TextStyle(
                        fontFamily: 'Aligarh', fontWeight: FontWeight.w800,
                        fontSize: 14.5, color: textC)),
                  ]),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _lifeStat(Icons.local_fire_department_rounded, '$streak',
                        t('أيام تتابع', 'Streak'), AppColors.haramRed, muted),
                    _lifeStat(Icons.directions_run_rounded,
                        workoutMin > 0 ? '${workoutMin}m' : '—',
                        t('اليوم', 'Today'), AppColors.halalGreen, muted),
                    _lifeStat(Icons.water_drop_rounded, '${water.cups}/${water.goal}',
                        t('ماء اليوم', 'Water'), AppColors.waterBlue, muted),
                    _lifeStat(Icons.bedtime_rounded, '${sleep.hours.toInt()}h',
                        t('نوم اليوم', 'Sleep'), AppColors.sleepPurple, muted),
                  ]),
                ]),
              )),
              const SizedBox(height: 14),

              // ── Body metrics ──────────────────────────────
              if (profile != null) ...[
                Reveal(index: 4, child: PressFx(
                  onTap: () => context.go('/body'),
                  scale: 0.985,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDeco(),
                    child: Column(children: [
                      Row(children: [
                        const IconBadge(icon: Icons.accessibility_new_rounded,
                            color: AppColors.halalGreen, size: 34),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t('مقاييس جسمك', 'Body metrics'),
                            style: TextStyle(fontFamily: 'Aligarh',
                                fontWeight: FontWeight.w800, fontSize: 14.5,
                                color: textC))),
                        Text(t('عرض الكل', 'View all'), style: const TextStyle(
                            fontFamily: 'Aligarh', fontSize: 12,
                            fontWeight: FontWeight.w700, color: AppColors.halalGreen)),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: AppColors.halalGreen),
                      ]),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                        _bodyMini('BMI', profile.bmi.toStringAsFixed(1),
                            _bmiColor(profile.bmi), muted),
                        _bodyMini(t('السعرات', 'Cals'),
                            '${profile.calorieGoalKcal.toInt()}', AppColors.haramRed, muted),
                        _bodyMini(isAr ? plan.nameAr() : plan.nameEn(),
                            'P:${(profile.calorieGoalKcal * plan.proteinPct / 400).toInt()}g',
                            AppColors.halalGreen, muted),
                        _bodyMini(t('الماء', 'Water'), '${profile.waterLiters}L',
                            AppColors.waterBlue, muted),
                      ]),
                    ]),
                  ),
                )),
                const SizedBox(height: 14),
              ],

              // ── Achievements ──────────────────────────────
              Reveal(index: 5,
                child: _achievementsCard(isPremium, isAr, isDark, ref, context)),
              const SizedBox(height: 14),

              // ── Premium upsell ────────────────────────────
              if (!isPremium) ...[
                Reveal(index: 6, child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF0E3B26), Color(0xFF07160F)]),
                    border: Border.all(
                        color: AppColors.accentGold.withOpacity(0.45), width: 0.9),
                    boxShadow: [BoxShadow(
                        color: AppColors.accentGold.withOpacity(0.18),
                        blurRadius: 26, offset: const Offset(0, 10))],
                  ),
                  child: Column(children: [
                    Row(children: [
                      const BrandMark(size: 42),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t('ترقية إلى بريميوم', 'Upgrade to Premium'),
                            style: const TextStyle(fontFamily: 'Aligarh',
                                fontWeight: FontWeight.w900, fontSize: 15.5,
                                color: Color(0xFFF0CF98))),
                        const SizedBox(height: 3),
                        Text(t('ماسحات غير محدودة + ١٨٠ تمرين + مخطط AI + مقاييس دقيقة',
                               'Unlimited scans + 180 workouts + AI planner + precise body metrics'),
                            style: const TextStyle(fontFamily: 'Aligarh',
                                fontSize: 11.5, height: 1.4, color: Colors.white70)),
                      ])),
                    ]),
                    const SizedBox(height: 14),
                    ShineButton(
                      label: t('افتح بريميوم', 'Unlock Premium'),
                      icon: Icons.workspace_premium_rounded,
                      height: 50,
                      onPressed: () => context.push('/paywall'),
                    ),
                  ]),
                )),
                const SizedBox(height: 14),
              ],

              // ── Account list ──────────────────────────────
              Reveal(index: 7, child: Container(
                decoration: cardDeco(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(children: [
                      _tileRow(Icons.location_on_rounded, AppColors.haramRed,
                          t('المدينة', 'City'), city, textC, muted, border,
                          () => _showCityPicker(context, ref, isAr)),
                      _tileRow(Icons.translate_rounded, AppColors.waterBlue,
                          t('اللغة', 'Language'),
                          tLang(lang, 'العربية', 'English', 'Français', 'Türkçe', 'Melayu', 'Indonesia'),
                          textC, muted, border,
                          () => ref.read(languageProvider.notifier).set(_nextLang(lang))),
                      _tileRow(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                          isDark ? AppColors.accentGold : const Color(0xFF7F8CFF),
                          isDark ? t('الوضع النهاري', 'Day mode') : t('الوضع الليلي', 'Night mode'),
                          isDark ? t('مفعّل', 'Active') : t('معطّل', 'Off'),
                          textC, muted, border,
                          () => ref.read(themeProvider.notifier).toggle()),
                      if (profile != null)
                        _tileRow(Icons.edit_rounded, AppColors.halalGreen,
                            t('تعديل معلوماتي', 'Edit my info'), '',
                            textC, muted, border, () => context.go('/body')),
                      if (isPremium)
                        _tileRow(Icons.workspace_premium_rounded, AppColors.accentGold,
                            t('إدارة الاشتراك', 'Manage subscription'),
                            isAr
                              ? (planName == 'lifetime' ? 'مدى الحياة' : planName == 'yearly' ? 'سنوي نشط' : 'شهري نشط')
                              : (planName == 'lifetime' ? 'Lifetime' : planName == 'yearly' ? 'Yearly active' : 'Monthly active'),
                            textC, muted, border,
                            () async {
                              await ref.read(premiumProvider.notifier).refresh();
                              if (context.mounted) _showManageSubSheet(context, ref, isAr, planName);
                            }),
                      if (!isPremium)
                        _tileRow(Icons.lock_open_rounded, AppColors.accentGold,
                            t('ترقية إلى بريميوم', 'Upgrade to Premium'),
                            t('افتح كل الميزات', 'Unlock all features'),
                            textC, muted, border,
                            () { if (context.mounted) context.push('/paywall'); }),
                      _tileRow(Icons.lock_outline_rounded, AppColors.halalGreen,
                          t('سياسة الخصوصية', 'Privacy policy'), '',
                          textC, muted, border, () {}),
                      _tileRow(Icons.info_outline_rounded, AppColors.waterBlue,
                          t('حول التطبيق', 'About app'), 'v1.6',
                          textC, muted, border,
                          () => showAboutDialog(
                            context: context, applicationName: 'HalalCalorie',
                            applicationVersion: '1.6.0',
                            children: [const Text('© 2026 HalalCalorie — Halal • Private • Ad-free',
                                style: TextStyle(fontFamily: 'Aligarh'))])),
                      _tileRow(Icons.logout_rounded, AppColors.haramRed,
                          t('تسجيل الخروج', 'Sign out'), '',
                          textC, muted, border,
                          () => _signOut(context, ref, isAr),
                          danger: true, last: true),
                    ]),
                  ),
                ),
              )),
            ],
          ),
        ),
      ]),
    );
  }

  // ── ACHIEVEMENT BADGES ─────────────────────────────────────
  Widget _achievementsCard(bool isPremium, bool isAr, bool isDark, WidgetRef ref, BuildContext context) {
    final ach  = ref.watch(achievementProvider);
    final fast = ref.watch(fastingProvider);
    final card = isDark ? const Color(0xFF0F1E18) : Colors.white;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    String t(String ar, String en) => isAr ? ar : en;

    final badges = <(IconData, String, bool)>[
      (Icons.eco_rounded,           t('البداية','Awakened'),         ach.totalDaysLogged >= 1),
      (Icons.link_rounded,          t('أسبوع كامل','Chain of Seven'), ach.totalDaysLogged >= 7),
      (Icons.nights_stay_rounded,   t('أول إمساك','First Restraint'), fast.lifetimeCount >= 1),
      (Icons.terrain_rounded,       t('الثابت','Unmoved'),           fast.lifetimeCount >= 7),
      (Icons.spa_rounded,           t('الطيّب','Wholesome'),         ach.wholeFoodsLogged >= 3),
      (Icons.auto_awesome_rounded,  t('المتقن','Refined'),           ach.totalDaysLogged >= 30),
      (Icons.emoji_events_rounded,  t('المئة','Centurion'),          ach.totalDaysLogged >= 100),
      (Icons.menu_book_rounded,     t('العزم','Resolve'),
        ach.totalDaysLogged >= 28 && fast.lifetimeCount >= 4),
    ];
    final earned = badges.where((b) => b.$3).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 0.6),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.30 : 0.07),
          blurRadius: 24, offset: const Offset(0, 8))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const IconBadge(icon: Icons.military_tech_rounded,
              color: AppColors.accentGold, size: 34),
          const SizedBox(width: 10),
          Expanded(child: Text(t('إنجازاتك','Your achievements'),
            style: TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800,
              fontSize: 14.5, color: textC))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentGold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20)),
            child: Text('$earned/${badges.length}',
              style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11.5,
                fontWeight: FontWeight.w800, color: AppColors.accentGold)),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
          children: badges.map((b) => _badge(b.$1, b.$2, b.$3, muted, isDark)).toList()),
        if (!isPremium) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => context.push('/paywall'),
            child: Center(child: Text(
              t('ترقّ لفتح كل الإنجازات','Upgrade to unlock all badges'),
              style: const TextStyle(fontFamily: 'Aligarh',
                fontSize: 11.5, color: AppColors.accentGold))),
          ),
        ],
      ]),
    );
  }

  Widget _badge(IconData icon, String label, bool earned, Color muted, bool isDark) =>
    AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: earned
            ? LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [AppColors.accentGold.withOpacity(0.20),
                         AppColors.accentGold.withOpacity(0.05)])
            : null,
        color: earned ? null : (isDark ? const Color(0xFF16231C) : const Color(0xFFF1F3F2)),
        border: Border.all(
          color: earned ? AppColors.accentGold.withOpacity(0.5) : Colors.transparent),
        boxShadow: earned
            ? [BoxShadow(color: AppColors.accentGold.withOpacity(0.22), blurRadius: 14)]
            : const [],
      ),
      child: Column(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: earned
                ? const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFF0CF98), Color(0xFFDBA75D)])
                : null,
            color: earned ? null : muted.withOpacity(0.14),
          ),
          child: Icon(earned ? icon : Icons.lock_rounded,
              size: earned ? 21 : 17,
              color: earned ? const Color(0xFF1A0F00) : muted.withOpacity(0.7)),
        ),
        const SizedBox(height: 6),
        Text(label,
          style: TextStyle(fontFamily: 'Aligarh', fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: earned ? AppColors.accentGold : muted),
          textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis),
      ]),
    );

  Widget _lifeStat(IconData icon, String val, String label, Color col, Color muted) {
    return Column(children: [
      Icon(icon, size: 22, color: col),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(fontFamily: 'Aligarh', fontSize: 15,
          fontWeight: FontWeight.w900, color: col)),
      Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
    ]);
  }

  Widget _bodyMini(String label, String value, Color color, Color muted) {
    return Column(children: [
      Text(value, style: TextStyle(fontFamily: 'Aligarh', fontSize: 16,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted)),
    ]);
  }

  Widget _tileRow(IconData icon, Color color, String title, String sub,
      Color textC, Color muted, Color border, VoidCallback onTap,
      {bool danger = false, bool last = false}) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            IconBadge(icon: icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontFamily: 'Aligarh', fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: danger ? AppColors.haramRed : textC)),
              if (sub.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(sub, style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 11.5, color: muted)),
                ),
            ])),
            Icon(Icons.chevron_right_rounded, size: 21, color: muted),
          ]),
        ),
      ),
      if (!last)
        Divider(height: 1, indent: 62, endIndent: 14, color: border),
    ]);
  }

'''
def pro_patch(s):
    if 'AvatarRing(' in s: return s
    return replace_region(s, 'Widget build(BuildContext context, WidgetRef ref) {',
                          '  Color _bmiColor(double bmi) {', PRO_BUILD, start_back='  @override')
edit(PRO, pro_patch, 'rebuilt build()')
for n in ('motion.dart', 'fx.dart', 'fx4.dart', 'fx6.dart'):
    add_import(PRO, rel_core(PRO, n))

# ── App-wide: emoji text -> vector icons ───────────────────────────
EMO = '[\U0001F300-\U0001FAFF\u2600-\u27BF\u2B50\u2705\u274C\u2764\u2B06\u2B07\u2713\u2715\u2605\u263E]'
LIT = re.compile(r"(?:const\s+)?Text\(\s*'(" + EMO + r"\uFE0F?)'\s*,\s*style:\s*(?:const\s+)?TextStyle\(\s*fontSize:\s*(\d+(?:\.\d+)?)\s*,?\s*\)\s*,?\s*\)")
VAR = re.compile(r"(?:const\s+)?Text\(\s*((?:widget\.|w\.|item\.|e\.|p\.|a\.)?(?:emoji|em|glyph|icon)(?:\(\))?)\s*,\s*style:\s*(?:const\s+)?TextStyle\(\s*fontSize:\s*(\d+(?:\.\d+)?)\s*,?\s*\)\s*,?\s*\)")
def emoji_patch(s):
    n = LIT.sub(lambda m: "const EmojiIcon('%s', size: %s)" % (m.group(1), m.group(2)), s)
    n = VAR.sub(lambda m: "EmojiIcon(%s, size: %s)" % (m.group(1), m.group(2)), n)
    if n != s and 'core/fx6.dart' not in n:
        return n   # import added separately below
    return n
touched = []
for fp in sorted(glob.glob(path('lib/features/**/*.dart'), recursive=True)):
    rel = os.path.relpath(fp, ROOT).replace(os.sep, '/')
    src = open(fp, encoding='utf-8').read()
    if LIT.search(src) or VAR.search(src):
        edit(rel, emoji_patch, 'emoji -> EmojiIcon')
        add_import(rel, rel_core(rel, 'fx6.dart'))
        touched.append(rel)

edit('pubspec.yaml', sub_once('version: 1.7.0+20', 'version: 1.8.0+21'), 'version 1.8.0+21')

print('\n== sanity ==')
balance_check(['lib/core/fx6.dart', LOGIN := 'lib/features/auth/login_screen.dart', SET, PRO] + touched)
print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git add -A && git commit -m "v49: core screens" && git push')
