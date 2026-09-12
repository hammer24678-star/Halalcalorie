#!/usr/bin/env python3
"""
patch_v34_add_15_new_lifts_and_fix_icons.py
=============================================

Three things:

1. FIX: Bench Press icon. The old gymB_flat_bench_press.png (narrow
   grip, straight-leg-off-the-bench pose) reads as a lying triceps
   extension / skull crusher at 42px, not a bench press. Replaced
   with a clearer wide-grip, bent-knee flat-bench pose from the same
   pack (this script literally overwrites the file — see the asset
   drop-in step below, no Dart change needed for this part).

2. NOT FIXED: Back Squat. Both squat photos available in the icon
   packs you've sent so far show a FRONT squat (bar racked across
   the front of the shoulders, elbows up) rather than a back squat
   (bar on the traps, elbows down/back). There's no genuine back-squat
   pose in either pack, so nothing was swapped in here rather than
   trade one wrong picture for another. Options next time you have a
   minute: (a) send/source one proper back-squat reference image and
   I'll crop+wire it the same way as the others, or (b) I generate a
   fresh flat-illustration back-squat icon from scratch in this art
   style (won't be pixel-identical to the rest of the pack, but will
   at least show the right lift).

3. NEW: 15 additional Ranked Lift exercises, built from the poses in
   the 75-icon batch that don't already correspond to one of the
   existing 13 lifts (Romanian Deadlift, Seated Cable Row, One-Arm DB
   Row, Lateral Raise, Cable Fly, Tricep Pushdown, Incline Bench
   Press, Skull Crusher, Walking Lunge, Bulgarian Split Squat,
   Step-Up, Box Jump, Kettlebell Swing, Farmer's Carry, Russian
   Twist). That's 15, not 75 -- the other ~60 files in the batch were
   either color-recolored duplicates of the SAME pose (sheet2/sheet7
   and sheet3/sheet6 are the same 15 poses each, just re-tinted) or
   alternate art for a lift you already have (squat/bench/deadlift/
   row/ohp/curl/pullup/pushup/plank/dip/legpress/latpulldown all had
   a second-style duplicate in the batch). Adding 75 *rows* would
   mean several literally-identical entries for "Bench Press" etc.,
   so this wires in one entry per genuinely distinct movement instead.

   IMPORTANT CAVEAT: the strength-standard numbers (maleStandards/
   femaleStandards) for these 15 are ESTIMATES, extrapolated from the
   ratios of similar existing lifts -- NOT pulled from a published
   strength-standards table the way the original 13 were (see that
   comment in strength.dart). Treat Ranked tiers on these 15 as a
   reasonable first draft, not verified data. Happy to revise any of
   them if they feel off once you've logged a few real sets.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V34_15_NEW_LIFTS"

STRENGTH = "lib/core/strength.dart"
ICON_ASSETS = "lib/data/icon_assets.dart"
PUBSPEC = "pubspec.yaml"


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


NEW_LIFTS_DART = f"""  // {MARKER}: 15 new lifts, see this script's header for how these
  // were chosen and why standards below are estimates, not sourced
  // published data like the original 13 above.
  LiftExercise(
    id: 'rdl', nameEn: 'Romanian Deadlift', nameAr: 'رفعة رومانية', glyph: '🏋️',
    kind: LiftKind.loaded, group: 'back',
    maleStandards:   [0.50, 0.80, 1.10, 1.45, 1.80, 2.15, 2.50, 2.85, 3.20],
    femaleStandards: [0.35, 0.55, 0.80, 1.05, 1.35, 1.65, 1.90, 2.15, 2.40],
  ),
  LiftExercise(
    id: 'cablerow', nameEn: 'Seated Cable Row', nameAr: 'تجديف كابل جالس', glyph: '🚣',
    kind: LiftKind.loaded, group: 'back',
    maleStandards:   [0.35, 0.55, 0.78, 1.00, 1.25, 1.48, 1.68, 1.85, 2.05],
    femaleStandards: [0.25, 0.38, 0.55, 0.72, 0.90, 1.08, 1.22, 1.36, 1.50],
  ),
  LiftExercise(
    id: 'onearmrow', nameEn: 'One-Arm Dumbbell Row', nameAr: 'تجديف دمبل بيد واحدة', glyph: '🚣',
    kind: LiftKind.loaded, group: 'back',
    maleStandards:   [0.18, 0.28, 0.40, 0.53, 0.66, 0.79, 0.90, 1.00, 1.10],
    femaleStandards: [0.10, 0.16, 0.24, 0.32, 0.40, 0.48, 0.55, 0.62, 0.70],
  ),
  LiftExercise(
    id: 'farmerscarry', nameEn: "Farmer's Carry", nameAr: 'حمل المزارع', glyph: '🧳',
    kind: LiftKind.loaded, group: 'back',
    maleStandards:   [0.40, 0.60, 0.85, 1.10, 1.40, 1.70, 2.00, 2.30, 2.60],
    femaleStandards: [0.25, 0.40, 0.58, 0.78, 1.00, 1.22, 1.44, 1.65, 1.90],
  ),
  LiftExercise(
    id: 'lateralraise', nameEn: 'Lateral Raise', nameAr: 'رفرفة جانبية', glyph: '🤷',
    kind: LiftKind.loaded, group: 'shoulders',
    maleStandards:   [0.06, 0.10, 0.14, 0.19, 0.24, 0.29, 0.34, 0.39, 0.45],
    femaleStandards: [0.04, 0.06, 0.09, 0.12, 0.16, 0.20, 0.24, 0.28, 0.32],
  ),
  LiftExercise(
    id: 'cablefly', nameEn: 'Cable Fly', nameAr: 'فتح كابل للصدر', glyph: '🦋',
    kind: LiftKind.loaded, group: 'chest',
    maleStandards:   [0.10, 0.16, 0.24, 0.32, 0.40, 0.48, 0.55, 0.62, 0.70],
    femaleStandards: [0.06, 0.10, 0.15, 0.20, 0.26, 0.32, 0.38, 0.44, 0.50],
  ),
  LiftExercise(
    id: 'inclinebench', nameEn: 'Incline Bench Press', nameAr: 'بنش مائل', glyph: '💪',
    kind: LiftKind.loaded, group: 'chest',
    maleStandards:   [0.28, 0.45, 0.65, 0.90, 1.15, 1.40, 1.62, 1.82, 2.00],
    femaleStandards: [0.16, 0.26, 0.38, 0.52, 0.68, 0.84, 0.98, 1.10, 1.22],
  ),
  LiftExercise(
    id: 'triceppushdown', nameEn: 'Tricep Pushdown', nameAr: 'ضغط الترايسبس بالكابل', glyph: '💪',
    kind: LiftKind.loaded, group: 'arms',
    maleStandards:   [0.15, 0.24, 0.34, 0.45, 0.56, 0.68, 0.79, 0.90, 1.00],
    femaleStandards: [0.08, 0.13, 0.19, 0.26, 0.33, 0.40, 0.46, 0.53, 0.60],
  ),
  LiftExercise(
    id: 'skullcrusher', nameEn: 'Skull Crusher', nameAr: 'كسر الجمجمة', glyph: '💀',
    kind: LiftKind.loaded, group: 'arms',
    maleStandards:   [0.15, 0.24, 0.34, 0.45, 0.56, 0.68, 0.79, 0.90, 1.00],
    femaleStandards: [0.08, 0.13, 0.19, 0.26, 0.33, 0.40, 0.46, 0.53, 0.60],
  ),
  LiftExercise(
    id: 'walklunge', nameEn: 'Walking Lunge', nameAr: 'اندفاع بالمشي', glyph: '🚶',
    kind: LiftKind.loaded, group: 'legs',
    maleStandards:   [0.15, 0.25, 0.38, 0.52, 0.68, 0.84, 1.00, 1.15, 1.30],
    femaleStandards: [0.10, 0.18, 0.28, 0.40, 0.52, 0.65, 0.78, 0.90, 1.02],
  ),
  LiftExercise(
    id: 'splitsquat', nameEn: 'Bulgarian Split Squat', nameAr: 'سكوات بلغاري', glyph: '🦵',
    kind: LiftKind.loaded, group: 'legs',
    maleStandards:   [0.15, 0.25, 0.38, 0.52, 0.68, 0.84, 1.00, 1.15, 1.30],
    femaleStandards: [0.10, 0.18, 0.28, 0.40, 0.52, 0.65, 0.78, 0.90, 1.02],
  ),
  LiftExercise(
    id: 'stepup', nameEn: 'Box Step-Up', nameAr: 'صعود الصندوق', glyph: '🪜',
    kind: LiftKind.loaded, group: 'legs',
    maleStandards:   [0.20, 0.32, 0.46, 0.62, 0.78, 0.95, 1.10, 1.25, 1.40],
    femaleStandards: [0.12, 0.20, 0.30, 0.42, 0.54, 0.66, 0.78, 0.90, 1.00],
  ),
  LiftExercise(
    id: 'kbswing', nameEn: 'Kettlebell Swing', nameAr: 'أرجحة الكيتل بيل', glyph: '🏋️',
    kind: LiftKind.loaded, group: 'legs',
    maleStandards:   [0.20, 0.32, 0.45, 0.60, 0.75, 0.90, 1.05, 1.20, 1.35],
    femaleStandards: [0.14, 0.22, 0.32, 0.44, 0.56, 0.68, 0.80, 0.92, 1.05],
  ),
  LiftExercise(
    id: 'boxjump', nameEn: 'Box Jump', nameAr: 'قفز الصندوق', glyph: '📦',
    kind: LiftKind.bodyweight, group: 'legs',
    maleStandards:   [5, 10, 18, 28, 40, 52, 65, 80, 95],
    femaleStandards: [3, 7, 13, 20, 30, 40, 50, 62, 75],
  ),
  LiftExercise(
    id: 'russiantwist', nameEn: 'Russian Twist', nameAr: 'لفة روسية', glyph: '🌀',
    kind: LiftKind.loaded, group: 'core',
    maleStandards:   [0.10, 0.16, 0.24, 0.32, 0.40, 0.48, 0.56, 0.64, 0.72],
    femaleStandards: [0.06, 0.10, 0.15, 0.20, 0.26, 0.32, 0.38, 0.44, 0.50],
  ),
"""

NEW_ICON_ENTRIES = f"""  // {MARKER}: icons for the 15 new lifts above.
  'rdl': '$_kIcons/gym_strength/gymD_romanian_deadlift.png',
  'cablerow': '$_kIcons/gym_strength/gymD_seated_cable_row.png',
  'onearmrow': '$_kIcons/gym_strength/gymD_one_arm_row.png',
  'farmerscarry': '$_kIcons/gym_strength/gymD_farmers_carry.png',
  'lateralraise': '$_kIcons/gym_strength/gymD_lateral_raise.png',
  'cablefly': '$_kIcons/gym_strength/gymD_cable_fly.png',
  'inclinebench': '$_kIcons/gym_strength/gymD_incline_bench.png',
  'triceppushdown': '$_kIcons/gym_strength/gymD_tricep_pushdown.png',
  'skullcrusher': '$_kIcons/gym_strength/gymD_skull_crusher.png',
  'walklunge': '$_kIcons/gym_strength/gymD_walking_lunge.png',
  'splitsquat': '$_kIcons/gym_strength/gymD_split_squat.png',
  'stepup': '$_kIcons/gym_strength/gymD_step_up.png',
  'kbswing': '$_kIcons/gym_strength/gymD_kettlebell_swing.png',
  'boxjump': '$_kIcons/gym_strength/gymD_box_jump.png',
  'russiantwist': '$_kIcons/gym_strength/gymD_russian_twist.png',
"""


def main():
    print("=" * 70)
    print("v34 — 15 new Ranked Lifts + bench-press icon fix")
    print("=" * 70)

    # ── 1. strength.dart: insert the 15 new LiftExercise entries ──────
    edit(STRENGTH,
         "  LiftExercise(\n"
         "    id: 'plank', nameEn: 'Plank', nameAr: 'بلانك', glyph: '🧘',\n"
         "    kind: LiftKind.timed, group: 'core',\n"
         "    maleStandards:   [20, 45, 75, 110, 150, 195, 240, 300, 360],\n"
         "    femaleStandards: [15, 35, 60, 95, 130, 170, 215, 270, 330],\n"
         "  ),\n"
         "];",
         "  LiftExercise(\n"
         "    id: 'plank', nameEn: 'Plank', nameAr: 'بلانك', glyph: '🧘',\n"
         "    kind: LiftKind.timed, group: 'core',\n"
         "    maleStandards:   [20, 45, 75, 110, 150, 195, 240, 300, 360],\n"
         "    femaleStandards: [15, 35, 60, 95, 130, 170, 215, 270, 330],\n"
         "  ),\n"
         f"{NEW_LIFTS_DART}"
         "];",
         "strength.dart: insert 15 new LiftExercise entries")

    # ── 2. icon_assets.dart: wire icons for the 15 new lifts ──────────
    edit(ICON_ASSETS,
         "  'plank': '$_kIcons/gym_strength/gymC_plank.png',\n"
         "};",
         "  'plank': '$_kIcons/gym_strength/gymC_plank.png',\n"
         f"{NEW_ICON_ENTRIES}"
         "};",
         "icon_assets.dart: wire 15 new exercise icons")

    # ── 3. pubspec.yaml: declare the full 75-icon reference folder ────
    # (committed a few patches ago but never added to the asset list,
    # so Flutter wasn't actually bundling it)
    edit(PUBSPEC,
         "    - assets/icons/gym_strength/\n",
         "    - assets/icons/gym_strength/\n"
         "    - assets/icons/gym_strength_v2/\n",
         "pubspec: declare assets/icons/gym_strength_v2/")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Also drop in the icon files from assets/icons/gym_strength/ in the zip
I gave you -- 15 new gymD_*.png files, plus an OVERWRITTEN
gymB_flat_bench_press.png (the bench-press fix). Copy all 16 into your
assets/icons/gym_strength/ folder, replacing the old bench file.

Back Squat's icon is UNTOUCHED -- still the front-squat picture, see
this script's header for why. Let me know how you want to handle it.

Next:
  1. flutter clean && flutter pub get
  2. flutter analyze
  3. Ranked Lifts should now show 28 exercises across the same 6
     muscle-group sections, and Bench Press's icon should read
     clearly as a bench press now.
""")


if __name__ == "__main__":
    main()
