import 'dart:math';
// ============================================================
//  user_profile.dart — HalalCalorie v1.0
//  Complete user profile with body metrics engine
//  All calculations: BMR, TDEE, BMI, body fat %, macros
// ============================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ── Activity Level Enum ────────────────────────────────────
enum ActivityLevel {
  sedentary,      // desk job, little exercise
  lightlyActive,  // 1-3 days/week
  moderatelyActive, // 3-5 days/week
  veryActive,     // 6-7 days/week
  extraActive,    // athlete / physical job
}

extension ActivityLevelExt on ActivityLevel {
  /// Mifflin-St Jeor multiplier
  double get multiplier {
    switch (this) {
      case ActivityLevel.sedentary:       return 1.2;
      case ActivityLevel.lightlyActive:   return 1.375;
      case ActivityLevel.moderatelyActive: return 1.55;
      case ActivityLevel.veryActive:      return 1.725;
      case ActivityLevel.extraActive:     return 1.9;
    }
  }

  String nameAr() {
    switch (this) {
      case ActivityLevel.sedentary:       return 'خامل (مكتبي)';
      case ActivityLevel.lightlyActive:   return 'خفيف (1-3 أيام/أسبوع)';
      case ActivityLevel.moderatelyActive: return 'متوسط (3-5 أيام/أسبوع)';
      case ActivityLevel.veryActive:      return 'نشيط (6-7 أيام/أسبوع)';
      case ActivityLevel.extraActive:     return 'رياضي (تمارين شاقة)';
    }
  }

  String nameEn() {
    switch (this) {
      case ActivityLevel.sedentary:       return 'Sedentary (desk job)';
      case ActivityLevel.lightlyActive:   return 'Lightly Active (1-3 days/wk)';
      case ActivityLevel.moderatelyActive: return 'Moderately Active (3-5 days/wk)';
      case ActivityLevel.veryActive:      return 'Very Active (6-7 days/wk)';
      case ActivityLevel.extraActive:     return 'Athlete (intense exercise)';
    }
  }

  String emoji() {
    switch (this) {
      case ActivityLevel.sedentary:       return '🪑';
      case ActivityLevel.lightlyActive:   return '🚶';
      case ActivityLevel.moderatelyActive: return '🏃';
      case ActivityLevel.veryActive:      return '💪';
      case ActivityLevel.extraActive:     return '🏋️';
    }
  }
}

// ── Primary Goal Enum ──────────────────────────────────────
enum FitnessGoal {
  loseWeight,
  gainMuscle,
  maintain,
  improveHealth,
  ramadanPrep,
}

extension FitnessGoalExt on FitnessGoal {
  String nameAr() {
    switch (this) {
      case FitnessGoal.loseWeight:    return 'خسارة الوزن';
      case FitnessGoal.gainMuscle:    return 'بناء العضلات';
      case FitnessGoal.maintain:      return 'الحفاظ على الوزن';
      case FitnessGoal.improveHealth: return 'تحسين الصحة العامة';
      case FitnessGoal.ramadanPrep:   return 'الاستعداد لرمضان';
    }
  }

  String nameEn() {
    switch (this) {
      case FitnessGoal.loseWeight:    return 'Lose Weight';
      case FitnessGoal.gainMuscle:    return 'Build Muscle';
      case FitnessGoal.maintain:      return 'Maintain Weight';
      case FitnessGoal.improveHealth: return 'Improve Health';
      case FitnessGoal.ramadanPrep:   return 'Ramadan Preparation';
    }
  }

  String emoji() {
    switch (this) {
      case FitnessGoal.loseWeight:    return '⬇️';
      case FitnessGoal.gainMuscle:    return '💪';
      case FitnessGoal.maintain:      return '⚖️';
      case FitnessGoal.improveHealth: return '❤️';
      case FitnessGoal.ramadanPrep:   return '🌙';
    }
  }

  /// Calorie adjustment from TDEE
  int get calorieAdjustment {
    switch (this) {
      case FitnessGoal.loseWeight:    return -500;  // -500 kcal deficit
      case FitnessGoal.gainMuscle:    return 300;   // +300 kcal surplus
      case FitnessGoal.maintain:      return 0;
      case FitnessGoal.improveHealth: return 0;
      case FitnessGoal.ramadanPrep:   return -200;  // slight deficit
    }
  }
}

// ── Diet Preference Enum ───────────────────────────────────
enum DietPreference {
  halalOnly,
  vegetarianHalal,
  wholeFoods,
  lowCarb,
}

extension DietPrefExt on DietPreference {
  String nameAr() {
    switch (this) {
      case DietPreference.halalOnly:        return 'حلال فقط (افتراضي)';
      case DietPreference.vegetarianHalal:  return 'نباتي + حلال';
      case DietPreference.wholeFoods:       return 'أطعمة كاملة';
      case DietPreference.lowCarb:          return 'قليل الكربوهيدرات';
    }
  }

  String nameEn() {
    switch (this) {
      case DietPreference.halalOnly:        return 'Halal Only (default)';
      case DietPreference.vegetarianHalal:  return 'Vegetarian + Halal';
      case DietPreference.wholeFoods:       return 'Whole Foods';
      case DietPreference.lowCarb:          return 'Low Carb';
    }
  }
}

// ── Body Frame Enum ────────────────────────────────────────
enum BodyFrame { small, medium, large }

extension BodyFrameExt on BodyFrame {
  String nameAr() {
    switch (this) {
      case BodyFrame.small:  return 'صغير (< 15 سم)';
      case BodyFrame.medium: return 'متوسط (15-17 سم)';
      case BodyFrame.large:  return 'كبير (> 17 سم)';
    }
  }

  String nameEn() {
    switch (this) {
      case BodyFrame.small:  return 'Small (< 15 cm)';
      case BodyFrame.medium: return 'Medium (15-17 cm)';
      case BodyFrame.large:  return 'Large (> 17 cm)';
    }
  }
}

// ── Health Condition ───────────────────────────────────────
enum HealthCondition {
  none, diabetes, hypertension, heartDisease, thyroid, other
}

extension HealthCondExt on HealthCondition {
  String nameAr() {
    switch (this) {
      case HealthCondition.none:         return 'لا يوجد';
      case HealthCondition.diabetes:     return 'السكري';
      case HealthCondition.hypertension: return 'ضغط الدم';
      case HealthCondition.heartDisease: return 'أمراض القلب';
      case HealthCondition.thyroid:      return 'الغدة الدرقية';
      case HealthCondition.other:        return 'أخرى';
    }
  }

  String nameEn() {
    switch (this) {
      case HealthCondition.none:         return 'None';
      case HealthCondition.diabetes:     return 'Diabetes';
      case HealthCondition.hypertension: return 'Hypertension';
      case HealthCondition.heartDisease: return 'Heart Disease';
      case HealthCondition.thyroid:      return 'Thyroid';
      case HealthCondition.other:        return 'Other';
    }
  }
}

// ── Core User Profile Model ─────────────────────────────── v2
class UserProfile {
  final String id;
  final String gender;          // 'brothers' | 'sisters'
  final int age;                // years
  final double heightCm;        // cm
  final double weightKg;        // kg
  final double? waistCm;        // optional, for body fat Navy method
  final ActivityLevel activityLevel;
  final FitnessGoal primaryGoal;
  final DietPreference dietPreference;
  final List<HealthCondition> healthConditions;
  final int mealsPerDay;        // 2-6
  final double sleepHours;      // hours
  final BodyFrame bodyFrame;
  final double? targetWeightKg; // optional goal weight
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.waistCm,
    required this.activityLevel,
    required this.primaryGoal,
    required this.dietPreference,
    required this.healthConditions,
    required this.mealsPerDay,
    required this.sleepHours,
    required this.bodyFrame,
    this.targetWeightKg,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isMale => gender == 'brothers';

  // ── BMI ──────────────────────────────────────────────────
  double get bmi {
    final hM = heightCm / 100.0;
    return weightKg / (hM * hM);
  }

  String get bmiCategory {
    if (bmi < 18.5) return isMale ? 'نقص وزن / Underweight' : 'نقص وزن / Underweight';
    if (bmi < 25.0) return 'وزن مثالي ✓ / Normal ✓';
    if (bmi < 30.0) return 'زيادة وزن / Overweight';
    return 'سمنة / Obese';
  }

  String get bmiCategoryAr {
    if (bmi < 18.5) return 'نقص وزن';
    if (bmi < 25.0) return 'وزن مثالي ✓';
    if (bmi < 30.0) return 'زيادة وزن';
    return 'سمنة';
  }

  String get bmiCategoryEn {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal ✓';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  // ── Body Fat % — Deurenberg Formula ──────────────────────
  // Men:   BF% = 1.20 × BMI + 0.23 × age − 16.2
  // Women: BF% = 1.20 × BMI + 0.23 × age − 5.4
  double get bodyFatPercent {
    if (isMale) {
      return (1.20 * bmi) + (0.23 * age) - 16.2;
    } else {
      return (1.20 * bmi) + (0.23 * age) - 5.4;
    }
  }

  // Body Fat via Navy Method (more accurate if waist known)
  double? get bodyFatPercentNavy {
    if (waistCm == null) return null;
    if (isMale) {
      // Men: 495 / (1.0324 – 0.19077 × log10(waist – neck) + 0.15456 × log10(height)) – 450
      // Simplified without neck measurement:
      final w = waistCm!;
      final h = heightCm;
      final val = 495.0 / (1.0324 - 0.19077 * _log10(w - 0) + 0.15456 * _log10(h)) - 450;
      return val.clamp(3.0, 50.0);
    } else {
      final w = waistCm!;
      final h = heightCm;
      final val = 495.0 / (1.29579 - 0.35004 * _log10(w) + 0.22100 * _log10(h)) - 450;
      return val.clamp(10.0, 60.0);
    }
  }

  static double _log10(double x) => x > 0 ? log(x) / ln10 : 0;

  String get bodyFatCategory {
    final bf = bodyFatPercent;
    if (isMale) {
      if (bf < 6)  return 'أساسي / Essential';
      if (bf < 14) return 'رياضي / Athletic';
      if (bf < 18) return 'لياقة جيدة / Fitness';
      if (bf < 25) return 'متوسط / Average';
      return 'زيادة دهون / High';
    } else {
      if (bf < 14) return 'أساسي / Essential';
      if (bf < 21) return 'رياضية / Athletic';
      if (bf < 25) return 'لياقة جيدة / Fitness';
      if (bf < 32) return 'متوسط / Average';
      return 'زيادة دهون / High';
    }
  }

  // ── Lean Body Mass ────────────────────────────────────────
  double get leanBodyMassKg {
    return weightKg * (1.0 - (bodyFatPercent / 100.0));
  }

  // ── Muscle Mass (estimate) ────────────────────────────────
  // Muscle is approximately 85% of lean body mass (rough estimate)
  double get muscleMassKg {
    return leanBodyMassKg * 0.85;
  }

  // ── Bone Mass Estimate ────────────────────────────────────
  double get boneMassKg {
    // Rough: 3.3% of body weight for men, 3% for women
    return weightKg * (isMale ? 0.033 : 0.030);
  }

  // ── BMR — Mifflin-St Jeor Equation ───────────────────────
  // Men:   BMR = 10×W + 6.25×H − 5×A + 5
  // Women: BMR = 10×W + 6.25×H − 5×A − 161
  double get bmrKcal {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return isMale ? base + 5 : base - 161;
  }

  // ── TDEE (Total Daily Energy Expenditure) ─────────────────
  double get tdeeKcal {
    return bmrKcal * activityLevel.multiplier;
  }

  // ── Calorie Goal (adjusted for goal) ─────────────────────
  double get calorieGoalKcal {
    return (tdeeKcal + primaryGoal.calorieAdjustment).clamp(1200, 4000);
  }

  // ── Macro Targets ─────────────────────────────────────────
  // Protein: 1.6-2.2 g/kg lean mass for muscle building; 1.2 g/kg for others
  double get proteinGrams {
    switch (primaryGoal) {
      case FitnessGoal.gainMuscle:
        return (leanBodyMassKg * 2.0).roundToDouble();
      case FitnessGoal.loseWeight:
        return (leanBodyMassKg * 1.8).roundToDouble();
      default:
        return (leanBodyMassKg * 1.5).roundToDouble();
    }
  }

  // Fat: 25-30% of total calories
  double get fatGrams {
    return ((calorieGoalKcal * 0.28) / 9.0).roundToDouble();
  }

  // Carbs: remaining calories
  double get carbsGrams {
    final proteinCal = proteinGrams * 4;
    final fatCal = fatGrams * 9;
    return (((calorieGoalKcal - proteinCal - fatCal) / 4.0)).clamp(50, 500).roundToDouble();
  }

  // ── Daily Water Need ──────────────────────────────────────
  // 33ml per kg + exercise
  double get waterLiters {
    double base = weightKg * 0.033;
    if (activityLevel == ActivityLevel.veryActive ||
        activityLevel == ActivityLevel.extraActive) {
      base += 0.5;
    }
    return (base * 10).round() / 10.0;
  }

  int get waterCupsGoal => (waterLiters / 0.25).ceil().clamp(6, 16);

  // ── Ideal Weight — Devine Formula ────────────────────────
  double get idealWeightKg {
    final heightInches = heightCm / 2.54;
    if (isMale) {
      return 50.0 + 2.3 * (heightInches - 60);
    } else {
      return 45.5 + 2.3 * (heightInches - 60);
    }
  }

  double get weightDifferenceKg => targetWeightKg != null
      ? (targetWeightKg! - weightKg)
      : (idealWeightKg - weightKg);

  // ── Personalized Greeting ─────────────────────────────────
  String greetingAr() {
    if (primaryGoal == FitnessGoal.ramadanPrep) {
      return 'رمضان كريم! جاهز للبركة؟ 🌙';
    }
    if (primaryGoal == FitnessGoal.loseWeight) {
      final remaining = (weightKg - idealWeightKg).abs();
      return 'هدفك: ${remaining.toStringAsFixed(1)} كجم للوصول للمثالي 💪';
    }
    return 'السلام عليكم! كل يوم أفضل 🌿';
  }

  String greetingEn() {
    if (primaryGoal == FitnessGoal.ramadanPrep) {
      return 'Ramadan Mubarak! Ready for a strong month? 🌙';
    }
    if (primaryGoal == FitnessGoal.loseWeight) {
      final remaining = (weightKg - idealWeightKg).abs();
      return 'Goal: ${remaining.toStringAsFixed(1)} kg to ideal weight 💪';
    }
    return 'Peace be upon you! Every day better 🌿';
  }

  // ── Serialization ─────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'gender': gender,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'waistCm': waistCm,
    'activityLevel': activityLevel.index,
    'primaryGoal': primaryGoal.index,
    'dietPreference': dietPreference.index,
    'healthConditions': healthConditions.map((e) => e.index).toList(),
    'mealsPerDay': mealsPerDay,
    'sleepHours': sleepHours,
    'bodyFrame': bodyFrame.index,
    'targetWeightKg': targetWeightKg,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static UserProfile fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] ?? 'user_1',
    gender: j['gender'] ?? 'brothers',
    age: j['age'] ?? 25,
    heightCm: (j['heightCm'] ?? 170).toDouble(),
    weightKg: (j['weightKg'] ?? 70).toDouble(),
    waistCm: j['waistCm']?.toDouble(),
    activityLevel: ActivityLevel.values[j['activityLevel'] ?? 0],
    primaryGoal: FitnessGoal.values[j['primaryGoal'] ?? 0],
    dietPreference: DietPreference.values[j['dietPreference'] ?? 0],
    healthConditions: (j['healthConditions'] as List?)
        ?.map((i) => HealthCondition.values[(i as num?)?.toInt() ?? 0])
        .toList() ?? [HealthCondition.none],
    mealsPerDay: j['mealsPerDay'] ?? 3,
    sleepHours: (j['sleepHours'] ?? 7).toDouble(),
    bodyFrame: BodyFrame.values[j['bodyFrame'] ?? 1],
    targetWeightKg: j['targetWeightKg']?.toDouble(),
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
    updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
  );

  UserProfile copyWith({
    int? age,
    double? heightCm,
    double? weightKg,
    double? waistCm,
    ActivityLevel? activityLevel,
    FitnessGoal? primaryGoal,
    DietPreference? dietPreference,
    List<HealthCondition>? healthConditions,
    int? mealsPerDay,
    double? sleepHours,
    BodyFrame? bodyFrame,
    double? targetWeightKg,
  }) => UserProfile(
    id: id,
    gender: gender,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    waistCm: waistCm ?? this.waistCm,
    activityLevel: activityLevel ?? this.activityLevel,
    primaryGoal: primaryGoal ?? this.primaryGoal,
    dietPreference: dietPreference ?? this.dietPreference,
    healthConditions: healthConditions ?? this.healthConditions,
    mealsPerDay: mealsPerDay ?? this.mealsPerDay,
    sleepHours: sleepHours ?? this.sleepHours,
    bodyFrame: bodyFrame ?? this.bodyFrame,
    targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}

// ── User Profile Repository ────────────────────────────────
class UserProfileRepository {
  static const _key = 'user_profile_v2';

  static Future<UserProfile?> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(UserProfile profile) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(profile.toJson()));
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
  }
}
