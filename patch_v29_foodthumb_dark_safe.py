#!/usr/bin/env python3
"""
patch_v29_foodthumb_dark_safe.py
=================================

The Add Food list (and every other food icon in the app — history rows,
quick-add grid, search results, the "whole food logged" snackbar — they
all render through the single `FoodThumb` widget) was never touched by
v26-v28. Those patches only wired darkSafeAsset() into mood faces,
status glyphs, the mosque mark and the splash logo. FoodThumb's
`_content()` still draws its PNG via a plain `Image.asset(...)`, so it
shows the same light fringe on dark surfaces that v26 was written to
fix everywhere else.

This patch:
  1. lib/core/food_emoji.dart — import icon_assets.dart, and switch
     FoodThumb's asset branch from Image.asset to darkSafeAsset, same
     forest-plate composite used elsewhere. `_content()` is a State
     method, so `context` (and therefore `Theme.of(context)`) is
     always available there — no scope issue like the home_screen one.
  2. lib/features/nutrition/nutrition_screen.dart — same fringe on the
     small icon in the "whole food — logged!" SnackBar; fixed the same
     way (isDark is already in scope there, it's just a nested closure
     in the same build method).

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V29_FOODTHUMB_DARK_SAFE"

FOOD_EMOJI = "lib/core/food_emoji.dart"
NUTR = "lib/features/nutrition/nutrition_screen.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = p.read_text(encoding="utf-8")
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")


def main():
    print("=" * 70)
    print("v29 — FoodThumb dark-safe asset (fixes Add Food list fringe)")
    print("=" * 70)

    p = ROOT / FOOD_EMOJI
    if not p.exists():
        _log(f"{FOOD_EMOJI}: file", "SKIPPED-NOT-FOUND")
    else:
        text = p.read_text(encoding="utf-8")
        if MARKER in text:
            _log("food_emoji: already patched", "SKIPPED-ALREADY")
        else:
            changed = False

            # 1. import icon_assets.dart for darkSafeAsset
            old_imports = (
                "import 'package:flutter/material.dart';\n"
                "import 'package:connectivity_plus/connectivity_plus.dart';\n"
                "import 'open_food_facts_service.dart';\n"
            )
            new_imports = (
                "import 'package:flutter/material.dart';\n"
                "import 'package:connectivity_plus/connectivity_plus.dart';\n"
                "import 'open_food_facts_service.dart';\n"
                f"import '../data/icon_assets.dart'; // {MARKER}\n"
            )
            if old_imports in text:
                text = text.replace(old_imports, new_imports, 1)
                changed = True
                _log("food_emoji: import icon_assets.dart", "OK")
            elif "'../data/icon_assets.dart'" in text:
                _log("food_emoji: import icon_assets.dart", "SKIPPED-ALREADY")
            else:
                _log("food_emoji: import icon_assets.dart", "SKIPPED-NOT-FOUND")

            # 2. swap Image.asset -> darkSafeAsset in the asset branch
            old_content = """    if (_assetPath != null) {
      return Image.asset(
        _assetPath!,
        fit: BoxFit.contain,
        width: widget.size,
        height: widget.size,
        errorBuilder: (_, __, ___) =>
            _glyphView(_glyph ?? kFoodGlyphFallback),
      );
    }"""
            new_content = f"""    if (_assetPath != null) {{
      // {MARKER}: forest-plate composite kills the light PNG fringe
      // in dark mode (same fix as mood faces / status glyphs).
      return darkSafeAsset(
        _assetPath!,
        fit: BoxFit.contain,
        width: widget.size,
        height: widget.size,
        isDark: Theme.of(context).brightness == Brightness.dark,
        radius: BorderRadius.circular(widget.radius),
        errorChild: _glyphView(_glyph ?? kFoodGlyphFallback),
      );
    }}"""
            if old_content in text:
                text = text.replace(old_content, new_content, 1)
                changed = True
                _log("food_emoji: FoodThumb Image.asset -> darkSafeAsset", "OK")
            else:
                _log("food_emoji: FoodThumb Image.asset -> darkSafeAsset", "SKIPPED-NOT-FOUND")

            if changed:
                p.write_text(text, encoding="utf-8")

    # Nutrition: "whole food logged" snackbar icon
    old_snack = """                      wholesomeFoodAsset(wholesome.$4) != null
                        ? Image.asset(wholesomeFoodAsset(wholesome.$4)!,
                            width: 20, height: 20,
                            errorBuilder: (_, __, ___) => Text(wholesome.$1,
                                style: const TextStyle(fontSize: 20)))
                        : Text(wholesome.$1,
                            style: const TextStyle(fontSize: 20)),"""
    new_snack = f"""                      // {MARKER}
                      wholesomeFoodAsset(wholesome.$4) != null
                        ? darkSafeAsset(wholesomeFoodAsset(wholesome.$4)!,
                            width: 20, height: 20, isDark: isDark,
                            errorChild: Text(wholesome.$1,
                                style: const TextStyle(fontSize: 20)))
                        : Text(wholesome.$1,
                            style: const TextStyle(fontSize: 20)),"""
    edit(NUTR, old_snack, new_snack, "nutrition: wholesome-logged snackbar icon")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next: flutter clean && flutter pub get, then rebuild.
This fixes FoodThumb everywhere it's used (Add Food list, quick-add
grid, search results, history rows) since they all go through the
same widget. If some other spot still shows a fringe after this, it's
rendering its own Image.asset outside FoodThumb/darkSafeAsset — send
the file/line and I'll wire that one in too.
""")


if __name__ == "__main__":
    main()
