#!/usr/bin/env python3
"""
patch_v50_nutrition.py
======================
HalalCalorie v50 - Nutrition brought up to the Home standard.
Run from the repo root (needs v49 applied):

    python3 patch_v50_nutrition.py

Safe to run twice. No new dependencies.

NEW  lib/core/fx7.dart
     SoftAurora, SegTabs, SegPick, WaterTile, EmptyState, SectionTitle,
     StatTile - a layout kit that the later screen patches reuse.

NUTRITION
     * living aurora behind both tabs (fades in under the app bar)
     * Today / Recipes / AI Plan: sliding gradient pill tabs instead of the
       stock underline bar
     * Light / Dark / Ramadan switch: compact sliding pill selector
     * Add Food: gradient floating pill with glow and press feedback
     * calorie card: gradient surface, hairline edge, bigger glow
     * Eaten / Burned boxes: count-up numbers on tinted icon tiles
     * Protein / Carbs / Fat bars now fill from zero on entry
     * water: living glass icon, animated bar, minus and plus
     * weekly chart: gradient bars with a faint goal backdrop
     * recipes: each card rises in with a stagger
pubspec    1.8.0+21 -> 1.9.0+22
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

def _skip_str(s, i):
    """s[i] is the opening quote. Returns index just after the string."""
    raw = i > 0 and s[i-1] == 'r' and (i < 2 or not (s[i-2].isalnum() or s[i-2] == '_'))
    q = s[i]
    triple = s[i:i+3] == q*3
    j = i + (3 if triple else 1)
    while j < len(s):
        c = s[j]
        if not raw and c == '\\':
            j += 2; continue
        if not raw and c == '$' and j + 1 < len(s) and s[j+1] == '{':
            j = _match(s, j + 1, '{', '}') + 1
            continue
        if triple:
            if s[j:j+3] == q*3:
                return j + 3
        elif c == q:
            return j + 1
        elif c == '\n' and not triple:
            return j + 1
        j += 1
    return j

def _match(s, i, o, c):
    """s[i] == o. Returns index of the matching closer."""
    depth = 0
    j = i
    n = len(s)
    while j < n:
        ch = s[j]
        if ch == '/' and s[j:j+2] == '//':
            j = s.find('\n', j)
            if j < 0: return -1
            continue
        if ch == '/' and s[j:j+2] == '/*':
            j = s.find('*/', j)
            if j < 0: return -1
            j += 2; continue
        if ch in '\'"':
            j = _skip_str(s, j); continue
        if ch == o: depth += 1
        elif ch == c:
            depth -= 1
            if depth == 0: return j
        j += 1
    return -1

def call_span(s, anchor, start=0):
    """Span (a, b) of the call that begins with `anchor` (which must end in '(')."""
    a = s.find(anchor, start)
    if a < 0: return None
    p = a + len(anchor) - 1
    e = _match(s, p, '(', ')')
    if e < 0: return None
    return a, e + 1

def replace_call(s, anchor, new, start=0):
    sp = call_span(s, anchor, start)
    if not sp: return None
    return s[:sp[0]] + new + s[sp[1]:]

print('== v50 nutrition ==')
write('lib/core/fx7.dart', r'''// ════════════════════════════════════════════════════════════════════
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
                  Text('$cups / $goal  •  ${(pct * 100).toInt()}%',
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
''')

NUT = 'lib/features/nutrition/nutrition_screen.dart'
for n in ('motion.dart', 'fx.dart', 'fx7.dart'):
    add_import(NUT, rel_core(NUT, n))

def nut(s):
    if 'SegTabs(' in s: return s
    # 1. floating action button -> gradient pill
    FAB = """PressFx(
          onTap: () => _openAdd(context, isAr, isDark, isPremium),
          scale: 0.94,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: isRamadan
                    ? const [Color(0xFFFFD97A), Color(0xFFE8B84B)]
                    : const [Color(0xFF3FB950), Color(0xFF1E9E52)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded,
                  color: isRamadan ? AppColors.ramadanInk : Colors.white,
                  size: 26),
              const SizedBox(width: 8),
              Text(tl('أضف طعام', 'Add Food'),
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      color: isRamadan ? AppColors.ramadanInk : Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ]),
          ),
        )"""
    n = replace_call(s, 'FloatingActionButton.extended(', FAB)
    if n is None: return None
    s = n

    # 2. TabBar -> SegTabs (first TabBar( in the main build only)
    SEG = """SegTabs(
                controller: _tab,
                accent: accent,
                onAccent: isRamadan ? AppColors.ramadanInk : Colors.white,
                textColor: textC,
                mutedColor: muted,
                labels: [
                  tl('اليوم', 'Today'),
                  tl('الوصفات', 'Recipes'),
                  tl('مخطط AI', 'AI Plan'),
                ],
              )"""
    n = replace_call(s, 'TabBar(', SEG)
    if n is None: return None
    s = n
    s = s.replace('preferredSize: const Size.fromHeight(92)', 'preferredSize: const Size.fromHeight(104)', 1)

    # 3. theme pills -> compact sliding selector
    PILLS = """  // v50: Light / Dark / Ramadan preview switcher (local to this screen).
  Widget _themeSwitcherPills(
      bool isAr, String Function(String, String) tl, Color textC) {
    const modes = [_NutriTheme.light, _NutriTheme.dark, _NutriTheme.ramadan];
    final idx = modes.indexOf(_previewTheme);
    final isRam = _previewTheme == _NutriTheme.ramadan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
      child: SegPick(
        index: idx < 0 ? 0 : idx,
        labels: [tl('فاتح', 'Light'), tl('داكن', 'Dark'), tl('رمضان', 'Ramadan')],
        icons: const [
          Icons.light_mode_rounded,
          Icons.dark_mode_rounded,
          Icons.nights_stay_rounded,
        ],
        accent: isRam ? AppColors.ramadanGold : AppColors.brandGreen,
        onAccent: isRam ? AppColors.ramadanInk : Colors.white,
        textColor: textC,
        height: 36,
        onChanged: (i) => setState(() => _previewTheme = modes[i]),
      ),
    );
  }

"""
    n = replace_region(s, 'Widget _themeSwitcherPills(', '  MealType _mealType(', PILLS, start_back='  // v19')
    if n is None: return None
    s = n

    # 4. aurora behind the tab views
    sp = call_span(s, 'TabBarView(\n          controller: _tab,')
    if sp is None:
        sp = call_span(s, 'TabBarView(')
    if sp is None: return None
    orig = s[sp[0]:sp[1]]
    AUR = """Stack(children: [
          Positioned.fill(
            child: SoftAurora(
              base: bg,
              colors: isRamadan
                  ? const [Color(0xFFE8B84B), Color(0xFF5B3FD0), Color(0xFF2B1B6B)]
                  : const [Color(0xFF1E9E52), Color(0xFFDBA75D), Color(0xFF0E6B6B)],
              intensity: isDark ? 0.50 : 0.26,
            ),
          ),
          """ + orig + """,
        ])"""
    s = s[:sp[0]] + AUR + s[sp[1]:]

    # 5. calorie card surface
    CARD = re.compile(r"color: cardBg,\s*borderRadius: BorderRadius\.circular\(24\),\s*boxShadow: \[\s*BoxShadow\(\s*color: calCol\.withOpacity\(0\.18\),")
    if not CARD.search(s): return None
    s = CARD.sub(lambda m: """gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          cardBg,
                          Color.lerp(cardBg, calCol, isDark ? 0.10 : 0.06)!,
                        ],
                      ),
                      border: Border.all(
                          color: calCol.withOpacity(0.28), width: 0.8),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: calCol.withOpacity(0.22),""", s, count=1)

    # 6. water row -> WaterTile
    mark = "const EmojiIcon('\U0001F4A7', size: 14),"
    k = s.find(mark)
    if k < 0: return None
    a = s.rfind('Row(', 0, k)
    e = _match(s, a + 3, '(', ')')
    if a < 0 or e < 0: return None
    WATER = """WaterTile(
                      cups: ref.watch(waterProvider).cups,
                      goal: ref.watch(waterProvider).goal,
                      label: tl('الماء', 'Water'),
                      isDark: isDark,
                      onAdd: () => ref.read(waterProvider.notifier).add(),
                      onRemove: () => ref.read(waterProvider.notifier).remove(),
                    )"""
    s = s[:a] + WATER + s[e + 1:]

    # 7. summary boxes -> count-up tiles
    SUMMARY = """  Widget _summaryBox(String emoji, String label, String val,
      Color color, bool isDark) {
    final n = num.tryParse(val);
    final big = TextStyle(
        fontFamily: 'Aligarh', fontSize: 26, fontWeight: FontWeight.w900,
        height: 1.0, color: color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(isDark ? 0.20 : 0.12),
            color.withOpacity(isDark ? 0.06 : 0.04),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.32), width: 0.8),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: EmojiIcon(emoji, size: 22, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            n != null
                ? CountUp(value: n, style: big)
                : Text(val, style: big),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 11.5,
                color: color.withOpacity(0.9), fontWeight: FontWeight.w700)),
          ],
        )),
      ]),
    );
  }

"""
    n = replace_region(s, 'Widget _summaryBox(String emoji, String label, String val,', '  Widget _macroRow(', SUMMARY, start_back='  // PATCH_V22_REMASTER')
    if n is None: return None
    s = n

    # 8. macro bars fill from zero
    i = s.find('LayoutBuilder(builder: (_, constraints) => AnimatedContainer(')
    if i >= 0:
        a = s.find('AnimatedContainer(', i)
        e = _match(s, a + len('AnimatedContainer'), '(', ')')
        old = s[a:e + 1]
        d = old.find('decoration:')
        if d >= 0:
            deco = old[d:-1].rstrip().rstrip(',')
            newbar = ("TweenAnimationBuilder<double>(\n"
                      "            tween: Tween<double>(begin: 0.0, end: pct),\n"
                      "            duration: const Duration(milliseconds: 900),\n"
                      "            curve: Curves.easeOutCubic,\n"
                      "            builder: (_, pv, __) => Container(\n"
                      "              height: 10,\n"
                      "              width: constraints.maxWidth * pv,\n"
                      "              " + deco + ",\n"
                      "            ),\n"
                      "          )")
            s = s[:a] + newbar + s[e + 1:]

    # 9. weekly chart bars
    ROD = re.compile(r"BarChartRodData\(\s*toY: kcal,\s*color: isToday\s*\?\s*AppColors\.brandGreen\s*:\s*AppColors\.brandGreen\s*\.withOpacity\(0\.4\),\s*width: 14,")
    if ROD.search(s):
        s = ROD.sub(lambda m: """BarChartRodData(
                                  toY: kcal,
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: isToday
                                        ? const [Color(0xFF1E9E52), Color(0xFF78E08E)]
                                        : [
                                            AppColors.brandGreen.withOpacity(0.25),
                                            AppColors.brandGreen.withOpacity(0.55),
                                          ],
                                  ),
                                  backDrawRodData: BackgroundBarChartRodData(
                                    show: true,
                                    toY: goal > 0 ? goal.toDouble() : 2000.0,
                                    color: muted.withOpacity(0.08),
                                  ),
                                  width: 16,""", s, count=1)

    # 10. recipes rise in
    r = s.find('final em = emojis[r.id % emojis.length];')
    if r >= 0:
        sp = call_span(s, 'Container(', r)
        if sp:
            inner = s[sp[0]:sp[1]]
            s = s[:sp[0]] + "Reveal(index: r.id % 8, child: " + inner + ")" + s[sp[1]:]
    return s
edit(NUT, nut, 'Nutrition overhaul')

edit('pubspec.yaml', sub_once('version: 1.8.0+21', 'version: 1.9.0+22'), 'version 1.9.0+22')

print('\n== sanity ==')
balance_check(['lib/core/fx7.dart', NUT])
print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git add -A && git commit -m "v50: nutrition" && git push')
