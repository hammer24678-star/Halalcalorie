// router.dart — HalalCalorie v1.0
import 'package:flutter/material.dart'; import'package:flutter_riverpod/flutter_riverpod.dart'; import'package:go_router/go_router.dart'; import'../features/onboarding/onboarding_screen.dart'; import'../features/home/home_screen.dart'; import'../features/scanner/scanner_screen.dart'; import'../features/scanner/food_photo_screen.dart'; import'../features/nutrition/nutrition_screen.dart'; import'../features/fitness/fitness_screen.dart'; import'../features/health/health_screen.dart'; import'../features/body/body_screen.dart'; import'../features/body/body_photo_screen.dart'; import'../features/profile/profile_screen.dart'; import'../features/settings/settings_screen.dart'; import'../features/paywall/paywall_screen.dart'; import'providers.dart'; import'shell.dart';

class AppRouter {
  static GoRouter router(Ref ref) {
    final notifier = _OnboardingNotifier(ref);
    return GoRouter( initialLocation:'/home',
      refreshListenable: notifier,
      redirect: (context, state) {
        final done = ref.read(onboardingDoneProvider); final onBoarding = state.matchedLocation =='/onboarding'; if (!done && !onBoarding) return'/onboarding'; if (done && onBoarding) return'/home';
        return null;
      },
      routes: [ GoRoute(path:'/onboarding', builder: (_, __) => const OnboardingScreen()),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [ GoRoute(path:'/home',      builder: (_, __) => const HomeScreen()), GoRoute(path:'/scanner',   builder: (_, __) => const ScannerScreen()), GoRoute(path:'/nutrition', builder: (_, __) => const NutritionScreen()), GoRoute(path:'/fitness',   builder: (_, __) => const FitnessScreen()), GoRoute(path:'/health',    builder: (_, __) => const HealthScreen()), GoRoute(path:'/body',      builder: (_, __) => const BodyScreen()), GoRoute(path:'/profile',   builder: (_, __) => const ProfileScreen()),
          ],
        ),
        GoRoute( path:'/workout/:id', builder: (ctx, state) => WorkoutPlayerScreen(workoutId: state.pathParameters['id']!),
        ), GoRoute(path:'/paywall',    builder: (_, __) => const PaywallScreen()), GoRoute(path:'/food-photo', builder: (_, __) => const FoodPhotoScreen()), GoRoute(path:'/body-photo', builder: (_, __) => const BodyPhotoScreen()), GoRoute(path:'/settings',   builder: (_, __) => const SettingsScreen()),
      ],
      errorBuilder: (_, state) => Scaffold( body: Center(child: Text('Route error: ${state.error}', style: const TextStyle(fontFamily:'Cairo'))),
      ),
    );
  }
}

class _OnboardingNotifier extends ChangeNotifier {
  _OnboardingNotifier(Ref ref) {
    try {
      ref.listen(onboardingDoneProvider, (_, __) {
        if (!disposed) notifyListeners();
      });
    } catch (_) {}
  }
  bool disposed = false;
  @override
  void dispose() { disposed = true; super.dispose(); }
}
