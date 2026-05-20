import 'package:flutter/material.dart' show Color;
// providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart'; import'package:shared_preferences/shared_preferences.dart'; import'package:go_router/go_router.dart'; import'../data/models/models.dart'; import'../data/models/user_profile.dart'; import'router.dart'; import'revenuecat_service.dart'; import'database.dart'; import'health_service.dart';

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

// ── Sunnah Fast Tracker ─────────────────────────────────
class SunnahFastState {
  final bool fastedToday;
  final int streak;
  final int lifetimeCount;
  final List<String> fastDates; // yyyy-MM-dd
  const SunnahFastState({
    this.fastedToday = false, this.streak = 0,
    this.lifetimeCount = 0, this.fastDates = const [],
  });
}

class SunnahFastNotifier extends StateNotifier<SunnahFastState> {
  SunnahFastNotifier() : super(const SunnahFastState()) { _load(); }

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
    state = SunnahFastState(
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

final sunnahFastProvider = StateNotifierProvider<SunnahFastNotifier, SunnahFastState>(
  (ref) => SunnahFastNotifier());

// ── Achievement Badges ────────────────────────────────────
class AchievementState {
  final int totalDaysLogged, sunnahFastCount, sunnahFoodsLogged;
  const AchievementState({
    this.totalDaysLogged = 0, this.sunnahFastCount = 0,
    this.sunnahFoodsLogged = 0,
  });
}

class AchievementNotifier extends StateNotifier<AchievementState> {
  AchievementNotifier() : super(const AchievementState()) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = AchievementState(
      totalDaysLogged:   p.getInt('ach_days_logged')  ?? 0,
      sunnahFastCount:   p.getInt('ach_sunnah_fasts') ?? 0,
      sunnahFoodsLogged: p.getInt('ach_sunnah_foods') ?? 0,
    );
  }
  Future<void> incrementDay() async {
    final p = await SharedPreferences.getInstance();
    final v = (p.getInt('ach_days_logged') ?? 0) + 1;
    await p.setInt('ach_days_logged', v);
    state = AchievementState(totalDaysLogged: v,
      sunnahFastCount: state.sunnahFastCount,
      sunnahFoodsLogged: state.sunnahFoodsLogged);
  }
  Future<void> incrementSunnahFood() async {
    final p = await SharedPreferences.getInstance();
    final v = (p.getInt('ach_sunnah_foods') ?? 0) + 1;
    await p.setInt('ach_sunnah_foods', v);
    state = AchievementState(totalDaysLogged: state.totalDaysLogged,
      sunnahFastCount: state.sunnahFastCount, sunnahFoodsLogged: v);
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
// BARAKAH ENGINE
// ══════════════════════════════════════════════════════════════════

class BarakahState {
  // 8 pillar scores — each 0..125 → total 0..1000
  final int nutrition;   // from calorie % goal
  final int hydration;   // from water cups
  final int sleep;       // from sleep hours
  final int movement;    // from step count
  final int fasting;     // sunnah fast today
  final int sunnahFood;  // sunnah foods logged today
  final int workout;     // workout minutes today
  final int dhikr;       // self-reported check-in

  const BarakahState({
    this.nutrition  = 0, this.hydration  = 0,
    this.sleep      = 0, this.movement   = 0,
    this.fasting    = 0, this.sunnahFood = 0,
    this.workout    = 0, this.dhikr      = 0,
  });

  int get score =>
      nutrition + hydration + sleep + movement +
      fasting + sunnahFood + workout + dhikr;

  // 0-1000 → tier label
  String tierEn() {
    if (score >= 900) return 'Radiant ✨';
    if (score >= 700) return 'Blessed 🌟';
    if (score >= 500) return 'Progressing 📈';
    if (score >= 300) return 'Rising 🌱';
    return 'Beginning 🤲';
  }
  String tierAr() {
    if (score >= 900) return 'مشرق ✨';
    if (score >= 700) return 'مبارك 🌟';
    if (score >= 500) return 'في تقدم 📈';
    if (score >= 300) return 'في الصعود 🌱';
    return 'في البداية 🤲';
  }

  Color tierColor() {
    if (score >= 900) return const Color(0xFFE8B84B);
    if (score >= 700) return const Color(0xFF3FB950);
    if (score >= 500) return const Color(0xFF58A6FF);
    if (score >= 300) return const Color(0xFFBC8CFF);
    return const Color(0xFF8B949E);
  }

  BarakahState copyWith({
    int? nutrition, int? hydration, int? sleep, int? movement,
    int? fasting, int? sunnahFood, int? workout, int? dhikr,
  }) => BarakahState(
    nutrition:  nutrition  ?? this.nutrition,
    hydration:  hydration  ?? this.hydration,
    sleep:      sleep      ?? this.sleep,
    movement:   movement   ?? this.movement,
    fasting:    fasting    ?? this.fasting,
    sunnahFood: sunnahFood ?? this.sunnahFood,
    workout:    workout    ?? this.workout,
    dhikr:      dhikr      ?? this.dhikr,
  );
}

class BarakahNotifier extends StateNotifier<BarakahState> {
  final Ref _ref;
  BarakahNotifier(this._ref) : super(const BarakahState()) { _sync(); }

  /// Called whenever user data changes — recomputes all 8 pillars.
  Future<void> _sync() async {
    final cals    = _ref.read(caloriesProvider);
    final water   = _ref.read(waterProvider);
    final sleep   = _ref.read(sleepProvider);
    final health  = _ref.read(healthProvider);
    final wMin    = _ref.read(workoutMinutesProvider);
    final fast    = _ref.read(sunnahFastProvider);

    // Load persisted dhikr from db
    final row     = await AppDatabase.getTodayBarakah();
    final dhikrOn = (row?['dhikr'] as int? ?? 0) == 1;

    // ── Pillar calculations (each caps at 125) ──────────────────
    // Nutrition: % of calorie goal eaten (80-110% = perfect 125)
    final calPct = cals.goal > 0 ? cals.total / cals.goal : 0.0;
    final nutScore = calPct >= 0.8 && calPct <= 1.1
        ? 125 : (calPct >= 0.6 ? 80 : 40);

    // Hydration: 8 cups = 125
    final hydScore = ((water.cups / water.goal) * 125).clamp(0, 125).toInt();

    // Sleep: 8h = 125
    final slpScore = ((sleep.hours / sleep.goal) * 125).clamp(0, 125).toInt();

    // Movement: 10,000 steps = 125
    final movScore = ((health.steps / 10000) * 125).clamp(0, 125).toInt();

    // Fasting: sunnah fast today = 125
    final fstScore = fast.fastedToday ? 125 : 0;

    // Sunnah food: loaded from db (set externally)
    final sfScore  = (row?['sunnah_food'] as int? ?? 0).clamp(0, 125);

    // Workout: 30+ min = 125
    final wrkScore = (wMin >= 30 ? 125 : ((wMin / 30) * 125).toInt()).clamp(0, 125);

    // Dhikr: self-reported toggle
    final dhkScore = dhikrOn ? 125 : 0;

    final newState = BarakahState(
      nutrition:  nutScore, hydration:  hydScore,
      sleep:      slpScore, movement:   movScore,
      fasting:    fstScore, sunnahFood: sfScore,
      workout:    wrkScore, dhikr:      dhkScore,
    );

    state = newState;

    // Persist to DB
    await AppDatabase.upsertBarakah(
      nutrition:  nutScore, hydration:  hydScore,
      sleep:      slpScore, movement:   movScore,
      fasting:    fstScore, sunnahFood: sfScore,
      workout:    wrkScore, dhikr:      dhkScore,
      score:      newState.score,
    );

    // Cascade badge check
    _ref.read(badgeProvider.notifier).evaluate(newState, fast, _ref.read(streakProvider));
  }

  Future<void> toggleDhikr() async {
    final row    = await AppDatabase.getTodayBarakah();
    final wasOn  = (row?['dhikr'] as int? ?? 0) == 1;
    await AppDatabase.upsertBarakah(dhikr: wasOn ? 0 : 1);
    await _sync();
  }

  /// Call after any pillar-affecting action to keep score live.
  void refresh() => _sync();
}

final barakahProvider =
    StateNotifierProvider<BarakahNotifier, BarakahState>(
        (ref) => BarakahNotifier(ref));

final barakahWeekProvider = FutureProvider<List<Map<String,dynamic>>>((ref) async {
  ref.watch(barakahProvider);
  return AppDatabase.getWeeklyBarakah();
});

// ──────────────────────────────────────────────────────────────────
// BADGE SYSTEM — 20 badges stored in SharedPreferences as a Set<int>
// ──────────────────────────────────────────────────────────────────

class BadgeState {
  final Set<int> earned; // badge IDs that have been unlocked
  const BadgeState({required this.earned});
}

// Static badge definitions
class AppBadge {
  final int    id;
  final String emoji;
  final String nameAr;
  final String nameEn;
  final String descAr;
  final String descEn;
  const AppBadge({required this.id, required this.emoji,
    required this.nameAr, required this.nameEn,
    required this.descAr, required this.descEn});
}

const kBadges = [
  AppBadge(id:  1, emoji: '🌱', nameAr: 'الأولى',      nameEn: 'First Step',
    descAr: 'سجّل أول يوم', descEn: 'Log your first day'),
  AppBadge(id:  2, emoji: '📅', nameAr: 'أسبوع',        nameEn: 'Week Warrior',
    descAr: '٧ أيام متتالية', descEn: '7-day streak'),
  AppBadge(id:  3, emoji: '🌙', nameAr: 'صائم السنة',   nameEn: 'Sunnah Faster',
    descAr: 'أول صيام سنة', descEn: 'First sunnah fast'),
  AppBadge(id:  4, emoji: '🏆', nameAr: 'محارب السنة',  nameEn: 'Sunnah Warrior',
    descAr: '٧ صيامات سنة', descEn: '7 sunnah fasts'),
  AppBadge(id:  5, emoji: '🍯', nameAr: 'طعام نبوي',    nameEn: 'Sunnah Chef',
    descAr: 'سجّل ٣ أطعمة سنة', descEn: 'Log 3 sunnah foods'),
  AppBadge(id:  6, emoji: '💧', nameAr: 'حارس الماء',   nameEn: 'Water Guardian',
    descAr: 'أكمل هدف الماء ٣ أيام', descEn: 'Hit water goal 3 days'),
  AppBadge(id:  7, emoji: '💪', nameAr: 'المجاهد',       nameEn: 'Al-Mujahid',
    descAr: '٣٠ دقيقة تمرين', descEn: '30 min workout'),
  AppBadge(id:  8, emoji: '🔥', nameAr: 'مشتعل',         nameEn: 'On Fire',
    descAr: '٣ تمارين في أسبوع', descEn: '3 workouts in a week'),
  AppBadge(id:  9, emoji: '🌟', nameAr: 'بركة ٥٠٠',      nameEn: 'Barakah 500',
    descAr: 'نقاط بركة ≥ ٥٠٠', descEn: 'Barakah score ≥ 500'),
  AppBadge(id: 10, emoji: '🌠', nameAr: 'بركة ٧٠٠',      nameEn: 'Barakah 700',
    descAr: 'نقاط بركة ≥ ٧٠٠', descEn: 'Barakah score ≥ 700'),
  AppBadge(id: 11, emoji: '✨', nameAr: 'مشرق',           nameEn: 'Radiant',
    descAr: 'نقاط بركة ≥ ٩٠٠', descEn: 'Barakah score ≥ 900'),
  AppBadge(id: 12, emoji: '🤲', nameAr: 'الذاكر',         nameEn: 'The Rememberer',
    descAr: 'أول ذكر يومي', descEn: 'First daily dhikr check-in'),
  AppBadge(id: 13, emoji: '📖', nameAr: 'النية',          nameEn: 'Niyyah Master',
    descAr: '٢٨ يوم + ٤ صيامات', descEn: '28 days + 4 fasts'),
  AppBadge(id: 14, emoji: '💎', nameAr: 'مئة يوم',        nameEn: 'Centurion',
    descAr: '١٠٠ يوم تتابع', descEn: '100-day streak'),
  AppBadge(id: 15, emoji: '🕌', nameAr: 'السلوك الكامل', nameEn: 'Full Sunnah',
    descAr: 'أكمل كل أعمدة البركة', descEn: 'Complete all 8 pillars in one day'),
  AppBadge(id: 16, emoji: '🌅', nameAr: 'الفجر المبكر',  nameEn: 'Fajr Riser',
    descAr: 'سجّل تمرين قبل الساعة ٦', descEn: 'Log workout before 6 AM'),
  AppBadge(id: 17, emoji: '⚡', nameAr: 'العزيمة',        nameEn: 'Azimah',
    descAr: '١٤ يوم متتالية', descEn: '14-day streak'),
  AppBadge(id: 18, emoji: '🎖️', nameAr: 'شهر كامل',     nameEn: 'Full Month',
    descAr: '٣٠ يوم تتابع', descEn: '30-day streak'),
  AppBadge(id: 19, emoji: '🌍', nameAr: 'المسافر الصالح', nameEn: 'Righteous Traveller',
    descAr: 'استخدم التطبيق بـ ٣ لغات', descEn: 'Use the app in 3 languages'),
  AppBadge(id: 20, emoji: '👑', nameAr: 'خير المؤمنين',  nameEn: 'Best Believer',
    descAr: 'كل الأعمدة + ١٠٠ يوم', descEn: 'All pillars + 100-day streak'),
];

class BadgeNotifier extends StateNotifier<BadgeState> {
  BadgeNotifier() : super(const BadgeState(earned: {})) { _load(); }

  Future<void> _load() async {
    final p    = await SharedPreferences.getInstance();
    final list = p.getStringList('barakah_badges') ?? [];
    state = BadgeState(earned: list.map(int.parse).toSet());
  }

  Future<void> _unlock(int id) async {
    if (state.earned.contains(id)) return;
    final newSet = {...state.earned, id};
    state = BadgeState(earned: newSet);
    final p = await SharedPreferences.getInstance();
    await p.setStringList('barakah_badges', newSet.map((e) => e.toString()).toList());
  }

  void evaluate(BarakahState b, SunnahFastState fast, int streak) {
    // Score-based badges
    if (b.score >= 500) _unlock(9);
    if (b.score >= 700) _unlock(10);
    if (b.score >= 900) _unlock(11);
    // All 8 pillars active today
    if ([b.nutrition, b.hydration, b.sleep, b.movement,
         b.fasting, b.sunnahFood, b.workout, b.dhikr].every((v) => v > 0)) _unlock(15);
    // Streak badges
    if (streak >=   1) _unlock(1);
    if (streak >=   7) _unlock(2);
    if (streak >=  14) _unlock(17);
    if (streak >=  30) _unlock(18);
    if (streak >= 100) _unlock(14);
    if (streak >= 100 &&
        [b.nutrition, b.hydration, b.sleep, b.movement,
         b.fasting, b.sunnahFood, b.workout, b.dhikr].every((v) => v > 0)) _unlock(20);
    // Fasting badges
    if (fast.lifetimeCount >=  1) _unlock(3);
    if (fast.lifetimeCount >=  7) _unlock(4);
    // Dhikr badge
    if (b.dhikr > 0) _unlock(12);
    // Workout badge
    if (b.workout >= 125) _unlock(7);
    // Niyyah master: 28 days + 4 fasts
    if (streak >= 28 && fast.lifetimeCount >= 4) _unlock(13);
  }

  void unlockWorkoutWeek() => _unlock(8);
  void unlockSunnahChef()  => _unlock(5);
  void unlockWaterGuard()  => _unlock(6);
  void unlockFajrRiser()   => _unlock(16);
}

final badgeProvider =
    StateNotifierProvider<BadgeNotifier, BadgeState>(
        (ref) => BadgeNotifier());

final routerProvider = Provider<GoRouter>((ref) => AppRouter.router(ref));
