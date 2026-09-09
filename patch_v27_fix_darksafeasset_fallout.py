#!/usr/bin/env python3
"""
patch_v27_fix_darksafeasset_fallout.py
=======================================

Fixes the build breakage left by patch_v26_dark_outline_arabic_titles.py.

Root causes (from the CI log):

1. `_patch_mosque_and_glyphs()` in v26 had two families of find/replace
   pairs for status-glyph and wholesome-food call sites. The
   "full block" pairs (old string includes the trailing
   `errorBuilder: (_, __, ___) => X`) rewrote correctly to
   `errorChild: X`. But three call sites only had their *opening*
   `Image.asset(...)` -> `darkSafeAsset(...)` fragment matched:

       Image.asset(statusGlyphForEmoji(widget.emoji)!, width: 18, height: 18,
       Image.asset(statusGlyphForEmoji(item.emoji)!, width: 20, height: 20,
       Image.asset(f['asset']!, width: 18, height: 18,   (HOME_WHOLESOME_OLD)

   The old `errorBuilder: (_, __, ___) => ...)` tail one line down was
   never touched, so those three calls ended up as
   `darkSafeAsset(..., isDark: isDark, errorBuilder: (_, __, ___) => ...)`.
   `darkSafeAsset` has no `errorBuilder` parameter (only `errorChild`) ->
   the 3 "No named parameter 'errorBuilder'" errors in home_screen.dart.

2. The health status-glyph rewrite inserted `isDark: isDark` at a call
   site that isn't inside the scope where the build method's local
   `isDark` bool is defined (a different helper/branch inside
   `_HealthScreenState`) -> "getter 'isDark' isn't defined" at
   health_screen.dart:550.

This patch:
  A) Scans every `darkSafeAsset(...)` call (balanced-paren aware, so it
     doesn't care about exact whitespace/line breaks) in the affected
     screens and converts any leftover
     `errorBuilder: (_, __, ___) => X` tail to `errorChild: X`.
  B) Rewrites the one broken `isDark: isDark` reference in
     health_screen.dart's status-glyph call to compute brightness
     locally via `Theme.of(context).brightness == Brightness.dark`,
     which doesn't depend on which method/branch it's called from.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []

MARKER_A = "PATCH_V27_FIX_DARKSAFEASSET_ERRORBUILDER"
MARKER_B = "PATCH_V27_FIX_HEALTH_ISDARK_SCOPE"

# Screens that call darkSafeAsset() per v26 — safe to scan all of them,
# this is a no-op on files where nothing is broken.
SCREENS_TO_SCAN = [
    "lib/features/home/home_screen.dart",
    "lib/features/health/health_screen.dart",
    "lib/features/splash/splash_screen.dart",
    "lib/features/fitness/fitness_screen.dart",
    "lib/features/nutrition/nutrition_screen.dart",
]

HEALTH = "lib/features/health/health_screen.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def _find_balanced_call(text, start_idx):
    """Given the index of the 'd' in 'darkSafeAsset(', return the index
    of the matching closing ')' for that call, using paren depth
    counting (ignores parens inside strings — not needed here since
    darkSafeAsset call args in this codebase contain no parens inside
    string literals)."""
    open_paren = text.index("(", start_idx)
    depth = 0
    k = open_paren
    n = len(text)
    while k < n:
        c = text[k]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return k
        k += 1
    raise ValueError("Unbalanced parens scanning darkSafeAsset(...) call")


def fix_dangling_error_builder(rel_path):
    p = ROOT / rel_path
    if not p.exists():
        _log(f"{rel_path}: file", "SKIPPED-NOT-FOUND")
        return
    text = p.read_text(encoding="utf-8")

    out = []
    i = 0
    n = len(text)
    changed = False
    fixed_count = 0

    while True:
        idx = text.find("darkSafeAsset(", i)
        if idx == -1:
            out.append(text[i:])
            break
        out.append(text[i:idx])
        close_idx = _find_balanced_call(text, idx)
        call_text = text[idx:close_idx + 1]
        new_call = call_text.replace("errorBuilder: (_, __, ___) =>", "errorChild:")
        if new_call != call_text:
            changed = True
            fixed_count += 1
        out.append(new_call)
        i = close_idx + 1

    if not changed:
        _log(f"{rel_path}: darkSafeAsset errorBuilder->errorChild", "SKIPPED-NOT-FOUND")
        return

    new_text = "".join(out)
    if MARKER_A not in new_text:
        new_text = f"// {MARKER_A}\n" + new_text
    p.write_text(new_text, encoding="utf-8")
    _log(f"{rel_path}: darkSafeAsset errorBuilder->errorChild ({fixed_count}x)", "OK")


def fix_health_isdark_scope():
    p = ROOT / HEALTH
    if not p.exists():
        _log(f"{HEALTH}: file", "SKIPPED-NOT-FOUND")
        return
    text = p.read_text(encoding="utf-8")

    if MARKER_B in text:
        _log("health: isDark scope fix", "SKIPPED-ALREADY")
        return

    old = "darkSafeAsset(statusGlyphForEmoji(emoji)!, width: 20, height: 20, isDark: isDark,"
    new = (
        f"// {MARKER_B}: isDark isn't in scope at this call site, compute locally\n"
        "                  darkSafeAsset(statusGlyphForEmoji(emoji)!, width: 20, height: 20,\n"
        "                      isDark: Theme.of(context).brightness == Brightness.dark,"
    )

    if old not in text:
        _log("health: isDark scope fix", "SKIPPED-NOT-FOUND")
        return

    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log("health: isDark scope fix", "OK")


def main():
    print("=" * 70)
    print("v27 — fix v26 fallout (dangling errorBuilder + isDark scope)")
    print("=" * 70)

    for rel in SCREENS_TO_SCAN:
        fix_dangling_error_builder(rel)

    fix_health_isdark_scope()

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s.startswith("OK"))
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next: flutter clean && flutter pub get, then rebuild.
If health_screen.dart still fails on 'context' not being in scope at
that call site, that call is inside a method with no BuildContext
parameter — in that case pass isDark in from the caller instead of
computing Theme.of(context) there.
""")


if __name__ == "__main__":
    main()
