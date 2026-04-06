import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../data/models/models.dart';
import '../data/models/user_profile.dart';
import 'router.dart';
import 'database.dart';
import 'health_service.dart';
import 'revenuecat_service.dart';

// Language
final languageProvider = StateNotifierProvider<LanguageNotifier, String>(
  (ref) => LanguageNotifier(),
);
class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('ar') { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getString('language') ?? 'ar';
    } catch (_) {}
  }
  Future<void> set(String lang) async {
    state = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString('language', lang);
  }
}

// Theme
final themeProvider = StateNotifierProvider<ThemeNotifier, bool>(
  (ref) => ThemeNotifier(),
);
class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(true) { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getBool('dark_mode') ?? true;
    } catch (_) {}
  }
  Future<void> toggle() async {
    state = !state;
    final p = await SharedPreferences.getInstance();
    await p.setBool('dark_mode', state);
  }
}

// Onboarding
final onboardingDoneProvider = StateNotifierProvider<OnboardingNotifier, bool>(
  (ref) => OnboardingNotifier(),
);
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(true) {}
  Future<void> complete() async {
    state = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', true);
  }
  Future<void> reset() async {
    state = false;
    final p = await SharedPreferences.getInstance();
    await p.setBool('onboarding_done', false);
  }
}

// Router
final routerProvider = Provider<GoRouter>((ref) => AppRouter.router(ref));

// Gender
final genderProvider = StateNotifierProvider<GenderNotifier, String>(
  (ref) => GenderNotifier(),
);
class GenderNotifier extends StateNotifier<String> {
  GenderNotifier() : super('brothers') { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getString('gender') ?? 'brothers';
    } catch (_) {}
  }
  Future<void> set(String g) async {
    state = g;
    final p = await SharedPreferences.getInstance();
    await p.setString('gender', g);
  }
}

// User Profile
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile?>(
  (ref) => UserProfileNotifier(),
);
class UserProfileNotifier extends StateNotifier<UserProfile?> {
  UserProfileNotifier() : super(null) { _load(); }
  Future<void> _load() async {
    try { state = await UserProfileRepository.load(); } catch (_) {}
  }
  Future<void> save(UserProfile profile) async {
    await UserProfileRepository.save(profile); state = profile;
  }
  Future<void> clear() async { await UserProfileRepository.clear(); state = null; }
}

// Premium
final premiumProvider = StateNotifierProvider<PremiumNotifier, bool>(
  (ref) => PremiumNotifier(),
);
class PremiumNotifier extends StateNotifier<bool> {
  PremiumNotifier() : super(false) { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getBool('is_premium') ?? false;
    } catch (_) {}
  }
  Future<void> onPurchaseSuccess() async {
    state = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool('is_premium', true);
  }
  Future<void> refresh() async {}
  Future<void> unlock() async {
    state = true;
    final p = await SharedPreferences.getInstance();
    await p.setBool('is_premium', true);
  }
  Future<void> revoke() async {
    state = false;
    final p = await SharedPreferences.getInstance();
    await p.setBool('is_premium', false);
  }
}

final planNameProvider = FutureProvider<String>((ref) async => 'free');
final rcOfferingsProvider = FutureProvider<List<RCOffering>>((ref) async => []);

// Streak
final streakProvider = StateNotifierProvider<StreakNotifier, int>(
  (ref) => StreakNotifier(),
);
class StreakNotifier extends StateNotifier<int> {
  StreakNotifier() : super(0) { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getInt('streak') ?? 0;
    } catch (_) {}
  }
  Future<void> increment() async {
    final newStreak = state + 1;
    state = newStreak;
    final p = await SharedPreferences.getInstance();
    await p.setInt('streak', newStreak);
  }
  Future<void> reset() async {
    state = 0;
    final p = await SharedPreferences.getInstance();
    await p.setInt('streak', 0);
  }
}

// Health Permission — no platform calls in constructor
final healthPermProvider = StateNotifierProvider<HealthPermNotifier, bool>(
  (ref) => HealthPermNotifier(),
);
class HealthPermNotifier extends StateNotifier<bool> {
  HealthPermNotifier() : super(false);
  Future<void> request() async {
    try {
      final svc = HealthService();
      state = await svc.requestPermission();
    } catch (_) { state = false; }
  }
}

// Steps
final stepsProvider = StateNotifierProvider<StepsNotifier, int>(
  (ref) => StepsNotifier(),
);
class StepsNotifier extends StateNotifier<int> {
  StepsNotifier() : super(0) { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getInt('steps_today') ?? 0;
    } catch (_) {}
  }
  Future<void> update(int steps) async {
    state = steps;
    final p = await SharedPreferences.getInstance();
    await p.setInt('steps_today', steps);
  }
}

// Calories
class CaloriesState {
  final int total, goal;
  final double percent;
  final List<FoodEntry> entries;
  final double proteinTotal, carbsTotal, fatTotal;
  const CaloriesState({
    this.total = 0, this.goal = 2000, this.percent = 0,
    this.entries = const [], this.proteinTotal = 0,
    this.carbsTotal = 0, this.fatTotal = 0,
  });
}

final caloriesProvider = StateNotifierProvider<CaloriesNotifier, CaloriesState>(
  (ref) => CaloriesNotifier(),
);
class CaloriesNotifier extends StateNotifier<CaloriesState> {
  CaloriesNotifier() : super(const CaloriesState()) { _load(); }
  Future<void> _load() async {
    try {
      final entries = await AppDatabase.getTodayEntries();
      final goal = await _loadGoal();
      _update(entries, goal);
    } catch (_) {}
  }
  Future<int> _loadGoal() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getInt('calorie_goal') ?? 2000;
    } catch (_) { return 2000; }
  }
  void _update(List<FoodEntry> entries, int goal) {
    final total = entries.fold(0, (s, e) => s + e.kcal);
    final protein = entries.fold(0.0, (s, e) => s + e.proteinG);
    final carbs = entries.fold(0.0, (s, e) => s + e.carbsG);
    final fat = entries.fold(0.0, (s, e) => s + e.fatG);
    state = CaloriesState(
      total: total, goal: goal,
      percent: goal > 0 ? (total / goal).clamp(0.0, 1.0) : 0,
      entries: entries, proteinTotal: protein,
      carbsTotal: carbs, fatTotal: fat,
    );
  }
  Future<void> addEntry(FoodEntry entry) async {
    try {
      await AppDatabase.insertEntry(entry);
      await _load();
    } catch (_) {}
  }
  Future<void> removeEntry(int id) async {
    try {
      await AppDatabase.deleteEntry(id);
      await _load();
    } catch (_) {}
  }
  Future<void> reloadFromDb() async { await _load(); }
  Future<void> setGoal(int goal) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('calorie_goal', goal);
    await _load();
  }
  Future<void> syncWithProfile(UserProfile profile) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('calorie_goal', profile.dailyCalorieGoal);
    await _load();
  }
}

final weeklyKcalProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try { return await AppDatabase.getWeeklyKcal(); } catch (_) { return []; }
});

// Water
final waterProvider = StateNotifierProvider<WaterNotifier, int>(
  (ref) => WaterNotifier(),
);
class WaterNotifier extends StateNotifier<int> {
  WaterNotifier() : super(0) { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getInt('water_today') ?? 0;
    } catch (_) {}
  }
  Future<void> add(int ml) async {
    state += ml;
    final p = await SharedPreferences.getInstance();
    await p.setInt('water_today', state);
  }
  Future<void> reset() async {
    state = 0;
    final p = await SharedPreferences.getInstance();
    await p.setInt('water_today', 0);
  }
}

// Sleep
final sleepProvider = StateNotifierProvider<SleepNotifier, double>(
  (ref) => SleepNotifier(),
);
class SleepNotifier extends StateNotifier<double> {
  SleepNotifier() : super(0) { _load(); }
  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = p.getDouble('sleep_hours') ?? 0;
    } catch (_) {}
  }
  Future<void> set(double hours) async {
    state = hours;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('sleep_hours', hours);
  }
}

// Health data
final healthProvider = StateNotifierProvider<HealthNotifier, Map<String, dynamic>>(
  (ref) => HealthNotifier(),
);
class HealthNotifier extends StateNotifier<Map<String, dynamic>> {
  HealthNotifier() : super({
    'steps': 0, 'heartRate': 0, 'sleepHours': 0.0,
    'activeMinutes': 0, 'caloriesBurned': 0,
  });
  Future<void> refresh() async {}
  void update(Map<String, dynamic> data) { state = {...state, ...data}; }
}

// Referral
final referralProvider = StateNotifierProvider<ReferralNotifier, Map<String, dynamic>>(
  (ref) => ReferralNotifier(),
);
class ReferralNotifier extends StateNotifier<Map<String, dynamic>> {
  ReferralNotifier() : super({'code': 'HALAL2024', 'count': 0, 'freeMonths': 0});
  Future<void> load() async {}
  Future<bool> applyCode(String code) async { return false; }
}

// Weekly report
final weeklyReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return {
    'avgCalories': 0, 'totalWorkouts': 0, 'avgSteps': 0,
    'avgSleep': 0.0, 'avgWater': 0,
  };
});
