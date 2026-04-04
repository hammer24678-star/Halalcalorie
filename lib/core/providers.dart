// providers.dart — HalalCalorie v1.0
// Full SQLite-backed state management
import 'package:flutter_riverpod/flutter_riverpod.dart'; import'package:shared_preferences/shared_preferences.dart'; import'package:go_router/go_router.dart'; import'../data/models/models.dart'; import'../data/models/user_profile.dart'; import'router.dart'; import'revenuecat_service.dart'; import'database.dart'; import'health_service.dart';

// ── Language ───────────────────────────────────────────────
final languageProvider = StateNotifierProvider<LanguageNotifier, String>(
  (ref) => LanguageNotifier(),
);
class LanguageNotifier extends StateNotifier<String> { LanguageNotifier() : super('ar') { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getString('language') ?? 'ar';
  }
  Future<void> set(String lang) async {
    state = lang;
    final p = await SharedPreferences.getInstance(); await p.setString('language', lang);
  }
}

// ── Theme ──────────────────────────────────────────────────
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>(
  (ref) => ThemeNotifier(),
);
class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(true) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getBool('dark_mode') ?? true;
  }
  Future<void> toggle() async {
    state = !state;
    final p = await SharedPreferences.getInstance(); await p.setBool('dark_mode', state);
  }
}

// ── Onboarding ─────────────────────────────────────────────
final onboardingDoneProvider = StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) => OnboardingNotifier(),
);
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getBool('onboarding_done') ?? false;
  }
  Future<void> complete() async {
    state = true;
    final p = await SharedPreferences.getInstance(); await p.setBool('onboarding_done', true);
  }
  Future<void> reset() async {
    state = false;
    final p = await SharedPreferences.getInstance(); await p.setBool('onboarding_done', false);
  }
}

// ── Gender ─────────────────────────────────────────────────
final genderProvider = StateNotifierProvider<GenderNotifier, String>(
  (ref) => GenderNotifier(),
);
class GenderNotifier extends StateNotifier<String> { GenderNotifier() : super('brothers') { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getString('gender') ?? 'brothers';
  }
  Future<void> set(String g) async {
    state = g;
    final p = await SharedPreferences.getInstance(); await p.setString('gender', g);
  }
}

// ── User Profile ───────────────────────────────────────────
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile?>(
  (ref) => UserProfileNotifier(),
);
class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier() : super(null) { _load(); }
  Future<void> _load() async { state = await UserProfileRepository.load(); }
  Future<void> save(UserProfile profile) async {
    await UserProfileRepository.save(profile); state = profile;
  }
  Future<void> clear() async { await UserProfileRepository.clear(); state = null; }
}

// ── Premium (RevenueCat-backed) ────────────────────────────
final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>(
  (ref) => PremiumNotifier(),
);
class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier() : super(false) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getBool('is_premium') ?? false;
    final live = await RevenueCatService.isPremium();
    if (live != state) {
      state = live; await p.setBool('is_premium', live);
    }
  }
  Future<void> onPurchaseSuccess() async {
    state = true;
    final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', true);
  }
  Future<void> refresh() async {
    final live = await RevenueCatService.isPremium();
    state = live;
    final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', live);
  }
  Future<void> unlock() async {
    state = true;
    final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', true);
  }
  Future<void> revoke() async {
    state = false;
    final p = await SharedPreferences.getInstance(); await p.setBool('is_premium', false);
  }
}

final planNameProvider = FutureProvider<String>((ref) async {
  final isPrem = ref.watch(premiumProvider); if (!isPrem) return'free';
  return RevenueCatService.getActivePlanId();
});

final rcOfferingsProvider = FutureProvider<List<RCOffering>>((ref) async {
  return RevenueCatService.getOfferings();
});

// ── Streak (persisted) ────────────────────────────────────
final streakProvider = StateNotifierProvider<StreakNotifier, int>(
  (ref) => StreakNotifier(),
);
class StreakNotifier extends StateNotifier<int> {
  StreakNotifier() : super(0) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); final lastDate = p.getString('streak_last_date') ?? '';
    final today    = _dateKey(); final streak   = p.getInt('streak') ?? 0;
    // If last activity was yesterday → keep streak; today → keep; older → reset
    if (lastDate == today) {
      state = streak;
    } else if (lastDate == _yesterday()) {
      state = streak; // will increment when workout done today
    } else if (lastDate.isEmpty) {
      state = 0;
    } else {
      // Streak broken — reset
      state = 0; await p.setInt('streak', 0);
    }
  }
  Future<void> increment() async {
    final p       = await SharedPreferences.getInstance();
    final today   = _dateKey(); final lastDate = p.getString('streak_last_date') ?? '';
    if (lastDate == today) return; // already incremented today
    final newStreak = (lastDate == _yesterday()) ? state + 1 : 1;
    state = newStreak; await p.setInt('streak', newStreak); await p.setString('streak_last_date', today);
  }
  String _dateKey() {
    final n = DateTime.now(); return'${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }
  String _yesterday() {
    final y = DateTime.now().subtract(const Duration(days: 1)); return'${y.year}-${y.month.toString().padLeft(2,'0')}-${y.day.toString().padLeft(2,'0')}';
  }
}

// ── Calories (SQLite-backed) ────────────────────────────────
final caloriesProvider = StateNotifierProvider<CaloriesNotifier, CaloriesState>(
  (ref) => CaloriesNotifier(ref),
);

class CaloriesState {
  final int goal;
  final List<MealEntry> entries;
  CaloriesState({required this.goal, required this.entries});
  int    get total     => entries.fold(0, (s, e) => s + e.kcal);
  int    get remaining => (goal - total).clamp(0, 99999);
  double get percent   => goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0.0;
  double get proteinTotal => entries.fold(0.0, (s, e) => s + e.proteinG);
  double get carbsTotal   => entries.fold(0.0, (s, e) => s + e.carbsG);
  double get fatTotal     => entries.fold(0.0, (s, e) => s + e.fatG);
}

class CaloriesNotifier extends StateNotifier<CaloriesState> {
  final Ref _ref;
  CaloriesNotifier(this._ref) : super(CaloriesState(goal: 2000, entries: [])) {
    _init();
    _ref.listen(userProfileProvider, (_, profile) {
      if (profile != null) syncWithProfile(profile);
    });
  }
  Future<void> _init() async {
    final p    = _ref.read(userProfileProvider);
    final goal = p?.calorieGoalKcal.toInt() ?? 2000;
    final rows = await AppDatabase.getTodayMeals();
    final entries = rows.asMap().entries.map((e) => MealEntry( id:       e.value['id'] as int, name:     e.value['name'] as String, kcal:     e.value['kcal'] as int, proteinG: (e.value['protein_g'] as num?)?.toDouble() ?? 0, carbsG:   (e.value['carbs_g'] as num?)?.toDouble() ?? 0, fatG:     (e.value['fat_g'] as num?)?.toDouble() ?? 0, time:     DateTime.tryParse(e.value['created'] as String? ?? '') ?? DateTime.now(),
    )).toList();
    state = CaloriesState(goal: goal, entries: entries);
  }
  void syncWithProfile(UserProfile p) {
    state = CaloriesState(goal: p.calorieGoalKcal.toInt(), entries: state.entries);
  }
  void setGoal(int g) => state = CaloriesState(goal: g.clamp(500, 9999), entries: state.entries);
  Future<void> addEntry(String name, int kcal, {double proteinG = 0, double carbsG = 0, double fatG = 0}) async {
    if (kcal <= 0) return;
    final id = await AppDatabase.insertMeal(
      name: name, kcal: kcal.clamp(1, 9999),
      proteinG: proteinG, carbsG: carbsG, fatG: fatG,
    );
    final entry = MealEntry(
      id: id, name: name, kcal: kcal.clamp(1, 9999), time: DateTime.now(),
      proteinG: proteinG, carbsG: carbsG, fatG: fatG,
    );
    state = CaloriesState(goal: state.goal, entries: [...state.entries, entry]);
  }
  Future<void> reloadFromDb() async {
    final rows = await AppDatabase.getTodayMeals();
    final entries = rows.map((e) => MealEntry(
      id:       e['id'] as int,
      name:     e['name'] as String,
      kcal:     e['kcal'] as int,
      proteinG: (e['protein_g'] as num?)?.toDouble() ?? 0,
      carbsG:   (e['carbs_g'] as num?)?.toDouble() ?? 0,
      fatG:     (e['fat_g'] as num?)?.toDouble() ?? 0,
      time:     DateTime.tryParse(e['created'] as String? ?? '') ?? DateTime.now(),
    )).toList();
    state = CaloriesState(goal: state.goal, entries: entries);
  }

  Future<void> removeEntry(int id) async {
    await AppDatabase.deleteMeal(id);
    state = CaloriesState(goal: state.goal,
        entries: state.entries.where((x) => x.id != id).toList());
  }
}

// ── Weekly Calories (for chart) ────────────────────────────
final weeklyKcalProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  ref.watch(caloriesProvider); // invalidate when entries change
  final rows = await AppDatabase.getWeeklyKcal(); return rows.map((r) => {'date': r.dateKey, 'kcal': r.kcal}).toList();
});

// ── Water ──────────────────────────────────────────────────
final waterProvider = StateNotifierProvider<WaterNotifier, WaterState>(
  (ref) => WaterNotifier(ref),
);
class WaterState {
  final int cups, goal;
  WaterState({required this.cups, required this.goal});
  double get percent => goal > 0 ? (cups / goal).clamp(0, 1) : 0;
}
class WaterNotifier extends StateNotifier<WaterState> {
  final Ref _ref;
  WaterNotifier(this._ref) : super(WaterState(cups: 0, goal: 8)) { _init(); }
  Future<void> _init() async {
    final p    = _ref.read(userProfileProvider);
    final goal = p?.waterCupsGoal ?? 8;
    final row  = await AppDatabase.getTodaySummary(); final cups = (row?['water_cups'] as int?) ?? 0;
    state = WaterState(cups: cups, goal: goal);
  }
  Future<void> add() async {
    final cups = (state.cups + 1).clamp(0, 20);
    state = WaterState(cups: cups, goal: state.goal);
    await AppDatabase.upsertSummary(waterCups: cups);
  }
  Future<void> remove() async {
    final cups = (state.cups - 1).clamp(0, 20);
    state = WaterState(cups: cups, goal: state.goal);
    await AppDatabase.upsertSummary(waterCups: cups);
  }
  void setGoal(int g) => state = WaterState(cups: state.cups, goal: g);
  Future<void> set(int cups) async {
    final c = cups.clamp(0, 20);
    state = WaterState(cups: c, goal: state.goal);
    await AppDatabase.upsertSummary(waterCups: c);
  }
}

// ── Sleep ──────────────────────────────────────────────────
final sleepProvider = StateNotifierProvider<SleepNotifier, SleepState>(
  (ref) => SleepNotifier(ref),
);
class SleepState {
  final double hours, goal;
  SleepState({required this.hours, required this.goal});
  double get percent => goal > 0 ? (hours / goal).clamp(0, 1) : 0;
  String qualityAr() { if (hours >= 8) return'نوم مثالي 😊'; if (hours >= 6) return'نوم كافٍ 😐'; return'نوم غير كافٍ 😔';
  }
  String qualityEn() { if (hours >= 8) return'Ideal sleep 😊'; if (hours >= 6) return'Adequate sleep 😐'; return'Insufficient sleep 😔';
  }
}
class SleepNotifier extends StateNotifier<SleepState> {
  final Ref _ref;
  SleepNotifier(this._ref) : super(SleepState(hours: 7, goal: 8)) { _init(); }
  Future<void> _init() async {
    final row  = await AppDatabase.getTodaySummary(); final hrs  = (row?['sleep_hrs'] as num?)?.toDouble() ?? 7.0;
    final p    = _ref.read(userProfileProvider);
    state = SleepState(hours: hrs, goal: p?.sleepHours ?? 8);
  }
  Future<void> set(double h) async {
    state = SleepState(hours: h.clamp(0, 24), goal: state.goal);
    await AppDatabase.upsertSummary(sleepHrs: h.clamp(0, 24));
  }
}

// ── Health ─────────────────────────────────────────────────
final healthProvider = StateNotifierProvider<HealthNotifier, HealthState>(
  (ref) => HealthNotifier(),
);
class HealthState {
  final int steps, stepsGoal, heartRate;
  final String? mood;
  final double? quickBmi;
  HealthState({this.steps = 0, this.stepsGoal = 10000, this.heartRate = 72,
                this.mood, this.quickBmi});
}
class HealthNotifier extends StateNotifier<HealthState> {
  HealthNotifier() : super(HealthState()) { _init(); }
  Future<void> _init() async {
    final row = await AppDatabase.getTodaySummary();
    if (row == null) return;
    state = HealthState( steps:     (row['steps'] as int?) ?? 0,
      stepsGoal: state.stepsGoal,
      heartRate: state.heartRate, mood:      row['mood'] as String?,
    );
  }
  Future<void> setSteps(int n) async {
    state = HealthState(steps: n.clamp(0, 99999), stepsGoal: state.stepsGoal,
        heartRate: state.heartRate, mood: state.mood, quickBmi: state.quickBmi);
    await AppDatabase.upsertSummary(steps: n.clamp(0, 99999));
  }
  Future<void> addSteps(int n) => setSteps(state.steps + n);
  void setHeartRate(int hr) => state = HealthState(
      steps: state.steps, stepsGoal: state.stepsGoal,
      heartRate: hr.clamp(30, 250), mood: state.mood, quickBmi: state.quickBmi);
  Future<void> setMood(String m) async {
    state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal,
        heartRate: state.heartRate, mood: m, quickBmi: state.quickBmi);
    await AppDatabase.upsertSummary(mood: m);
  }
  void setBMI(double w, double h) {
    if (h <= 0) return;
    final bmi = w / ((h / 100) * (h / 100));
    state = HealthState(steps: state.steps, stepsGoal: state.stepsGoal,
        heartRate: state.heartRate, mood: state.mood, quickBmi: bmi);
  }
}

// ── Workout minutes today ──────────────────────────────────
final workoutMinutesProvider = StateNotifierProvider<WorkoutMinutesNotifier, int>(
  (ref) => WorkoutMinutesNotifier(),
);
class WorkoutMinutesNotifier extends StateNotifier<int> {
  WorkoutMinutesNotifier() : super(0) { _init(); }
  Future<void> _init() async {
    state = await AppDatabase.getTodayWorkoutMinutes();
  }
  Future<void> add(String workoutId, int minutes) async {
    await AppDatabase.logWorkout(workoutId, minutes);
    state = state + minutes;
  }
}

// ── Scanner ────────────────────────────────────────────────
final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>(
  (ref) => ScanNotifier(),
);
class ScanState {
  final List<ScanResult> history;
  final int todayCount;
  ScanState({required this.history, required this.todayCount});
}
class ScanNotifier extends StateNotifier<ScanState> {
  ScanNotifier() : super(ScanState(history: [], todayCount: 0));
  void addScan(ScanResult r) => state = ScanState(
    history: [r, ...state.history.take(49)],
    todayCount: state.todayCount + 1,
  );
}

// ── Zakat ──────────────────────────────────────────────────
final zakatProvider = StateNotifierProvider<ZakatNotifier, double>(
  (ref) => ZakatNotifier(),
);
class ZakatNotifier extends StateNotifier<double> {
  ZakatNotifier() : super(0) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getDouble('zakat_amount') ?? 0;
  }
  Future<void> add(double amount) async {
    state += amount;
    final p = await SharedPreferences.getInstance(); await p.setDouble('zakat_amount', state);
  }
}

// ── City ───────────────────────────────────────────────────
final cityProvider = StateNotifierProvider<CityNotifier, String>(
  (ref) => CityNotifier(),
);
class CityNotifier extends StateNotifier<String> { CityNotifier() : super('القاهرة') { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getString('city') ?? 'القاهرة';
  }
  Future<void> set(String city) async {
    state = city;
    final p = await SharedPreferences.getInstance(); await p.setString('city', city);
  }
}

// ── Weight Log (SQLite-backed) ─────────────────────────────
final weightLogProvider = StateNotifierProvider<WeightLogNotifier, List<WeightEntry>>(
  (ref) => WeightLogNotifier(),
);
class WeightEntry {
  final int id;
  final DateTime date;
  final double weightKg;
  final String? note;
  WeightEntry({required this.id, required this.date, required this.weightKg, this.note});
}
class WeightLogNotifier extends StateNotifier<List<WeightEntry>> {
  WeightLogNotifier() : super([]) { _load(); }
  Future<void> _load() async {
    final rows = await AppDatabase.getWeightLog(limit: 60);
    state = rows.map((r) => WeightEntry( id:       r['id'] as int, date:     DateTime.tryParse(r['created'] as String? ?? '') ?? DateTime.now(), weightKg: (r['weight_kg'] as num).toDouble(), note:     r['note'] as String?,
    )).toList();
  }
  Future<void> add(double kg, {String? note}) async {
    final id = await AppDatabase.insertWeight(kg, note: note);
    final entry = WeightEntry(id: id, date: DateTime.now(), weightKg: kg, note: note);
    state = [...state, entry];
  }
  Future<void> remove(int id) async {
    await AppDatabase.deleteWeight(id);
    state = state.where((e) => e.id != id).toList();
  }
}

// ── Ramadan mode ───────────────────────────────────────────
final ramadanModeProvider = StateNotifierProvider<RamadanNotifier, bool>(
  (ref) => RamadanNotifier(),
);
class RamadanNotifier extends StateNotifier<bool> {
  RamadanNotifier() : super(false) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getBool('ramadan_mode') ?? false;
  }
  Future<void> toggle() async {
    state = !state;
    final p = await SharedPreferences.getInstance(); await p.setBool('ramadan_mode', state);
  }
}

// ── Notifications setting ──────────────────────────────────
final notificationsEnabledProvider = StateNotifierProvider<NotifNotifier, bool>(
  (ref) => NotifNotifier(),
);
class NotifNotifier extends StateNotifier<bool> {
  NotifNotifier() : super(true) { _load(); }
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance(); state = p.getBool('notifications_on') ?? true;
  }
  Future<void> toggle() async {
    state = !state;
    final p = await SharedPreferences.getInstance(); await p.setBool('notifications_on', state);
  }
}


// ── Real Health Data (Google Fit / Health Connect) ────────
final healthPermissionProvider = StateNotifierProvider<HealthPermNotifier, bool>(
  (ref) => HealthPermNotifier(),
);

class HealthPermNotifier extends StateNotifier<bool> {
  // Don't request permissions on init - causes crash before UI shows
  HealthPermNotifier() : super(false);
  Future<bool> request() async {
    try {
      final granted = await HealthService.requestPermissions();
      state = granted;
      return granted;
    } catch (_) { return false; }
  }
}

// ── Router ─────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) => AppRouter.router(ref));
