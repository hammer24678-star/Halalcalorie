#!/usr/bin/env python3
"""
patch_v15_fitness_icons.py — Fitness screen: real workout icons
==================================================================

WHAT I FOUND FIRST
  Same story as nutrition: fitness_screen.dart already matches the v10
  mockup structurally -- same 7 category tabs (all/walking/strength/
  gentle/ramadan/breathing/family), the exact same coaching-line text
  ("القوة تُبنى بالتكرار، لا بيوم واحد شديد"), the same card-based look.
  It even already has an earlier PATCH_NEW_ASSET_PACKS asset (a faint
  muscle-category watermark on each card). No layout rebuild needed.

  The one real gap: each workout card's icon is still a plain emoji
  (🚶🏋️🌙 etc.) even though you have 90 gender-matched illustrated icons
  (workouts_brothers/, workouts_sisters_hijab/) sitting unused.

WHAT THIS DOES
  Maps all 35 workouts in kWorkouts (lib/data/models/models.dart) to a
  specific brothers and/or sisters illustration by hand -- not every
  workout has a confident match in both packs (the brothers pack is
  walk/strength only, no breathing or stretch content; a handful of ids
  are left unmapped on purpose rather than showing a mismatched-gender
  or unrelated picture). Unmapped ids simply keep the emoji -- same
  fallback pattern used everywhere else in this codebase.

  fitness_screen.dart's workout-grid icon (currently
  Text(w.emoji, style: TextStyle(fontSize: 32))) is patched to prefer
  the mapped illustration for the current gender, falling back to the
  emoji automatically via errorBuilder.

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


_WORKOUT_ICON_SNIPPET = """
// ═══════════════════════════════════════════════════════════
// WORKOUT ILLUSTRATIONS — PATCH_V15_FITNESS_ICONS
// Hand-mapped from kWorkouts (lib/data/models/models.dart) to the
// gender-matched illustration packs. Ids not listed here have no
// confident match in that pack and keep their emoji -- see
// fitness_screen.dart's use site for the fallback.
// ═══════════════════════════════════════════════════════════
const Map<String, String> kWorkoutIconBrothers = {
  'w1': 'assets/icons/workouts_brothers/evening_walk.png',
  'w6': 'assets/icons/workouts_brothers/brisk_walk_timer.png',
  'w10': 'assets/icons/workouts_brothers/park_walk_family.png',
  'w2': 'assets/icons/workouts_brothers/beginner_squats.png',
  'w8': 'assets/icons/workouts_brothers/advanced_back_shirtless.png',
  'w11': 'assets/icons/workouts_brothers/explosive_pushup.png',
  'w4': 'assets/icons/workouts_brothers/mosque_walk.png',
  'w14': 'assets/icons/workouts_brothers/mosque_walk.png',
  'w15': 'assets/icons/workouts_brothers/mosque_walk.png',
  'w21': 'assets/icons/workouts_brothers/mosque_walk.png',
  'w17': 'assets/icons/workouts_brothers/no_equipment_run.png',
  'w18': 'assets/icons/workouts_brothers/heavy_lifts_bench.png',
  'w28': 'assets/icons/workouts_brothers/heavy_lifts_bench.png',
  'w12': 'assets/icons/workouts_brothers/stair_walk.png',
  'w23': 'assets/icons/workouts_brothers/no_equipment_run.png',
  'w35': 'assets/icons/workouts_brothers/no_equipment_run.png',
  'w24': 'assets/icons/workouts_brothers/explosive_pushup.png',
  'w26': 'assets/icons/workouts_brothers/walk_with_friend.png',
  'w32': 'assets/icons/workouts_brothers/home_weights_press.png',
  'w34': 'assets/icons/workouts_brothers/power_circle.png',
  'w20': 'assets/icons/workouts_brothers/park_walk_family.png',
  'w30': 'assets/icons/workouts_brothers/walk_with_friend2.png',
};

const Map<String, String> kWorkoutIconSisters = {
  'w3': 'assets/icons/workouts_sisters_hijab/beginner_yoga.png',
  'w5': 'assets/icons/workouts_sisters_hijab/postnatal_recovery.png',
  'w9': 'assets/icons/workouts_sisters_hijab/long_sit_stretch.png',
  'w4': 'assets/icons/workouts_sisters_hijab/ramadan_family.png',
  'w14': 'assets/icons/workouts_sisters_hijab/taraweeh_walk.png',
  'w15': 'assets/icons/workouts_sisters_hijab/fajr_meditation.png',
  'w21': 'assets/icons/workouts_sisters_hijab/fajr_meditation.png',
  'w7': 'assets/icons/workouts_sisters_hijab/breathing_478.png',
  'w31': 'assets/icons/workouts_sisters_hijab/breathing_478.png',
  'w22': 'assets/icons/workouts_sisters_hijab/sleep_stretch.png',
  'w27': 'assets/icons/workouts_sisters_hijab/pre_sleep_stretch.png',
  'w16': 'assets/icons/workouts_sisters_hijab/mindful_session.png',
  'w20': 'assets/icons/workouts_sisters_hijab/kids_balance.png',
  'w17': 'assets/icons/workouts_sisters_hijab/cardio_circle_20.png',
  'w35': 'assets/icons/workouts_sisters_hijab/cardio_circle_20.png',
  'w25': 'assets/icons/workouts_sisters_hijab/cardio_circle_20.png',
  'w19': 'assets/icons/workouts_sisters_hijab/functional_strength.png',
  'w13': 'assets/icons/workouts_sisters_hijab/functional_strength.png',
  'w12': 'assets/icons/workouts_sisters_hijab/lower_body_strength.png',
  'w23': 'assets/icons/workouts_sisters_hijab/home_dance_cardio.png',
  'w26': 'assets/icons/workouts_sisters_hijab/light_jog.png',
  'w28': 'assets/icons/workouts_sisters_hijab/kettlebell_circle.png',
  'w32': 'assets/icons/workouts_sisters_hijab/kettlebell_circle.png',
  'w29': 'assets/icons/workouts_sisters_hijab/lotus_yoga.png',
  'w33': 'assets/icons/workouts_sisters_hijab/lotus_yoga2.png',
  'w34': 'assets/icons/workouts_sisters_hijab/morning_fitness.png',
  'w6': 'assets/icons/workouts_sisters_hijab/morning_stretch.png',
  'w1': 'assets/icons/workouts_sisters_hijab/family_evening_walk.png',
  'w10': 'assets/icons/workouts_sisters_hijab/family_evening_walk.png',
  'w30': 'assets/icons/workouts_sisters_hijab/family_race.png',
};

/// Gender-matched workout icon, or null to keep the emoji. Deliberately
/// returns null rather than cross-gender art when a workout's `gender`
/// is 'brothers'/'sisters' and the requesting screen's mode doesn't
/// match -- the caller is expected to pass the right `isSis` for the
/// current mode, not per-workout gender.
String? workoutIconAsset(String workoutId, bool isSis) =>
    (isSis ? kWorkoutIconSisters : kWorkoutIconBrothers)[workoutId];
"""


def add_workout_icon_map():
    old = (
        "String workoutBrotherAsset(String name) => "
        "'$_kIcons/workouts_brothers/$name.png';\n"
        "String workoutSisterAsset(String name) => "
        "'$_kIcons/workouts_sisters_hijab/$name.png';"
    )
    new = old + "\n" + _WORKOUT_ICON_SNIPPET
    apply_one(
        "lib/data/icon_assets.dart", old, new,
        "add kWorkoutIconBrothers/Sisters + workoutIconAsset()",
    )


def patch_fitness_screen():
    old = """                              Text(w.emoji, style: const TextStyle(fontSize: 32)),"""
    new = """                              workoutIconAsset(w.id, isSis) != null
                                ? Image.asset(workoutIconAsset(w.id, isSis)!,
                                    width: 44, height: 44, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        Text(w.emoji, style: const TextStyle(fontSize: 32)))
                                : Text(w.emoji, style: const TextStyle(fontSize: 32)),"""
    apply_one(
        "lib/features/fitness/fitness_screen.dart", old, new,
        "workout grid icon: emoji -> gender-matched illustration",
    )
    apply_one(
        "lib/features/fitness/fitness_screen.dart",
        "import 'lift_screen.dart'; import'../../data/models/models.dart'; import '../../data/muscle_assets.dart';",
        "import 'lift_screen.dart'; import'../../data/models/models.dart'; import '../../data/muscle_assets.dart'; import '../../data/icon_assets.dart';",
        "add icon_assets.dart import",
    )


def main():
    print("=" * 70)
    print("Fitness screen: real workout icons")
    print("=" * 70)
    add_workout_icon_map()
    patch_fitness_screen()

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


if __name__ == "__main__":
    main()
