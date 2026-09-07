# patch_lift_muscle_icons.py
#
# The "القوة المصنّفة" (Ranked Strength) screen — lib/features/fitness/
# lift_screen.dart — shows a 42x42 icon box next to every exercise
# (Squats, Hip Thrust, Leg Press, ...). Right now that box just renders
# exercise.glyph, a placeholder Unicode emoji (🦵 🍑 🦿 🤸 ...) picked as
# a joke/placeholder when the ranked-lifting feature was first built.
#
# This patch:
#   1. Extends lib/data/muscle_assets.dart with a per-exercise-id map
#      (kMuscleAssetByExerciseId) pointing each of the 13 kLiftExercises
#      entries at one of the assets/muscles/*.png illustrations, plus a
#      muscleAssetForExercise(id) helper (mirrors muscleAssetForCategory).
#   2. Edits _ExerciseRow in lift_screen.dart to render that image
#      instead of the emoji glyph, with an errorBuilder fallback back to
#      the original emoji so a missing/renamed asset can never crash the
#      row -- it just silently degrades to the old look.
#
# Mapping is by movement pattern, picked from the muscle set already
# shipped in assets/muscles/ (see the earlier leaf/muscle patch):
#   squat, legpress   -> quads_front.png      (quad-dominant)
#   deadlift          -> hamstrings_glutes_back.png
#   hipthrust         -> glutes.png
#   bench             -> torso_chest_abs.png
#   dip               -> chest_flex_crossed.png
#   pushup            -> bicep_flex_arm_v3.png  (chest+triceps, arm stand-in)
#   ohp               -> bicep_flex_arm_v2.png  (no dedicated deltoid art yet)
#   row               -> back_lats_v1.png
#   latpulldown       -> back_lats_v2.png
#   pullup            -> back_lats_v3.png
#   curl              -> bicep_flex_arm_v1.png
#   plank             -> abs_sixpack.png
# Reused/unassigned assets (calf_front/back, adductors_inner_thigh,
# obliques_ribcage_side, bicep_flex_hero, bicep_flex_side_v1) stay
# available for future exercises or the category-level fitness_screen
# mapping already in place -- nothing here touches that.
#
# NOTE on ohp: there's no shoulder/deltoid illustration in the current
# muscle pack, so it borrows an arm-flex image as a stand-in. Swap
# kMuscleAssetByExerciseId['ohp'] for a real deltoid asset whenever one
# gets added.
#
# Run from the project root (same folder as pubspec.yaml).

from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []


def _log(label, status):
    LEDGER.append((label, status))


def apply_literal(rel_path, old, new, label, skip_if=None):
    p = ROOT / rel_path
    if not p.exists():
        raise SystemExit(f"ERROR ({label}): {rel_path} not found under {ROOT}")
    text = p.read_text(encoding="utf-8")
    if skip_if is not None and old not in text and skip_if in text:
        _log(label, "SKIPPED-ALREADY")
        return
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"ERROR ({label}): expected 1 match, found {n} in {rel_path} "
                          f"-- refusing to guess, no changes made.")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")
    _log(label, "APPLIED")


MUSCLE_ASSETS = 'lib/data/muscle_assets.dart'
LIFT_SCREEN = 'lib/features/fitness/lift_screen.dart'

MARKER = "PATCH_LIFT_MUSCLE_ICONS"

EXERCISE_MAP_BLOCK = '''

// PATCH_LIFT_MUSCLE_ICONS
// Per-exercise (not per-category) mapping for the Ranked Lifting list --
// see lift_screen.dart's _ExerciseRow. Keyed by LiftExercise.id.
const Map<String, String> kMuscleAssetByExerciseId = {
  'squat':       'assets/muscles/quads_front.png',
  'deadlift':    'assets/muscles/hamstrings_glutes_back.png',
  'bench':       'assets/muscles/torso_chest_abs.png',
  'ohp':         'assets/muscles/bicep_flex_arm_v2.png', // no deltoid art yet
  'row':         'assets/muscles/back_lats_v1.png',
  'hipthrust':   'assets/muscles/glutes.png',
  'legpress':    'assets/muscles/quads_front.png',
  'latpulldown': 'assets/muscles/back_lats_v2.png',
  'curl':        'assets/muscles/bicep_flex_arm_v1.png',
  'pullup':      'assets/muscles/back_lats_v3.png',
  'dip':         'assets/muscles/chest_flex_crossed.png',
  'pushup':      'assets/muscles/bicep_flex_arm_v3.png',
  'plank':       'assets/muscles/abs_sixpack.png',
};

String? muscleAssetForExercise(String exerciseId) =>
    kMuscleAssetByExerciseId[exerciseId];
'''


def patch_muscle_assets_file():
    p = ROOT / MUSCLE_ASSETS
    if not p.exists():
        raise SystemExit(
            f"ERROR: {MUSCLE_ASSETS} not found -- run the earlier "
            f"leaf-ring/workout-assets patch first, it creates this file."
        )
    text = p.read_text(encoding="utf-8")
    if MARKER in text:
        _log('muscle_assets.dart: add kMuscleAssetByExerciseId', "SKIPPED-ALREADY")
        return
    p.write_text(text + EXERCISE_MAP_BLOCK, encoding="utf-8")
    _log('muscle_assets.dart: add kMuscleAssetByExerciseId', "APPLIED")


# -----------------------------------------------------------------------
# lift_screen.dart -- import muscle_assets.dart, swap the glyph Text for
# an Image.asset (with an errorBuilder fallback to the original emoji).
# -----------------------------------------------------------------------

LIFT_HUNKS = [
    (
        "import muscle_assets.dart",
        "import '../../core/providers.dart';\n"
        "import '../../core/l10n.dart';",
        "import '../../core/providers.dart';\n"
        "import '../../data/muscle_assets.dart';\n"
        "import '../../core/l10n.dart';",
    ),
    (
        "exercise glyph -> muscle illustration",
        """            child: Center(
                child: Text(exercise.glyph,
                    style: const TextStyle(fontSize: 20))),""",
        """            child: Center(
                child: muscleAssetForExercise(exercise.id) != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          muscleAssetForExercise(exercise.id)!,
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                          // PATCH_LIFT_MUSCLE_ICONS: never let a missing
                          // asset crash the row -- fall back to the emoji.
                          errorBuilder: (_, __, ___) => Text(exercise.glyph,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      )
                    : Text(exercise.glyph,
                        style: const TextStyle(fontSize: 20))),""",
    ),
]

LIFT_SKIP_MARKERS = [
    "import '../../data/muscle_assets.dart';",
    "muscleAssetForExercise(exercise.id)",
]


def patch_lift_screen():
    for (label, old, new), marker in zip(LIFT_HUNKS, LIFT_SKIP_MARKERS):
        apply_literal(LIFT_SCREEN, old, new,
                      f'lift_screen.dart: {label}', skip_if=marker)


def main():
    patch_muscle_assets_file()
    patch_lift_screen()

    print("\n=== lift-muscle-icons ledger ===")
    for label, status in LEDGER:
        print(f"[{status}] {label}")
    print("==================================\n")


if __name__ == "__main__":
    main()
