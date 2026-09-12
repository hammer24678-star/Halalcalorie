import 'package:flutter/material.dart';

// icon_assets.dart
// PATCH_V10_REDESIGN
//
// Maps the new hand-picked icon pack (assets/icons/**) to the app's
// features. Mirrors the fallback-safe pattern established in
// muscle_assets.dart / lift_screen.dart: every lookup here returns a
// plain String (or null), the caller decides how to render it, and
// every call site that uses one of these paths must keep an
// errorBuilder fallback to the original emoji so a missing asset can
// never crash a row.
//
// Categories not yet wired into a specific screen (fruits, vegetables,
// proteins, pantry_and_dishes, workouts_brothers, workouts_sisters_hijab)
// are still exposed here in full so they're one line away from use —
// see the bottom of this file.

import 'muscle_assets.dart';

const String _kIcons = 'assets/icons';

// ─────────────────────────────────────────────────────────────────
// Mood picker (health_screen.dart _moodCard) — replaces the old
// mismatched assets/emoji/face_emojis/* placeholders (kirakira, uwu,
// wat, yawn, nervous) with 8 purpose-drawn mood faces.
// ─────────────────────────────────────────────────────────────────
const List<Map<String, String>> kMoodFacesAr = [
  {'asset': '$_kIcons/mood_faces/mumtaz.png', 'label': 'ممتاز'},
  {'asset': '$_kIcons/mood_faces/jayed.png', 'label': 'جيد'},
  {'asset': '$_kIcons/mood_faces/mutahammis.png', 'label': 'متحمس'},
  {'asset': '$_kIcons/mood_faces/aadi.png', 'label': 'عادي'},
  {'asset': '$_kIcons/mood_faces/raadi.png', 'label': 'راضي'},
  {'asset': '$_kIcons/mood_faces/jaee.png', 'label': 'جائع'},
  {'asset': '$_kIcons/mood_faces/taaban.png', 'label': 'تعبان'},
  {'asset': '$_kIcons/mood_faces/mutawattir.png', 'label': 'متوتر'},
];
const List<Map<String, String>> kMoodFacesEn = [
  {'asset': '$_kIcons/mood_faces/mumtaz.png', 'label': 'Excellent'},
  {'asset': '$_kIcons/mood_faces/jayed.png', 'label': 'Good'},
  {'asset': '$_kIcons/mood_faces/mutahammis.png', 'label': 'Motivated'},
  {'asset': '$_kIcons/mood_faces/aadi.png', 'label': 'Okay'},
  {'asset': '$_kIcons/mood_faces/raadi.png', 'label': 'Satisfied'},
  {'asset': '$_kIcons/mood_faces/jaee.png', 'label': 'Hungry'},
  {'asset': '$_kIcons/mood_faces/taaban.png', 'label': 'Tired'},
  {'asset': '$_kIcons/mood_faces/mutawattir.png', 'label': 'Stressed'},
];

// ─────────────────────────────────────────────────────────────────
// Status glyphs — 1:1 replacements for emoji already used on the
// home screen's 4-stat row (_Stat) and quick-actions grid (_QTile),
// and reused for health_screen's _stepStat row. Not every emoji in
// the app has a matching glyph; unmapped ones fall through to null
// and the caller keeps using the emoji.
// ─────────────────────────────────────────────────────────────────
const Map<String, String> kStatusGlyphByEmoji = {
  '📸': '$_kIcons/status_glyphs/glyph_camera.png',
  '📷': '$_kIcons/status_glyphs/glyph_camera_flash.png',
  '💧': '$_kIcons/status_glyphs/glyph_water_drop.png',
  '😴': '$_kIcons/status_glyphs/glyph_sleepy_moon.png',
  '🔥': '$_kIcons/status_glyphs/glyph_fire.png',
  '🏃': '$_kIcons/status_glyphs/glyph_running_person.png',
};

String? statusGlyphForEmoji(String emoji) => kStatusGlyphByEmoji[emoji];

// ─────────────────────────────────────────────────────────────────
// Mosque mark — the app's own mark, replacing the generic 🕌 emoji
// (prayer_card.dart badge) and assets/logo.png (splash_screen.dart).
// ─────────────────────────────────────────────────────────────────
const String kMosqueMarkSmall = '$_kIcons/mosque_mark/mosque_small.png';
const String kMosqueMarkMedium = '$_kIcons/mosque_mark/mosque_medium.png';

// ─────────────────────────────────────────────────────────────────
// Wholesome-food snackbar (nutrition_screen.dart _checkWholesomeFood)
// — keyed by the same Arabic/English keys already used in
// _kWholesomeFoods, covering the 10 foods this pack has art for.
// Foods outside this list (barley, pomegranate, oat) keep their emoji.
// ─────────────────────────────────────────────────────────────────
const Map<String, String> kWholesomeFoodAssetByKey = {
  'تمر': '$_kIcons/wholesome_foods_10/tamr.png',
  'date': '$_kIcons/wholesome_foods_10/tamr.png',
  'عسل': '$_kIcons/wholesome_foods_10/asal.png',
  'honey': '$_kIcons/wholesome_foods_10/asal.png',
  'زيتون': '$_kIcons/wholesome_foods_10/zaytoon.png',
  'olive': '$_kIcons/wholesome_foods_10/zaytoon.png',
  'حليب': '$_kIcons/wholesome_foods_10/haleeb.png',
  'milk': '$_kIcons/wholesome_foods_10/haleeb.png',
  'زبادي': '$_kIcons/wholesome_foods_10/zabadi.png',
  'yogurt': '$_kIcons/wholesome_foods_10/zabadi.png',
  'تين': '$_kIcons/wholesome_foods_10/teen.png',
  'fig': '$_kIcons/wholesome_foods_10/teen.png',
  'عدس': '$_kIcons/wholesome_foods_10/ads.png',
  'lentil': '$_kIcons/wholesome_foods_10/ads.png',
  'سمك': '$_kIcons/wholesome_foods_10/samak.png',
  'fish': '$_kIcons/wholesome_foods_10/samak.png',
  'مكسرات': '$_kIcons/wholesome_foods_10/mukassarat.png',
  'nut': '$_kIcons/wholesome_foods_10/mukassarat.png',
  'بيض': '$_kIcons/wholesome_foods_10/bayd.png',
  'egg': '$_kIcons/wholesome_foods_10/bayd.png',
};

String? wholesomeFoodAsset(String key) => kWholesomeFoodAssetByKey[key];

// ─────────────────────────────────────────────────────────────────
// Profile avatar — replaces the 🧕 / 🧔 emoji in profile_screen.dart
// with full-body brothers/sisters illustrations (portrait crop,
// use BoxFit.cover in a ClipOval).
// ─────────────────────────────────────────────────────────────────
const String kAvatarBrothers = '$_kIcons/avatars/avatar_brothers_1.png';
const String kAvatarSisters = '$_kIcons/avatars/avatar_sisters_1.png';

// ─────────────────────────────────────────────────────────────────
// Ranked Strength exercise photos (fitness/lift_screen.dart) — a
// photographic upgrade over the muscle-illustration set in
// muscle_assets.dart. exerciseIconAsset() prefers the photo and
// falls back to the existing muscle art, so nothing regresses if a
// mapping below is ever wrong or an id is added that isn't listed.
// ─────────────────────────────────────────────────────────────────
const Map<String, String> kGymPhotoAssetByExerciseId = {
  'squat': '$_kIcons/gym_strength/gymB_back_squat.png',
  'deadlift': '$_kIcons/gym_strength/gymA_deadlift.png',
  'bench': '$_kIcons/gym_strength/gymB_flat_bench_press.png',
  'ohp': '$_kIcons/gym_strength/gymC_overhead_press.png',
  'row': '$_kIcons/gym_strength/gymC_bent_over_row.png',
  'hipthrust': '$_kIcons/gym_strength/gymB_glute_bridge.png', // closest match — no dedicated hip-thrust photo in this pack
  'legpress': '$_kIcons/gym_strength/gymA_leg_press.png',
  'latpulldown': '$_kIcons/gym_strength/gymA_lat_pulldown.png',
  'curl': '$_kIcons/gym_strength/gymB_standing_db_curl.png',
  'pullup': '$_kIcons/gym_strength/gymA_pullup.png',
  'dip': '$_kIcons/gym_strength/gymC_tricep_dip.png',
  'pushup': '$_kIcons/gym_strength/gymC_pushup.png',
  'plank': '$_kIcons/gym_strength/gymC_plank.png',
  // PATCH_V34_15_NEW_LIFTS: icons for the 15 new lifts above.
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
};

/// Drop-in replacement for muscleAssetForExercise(): tries the new
/// photo set first, falls back to the original muscle-illustration
/// mapping so lift_screen.dart's existing errorBuilder is the only
/// safety net that's ever needed.
String? exerciseIconAsset(String exerciseId) =>
    kGymPhotoAssetByExerciseId[exerciseId] ?? muscleAssetForExercise(exerciseId);

// ─────────────────────────────────────────────────────────────────
// Registered but not yet wired into a screen — full listing so
// these are one line away from use rather than needing another
// asset-pack extraction later.
// ─────────────────────────────────────────────────────────────────
const List<String> kFruitAssets = [
  'apple', 'avocado', 'banana', 'cherry', 'coconut', 'dates3', 'grapes',
  'guava', 'kiwi', 'lemon', 'mango', 'melon', 'orange', 'papaya', 'peach',
  'pear', 'pineapple', 'pomegranate', 'strawberry', 'watermelon',
];
const List<String> kVegetableAssets = [
  'beet', 'broccoli', 'carrot', 'cauliflower', 'chili', 'corn', 'cucumber',
  'eggplant', 'garlic', 'green_beans', 'green_pepper', 'lettuce', 'onion',
  'peas', 'potato', 'radish', 'spinach', 'sweet_potato', 'tomato', 'zucchini',
];
const List<String> kProteinAssets = [
  'beef', 'beef_cut', 'cheese1', 'cheese2', 'chicken', 'lamb', 'salmon',
  'shrimp', 'tuna',
];
const List<String> kPantryAndDishAssets = [
  'baba_ghanoush', 'baklava1', 'baklava2', 'basbousa', 'bread_loaf', 'butter',
  'cake', 'chocolate', 'cilantro', 'cinnamon', 'coffee', 'cookie', 'cookies2',
  'couscous', 'cream', 'cumin_spoon', 'dates2', 'edamame', 'falafel',
  'fattoush', 'flour_bag', 'flour_jar', 'ginger', 'grilled_fish', 'hummus',
  'icecream', 'jam', 'kebab', 'ketchup', 'kunafa', 'mahalabia', 'majboos',
  'mansaf', 'mayo', 'mint', 'mustard', 'noodles', 'olive_oil', 'om_ali',
  'parsley', 'peanuts', 'pepper_mill', 'pita', 'qamar_aldin', 'rice_bowl',
  'rice_milk', 'rice_raw', 'saffron', 'salt_bowl', 'salt_jar', 'sesame',
  'shawarma', 'softserve', 'soy_sauce', 'spice_bowl', 'spices', 'sugar_bowl',
  'tabbouleh', 'tamarind', 'tea', 'tofu', 'turmeric', 'vinegar', 'water_glass',
];
const List<String> kWorkoutBrothersAssets = [
  'active_shopping', 'advanced_back_shirtless', 'barefoot_grass',
  'beginner_squats', 'biceps_flex', 'brisk_walk_timer', 'evening_walk',
  'explosive_pushup', 'grip_strength', 'heavy_lifts_bench',
  'home_fitness_trophy', 'home_weights_press', 'iron_core_shield',
  'mosque_walk', 'night_walk', 'no_equipment_run', 'park_walk_family',
  'plank_shirtless', 'power_circle', 'power_circle2',
  'pushup_pullup_shirtless', 'rope_climb', 'stair_walk',
  'walk_with_friend', 'walk_with_friend2',
];
const List<String> kWorkoutSistersHijabAssets = [
  'balance_games', 'balance_stretch', 'ball_game', 'beginner_yoga',
  'breathing_478', 'cardio_circle_20', 'cat_cow', 'chest_breathing',
  'daily_routine', 'desk_break', 'eid_activity', 'eid_family_sport',
  'fajr_meditation', 'family_dance', 'family_evening_walk', 'family_icon',
  'family_race', 'functional_strength', 'general_icon', 'glute_bridge',
  'home_dance_cardio', 'hourglass_focus', 'joint_care', 'joint_mobility',
  'jump_variety', 'kettlebell_circle', 'kids_balance', 'light_dumbbell',
  'light_jog', 'long_sit_stretch', 'lotus_yoga', 'lotus_yoga2', 'lower_back',
  'lower_body_strength', 'mindful_session', 'morning_fitness',
  'morning_stretch', 'morning_stretch2', 'neck_shoulder', 'office_desk',
  'office_stretch', 'pelvic_floor', 'pillow_fight', 'plank_core',
  'post_exercise_stretch', 'postnatal_recovery', 'postnatal_stretch',
  'posture_fix', 'pre_sleep_stretch', 'progressive_relax', 'ramadan_family',
  'resistance_band', 'rope_jump', 'routine_cycle', 'senior_exercise',
  'shadow_boxing', 'side_stretch', 'sleep_stretch', 'stair_run',
  'stroller_walk', 'study_focus_breath', 'taraweeh_walk', 'time_management',
  'weekly_fitness_test',
];

String fruitAsset(String name) => '$_kIcons/fruits/$name.png';
String vegetableAsset(String name) => '$_kIcons/vegetables/$name.png';
String proteinAsset(String name) => '$_kIcons/proteins/$name.png';
String pantryAsset(String name) => '$_kIcons/pantry_and_dishes/$name.png';
String workoutBrotherAsset(String name) => '$_kIcons/workouts_brothers/$name.png';

// PATCH_V32_HEALTH_ARTICLE_ICONS
String healthArticleAsset(String name) => '$_kIcons/health/$name.png';
String workoutSisterAsset(String name) => '$_kIcons/workouts_sisters_hijab/$name.png';

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


// ─────────────────────────────────────────────────────────────────
// PATCH_V26_DARK_OUTLINE_AR_TITLES
// Transparent PNG packs leave a light fringe against forest-dark
// surfaces. darkSafeAsset composites them cleanly without tinting
// full-colour emoji art.
// ─────────────────────────────────────────────────────────────────
Widget darkSafeAsset(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  bool isDark = false,
  Widget? errorChild,
  BorderRadius? radius,
  Color? plateColor, // PATCH_V30_DARKSAFE_PLATE_COLOR
}) {
  final img = Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
    isAntiAlias: true,
    errorBuilder: errorChild == null
        ? null
        : (_, __, ___) => errorChild,
  );
  // PATCH_V30_DARKSAFE_PLATE_COLOR: clip now applies in both modes -- previously a light-mode
  // caller passing `radius` silently lost it.
  final clipped = radius != null
      ? ClipRRect(borderRadius: radius, child: img)
      : img;
  if (!isDark) return clipped;
  // Plate defaults to the old flat forest tone for existing callers that
  // don't pass one (mood faces, FoodThumb, status glyphs -- unchanged).
  // New callers should pass the *actual* local surface color (via
  // Color.alphaBlend for a tinted overlay) -- a mismatched flat plate is
  // exactly what drew a visible box instead of hiding the fringe.
  return ColoredBox(
    color: plateColor ?? const Color(0xFF0E1A14),
    child: clipped,
  );
}
