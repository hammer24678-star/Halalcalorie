// ════════════════════════════════════════════════════════════════════
//  router.dart — routes and transitions
// ════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/home/home_screen.dart';
import '../features/scanner/scanner_screen.dart';
import '../features/scanner/food_photo_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/fitness/fitness_screen.dart';
import '../features/fitness/lift_screen.dart';
import '../features/health/health_screen.dart';
import '../features/body/body_screen.dart';
import '../features/body/body_photo_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/paywall/paywall_screen.dart';
import '../features/ascent/ascent_screen.dart';
import 'motion.dart';
import 'providers.dart';
import 'shell.dart';

class AppRouter {
  static GoRouter router(Ref ref) {
    final notifier = _OnboardingNotifier(ref);
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: notifier,
      redirect: (context, state) {
        final loc = state.matchedLocation;
        // The splash drives itself and must never be redirected away.
        if (loc == '/splash') return null;
        final done = ref.read(onboardingDoneProvider);
        final onBoarding = loc == '/onboarding';
        if (!done && !onBoarding) return '/onboarding';
        if (done && onBoarding) return '/home';
        return null;
      },
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(
            path: '/onboarding', builder: (_, __) => const OnboardingScreen()),

        // ── Tabs live inside the shell ──
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            _tab('/home', (_, __) => const HomeScreen()),
            _tab('/scanner', (_, __) => const ScannerScreen()),
            _tab('/nutrition', (_, __) => const NutritionScreen()),
            _tab('/fitness', (_, __) => const FitnessScreen()),
            _tab('/ascent', (_, __) => const AscentScreen()),
            // Legacy deep link from earlier builds.
            GoRoute(path: '/barakah', redirect: (_, __) => '/ascent'),
            _tab('/health', (_, __) => const HealthScreen()),
            _tab('/body', (_, __) => const BodyScreen()),
            _tab('/profile', (_, __) => const ProfileScreen()),
          ],
        ),

        // ── Pushed over the shell ──
        _page('/lift', (_, __) => const LiftScreen()),
        _page('/lift/:id', (ctx, state) =>
            LiftDetailScreen(exerciseId: state.pathParameters['id'] ?? '')),
        _page('/workout/:id', (ctx, state) =>
            WorkoutPlayerScreen(workoutId: state.pathParameters['id']!)),
        _page('/paywall', (_, __) => const PaywallScreen()),
        _page('/food-photo', (_, __) => const FoodPhotoScreen()),
        _page('/body-photo', (_, __) => const BodyPhotoScreen()),
        _page('/settings', (_, __) => const SettingsScreen()),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(
          child: Text('Route error: ${state.error}',
              style: const TextStyle(fontFamily: 'Cairo')),
        ),
      ),
    );
  }

  /// Tab route: cross-fades, since the shell stays put underneath.
  static GoRoute _tab(String path, Widget Function(BuildContext, GoRouterState) build) =>
      GoRoute(
        path: path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: build(context, state),
          transitionDuration: Motion.quick,
          reverseTransitionDuration: Motion.fast,
          transitionsBuilder: fadeThrough,
        ),
      );

  /// Pushed route: slides up from the bottom.
  static GoRoute _page(String path, Widget Function(BuildContext, GoRouterState) build) =>
      GoRoute(
        path: path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: build(context, state),
          transitionDuration: Motion.base,
          reverseTransitionDuration: Motion.quick,
          transitionsBuilder: (context, animation, secondary, child) {
            final curved =
                CurvedAnimation(parent: animation, curve: Motion.curve);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
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
  void dispose() {
    disposed = true;
    super.dispose();
  }
}
