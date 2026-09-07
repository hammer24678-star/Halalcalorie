#!/usr/bin/env python3
"""
patch_v16_palette_cleanup.py — kill leftover old-palette hardcoded colors
===========================================================================

WHAT I WAS LOOKING FOR
  Health and Ascent screens turned out to already match the v10 mockup
  exactly (same quest colors/emoji/labels, same tab names, byte-for-byte
  in places) -- no patch needed for either. So instead of manufacturing
  busywork there, I went looking for what could actually still look
  "off" now that the rest of the app is on the new forest-green palette:
  spots that hardcode the OLD GitHub-dark hex values directly instead of
  referencing AppColors. Those didn't get the palette update at all, so
  they now visually clash with everything around them.

FOUND (grep across every screen for the retired hex literals):
  - lib/core/shell.dart — the bottom nav bar itself (every screen sits on
    top of this). Background/border were still the old gray, so the nav
    bar looked like a leftover GitHub-dark strip under an otherwise green
    app on every single screen.
  - lib/features/home/home_screen.dart — 3 separate spots: the medical
    disclaimer banner, a ring-chart track color, a small icon button.
  - lib/features/onboarding/onboarding_screen.dart — 11 occurrences
    across the whole file (option cards, buttons) -- the first-time
    setup flow would have looked like the old theme entirely.
  - lib/features/profile/profile_screen.dart — 1 spot (achievements card
    border).

NOT touched: lib/core/ascent.dart's `rankE = Color(0xFF8B949E)`. That one
only coincidentally matches an old palette value -- it's the deliberate
"graphite" color for the lowest rank tier (E), not a theme leftover, so
changing it would break the rank-color ladder rather than fix anything.

SAFETY: same exact-match-or-refuse rule as every other patch in this set.
Blanket per-file replaces are used only where I confirmed every
occurrence of that exact literal plays the same role (verified counts
below match what's actually in the file).
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


def apply_all(relpath, old, new, note, expect):
    path = _p(relpath)
    if not path.exists():
        FAILED.append(f"{relpath}: file not found")
        print(f"REFUSING {relpath}: file not found — {note}")
        return False
    text = path.read_text(encoding="utf-8")
    n = text.count(old)
    if n != expect:
        FAILED.append(f"{relpath}: {note} (expected {expect} matches, found {n})")
        print(f"REFUSING {relpath}: expected exactly {expect} matches for {note!r}, "
              f"found {n}. No changes made to this file.")
        return False
    path.write_text(text.replace(old, new), encoding="utf-8")
    LEDGER.append(f"OK   {relpath}: {note} ({n}x)")
    return True


# ═════════════════════════════════════════════════════════════════
# 1. Bottom nav bar (shell.dart) -- app-wide, highest visual impact
# ═════════════════════════════════════════════════════════════════
def patch_shell():
    apply_one(
        "lib/core/shell.dart",
        "    final bg         = widget.isDark ? const Color(0xFF161B22) : Colors.white;\n"
        "    final border     = widget.isDark ? const Color(0xFF21262D) : const Color(0xFFD0D7DE);",
        "    final bg         = widget.isDark ? AppColors.darkCard : Colors.white;\n"
        "    final border     = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;",
        "bottom nav bar bg/border -> new forest palette (was old gray on every screen)",
    )


# ═════════════════════════════════════════════════════════════════
# 2. home_screen.dart -- 3 leftover spots
# ═════════════════════════════════════════════════════════════════
def patch_home():
    F = "lib/features/home/home_screen.dart"
    apply_one(
        F,
        "      decoration: BoxDecoration(\n"
        "        color: const Color(0xFF161B22),\n"
        "        borderRadius: BorderRadius.circular(10),\n"
        "        border: Border.all(color: const Color(0xFF30363D), width: 0.5),\n"
        "      ),",
        "      decoration: BoxDecoration(\n"
        "        color: AppColors.darkCard,\n"
        "        borderRadius: BorderRadius.circular(10),\n"
        "        border: Border.all(color: AppColors.darkBorder, width: 0.5),\n"
        "      ),",
        "medical disclaimer banner -> new dark card/border",
    )
    apply_one(
        F,
        "          color: Color(0xFF8B949E),",
        "          color: AppColors.darkMuted,",
        "medical disclaimer text -> new dark muted",
    )
    apply_one(
        F,
        "..color = isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF)",
        "..color = isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF)",
        "ring-chart track color (dark branch) -> new dark border",
    )
    apply_one(
        F,
        "color: isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA),\n"
        "borderRadius: BorderRadius.circular(8),\n"
        "border: Border.all(\n"
        "color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),",
        "color: isDark ? AppColors.darkCardAlt : AppColors.lightCard,\n"
        "borderRadius: BorderRadius.circular(8),\n"
        "border: Border.all(\n"
        "color: isDark ? AppColors.darkBorder : AppColors.lightBorder,",
        "small icon button -> new palette",
    )


# ═════════════════════════════════════════════════════════════════
# 3. onboarding_screen.dart -- first-run flow, 11 occurrences total
# ═════════════════════════════════════════════════════════════════
def patch_onboarding():
    F = "lib/features/onboarding/onboarding_screen.dart"
    apply_one(
        F,
        "final bg     = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4F8);",
        "final bg     = isDark ? AppColors.darkBg : const Color(0xFFF0F4F8);",
        "screen background -> new dark bg",
    )
    apply_all(
        F,
        "isDark ? const Color(0xFF161B22) : Colors.white",
        "isDark ? AppColors.darkCard : Colors.white",
        "option-card backgrounds -> new dark card",
        expect=4,
    )
    apply_all(
        F,
        "isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF)",
        "isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF)",
        "option-card/button borders -> new dark border",
        expect=6,
    )


def check_onboarding_import():
    F = _p("lib/features/onboarding/onboarding_screen.dart")
    text = F.read_text(encoding="utf-8")
    if "core/theme.dart" not in text:
        FAILED.append(f"{F}: AppColors not imported -- add `import '../../core/theme.dart';`")
        print("WARNING: onboarding_screen.dart doesn't import theme.dart -- "
              "add `import '../../core/theme.dart';` near the top or AppColors "
              "references above won't compile.")


# ═════════════════════════════════════════════════════════════════
# 4. profile_screen.dart -- achievements card border
# ═════════════════════════════════════════════════════════════════
def patch_profile():
    apply_one(
        "lib/features/profile/profile_screen.dart",
        "          color: isDark ? const Color(0xFF21262D) : const Color(0xFFE8E4DF))),",
        "          color: isDark ? AppColors.darkBorder : const Color(0xFFE8E4DF))),",
        "achievements card border -> new dark border",
    )


def main():
    print("=" * 70)
    print("Palette cleanup: killing leftover old-theme hardcoded colors")
    print("=" * 70)
    patch_shell()
    patch_home()
    patch_onboarding()
    check_onboarding_import()
    patch_profile()

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
    print("Not touched (intentional, not a leftover): lib/core/ascent.dart's")
    print("rankE graphite color -- that's the E-rank tier color, not a theme bug.")


if __name__ == "__main__":
    main()
