#!/usr/bin/env python3
"""
patch_v33_dark_fringe_and_duplicate_icon.py
=============================================

Fixes two bugs visible in the screenshots:

1. Health Articles tab: article badges use a plain Image.asset() instead
   of darkSafeAsset(), so in dark mode the transparent-PNG fringe shows up
   as a light halo around every article icon (bone, salad bowl, etc).
   patch_v32_health_article_icons.py added the Image.asset call but never
   routed it through darkSafeAsset the way every other icon call site does.

2. models.dart: patch_v32b wired h9 ("قراءة الملصق الغذائي" / reading food
   labels) to the SAME iconAsset ('digestion_fiber') as h6 ("الهضم والألياف"
   / digestion & fiber). Both articles show the identical salad-bowl icon.
   There's no dedicated "label reading" illustration yet, so this patch
   just un-wires h9's iconAsset so it falls back to its own emoji (🥗ish
   distinct glyph) instead of visually duplicating h6. Swap in a real
   'label_reading' asset later and re-wire it the same way h1..h8/h10 are.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []

HEALTH_SCREEN = "lib/features/health/health_screen.dart"
MODELS = "lib/data/models/models.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        _log(label, "SKIPPED-NOT-FOUND")
        return False
    text = p.read_text(encoding="utf-8")
    if old not in text:
        if new in text:
            _log(label, "SKIPPED-ALREADY")
        else:
            _log(label, "SKIPPED-NOT-FOUND")
        return False
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")
    return True


def main():
    print("=" * 70)
    print("v33 — dark-mode article-icon fringe + duplicate icon fix")
    print("=" * 70)

    # ── 1. Route the Health Articles badge through darkSafeAsset ──────
    edit(HEALTH_SCREEN,
         "                    child: Center(child: a.iconAsset != null\n"
         "                        ? Image.asset(healthArticleAsset(a.iconAsset!),\n"
         "                            width: 28, height: 28, fit: BoxFit.contain,\n"
         "                            errorBuilder: (_, __, ___) => Text(a.icon,\n"
         "                                style: const TextStyle(fontSize: 24)))\n"
         "                        : Text(a.icon,\n"
         "                            style: const TextStyle(fontSize: 24))),",
         "                    // PATCH_V33_DARK_FRINGE_FIX: darkSafeAsset composites a\n"
         "                    // plate behind the transparent PNG in dark mode so the\n"
         "                    // light fringe doesn't show against the dark card.\n"
         "                    child: Center(child: a.iconAsset != null\n"
         "                        ? darkSafeAsset(healthArticleAsset(a.iconAsset!),\n"
         "                            width: 28, height: 28, fit: BoxFit.contain,\n"
         "                            isDark: isDark,\n"
         "                            plateColor: Color.alphaBlend(\n"
         "                                artColor.withOpacity(0.18), bg),\n"
         "                            errorChild: Text(a.icon,\n"
         "                                style: const TextStyle(fontSize: 24)))\n"
         "                        : Text(a.icon,\n"
         "                            style: const TextStyle(fontSize: 24))),",
         "health_screen: article badge -> darkSafeAsset")

    # ── 2. Un-wire h9's duplicate iconAsset (was copy-pasted from h6) ──
    edit(MODELS,
         "icon:'🥗', iconAsset:'digestion_fiber', colorValue:0xFF009688, title:'قراءة الملصق الغذائي',",
         "icon:'🥗', colorValue:0xFF009688, title:'قراءة الملصق الغذائي',",
         "models: h9 -> stop reusing h6's digestion_fiber icon")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Also drop the corrected exercise illustrations from
assets/icons/gym_strength_new/ into assets/icons/gym_strength/
(overwriting the old mismatched files) -- see NOTES_workout_icons.md
for exactly which file replaces which and why. No code changes are
needed for that part: lift_screen.dart's exerciseIconAsset() mapping
was already correct, it was the art at those paths that was wrong.

Next:
  1. Copy the new PNGs into assets/icons/gym_strength/
  2. flutter clean && flutter pub get
  3. flutter analyze (should be clean)
  4. Check Health > Articles and Fitness > Ranked Lifting in both themes.
""")


if __name__ == "__main__":
    main()
