// muscle_assets.dart
// PATCH_LEAF_RING_AND_WORKOUT_ASSETS
//
// Maps a workout's `category` (see kWorkouts / Workout.category in
// models.dart) to one of the muscle-illustration PNGs under
// assets/muscles/. These came from user-supplied reference sheets that
// were auto-cropped into individual transparent-background pieces —
// see the patch script header for the source-licensing note before
// shipping them in a store build.
//
// Deliberately keyed by category, not by individual workout id: with
// 23 workouts and 7 categories, per-category is enough to give the
// player screen a relevant illustration without hand-tagging every
// workout. Swap to a per-workout `targetMuscle` field on Workout later
// if finer targeting is worth the data-entry cost.

const Map<String, String> kMuscleAssetByCategory = {
  'strength': 'assets/muscles/bicep_flex_hero.png',
  'walking': 'assets/muscles/calf_front.png',
  'gentle': 'assets/muscles/abs_sixpack.png',
  'ramadan': 'assets/muscles/torso_chest_abs.png',
  'breathing': 'assets/muscles/abs_sixpack.png',
  'family': 'assets/muscles/back_lats_v1.png',
};

const String kMuscleAssetDefault = 'assets/muscles/bicep_flex_hero.png';

String muscleAssetForCategory(String category) =>
    kMuscleAssetByCategory[category] ?? kMuscleAssetDefault;


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
