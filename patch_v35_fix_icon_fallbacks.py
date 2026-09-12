#!/usr/bin/env python3
"""
patch_v35_fix_icon_fallbacks.py
=============================================

Two things wrong, one real code bug and one asset-location problem,
plus a defensive fix so this class of bug stops looking so bad.

1. BUG: "قراءة الملصق الغذائي" (h9) is back to sharing h6's salad-bowl
   icon. patch_v33 removed that duplicate; patch_v32b ran *after* v33
   in your actual git history (despite the lower version number) and
   silently re-added it. This un-wires it again.

2. NOT A CODE BUG -- an asset-location problem: icon_assets.dart's
   paths for the 15 new Ranked Lifts and all 9 health-article icons
   are correct (checked against the dump). The emoji you're seeing
   (walking lunge, split squat, step-up, kettlebell swing, box jump,
   and the blood-drop health icon) is darkSafeAsset's errorChild --
   it only fires when the PNG at that exact path can't be loaded. So
   those specific files aren't sitting where the code expects, even
   though the 75-icon batch exists on disk somewhere. This script
   searches assets/icons/** for a same-subject file and copies it
   into the exact expected filename when it finds exactly one match.
   Anything it can't find gets printed plainly so you know exactly
   what's still missing.

3. COSMETIC (always applied, independent of #2): whatever's still on
   emoji after this runs was rendering at full native size and full
   saturation with no dimming, which is why it visually pops next to
   the flatter illustrated icons -- that's the "blood looks out of
   place" effect. Shrinks + dims the fallback so a future gap in the
   icon set degrades quietly instead of sticking out.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V35_ICON_FALLBACKS"

MODELS = "lib/data/models/models.dart"
HEALTH_SCREEN = "lib/features/health/health_screen.dart"
LIFT_SCREEN = "lib/features/fitness/lift_screen.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:28s} {label}")


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


# ── expected path -> fuzzy tokens to search assets/icons/** for a same-subject file ──
REQUIRED_ASSETS = [
    ("assets/icons/health/water.png",          ["water"]),
    ("assets/icons/health/sleep.png",           ["sleep"]),
    ("assets/icons/health/heart.png",           ["heart"]),
    ("assets/icons/health/brain.png",           ["brain"]),
    ("assets/icons/health/bones.png",           ["bone"]),
    ("assets/icons/health/digestion_fiber.png", ["digest", "fiber"]),
    ("assets/icons/health/stress_relax.png",    ["stress", "relax", "meditat"]),
    ("assets/icons/health/weight_bmi.png",      ["weight", "bmi", "scale"]),
    ("assets/icons/health/checkup_blood.png",   ["blood", "checkup"]),
    ("assets/icons/gym_strength/gymB_flat_bench_press.png",  ["bench"]),
    ("assets/icons/gym_strength/gymD_romanian_deadlift.png", ["romanian", "_rdl"]),
    ("assets/icons/gym_strength/gymD_seated_cable_row.png",  ["cable_row", "cablerow", "seated_row"]),
    ("assets/icons/gym_strength/gymD_one_arm_row.png",       ["one_arm_row", "onearmrow", "one_arm_db"]),
    ("assets/icons/gym_strength/gymD_farmers_carry.png",     ["farmer"]),
    ("assets/icons/gym_strength/gymD_lateral_raise.png",     ["lateral"]),
    ("assets/icons/gym_strength/gymD_cable_fly.png",         ["cable_fly", "cablefly", "chest_fly"]),
    ("assets/icons/gym_strength/gymD_incline_bench.png",     ["incline"]),
    ("assets/icons/gym_strength/gymD_tricep_pushdown.png",   ["pushdown"]),
    ("assets/icons/gym_strength/gymD_skull_crusher.png",     ["skull"]),
    ("assets/icons/gym_strength/gymD_walking_lunge.png",     ["lunge"]),
    ("assets/icons/gym_strength/gymD_split_squat.png",       ["split_squat", "splitsquat", "bulgarian"]),
    ("assets/icons/gym_strength/gymD_step_up.png",           ["step_up", "stepup", "box_step"]),
    ("assets/icons/gym_strength/gymD_kettlebell_swing.png",  ["kettlebell", "kb_swing", "kbswing"]),
    ("assets/icons/gym_strength/gymD_box_jump.png",          ["box_jump", "boxjump"]),
    ("assets/icons/gym_strength/gymD_russian_twist.png",     ["russian"]),
]


def _norm(p: Path) -> str:
    return p.stem.lower().replace("-", "_").replace(" ", "_")


def scan_and_heal():
    icons_root = ROOT / "assets" / "icons"
    all_pngs = list(icons_root.rglob("*.png")) if icons_root.exists() else []

    print()
    print("-" * 70)
    print(f"Asset scan: {len(all_pngs)} PNGs found under assets/icons/**")
    print("-" * 70)

    healed, missing = [], []

    for rel, tokens in REQUIRED_ASSETS:
        target = ROOT / rel
        if target.exists():
            _log(rel, "PRESENT")
            continue

        candidates = [
            f for f in all_pngs
            if f.resolve() != target.resolve()
            and any(tok in _norm(f) for tok in tokens)
        ]

        if len(candidates) == 1:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidates[0], target)
            _log(rel, f"HEALED <- {candidates[0].relative_to(ROOT)}")
            healed.append(rel)
        elif len(candidates) > 1:
            _log(rel, f"AMBIGUOUS ({len(candidates)} matches, none copied)")
            for c in candidates:
                print(f"        candidate: {c.relative_to(ROOT)}")
            missing.append(rel)
        else:
            _log(rel, "MISSING (not found anywhere under assets/icons/**)")
            missing.append(rel)

    return healed, missing


def main():
    print("=" * 70)
    print("v35 -- icon fallback fixes: h9 dup, dim/shrink emoji, asset auto-heal")
    print("=" * 70)

    # ── 1. models.dart: h9 duplicate icon (v32b silently undid v33) ──────
    edit(MODELS,
         "icon:'🥗', iconAsset:'digestion_fiber', colorValue:0xFF009688, title:'قراءة الملصق الغذائي',",
         "icon:'🥗', colorValue:0xFF009688, title:'قراءة الملصق الغذائي', "
         f"// {MARKER}: v32b re-added the h6 duplicate v33 had removed",
         "models: h9 -> stop reusing h6's digestion_fiber icon (again)")

    # ── 2. health_screen.dart: dim + shrink the article-icon fallback ────
    edit(HEALTH_SCREEN,
         "                    // PATCH_V32_HEALTH_ARTICLE_ICONS: illustrated badge, emoji stays\n"
         "                    // as the errorBuilder fallback.\n"
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
         f"                    // {MARKER}: emoji fallback dimmed + shrunk to match\n"
         "                    // the 28px illustrated badges instead of popping as a\n"
         "                    // full-size native emoji.\n"
         "                    child: Center(child: a.iconAsset != null\n"
         "                        ? darkSafeAsset(healthArticleAsset(a.iconAsset!),\n"
         "                            width: 28, height: 28, fit: BoxFit.contain,\n"
         "                            isDark: isDark,\n"
         "                            plateColor: Color.alphaBlend(\n"
         "                                artColor.withOpacity(0.18), bg),\n"
         "                            errorChild: Opacity(opacity: 0.55, child: Text(a.icon,\n"
         "                                style: const TextStyle(fontSize: 18))))\n"
         "                        : Opacity(opacity: 0.55, child: Text(a.icon,\n"
         "                            style: const TextStyle(fontSize: 18)))),",
         "health_screen: dim + shrink article-icon fallback")

    # ── 3. lift_screen.dart: dim + shrink the exercise-icon fallback ─────
    edit(LIFT_SCREEN,
         "            child: Center(\n"
         "                // PATCH_V30_DARKSAFE_PLATE_COLOR: plate matched to this row's own tinted\n"
         "                // background instead of the mismatched v26 default.\n"
         "                child: exerciseIconAsset(exercise.id) != null\n"
         "                    ? darkSafeAsset(\n"
         "                        exerciseIconAsset(exercise.id)!,\n"
         "                        width: 30,\n"
         "                        height: 30,\n"
         "                        fit: BoxFit.contain,\n"
         "                        isDark: Theme.of(context).brightness == Brightness.dark,\n"
         "                        radius: BorderRadius.circular(10),\n"
         "                        plateColor: Color.alphaBlend(\n"
         "                            (logged ? rank.color : muted).withOpacity(0.10), card),\n"
         "                        // PATCH_LIFT_MUSCLE_ICONS: never let a missing\n"
         "                        // asset crash the row -- fall back to the emoji.\n"
         "                        errorChild: Text(exercise.glyph,\n"
         "                            style: const TextStyle(fontSize: 20)),\n"
         "                      )\n"
         "                    : Text(exercise.glyph,\n"
         "                        style: const TextStyle(fontSize: 20))),\n"
         "          ),",
         "            child: Center(\n"
         "                // PATCH_V30_DARKSAFE_PLATE_COLOR: plate matched to this row's own tinted\n"
         "                // background instead of the mismatched v26 default.\n"
         f"                // {MARKER}: emoji fallback dimmed + shrunk to match\n"
         "                // the 30px illustrated icons instead of popping as a\n"
         "                // full-size native emoji.\n"
         "                child: exerciseIconAsset(exercise.id) != null\n"
         "                    ? darkSafeAsset(\n"
         "                        exerciseIconAsset(exercise.id)!,\n"
         "                        width: 30,\n"
         "                        height: 30,\n"
         "                        fit: BoxFit.contain,\n"
         "                        isDark: Theme.of(context).brightness == Brightness.dark,\n"
         "                        radius: BorderRadius.circular(10),\n"
         "                        plateColor: Color.alphaBlend(\n"
         "                            (logged ? rank.color : muted).withOpacity(0.10), card),\n"
         "                        // PATCH_LIFT_MUSCLE_ICONS: never let a missing\n"
         "                        // asset crash the row -- fall back to the emoji.\n"
         "                        errorChild: Opacity(opacity: 0.5, child: Text(exercise.glyph,\n"
         "                            style: const TextStyle(fontSize: 15))),\n"
         "                      )\n"
         "                    : Opacity(opacity: 0.5, child: Text(exercise.glyph,\n"
         "                        style: const TextStyle(fontSize: 15)))),\n"
         "          ),",
         "lift_screen: dim + shrink exercise-icon fallback")

    # ── 4. scan assets/icons/** and auto-heal what it can find ───────────
    healed, missing = scan_and_heal()

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} code fix(es) applied. {len(healed)} icon(s) auto-healed from elsewhere in assets/icons/**.")
    if missing:
        print(f"{len(missing)} icon(s) still need a source file -- see MISSING/AMBIGUOUS lines above.")
    print("=" * 70)
    print("""
Next:
  1. flutter clean && flutter pub get
  2. flutter analyze
  3. Check Health > Articles and Fitness > Ranked Lifting in both themes.
     - "قراءة الملصق الغذائي" no longer shares h6's salad-bowl icon.
     - Anything still MISSING above renders as a small, dimmed emoji
       instead of a full-size one -- drop the matching PNG at the exact
       path printed and re-run this script to wire it in for real.
""")


if __name__ == "__main__":
    main()
