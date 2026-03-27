// models.dart — HalalCalorie v1.1
// Core data models + full content library

// ── Meal Entry ──────────────────────────────────
class MealEntry {
  final int     id;
  final String  name;
  final int     kcal;
  final DateTime time;
  final double  proteinG, carbsG, fatG;
  final String? photoPath;
  const MealEntry({
    required this.id, required this.name, required this.kcal,
    required this.time,
    this.proteinG = 0, this.carbsG = 0, this.fatG = 0,
    this.photoPath,
  });
}

// ── Scan Result ─────────────────────────────────
class ScanResult {
  final String barcode, name;
  final String? brand;
  final HalalStatus status;
  final List<String> certs;
  final String? notes;
  final DateTime scannedAt;
  ScanResult({
    required this.barcode, required this.name, this.brand,
    required this.status, this.certs = const [], this.notes, DateTime? scannedAt,
  }) : scannedAt = scannedAt ?? DateTime.now();
}

enum HalalStatus { halal, doubtful, haram, unknown }
extension HalalStatusExt on HalalStatus {
  String get label {
    switch (this) {
      case HalalStatus.halal:    return 'حلال ✓';
      case HalalStatus.doubtful: return 'مشبوه ⚠️';
      case HalalStatus.haram:    return 'حرام ✕';
      case HalalStatus.unknown:  return 'غير معروف ?';
    }
  }
  String get labelEn {
    switch (this) {
      case HalalStatus.halal:    return 'Halal ✓';
      case HalalStatus.doubtful: return 'Doubtful ⚠️';
      case HalalStatus.haram:    return 'Haram ✕';
      case HalalStatus.unknown:  return 'Unknown ?';
    }
  }
  String get emoji {
    switch (this) {
      case HalalStatus.halal:    return '✅';
      case HalalStatus.doubtful: return '⚠️';
      case HalalStatus.haram:    return '❌';
      case HalalStatus.unknown:  return '❓';
    }
  }
}

// ── AI Food Photo Result ─────────────────────────
class FoodPhotoResult {
  final String   foodName, foodNameEn;
  final int      kcal;
  final double   proteinG, carbsG, fatG;
  final HalalStatus halalStatus;
  final String   halalExplanation, halalExplanationEn;
  final String?  sunnahNote, sunnahNoteEn;
  final double   confidence;
  final String   portionSize;
  final List<String> ingredients;
  const FoodPhotoResult({
    required this.foodName, required this.foodNameEn,
    required this.kcal,
    required this.proteinG, required this.carbsG, required this.fatG,
    required this.halalStatus,
    required this.halalExplanation, required this.halalExplanationEn,
    this.sunnahNote, this.sunnahNoteEn,
    this.confidence = 0.0,
    this.portionSize = '',
    this.ingredients = const [],
  });
  // Compatibility getters
  String get halalNote => halalExplanation;
}

// ── AI Body Photo Result ─────────────────────────
class BodyPhotoResult {
  final double bodyFatPercent, muscleMassKg, leanBodyMassKg;
  final String bodyType, bodyTypeEn;
  final List<String> recommendationsAr, recommendationsEn;
  final String rawAnalysis;
  const BodyPhotoResult({
    required this.bodyFatPercent, required this.muscleMassKg, required this.leanBodyMassKg,
    required this.bodyType, required this.bodyTypeEn,
    required this.recommendationsAr, required this.recommendationsEn,
    required this.rawAnalysis,
  });
  // Compatibility getters
  List<String> get recommendations => recommendationsEn;
  String get rawAnalysisAr => rawAnalysis;
  factory BodyPhotoResult.fromJson(Map<String, dynamic> j, double weightKg) {
    final bf = (j['estimatedBodyFatPct'] as num?)?.toDouble() ?? 20.0;
    final muscle = (j['estimatedMuscleMassKg'] as num?)?.toDouble() ?? weightKg * 0.4;
    return BodyPhotoResult(
      bodyFatPercent: bf,
      muscleMassKg: muscle,
      leanBodyMassKg: weightKg * (1 - bf / 100),
      bodyType: j['bodyTypeAr'] as String? ?? 'متوازن',
      bodyTypeEn: j['bodyType'] as String? ?? 'mesomorph',
      recommendationsAr: List<String>.from(j['recommendationsAr'] ?? []),
      recommendationsEn: List<String>.from(j['recommendations'] ?? []),
      rawAnalysis: j.toString(),
    );
  }
}

// ── Workout Exercise Step ────────────────────────
class WorkoutStep {
  final String nameAr, nameEn;
  final int    durationSec;
  final int    reps;
  final String? instructionAr, instructionEn;
  const WorkoutStep({
    required this.nameAr, required this.nameEn,
    this.durationSec = 0, this.reps = 0,
    this.instructionAr, this.instructionEn,
  });
}

// ── Workout ─────────────────────────────────────
class Workout {
  final String id, emoji, titleAr, titleEn;
  final String descAr, descEn;
  final int    durationMin;
  final String level, levelEn, levelColor, gender, category;
  final String? hadith, hadithEn;
  final List<WorkoutStep> steps;
  final bool isPremium;
  const Workout({
    required this.id, required this.emoji,
    required this.titleAr, required this.titleEn,
    required this.descAr, required this.descEn,
    required this.durationMin,
    required this.level, required this.levelEn,
    this.levelColor = '#00A86B', this.gender = 'both',
    this.category = 'general',
    this.hadith, this.hadithEn,
    this.steps = const [],
    this.isPremium = false,
  });
}

// ── 24 Full Workouts ─────────────────────────────
const kWorkouts = [
  Workout(
    id: 'w1', emoji: '🚶', gender: 'both', category: 'walking', isPremium: false,
    titleAr: 'مشي الرسول ﷺ قبل المغرب', titleEn: 'Prophet\'s Evening Walk',
    descAr: 'تمرين خفيف مستوحى من هدي النبي ﷺ',
    descEn: 'Light walk inspired by the Prophet\'s ﷺ guidance',
    durationMin: 20, level: 'مبتدئ', levelEn: 'Beginner',
    hadith: 'كان النبي ﷺ يمشي بخطى متوسطة — البخاري',
    hadithEn: 'The Prophet ﷺ walked at a moderate pace — Al-Bukhari',
    steps: [
      WorkoutStep(nameAr: 'إحماء خفيف', nameEn: 'Warm-up', durationSec: 120, instructionAr: 'ابدأ بالمشي ببطء مع التنفس العميق', instructionEn: 'Start walking slowly with deep breathing'),
      WorkoutStep(nameAr: 'مشي معتدل', nameEn: 'Moderate walk', durationSec: 600, instructionAr: 'امش بخطى منتظمة متوسطة السرعة', instructionEn: 'Walk at a steady moderate pace'),
      WorkoutStep(nameAr: 'مشي سريع', nameEn: 'Brisk walk', durationSec: 300, instructionAr: 'زِد سرعتك قليلاً وتنفس بعمق', instructionEn: 'Increase your pace slightly'),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 180, instructionAr: 'عُد للمشي البطيء والتنفس العميق', instructionEn: 'Return to slow walking'),
    ],
  ),
  Workout(
    id: 'w6', emoji: '🌅', gender: 'both', category: 'walking', isPremium: false,
    titleAr: 'مشي الفجر السني', titleEn: 'Fajr Morning Walk',
    descAr: 'استقبل الصبح بخطوات مباركة',
    descEn: 'Start your blessed morning with movement',
    durationMin: 15, level: 'مبتدئ', levelEn: 'Beginner',
    hadith: 'بارك اللهم لأمتي في بكورها — الترمذي',
    hadithEn: 'O Allah bless my nation in its early mornings — Al-Tirmidhi',
    steps: [
      WorkoutStep(nameAr: 'إطالة خفيفة', nameEn: 'Light stretch', durationSec: 120, instructionAr: 'مُد ذراعيك للأمام والخلف', instructionEn: 'Stretch arms forward and back'),
      WorkoutStep(nameAr: 'مشي الفجر', nameEn: 'Fajr walk', durationSec: 600, instructionAr: 'امش في الهواء الطلق مع ذكر الله', instructionEn: 'Walk in fresh air while remembering Allah'),
      WorkoutStep(nameAr: 'تنفس عميق', nameEn: 'Deep breathing', durationSec: 180, instructionAr: 'شهيق ٤ ثواني، زفير ٤ ثواني — ٥ مرات', instructionEn: 'Inhale 4s, exhale 4s — repeat 5 times'),
    ],
  ),
  Workout(
    id: 'w10', emoji: '👨‍👩‍👧', gender: 'both', category: 'walking', isPremium: false,
    titleAr: 'مشي المساء مع العائلة', titleEn: 'Family Evening Walk',
    descAr: 'صِحة وصِلة رحم في خطوة واحدة',
    descEn: 'Health and family bonding in one step',
    durationMin: 25, level: 'مبتدئ', levelEn: 'Beginner',
    steps: [
      WorkoutStep(nameAr: 'انطلاق', nameEn: 'Start', durationSec: 300, instructionAr: 'ابدأ المشي مع عائلتك بخطى مريحة', instructionEn: 'Start walking with your family'),
      WorkoutStep(nameAr: 'منتصف الطريق', nameEn: 'Mid walk', durationSec: 900, instructionAr: 'حافظ على إيقاع منتظم', instructionEn: 'Maintain steady rhythm'),
      WorkoutStep(nameAr: 'عودة', nameEn: 'Return', durationSec: 300, instructionAr: 'أبطئ تدريجياً', instructionEn: 'Slow down gradually'),
    ],
  ),
  Workout(
    id: 'w2', emoji: '💪', gender: 'brothers', category: 'strength', isPremium: false,
    titleAr: 'تمارين قوة أساسية للإخوة', titleEn: 'Basic Strength — Brothers',
    descAr: 'بناء القوة الأساسية بلا أجهزة',
    descEn: 'Build core strength with no equipment',
    durationMin: 15, level: 'مبتدئ', levelEn: 'Beginner',
    hadith: 'المؤمن القوي خير وأحب إلى الله من المؤمن الضعيف — مسلم',
    hadithEn: 'The strong believer is more beloved to Allah — Muslim',
    steps: [
      WorkoutStep(nameAr: 'إحماء', nameEn: 'Warm-up', durationSec: 120),
      WorkoutStep(nameAr: 'ضغط', nameEn: 'Push-ups', reps: 10, instructionAr: 'ضغط كامل مع إبقاء الظهر مستقيماً', instructionEn: 'Full push-up with straight back'),
      WorkoutStep(nameAr: 'قرفصاء', nameEn: 'Squats', reps: 15, instructionAr: 'انزل حتى تصبح ركبتاك زاوية 90 درجة', instructionEn: 'Lower until knees reach 90 degrees'),
      WorkoutStep(nameAr: 'لوح', nameEn: 'Plank', durationSec: 30),
      WorkoutStep(nameAr: 'دفع للأعلى', nameEn: 'Tricep Dips', reps: 10, instructionAr: 'استخدم كرسياً', instructionEn: 'Use a chair'),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 120),
    ],
  ),
  Workout(
    id: 'w8', emoji: '🏋️', gender: 'brothers', category: 'strength', isPremium: false,
    titleAr: 'تقوية الظهر والبطن', titleEn: 'Back & Core Strength',
    descAr: 'يُصلح الوضعية ويُقوّي العمود الفقري',
    descEn: 'Fixes posture and strengthens spine',
    durationMin: 18, level: 'متوسط', levelEn: 'Intermediate', levelColor: '#0A6B4A',
    steps: [
      WorkoutStep(nameAr: 'دوران الورك', nameEn: 'Hip circles', durationSec: 60),
      WorkoutStep(nameAr: 'جسر الأرداف', nameEn: 'Glute bridge', reps: 15),
      WorkoutStep(nameAr: 'سباحة على الأرض', nameEn: 'Superman', reps: 12),
      WorkoutStep(nameAr: 'لوح جانبي', nameEn: 'Side plank', durationSec: 30, instructionAr: 'كل جانب', instructionEn: 'Each side'),
      WorkoutStep(nameAr: 'تمرين الطيار', nameEn: 'Bird dog', reps: 10),
      WorkoutStep(nameAr: 'إطالة الظهر', nameEn: 'Cat-cow stretch', durationSec: 60),
    ],
  ),
  Workout(
    id: 'w11', emoji: '🔥', gender: 'brothers', category: 'strength', isPremium: true,
    titleAr: 'تمرين HIIT الإسلامي', titleEn: 'Islamic HIIT',
    descAr: 'تدريب متقطع عالي الكثافة',
    descEn: 'High-intensity interval training',
    durationMin: 20, level: 'متقدم', levelEn: 'Advanced', levelColor: '#C62828',
    steps: [
      WorkoutStep(nameAr: 'إحماء', nameEn: 'Warm-up', durationSec: 120),
      WorkoutStep(nameAr: 'قفز القرفصاء', nameEn: 'Jump squats', durationSec: 40),
      WorkoutStep(nameAr: 'راحة', nameEn: 'Rest', durationSec: 20),
      WorkoutStep(nameAr: 'برباوي', nameEn: 'Burpees', durationSec: 40),
      WorkoutStep(nameAr: 'راحة', nameEn: 'Rest', durationSec: 20),
      WorkoutStep(nameAr: 'تسلق الجبل', nameEn: 'Mountain climbers', durationSec: 40),
      WorkoutStep(nameAr: 'راحة', nameEn: 'Rest', durationSec: 20),
      WorkoutStep(nameAr: 'قفز النجمة', nameEn: 'Jumping jacks', durationSec: 40),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w3', emoji: '🧘', gender: 'sisters', category: 'gentle', isPremium: false,
    titleAr: 'تمارين لطيفة للأخوات', titleEn: 'Gentle Exercises — Sisters',
    descAr: 'تمارين محتشمة لطيفة',
    descEn: 'Modest gentle exercises',
    durationMin: 12, level: 'مبتدئ', levelEn: 'Beginner',
    hadith: 'إن لجسدك عليك حقاً — البخاري',
    hadithEn: 'Your body has a right over you — Al-Bukhari',
    steps: [
      WorkoutStep(nameAr: 'إحماء', nameEn: 'Warm-up', durationSec: 120),
      WorkoutStep(nameAr: 'قرفصاء', nameEn: 'Squats', reps: 12),
      WorkoutStep(nameAr: 'دفع الحائط', nameEn: 'Wall push-ups', reps: 10),
      WorkoutStep(nameAr: 'رفع الساق الجانبي', nameEn: 'Side leg raise', reps: 15, instructionAr: '١٥ لكل ساق', instructionEn: '15 each leg'),
      WorkoutStep(nameAr: 'إطالة', nameEn: 'Stretching', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w5', emoji: '🌸', gender: 'sisters', category: 'postnatal', isPremium: false,
    titleAr: 'تعافي ما بعد الولادة', titleEn: 'Postnatal Recovery',
    descAr: 'تمارين آمنة بعد الولادة — استشيري طبيبك أولاً',
    descEn: 'Safe post-birth exercises — consult your doctor first',
    durationMin: 10, level: 'ما بعد الولادة', levelEn: 'Postnatal', levelColor: '#F57C00',
    steps: [
      WorkoutStep(nameAr: 'تنفس الحجاب الحاجز', nameEn: 'Diaphragm breathing', durationSec: 180),
      WorkoutStep(nameAr: 'تمارين قاع الحوض', nameEn: 'Pelvic floor', reps: 10, instructionAr: 'شدّي لمدة ٥ ثواني', instructionEn: 'Hold 5 seconds'),
      WorkoutStep(nameAr: 'إطالة لطيفة', nameEn: 'Gentle stretch', durationSec: 240),
    ],
  ),
  Workout(
    id: 'w9', emoji: '🤸', gender: 'sisters', category: 'gentle', isPremium: false,
    titleAr: 'إطالة وتمدد للأخوات', titleEn: 'Flexibility — Sisters',
    descAr: 'مرونة كاملة للجسم',
    descEn: 'Full body flexibility',
    durationMin: 15, level: 'مبتدئ', levelEn: 'Beginner',
    steps: [
      WorkoutStep(nameAr: 'إطالة العنق', nameEn: 'Neck stretch', durationSec: 120),
      WorkoutStep(nameAr: 'إطالة الكتف', nameEn: 'Shoulder stretch', durationSec: 120),
      WorkoutStep(nameAr: 'إطالة الظهر', nameEn: 'Back stretch', durationSec: 180),
      WorkoutStep(nameAr: 'إطالة الفخذ', nameEn: 'Hip flexor', durationSec: 120, instructionAr: '٦٠ ثانية كل جانب', instructionEn: '60s each side'),
      WorkoutStep(nameAr: 'استرخاء نهائي', nameEn: 'Final relaxation', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w4', emoji: '🌙', gender: 'both', category: 'ramadan', isPremium: false,
    titleAr: 'تمرين رمضان الخفيف', titleEn: 'Light Ramadan Workout',
    descAr: 'مصمم خصيصاً للصائم — خفيف وفعّال',
    descEn: 'Specially designed for fasting — light & effective',
    durationMin: 10, level: 'رمضان', levelEn: 'Ramadan', levelColor: '#D4A017',
    hadith: 'الصيام والقرآن يشفعان للعبد — أحمد',
    hadithEn: 'Fasting and Quran intercede for the servant — Ahmad',
    steps: [
      WorkoutStep(nameAr: 'تنفس رمضاني', nameEn: 'Ramadan breathing', durationSec: 120),
      WorkoutStep(nameAr: 'إطالة الجسم', nameEn: 'Full body stretch', durationSec: 180),
      WorkoutStep(nameAr: 'مشي خفيف', nameEn: 'Light walk', durationSec: 240),
      WorkoutStep(nameAr: 'قرفصاء خفيفة', nameEn: 'Light squats', reps: 8),
    ],
  ),
  Workout(
    id: 'w14', emoji: '🤲', gender: 'both', category: 'ramadan', isPremium: false,
    titleAr: 'تمرين بعد الإفطار', titleEn: 'Post-Iftar Workout',
    descAr: 'بعد الإفطار بساعتين — أمثل وقت في رمضان',
    descEn: 'Two hours after iftar — optimal Ramadan workout time',
    durationMin: 20, level: 'رمضان', levelEn: 'Ramadan', levelColor: '#D4A017',
    steps: [
      WorkoutStep(nameAr: 'إحماء', nameEn: 'Warm-up', durationSec: 120),
      WorkoutStep(nameAr: 'مشي سريع', nameEn: 'Brisk walk', durationSec: 600),
      WorkoutStep(nameAr: 'ضغط', nameEn: 'Push-ups', reps: 12),
      WorkoutStep(nameAr: 'قرفصاء', nameEn: 'Squats', reps: 15),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 120),
    ],
  ),
  Workout(
    id: 'w7', emoji: '🫁', gender: 'both', category: 'breathing', isPremium: false,
    titleAr: 'تمارين التنفس والاسترخاء', titleEn: 'Breathing & Relaxation',
    descAr: 'يُخفف التوتر ويُصفي الذهن',
    descEn: 'Reduces stress and clears mind',
    durationMin: 8, level: 'مبتدئ', levelEn: 'Beginner',
    hadith: 'ألا بذكر الله تطمئن القلوب — الرعد: ٢٨',
    hadithEn: 'Verily in the remembrance of Allah do hearts find rest — Quran 13:28',
    steps: [
      WorkoutStep(nameAr: 'تنفس صندوقي', nameEn: 'Box breathing', durationSec: 120, instructionAr: 'شهيق ٤، ثبات ٤، زفير ٤، ثبات ٤', instructionEn: 'Inhale 4, hold 4, exhale 4, hold 4'),
      WorkoutStep(nameAr: 'تنفس البطن', nameEn: 'Belly breathing', durationSec: 120),
      WorkoutStep(nameAr: 'استرخاء العضلات', nameEn: 'Muscle relaxation', durationSec: 180),
      WorkoutStep(nameAr: 'ذكر وتأمل', nameEn: 'Dhikr & reflection', durationSec: 60, instructionAr: 'سبحان الله، الحمد لله، الله أكبر', instructionEn: 'SubhanAllah, Alhamdulillah, Allahu Akbar'),
    ],
  ),
  Workout(
    id: 'w22', emoji: '💤', gender: 'both', category: 'breathing', isPremium: false,
    titleAr: 'نوم أفضل — تمرين قبل النوم', titleEn: 'Better Sleep Routine',
    descAr: 'استعدّ للنوم المثالي — مثبت علمياً',
    descEn: 'Prepare for optimal sleep — proven effective',
    durationMin: 10, level: 'مبتدئ', levelEn: 'Beginner',
    steps: [
      WorkoutStep(nameAr: 'إطالة الظهر', nameEn: 'Back stretch', durationSec: 120),
      WorkoutStep(nameAr: 'إطالة الورك', nameEn: 'Hip stretch', durationSec: 120),
      WorkoutStep(nameAr: 'استرخاء تدريجي', nameEn: 'Progressive relaxation', durationSec: 180),
      WorkoutStep(nameAr: 'تنفس النوم', nameEn: 'Sleep breathing', durationSec: 180, instructionAr: 'شهيق ٤ ثواني، زفير ٦ ثواني', instructionEn: 'Inhale 4s, exhale 6s'),
    ],
  ),
  Workout(
    id: 'w21', emoji: '🕌', gender: 'both', category: 'general', isPremium: false,
    titleAr: 'تمارين بين الصلوات', titleEn: 'Between Prayers Exercises',
    descAr: 'استغلال الأوقات بين الصلوات',
    descEn: 'Use the time between prayers to move',
    durationMin: 5, level: 'مبتدئ', levelEn: 'Beginner',
    steps: [
      WorkoutStep(nameAr: 'إطالة خفيفة', nameEn: 'Quick stretch', durationSec: 60),
      WorkoutStep(nameAr: 'قرفصاء', nameEn: 'Squats', reps: 10),
      WorkoutStep(nameAr: 'ضغط سريع', nameEn: 'Quick push-ups', reps: 8),
      WorkoutStep(nameAr: 'تنفس ذكر', nameEn: 'Dhikr breathing', durationSec: 60),
    ],
  ),
  Workout(
    id: 'w20', emoji: '👧', gender: 'both', category: 'family', isPremium: false,
    titleAr: 'ألعاب نشطة مع الأطفال', titleEn: 'Active Games with Kids',
    descAr: 'تمرين ممتع مع أبنائك',
    descEn: 'Fun exercise with your children',
    durationMin: 20, level: 'مبتدئ', levelEn: 'Beginner',
    steps: [
      WorkoutStep(nameAr: 'ركض تتبع', nameEn: 'Tag game', durationSec: 300),
      WorkoutStep(nameAr: 'قفز مع الأطفال', nameEn: 'Jump together', durationSec: 120),
      WorkoutStep(nameAr: 'مشي القرد', nameEn: 'Bear walk', durationSec: 60),
      WorkoutStep(nameAr: 'تهدئة معاً', nameEn: 'Cool down together', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w17', emoji: '🚴', gender: 'both', category: 'cardio', isPremium: true,
    titleAr: 'كارديو متقدم', titleEn: 'Advanced Cardio',
    descAr: 'لياقة قلبية عالية — حرق فعّال',
    descEn: 'High cardiovascular fitness — effective fat burn',
    durationMin: 30, level: 'متقدم', levelEn: 'Advanced', levelColor: '#C62828',
    steps: [
      WorkoutStep(nameAr: 'إحماء', nameEn: 'Warm-up', durationSec: 180),
      WorkoutStep(nameAr: 'جري محلي', nameEn: 'Jogging in place', durationSec: 300),
      WorkoutStep(nameAr: 'برباوي', nameEn: 'Burpees', reps: 15),
      WorkoutStep(nameAr: 'راحة', nameEn: 'Rest', durationSec: 60),
      WorkoutStep(nameAr: 'جري محلي', nameEn: 'Jogging in place', durationSec: 300),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w18', emoji: '🧗', gender: 'brothers', category: 'strength', isPremium: true,
    titleAr: 'تمرين القوة الكاملة', titleEn: 'Full Body Strength',
    descAr: 'تمرين شامل لكل عضلات الجسم',
    descEn: 'Complete workout for all muscle groups',
    durationMin: 35, level: 'متقدم', levelEn: 'Advanced', levelColor: '#C62828',
    steps: [
      WorkoutStep(nameAr: 'إحماء ديناميكي', nameEn: 'Dynamic warm-up', durationSec: 180),
      WorkoutStep(nameAr: 'ضغط متعدد الزوايا', nameEn: 'Multi-angle push-ups', reps: 20),
      WorkoutStep(nameAr: 'قرفصاء عميقة', nameEn: 'Deep squats', reps: 20),
      WorkoutStep(nameAr: 'طعنة بخطوة', nameEn: 'Walking lunges', reps: 16),
      WorkoutStep(nameAr: 'لوح', nameEn: 'Plank', durationSec: 60),
      WorkoutStep(nameAr: 'دفع الكتف', nameEn: 'Pike push-ups', reps: 12),
      WorkoutStep(nameAr: 'إطالة', nameEn: 'Stretch', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w19', emoji: '🌟', gender: 'sisters', category: 'strength', isPremium: true,
    titleAr: 'تناسق الأخوات المتقدم', titleEn: 'Sisters Advanced Toning',
    descAr: 'رشاقة وتناسق من الرأس للقدم — محتشم كامل',
    descEn: 'Full body toning head to toe — fully modest',
    durationMin: 30, level: 'متوسط', levelEn: 'Intermediate', levelColor: '#7C4DFF',
    steps: [
      WorkoutStep(nameAr: 'إحماء', nameEn: 'Warm-up', durationSec: 120),
      WorkoutStep(nameAr: 'ضغط معدّل', nameEn: 'Modified push-ups', reps: 12),
      WorkoutStep(nameAr: 'رفع الساق الخلفي', nameEn: 'Donkey kicks', reps: 15, instructionAr: 'كل جانب', instructionEn: 'Each side'),
      WorkoutStep(nameAr: 'قرفصاء الحائط', nameEn: 'Wall sit', durationSec: 45),
      WorkoutStep(nameAr: 'جسر الأرداف', nameEn: 'Glute bridge', reps: 15),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w12', emoji: '🦵', gender: 'brothers', category: 'strength', isPremium: true,
    titleAr: 'تمرين الساقين المتكامل', titleEn: 'Complete Leg Day',
    descAr: 'تقوية الساقين بالكامل بلا أجهزة',
    descEn: 'Full leg workout with no equipment',
    durationMin: 25, level: 'متوسط', levelEn: 'Intermediate', levelColor: '#0A6B4A',
    steps: [
      WorkoutStep(nameAr: 'إحماء الساق', nameEn: 'Leg warm-up', durationSec: 120),
      WorkoutStep(nameAr: 'قرفصاء واسعة', nameEn: 'Wide squat', reps: 15),
      WorkoutStep(nameAr: 'طعنة أمامية', nameEn: 'Forward lunge', reps: 10, instructionAr: '١٠ لكل ساق', instructionEn: '10 each leg'),
      WorkoutStep(nameAr: 'رفع الكعب', nameEn: 'Calf raises', reps: 20),
      WorkoutStep(nameAr: 'قفز القرفصاء', nameEn: 'Jump squats', reps: 10),
      WorkoutStep(nameAr: 'إطالة الساق', nameEn: 'Leg stretch', durationSec: 120),
    ],
  ),
  Workout(
    id: 'w23', emoji: '🌊', gender: 'both', category: 'cardio', isPremium: true,
    titleAr: 'كارديو المنزل ٣٠ دقيقة', titleEn: '30-Min Home Cardio',
    descAr: 'حرق الدهون في المنزل بدون أجهزة',
    descEn: 'Effective fat burning at home with no equipment',
    durationMin: 30, level: 'متوسط', levelEn: 'Intermediate', levelColor: '#0A6B4A',
    steps: [
      WorkoutStep(nameAr: 'إحماء', nameEn: 'Warm-up', durationSec: 180),
      WorkoutStep(nameAr: 'مجموعة ١: قفز', nameEn: 'Set 1: Jumping', durationSec: 180),
      WorkoutStep(nameAr: 'راحة', nameEn: 'Rest', durationSec: 30),
      WorkoutStep(nameAr: 'مجموعة ٢: عدو', nameEn: 'Set 2: Sprint in place', durationSec: 180),
      WorkoutStep(nameAr: 'راحة', nameEn: 'Rest', durationSec: 30),
      WorkoutStep(nameAr: 'مجموعة ٣: برباوي', nameEn: 'Set 3: Burpees', durationSec: 180),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 180),
    ],
  ),
  Workout(
    id: 'w13', emoji: '🧘‍♀️', gender: 'sisters', category: 'strength', isPremium: true,
    titleAr: 'تقوية المنطقة الوسطى للأخوات', titleEn: 'Core Strength — Sisters',
    descAr: 'تمارين البطن والخصر بطريقة محتشمة',
    descEn: 'Core exercises modest and safe',
    durationMin: 18, level: 'متوسط', levelEn: 'Intermediate', levelColor: '#D4A017',
    steps: [
      WorkoutStep(nameAr: 'لوح', nameEn: 'Plank', durationSec: 30),
      WorkoutStep(nameAr: 'لفات البطن', nameEn: 'Crunches', reps: 15),
      WorkoutStep(nameAr: 'رفع الساقين', nameEn: 'Leg raises', reps: 10),
      WorkoutStep(nameAr: 'جسر الأرداف', nameEn: 'Glute bridge', reps: 15),
      WorkoutStep(nameAr: 'لوح جانبي', nameEn: 'Side plank', durationSec: 25, instructionAr: 'كل جانب', instructionEn: 'Each side'),
      WorkoutStep(nameAr: 'تهدئة', nameEn: 'Cool down', durationSec: 120),
    ],
  ),
  Workout(
    id: 'w16', emoji: '🧠', gender: 'both', category: 'breathing', isPremium: false,
    titleAr: 'تمرين الذهن الصافي', titleEn: 'Clear Mind Practice',
    descAr: 'للمذاكرة والعمل — يُحسّن التركيز',
    descEn: 'For studying and work — improves focus',
    durationMin: 12, level: 'مبتدئ', levelEn: 'Beginner',
    steps: [
      WorkoutStep(nameAr: 'مشي قصير', nameEn: 'Short walk', durationSec: 180),
      WorkoutStep(nameAr: 'تنفس 4-7-8', nameEn: '4-7-8 breathing', durationSec: 180, instructionAr: 'شهيق ٤، ثبات ٧، زفير ٨', instructionEn: 'Inhale 4, hold 7, exhale 8'),
      WorkoutStep(nameAr: 'استرخاء الوجه', nameEn: 'Face relaxation', durationSec: 120),
    ],
  ),
  Workout(
    id: 'w15', emoji: '✨', gender: 'both', category: 'ramadan', isPremium: false,
    titleAr: 'تمرين السحور', titleEn: 'Suhoor Workout',
    descAr: 'حرّك جسمك قبل السحور',
    descEn: 'Move before suhoor — boosts metabolism',
    durationMin: 8, level: 'رمضان', levelEn: 'Ramadan', levelColor: '#D4A017',
    steps: [
      WorkoutStep(nameAr: 'إطالة الصباح', nameEn: 'Morning stretch', durationSec: 180),
      WorkoutStep(nameAr: 'تنفس عميق', nameEn: 'Deep breathing', durationSec: 120),
      WorkoutStep(nameAr: 'مشي خفيف', nameEn: 'Light walk', durationSec: 180),
    ],
  ),
];

// ── Daily Hadiths — 30 rotating ─────────────────
const kDailyHadiths = [
  {'ar': 'إن الله طيب لا يقبل إلا طيباً — مسلم',         'en': 'Allah is pure and accepts only what is pure — Muslim'},
  {'ar': 'المؤمن القوي خير من المؤمن الضعيف — مسلم',      'en': 'The strong believer is better than the weak — Muslim'},
  {'ar': 'إن لجسدك عليك حقاً — البخاري',                  'en': 'Your body has a right over you — Al-Bukhari'},
  {'ar': 'الطهور شطر الإيمان — مسلم',                      'en': 'Cleanliness is half of faith — Muslim'},
  {'ar': 'بارك الله لأمتي في بكورها — الترمذي',            'en': 'Allah blesses my nation in its early mornings — Al-Tirmidhi'},
  {'ar': 'لا ضرر ولا ضرار — ابن ماجه',                    'en': 'Do not cause harm or reciprocate harm — Ibn Majah'},
  {'ar': 'أحب الأعمال إلى الله أدومها وإن قل — متفق عليه', 'en': 'The most beloved deeds are the most consistent — Agreed upon'},
  {'ar': 'إذا أكل أحدكم فليأكل بيمينه — مسلم',            'en': 'When you eat, eat with your right hand — Muslim'},
  {'ar': 'كلوا واشربوا ولا تسرفوا — الأعراف: ٣١',          'en': 'Eat and drink but do not waste — Quran 7:31'},
  {'ar': 'نعمتان مغبون فيهما: الصحة والفراغ — البخاري',    'en': 'Two blessings often neglected: health and free time — Bukhari'},
  {'ar': 'ما ملأ ابن آدم وعاءً شراً من بطنه — الترمذي',    'en': 'No vessel filled is worse than the belly — Al-Tirmidhi'},
  {'ar': 'الصيام جنة — البخاري',                           'en': 'Fasting is a shield — Al-Bukhari'},
  {'ar': 'تسحروا فإن في السحور بركة — البخاري',            'en': 'Eat suhoor, there is blessing in it — Al-Bukhari'},
  {'ar': 'أفضل الصدقة أن تصدق وأنت صحيح — البخاري',       'en': 'Best charity is when you are healthy — Al-Bukhari'},
  {'ar': 'من أصبح منكم آمناً في سربه — الترمذي',           'en': 'He who wakes secure in his household — Al-Tirmidhi'},
  {'ar': 'ألا بذكر الله تطمئن القلوب — الرعد: ٢٨',         'en': 'In remembrance of Allah do hearts find rest — 13:28'},
  {'ar': 'يسروا ولا تعسروا وبشروا ولا تنفروا — متفق عليه',  'en': 'Make things easy, not difficult — Agreed upon'},
  {'ar': 'خير الناس أنفعهم للناس — الطبراني',              'en': 'The best people are those most beneficial — Al-Tabarani'},
  {'ar': 'البر حسن الخلق — مسلم',                          'en': 'Righteousness is good character — Muslim'},
  {'ar': 'لا تحقرن من المعروف شيئاً — مسلم',               'en': 'Do not belittle any act of kindness — Muslim'},
  {'ar': 'السواك مطهرة للفم مرضاة للرب — النسائي',          'en': 'Siwak purifies the mouth and pleases the Lord — Al-Nasa\'i'},
  {'ar': 'من لا يشكر الناس لا يشكر الله — الترمذي',        'en': 'Whoever does not thank people does not thank Allah — Tirmidhi'},
  {'ar': 'إن الله يحب إذا عمل أحدكم عملاً أن يتقنه — البيهقي', 'en': 'Allah loves when you do work with excellence — Al-Bayhaqi'},
  {'ar': 'عليك بالصدق فإن الصدق يهدي إلى البر — البخاري',  'en': 'Be truthful, for truth leads to righteousness — Bukhari'},
  {'ar': 'التواضع لا يزيد العبد إلا رفعة — الطبراني',       'en': 'Humility only raises a person\'s rank — Al-Tabarani'},
  {'ar': 'من كان يؤمن بالله واليوم الآخر فليقل خيراً أو ليصمت — متفق عليه', 'en': 'Speak good or remain silent — Agreed upon'},
  {'ar': 'الدعاء هو العبادة — الترمذي',                    'en': 'Du\'a is the essence of worship — Al-Tirmidhi'},
  {'ar': 'ما يزال البلاء بالمؤمن حتى يلقى الله وما عليه خطيئة — الترمذي', 'en': 'Trials continue for the believer until he meets Allah sinless — Tirmidhi'},
  {'ar': 'اللهم اجعلنا ممن إذا أُعطي شكر وإذا ابتُلي صبر — أحمد', 'en': 'O Allah make us those who are thankful when given — Ahmad'},
  {'ar': 'إن مع العسر يسراً — الشرح: ٦',                   'en': 'With every hardship comes ease — Quran 94:6'},
];

// ── Recipe ─────────────────────────────────────
class Recipe {
  final int id, timeMins, costEGP, kcal;
  final int proteinG, carbsG, fatG;
  final String nameAr;
  final List<String> sunnahIngredients, ingredients, steps;
  const Recipe({
    required this.id, required this.nameAr, required this.timeMins,
    required this.costEGP, required this.kcal,
    required this.proteinG, required this.carbsG, required this.fatG,
    required this.sunnahIngredients, required this.ingredients, required this.steps,
  });
}

const kRecipes = [
  Recipe(id: 1, nameAr: 'شوربة العدس السنية', timeMins: 25, costEGP: 18, kcal: 175,
    proteinG: 11, carbsG: 28, fatG: 3,
    sunnahIngredients: ['زيت زيتون', 'كمون'],
    ingredients: ['عدس أحمر ١ كوب', 'بصلة كبيرة', 'ثوم ٣ فصوص', 'كمون', 'زيت زيتون'],
    steps: ['أضف العدس والبصل والثوم مع ١ لتر ماء.', 'اغلِ ثم خفف النار ٢٠ دقيقة.', 'اخلط وأضف الكمون وزيت الزيتون.']),
  Recipe(id: 2, nameAr: 'سلطة التمر والجوز', timeMins: 10, costEGP: 35, kcal: 210,
    proteinG: 4, carbsG: 32, fatG: 9,
    sunnahIngredients: ['تمر', 'عسل'],
    ingredients: ['تمر مجفف ٦ حبات', 'جوز مفروم ٢٥ج', 'خس', 'عسل', 'ليمون'],
    steps: ['قطّع التمر والجوز.', 'اخلط مع الخس.', 'أضف عصير الليمون والعسل.']),
  Recipe(id: 3, nameAr: 'بيض مقلي بزيت الزيتون', timeMins: 8, costEGP: 12, kcal: 165,
    proteinG: 12, carbsG: 1, fatG: 12,
    sunnahIngredients: ['زيت زيتون'],
    ingredients: ['بيضتان', 'زيت زيتون بكر', 'ملح وكمون'],
    steps: ['سخن زيت الزيتون.', 'أضف البيض واطهُه.', 'رشّ الكمون والملح.']),
  Recipe(id: 4, nameAr: 'عصيدة الشوفان بالتمر والعسل', timeMins: 10, costEGP: 22, kcal: 280,
    proteinG: 8, carbsG: 52, fatG: 5,
    sunnahIngredients: ['تمر', 'عسل'],
    ingredients: ['شوفان ١ كوب', 'حليب ٢٠٠مل', 'تمر ٣ حبات', 'عسل', 'قرفة'],
    steps: ['اطبخ الشوفان مع الحليب.', 'أضف التمر والقرفة.', 'قدّم وأضف العسل.']),
  Recipe(id: 5, nameAr: 'شراب الحبة السوداء والعسل', timeMins: 3, costEGP: 8, kcal: 90,
    proteinG: 1, carbsG: 14, fatG: 2,
    sunnahIngredients: ['حبة سوداء', 'عسل'],
    ingredients: ['حبة سوداء مطحونة', 'عسل طبيعي', 'ماء فاتر'],
    steps: ['سخن الماء لدرجة فاترة.', 'أضف الحبة السوداء والعسل.', 'اشربه صباحاً على الريق.']),
  Recipe(id: 6, nameAr: 'دجاج مشوي بالثوم والليمون', timeMins: 35, costEGP: 85, kcal: 285,
    proteinG: 38, carbsG: 4, fatG: 12,
    sunnahIngredients: ['زيت زيتون'],
    ingredients: ['صدر دجاج حلال', 'ثوم', 'ليمون', 'زيت زيتون', 'كمون'],
    steps: ['تبّل الدجاج بالمكونات.', 'اترك ٣٠ دقيقة.', 'اشوِه ٦-٧ دقائق كل جانب.']),
];

// ── Health Article ──────────────────────────────
class HealthArticle {
  final String id, icon, title, summary, body;
  final int colorValue;
  const HealthArticle({
    required this.id, required this.icon, required this.title,
    required this.summary, required this.body, required this.colorValue,
  });
}

const kHealthArticles = [
  HealthArticle(id:'h1', icon:'💧', colorValue:0xFF2196F3, title:'الماء — شفاء كل شيء',
    summary:'احتياج الجسم اليومي وفوائد الإماهة',
    body:'يتكون جسمك من 60% ماء. كل خلية تحتاج الماء للعمل.\n\nالاحتياج اليومي:\n• رجال: 3.7 لتر\n• نساء: 2.7 لتر\n\nعلامات الجفاف:\n• لون البول داكن\n• صداع وتعب\n\nمن السنة: اشربوا في ثلاث جرعات وسمّوا الله.'),
  HealthArticle(id:'h2', icon:'😴', colorValue:0xFF7C4DFF, title:'النوم — رحمة ربانية',
    summary:'كيف يُشفي النوم الجسم والعقل',
    body:'النوم ليس سلبياً — الجسم يعمل بنشاط:\n\n• إصلاح الخلايا\n• تعزيز الذاكرة\n• تنظيف الدماغ\n• تقوية المناعة\n\nالاحتياج: 7-9 ساعات.\n\nمن السنة: النوم المبكر والاستيقاظ للفجر يوافق الساعة البيولوجية تماماً.'),
  HealthArticle(id:'h3', icon:'❤️', colorValue:0xFFE53935, title:'صحة القلب — حياة أطول',
    summary:'أرقام يجب أن تعرفها عن قلبك',
    body:'الأرقام الصحية:\n• ضغط الدم: أقل من 120/80\n• نبض الراحة: 60-100\n• الكوليسترول: أقل من 200 ملجم/دل\n\nالوقاية:\n• المشي يخفض الضغط 5-8 نقاط\n• الصيام يحسن حساسية الأنسولين'),
  HealthArticle(id:'h4', icon:'🧠', colorValue:0xFF00ACC1, title:'صحة الدماغ والذاكرة',
    summary:'غذاء وعادات تقوي عقلك',
    body:'أطعمة تقوي الدماغ من السنة:\n• العسل: مضاد أكسدة\n• زيت الزيتون: يقلل الالتهاب\n• التمر: يرفع الجلوكوز طبيعياً\n\nعادات مثبتة:\n• النوم الكافي\n• التمرين 30 دقيقة يومياً\n• قراءة القرآن الكريم'),
  HealthArticle(id:'h5', icon:'🦴', colorValue:0xFFFF7043, title:'العظام والمفاصل',
    summary:'تقوية الهيكل العظمي',
    body:'ذروة كثافة العظام في الـ 30!\n\nمصادر الكالسيوم:\n• حليب ومنتجات الألبان\n• السمسم والطحينة\n• الخضروات الورقية\n\nفيتامين D:\nأشعة الشمس 20 دقيقة يومياً.'),
  HealthArticle(id:'h6', icon:'🫁', colorValue:0xFF4CAF50, title:'الجهاز الهضمي',
    summary:'صحة الأمعاء = صحة الجسم كله',
    body:'95% من السيروتونين يُنتج في الأمعاء!\n\nأطعمة تقوي الأمعاء:\n• الألياف: شعير، عدس\n• البروبيوتيك: زبادي طبيعي\n• الزنجبيل والكمون\n\nالصيام المتقطع يُجدد بطانة الأمعاء!'),
  HealthArticle(id:'h7', icon:'🧘', colorValue:0xFF9C27B0, title:'الصحة النفسية',
    summary:'كيف تحمي عقلك وروحك',
    body:'تقنيات علمية مثبتة:\n• التنفس العميق: 4 شهيق، 4 زفير\n• المشي 20 دقيقة يخفض الكورتيزول 21٪\n\nمن الإسلام:\n• الذكر والتسبيح\n• الصلاة: تنفس + حركة + تأمل'),
  HealthArticle(id:'h8', icon:'⚖️', colorValue:0xFFFF5722, title:'الوزن ومؤشر كتلة الجسم',
    summary:'احسب وزنك المثالي',
    body:'BMI = الوزن ÷ الطول²\n\n• أقل من 18.5 = نقص وزن\n• 18.5-24.9 = وزن مثالي ✓\n• 25-29.9 = زيادة وزن\n• 30+ = سمنة\n\nالصيام المتقطع يقلل الوزن 3-8% خلال 8 أسابيع.'),
  HealthArticle(id:'h9', icon:'💊', colorValue:0xFF009688, title:'المكملات والفيتامينات',
    summary:'ما تحتاجه فعلاً',
    body:'الأهم:\n• فيتامين D3: 2000-4000 وحدة\n• أوميجا 3: 1-2 جرام\n• مغنيسيوم: 300-400 ملجم\n\nمن السنة:\n• الحبة السوداء: فيها شفاء\n• العسل الطبيعي: مضاد جرثومي'),
  HealthArticle(id:'h10', icon:'🩸', colorValue:0xFFF44336, title:'فحوصات سنوية أساسية',
    summary:'دليل الفحوصات الدورية',
    body:'الوقاية خير من العلاج!\n\nكل سنة فوق 18:\n✓ صورة دم كاملة CBC\n✓ سكر صيام\n✓ دهنيات الدم\n✓ فيتامين D و B12\n✓ ضغط الدم'),
];

// ── Quick Food — 50 items with full macros ───────
class QuickFood {
  final String name, nameEn;
  final int kcal;
  final double proteinG, carbsG, fatG;
  const QuickFood({
    required this.name, required this.nameEn,
    required this.kcal,
    this.proteinG = 0, this.carbsG = 0, this.fatG = 0,
  });
}

const kQuickFoods = [
  QuickFood(name: 'تمر (١ حبة)',        nameEn: 'Date (1 piece)',         kcal: 23,  proteinG: 0.2, carbsG: 6,   fatG: 0.0),
  QuickFood(name: 'عسل (١ ملعقة)',       nameEn: 'Honey (1 tbsp)',         kcal: 64,  proteinG: 0.1, carbsG: 17,  fatG: 0.0),
  QuickFood(name: 'زيت زيتون (١ ملعقة)', nameEn: 'Olive oil (1 tbsp)',     kcal: 119, proteinG: 0.0, carbsG: 0,   fatG: 14.0),
  QuickFood(name: 'حبة سوداء (١ م.ص)',  nameEn: 'Black seed (1 tsp)',     kcal: 16,  proteinG: 0.8, carbsG: 1,   fatG: 1.0),
  QuickFood(name: 'خل التفاح (١ م.ص)',  nameEn: 'Apple cider vinegar',    kcal: 3,   proteinG: 0.0, carbsG: 1,   fatG: 0.0),
  QuickFood(name: 'خبز أسمر (شريحة)',   nameEn: 'Whole wheat bread',     kcal: 80,  proteinG: 3,   carbsG: 15,  fatG: 1.0),
  QuickFood(name: 'خبز بلدي (رغيف)',    nameEn: 'Pita bread',             kcal: 165, proteinG: 5,   carbsG: 33,  fatG: 1.0),
  QuickFood(name: 'أرز أبيض (١ كوب)',   nameEn: 'White rice (1 cup)',     kcal: 206, proteinG: 4,   carbsG: 45,  fatG: 0.4),
  QuickFood(name: 'أرز بني (١ كوب)',    nameEn: 'Brown rice (1 cup)',     kcal: 216, proteinG: 5,   carbsG: 45,  fatG: 1.8),
  QuickFood(name: 'عدس مطبوخ (١ كوب)',  nameEn: 'Cooked lentils (1 cup)',kcal: 230, proteinG: 18,  carbsG: 40,  fatG: 1.0),
  QuickFood(name: 'فول مدمس (١ كوب)',   nameEn: 'Fava beans (1 cup)',    kcal: 187, proteinG: 13,  carbsG: 33,  fatG: 1.0),
  QuickFood(name: 'حمص مسلوق (١ كوب)',  nameEn: 'Chickpeas (1 cup)',     kcal: 269, proteinG: 15,  carbsG: 45,  fatG: 4.0),
  QuickFood(name: 'بيضة مسلوقة',        nameEn: 'Boiled egg',             kcal: 78,  proteinG: 6,   carbsG: 1,   fatG: 5.0),
  QuickFood(name: 'بيض مقلي (٢ بيضة)', nameEn: 'Fried eggs (2)',         kcal: 185, proteinG: 12,  carbsG: 2,   fatG: 14.0),
  QuickFood(name: 'دجاج مشوي (١٠٠ج)',  nameEn: 'Grilled chicken (100g)',kcal: 165, proteinG: 31,  carbsG: 0,   fatG: 4.0),
  QuickFood(name: 'لحم بقر مشوي (١٠٠ج)',nameEn: 'Grilled beef (100g)',  kcal: 215, proteinG: 26,  carbsG: 0,   fatG: 12.0),
  QuickFood(name: 'تونة معلبة (١٠٠ج)', nameEn: 'Canned tuna (100g)',    kcal: 116, proteinG: 26,  carbsG: 0,   fatG: 1.0),
  QuickFood(name: 'سمك مشوي (١٠٠ج)',   nameEn: 'Grilled fish (100g)',   kcal: 130, proteinG: 22,  carbsG: 0,   fatG: 4.0),
  QuickFood(name: 'جبنة بيضاء (٣٠ج)',  nameEn: 'White cheese (30g)',    kcal: 75,  proteinG: 5,   carbsG: 1,   fatG: 6.0),
  QuickFood(name: 'زبادي طبيعي (١ كوب)',nameEn: 'Plain yogurt (1 cup)', kcal: 150, proteinG: 8,   carbsG: 11,  fatG: 8.0),
  QuickFood(name: 'حليب كامل (٢٠٠ مل)', nameEn: 'Full milk (200ml)',    kcal: 130, proteinG: 7,   carbsG: 10,  fatG: 7.0),
  QuickFood(name: 'حليب قليل الدسم',    nameEn: 'Low-fat milk (200ml)',  kcal: 90,  proteinG: 7,   carbsG: 10,  fatG: 2.5),
  QuickFood(name: 'موز (حبة متوسطة)',   nameEn: 'Banana (medium)',        kcal: 105, proteinG: 1,   carbsG: 27,  fatG: 0.3),
  QuickFood(name: 'تفاح (حبة متوسطة)',  nameEn: 'Apple (medium)',         kcal: 95,  proteinG: 0.5, carbsG: 25,  fatG: 0.3),
  QuickFood(name: 'برتقال (حبة)',        nameEn: 'Orange',                 kcal: 62,  proteinG: 1,   carbsG: 15,  fatG: 0.2),
  QuickFood(name: 'عنب (١ كوب)',        nameEn: 'Grapes (1 cup)',         kcal: 104, proteinG: 1,   carbsG: 27,  fatG: 0.2),
  QuickFood(name: 'بطيخ (٢٠٠ج)',       nameEn: 'Watermelon (200g)',      kcal: 60,  proteinG: 1,   carbsG: 15,  fatG: 0.3),
  QuickFood(name: 'مانجو (١٠٠ج)',      nameEn: 'Mango (100g)',           kcal: 60,  proteinG: 0.8, carbsG: 15,  fatG: 0.4),
  QuickFood(name: 'توت (١ كوب)',        nameEn: 'Berries (1 cup)',        kcal: 84,  proteinG: 1,   carbsG: 21,  fatG: 0.5),
  QuickFood(name: 'طماطم (حبة كبيرة)',  nameEn: 'Tomato (large)',         kcal: 35,  proteinG: 2,   carbsG: 7,   fatG: 0.4),
  QuickFood(name: 'خيار (حبة)',         nameEn: 'Cucumber',               kcal: 16,  proteinG: 1,   carbsG: 4,   fatG: 0.1),
  QuickFood(name: 'سبانخ مطبوخة (١ كوب)',nameEn: 'Cooked spinach (1c)', kcal: 41,  proteinG: 5,   carbsG: 7,   fatG: 0.5),
  QuickFood(name: 'بطاطا مشوية (١٠٠ج)',nameEn: 'Baked potato (100g)',   kcal: 93,  proteinG: 2,   carbsG: 21,  fatG: 0.1),
  QuickFood(name: 'بطاطا حلوة (١٠٠ج)', nameEn: 'Sweet potato (100g)',   kcal: 86,  proteinG: 2,   carbsG: 20,  fatG: 0.1),
  QuickFood(name: 'لوز (٣٠ج)',          nameEn: 'Almonds (30g)',          kcal: 173, proteinG: 6,   carbsG: 6,   fatG: 15.0),
  QuickFood(name: 'جوز (٣٠ج)',          nameEn: 'Walnuts (30g)',          kcal: 196, proteinG: 5,   carbsG: 4,   fatG: 20.0),
  QuickFood(name: 'فستق (٣٠ج)',         nameEn: 'Pistachios (30g)',       kcal: 159, proteinG: 6,   carbsG: 8,   fatG: 13.0),
  QuickFood(name: 'سمسم (٢ م.ك)',       nameEn: 'Sesame seeds (2 tbsp)', kcal: 104, proteinG: 3,   carbsG: 4,   fatG: 9.0),
  QuickFood(name: 'شوفان مطبوخ (١ كوب)',nameEn: 'Oatmeal (1 cup)',      kcal: 166, proteinG: 6,   carbsG: 28,  fatG: 4.0),
  QuickFood(name: 'كينوا مطبوخة (١ كوب)',nameEn: 'Cooked quinoa (1c)',  kcal: 222, proteinG: 8,   carbsG: 39,  fatG: 4.0),
  QuickFood(name: 'خبز توست (شريحتان)', nameEn: 'Toast (2 slices)',      kcal: 160, proteinG: 6,   carbsG: 30,  fatG: 2.0),
  QuickFood(name: 'عصير برتقال طازج',   nameEn: 'Fresh OJ (200ml)',      kcal: 88,  proteinG: 1,   carbsG: 21,  fatG: 0.4),
  QuickFood(name: 'لبن (٢٠٠ مل)',       nameEn: 'Lassi/Buttermilk',      kcal: 72,  proteinG: 4,   carbsG: 8,   fatG: 2.5),
  QuickFood(name: 'شاي بالحليب',        nameEn: 'Tea with milk',          kcal: 45,  proteinG: 1,   carbsG: 6,   fatG: 1.5),
  QuickFood(name: 'طحينة (١ م.ك)',      nameEn: 'Tahini (1 tbsp)',        kcal: 89,  proteinG: 3,   carbsG: 3,   fatG: 8.0),
  QuickFood(name: 'حلاوة طحينية (٣٠ج)', nameEn: 'Halawa (30g)',          kcal: 159, proteinG: 3,   carbsG: 14,  fatG: 10.0),
  QuickFood(name: 'مربى (١ م.ك)',       nameEn: 'Jam (1 tbsp)',           kcal: 56,  proteinG: 0.1, carbsG: 14,  fatG: 0.0),
  QuickFood(name: 'شوربة عدس (كوب)',    nameEn: 'Lentil soup (cup)',      kcal: 175, proteinG: 11,  carbsG: 28,  fatG: 3.0),
  QuickFood(name: 'كشري (طبق متوسط)',   nameEn: 'Koshari (medium plate)', kcal: 430, proteinG: 15,  carbsG: 85,  fatG: 5.0),
  QuickFood(name: 'فتة بالدجاج',        nameEn: 'Chicken fattah',         kcal: 520, proteinG: 32,  carbsG: 55,  fatG: 18.0),
  QuickFood(name: 'وجبة خفيفة صحية',   nameEn: 'Healthy snack',          kcal: 150, proteinG: 5,   carbsG: 20,  fatG: 5.0),
  QuickFood(name: 'كشري (طبق كبير)',      nameEn: 'Koshari (large)',        kcal: 520, proteinG: 16, carbsG: 98,  fatG: 6.0),
  QuickFood(name: 'مكرونة بشاميل',        nameEn: 'Bechamel pasta',         kcal: 380, proteinG: 18, carbsG: 42,  fatG: 14.0),
  QuickFood(name: 'ملوخية بالدجاج',       nameEn: 'Molokhia with chicken',  kcal: 210, proteinG: 22, carbsG: 8,   fatG: 9.0),
  QuickFood(name: 'كفتة مشوية (٢ قطعة)', nameEn: 'Grilled kofta (2pc)',    kcal: 280, proteinG: 24, carbsG: 4,   fatG: 18.0),
  QuickFood(name: 'طاجن لحم بالخضار',    nameEn: 'Meat tagine',            kcal: 340, proteinG: 28, carbsG: 14,  fatG: 18.0),
  QuickFood(name: 'محشي ورق عنب (٥)',    nameEn: 'Stuffed grape leaves',   kcal: 180, proteinG: 6,  carbsG: 26,  fatG: 7.0),
  QuickFood(name: 'أرز بالشعرية',        nameEn: 'Rice with vermicelli',   kcal: 240, proteinG: 5,  carbsG: 50,  fatG: 3.0),
  QuickFood(name: 'بامية باللحم',        nameEn: 'Okra with meat',         kcal: 195, proteinG: 16, carbsG: 12,  fatG: 9.0),
  QuickFood(name: 'حساء الشعير',         nameEn: 'Barley soup',            kcal: 160, proteinG: 6,  carbsG: 30,  fatG: 2.0),
  QuickFood(name: 'بيض بالبسطرمة',       nameEn: 'Eggs with pastrami',     kcal: 220, proteinG: 18, carbsG: 2,   fatG: 16.0),
  QuickFood(name: 'فول نابت',            nameEn: 'Sprouted fava beans',    kcal: 140, proteinG: 10, carbsG: 22,  fatG: 1.0),
  QuickFood(name: 'عيش شمسي',            nameEn: 'Sourdough bread',        kcal: 200, proteinG: 7,  carbsG: 40,  fatG: 2.0),
  QuickFood(name: 'خبز فينو',            nameEn: 'Fino bread roll',        kcal: 250, proteinG: 8,  carbsG: 48,  fatG: 3.0),
  QuickFood(name: 'سمن بلدي (١ م.ك)',    nameEn: 'Ghee (1 tbsp)',          kcal: 130, proteinG: 0,  carbsG: 0,   fatG: 14.0),
  QuickFood(name: 'عسل سدر (١ م.ك)',     nameEn: 'Sidr honey (1 tbsp)',    kcal: 64,  proteinG: 0.1, carbsG: 17, fatG: 0.0),
  QuickFood(name: 'تمر مجدول (١ حبة)',   nameEn: 'Medjool date',           kcal: 66,  proteinG: 0.4, carbsG: 18, fatG: 0.0),
  QuickFood(name: 'تمر عجوة (١ حبة)',    nameEn: 'Ajwa date',              kcal: 20,  proteinG: 0.2, carbsG: 5,  fatG: 0.0),
  QuickFood(name: 'زيت حبة البركة',      nameEn: 'Black seed oil (1 tsp)', kcal: 45,  proteinG: 0,   carbsG: 0,  fatG: 5.0),
  QuickFood(name: 'خل التفاح (١ م.ك)',   nameEn: 'ACV (1 tbsp)',           kcal: 3,   proteinG: 0,   carbsG: 0,  fatG: 0.0),
  QuickFood(name: 'ثمر الزيتون (١٠)',    nameEn: 'Olives (10 pcs)',        kcal: 59,  proteinG: 0.4, carbsG: 2,  fatG: 6.0),
  QuickFood(name: 'حليب إبل (٢٠٠مل)',   nameEn: 'Camel milk (200ml)',     kcal: 108, proteinG: 5.8, carbsG: 9,  fatG: 5.0),
  QuickFood(name: 'ثريد (طبق)',          nameEn: 'Thareed dish',           kcal: 420, proteinG: 28,  carbsG: 48, fatG: 12.0),
  QuickFood(name: 'لبن رائب (١ كوب)',    nameEn: 'Cultured milk',          kcal: 110, proteinG: 8,   carbsG: 12, fatG: 3.0),
  QuickFood(name: 'قرع/يقطين مسلوق',    nameEn: 'Boiled pumpkin',         kcal: 49,  proteinG: 2,   carbsG: 12, fatG: 0.1),
  QuickFood(name: 'حساء الثريد بالخروف', nameEn: 'Lamb thareed soup',     kcal: 380, proteinG: 30,  carbsG: 32, fatG: 14.0),
  QuickFood(name: 'كبسة دجاج (طبق)',     nameEn: 'Chicken kabsa',          kcal: 580, proteinG: 38, carbsG: 68,  fatG: 16.0),
  QuickFood(name: 'مندي لحم (طبق)',      nameEn: 'Lamb mandi',             kcal: 620, proteinG: 42, carbsG: 65,  fatG: 18.0),
  QuickFood(name: 'جريش (طبق)',          nameEn: 'Jareesh dish',           kcal: 320, proteinG: 12, carbsG: 58,  fatG: 5.0),
  QuickFood(name: 'حريرة (كوب)',         nameEn: 'Harira soup (cup)',      kcal: 185, proteinG: 11, carbsG: 28,  fatG: 4.0),
  QuickFood(name: 'مطبق لحم',            nameEn: 'Meat mutabbaq',          kcal: 420, proteinG: 22, carbsG: 42,  fatG: 18.0),
  QuickFood(name: 'صالونة دجاج',         nameEn: 'Chicken saloona',        kcal: 245, proteinG: 26, carbsG: 14,  fatG: 9.0),
  QuickFood(name: 'خبز تنور',            nameEn: 'Tandoor bread',          kcal: 180, proteinG: 6,  carbsG: 36,  fatG: 2.0),
  QuickFood(name: 'حمص بالطحينة (١٠٠ج)', nameEn: 'Hummus (100g)',         kcal: 166, proteinG: 8,  carbsG: 14,  fatG: 10.0),
  QuickFood(name: 'فلافل (٣ حبات)',      nameEn: 'Falafel (3 pcs)',        kcal: 180, proteinG: 7,  carbsG: 18,  fatG: 9.0),
  QuickFood(name: 'تبولة (١٠٠ج)',        nameEn: 'Tabbouleh (100g)',       kcal: 100, proteinG: 3,  carbsG: 14,  fatG: 4.0),
  QuickFood(name: 'شاورما دجاج (ساندوتش)',nameEn: 'Chicken shawarma',     kcal: 440, proteinG: 30, carbsG: 45,  fatG: 14.0),
  QuickFood(name: 'كباب مشوي (٢ قطعة)', nameEn: 'Grilled kebab (2pc)',    kcal: 320, proteinG: 28, carbsG: 2,   fatG: 22.0),
  QuickFood(name: 'مسقعة (١٠٠ج)',        nameEn: 'Moussaka (100g)',        kcal: 140, proteinG: 5,  carbsG: 12,  fatG: 8.0),
  QuickFood(name: 'فتوش (طبق)',          nameEn: 'Fattoush salad',         kcal: 130, proteinG: 3,  carbsG: 20,  fatG: 5.0),
  QuickFood(name: 'لبنة (٥٠ج)',          nameEn: 'Labneh (50g)',           kcal: 75,  proteinG: 5,  carbsG: 3,   fatG: 5.0),
  QuickFood(name: 'منسف لحم (طبق)',      nameEn: 'Mansaf with lamb',       kcal: 680, proteinG: 45, carbsG: 72,  fatG: 22.0),
  QuickFood(name: 'لحم غنم مشوي (١٠٠ج)', nameEn: 'Grilled lamb (100g)',  kcal: 258, proteinG: 25, carbsG: 0,   fatG: 17.0),
  QuickFood(name: 'لحم جمل (١٠٠ج)',      nameEn: 'Camel meat (100g)',     kcal: 186, proteinG: 28, carbsG: 0,   fatG: 8.0),
  QuickFood(name: 'قلوب دجاج (١٠٠ج)',   nameEn: 'Chicken hearts (100g)', kcal: 185, proteinG: 26, carbsG: 0,   fatG: 8.0),
  QuickFood(name: 'كبدة دجاج (١٠٠ج)',   nameEn: 'Chicken liver (100g)',  kcal: 172, proteinG: 27, carbsG: 1,   fatG: 6.0),
  QuickFood(name: 'سمك بوري مشوي',       nameEn: 'Grilled mullet',        kcal: 148, proteinG: 24, carbsG: 0,   fatG: 5.0),
  QuickFood(name: 'جمبري مشوي (١٠٠ج)', nameEn: 'Grilled shrimp (100g)', kcal: 99,  proteinG: 24, carbsG: 0,   fatG: 1.0),
  QuickFood(name: 'سردين معلب (١٠٠ج)',  nameEn: 'Canned sardines (100g)',kcal: 208, proteinG: 25, carbsG: 0,   fatG: 11.0),
  QuickFood(name: 'بيض مسلوق (٢ بيضة)', nameEn: 'Boiled eggs (2)',       kcal: 156, proteinG: 12, carbsG: 2,   fatG: 10.0),
  QuickFood(name: 'ستيك لحم بقر (١٥٠ج)',nameEn: 'Beef steak (150g)',    kcal: 322, proteinG: 39, carbsG: 0,   fatG: 18.0),
  QuickFood(name: 'جبنة رومي (٣٠ج)',    nameEn: 'Rumi cheese (30g)',     kcal: 120, proteinG: 8,  carbsG: 0,   fatG: 10.0),
  QuickFood(name: 'جبنة موزاريلا (٣٠ج)',nameEn: 'Mozzarella (30g)',      kcal: 85,  proteinG: 6,  carbsG: 1,   fatG: 6.0),
  QuickFood(name: 'قشطة (١ م.ك)',        nameEn: 'Clotted cream (1 tbsp)',kcal: 52,  proteinG: 0.5, carbsG: 1, fatG: 5.0),
  QuickFood(name: 'زبدة (١ م.ك)',        nameEn: 'Butter (1 tbsp)',       kcal: 102, proteinG: 0.1, carbsG: 0, fatG: 12.0),
  QuickFood(name: 'حليب جاموسي (٢٠٠مل)',nameEn: 'Buffalo milk (200ml)', kcal: 236, proteinG: 8,  carbsG: 10,  fatG: 18.0),
  QuickFood(name: 'زبادي يوناني (١٥٠ج)',nameEn: 'Greek yogurt (150g)',  kcal: 130, proteinG: 17, carbsG: 6,   fatG: 4.0),
  QuickFood(name: 'بصل أخضر (٥٠ج)',    nameEn: 'Spring onions (50g)',   kcal: 16,  proteinG: 0.9, carbsG: 3,  fatG: 0.1),
  QuickFood(name: 'فلفل ألوان (١٠٠ج)', nameEn: 'Bell peppers (100g)',   kcal: 31,  proteinG: 1,   carbsG: 6,  fatG: 0.3),
  QuickFood(name: 'زيتون أسود (١٠)',   nameEn: 'Black olives (10)',     kcal: 73,  proteinG: 0.5, carbsG: 4,  fatG: 7.0),
  QuickFood(name: 'كوسة مشوية (١٠٠ج)', nameEn: 'Grilled zucchini',     kcal: 35,  proteinG: 2,   carbsG: 5,  fatG: 1.0),
  QuickFood(name: 'باذنجان مشوي (١٠٠ج)',nameEn: 'Grilled eggplant',    kcal: 45,  proteinG: 2,   carbsG: 8,  fatG: 1.0),
  QuickFood(name: 'ذرة مسلوقة (١ كيزة)',nameEn: 'Boiled corn cob',     kcal: 132, proteinG: 5,   carbsG: 29, fatG: 2.0),
  QuickFood(name: 'جزر مسلوق (١٠٠ج)', nameEn: 'Boiled carrots (100g)',kcal: 41,  proteinG: 1,   carbsG: 10, fatG: 0.2),
  QuickFood(name: 'فاصوليا خضراء (١٠٠ج)',nameEn: 'Green beans (100g)', kcal: 31,  proteinG: 2,   carbsG: 7,  fatG: 0.1),
  QuickFood(name: 'بروكلي مسلوق (١٠٠ج)',nameEn: 'Boiled broccoli',    kcal: 35,  proteinG: 2,   carbsG: 7,  fatG: 0.4),
  QuickFood(name: 'سلطة خضراء (طبق)',  nameEn: 'Green salad (plate)',  kcal: 45,  proteinG: 2,   carbsG: 8,  fatG: 2.0),
  QuickFood(name: 'رمان (حبة متوسطة)', nameEn: 'Pomegranate (medium)', kcal: 234, proteinG: 5,  carbsG: 53,  fatG: 3.0),
  QuickFood(name: 'تين طازج (٢ حبة)',  nameEn: 'Fresh figs (2)',       kcal: 74,  proteinG: 1,  carbsG: 19,  fatG: 0.3),
  QuickFood(name: 'عنب أسود (١ كوب)', nameEn: 'Black grapes (1 cup)', kcal: 100, proteinG: 1,  carbsG: 27,  fatG: 0.2),
  QuickFood(name: 'خوخ (حبة)',         nameEn: 'Peach',                kcal: 59,  proteinG: 1,  carbsG: 15,  fatG: 0.4),
  QuickFood(name: 'مشمش (٣ حبات)',    nameEn: 'Apricots (3)',         kcal: 48,  proteinG: 1,  carbsG: 11,  fatG: 0.4),
  QuickFood(name: 'إجاص (حبة)',        nameEn: 'Pear',                 kcal: 101, proteinG: 1,  carbsG: 27,  fatG: 0.2),
  QuickFood(name: 'فراولة (١ كوب)',   nameEn: 'Strawberries (1 cup)', kcal: 49,  proteinG: 1,  carbsG: 12,  fatG: 0.5),
  QuickFood(name: 'كيوي (حبة)',        nameEn: 'Kiwi',                 kcal: 61,  proteinG: 1,  carbsG: 15,  fatG: 0.5),
  QuickFood(name: 'ليمون (حبة)',       nameEn: 'Lemon',                kcal: 17,  proteinG: 0.6,carbsG: 5,   fatG: 0.2),
  QuickFood(name: 'أناناس (١٠٠ج)',    nameEn: 'Pineapple (100g)',     kcal: 50,  proteinG: 0.5,carbsG: 13,  fatG: 0.1),
  QuickFood(name: 'قهوة سادة (فنجان)', nameEn: 'Black coffee (cup)',   kcal: 2,   proteinG: 0,  carbsG: 0,   fatG: 0.0),
  QuickFood(name: 'قهوة بالحليب',      nameEn: 'Coffee with milk',     kcal: 60,  proteinG: 3,  carbsG: 6,   fatG: 2.5),
  QuickFood(name: 'عصير مانجو طازج',   nameEn: 'Fresh mango juice',    kcal: 120, proteinG: 1,  carbsG: 30,  fatG: 0.3),
  QuickFood(name: 'عصير رمان طازج',    nameEn: 'Fresh pomegranate juice',kcal:134, proteinG: 1, carbsG: 33,  fatG: 0.7),
  QuickFood(name: 'شاي أخضر (كوب)',   nameEn: 'Green tea (cup)',       kcal: 2,   proteinG: 0,  carbsG: 0,   fatG: 0.0),
  QuickFood(name: 'شاي أسود بنعناع',  nameEn: 'Mint black tea',        kcal: 5,   proteinG: 0,  carbsG: 1,   fatG: 0.0),
  QuickFood(name: 'عرق سوس (كوب)',    nameEn: 'Licorice drink (cup)',  kcal: 45,  proteinG: 0,  carbsG: 11,  fatG: 0.0),
  QuickFood(name: 'كركديه بارد (كوب)', nameEn: 'Hibiscus drink (cup)', kcal: 37,  proteinG: 0,  carbsG: 9,   fatG: 0.0),
  QuickFood(name: 'تمر هندي (كوب)',   nameEn: 'Tamarind drink (cup)', kcal: 120, proteinG: 1,  carbsG: 31,  fatG: 0.1),
  QuickFood(name: 'لبن ساده (كوب)',   nameEn: 'Plain lassi (cup)',     kcal: 72,  proteinG: 4,  carbsG: 8,   fatG: 2.5),
  QuickFood(name: 'لقيمات (٥ حبات)',  nameEn: 'Luqaimat (5 pcs)',     kcal: 250, proteinG: 4,  carbsG: 38,  fatG: 10.0),
  QuickFood(name: 'كنافة (١٠٠ج)',    nameEn: 'Kunafa (100g)',         kcal: 380, proteinG: 8,  carbsG: 52,  fatG: 16.0),
  QuickFood(name: 'بسبوسة (قطعة)',   nameEn: 'Basbousa (piece)',      kcal: 220, proteinG: 4,  carbsG: 38,  fatG: 7.0),
  QuickFood(name: 'أم علي (١٠٠ج)',   nameEn: 'Om Ali (100g)',         kcal: 290, proteinG: 7,  carbsG: 38,  fatG: 13.0),
  QuickFood(name: 'حلوى المولد',      nameEn: 'Mawlid candy (30g)',   kcal: 110, proteinG: 0,  carbsG: 28,  fatG: 0.0),
  QuickFood(name: 'مهلبية (كوب)',    nameEn: 'Muhallabia (cup)',      kcal: 180, proteinG: 5,  carbsG: 32,  fatG: 4.0),
  QuickFood(name: 'تمر محشي بالجوز', nameEn: 'Walnut-stuffed dates', kcal: 90,  proteinG: 1,  carbsG: 16,  fatG: 3.0),
  QuickFood(name: 'فستق حلبي (٣٠ج)', nameEn: 'Pistachios (30g)',     kcal: 159, proteinG: 6,  carbsG: 8,   fatG: 13.0),
  QuickFood(name: 'كاشير (٣٠ج)',     nameEn: 'Cashews (30g)',         kcal: 164, proteinG: 5,  carbsG: 9,   fatG: 13.0),
  QuickFood(name: 'برغل مطبوخ (١ كوب)',nameEn: 'Cooked bulgur (1c)',  kcal: 151, proteinG: 6,  carbsG: 34,  fatG: 0.4),
  QuickFood(name: 'فريك مطبوخ (١ كوب)',nameEn: 'Cooked freekeh (1c)',kcal: 180, proteinG: 8,  carbsG: 38,  fatG: 1.5),
  QuickFood(name: 'عدس أخضر (١ كوب)', nameEn: 'Green lentils (1c)',  kcal: 230, proteinG: 18, carbsG: 40,  fatG: 0.8),
  QuickFood(name: 'فاصوليا بيضاء (١ كوب)',nameEn: 'White beans (1c)',kcal: 249, proteinG: 17, carbsG: 45,  fatG: 0.6),
  QuickFood(name: 'بازلاء (١ كوب)',   nameEn: 'Green peas (1c)',      kcal: 134, proteinG: 9,  carbsG: 25,  fatG: 0.4),
  QuickFood(name: 'ذرة صفراء (١ كوب)',nameEn: 'Sweet corn (1c)',      kcal: 132, proteinG: 5,  carbsG: 29,  fatG: 2.0),
  QuickFood(name: 'هريس بالدجاج (طبق)',    nameEn: 'Chicken harees',         kcal: 420, proteinG: 32, carbsG: 48,  fatG: 10.0),
  QuickFood(name: 'مرقوق لحم (طبق)',       nameEn: 'Meat margoug',           kcal: 480, proteinG: 28, carbsG: 52,  fatG: 16.0),
  QuickFood(name: 'سليق (طبق)',            nameEn: 'Saudi saleeg',           kcal: 520, proteinG: 30, carbsG: 62,  fatG: 14.0),
  QuickFood(name: 'قوزي (حصة)',            nameEn: 'Qouzi lamb rice',        kcal: 650, proteinG: 42, carbsG: 70,  fatG: 20.0),
  QuickFood(name: 'لقيمات بالعسل (٥)',    nameEn: 'Luqaimat with honey',    kcal: 280, proteinG: 4,  carbsG: 44,  fatG: 11.0),
  QuickFood(name: 'محمر (طبق)',            nameEn: 'Muhammar sweet rice',    kcal: 340, proteinG: 5,  carbsG: 72,  fatG: 4.0),
  QuickFood(name: 'مطبق دجاج',            nameEn: 'Chicken mutabbaq',       kcal: 380, proteinG: 24, carbsG: 38,  fatG: 14.0),
  QuickFood(name: 'أسياخ لحم مشوي',       nameEn: 'Grilled meat skewers',   kcal: 310, proteinG: 30, carbsG: 2,   fatG: 20.0),
  QuickFood(name: 'ماء زمزم (٢٥٠مل)',     nameEn: 'Zamzam water',           kcal: 0,   proteinG: 0,  carbsG: 0,   fatG: 0.0),
  QuickFood(name: 'تمر صفري (٣ حبات)',    nameEn: 'Safawi dates (3)',        kcal: 60,  proteinG: 0.5,carbsG: 16,  fatG: 0.0),
  QuickFood(name: 'قهوة عربية (فنجان)',   nameEn: 'Arabic coffee (cup)',     kcal: 5,   proteinG: 0,  carbsG: 1,   fatG: 0.0),
  QuickFood(name: 'حليب بعير (٢٠٠مل)',   nameEn: 'Camel milk (200ml)',      kcal: 108, proteinG: 5.8,carbsG: 9,   fatG: 5.0),
  QuickFood(name: 'خبز رقاق (رقيفة)',    nameEn: 'Raqaq flatbread',        kcal: 120, proteinG: 3,  carbsG: 24,  fatG: 1.5),
  QuickFood(name: 'شاورما لحم (ساندوتش)', nameEn: 'Beef shawarma sandwich',  kcal: 520, proteinG: 32, carbsG: 48,  fatG: 18.0),
  QuickFood(name: 'فريك بالدجاج (طبق)',  nameEn: 'Freekeh with chicken',   kcal: 480, proteinG: 38, carbsG: 52,  fatG: 10.0),
  QuickFood(name: 'بيتزا مارغريتا (شريحة)',nameEn: 'Margherita pizza slice', kcal: 272, proteinG: 12, carbsG: 34,  fatG: 10.0),
  QuickFood(name: 'برجر دجاج حلال',       nameEn: 'Halal chicken burger',   kcal: 490, proteinG: 30, carbsG: 44,  fatG: 20.0),
  QuickFood(name: 'باستا بولونيز',         nameEn: 'Pasta bolognese',        kcal: 420, proteinG: 22, carbsG: 52,  fatG: 12.0),
  QuickFood(name: 'شوربة طماطم (كوب)',    nameEn: 'Tomato soup (cup)',       kcal: 90,  proteinG: 3,  carbsG: 16,  fatG: 2.0),
  QuickFood(name: 'سلطة سيزر بالدجاج',   nameEn: 'Caesar salad w chicken',  kcal: 380, proteinG: 28, carbsG: 14,  fatG: 22.0),
  QuickFood(name: 'سباغيتي مع صلصة',     nameEn: 'Spaghetti with sauce',   kcal: 350, proteinG: 14, carbsG: 58,  fatG: 8.0),
  QuickFood(name: 'شوربة دجاج بالخضار',  nameEn: 'Chicken vegetable soup',  kcal: 120, proteinG: 10, carbsG: 12,  fatG: 3.0),
  QuickFood(name: 'سندوتش تونة',          nameEn: 'Tuna sandwich',          kcal: 320, proteinG: 22, carbsG: 34,  fatG: 10.0),
  QuickFood(name: 'بيض مخفوق مع خبز',   nameEn: 'Scrambled eggs on toast', kcal: 280, proteinG: 16, carbsG: 24,  fatG: 12.0),
  QuickFood(name: 'دجاج مشوي مع أرز',   nameEn: 'Grilled chicken & rice',  kcal: 480, proteinG: 42, carbsG: 48,  fatG: 8.0),
  QuickFood(name: 'ستيك سالمون مشوي',   nameEn: 'Grilled salmon steak',    kcal: 280, proteinG: 34, carbsG: 0,   fatG: 16.0),
  QuickFood(name: 'بطاطس مقلية (حصة)',  nameEn: 'French fries (portion)',   kcal: 365, proteinG: 4,  carbsG: 48,  fatG: 17.0),
  QuickFood(name: 'كولسلو (١٠٠ج)',      nameEn: 'Coleslaw (100g)',          kcal: 152, proteinG: 1,  carbsG: 14,  fatG: 10.0),
  QuickFood(name: 'بروتين واي (سكوب)',  nameEn: 'Whey protein (1 scoop)',   kcal: 120, proteinG: 25, carbsG: 3,   fatG: 2.0),
  QuickFood(name: 'شوكولاتة داكنة (٣٠ج)',nameEn: 'Dark chocolate (30g)',   kcal: 170, proteinG: 2,  carbsG: 13,  fatG: 12.0),
  QuickFood(name: 'كريب بالموز',         nameEn: 'Banana crepe',            kcal: 230, proteinG: 6,  carbsG: 38,  fatG: 7.0),
  QuickFood(name: 'عصير تفاح طبيعي',    nameEn: 'Natural apple juice',     kcal: 114, proteinG: 0.5,carbsG: 28,  fatG: 0.3),
  QuickFood(name: 'لاتيه بالحليب',       nameEn: 'Latte with milk',         kcal: 190, proteinG: 7,  carbsG: 18,  fatG: 7.0),
  QuickFood(name: 'كابوتشينو',           nameEn: 'Cappuccino',              kcal: 120, proteinG: 5,  carbsG: 10,  fatG: 5.0),
  QuickFood(name: 'سموذي فراولة موز',   nameEn: 'Strawberry banana smoothie',kcal:200, proteinG: 4,  carbsG: 45,  fatG: 1.0),
  // ═══ PAKISTANI & INDIAN HALAL ═══════════════════════════════════
  QuickFood(name: 'بيريانى دجاج (طبق)',    nameEn: 'Chicken biryani',         kcal: 490, proteinG: 32, carbsG: 58,  fatG: 12.0),
  QuickFood(name: 'بيريانى لحم (طبق)',     nameEn: 'Beef biryani',            kcal: 540, proteinG: 36, carbsG: 58,  fatG: 16.0),
  QuickFood(name: 'كاري دجاج (طبق)',       nameEn: 'Chicken curry',           kcal: 320, proteinG: 28, carbsG: 12,  fatG: 18.0),
  QuickFood(name: 'كاري لحم (طبق)',        nameEn: 'Lamb curry',              kcal: 380, proteinG: 30, carbsG: 10,  fatG: 22.0),
  QuickFood(name: 'داهل عدس (طبق)',        nameEn: 'Dal lentils',             kcal: 220, proteinG: 12, carbsG: 32,  fatG: 5.0),
  QuickFood(name: 'سموسة دجاج (٢ حبة)',   nameEn: 'Chicken samosa (2)',      kcal: 280, proteinG: 12, carbsG: 26,  fatG: 14.0),
  QuickFood(name: 'نان (رغيف)',            nameEn: 'Naan bread',              kcal: 262, proteinG: 9,  carbsG: 45,  fatG: 5.0),
  QuickFood(name: 'رغيف باراثا',           nameEn: 'Paratha bread',           kcal: 300, proteinG: 7,  carbsG: 42,  fatG: 12.0),
  QuickFood(name: 'تشاباتي (رغيف)',        nameEn: 'Chapati',                 kcal: 120, proteinG: 4,  carbsG: 22,  fatG: 2.0),
  QuickFood(name: 'لسي مانجو (كوب)',       nameEn: 'Mango lassi',             kcal: 180, proteinG: 5,  carbsG: 32,  fatG: 4.0),
  QuickFood(name: 'خبز بوري (١ حبة)',      nameEn: 'Puri bread',              kcal: 145, proteinG: 3,  carbsG: 18,  fatG: 7.0),
  QuickFood(name: 'كفتة هندية (٢ قطعة)',  nameEn: 'Indian kofta (2)',        kcal: 290, proteinG: 22, carbsG: 8,   fatG: 18.0),
  QuickFood(name: 'بالاك باناير',          nameEn: 'Palak paneer',            kcal: 260, proteinG: 14, carbsG: 10,  fatG: 18.0),
  QuickFood(name: 'تكا دجاج (٣ قطع)',     nameEn: 'Chicken tikka (3pc)',     kcal: 220, proteinG: 30, carbsG: 4,   fatG: 9.0),
  QuickFood(name: 'تشاي حليب هندي',        nameEn: 'Masala chai',             kcal: 90,  proteinG: 3,  carbsG: 14,  fatG: 3.0),
  QuickFood(name: 'رز بسمتي (١ كوب)',     nameEn: 'Basmati rice (1 cup)',    kcal: 210, proteinG: 4,  carbsG: 46,  fatG: 0.5),
  QuickFood(name: 'كاري حمص (داهل)',       nameEn: 'Chickpea curry',          kcal: 240, proteinG: 10, carbsG: 34,  fatG: 8.0),
  QuickFood(name: 'حلوى قلاب جامون',      nameEn: 'Gulab jamun (2pc)',       kcal: 250, proteinG: 4,  carbsG: 38,  fatG: 9.0),
  QuickFood(name: 'خير حلوى أرز',         nameEn: 'Kheer rice pudding',      kcal: 200, proteinG: 6,  carbsG: 32,  fatG: 6.0),
  QuickFood(name: 'هاليم لحم (طبق)',       nameEn: 'Haleem (meat & lentils)', kcal: 350, proteinG: 28, carbsG: 28,  fatG: 12.0),
  QuickFood(name: 'نهاري لحم (طبق)',       nameEn: 'Nihari beef stew',        kcal: 420, proteinG: 34, carbsG: 14,  fatG: 24.0),
  QuickFood(name: 'تشولي بطاطس (طبق)',    nameEn: 'Aloo chana',              kcal: 230, proteinG: 9,  carbsG: 38,  fatG: 6.0),

  // ═══ INDONESIAN & MALAYSIAN HALAL ═══════════════════════════════
  QuickFood(name: 'ناسي غورنج (طبق)',      nameEn: 'Nasi goreng',             kcal: 440, proteinG: 14, carbsG: 68,  fatG: 14.0),
  QuickFood(name: 'ميي غورنج (طبق)',       nameEn: 'Mee goreng',              kcal: 420, proteinG: 12, carbsG: 64,  fatG: 14.0),
  QuickFood(name: 'ساتيه دجاج (٤ أسياخ)', nameEn: 'Chicken satay (4 skewers)',kcal:220, proteinG: 22, carbsG: 8,   fatG: 10.0),
  QuickFood(name: 'ريندانج لحم (١٠٠ج)',   nameEn: 'Beef rendang (100g)',     kcal: 195, proteinG: 20, carbsG: 4,   fatG: 11.0),
  QuickFood(name: 'لاكسا (كوب كبير)',     nameEn: 'Laksa soup',              kcal: 380, proteinG: 18, carbsG: 42,  fatG: 16.0),
  QuickFood(name: 'باكسو (كوب)',           nameEn: 'Bakso meatball soup',     kcal: 280, proteinG: 16, carbsG: 28,  fatG: 10.0),
  QuickFood(name: 'غادو غادو (طبق)',       nameEn: 'Gado gado salad',         kcal: 300, proteinG: 12, carbsG: 28,  fatG: 16.0),
  QuickFood(name: 'ناسي ليماك (طبق)',     nameEn: 'Nasi lemak',              kcal: 480, proteinG: 14, carbsG: 58,  fatG: 22.0),
  QuickFood(name: 'روتي كاناي',            nameEn: 'Roti canai',              kcal: 301, proteinG: 8,  carbsG: 42,  fatG: 12.0),
  QuickFood(name: 'تمبه (١٠٠ج)',          nameEn: 'Tempeh (100g)',           kcal: 193, proteinG: 19, carbsG: 8,   fatG: 11.0),
  QuickFood(name: 'توفو مقلي (١٠٠ج)',    nameEn: 'Fried tofu (100g)',       kcal: 175, proteinG: 11, carbsG: 4,   fatG: 13.0),
  QuickFood(name: 'سيوتو دجاج',           nameEn: 'Soto ayam chicken soup',  kcal: 230, proteinG: 18, carbsG: 18,  fatG: 8.0),
  QuickFood(name: 'إينداومي (كيس)',        nameEn: 'Indomie instant noodles', kcal: 350, proteinG: 8,  carbsG: 50,  fatG: 13.0),
  QuickFood(name: 'مارتاباك لحم',         nameEn: 'Martabak meat pancake',   kcal: 380, proteinG: 18, carbsG: 38,  fatG: 16.0),
  QuickFood(name: 'أيام بنيك (١٠٠ج)',    nameEn: 'Ayam bakar (grilled chicken)',kcal:165,proteinG:28, carbsG: 0,   fatG: 6.0),

  // ═══ FAMOUS RESTAURANT — McDONALD'S HALAL ═════════════════════
  QuickFood(name: 'ماكدونالدز: برجر دجاج حلال',   nameEn: "McDonald's McChicken",       kcal: 430, proteinG: 20, carbsG: 40, fatG: 20.0),
  QuickFood(name: 'ماكدونالدز: ماك كريسبي',        nameEn: "McDonald's McCrispy",         kcal: 530, proteinG: 28, carbsG: 50, fatG: 22.0),
  QuickFood(name: 'ماكدونالدز: فيلية-أو-فيش',     nameEn: "McDonald's Filet-O-Fish",     kcal: 390, proteinG: 16, carbsG: 39, fatG: 18.0),
  QuickFood(name: 'ماكدونالدز: بطاطس وسط',        nameEn: "McDonald's Medium Fries",     kcal: 320, proteinG: 4,  carbsG: 43, fatG: 15.0),
  QuickFood(name: 'ماكدونالدز: بطاطس كبير',       nameEn: "McDonald's Large Fries",      kcal: 445, proteinG: 6,  carbsG: 59, fatG: 21.0),
  QuickFood(name: 'ماكدونالدز: آبل باي',          nameEn: "McDonald's Apple Pie",        kcal: 240, proteinG: 3,  carbsG: 35, fatG: 11.0),
  QuickFood(name: 'ماكدونالدز: ماك فلوري',        nameEn: "McDonald's McFlurry Oreo",    kcal: 510, proteinG: 11, carbsG: 80, fatG: 17.0),
  QuickFood(name: 'ماكدونالدز: عصير برتقال',      nameEn: "McDonald's Orange Juice",     kcal: 140, proteinG: 2,  carbsG: 33, fatG: 0.0),
  QuickFood(name: 'ماكدونالدز: مشروب كوكا كولا وسط', nameEn: "McDonald's Medium Coke",  kcal: 210, proteinG: 0,  carbsG: 56, fatG: 0.0),
  QuickFood(name: 'ماكدونالدز: هاش براون',        nameEn: "McDonald's Hash Brown",       kcal: 150, proteinG: 1,  carbsG: 15, fatG: 9.0),
  QuickFood(name: 'ماكدونالدز: باني كيك إفطار',   nameEn: "McDonald's Hotcakes",         kcal: 580, proteinG: 13, carbsG: 98, fatG: 15.0),

  // ═══ FAMOUS RESTAURANT — KFC HALAL ══════════════════════════════
  QuickFood(name: 'كنتاكي: قطعة دجاج أصلية',    nameEn: 'KFC Original Chicken (1pc)',  kcal: 320, proteinG: 28, carbsG: 11, fatG: 19.0),
  QuickFood(name: 'كنتاكي: قطعة دجاج مقرمش',    nameEn: 'KFC Crispy Chicken (1pc)',    kcal: 400, proteinG: 30, carbsG: 18, fatG: 24.0),
  QuickFood(name: 'كنتاكي: زنجر برجر',           nameEn: 'KFC Zinger Burger',           kcal: 490, proteinG: 24, carbsG: 44, fatG: 22.0),
  QuickFood(name: 'كنتاكي: تواستر برجر',         nameEn: 'KFC Twister Wrap',            kcal: 480, proteinG: 22, carbsG: 48, fatG: 20.0),
  QuickFood(name: 'كنتاكي: بوبكورن دجاج (وسط)', nameEn: 'KFC Popcorn Chicken Medium',  kcal: 370, proteinG: 22, carbsG: 28, fatG: 18.0),
  QuickFood(name: 'كنتاكي: ماش بوتيتو',          nameEn: 'KFC Mashed Potatoes',         kcal: 130, proteinG: 2,  carbsG: 20, fatG: 5.0),
  QuickFood(name: 'كنتاكي: كول سلو',             nameEn: 'KFC Coleslaw',                kcal: 170, proteinG: 1,  carbsG: 22, fatG: 9.0),
  QuickFood(name: 'كنتاكي: وجبة باكت (٨ قطع)',  nameEn: 'KFC 8pc Bucket',             kcal:2560, proteinG:220, carbsG:88, fatG:152.0),
  QuickFood(name: 'كنتاكي: بسكويت',              nameEn: 'KFC Biscuit',                 kcal: 220, proteinG: 4,  carbsG: 26, fatG: 11.0),

  // ═══ FAMOUS RESTAURANT — SUBWAY HALAL ═══════════════════════════
  QuickFood(name: 'صب واي: ساندوتش دجاج تيريياكي', nameEn: 'Subway Chicken Teriyaki 6"',kcal: 350, proteinG: 24, carbsG: 46, fatG: 6.0),
  QuickFood(name: 'صب واي: ساندوتش تونا ٦ إنش',   nameEn: 'Subway Tuna 6"',            kcal: 480, proteinG: 20, carbsG: 44, fatG: 24.0),
  QuickFood(name: 'صب واي: ساندوتش فلافل',         nameEn: 'Subway Falafel 6"',          kcal: 380, proteinG: 14, carbsG: 56, fatG: 12.0),
  QuickFood(name: 'صب واي: كوكيز شوكولاتة',        nameEn: 'Subway Chocolate Cookie',    kcal: 210, proteinG: 2,  carbsG: 30, fatG: 10.0),

  // ═══ FAMOUS RESTAURANT — PIZZA HUT HALAL ════════════════════════
  QuickFood(name: 'بيتزا هت: بيتزا دجاج سوبريم (شريحة)', nameEn: 'Pizza Hut Chicken Supreme slice', kcal: 290, proteinG: 16, carbsG: 32, fatG: 10.0),
  QuickFood(name: 'بيتزا هت: بيتزا مارغريتا (شريحة)',   nameEn: 'Pizza Hut Margherita slice',      kcal: 240, proteinG: 11, carbsG: 30, fatG: 8.0),
  QuickFood(name: 'بيتزا هت: عيدان خبز بالثوم',        nameEn: 'Pizza Hut Garlic Bread Sticks',   kcal: 180, proteinG: 5,  carbsG: 28, fatG: 6.0),
  QuickFood(name: 'بيتزا هت: أجنحة دجاج (٤ قطع)',     nameEn: 'Pizza Hut Chicken Wings (4)',     kcal: 280, proteinG: 22, carbsG: 8,  fatG: 18.0),

  // ═══ FAMOUS RESTAURANT — BURGER KING HALAL ══════════════════════
  QuickFood(name: 'برجر كينج: وبر دجاج حلال',     nameEn: 'Burger King Chicken Whopper', kcal: 660, proteinG: 38, carbsG: 52, fatG: 32.0),
  QuickFood(name: 'برجر كينج: كريسبي دجاج',       nameEn: 'Burger King Crispy Chicken',  kcal: 520, proteinG: 28, carbsG: 46, fatG: 24.0),
  QuickFood(name: 'برجر كينج: أونيون رينجز (وسط)',nameEn: 'Burger King Onion Rings Med', kcal: 320, proteinG: 4,  carbsG: 38, fatG: 17.0),

  // ═══ FAMOUS RESTAURANT — HARDEE'S / CARL'S JR HALAL ═══════════
  QuickFood(name: 'هارديز: برجر دجاج مقرمش',    nameEn: "Hardee's Crispy Chicken",    kcal: 550, proteinG: 30, carbsG: 50, fatG: 24.0),
  QuickFood(name: 'هارديز: ثيك بيرجر دجاج',     nameEn: "Hardee's Thickburger Chicken",kcal:620, proteinG: 34, carbsG: 52, fatG: 28.0),

  // ═══ FAMOUS RESTAURANT — POPEYES HALAL ══════════════════════════
  QuickFood(name: 'بوبايز: دجاج مقرمش (قطعة)',  nameEn: "Popeyes Spicy Chicken (1pc)", kcal: 360, proteinG: 22, carbsG: 17, fatG: 22.0),
  QuickFood(name: 'بوبايز: بسكويت',              nameEn: "Popeyes Biscuit",             kcal: 260, proteinG: 4,  carbsG: 26, fatG: 15.0),
  QuickFood(name: 'بوبايز: ساندوتش دجاج',        nameEn: "Popeyes Chicken Sandwich",    kcal: 700, proteinG: 28, carbsG: 50, fatG: 42.0),

  // ═══ FAMOUS RESTAURANT — STARBUCKS HALAL ════════════════════════
  QuickFood(name: 'ستاربكس: لاتيه وسط',         nameEn: 'Starbucks Latte (Grande)',    kcal: 190, proteinG: 11, carbsG: 19, fatG: 7.0),
  QuickFood(name: 'ستاربكس: كابوتشينو وسط',     nameEn: 'Starbucks Cappuccino Grande', kcal: 120, proteinG: 7,  carbsG: 12, fatG: 4.0),
  QuickFood(name: 'ستاربكس: موكا فراباتشينو',    nameEn: 'Starbucks Mocha Frappuccino', kcal: 380, proteinG: 5,  carbsG: 61, fatG: 13.0),
  QuickFood(name: 'ستاربكس: كيكة شوكولاتة',     nameEn: 'Starbucks Chocolate Cake',    kcal: 380, proteinG: 6,  carbsG: 50, fatG: 18.0),
  QuickFood(name: 'ستاربكس: كروسان',             nameEn: 'Starbucks Croissant',         kcal: 260, proteinG: 5,  carbsG: 29, fatG: 14.0),

  // ═══ FAMOUS RESTAURANT — SHAWARMA CHAINS ════════════════════════
  QuickFood(name: 'شاورمر: شاورما دجاج (ساندوتش)', nameEn: 'Shawarmer Chicken Sandwich', kcal: 480, proteinG: 32, carbsG: 44, fatG: 18.0),
  QuickFood(name: 'أسياخ: مشوى دجاج (طبق)',      nameEn: 'Grilled chicken plate',       kcal: 520, proteinG: 42, carbsG: 48, fatG: 14.0),
  QuickFood(name: 'كبسة روف (طبق)',               nameEn: 'Kabsa Roof restaurant',       kcal: 680, proteinG: 44, carbsG: 72, fatG: 18.0),

  // ═══ COFFEE & BAKERY ════════════════════════════════════════════
  QuickFood(name: 'كروسان زبدة',                  nameEn: 'Butter croissant',            kcal: 272, proteinG: 5,  carbsG: 31, fatG: 14.0),
  QuickFood(name: 'دونات سكر (حبة)',              nameEn: 'Glazed donut',                kcal: 250, proteinG: 4,  carbsG: 34, fatG: 12.0),
  QuickFood(name: 'مافن بلوبيري',                 nameEn: 'Blueberry muffin',            kcal: 340, proteinG: 5,  carbsG: 48, fatG: 14.0),
  QuickFood(name: 'باغيل سادة',                   nameEn: 'Plain bagel',                 kcal: 270, proteinG: 10, carbsG: 53, fatG: 2.0),
  QuickFood(name: 'وافل (قطعة)',                  nameEn: 'Waffle',                      kcal: 218, proteinG: 6,  carbsG: 25, fatG: 11.0),
  QuickFood(name: 'فطيرة تفاح (شريحة)',           nameEn: 'Apple pie slice',             kcal: 296, proteinG: 2,  carbsG: 43, fatG: 14.0),

  // ═══ DEEPER EGYPTIAN STAPLES ════════════════════════════════════
  QuickFood(name: 'فتة بالكفتة',              nameEn: 'Kofta fattah',           kcal: 580, proteinG: 34, carbsG: 58,  fatG: 20.0),
  QuickFood(name: 'طاجن فراخ بالخضار',        nameEn: 'Chicken tagine',          kcal: 290, proteinG: 28, carbsG: 16,  fatG: 12.0),
  QuickFood(name: 'حمام محشي بالأرز',         nameEn: 'Stuffed pigeon with rice', kcal: 380, proteinG: 30, carbsG: 28,  fatG: 16.0),
  QuickFood(name: 'إسكالوب دجاج',             nameEn: 'Chicken escalope',        kcal: 340, proteinG: 28, carbsG: 18,  fatG: 16.0),
  QuickFood(name: 'بيف سيتيه (وجبة)',         nameEn: 'Beef hawawshi',           kcal: 520, proteinG: 26, carbsG: 44,  fatG: 24.0),
  QuickFood(name: 'هواوشي لحم (فينو)',        nameEn: 'Beef hawawshi sandwich',  kcal: 480, proteinG: 24, carbsG: 42,  fatG: 22.0),
  QuickFood(name: 'فراخ بانيه (٢ قطعة)',      nameEn: 'Breaded chicken (2pc)',   kcal: 360, proteinG: 26, carbsG: 22,  fatG: 18.0),
  QuickFood(name: 'روستو لحم بتلو (١٠٠ج)',   nameEn: 'Veal roast (100g)',       kcal: 185, proteinG: 28, carbsG: 0,   fatG: 8.0),
  QuickFood(name: 'سبانخ بالمرق (طبق)',       nameEn: 'Spinach in broth',        kcal: 120, proteinG: 8,  carbsG: 10,  fatG: 5.0),
  QuickFood(name: 'مسقعة بالبيض',             nameEn: 'Moussaka with eggs',      kcal: 260, proteinG: 12, carbsG: 18,  fatG: 16.0),
  QuickFood(name: 'طاجن سمك (طبق)',           nameEn: 'Fish tagine',             kcal: 220, proteinG: 24, carbsG: 10,  fatG: 8.0),
  QuickFood(name: 'سمبوسك لحم (٣ حبات)',     nameEn: 'Meat sambousek (3)',       kcal: 280, proteinG: 14, carbsG: 24,  fatG: 14.0),
  QuickFood(name: 'رقاق بالجبنة (٢ رقاقة)',  nameEn: 'Cheese rakak (2)',        kcal: 320, proteinG: 12, carbsG: 30,  fatG: 16.0),
  QuickFood(name: 'عيش فينو بالجبنة والطماطم', nameEn: 'Fino with cheese & tomato', kcal: 350, proteinG: 12, carbsG: 44, fatG: 12.0),
  QuickFood(name: 'بيض بالبسطرمة والجبنة',   nameEn: 'Eggs with pastrami & cheese', kcal: 280, proteinG: 20, carbsG: 2, fatG: 20.0),
  QuickFood(name: 'كبدة إسكندراني (طبق)',    nameEn: 'Alexandrian liver',       kcal: 240, proteinG: 24, carbsG: 8,   fatG: 12.0),

  // ═══ DEEPER GULF & LEVANTINE ════════════════════════════════════
  QuickFood(name: 'أرز لحم بالكمون',          nameEn: 'Spiced lamb rice',        kcal: 560, proteinG: 34, carbsG: 64,  fatG: 16.0),
  QuickFood(name: 'مفطح دجاج (طبق)',          nameEn: 'Muffatah chicken',        kcal: 520, proteinG: 36, carbsG: 58,  fatG: 14.0),
  QuickFood(name: 'سليق دجاج (طبق)',          nameEn: 'Chicken saleeg',          kcal: 480, proteinG: 32, carbsG: 56,  fatG: 12.0),
  QuickFood(name: 'دجاج مشوي بالليمون',       nameEn: 'Lemon grilled chicken',   kcal: 280, proteinG: 36, carbsG: 4,   fatG: 12.0),
  QuickFood(name: 'مشاوي مشكلة (طبق)',        nameEn: 'Mixed grill plate',       kcal: 620, proteinG: 52, carbsG: 8,   fatG: 40.0),
  QuickFood(name: 'خروف مشوي كامل (١٠٠ج)',   nameEn: 'Whole roasted lamb',      kcal: 280, proteinG: 26, carbsG: 0,   fatG: 18.0),
  QuickFood(name: 'تبسي باذنجان (طبق)',       nameEn: 'Eggplant tabsi',          kcal: 180, proteinG: 6,  carbsG: 18,  fatG: 10.0),
  QuickFood(name: 'مقلوبة دجاج (طبق)',        nameEn: 'Chicken maqlouba',        kcal: 540, proteinG: 34, carbsG: 64,  fatG: 14.0),
  QuickFood(name: 'مقلوبة لحم (طبق)',         nameEn: 'Meat maqlouba',           kcal: 580, proteinG: 36, carbsG: 64,  fatG: 18.0),
  QuickFood(name: 'كنافة نابلسية (١٠٠ج)',    nameEn: 'Nablus kunafa (100g)',    kcal: 360, proteinG: 10, carbsG: 48,  fatG: 16.0),
  QuickFood(name: 'قطايف بالقشطة (٢ حبة)',   nameEn: 'Qatayef with cream (2)', kcal: 280, proteinG: 6,  carbsG: 38,  fatG: 12.0),
  QuickFood(name: 'مناقيش زعتر (رغيف)',      nameEn: 'Zaatar manaqeesh',       kcal: 240, proteinG: 6,  carbsG: 36,  fatG: 8.0),
  QuickFood(name: 'مناقيش جبنة (رغيف)',      nameEn: 'Cheese manaqeesh',        kcal: 320, proteinG: 12, carbsG: 36,  fatG: 14.0),

  // ═══ DEEPER SUNNAH FOODS ════════════════════════════════════════
  QuickFood(name: 'ثريد تمر ولبن',            nameEn: 'Thareed with dates & milk', kcal: 380, proteinG: 12, carbsG: 62, fatG: 8.0),
  QuickFood(name: 'حلبة (كوب)',               nameEn: 'Fenugreek drink (cup)',    kcal: 36,  proteinG: 3,  carbsG: 6,   fatG: 1.0),
  QuickFood(name: 'مرق لحم بالخضار',          nameEn: 'Lamb broth with veg',     kcal: 120, proteinG: 10, carbsG: 8,   fatG: 4.0),
  QuickFood(name: 'خل التفاح مع الماء',       nameEn: 'Apple cider vinegar water',kcal: 6,  proteinG: 0,  carbsG: 1,   fatG: 0.0),
  QuickFood(name: 'قرفة مع عسل (كوب)',        nameEn: 'Cinnamon honey drink',    kcal: 70,  proteinG: 0,  carbsG: 18,  fatG: 0.0),
  QuickFood(name: 'زيت الزيتون البكر (م.ك)',  nameEn: 'Extra virgin olive oil (1tbsp)',kcal:119, proteinG:0, carbsG:0, fatG:14.0),
  QuickFood(name: 'ثوم نيء (فص)',             nameEn: 'Raw garlic (1 clove)',     kcal: 4,   proteinG: 0.2,carbsG: 1,   fatG: 0.0),
  QuickFood(name: 'زنجبيل طازج (١ م.ص)',     nameEn: 'Fresh ginger (1 tsp)',     kcal: 2,   proteinG: 0,  carbsG: 0.5, fatG: 0.0),
  QuickFood(name: 'كركم (١ م.ص)',             nameEn: 'Turmeric (1 tsp)',         kcal: 8,   proteinG: 0.2,carbsG: 1.5, fatG: 0.0),
  QuickFood(name: 'تين مجفف (٣ حبات)',        nameEn: 'Dried figs (3)',           kcal: 111, proteinG: 1,  carbsG: 29,  fatG: 0.4),
  QuickFood(name: 'مشمش مجفف (٥ حبات)',      nameEn: 'Dried apricots (5)',       kcal: 78,  proteinG: 1,  carbsG: 20,  fatG: 0.1),
  QuickFood(name: 'زبيب (٣٠ج)',              nameEn: 'Raisins (30g)',            kcal: 90,  proteinG: 1,  carbsG: 24,  fatG: 0.1),

  // ═══ SOUPS & LIGHT MEALS ════════════════════════════════════════
  QuickFood(name: 'شوربة عدس أحمر (كوب)',    nameEn: 'Red lentil soup (cup)',    kcal: 160, proteinG: 10, carbsG: 28,  fatG: 2.0),
  QuickFood(name: 'شوربة خضار (كوب)',         nameEn: 'Vegetable soup (cup)',     kcal: 80,  proteinG: 3,  carbsG: 14,  fatG: 1.0),
  QuickFood(name: 'شوربة دجاج بالشعير',      nameEn: 'Chicken barley soup',      kcal: 200, proteinG: 14, carbsG: 26,  fatG: 4.0),
  QuickFood(name: 'شوربة الفطر (كوب)',        nameEn: 'Mushroom soup (cup)',      kcal: 100, proteinG: 3,  carbsG: 12,  fatG: 4.0),
  QuickFood(name: 'شوربة بصل (كوب)',          nameEn: 'Onion soup (cup)',         kcal: 90,  proteinG: 3,  carbsG: 14,  fatG: 2.0),
  QuickFood(name: 'شوربة طماطم حمراء (كوب)', nameEn: 'Tomato soup (cup)',        kcal: 90,  proteinG: 3,  carbsG: 16,  fatG: 2.0),
  QuickFood(name: 'شوربة بروكلي (كوب)',       nameEn: 'Broccoli soup (cup)',      kcal: 100, proteinG: 4,  carbsG: 12,  fatG: 4.0),

  // ═══ HEALTHY & FITNESS FOODS ════════════════════════════════════
  QuickFood(name: 'صدر دجاج مسلوق (١٥٠ج)',  nameEn: 'Boiled chicken breast',   kcal: 248, proteinG: 46, carbsG: 0,   fatG: 5.0),
  QuickFood(name: 'تونة بالماء (علبة ١٨٠ج)',nameEn: 'Tuna in water (180g can)',kcal: 180, proteinG: 40, carbsG: 0,   fatG: 2.0),
  QuickFood(name: 'بياض البيض (٣ بيضات)',    nameEn: 'Egg whites (3)',           kcal: 51,  proteinG: 11, carbsG: 1,   fatG: 0.2),
  QuickFood(name: 'زبادي يوناني صفر دسم',    nameEn: 'Non-fat Greek yogurt',    kcal: 100, proteinG: 17, carbsG: 6,   fatG: 0.0),
  QuickFood(name: 'شوفان ١٠٠ج نيء',         nameEn: 'Raw oats (100g)',          kcal: 389, proteinG: 17, carbsG: 66,  fatG: 7.0),
  QuickFood(name: 'موز (حبة متوسطة)',         nameEn: 'Banana (medium)',          kcal: 105, proteinG: 1,  carbsG: 27,  fatG: 0.3),
  QuickFood(name: 'تفاحة (حبة متوسطة)',       nameEn: 'Apple (medium)',           kcal: 95,  proteinG: 0.5,carbsG: 25,  fatG: 0.3),
  QuickFood(name: 'بطيخ (١ شريحة ٣٠٠ج)',    nameEn: 'Watermelon (300g)',        kcal: 90,  proteinG: 2,  carbsG: 22,  fatG: 0.5),
  QuickFood(name: 'عصير خضار أخضر',          nameEn: 'Green vegetable juice',    kcal: 60,  proteinG: 2,  carbsG: 12,  fatG: 0.5),
  QuickFood(name: 'بروتين بار (بار واحد)',   nameEn: 'Protein bar (1 bar)',      kcal: 200, proteinG: 20, carbsG: 22,  fatG: 6.0),
  QuickFood(name: 'مكسرات مشكلة (٣٠ج)',     nameEn: 'Mixed nuts (30g)',         kcal: 185, proteinG: 5,  carbsG: 7,   fatG: 16.0),
  QuickFood(name: 'جوز (٧ حبات)',            nameEn: 'Walnuts (7 halves)',       kcal: 185, proteinG: 4,  carbsG: 4,   fatG: 18.0),
  QuickFood(name: 'لوز (٢٣ حبة)',            nameEn: 'Almonds (23)',             kcal: 164, proteinG: 6,  carbsG: 6,   fatG: 14.0),

  // ═══ BREAKFAST FOODS ════════════════════════════════════════════
  QuickFood(name: 'بيض عيون (٢ بيضة)',       nameEn: 'Fried eggs (2)',           kcal: 185, proteinG: 12, carbsG: 1,   fatG: 14.0),
  QuickFood(name: 'فطور إنجليزي كامل',        nameEn: 'Full English breakfast',   kcal: 760, proteinG: 40, carbsG: 32,  fatG: 48.0),
  QuickFood(name: 'شوفان بالحليب (كوب)',      nameEn: 'Oatmeal with milk (cup)',  kcal: 250, proteinG: 10, carbsG: 36,  fatG: 7.0),
  QuickFood(name: 'فلاح فطور (طبق مصري)',    nameEn: 'Fallah breakfast plate',   kcal: 520, proteinG: 22, carbsG: 62,  fatG: 18.0),
  QuickFood(name: 'فول بزيت وليمون',          nameEn: 'Foul with oil & lemon',   kcal: 200, proteinG: 10, carbsG: 28,  fatG: 7.0),
  QuickFood(name: 'عجة فيتة (٢ بيضة)',       nameEn: 'Feta omelette (2 eggs)',   kcal: 240, proteinG: 16, carbsG: 2,   fatG: 18.0),
  QuickFood(name: 'بانكيك (٣ قطع)',           nameEn: 'Pancakes (3)',             kcal: 360, proteinG: 8,  carbsG: 56,  fatG: 10.0),
  QuickFood(name: 'توست فرنسي (٢ شريحة)',    nameEn: 'French toast (2 slices)',  kcal: 280, proteinG: 8,  carbsG: 36,  fatG: 11.0),
  QuickFood(name: 'موسلي بالزبادي (كوب)',    nameEn: 'Muesli with yogurt',       kcal: 320, proteinG: 12, carbsG: 48,  fatG: 8.0),
  QuickFood(name: 'أكل الحبوب مع حليب (كوب)',nameEn: 'Cereal with milk (cup)',   kcal: 240, proteinG: 8,  carbsG: 44,  fatG: 4.0),

  // ═══ SNACKS & STREET FOOD ═══════════════════════════════════════
  QuickFood(name: 'ذرة مشوية بالزبدة',       nameEn: 'Grilled corn with butter', kcal: 180, proteinG: 4,  carbsG: 30,  fatG: 6.0),
  QuickFood(name: 'بطاطا مشوية بالزعتر',     nameEn: 'Roasted potatoes zaatar', kcal: 200, proteinG: 4,  carbsG: 38,  fatG: 4.0),
  QuickFood(name: 'بطاطس شيبس محلي (كيس)',  nameEn: 'Local potato chips (bag)',  kcal: 150, proteinG: 2,  carbsG: 18,  fatG: 8.0),
  QuickFood(name: 'فشار (كوب)',               nameEn: 'Popcorn (cup)',             kcal: 55,  proteinG: 1,  carbsG: 11,  fatG: 1.0),
  QuickFood(name: 'فشار بالزبدة (كوب)',      nameEn: 'Buttered popcorn (cup)',   kcal: 90,  proteinG: 1,  carbsG: 10,  fatG: 5.0),
  QuickFood(name: 'ترمس (١٠٠ج)',             nameEn: 'Lupin beans (100g)',        kcal: 370, proteinG: 36, carbsG: 40,  fatG: 10.0),
  QuickFood(name: 'سوبيا (كوب)',              nameEn: 'Sobia drink (cup)',         kcal: 120, proteinG: 2,  carbsG: 28,  fatG: 1.0),
  QuickFood(name: 'بليلة قمح (كوب)',         nameEn: 'Wheat baleela (cup)',       kcal: 280, proteinG: 8,  carbsG: 56,  fatG: 2.0),
  QuickFood(name: 'حمص محمص (٣٠ج)',         nameEn: 'Roasted chickpeas (30g)',  kcal: 120, proteinG: 6,  carbsG: 18,  fatG: 3.0),
  QuickFood(name: 'بسبوسة تمر (قطعة)',       nameEn: 'Date basbousa',            kcal: 200, proteinG: 3,  carbsG: 36,  fatG: 6.0),
  QuickFood(name: 'حلاوة طحينية (٣٠ج)',     nameEn: 'Tahini halva (30g)',       kcal: 155, proteinG: 4,  carbsG: 18,  fatG: 8.0),
  QuickFood(name: 'كعك بالسمسم (حبة)',       nameEn: 'Sesame ring cookie',       kcal: 90,  proteinG: 2,  carbsG: 12,  fatG: 4.0),

  // ═══ DRINKS & BEVERAGES ═════════════════════════════════════════
  QuickFood(name: 'عصير برتقال طبيعي (٢٥٠مل)', nameEn: 'Fresh orange juice 250ml', kcal: 112, proteinG: 2, carbsG: 26, fatG: 0.5),
  QuickFood(name: 'عصير مانجو طازج (٢٥٠مل)', nameEn: 'Fresh mango juice 250ml',  kcal: 130, proteinG: 1,  carbsG: 32,  fatG: 0.4),
  QuickFood(name: 'عصير جزر وتفاح',           nameEn: 'Carrot apple juice',       kcal: 90,  proteinG: 1,  carbsG: 22,  fatG: 0.3),
  QuickFood(name: 'ماء جوز الهند (٢٥٠مل)',   nameEn: 'Coconut water 250ml',      kcal: 46,  proteinG: 2,  carbsG: 9,   fatG: 0.5),
  QuickFood(name: 'حليب لوز (٢٠٠مل)',        nameEn: 'Almond milk 200ml',        kcal: 60,  proteinG: 1,  carbsG: 8,   fatG: 3.0),
  QuickFood(name: 'حليب كامل الدسم (٢٠٠مل)', nameEn: 'Whole milk 200ml',        kcal: 122, proteinG: 6,  carbsG: 9,   fatG: 7.0),
  QuickFood(name: 'شاي أسود بدون سكر',        nameEn: 'Black tea no sugar',       kcal: 2,   proteinG: 0,  carbsG: 0.5, fatG: 0.0),
  QuickFood(name: 'شاي أسود بسكر وحليب',     nameEn: 'Tea with milk & sugar',    kcal: 55,  proteinG: 1,  carbsG: 10,  fatG: 1.0),
  QuickFood(name: 'عرق سوس بارد (كوب)',      nameEn: 'Licorice drink cold',      kcal: 45,  proteinG: 0,  carbsG: 11,  fatG: 0.0),
  QuickFood(name: 'مشروب طاقة حلال (علبة)', nameEn: 'Halal energy drink (can)', kcal: 110, proteinG: 0,  carbsG: 28,  fatG: 0.0),
  QuickFood(name: 'ماء عادي (٢٥٠مل)',        nameEn: 'Water (250ml)',             kcal: 0,   proteinG: 0,  carbsG: 0,   fatG: 0.0),
  QuickFood(name: 'ماء بفوز (علبة)',          nameEn: 'Sparkling water (can)',     kcal: 0,   proteinG: 0,  carbsG: 0,   fatG: 0.0),

  // ═══ RAMADAN SPECIAL FOODS ══════════════════════════════════════
  QuickFood(name: 'حساء حريرة رمضان',        nameEn: 'Ramadan harira soup',      kcal: 200, proteinG: 12, carbsG: 28,  fatG: 5.0),
  QuickFood(name: 'قطايف محشية بالجوز (٢)', nameEn: 'Qatayef with walnuts (2)', kcal: 320, proteinG: 6,  carbsG: 44,  fatG: 14.0),
  QuickFood(name: 'تمر بالطحينة (٣ حبات)',  nameEn: 'Dates with tahini (3)',    kcal: 120, proteinG: 2,  carbsG: 20,  fatG: 4.0),
  QuickFood(name: 'إفطار رمضاني كامل',       nameEn: 'Full Ramadan iftar plate', kcal: 800, proteinG: 38, carbsG: 96,  fatG: 24.0),
  QuickFood(name: 'شربات رمضان (كوب)',       nameEn: 'Ramadan sherbet (cup)',     kcal: 120, proteinG: 0,  carbsG: 30,  fatG: 0.0),
  QuickFood(name: 'صمون رمضاني (رغيف)',     nameEn: 'Ramadan bread loaf',       kcal: 320, proteinG: 10, carbsG: 64,  fatG: 4.0),
  QuickFood(name: 'كنافة رمضان بالقشطة',    nameEn: 'Ramadan kunafa with cream',kcal: 420, proteinG: 8,  carbsG: 58,  fatG: 18.0),
  QuickFood(name: 'زلابية (٥ حبات)',         nameEn: 'Zalabia fritters (5)',     kcal: 300, proteinG: 4,  carbsG: 42,  fatG: 13.0),
  QuickFood(name: 'بريوات باللوز (٣ حبات)', nameEn: 'Almond briouat (3)',       kcal: 280, proteinG: 5,  carbsG: 30,  fatG: 16.0),

  // ═══ CONDIMENTS & SAUCES ════════════════════════════════════════
  QuickFood(name: 'طحينة (٢ م.ك)',           nameEn: 'Tahini (2 tbsp)',           kcal: 178, proteinG: 6,  carbsG: 6,   fatG: 16.0),
  QuickFood(name: 'صلصة طرطور (٢ م.ك)',     nameEn: 'Tartour sauce (2 tbsp)',   kcal: 100, proteinG: 2,  carbsG: 4,   fatG: 9.0),
  QuickFood(name: 'مربى مشمش (١ م.ك)',       nameEn: 'Apricot jam (1 tbsp)',     kcal: 48,  proteinG: 0,  carbsG: 13,  fatG: 0.0),
  QuickFood(name: 'عسل طبيعي (١ م.ك)',       nameEn: 'Natural honey (1 tbsp)',   kcal: 64,  proteinG: 0,  carbsG: 17,  fatG: 0.0),
  QuickFood(name: 'كاتشب (١ م.ك)',           nameEn: 'Ketchup (1 tbsp)',         kcal: 20,  proteinG: 0,  carbsG: 5,   fatG: 0.0),
  QuickFood(name: 'مايونيز حلال (١ م.ك)',   nameEn: 'Halal mayo (1 tbsp)',      kcal: 90,  proteinG: 0,  carbsG: 1,   fatG: 10.0),
  QuickFood(name: 'صلصة تاكو حلال (١ م.ك)',nameEn: 'Halal taco sauce (1 tbsp)',kcal: 15,  proteinG: 0,  carbsG: 3,   fatG: 0.0),
  QuickFood(name: 'ثومية (١ م.ك)',           nameEn: 'Toum garlic sauce (1 tbsp)',kcal: 90, proteinG: 0,  carbsG: 2,   fatG: 9.0),

  // ═══ PAKISTANI & INDIAN HALAL ═══════════════════════════════════
  QuickFood(name: 'بيريانى دجاج (طبق)',    nameEn: 'Chicken biryani',         kcal: 490, proteinG: 32, carbsG: 58,  fatG: 12.0),
  QuickFood(name: 'بيريانى لحم (طبق)',     nameEn: 'Beef biryani',            kcal: 540, proteinG: 36, carbsG: 58,  fatG: 16.0),
  QuickFood(name: 'كاري دجاج (طبق)',       nameEn: 'Chicken curry',           kcal: 320, proteinG: 28, carbsG: 12,  fatG: 18.0),
  QuickFood(name: 'كاري لحم (طبق)',        nameEn: 'Lamb curry',              kcal: 380, proteinG: 30, carbsG: 10,  fatG: 22.0),
  QuickFood(name: 'داهل عدس (طبق)',        nameEn: 'Dal lentils',             kcal: 220, proteinG: 12, carbsG: 32,  fatG: 5.0),
  QuickFood(name: 'سموسة دجاج (٢ حبة)',   nameEn: 'Chicken samosa (2)',      kcal: 280, proteinG: 12, carbsG: 26,  fatG: 14.0),
  QuickFood(name: 'نان (رغيف)',            nameEn: 'Naan bread',              kcal: 262, proteinG: 9,  carbsG: 45,  fatG: 5.0),
  QuickFood(name: 'رغيف باراثا',           nameEn: 'Paratha bread',           kcal: 300, proteinG: 7,  carbsG: 42,  fatG: 12.0),
  QuickFood(name: 'تشاباتي (رغيف)',        nameEn: 'Chapati',                 kcal: 120, proteinG: 4,  carbsG: 22,  fatG: 2.0),
  QuickFood(name: 'لسي مانجو (كوب)',       nameEn: 'Mango lassi',             kcal: 180, proteinG: 5,  carbsG: 32,  fatG: 4.0),
  QuickFood(name: 'خبز بوري (١ حبة)',      nameEn: 'Puri bread',              kcal: 145, proteinG: 3,  carbsG: 18,  fatG: 7.0),
  QuickFood(name: 'كفتة هندية (٢ قطعة)',  nameEn: 'Indian kofta (2)',        kcal: 290, proteinG: 22, carbsG: 8,   fatG: 18.0),
  QuickFood(name: 'بالاك باناير',          nameEn: 'Palak paneer',            kcal: 260, proteinG: 14, carbsG: 10,  fatG: 18.0),
  QuickFood(name: 'تكا دجاج (٣ قطع)',     nameEn: 'Chicken tikka (3pc)',     kcal: 220, proteinG: 30, carbsG: 4,   fatG: 9.0),
  QuickFood(name: 'تشاي حليب هندي',        nameEn: 'Masala chai',             kcal: 90,  proteinG: 3,  carbsG: 14,  fatG: 3.0),
  QuickFood(name: 'رز بسمتي (١ كوب)',     nameEn: 'Basmati rice (1 cup)',    kcal: 210, proteinG: 4,  carbsG: 46,  fatG: 0.5),
  QuickFood(name: 'كاري حمص (داهل)',       nameEn: 'Chickpea curry',          kcal: 240, proteinG: 10, carbsG: 34,  fatG: 8.0),
  QuickFood(name: 'حلوى قلاب جامون',      nameEn: 'Gulab jamun (2pc)',       kcal: 250, proteinG: 4,  carbsG: 38,  fatG: 9.0),
  QuickFood(name: 'خير حلوى أرز',         nameEn: 'Kheer rice pudding',      kcal: 200, proteinG: 6,  carbsG: 32,  fatG: 6.0),
  QuickFood(name: 'هاليم لحم (طبق)',       nameEn: 'Haleem (meat & lentils)', kcal: 350, proteinG: 28, carbsG: 28,  fatG: 12.0),
  QuickFood(name: 'نهاري لحم (طبق)',       nameEn: 'Nihari beef stew',        kcal: 420, proteinG: 34, carbsG: 14,  fatG: 24.0),
  QuickFood(name: 'تشولي بطاطس (طبق)',    nameEn: 'Aloo chana',              kcal: 230, proteinG: 9,  carbsG: 38,  fatG: 6.0),

  // ═══ INDONESIAN & MALAYSIAN HALAL ═══════════════════════════════
  QuickFood(name: 'ناسي غورنج (طبق)',      nameEn: 'Nasi goreng',             kcal: 440, proteinG: 14, carbsG: 68,  fatG: 14.0),
  QuickFood(name: 'ميي غورنج (طبق)',       nameEn: 'Mee goreng',              kcal: 420, proteinG: 12, carbsG: 64,  fatG: 14.0),
  QuickFood(name: 'ساتيه دجاج (٤ أسياخ)', nameEn: 'Chicken satay (4 skewers)',kcal:220, proteinG: 22, carbsG: 8,   fatG: 10.0),
  QuickFood(name: 'ريندانج لحم (١٠٠ج)',   nameEn: 'Beef rendang (100g)',     kcal: 195, proteinG: 20, carbsG: 4,   fatG: 11.0),
  QuickFood(name: 'لاكسا (كوب كبير)',     nameEn: 'Laksa soup',              kcal: 380, proteinG: 18, carbsG: 42,  fatG: 16.0),
  QuickFood(name: 'باكسو (كوب)',           nameEn: 'Bakso meatball soup',     kcal: 280, proteinG: 16, carbsG: 28,  fatG: 10.0),
  QuickFood(name: 'غادو غادو (طبق)',       nameEn: 'Gado gado salad',         kcal: 300, proteinG: 12, carbsG: 28,  fatG: 16.0),
  QuickFood(name: 'ناسي ليماك (طبق)',     nameEn: 'Nasi lemak',              kcal: 480, proteinG: 14, carbsG: 58,  fatG: 22.0),
  QuickFood(name: 'روتي كاناي',            nameEn: 'Roti canai',              kcal: 301, proteinG: 8,  carbsG: 42,  fatG: 12.0),
  QuickFood(name: 'تمبه (١٠٠ج)',          nameEn: 'Tempeh (100g)',           kcal: 193, proteinG: 19, carbsG: 8,   fatG: 11.0),
  QuickFood(name: 'توفو مقلي (١٠٠ج)',    nameEn: 'Fried tofu (100g)',       kcal: 175, proteinG: 11, carbsG: 4,   fatG: 13.0),
  QuickFood(name: 'سيوتو دجاج',           nameEn: 'Soto ayam chicken soup',  kcal: 230, proteinG: 18, carbsG: 18,  fatG: 8.0),
  QuickFood(name: 'إينداومي (كيس)',        nameEn: 'Indomie instant noodles', kcal: 350, proteinG: 8,  carbsG: 50,  fatG: 13.0),
  QuickFood(name: 'مارتاباك لحم',         nameEn: 'Martabak meat pancake',   kcal: 380, proteinG: 18, carbsG: 38,  fatG: 16.0),
  QuickFood(name: 'أيام بنيك (١٠٠ج)',    nameEn: 'Ayam bakar (grilled chicken)',kcal:165,proteinG:28, carbsG: 0,   fatG: 6.0),

  // ═══ FAMOUS RESTAURANT — McDONALD'S HALAL ═════════════════════
  QuickFood(name: 'ماكدونالدز: برجر دجاج حلال',   nameEn: "McDonald's McChicken",       kcal: 430, proteinG: 20, carbsG: 40, fatG: 20.0),
  QuickFood(name: 'ماكدونالدز: ماك كريسبي',        nameEn: "McDonald's McCrispy",         kcal: 530, proteinG: 28, carbsG: 50, fatG: 22.0),
  QuickFood(name: 'ماكدونالدز: فيلية-أو-فيش',     nameEn: "McDonald's Filet-O-Fish",     kcal: 390, proteinG: 16, carbsG: 39, fatG: 18.0),
  QuickFood(name: 'ماكدونالدز: بطاطس وسط',        nameEn: "McDonald's Medium Fries",     kcal: 320, proteinG: 4,  carbsG: 43, fatG: 15.0),
  QuickFood(name: 'ماكدونالدز: بطاطس كبير',       nameEn: "McDonald's Large Fries",      kcal: 445, proteinG: 6,  carbsG: 59, fatG: 21.0),
  QuickFood(name: 'ماكدونالدز: آبل باي',          nameEn: "McDonald's Apple Pie",        kcal: 240, proteinG: 3,  carbsG: 35, fatG: 11.0),
  QuickFood(name: 'ماكدونالدز: ماك فلوري',        nameEn: "McDonald's McFlurry Oreo",    kcal: 510, proteinG: 11, carbsG: 80, fatG: 17.0),
  QuickFood(name: 'ماكدونالدز: عصير برتقال',      nameEn: "McDonald's Orange Juice",     kcal: 140, proteinG: 2,  carbsG: 33, fatG: 0.0),
  QuickFood(name: 'ماكدونالدز: مشروب كوكا كولا وسط', nameEn: "McDonald's Medium Coke",  kcal: 210, proteinG: 0,  carbsG: 56, fatG: 0.0),
  QuickFood(name: 'ماكدونالدز: هاش براون',        nameEn: "McDonald's Hash Brown",       kcal: 150, proteinG: 1,  carbsG: 15, fatG: 9.0),
  QuickFood(name: 'ماكدونالدز: باني كيك إفطار',   nameEn: "McDonald's Hotcakes",         kcal: 580, proteinG: 13, carbsG: 98, fatG: 15.0),

  // ═══ FAMOUS RESTAURANT — KFC HALAL ══════════════════════════════
  QuickFood(name: 'كنتاكي: قطعة دجاج أصلية',    nameEn: 'KFC Original Chicken (1pc)',  kcal: 320, proteinG: 28, carbsG: 11, fatG: 19.0),
  QuickFood(name: 'كنتاكي: قطعة دجاج مقرمش',    nameEn: 'KFC Crispy Chicken (1pc)',    kcal: 400, proteinG: 30, carbsG: 18, fatG: 24.0),
  QuickFood(name: 'كنتاكي: زنجر برجر',           nameEn: 'KFC Zinger Burger',           kcal: 490, proteinG: 24, carbsG: 44, fatG: 22.0),
  QuickFood(name: 'كنتاكي: تواستر برجر',         nameEn: 'KFC Twister Wrap',            kcal: 480, proteinG: 22, carbsG: 48, fatG: 20.0),
  QuickFood(name: 'كنتاكي: بوبكورن دجاج (وسط)', nameEn: 'KFC Popcorn Chicken Medium',  kcal: 370, proteinG: 22, carbsG: 28, fatG: 18.0),
  QuickFood(name: 'كنتاكي: ماش بوتيتو',          nameEn: 'KFC Mashed Potatoes',         kcal: 130, proteinG: 2,  carbsG: 20, fatG: 5.0),
  QuickFood(name: 'كنتاكي: كول سلو',             nameEn: 'KFC Coleslaw',                kcal: 170, proteinG: 1,  carbsG: 22, fatG: 9.0),
  QuickFood(name: 'كنتاكي: وجبة باكت (٨ قطع)',  nameEn: 'KFC 8pc Bucket',             kcal:2560, proteinG:220, carbsG:88, fatG:152.0),
  QuickFood(name: 'كنتاكي: بسكويت',              nameEn: 'KFC Biscuit',                 kcal: 220, proteinG: 4,  carbsG: 26, fatG: 11.0),

  // ═══ FAMOUS RESTAURANT — SUBWAY HALAL ═══════════════════════════
  QuickFood(name: 'صب واي: ساندوتش دجاج تيريياكي', nameEn: 'Subway Chicken Teriyaki 6"',kcal: 350, proteinG: 24, carbsG: 46, fatG: 6.0),
  QuickFood(name: 'صب واي: ساندوتش تونا ٦ إنش',   nameEn: 'Subway Tuna 6"',            kcal: 480, proteinG: 20, carbsG: 44, fatG: 24.0),
  QuickFood(name: 'صب واي: ساندوتش فلافل',         nameEn: 'Subway Falafel 6"',          kcal: 380, proteinG: 14, carbsG: 56, fatG: 12.0),
  QuickFood(name: 'صب واي: كوكيز شوكولاتة',        nameEn: 'Subway Chocolate Cookie',    kcal: 210, proteinG: 2,  carbsG: 30, fatG: 10.0),

  // ═══ FAMOUS RESTAURANT — PIZZA HUT HALAL ════════════════════════
  QuickFood(name: 'بيتزا هت: بيتزا دجاج سوبريم (شريحة)', nameEn: 'Pizza Hut Chicken Supreme slice', kcal: 290, proteinG: 16, carbsG: 32, fatG: 10.0),
  QuickFood(name: 'بيتزا هت: بيتزا مارغريتا (شريحة)',   nameEn: 'Pizza Hut Margherita slice',      kcal: 240, proteinG: 11, carbsG: 30, fatG: 8.0),
  QuickFood(name: 'بيتزا هت: عيدان خبز بالثوم',        nameEn: 'Pizza Hut Garlic Bread Sticks',   kcal: 180, proteinG: 5,  carbsG: 28, fatG: 6.0),
  QuickFood(name: 'بيتزا هت: أجنحة دجاج (٤ قطع)',     nameEn: 'Pizza Hut Chicken Wings (4)',     kcal: 280, proteinG: 22, carbsG: 8,  fatG: 18.0),

  // ═══ FAMOUS RESTAURANT — BURGER KING HALAL ══════════════════════
  QuickFood(name: 'برجر كينج: وبر دجاج حلال',     nameEn: 'Burger King Chicken Whopper', kcal: 660, proteinG: 38, carbsG: 52, fatG: 32.0),
  QuickFood(name: 'برجر كينج: كريسبي دجاج',       nameEn: 'Burger King Crispy Chicken',  kcal: 520, proteinG: 28, carbsG: 46, fatG: 24.0),
  QuickFood(name: 'برجر كينج: أونيون رينجز (وسط)',nameEn: 'Burger King Onion Rings Med', kcal: 320, proteinG: 4,  carbsG: 38, fatG: 17.0),

  // ═══ FAMOUS RESTAURANT — HARDEE'S / CARL'S JR HALAL ═══════════
  QuickFood(name: 'هارديز: برجر دجاج مقرمش',    nameEn: "Hardee's Crispy Chicken",    kcal: 550, proteinG: 30, carbsG: 50, fatG: 24.0),
  QuickFood(name: 'هارديز: ثيك بيرجر دجاج',     nameEn: "Hardee's Thickburger Chicken",kcal:620, proteinG: 34, carbsG: 52, fatG: 28.0),

  // ═══ FAMOUS RESTAURANT — POPEYES HALAL ══════════════════════════
  QuickFood(name: 'بوبايز: دجاج مقرمش (قطعة)',  nameEn: "Popeyes Spicy Chicken (1pc)", kcal: 360, proteinG: 22, carbsG: 17, fatG: 22.0),
  QuickFood(name: 'بوبايز: بسكويت',              nameEn: "Popeyes Biscuit",             kcal: 260, proteinG: 4,  carbsG: 26, fatG: 15.0),
  QuickFood(name: 'بوبايز: ساندوتش دجاج',        nameEn: "Popeyes Chicken Sandwich",    kcal: 700, proteinG: 28, carbsG: 50, fatG: 42.0),

  // ═══ FAMOUS RESTAURANT — STARBUCKS HALAL ════════════════════════
  QuickFood(name: 'ستاربكس: لاتيه وسط',         nameEn: 'Starbucks Latte (Grande)',    kcal: 190, proteinG: 11, carbsG: 19, fatG: 7.0),
  QuickFood(name: 'ستاربكس: كابوتشينو وسط',     nameEn: 'Starbucks Cappuccino Grande', kcal: 120, proteinG: 7,  carbsG: 12, fatG: 4.0),
  QuickFood(name: 'ستاربكس: موكا فراباتشينو',    nameEn: 'Starbucks Mocha Frappuccino', kcal: 380, proteinG: 5,  carbsG: 61, fatG: 13.0),
  QuickFood(name: 'ستاربكس: كيكة شوكولاتة',     nameEn: 'Starbucks Chocolate Cake',    kcal: 380, proteinG: 6,  carbsG: 50, fatG: 18.0),
  QuickFood(name: 'ستاربكس: كروسان',             nameEn: 'Starbucks Croissant',         kcal: 260, proteinG: 5,  carbsG: 29, fatG: 14.0),

  // ═══ FAMOUS RESTAURANT — SHAWARMA CHAINS ════════════════════════
  QuickFood(name: 'شاورمر: شاورما دجاج (ساندوتش)', nameEn: 'Shawarmer Chicken Sandwich', kcal: 480, proteinG: 32, carbsG: 44, fatG: 18.0),
  QuickFood(name: 'أسياخ: مشوى دجاج (طبق)',      nameEn: 'Grilled chicken plate',       kcal: 520, proteinG: 42, carbsG: 48, fatG: 14.0),
  QuickFood(name: 'كبسة روف (طبق)',               nameEn: 'Kabsa Roof restaurant',       kcal: 680, proteinG: 44, carbsG: 72, fatG: 18.0),

  // ═══ COFFEE & BAKERY ════════════════════════════════════════════
  QuickFood(name: 'كروسان زبدة',                  nameEn: 'Butter croissant',            kcal: 272, proteinG: 5,  carbsG: 31, fatG: 14.0),
  QuickFood(name: 'دونات سكر (حبة)',              nameEn: 'Glazed donut',                kcal: 250, proteinG: 4,  carbsG: 34, fatG: 12.0),
  QuickFood(name: 'مافن بلوبيري',                 nameEn: 'Blueberry muffin',            kcal: 340, proteinG: 5,  carbsG: 48, fatG: 14.0),
  QuickFood(name: 'باغيل سادة',                   nameEn: 'Plain bagel',                 kcal: 270, proteinG: 10, carbsG: 53, fatG: 2.0),
  QuickFood(name: 'وافل (قطعة)',                  nameEn: 'Waffle',                      kcal: 218, proteinG: 6,  carbsG: 25, fatG: 11.0),
  QuickFood(name: 'فطيرة تفاح (شريحة)',           nameEn: 'Apple pie slice',             kcal: 296, proteinG: 2,  carbsG: 43, fatG: 14.0),

  // ═══ DEEPER EGYPTIAN STAPLES ════════════════════════════════════
  QuickFood(name: 'فتة بالكفتة',              nameEn: 'Kofta fattah',           kcal: 580, proteinG: 34, carbsG: 58,  fatG: 20.0),
  QuickFood(name: 'طاجن فراخ بالخضار',        nameEn: 'Chicken tagine',          kcal: 290, proteinG: 28, carbsG: 16,  fatG: 12.0),
  QuickFood(name: 'حمام محشي بالأرز',         nameEn: 'Stuffed pigeon with rice', kcal: 380, proteinG: 30, carbsG: 28,  fatG: 16.0),
  QuickFood(name: 'إسكالوب دجاج',             nameEn: 'Chicken escalope',        kcal: 340, proteinG: 28, carbsG: 18,  fatG: 16.0),
  QuickFood(name: 'بيف سيتيه (وجبة)',         nameEn: 'Beef hawawshi',           kcal: 520, proteinG: 26, carbsG: 44,  fatG: 24.0),
  QuickFood(name: 'هواوشي لحم (فينو)',        nameEn: 'Beef hawawshi sandwich',  kcal: 480, proteinG: 24, carbsG: 42,  fatG: 22.0),
  QuickFood(name: 'فراخ بانيه (٢ قطعة)',      nameEn: 'Breaded chicken (2pc)',   kcal: 360, proteinG: 26, carbsG: 22,  fatG: 18.0),
  QuickFood(name: 'روستو لحم بتلو (١٠٠ج)',   nameEn: 'Veal roast (100g)',       kcal: 185, proteinG: 28, carbsG: 0,   fatG: 8.0),
  QuickFood(name: 'سبانخ بالمرق (طبق)',       nameEn: 'Spinach in broth',        kcal: 120, proteinG: 8,  carbsG: 10,  fatG: 5.0),
  QuickFood(name: 'مسقعة بالبيض',             nameEn: 'Moussaka with eggs',      kcal: 260, proteinG: 12, carbsG: 18,  fatG: 16.0),
  QuickFood(name: 'طاجن سمك (طبق)',           nameEn: 'Fish tagine',             kcal: 220, proteinG: 24, carbsG: 10,  fatG: 8.0),
  QuickFood(name: 'سمبوسك لحم (٣ حبات)',     nameEn: 'Meat sambousek (3)',       kcal: 280, proteinG: 14, carbsG: 24,  fatG: 14.0),
  QuickFood(name: 'رقاق بالجبنة (٢ رقاقة)',  nameEn: 'Cheese rakak (2)',        kcal: 320, proteinG: 12, carbsG: 30,  fatG: 16.0),
  QuickFood(name: 'عيش فينو بالجبنة والطماطم', nameEn: 'Fino with cheese & tomato', kcal: 350, proteinG: 12, carbsG: 44, fatG: 12.0),
  QuickFood(name: 'بيض بالبسطرمة والجبنة',   nameEn: 'Eggs with pastrami & cheese', kcal: 280, proteinG: 20, carbsG: 2, fatG: 20.0),
  QuickFood(name: 'كبدة إسكندراني (طبق)',    nameEn: 'Alexandrian liver',       kcal: 240, proteinG: 24, carbsG: 8,   fatG: 12.0),

  // ═══ DEEPER GULF & LEVANTINE ════════════════════════════════════
  QuickFood(name: 'أرز لحم بالكمون',          nameEn: 'Spiced lamb rice',        kcal: 560, proteinG: 34, carbsG: 64,  fatG: 16.0),
  QuickFood(name: 'مفطح دجاج (طبق)',          nameEn: 'Muffatah chicken',        kcal: 520, proteinG: 36, carbsG: 58,  fatG: 14.0),
  QuickFood(name: 'سليق دجاج (طبق)',          nameEn: 'Chicken saleeg',          kcal: 480, proteinG: 32, carbsG: 56,  fatG: 12.0),
  QuickFood(name: 'دجاج مشوي بالليمون',       nameEn: 'Lemon grilled chicken',   kcal: 280, proteinG: 36, carbsG: 4,   fatG: 12.0),
  QuickFood(name: 'مشاوي مشكلة (طبق)',        nameEn: 'Mixed grill plate',       kcal: 620, proteinG: 52, carbsG: 8,   fatG: 40.0),
  QuickFood(name: 'خروف مشوي كامل (١٠٠ج)',   nameEn: 'Whole roasted lamb',      kcal: 280, proteinG: 26, carbsG: 0,   fatG: 18.0),
  QuickFood(name: 'تبسي باذنجان (طبق)',       nameEn: 'Eggplant tabsi',          kcal: 180, proteinG: 6,  carbsG: 18,  fatG: 10.0),
  QuickFood(name: 'مقلوبة دجاج (طبق)',        nameEn: 'Chicken maqlouba',        kcal: 540, proteinG: 34, carbsG: 64,  fatG: 14.0),
  QuickFood(name: 'مقلوبة لحم (طبق)',         nameEn: 'Meat maqlouba',           kcal: 580, proteinG: 36, carbsG: 64,  fatG: 18.0),
  QuickFood(name: 'كنافة نابلسية (١٠٠ج)',    nameEn: 'Nablus kunafa (100g)',    kcal: 360, proteinG: 10, carbsG: 48,  fatG: 16.0),
  QuickFood(name: 'قطايف بالقشطة (٢ حبة)',   nameEn: 'Qatayef with cream (2)', kcal: 280, proteinG: 6,  carbsG: 38,  fatG: 12.0),
  QuickFood(name: 'مناقيش زعتر (رغيف)',      nameEn: 'Za'atar manaqeesh',       kcal: 240, proteinG: 6,  carbsG: 36,  fatG: 8.0),
  QuickFood(name: 'مناقيش جبنة (رغيف)',      nameEn: 'Cheese manaqeesh',        kcal: 320, proteinG: 12, carbsG: 36,  fatG: 14.0),

  // ═══ DEEPER SUNNAH FOODS ════════════════════════════════════════
  QuickFood(name: 'ثريد تمر ولبن',            nameEn: 'Thareed with dates & milk', kcal: 380, proteinG: 12, carbsG: 62, fatG: 8.0),
  QuickFood(name: 'حلبة (كوب)',               nameEn: 'Fenugreek drink (cup)',    kcal: 36,  proteinG: 3,  carbsG: 6,   fatG: 1.0),
  QuickFood(name: 'مرق لحم بالخضار',          nameEn: 'Lamb broth with veg',     kcal: 120, proteinG: 10, carbsG: 8,   fatG: 4.0),
  QuickFood(name: 'خل التفاح مع الماء',       nameEn: 'Apple cider vinegar water',kcal: 6,  proteinG: 0,  carbsG: 1,   fatG: 0.0),
  QuickFood(name: 'قرفة مع عسل (كوب)',        nameEn: 'Cinnamon honey drink',    kcal: 70,  proteinG: 0,  carbsG: 18,  fatG: 0.0),
  QuickFood(name: 'زيت الزيتون البكر (م.ك)',  nameEn: 'Extra virgin olive oil (1tbsp)',kcal:119, proteinG:0, carbsG:0, fatG:14.0),
  QuickFood(name: 'ثوم نيء (فص)',             nameEn: 'Raw garlic (1 clove)',     kcal: 4,   proteinG: 0.2,carbsG: 1,   fatG: 0.0),
  QuickFood(name: 'زنجبيل طازج (١ م.ص)',     nameEn: 'Fresh ginger (1 tsp)',     kcal: 2,   proteinG: 0,  carbsG: 0.5, fatG: 0.0),
  QuickFood(name: 'كركم (١ م.ص)',             nameEn: 'Turmeric (1 tsp)',         kcal: 8,   proteinG: 0.2,carbsG: 1.5, fatG: 0.0),
  QuickFood(name: 'تين مجفف (٣ حبات)',        nameEn: 'Dried figs (3)',           kcal: 111, proteinG: 1,  carbsG: 29,  fatG: 0.4),
  QuickFood(name: 'مشمش مجفف (٥ حبات)',      nameEn: 'Dried apricots (5)',       kcal: 78,  proteinG: 1,  carbsG: 20,  fatG: 0.1),
  QuickFood(name: 'زبيب (٣٠ج)',              nameEn: 'Raisins (30g)',            kcal: 90,  proteinG: 1,  carbsG: 24,  fatG: 0.1),

  // ═══ SOUPS & LIGHT MEALS ════════════════════════════════════════
  QuickFood(name: 'شوربة عدس أحمر (كوب)',    nameEn: 'Red lentil soup (cup)',    kcal: 160, proteinG: 10, carbsG: 28,  fatG: 2.0),
  QuickFood(name: 'شوربة خضار (كوب)',         nameEn: 'Vegetable soup (cup)',     kcal: 80,  proteinG: 3,  carbsG: 14,  fatG: 1.0),
  QuickFood(name: 'شوربة دجاج بالشعير',      nameEn: 'Chicken barley soup',      kcal: 200, proteinG: 14, carbsG: 26,  fatG: 4.0),
  QuickFood(name: 'شوربة الفطر (كوب)',        nameEn: 'Mushroom soup (cup)',      kcal: 100, proteinG: 3,  carbsG: 12,  fatG: 4.0),
  QuickFood(name: 'شوربة بصل (كوب)',          nameEn: 'Onion soup (cup)',         kcal: 90,  proteinG: 3,  carbsG: 14,  fatG: 2.0),
  QuickFood(name: 'شوربة طماطم حمراء (كوب)', nameEn: 'Tomato soup (cup)',        kcal: 90,  proteinG: 3,  carbsG: 16,  fatG: 2.0),
  QuickFood(name: 'شوربة بروكلي (كوب)',       nameEn: 'Broccoli soup (cup)',      kcal: 100, proteinG: 4,  carbsG: 12,  fatG: 4.0),

  // ═══ HEALTHY & FITNESS FOODS ════════════════════════════════════
  QuickFood(name: 'صدر دجاج مسلوق (١٥٠ج)',  nameEn: 'Boiled chicken breast',   kcal: 248, proteinG: 46, carbsG: 0,   fatG: 5.0),
  QuickFood(name: 'تونة بالماء (علبة ١٨٠ج)',nameEn: 'Tuna in water (180g can)',kcal: 180, proteinG: 40, carbsG: 0,   fatG: 2.0),
  QuickFood(name: 'بياض البيض (٣ بيضات)',    nameEn: 'Egg whites (3)',           kcal: 51,  proteinG: 11, carbsG: 1,   fatG: 0.2),
  QuickFood(name: 'زبادي يوناني صفر دسم',    nameEn: 'Non-fat Greek yogurt',    kcal: 100, proteinG: 17, carbsG: 6,   fatG: 0.0),
  QuickFood(name: 'شوفان ١٠٠ج نيء',         nameEn: 'Raw oats (100g)',          kcal: 389, proteinG: 17, carbsG: 66,  fatG: 7.0),
  QuickFood(name: 'موز (حبة متوسطة)',         nameEn: 'Banana (medium)',          kcal: 105, proteinG: 1,  carbsG: 27,  fatG: 0.3),
  QuickFood(name: 'تفاحة (حبة متوسطة)',       nameEn: 'Apple (medium)',           kcal: 95,  proteinG: 0.5,carbsG: 25,  fatG: 0.3),
  QuickFood(name: 'بطيخ (١ شريحة ٣٠٠ج)',    nameEn: 'Watermelon (300g)',        kcal: 90,  proteinG: 2,  carbsG: 22,  fatG: 0.5),
  QuickFood(name: 'عصير خضار أخضر',          nameEn: 'Green vegetable juice',    kcal: 60,  proteinG: 2,  carbsG: 12,  fatG: 0.5),
  QuickFood(name: 'بروتين بار (بار واحد)',   nameEn: 'Protein bar (1 bar)',      kcal: 200, proteinG: 20, carbsG: 22,  fatG: 6.0),
  QuickFood(name: 'مكسرات مشكلة (٣٠ج)',     nameEn: 'Mixed nuts (30g)',         kcal: 185, proteinG: 5,  carbsG: 7,   fatG: 16.0),
  QuickFood(name: 'جوز (٧ حبات)',            nameEn: 'Walnuts (7 halves)',       kcal: 185, proteinG: 4,  carbsG: 4,   fatG: 18.0),
  QuickFood(name: 'لوز (٢٣ حبة)',            nameEn: 'Almonds (23)',             kcal: 164, proteinG: 6,  carbsG: 6,   fatG: 14.0),

];

final kProductsDB = [
  // ── Real Egyptian products ─────────────────────────────
  ScanResult(barcode: '6224000537018', name: 'لبن بيتي', brand: 'بيتي', status: HalalStatus.halal, certs: ['HFCE Egypt']),
  ScanResult(barcode: '6224008761234', name: 'عصير بيتي مانجو', brand: 'بيتي', status: HalalStatus.halal),
  ScanResult(barcode: '6224001234567', name: 'جبنة بيضاء بيتي', brand: 'بيتي', status: HalalStatus.halal, certs: ['HFCE']),
  ScanResult(barcode: '6224009876543', name: 'زبادي بيتي', brand: 'بيتي', status: HalalStatus.halal),
  ScanResult(barcode: '5449000000996', name: 'كوكاكولا ٣٣٠مل', brand: 'Coca-Cola', status: HalalStatus.halal, certs: ['HFCE']),
  ScanResult(barcode: '5449000054227', name: 'بيبسي ٣٣٠مل', brand: 'PepsiCo', status: HalalStatus.halal),
  ScanResult(barcode: '5449000013132', name: 'سبرايت ٣٣٠مل', brand: 'Coca-Cola', status: HalalStatus.halal),
  ScanResult(barcode: '6111245141943', name: 'شيبسي بالملح', brand: 'PepsiCo', status: HalalStatus.doubtful, notes: 'يحتوي على نكهات يجب التحقق منها'),
  ScanResult(barcode: '6111245141950', name: 'شيبسي جبنة', brand: 'PepsiCo', status: HalalStatus.doubtful, notes: 'نكهة جبنة — تحقق من المكونات'),
  ScanResult(barcode: '6224003456789', name: 'كيكة مراعي', brand: 'مراعي', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281003016015', name: 'حليب المراعي كامل', brand: 'مراعي', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281003016022', name: 'حليب المراعي قليل دسم', brand: 'مراعي', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281006112229', name: 'عصير النعومي برتقال', brand: 'النعومي', status: HalalStatus.halal),
  ScanResult(barcode: '6224007654321', name: 'بسكويت بتي بتر', brand: 'Ulker', status: HalalStatus.halal, certs: ['HFCE']),
  ScanResult(barcode: '6224005432198', name: 'شوكولاتة كيت كات', brand: 'Nestlé', status: HalalStatus.halal, certs: ['HFCE']),
  ScanResult(barcode: '6224008765432', name: 'نستله كيت كات ميني', brand: 'Nestlé', status: HalalStatus.halal),
  ScanResult(barcode: '6224001357924', name: 'مكرونة بيلا', brand: 'بيلا', status: HalalStatus.halal),
  ScanResult(barcode: '6224002468013', name: 'أرز مصري ممتاز', brand: 'محلي', status: HalalStatus.halal),
  ScanResult(barcode: '6224006789012', name: 'سكر أبيض', brand: 'محلي', status: HalalStatus.halal),
  ScanResult(barcode: '6224003579135', name: 'زيت زيتون ابو ضم', brand: 'ابو ضم', status: HalalStatus.halal, certs: ['HFCE']),
  ScanResult(barcode: '6224007890123', name: 'طحينة السيدة', brand: 'السيدة', status: HalalStatus.halal),
  ScanResult(barcode: '6224004680246', name: 'عسل النحل المصفى', brand: 'محلي', status: HalalStatus.halal),
  ScanResult(barcode: '6224008901234', name: 'بازلاء خضراء معلبة', brand: 'كايرو فارم', status: HalalStatus.halal),
  ScanResult(barcode: '6224001234890', name: 'فول معلب بالزيت', brand: 'كايرو', status: HalalStatus.halal),
  ScanResult(barcode: '4005900075468', name: 'شوكولاتة ريتر سبورت', brand: 'Ritter', status: HalalStatus.haram, notes: 'يحتوي على جيلاتين خنزير'),
  ScanResult(barcode: '4008400401621', name: 'هاريبو غمي بيرز', brand: 'Haribo', status: HalalStatus.haram, notes: 'جيلاتين خنزير — حرام'),
  ScanResult(barcode: '7622210100139', name: 'أوريو بسكويت', brand: 'Oreo', status: HalalStatus.doubtful, notes: 'بعض الدول حلال وبعضها مشبوه'),
  ScanResult(barcode: '6224005678901', name: 'تشيتوس جبنة', brand: 'PepsiCo', status: HalalStatus.doubtful, notes: 'تحقق من رقم الإنزيم في المكونات'),
  ScanResult(barcode: '6281003001012', name: 'لاكتالس جبنة مثلثات', brand: 'Laughing Cow', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6224009012345', name: 'مياه سيوة ٠٫٥ لتر', brand: 'سيوة', status: HalalStatus.halal),
  ScanResult(barcode: '6224000123456', name: 'مياه بارادايس', brand: 'بارادايس', status: HalalStatus.halal),

  // ── UK Halal brands ────────────────────────────────────
  ScanResult(barcode: '5000169105893', name: 'Cadbury Dairy Milk', brand: 'Cadbury UK', status: HalalStatus.halal, certs: ['HFA UK'], notes: 'Halal certified in UK'),
  ScanResult(barcode: '5000159461023', name: 'Cadbury Roses', brand: 'Cadbury', status: HalalStatus.doubtful, notes: 'Check local certification'),
  ScanResult(barcode: '5010477330068', name: 'Walkers Crisps Plain', brand: 'Walkers', status: HalalStatus.halal),
  ScanResult(barcode: '5000188921898', name: 'McVities Digestive', brand: 'McVities', status: HalalStatus.halal, certs: ['HFA UK']),
  ScanResult(barcode: '5000393003468', name: 'Heinz Baked Beans', brand: 'Heinz', status: HalalStatus.halal),
  ScanResult(barcode: '5000167023762', name: 'Kelloggs Corn Flakes', brand: 'Kelloggs', status: HalalStatus.halal),
  ScanResult(barcode: '5000183700012', name: 'Hovis Wholemeal Bread', brand: 'Hovis', status: HalalStatus.halal),
  ScanResult(barcode: '5010251011392', name: 'Cathedral City Cheddar', brand: 'Cathedral City', status: HalalStatus.halal, certs: ['HFA']),
  ScanResult(barcode: '5000315621236', name: 'Flora Margarine', brand: 'Flora', status: HalalStatus.halal),
  ScanResult(barcode: '0000000016458', name: 'Twix Bar', brand: 'Mars', status: HalalStatus.halal, certs: ['HFA UK']),
  ScanResult(barcode: '5000159372700', name: 'Maltesers', brand: 'Mars', status: HalalStatus.halal, certs: ['HFA UK']),
  ScanResult(barcode: '5000159376043', name: 'Bounty Bar', brand: 'Mars', status: HalalStatus.halal, certs: ['HFA UK']),
  ScanResult(barcode: '5000159376012', name: 'Snickers Bar', brand: 'Mars', status: HalalStatus.halal, certs: ['HFA UK']),

  // ── US Halal brands ────────────────────────────────────
  ScanResult(barcode: '0016000275287', name: 'Cheerios Original', brand: 'General Mills', status: HalalStatus.halal),
  ScanResult(barcode: '0038000845604', name: 'Kelloggs Special K', brand: 'Kelloggs', status: HalalStatus.halal),
  ScanResult(barcode: '0044000032029', name: 'Oreo Original', brand: 'Nabisco', status: HalalStatus.doubtful, notes: 'US version — check ingredients'),
  ScanResult(barcode: '0010700504208', name: 'Pepperidge Farm Goldfish', brand: 'Pepperidge', status: HalalStatus.doubtful),
  ScanResult(barcode: '0041196870066', name: 'Lays Classic Chips', brand: 'PepsiCo US', status: HalalStatus.halal),
  ScanResult(barcode: '0028400090094', name: 'Doritos Nacho Cheese', brand: 'PepsiCo', status: HalalStatus.doubtful, notes: 'May contain non-halal enzymes'),
  ScanResult(barcode: '0019200043304', name: 'Tropicana Orange Juice', brand: 'Tropicana', status: HalalStatus.halal),
  ScanResult(barcode: '0078742098937', name: 'Sams Choice Water', brand: 'Walmart', status: HalalStatus.halal),
  ScanResult(barcode: '0012000161155', name: 'Pepsi Can 330ml', brand: 'PepsiCo US', status: HalalStatus.halal),
  ScanResult(barcode: '0049000028911', name: 'Coca-Cola Can 330ml', brand: 'Coca-Cola US', status: HalalStatus.halal),

  // ── EU Halal brands ────────────────────────────────────
  ScanResult(barcode: '8711000300022', name: 'Knorr Chicken Stock', brand: 'Knorr EU', status: HalalStatus.doubtful, notes: 'Check halal version'),
  ScanResult(barcode: '8710398520067', name: 'Lipton Yellow Label Tea', brand: 'Lipton', status: HalalStatus.halal),
  ScanResult(barcode: '8000500310427', name: 'Nutella 200g', brand: 'Ferrero', status: HalalStatus.halal, certs: ['IFANCA'], notes: 'Halal certified globally'),
  ScanResult(barcode: '3017620422003', name: 'Nutella 400g FR', brand: 'Ferrero FR', status: HalalStatus.halal, certs: ['IFANCA']),
  ScanResult(barcode: '7613035349988', name: 'Nescafe Original', brand: 'Nestle', status: HalalStatus.halal),
  ScanResult(barcode: '7613033383991', name: 'KitKat 4 Finger', brand: 'Nestle EU', status: HalalStatus.halal, certs: ['HFA']),
  ScanResult(barcode: '8076809513388', name: 'Barilla Spaghetti', brand: 'Barilla', status: HalalStatus.halal),
  ScanResult(barcode: '4005556011308', name: 'Haribo Gold Bears', brand: 'Haribo', status: HalalStatus.haram, notes: 'Contains pork gelatin — HARAM'),
  ScanResult(barcode: '4014400914001', name: 'Haribo Halal Bears', brand: 'Haribo Halal', status: HalalStatus.halal, certs: ['IFANCA'], notes: 'Special halal range'),
  ScanResult(barcode: '3046920022637', name: 'Milka Alpine Milk', brand: 'Milka', status: HalalStatus.doubtful, notes: 'Not halal certified in all regions'),
  ScanResult(barcode: '7622300441937', name: 'Toblerone 100g', brand: 'Mondelez', status: HalalStatus.doubtful, notes: 'Check local certification'),

  // ── Saudi / Gulf brands ────────────────────────────────
  ScanResult(barcode: '6281003016015', name: 'Almarai Full Fat Milk', brand: 'Almarai', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281003016022', name: 'Almarai Low Fat Milk', brand: 'Almarai', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281003016039', name: 'Almarai Orange Juice', brand: 'Almarai', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281003016046', name: 'Almarai Yogurt', brand: 'Almarai', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281006112229', name: 'Al Nada Juice Mango', brand: 'Al Nada', status: HalalStatus.halal),
  ScanResult(barcode: '6294003553008', name: 'Baladna Laban', brand: 'Baladna', status: HalalStatus.halal, certs: ['Qatar']),
  ScanResult(barcode: '6291003030009', name: 'Al Ain Water 500ml', brand: 'Al Ain', status: HalalStatus.halal),
  ScanResult(barcode: '6281055550001', name: 'Nadec Butter', brand: 'Nadec', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6281006890001', name: 'Saudia Cream', brand: 'Saudia', status: HalalStatus.halal, certs: ['SFDA']),
  ScanResult(barcode: '6911988023099', name: 'Indomie Mi Goreng', brand: 'Indomie', status: HalalStatus.halal, certs: ['MUI Indonesia']),
  ScanResult(barcode: '8993001901002', name: 'Indomie Chicken', brand: 'Indomie', status: HalalStatus.halal, certs: ['MUI']),

  // ── Known HARAM products ───────────────────────────────
  ScanResult(barcode: '0037466065099', name: 'Jack Daniel's Whiskey', brand: 'Jack Daniel's', status: HalalStatus.haram, notes: 'Alcohol — HARAM'),
  ScanResult(barcode: '5010148002849', name: 'Budweiser Beer', brand: 'AB InBev', status: HalalStatus.haram, notes: 'Alcohol — HARAM'),
  ScanResult(barcode: '0049695001023', name: 'Spam Classic', brand: 'Hormel', status: HalalStatus.haram, notes: 'Pork — HARAM'),
  ScanResult(barcode: '0017000097985', name: 'Oscar Mayer Bacon', brand: 'Kraft', status: HalalStatus.haram, notes: 'Pork — HARAM'),
];

