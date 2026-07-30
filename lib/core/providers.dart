// providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart'; import'package:shared_preferences/shared_preferences.dart'; import'package:go_router/go_router.dart'; import'../data/models/models.dart'; import'../data/models/user_profile.dart'; import'router.dart'; import'revenuecat_service.dart'; import'database.dart'; import'health_service.dart'; import'ascent.dart';
import 'package:package_info_plus/package_info_plus.dart';
export 'ascent.dart';

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) => LanguageNotifier());
class LanguageNotifier extends StateNotifier<String> { LanguageNotifier() : super('ar') { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getString('language') ?? 'ar'; }
  Future<void> set(String lang) async { state = lang; final p = await SharedPreferences.getInstance(); await p.setString('language', lang); }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>((ref) => ThemeNotifier());
class ThemeNotifier extends StateNotifier<bool> { ThemeNotifier() : super(true) { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getBool('dark_mode') ?? true; }
  Future<void> toggle() async { state = !state; final p = await SharedPreferences.getInstance(); await p.setBool('dark_mode', state); }
}

final onboardingDoneProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) => OnboardingNotifier());
class OnboardingNotifier extends StateNotifier<bool> { OnboardingNotifier() : super(false) { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getBool('onboarding_done') ?? false; }
  Future<void> complete() async { state = true; final p = await SharedPreferences.getInstance(); await p.setBool('onboarding_done', true); }
  Future<void> reset() async { state = false; final p = await SharedPreferences.getInstance(); await p.setBool('onboarding_done', false); }
}

final genderProvider = StateNotifierProvider<GenderNotifier, String>((ref) => GenderNotifier());
class GenderNotifier extends StateNotifier<String> { GenderNotifier() : super('brothers') { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getString('gender') ?? 'brothers'; }
  Future<void> set(String g) async { state = g; final p = await SharedPreferences.getInstance(); await p.setString('gender', g); }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile?>((ref) => UserProfileNotifier());
class UserProfileNotifier extends StateNotifier<UserProfile?> { UserProfileNotifier() : super(null) { _load(); }
  Future<void> _load() async { state = await UserProfileRepository.load(); }
  Future<void> save(UserProfile profile) async { await UserProfileRepository.save(profile); state = profile; }
  Future<void> clear() async { await UserProfileRepository.clear(); state = null; }
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>((ref) => PremiumNotifier());
class PremiumNotifier extends StateNotifier<bool> { PremiumNotifier() : super(false) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getBool('is_premium') ?? false;
    try { final live = await RevenueCatService.isPremium(); if (live != state) { state = live; await p.setBool('is_premium', live); } } catch (_) {}
  }
  Future<void> onPurchaseSuccess() async { state = true; final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', true); }
  Future<void> refresh() async { try { final live = await RevenueCatService.isPremium(); state = live; final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', live); } catch (_) {} }
  Future<void> unlock() async { state = true; final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', true); }
  Future<void> revoke() async { state = false; final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', false); }
}

final planNameProvider = FutureProvider<String>((ref) async { final isPrem = ref.watch(premiumProvider); if (!isPrem) return 'free'; return RevenueCatService.getActivePlanId(); });
final rcOfferingsProvider = FutureProvider<List<RCOffering>>((ref) async { return RevenueCatService.getOfferings(); });

final streakProvider = StateNotifierProvider<StreakNotifier, int>((ref) => StreakNotifier());
class StreakNotifier extends StateNotifier<int> { StreakNotifier() : super(0) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); final lastDate = p.getString('streak_last_date') ?? '';
    final today = _dateKey(); final streak = p.getInt('streak') ?? 0;
    if (lastDate == today) { state = streak; } else if (lastDate == _yesterday()) { state = streak; } else if (lastDate.isEmpty) { state = 0; } else { state = 0; await p.setInt('streak', 0); }
  }
  Future<void> increment() async {
    final p = await SharedPreferences.getInstance(); final today = _dateKey(); final lastDate = p.getString('streak_last_date') ?? '';
    if (lastDate == today) return;
    final newStreak = (lastDate == _yesterday()) ? state + 1 : 1;
    state = newStreak; await p.setInt('streak', newStreak); await p.setString('streak_last_date', today);
  }
  String _dateKey() { final n = DateTime.now(); return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}'; }
  String _yesterday() { final y = DateTime.now().subtract(const Duration(days: 1)); return '${y.year}-${y.month.toString().padLeft(2,'0')}-${y.day.toString().padLeft(2,'0')}'; }
}

final caloriesProvider = StateNotifierProvider<CaloriesNotifier, CaloriesState>((ref) => CaloriesNotifier(ref));
class CaloriesState {
  final int goal;
  final List<MealEntry> entries;
  CaloriesState({required this.goal, required this.entries});
  int get total => entries.fold(0, (s, e) => s + e.kcal);
  int get remaining => (goal - total).clamp(0, 99999);
  double get percent => goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0.0;
  double get proteinTotal => entries.fold(0.0, (s, e) => s + e.proteinG);
  double get carbsTotal   => entries.fold(0.0, (s, e) => s + e.carbsG);
  double get fatTotal     => entries.fold(0.0, (s, e) => s + e.fatG);
}
class CaloriesNotifier extends StateNotifier<CaloriesState> {
  final Ref _ref;
  CaloriesNotifier(this._ref) : super(CaloriesState(goal: 2000, entries: [])) {
    _init();
    _ref.listen(userProfileProvider, (_, profile) { if (profile != null) syncWithProfile(profile); });
  }
  Future<void> _init() async {
    final p = _ref.read(userProfileProvider); final goal = p?.calorieGoalKcal.toInt() ?? 2000;
    final rows = await AppDatabase.getTodayMeals();
    final entries = rows.map((e) => MealEntry(id: e['id'] as int, name: e['name'] as String, kcal: e['kcal'] as int, proteinG: (e['protein_g'] as num?)?.toDouble() ?? 0, carbsG: (e['carbs_g'] as num?)?.toDouble() ?? 0, fatG: (e['fat_g'] as num?)?.toDouble() ?? 0, time: DateTime.tryParse(e['created'] as String? ?? '') ?? DateTime.now())).toList();
    state = CaloriesState(goal: goal, entries: entries);
  }
  void syncWithProfile(UserProfile p) => state = CaloriesState(goal: p.calorieGoalKcal.toInt(), entries: state.entries);
  void setGoal(int g) => state = CaloriesState(goal: g.clamp(500, 9999), entries: state.entries);
  Future<void> addEntry(String name, int kcal, {double proteinG = 0, double carbsG = 0, double fatG = 0}) async {
    if (kcal <= 0) return;
    final id = await AppDatabase.insertMeal(name: name, kcal: kcal.clamp(1, 9999), proteinG: proteinG, carbsG: carbsG, fatG: fatG);
    if (id == -1) return;
    final entry = MealEntry(id: id, name: name, kcal: kcal.clamp(1, 9999), time: DateTime.now(), proteinG: proteinG, carbsG: carbsG, fatG: fatG);
    state = CaloriesState(goal: state.goal, entries: [...state.entries, entry]);
  }
  Future<void> reloadFromDb() async {
    final rows = await AppDatabase.getTodayMeals();
    final entries = rows.map((e) => MealEntry(id: e['id'] as int, name: e['name'] as String, kcal: e['kcal'] as int, proteinG: (e['protein_g'] as num?)?.toDouble() ?? 0, carbsG: (e['carbs_g'] as num?)?.toDouble() ?? 0, fatG: (e['fat_g'] as num?)?.toDouble() ?? 0, time: DateTime.tryParse(e['created'] as String? ?? '') ?? DateTime.now())).toList();
    state = CaloriesState(goal: state.goal, entries: entries);
  }
  Future<void> removeEntry(int id) async {
    await AppDatabase.deleteMeal(id);
    state = CaloriesState(goal: state.goal, entries: state.entries.where((x) => x.id != id).toList());
  }
}

final weeklyKcalProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(caloriesProvider);
  final rows = await AppDatabase.getWeeklyKcal(); return rows.map((r) => {'date': r.dateKey, 'kcal': r.kcal}).toList();
});

// ── Macro Plan ──────────────────────────────────────────
enum MacroPlan { balanced, highProtein, highCarb, keto }
extension MacroPlanExt on MacroPlan {
  int get proteinPct => switch (this) {
    MacroPlan.highProtein => 40,
    MacroPlan.keto        => 25,
    _                     => 30,
  };
  int get carbsPct => switch (this) {
    MacroPlan.highCarb    => 55,
    MacroPlan.keto        =>  5,
    MacroPlan.highProtein => 35,
    _                     => 40,
  };
  int get fatPct => switch (this) {
    MacroPlan.keto        => 70,
    MacroPlan.highProtein => 25,
    MacroPlan.highCarb    => 25,
    _                     => 30,
  };
  String nameAr() => switch (this) {
    MacroPlan.balanced    => 'متوازن',
    MacroPlan.highProtein => 'عالي البروتين',
    MacroPlan.highCarb    => 'عالي الكارب',
    MacroPlan.keto        => 'كيتو',
  };
  String nameEn() => switch (this) {
    MacroPlan.balanced    => 'Balanced',
    MacroPlan.highProtein => 'High Protein',
    MacroPlan.highCarb    => 'High Carb',
    MacroPlan.keto        => 'Keto',
  };
  String emoji() => switch (this) {
    MacroPlan.balanced    => '⚖️',
    MacroPlan.highProtein => '💪',
    MacroPlan.highCarb    => '🍚',
    MacroPlan.keto        => '🥑',
  };
}
final macroPlanProvider = StateNotifierProvider<MacroPlanNotifier, MacroPlan>(
    (ref) => MacroPlanNotifier());
class MacroPlanNotifier extends StateNotifier<MacroPlan> {
  MacroPlanNotifier() : super(MacroPlan.balanced) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final n = p.getString('macro_plan') ?? 'balanced';
    state = MacroPlan.values.firstWhere(
        (e) => e.name == n, orElse: () => MacroPlan.balanced);
  }
  Future<void> set(MacroPlan plan) async {
    state = plan;
    final p = await SharedPreferences.getInstance();
    await p.setString('macro_plan', plan.name);
  }
}

final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>((ref) => WaterNotifier(ref));
class WaterState { final int cups, goal; WaterState({required this.cups, required this.goal}); double get percent => goal > 0 ? (cups / goal).clamp(0, 1) : 0; }
class WaterNotifier extends StateNotifier<WaterState> {
  final Ref _ref;
  WaterNotifier(this._ref) : super(WaterState(cups: 0, goal: 8)) { _init(); }
  Future<void> _init() async {
    final p = _ref.read(userProfileProvider); final goal = p?.waterCupsGoal ?? 8;
    final row = await AppDatabase.getTodaySummary(); final cups = (row?['water_cups'] as int?) ?? 0;
    state = WaterState(cups: cups, goal: goal);
  }
  Future<void> add() async { final cups = (state.cups + 1).clamp(0, 20); state = WaterState(cups: cups, goal: state.goal); await AppDatabase.upsertSummary(waterCups: cups); }
  Future<void> remove() async { final cups = (state.cups - 1).clamp(0, 20); state = WaterState(cups: cups, goal: state.goal); await AppDatabase.upsertSummary(waterCups: cups); }
  void setGoal(int g) => state = WaterState(cups: state.cups, goal: g);
  Future<void> set(int cups) async { final c = cups.clamp(0, 20); state = WaterState(cups: c, goal: state.goal); await AppDatabase.upsertSummary(waterCups: c); }
}

final sleepProvider = StateNotifierProvider<SleepNotifier, SleepState>((ref) => SleepNotifier(ref));
class SleepState { final double hours, goal; SleepState({required this.hours, required this.goal}); double get percent => goal > 0 ? (hours / goal).clamp(0, 1) : 0; String qualityAr() { if (hours >= 8) return 'ممتاز'; if (hours >= 6) return 'كافٍ'; return 'غير كافٍ'; } String qualityEn() { if (hours >= 8) return 'Ideal'; if (hours >= 6) return 'Adequate'; return 'Insufficient'; } }
class SleepNotifier extends StateNotifier<SleepState> {
  final Ref _ref;
  SleepNotifier(this._ref) : super(SleepState(hours: 7, goal: 8)) { _init(); }
  Future<void> _init() async {
    final row = await AppDatabase.getTodaySummary(); final hrs = (row?['sleep_hrs'] as num?)?.toDouble() ?? 7.0;
    final p = _ref.read(userProfileProvider);
    state = SleepState(hours: hrs, goal: p?.sleepHours ?? 8);
  }
  Future<void> set(double h) async { state = SleepState(hours: h.clamp(0, 24), goal: state.goal); await AppDatabase.upsertSummary(sleepHrs: h.clamp(0, 24)); }
}

final healthProvider = StateNotifierProvider<HealthNotifier, HealthState>((ref) => HealthNotifier());
class HealthState { final int steps, stepsGoal, heartRate; final String? mood; final double? quickBmi; HealthState({this.steps = 0, this.stepsGoal = 10000, this.heartRate = 72, this.mood, this.quickBmi}); }
class HealthNotifier extends StateNotifier<HealthState> {
  HealthNotifier() : super(HealthState()) { _init(); }
  Future<void> _init() async {
    final row = await AppDatabase.getTodaySummary(); if (row == null) return;
    state = HealthState(steps: (row['steps'] as int?) ?? 0, stepsGoal: state.stepsGoal, heartRate: state.heartRate, mood: row['mood'] as String?);
  }
  Future<void> setSteps(int n) async { state = HealthState(steps: n.clamp(0, 99999), stepsGoal: state.stepsGoal, heartRate: state.heartRate, mood: state.mood, quickBmi: state.quickBmi); await AppDatabase.upsertSummary(steps: n.clamp(0, 99999)); }
  Future<void> addSteps(int n) => setSteps(state.steps + n);
  void setHeartRate(int hr) => state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal, heartRate: hr.clamp(30, 250), mood: state.mood, quickBmi: state.quickBmi);
  Future<void> setMood(String m) async { state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal, heartRate: state.heartRate, mood: m, quickBmi: state.quickBmi); await AppDatabase.upsertSummary(mood: m); }
  void setBMI(double w, double h) { if (h <= 0) return; final bmi = w / ((h / 100) * (h / 100)); state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal, heartRate: state.heartRate, mood: state.mood, quickBmi: bmi); }
}

final healthPermissionProvider = StateNotifierProvider<HealthPermNotifier, bool>((ref) => HealthPermNotifier());
class HealthPermNotifier extends StateNotifier<bool> {
  HealthPermNotifier() : super(false);
  Future<bool> request() async { try { final granted = await HealthService.requestPermissions(); state = granted; return granted; } catch (_) { return false; } }
}

final workoutMinutesProvider = StateNotifierProvider<WorkoutMinutesNotifier, int>((ref) => WorkoutMinutesNotifier());
class WorkoutMinutesNotifier extends StateNotifier<int> { WorkoutMinutesNotifier() : super(0) { _init(); }
  Future<void> _init() async { state = await AppDatabase.getTodayWorkoutMinutes(); }
  Future<void> add(String workoutId, int minutes) async { await AppDatabase.logWorkout(workoutId, minutes); state = state + minutes; }
}

final caloriesBurnedTodayProvider =
    StateNotifierProvider<BurnedCaloriesNotifier, double>(
        (ref) => BurnedCaloriesNotifier());
class BurnedCaloriesNotifier extends StateNotifier<double> {
  BurnedCaloriesNotifier() : super(0.0) { _init(); }
  Future<void> _init() async { state = await AppDatabase.getTodayBurnedKcal(); }
  void addBurned(double kcal) => state = state + kcal;
}

final workoutWeekProvider = FutureProvider<Set<String>>((ref) async {
  ref.watch(caloriesBurnedTodayProvider);
  return AppDatabase.getWeeklyWorkoutDays();
});

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) => ScanNotifier());

// ── AI Photo Scan daily counter (free: 3/day) ────────────────────────
final aiPhotoScanProvider = StateNotifierProvider<AiPhotoScanNotifier, int>(
    (ref) => AiPhotoScanNotifier());

class AiPhotoScanNotifier extends StateNotifier<int> {
  AiPhotoScanNotifier() : super(0) { _load(); }

  static String _dateKey() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final today = _dateKey();
      if ((p.getString('ai_photo_date') ?? '') != today) {
        await p.setString('ai_photo_date', today);
        await p.setInt('ai_photo_count', 0);
        state = 0;
      } else {
        state = p.getInt('ai_photo_count') ?? 0;
      }
    } catch (_) {}
  }

  Future<void> increment() async {
    state = state + 1;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('ai_photo_date', _dateKey());
      await p.setInt('ai_photo_count', state);
    } catch (_) {}
  }
}
class ScanState { final List<ScanResult> history; final int todayCount; ScanState({required this.history, required this.todayCount}); }
class ScanNotifier extends StateNotifier<ScanState> {
  static String _dateKey() => DateTime.now().toIso8601String().substring(0, 10);

  ScanNotifier() : super(ScanState(history: [], todayCount: 0)) { _load(); }

  Future<void> _load() async {
    try {
      final p     = await SharedPreferences.getInstance();
      final today = _dateKey();
      // Reset count if it's a new calendar day
      if ((p.getString('scan_date') ?? '') != today) {
        await p.setString('scan_date',  today);
        await p.setInt(   'scan_count', 0);
        state = ScanState(history: state.history, todayCount: 0);
      } else {
        final saved = p.getInt('scan_count') ?? 0;
        state = ScanState(history: state.history, todayCount: saved);
      }
    } catch (_) {}
  }

  void addScan(ScanResult r) {
    final newCount = state.todayCount + 1;
    state = ScanState(history: [r, ...state.history.take(49)], todayCount: newCount);
    // Persist asynchronously — fire-and-forget
    SharedPreferences.getInstance().then((p) {
      p.setString('scan_date',  _dateKey());
      p.setInt(   'scan_count', newCount);
    }).catchError((_) {});
  }
}

final zakatProvider = StateNotifierProvider<ZakatNotifier, double>((ref) => ZakatNotifier());
class ZakatNotifier extends StateNotifier<double> { ZakatNotifier() : super(0) { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getDouble('zakat_amount') ?? 0; }
  Future<void> add(double amount) async { state += amount; final p = await SharedPreferences.getInstance(); await p.setDouble('zakat_amount', state); }
}

final cityProvider = StateNotifierProvider<CityNotifier, String>((ref) => CityNotifier());
class CityNotifier extends StateNotifier<String> { CityNotifier() : super('\u0627\u0644\u0642\u0627\u0647\u0631\u0629') { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getString('city') ?? '\u0627\u0644\u0642\u0627\u0647\u0631\u0629'; }
  Future<void> set(String city) async { state = city; final p = await SharedPreferences.getInstance(); await p.setString('city', city); }
}

// ── Fasting-day tracker ─────────────────────────────────
class FastingState {
  final bool fastedToday;
  final int streak;
  final int lifetimeCount;
  final List<String> fastDates; // yyyy-MM-dd
  const FastingState({
    this.fastedToday = false, this.streak = 0,
    this.lifetimeCount = 0, this.fastDates = const [],
  });
}

class FastingNotifier extends StateNotifier<FastingState> {
  FastingNotifier() : super(const FastingState()) { _load(); }

  Future<void> _load() async {
    final p     = await SharedPreferences.getInstance();
    final dates = p.getStringList('sunnah_fast_dates') ?? [];
    final today = _today();
    final fastedToday = dates.contains(today);
    int streak = 0;
    DateTime d = DateTime.now();
    while (true) {
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      if (!dates.contains(key)) break;
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    state = FastingState(
      fastedToday: fastedToday, streak: streak,
      lifetimeCount: dates.length, fastDates: dates,
    );
  }

  Future<void> toggleToday() async {
    final p     = await SharedPreferences.getInstance();
    final dates = List<String>.from(state.fastDates);
    final today = _today();
    if (dates.contains(today)) dates.remove(today);
    else dates.add(today);
    await p.setStringList('sunnah_fast_dates', dates);
    await _load();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }
}

final fastingProvider = StateNotifierProvider<FastingNotifier, FastingState>(
  (ref) => FastingNotifier());

// ── Achievement Badges ────────────────────────────────────
class AchievementState {
  final int totalDaysLogged, fastCount, wholeFoodsLogged;
  const AchievementState({
    this.totalDaysLogged = 0, this.fastCount = 0,
    this.wholeFoodsLogged = 0,
  });
}

class AchievementNotifier extends StateNotifier<AchievementState> {
  AchievementNotifier() : super(const AchievementState()) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = AchievementState(
      totalDaysLogged:   p.getInt('ach_days_logged')  ?? 0,
      fastCount:   p.getInt('ach_sunnah_fasts') ?? 0,
      wholeFoodsLogged: p.getInt('ach_sunnah_foods') ?? 0,
    );
  }
  Future<void> incrementDay() async {
    final p = await SharedPreferences.getInstance();
    final v = (p.getInt('ach_days_logged') ?? 0) + 1;
    await p.setInt('ach_days_logged', v);
    state = AchievementState(totalDaysLogged: v,
      fastCount: state.fastCount,
      wholeFoodsLogged: state.wholeFoodsLogged);
  }
  Future<void> incrementWholeFood() async {
    final p = await SharedPreferences.getInstance();
    final v = (p.getInt('ach_sunnah_foods') ?? 0) + 1;
    await p.setInt('ach_sunnah_foods', v);
    state = AchievementState(totalDaysLogged: state.totalDaysLogged,
      fastCount: state.fastCount, wholeFoodsLogged: v);
  }
}

final achievementProvider = StateNotifierProvider<AchievementNotifier, AchievementState>(
  (ref) => AchievementNotifier());

final weightLogProvider = StateNotifierProvider<WeightLogNotifier, List<WeightEntry>>((ref) => WeightLogNotifier());
class WeightEntry { final int id; final DateTime date; final double weightKg; final String? note; WeightEntry({required this.id, required this.date, required this.weightKg, this.note}); }
class WeightLogNotifier extends StateNotifier<List<WeightEntry>> { WeightLogNotifier() : super([]) { _load(); }
  Future<void> _load() async { final rows = await AppDatabase.getWeightLog(limit: 60); state = rows.map((r) => WeightEntry(id: r['id'] as int, date: DateTime.tryParse(r['created'] as String? ?? '') ?? DateTime.now(), weightKg: (r['weight_kg'] as num).toDouble(), note: r['note'] as String?)).toList(); }
  Future<void> add(double kg, {String? note}) async { final id = await AppDatabase.insertWeight(kg, note: note); final entry = WeightEntry(id: id, date: DateTime.now(), weightKg: kg, note: note); state = [...state, entry]; }
  Future<void> remove(int id) async { await AppDatabase.deleteWeight(id); state = state.where((e) => e.id != id).toList(); }
}

final ramadanModeProvider = StateNotifierProvider<RamadanNotifier, bool>((ref) => RamadanNotifier());
class RamadanNotifier extends StateNotifier<bool> { RamadanNotifier() : super(false) { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getBool('ramadan_mode') ?? false; }
  Future<void> toggle() async { state = !state; final p = await SharedPreferences.getInstance(); await p.setBool('ramadan_mode', state); }
}

final notificationsEnabledProvider = StateNotifierProvider<NotifNotifier, bool>((ref) => NotifNotifier());
class NotifNotifier extends StateNotifier<bool> { NotifNotifier() : super(true) { _load(); }
  Future<void> _load() async { final p = await SharedPreferences.getInstance(); state = p.getBool('notifications_on') ?? true; }
  Future<void> toggle() async { state = !state; final p = await SharedPreferences.getInstance(); await p.setBool('notifications_on', state); }
}

// ══════════════════════════════════════════════════════════════════
// ASCENT SYSTEM
// Daily quests → daily score → XP → level → rank.
// Pure math and data live in core/ascent.dart; this is the wiring.
// ══════════════════════════════════════════════════════════════════

class AscentNotifier extends StateNotifier<AscentState> {
  final Ref _ref;
  AscentNotifier(this._ref) : super(const AscentState()) {
    _sync();
    // Keep the quest board live: logging a meal, a cup of water or a
    // workout should move the score without needing a screen reopen.
    _ref.listen(caloriesProvider,        (_, __) => _sync());
    _ref.listen(waterProvider,           (_, __) => _sync());
    _ref.listen(sleepProvider,           (_, __) => _sync());
    _ref.listen(healthProvider,          (_, __) => _sync());
    _ref.listen(workoutMinutesProvider,  (_, __) => _sync());
    _ref.listen(fastingProvider,         (_, __) => _sync());
  }

  /// Set by [_sync] whenever a recompute pushes the user past a level
  /// boundary, so the screen can play the level-up sequence once.
  int? pendingLevelUp;

  /// Recomputes every quest from live tracker data, persists the day and
  /// refreshes level/chain. Safe to call as often as you like.
  Future<void> _sync() async {
    final cals   = _ref.read(caloriesProvider);
    final water  = _ref.read(waterProvider);
    final sleep  = _ref.read(sleepProvider);
    final health = _ref.read(healthProvider);
    final minutes = _ref.read(workoutMinutesProvider);
    final fast   = _ref.read(fastingProvider);

    final row = await AppDatabase.getTodayAscent();
    // Stillness and wholesome are user-driven, so they come from the row.
    final stillness = (row?['stillness'] as int? ?? 0).clamp(0, kQuestMax);
    final wholesome = (row?['wholesome'] as int? ?? 0).clamp(0, kQuestMax);

    // Nourish: full marks inside 80-110% of the calorie goal.
    final calPct = cals.goal > 0 ? cals.total / cals.goal : 0.0;
    final nourish = calPct >= 0.8 && calPct <= 1.1
        ? kQuestMax
        : (calPct >= 0.6 ? 80 : (calPct > 0 ? 40 : 0));

    final hydrate = water.goal > 0
        ? ((water.cups / water.goal) * kQuestMax).clamp(0, kQuestMax).toInt() : 0;
    final rest = sleep.goal > 0
        ? ((sleep.hours / sleep.goal) * kQuestMax).clamp(0, kQuestMax).toInt() : 0;
    final move = ((health.steps / 10000) * kQuestMax).clamp(0, kQuestMax).toInt();
    final train = ((minutes / 30) * kQuestMax).clamp(0, kQuestMax).toInt();
    final restraint = fast.fastedToday ? kQuestMax : 0;

    final quests = <QuestId, int>{
      QuestId.nourish:   nourish,
      QuestId.hydrate:   hydrate,
      QuestId.rest:      rest,
      QuestId.move:      move,
      QuestId.train:     train,
      QuestId.stillness: stillness,
      QuestId.restraint: restraint,
      QuestId.wholesome: wholesome,
    };

    final score = quests.values
        .fold(0, (s, v) => s + v.clamp(0, kQuestMax));
    final allDone = quests.values.every((v) => v >= kQuestMax);

    // Chain excludes today so the multiplier can't chase its own tail.
    final chain = await _chainLength();
    final xp = xpForDay(score: score, chainDays: chain, allQuests: allDone);

    await AppDatabase.upsertAscent({
      'nourish':   nourish,
      'hydrate':   hydrate,
      'rest':      rest,
      'move':      move,
      'train':     train,
      'stillness': stillness,
      'restraint': restraint,
      'wholesome': wholesome,
      'score':     score,
      'xp':        xp,
    });

    final totalXp = await AppDatabase.getLifetimeXp();
    final week    = await AppDatabase.getWeeklyAscent();
    final weekBest = week.fold<int>(
        0, (b, r) => ((r['score'] as int?) ?? 0) > b ? (r['score'] as int) : b);

    final previousLevel = state.loading ? levelFromXp(totalXp) : state.level;
    final newLevel = levelFromXp(totalXp);
    if (newLevel > previousLevel) pendingLevelUp = newLevel;

    state = AscentState(
      quests: quests, totalXp: totalXp, chain: chain,
      weekBest: weekBest, loading: false,
    );

    _ref.read(titleProvider.notifier).evaluate(
        state, fast, _ref.read(streakProvider));
  }

  /// Consecutive qualifying days directly before today (today itself is
  /// still in progress, so it never counts toward its own multiplier).
  Future<int> _chainLength() async {
    final days = (await AppDatabase.getQualifyingDays()).toSet();
    var count = 0;
    var cursor = DateTime.now().subtract(const Duration(days: 1));
    while (count < 400) {
      final key = '${cursor.year}-'
          '${cursor.month.toString().padLeft(2, '0')}-'
          '${cursor.day.toString().padLeft(2, '0')}';
      if (!days.contains(key)) break;
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Marks the stillness quest done / undone for today.
  Future<void> toggleStillness() async {
    final row = await AppDatabase.getTodayAscent();
    final on = (row?['stillness'] as int? ?? 0) >= kQuestMax;
    await AppDatabase.upsertAscent({'stillness': on ? 0 : kQuestMax});
    await _sync();
  }

  /// Credits the wholesome-food quest — called when a whole food is logged.
  Future<void> creditWholesome({int points = 45}) async {
    final row = await AppDatabase.getTodayAscent();
    final current = row?['wholesome'] as int? ?? 0;
    if (current >= kQuestMax) return;
    await AppDatabase.upsertAscent(
        {'wholesome': (current + points).clamp(0, kQuestMax)});
    await _sync();
  }

  void consumeLevelUp() => pendingLevelUp = null;

  /// Call after any quest-affecting action to keep the score live.
  Future<void> refresh() => _sync();
}

final ascentProvider =
    StateNotifierProvider<AscentNotifier, AscentState>(
        (ref) => AscentNotifier(ref));

final ascentWeekProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(ascentProvider);
  return AppDatabase.getWeeklyAscent();
});

// ──────────────────────────────────────────────────────────────────
// TITLES — permanent unlocks, stored as a Set<int> in prefs
// ──────────────────────────────────────────────────────────────────

class TitleState {
  final Set<int> earned;
  const TitleState({required this.earned});
}

class TitleNotifier extends StateNotifier<TitleState> {
  TitleNotifier() : super(const TitleState(earned: {})) { _load(); }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    // Migrate the old key on first run so nobody loses what they earned.
    final list = p.getStringList('ascent_titles')
        ?? p.getStringList('barakah_badges')
        ?? const <String>[];
    state = TitleState(
        earned: list.map((e) => int.tryParse(e) ?? 0)
            .where((e) => e > 0).toSet());
  }

  Future<void> _unlock(int id) async {
    if (state.earned.contains(id)) return;
    final next = {...state.earned, id};
    state = TitleState(earned: next);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'ascent_titles', next.map((e) => e.toString()).toList());
  }

  void evaluate(AscentState a, FastingState fast, int streak) {
    if (a.score >= 500) _unlock(9);
    if (a.score >= 700) _unlock(10);
    if (a.score >= 900) _unlock(11);
    if (a.allQuestsDone) _unlock(15);

    if (streak >= 1)   _unlock(1);
    if (a.chain >= 7)   _unlock(2);
    if (a.chain >= 14)  _unlock(17);
    if (a.chain >= 30)  _unlock(18);
    if (a.chain >= 100) _unlock(14);
    if (a.chain >= 100 && a.allQuestsDone) _unlock(20);

    if (fast.lifetimeCount >= 1) _unlock(3);
    if (fast.lifetimeCount >= 7) _unlock(4);
    if (streak >= 28 && fast.lifetimeCount >= 4) _unlock(13);

    if (a.isDone(QuestId.stillness)) _unlock(12);
    if (a.isDone(QuestId.train))     _unlock(7);

    if (a.level >= 10) _unlock(21);
    if (a.level >= 20) _unlock(22);
    if (a.level >= 35) _unlock(23);
    if (a.level >= 55) _unlock(24);
  }

  void unlockTrainingWeek() => _unlock(8);
  void unlockWholesome()    => _unlock(5);
  void unlockTideKeeper()   => _unlock(6);
  void unlockDawnRiser()    => _unlock(16);
  void unlockWayfarer()     => _unlock(19);
}

final titleProvider =
    StateNotifierProvider<TitleNotifier, TitleState>(
        (ref) => TitleNotifier());


/// Real version and build number from the package, so the About row can
/// never drift from what was actually shipped.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version} (${info.buildNumber})';
  } catch (_) {
    return '';
  }
});

final routerProvider = Provider<GoRouter>((ref) => AppRouter.router(ref));


// ── AI Scan usage counter (free tier: 3 scans) ───────────────────────
const _kScanCountKey = 'ai_scan_count';

final scanCountProvider = StateNotifierProvider<ScanCountNotifier, int>((ref) {
  return ScanCountNotifier();
});

class ScanCountNotifier extends StateNotifier<int> {
  ScanCountNotifier() : super(0) { _load(); }

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString('ai_scan_date') ?? '';
    if (savedDate != _today()) {
      await prefs.setString('ai_scan_date', _today());
      await prefs.setInt(_kScanCountKey, 0);
      state = 0;
    } else {
      state = prefs.getInt(_kScanCountKey) ?? 0;
    }
  }

  bool get canScan => state < 3;

  Future<void> increment() async {
    state++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kScanCountKey, state);
    await prefs.setString('ai_scan_date', _today());
  }

  Future<void> reset() async {
    state = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kScanCountKey);
  }

}

