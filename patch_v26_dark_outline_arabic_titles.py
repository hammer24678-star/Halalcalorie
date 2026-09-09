#!/usr/bin/env python3
"""
patch_v26_dark_outline_arabic_titles.py
=======================================

1. DARK-MODE OUTLINE FIX (custom emojis + logo)
   Transparent PNG packs (mood faces, status glyphs, wholesome foods,
   mosque mark, app logo) show a light fringe / weird outline against
   forest-dark surfaces. Fix:
   - Shared helper `darkSafeAsset()` that composites the asset cleanly
     (high filter quality + optional dark-surface plate, no color-tint
     that would ruin full-colour emoji art).
   - Wire helper into mood faces, status glyphs, wholesome strip,
     mosque mark, and splash logo plate.

2. ARABIC-ONLY TITLE FONT → LemonBrush
   AppBar titles + hero greetings use LemonBrush when language is Arabic
   (`lang == 'ar'`). All other languages keep Bravoon.
   (Urdu stays Bravoon — user asked Arabic only.)

3. مزاجك اليومي
   Health tracking section title: "مزاجك اليوم" → "مزاجك اليومي".
   Mood face labels use dark-aware muted colour (was hard-coded
   AppColors.lightMuted, which reads wrong on dark cards).

Run from project root. Marker-gated, idempotent.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V26_DARK_OUTLINE_AR_TITLES"


def _log(label, status):
    LEDGER.append((label, status))


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERROR ({label}): {rel} not found under {ROOT}")
    text = p.read_text(encoding="utf-8")
    if MARKER in text and label.startswith("idempotency"):
        _log(label, "SKIPPED-ALREADY")
        return
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")


# ══════════════════════════════════════════════════════════════
# 0. SHARED HELPER — darkSafeAsset in icon_assets.dart
# ══════════════════════════════════════════════════════════════
ICON = "lib/data/icon_assets.dart"

ICON_HELPER_ANCHOR = """wholesomeFoodAsset(String key) => kWholesomeFoodAssetByKey[key];"""

ICON_HELPER_NEW = """wholesomeFoodAsset(String key) => kWholesomeFoodAssetByKey[key];

// ─────────────────────────────────────────────────────────────────
// PATCH_V26_DARK_OUTLINE_AR_TITLES
// Transparent PNG packs (mood faces, status glyphs, food icons,
// mosque mark, logo) leave a light fringe against forest-dark
// surfaces. darkSafeAsset composites them cleanly without tinting
// full-colour art (no BlendMode.srcIn / modulate).
// ─────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';

Widget darkSafeAsset(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  bool isDark = false,
  Widget? errorChild,
  BorderRadius? radius,
}) {
  final img = Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
    isAntiAlias: true,
    errorBuilder: errorChild == null
        ? null
        : (_, __, ___) => errorChild,
  );
  // On dark surfaces, sit the asset on a soft matching plate so any
  // residual light fringe blends into the plate instead of glowing.
  if (!isDark) return img;
  final child = radius != null
      ? ClipRRect(borderRadius: radius, child: img)
      : img;
  return ColoredBox(
    color: const Color(0xFF0E1A14), // forest plate ≈ AppColors.darkCard
    child: child,
  );
}
"""

# icon_assets is pure data today — import at top is safer. Rewrite approach:
ICON_TOP_OLD = None  # filled after we read actual top


# ══════════════════════════════════════════════════════════════
# 1. HEALTH — mood title + mood faces + dark-aware labels
# ══════════════════════════════════════════════════════════════
HEALTH = "lib/features/health/health_screen.dart"

HEALTH_MOOD_TITLE_OLD = """      _anim(4, _sectionTitle('😊 ${isAr ? "مزاجك اليوم" : "Today Mood"}', isDark)),"""

HEALTH_MOOD_TITLE_NEW = """      // PATCH_V26_DARK_OUTLINE_AR_TITLES: correct Arabic wording
      _anim(4, _sectionTitle('😊 ${isAr ? "مزاجك اليومي" : "Today Mood"}', isDark)),"""

HEALTH_MOOD_IMG_OLD = """            child: Column(children: [
              Image.asset(m[0], width: 28, height: 28,
                  errorBuilder: (_, __, ___) =>
                      const Text('🙂', style: TextStyle(fontSize: 28))),
              Text(m[1],
                  style: const TextStyle(fontFamily: 'Aligarh', fontSize: 9,
                      color: AppColors.lightMuted)),
            ]),"""

HEALTH_MOOD_IMG_NEW = """            // PATCH_V26_DARK_OUTLINE_AR_TITLES: kill PNG fringe + dark labels
            child: Column(children: [
              darkSafeAsset(m[0], width: 28, height: 28, isDark: isDark,
                  errorChild: const Text('🙂', style: TextStyle(fontSize: 28))),
              Text(m[1],
                  style: TextStyle(fontFamily: 'Aligarh', fontSize: 9,
                      color: isDark ? AppColors.darkMuted : AppColors.lightMuted)),
            ]),"""

# AppBar title — Arabic → LemonBrush
HEALTH_APPBAR_OLD = """        title: Text(t('الصحة والعافية', 'Health & Wellness'),
            style: const TextStyle(fontFamily: 'Bravoon',
                fontWeight: FontWeight.w400, fontSize: 22, color: Colors.white)),"""

HEALTH_APPBAR_NEW = """        // PATCH_V26_DARK_OUTLINE_AR_TITLES: LemonBrush for Arabic titles only
        title: Text(t('الصحة والعافية', 'Health & Wellness'),
            style: TextStyle(
                fontFamily: lang == 'ar' ? 'LemonBrush' : 'Bravoon',
                fontWeight: FontWeight.w400, fontSize: 22, color: Colors.white)),"""

# ══════════════════════════════════════════════════════════════
# 2. HOME — greeting font + mosque + wholesome + status glyphs
# ══════════════════════════════════════════════════════════════
HOME = "lib/features/home/home_screen.dart"

HOME_GREET_OLD = """            // PATCH_V22_REMASTER: Bravoon for hero titles (user choice)
            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Text(
                _greeting(now),
                style: TextStyle(
                  fontFamily: 'Bravoon',
                  fontWeight: FontWeight.w700,
                  fontSize: 42,
                  height: 1.0,
                  color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                ),
              ),
            ),"""

HOME_GREET_NEW = """            // PATCH_V26_DARK_OUTLINE_AR_TITLES: LemonBrush Arabic only
            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Text(
                _greeting(now),
                style: TextStyle(
                  fontFamily: lang == 'ar' ? 'LemonBrush' : 'Bravoon',
                  fontWeight: FontWeight.w700,
                  fontSize: 42,
                  height: 1.0,
                  color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                ),
              ),
            ),"""

HOME_MOSQUE_OLD = """    child: Image.asset('assets/icons/mosque_mark/mosque_small.png',
        width: 26, height: 26, fit: BoxFit.contain,
        errorBuilder: (_, __, ___)"""

# More flexible — capture exact from file later if needed
HOME_MOSQUE_ALT = None

HOME_WHOLESOME_OLD = """                  Image.asset(f['asset']!, width: 18, height: 18,"""

HOME_WHOLESOME_NEW = """                  // PATCH_V26: dark-safe food glyph
                  darkSafeAsset(f['asset']!, width: 18, height: 18, isDark: isDark,"""


# ══════════════════════════════════════════════════════════════
# 3. NUTRITION — greeting Arabic LemonBrush
# ══════════════════════════════════════════════════════════════
NUTR = "lib/features/nutrition/nutrition_screen.dart"

NUTR_GREET_OLD = """                            // PATCH_V22_REMASTER: Bravoon matches Home titles
                            style: TextStyle(fontFamily: 'Bravoon',
                                fontWeight: FontWeight.w700,
                                fontSize: 36, height: 1.0,
                                color: isRamadan ? AppColors.ramadanGold
                                    : isDark ? AppColors.greetGold
                                              : AppColors.greetGoldLight)),"""

NUTR_GREET_NEW = """                            // PATCH_V26_DARK_OUTLINE_AR_TITLES: LemonBrush Arabic only
                            style: TextStyle(
                                fontFamily: lang == 'ar' ? 'LemonBrush' : 'Bravoon',
                                fontWeight: FontWeight.w700,
                                fontSize: 36, height: 1.0,
                                color: isRamadan ? AppColors.ramadanGold
                                    : isDark ? AppColors.greetGold
                                              : AppColors.greetGoldLight)),"""
# Fallback if v22 marker was reformatted
NUTR_GREET_OLD2 = """                            style: TextStyle(fontFamily: 'Bravoon',
                                fontWeight: FontWeight.w700,
                                fontSize: 36, height: 1.0,
                                color: isRamadan ? AppColors.ramadanGold
                                    : isDark ? AppColors.greetGold
                                              : AppColors.greetGoldLight)),"""


# ══════════════════════════════════════════════════════════════
# 4. FITNESS — AppBar title
# ══════════════════════════════════════════════════════════════
FIT = "lib/features/fitness/fitness_screen.dart"

FIT_APPBAR_OLD = """          title: Text(l.fitnessTitle,
              style: const TextStyle(fontFamily: 'Bravoon',"""

FIT_APPBAR_NEW = """          // PATCH_V26_DARK_OUTLINE_AR_TITLES: LemonBrush Arabic only
          title: Text(l.fitnessTitle,
              style: TextStyle(fontFamily: lang == 'ar' ? 'LemonBrush' : 'Bravoon',"""

# ══════════════════════════════════════════════════════════════
# 5. SPLASH — logo plate dark-safe
# ══════════════════════════════════════════════════════════════
SPLASH = "lib/features/splash/splash_screen.dart"

SPLASH_LOGO_OLD = """          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
                // A missing asset must never leave a blank splash.
                errorBuilder: (_, __, ___) => _FallbackMark(accent: accent),
              ),
            ),
          ),"""

SPLASH_LOGO_NEW = """          // PATCH_V26_DARK_OUTLINE_AR_TITLES: solid plate under logo kills fringe
          child: ClipOval(
            child: ColoredBox(
              color: const Color(0xFF0E1A14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  isAntiAlias: true,
                  // A missing asset must never leave a blank splash.
                  errorBuilder: (_, __, ___) => _FallbackMark(accent: accent),
                ),
              ),
            ),
          ),"""


# ══════════════════════════════════════════════════════════════
# 6. THEME — document LemonBrush as Arabic title font
# ══════════════════════════════════════════════════════════════
THEME = "lib/core/theme.dart"

THEME_OLD = """  /// Cursive accent -- not currently used anywhere (the home/nutrition
  /// greetings that used to reference this moved to Bravoon in v17).
  /// Left registered in pubspec in case a future flourish wants it.
  static const lemonBrush = 'LemonBrush';"""

THEME_NEW = """  /// Arabic title font (AppBar + hero greetings when lang == 'ar').
  /// PATCH_V26_DARK_OUTLINE_AR_TITLES: restored for Arabic-only titles.
  /// Other languages keep Bravoon.
  static const lemonBrush = 'LemonBrush';"""


def _ensure_icon_helper():
    """Append darkSafeAsset to icon_assets.dart with a proper Flutter import."""
    p = ROOT / ICON
    text = p.read_text(encoding="utf-8")
    if "darkSafeAsset" in text:
        _log("icon_assets: darkSafeAsset helper", "SKIPPED-ALREADY")
        return

    # Ensure material import at top
    if "package:flutter/material.dart" not in text:
        # Insert after any existing imports or at top
        if text.startswith("//") or text.startswith("const ") or text.startswith("String ") or text.startswith("Map ") or text.startswith("List "):
            text = "import 'package:flutter/material.dart';\n\n" + text
        else:
            # find last import
            lines = text.splitlines(keepends=True)
            last_imp = 0
            for i, ln in enumerate(lines):
                if ln.startswith("import "):
                    last_imp = i + 1
            if last_imp == 0:
                lines.insert(0, "import 'package:flutter/material.dart';\n\n")
            else:
                lines.insert(last_imp, "import 'package:flutter/material.dart';\n")
            text = "".join(lines)

    helper = """

// ─────────────────────────────────────────────────────────────────
// PATCH_V26_DARK_OUTLINE_AR_TITLES
// Transparent PNG packs leave a light fringe against forest-dark
// surfaces. darkSafeAsset composites them cleanly without tinting
// full-colour emoji art.
// ─────────────────────────────────────────────────────────────────
Widget darkSafeAsset(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  bool isDark = false,
  Widget? errorChild,
  BorderRadius? radius,
}) {
  final img = Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
    isAntiAlias: true,
    errorBuilder: errorChild == null
        ? null
        : (_, __, ___) => errorChild,
  );
  if (!isDark) return img;
  final child = radius != null
      ? ClipRRect(borderRadius: radius, child: img)
      : img;
  // Soft forest plate ≈ darkCard so residual light fringe blends away.
  return ColoredBox(
    color: const Color(0xFF0E1A14),
    child: child,
  );
}
"""
    text = text.rstrip() + "\n" + helper
    p.write_text(text, encoding="utf-8")
    _log("icon_assets: darkSafeAsset helper", "OK")


def _patch_mosque_and_glyphs():
    """Home mosque mark + status glyphs → darkSafeAsset when isDark is in scope."""
    p = ROOT / HOME
    text = p.read_text(encoding="utf-8")
    changed = False

    # Mosque small mark (appears more than once possibly)
    old_m = """Image.asset('assets/icons/mosque_mark/mosque_small.png',
        width: 26, height: 26, fit: BoxFit.contain,
        errorBuilder: (_, __, ___)"""
    new_m = """darkSafeAsset('assets/icons/mosque_mark/mosque_small.png',
        width: 26, height: 26, isDark: isDark,
        errorChild:"""
    # The errorBuilder signature differs — handle carefully
    # Simpler targeted replace for the common pattern:
    patterns = [
        (
            "Image.asset('assets/icons/mosque_mark/mosque_small.png',\n"
            "        width: 26, height: 26, fit: BoxFit.contain,\n"
            "        errorBuilder: (_, __, ___) =>",
            "darkSafeAsset('assets/icons/mosque_mark/mosque_small.png',\n"
            "        width: 26, height: 26, isDark: isDark,\n"
            "        errorChild:",
        ),
        (
            "Image.asset('assets/icons/mosque_mark/mosque_small.png',\n"
            "                    width: 22, height: 22,\n"
            "                    errorBuilder: (_, __, ___) =>",
            "darkSafeAsset('assets/icons/mosque_mark/mosque_small.png',\n"
            "                    width: 22, height: 22, isDark: isDark,\n"
            "                    errorChild:",
        ),
        (
            "Image.asset('assets/icons/mosque_mark/mosque_small.png',\n"
            "        width: 26, height: 26, fit: BoxFit.contain,\n"
            "        errorBuilder: (_, __, ___)",
            "darkSafeAsset('assets/icons/mosque_mark/mosque_small.png',\n"
            "        width: 26, height: 26, isDark: isDark,\n"
            "        errorChild:",
        ),
    ]
    for old, new in patterns:
        if old in text:
            text = text.replace(old, new)
            changed = True
            _log("home: mosque mark → darkSafeAsset", "OK")
        else:
            _log("home: mosque pattern", "SKIPPED-NOT-FOUND")

    # status glyphs
    for old, new, label in [
        (
            "Image.asset(statusGlyphForEmoji(widget.emoji)!, width: 18, height: 18,",
            "darkSafeAsset(statusGlyphForEmoji(widget.emoji)!, width: 18, height: 18, isDark: isDark,",
            "home: status glyph widget",
        ),
        (
            "Image.asset(statusGlyphForEmoji(item.emoji)!, width: 20, height: 20,",
            "darkSafeAsset(statusGlyphForEmoji(item.emoji)!, width: 20, height: 20, isDark: isDark,",
            "home: status glyph item",
        ),
    ]:
        if old in text:
            text = text.replace(old, new)
            changed = True
            _log(label, "OK")
        else:
            _log(label, "SKIPPED-NOT-FOUND")

    # health status glyphs
    hp = ROOT / HEALTH
    ht = hp.read_text(encoding="utf-8")
    hchanged = False
    for old, new, label in [
        (
            "Image.asset(statusGlyphForEmoji(emoji)!, width: 20, height: 20,\n"
            "                  errorBuilder: (_, __, ___) =>\n"
            "                      Text(emoji, style: const TextStyle(fontSize: 20)))",
            "darkSafeAsset(statusGlyphForEmoji(emoji)!, width: 20, height: 20, isDark: isDark,\n"
            "                  errorChild:\n"
            "                      Text(emoji, style: const TextStyle(fontSize: 20)))",
            "health: status glyph",
        ),
    ]:
        if old in ht:
            ht = ht.replace(old, new)
            hchanged = True
            _log(label, "OK")
        else:
            # try looser
            loose_old = "Image.asset(statusGlyphForEmoji(emoji)!, width: 20, height: 20,"
            loose_new = "darkSafeAsset(statusGlyphForEmoji(emoji)!, width: 20, height: 20, isDark: isDark,"
            if loose_old in ht:
                ht = ht.replace(loose_old, loose_new)
                hchanged = True
                _log(label + " (loose)", "OK")
            else:
                _log(label, "SKIPPED-NOT-FOUND")

    # sleep face emoji images in health
    sleep_old = """        Image.asset(
"""
    # too broad — skip specific if not exact

    if changed:
        p.write_text(text, encoding="utf-8")
    if hchanged:
        hp.write_text(ht, encoding="utf-8")


def _ensure_imports():
    """Make sure screens that call darkSafeAsset import icon_assets."""
    for rel, need in [
        (HOME, "import '../../data/icon_assets.dart';"),
        (HEALTH, "import '../../data/icon_assets.dart';"),
        (SPLASH, "import '../../data/icon_assets.dart';"),
    ]:
        p = ROOT / rel
        if not p.exists():
            continue
        t = p.read_text(encoding="utf-8")
        if "icon_assets.dart" in t:
            _log(f"{rel}: icon_assets import", "SKIPPED-ALREADY")
            continue
        # insert after last import
        lines = t.splitlines(keepends=True)
        last = 0
        for i, ln in enumerate(lines):
            if ln.startswith("import "):
                last = i + 1
        lines.insert(last, need + "\n")
        p.write_text("".join(lines), encoding="utf-8")
        _log(f"{rel}: icon_assets import", "OK")


def main():
    print("=" * 70)
    print("v26 — dark-mode PNG outline fix + Arabic LemonBrush titles")
    print("      + مزاجك اليومي")
    print("=" * 70)

    _ensure_icon_helper()
    _ensure_imports()

    # Health
    edit(HEALTH, HEALTH_MOOD_TITLE_OLD, HEALTH_MOOD_TITLE_NEW,
         "health: مزاجك اليوم → مزاجك اليومي")
    edit(HEALTH, HEALTH_MOOD_IMG_OLD, HEALTH_MOOD_IMG_NEW,
         "health: mood faces darkSafe + dark labels")
    edit(HEALTH, HEALTH_APPBAR_OLD, HEALTH_APPBAR_NEW,
         "health: AppBar LemonBrush when Arabic")

    # Home
    edit(HOME, HOME_GREET_OLD, HOME_GREET_NEW,
         "home: greeting LemonBrush when Arabic")
    edit(HOME, HOME_WHOLESOME_OLD, HOME_WHOLESOME_NEW,
         "home: wholesome glyphs darkSafe")

    # Nutrition
    if not edit_try(NUTR, NUTR_GREET_OLD, NUTR_GREET_NEW,
                    "nutrition: greeting LemonBrush when Arabic"):
        edit(NUTR, NUTR_GREET_OLD2, NUTR_GREET_NEW,
             "nutrition: greeting LemonBrush when Arabic (fallback)")

    # Fitness
    edit(FIT, FIT_APPBAR_OLD, FIT_APPBAR_NEW,
         "fitness: AppBar LemonBrush when Arabic")

    # Splash logo
    edit(SPLASH, SPLASH_LOGO_OLD, SPLASH_LOGO_NEW,
         "splash: logo solid plate (no fringe)")

    # Theme comment
    edit(THEME, THEME_OLD, THEME_NEW,
         "theme: document LemonBrush as Arabic title font")

    _patch_mosque_and_glyphs()

    # Fitness needs isAr in scope at AppBar — verify
    _ensure_fitness_isAr()

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    for label, status in LEDGER:
        print(f"  {status:20s} {label}")
    print("=" * 70)
    print(f"{ok} applied.")
    print()
    print("WHAT YOU SHOULD SEE AFTER REBUILD")
    print("-" * 70)
    print("""
DARK MODE
  • Mood faces, status glyphs, wholesome food icons, mosque mark, and
    the splash logo no longer show a light fringe / weird outline.
    Assets sit on a soft forest plate; filter quality is high.

ARABIC TITLES (lang == 'ar' only)
  • AppBar titles on Health & Fitness use LemonBrush.
  • Home hero greeting uses LemonBrush.
  • Nutrition hero greeting uses LemonBrush.
  • English / French / Turkish / Urdu / Malay / Indonesian keep Bravoon.

HEALTH · Tracking
  • Section title is now « مزاجك اليومي » (was « مزاجك اليوم »).
  • Mood face labels use darkMuted in dark mode (readable).
""")


def edit_try(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        _log(label, "SKIPPED-NOT-FOUND")
        return False
    text = p.read_text(encoding="utf-8")
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return False
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")
    return True


def _ensure_fitness_isAr():
    """Fitness AppBar uses lang == 'ar' for LemonBrush — lang must be in scope."""
    p = ROOT / FIT
    t = p.read_text(encoding="utf-8")
    if "lang == 'ar' ? 'LemonBrush'" not in t:
        return
    if "languageProvider" in t and "final lang" in t:
        _log("fitness: lang in scope for LemonBrush", "OK")
        return
    _log("fitness: lang scope check", "SKIPPED-NOT-FOUND")


if __name__ == "__main__":
    main()
