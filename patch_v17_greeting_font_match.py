#!/usr/bin/env python3
"""
patch_v17_greeting_font_match.py — greeting text should look like the rest
of the app's titles, not a different (and currently plain-looking) font
===========================================================================

WHAT WAS WRONG
  The "Good morning" / "Good evening" hero greeting on Home and Nutrition
  is set to `fontFamily: 'LemonBrush'`. Every other title in the app
  (AppBar titles like "My Body Metrics", headlineLarge/headlineMedium/
  titleLarge in theme.dart) is 'Bravoon'. Side by side, the greeting reads
  as a plain fallback-looking font next to Bravoon's bold rounded titles
  -- confirmed from screenshots comparing the two headers directly.

FIX
  - lib/features/home/home_screen.dart — hero greeting: LemonBrush -> Bravoon
    (+ fontWeight: w700 to match titleLarge's weight), color unchanged
    (still AppColors.greetGold / greetGoldLight -- only the font moves).
  - lib/features/nutrition/nutrition_screen.dart — same greeting text,
    same swap, same untouched color.
  - lib/core/theme.dart — AppFonts.lemonBrush doc comment updated; it no
    longer describes a font actually used anywhere (see NOT TOUCHED).

NOT TOUCHED
  - AppFonts.greeting (theme.dart) — a TextStyle constant that still
    points at lemonBrush, but nothing in the app references it (grepped
    the whole tree). Dead code, not a rendering bug, so left alone rather
    than guessing at a "fix" for something nothing uses.
  - pubspec.yaml's LemonBrush font registration and the .otf asset file
    itself -- left in place. Removing them is a separate cleanup with its
    own risk (nothing else currently depends on it, but that's a reason
    to leave it inert, not a reason to touch pubspec in this patch).

SAFETY: same exact-match-or-refuse rule as every other patch in this set.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
LEDGER = []
FAILED = []


def _p(relpath):
    return ROOT / relpath


def apply_one(relpath, old, new, note):
    path = _p(relpath)
    if not path.exists():
        FAILED.append(f"{relpath}: file not found")
        print(f"REFUSING {relpath}: file not found — {note}")
        return False
    text = path.read_text(encoding="utf-8")
    n = text.count(old)
    if n != 1:
        FAILED.append(f"{relpath}: {note} (expected 1 match, found {n})")
        print(f"REFUSING {relpath}: expected exactly 1 match for {note!r}, found {n}. "
              f"No changes made to this file.")
        return False
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    LEDGER.append(f"OK   {relpath}: {note}")
    return True


# ═════════════════════════════════════════════════════════════════
# 1. home_screen.dart — hero greeting font + stale comment
# ═════════════════════════════════════════════════════════════════
def patch_home():
    F = "lib/features/home/home_screen.dart"
    apply_one(
        F,
        "// The v10 mockup's only use of LemonBrush: a big cursive time-of-day\n"
        "// greeting, with a streak badge and today's date. Didn't exist before.",
        "// PATCH_V17: greeting now uses Bravoon, matching every AppBar title\n"
        "// (e.g. 'My Body Metrics') instead of LemonBrush, which rendered as a\n"
        "// plain fallback next to it. Streak badge + today's date unchanged.",
        "stale comment -> reflects Bravoon greeting",
    )
    apply_one(
        F,
        "                style: TextStyle(\n"
        "                  fontFamily: 'LemonBrush', fontSize: 42, height: 1.0,\n"
        "                  color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,\n"
        "                ),",
        "                style: TextStyle(\n"
        "                  fontFamily: 'Bravoon', fontWeight: FontWeight.w700, fontSize: 42, height: 1.0,\n"
        "                  color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,\n"
        "                ),",
        "home hero greeting -> Bravoon (color untouched)",
    )


# ═════════════════════════════════════════════════════════════════
# 2. nutrition_screen.dart — same greeting, same swap
# ═════════════════════════════════════════════════════════════════
def patch_nutrition():
    apply_one(
        "lib/features/nutrition/nutrition_screen.dart",
        "                            style: TextStyle(fontFamily: 'LemonBrush',\n"
        "                                fontSize: 30, height: 1.0,\n"
        "                                color: isDark ? AppColors.greetGold : AppColors.greetGoldLight)),",
        "                            style: TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700,\n"
        "                                fontSize: 30, height: 1.0,\n"
        "                                color: isDark ? AppColors.greetGold : AppColors.greetGoldLight)),",
        "nutrition hero greeting -> Bravoon (color untouched)",
    )


# ═════════════════════════════════════════════════════════════════
# 3. theme.dart — doc comment only (lemonBrush is now unreferenced
#    anywhere in the app; see NOT TOUCHED above for why the constant
#    and pubspec registration stay as-is)
# ═════════════════════════════════════════════════════════════════
def patch_theme():
    apply_one(
        "lib/core/theme.dart",
        "  /// Cursive accent — reserved for one-off flourishes, not body copy\n"
        "  /// or buttons (e.g. a home-screen greeting, if one is added later).\n"
        "  static const lemonBrush = 'LemonBrush';",
        "  /// Cursive accent -- not currently used anywhere (the home/nutrition\n"
        "  /// greetings that used to reference this moved to Bravoon in v17).\n"
        "  /// Left registered in pubspec in case a future flourish wants it.\n"
        "  static const lemonBrush = 'LemonBrush';",
        "doc comment -> no longer claims an in-use example",
    )


def main():
    print("=" * 70)
    print("Greeting font match: LemonBrush -> Bravoon (home + nutrition hero)")
    print("=" * 70)
    patch_home()
    patch_nutrition()
    patch_theme()

    print()
    print("=" * 70)
    print(f"{len(LEDGER)} edit(s) applied, {len(FAILED)} refused.")
    for line in LEDGER:
        print(" ", line)
    if FAILED:
        for line in FAILED:
            print(" ", line)
        sys.exit(1)
    print("=" * 70)
    print("Not touched (see docstring): AppFonts.greeting constant (dead code,")
    print("nothing references it) and pubspec.yaml's LemonBrush registration.")


if __name__ == "__main__":
    main()
