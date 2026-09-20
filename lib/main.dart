import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'core/notifications.dart';
import 'core/database.dart';
import 'core/auth_service.dart';
import 'core/revenuecat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      debugPrint('FlutterError: ${details.exceptionAsString()}');
      FlutterError.presentError(details);
    };

    // Debug only: in release a build error should fall back to Flutter's neutral
    // error widget, not a red screen dumping the raw exception at the user.
    if (kDebugMode) ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: const Color(0xFF8B0000),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Text(
              'Error: ${details.exceptionAsString()}',
              style: const TextStyle(color: Colors.yellow, fontSize: 11),
            ),
          ),
        ),
      );
    };

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    try { await AppDatabase.db.timeout(const Duration(seconds: 5)); } catch (e) { debugPrint('DB init: $e'); }
    try { await NotificationService.init(); } catch (e) { debugPrint('Notif init: $e'); }
    try {
      // Re-applied on every launch (stable ids -> replaces, never duplicates):
      // repairs installs whose lunch reminder was overwritten by a water id,
      // and re-anchors the times to the current timezone.
      final _p = await SharedPreferences.getInstance();
      await NotificationService.rescheduleAll(
          isAr: (_p.getString('language') ?? 'ar') == 'ar');
    } catch (e) { debugPrint('Notif schedule: $e'); }
    try { await AuthService.init(); } catch (e) { debugPrint('Auth init: $e'); }
    try { await RCConfig.configure(); } catch (e) { debugPrint('RevenueCat init: $e'); }

    runApp(const ProviderScope(child: HalalCalorieApp()));

  }, (error, stack) {
    debugPrint('Unhandled: $error\n$stack');
  });
}

class HalalCalorieApp extends ConsumerStatefulWidget {
  const HalalCalorieApp({super.key});
  @override
  ConsumerState<HalalCalorieApp> createState() => _HalalCalorieAppState();
}

class _HalalCalorieAppState extends ConsumerState<HalalCalorieApp>
    with WidgetsBindingObserver {
  String _day = _dayKey();
  Timer? _midnight;

  static String _dayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _armMidnightTimer();
    // Start counting steps at launch when the permission is already granted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(stepTrackerProvider).ensureStarted(askPermissions: false).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _rollDayIfNeeded();
  }

  void _armMidnightTimer() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnight = Timer(next.difference(now), () {
      _rollDayIfNeeded();
      _armMidnightTimer();
    });
  }

  /// Everything "today"-scoped is loaded once per provider lifetime, so an app
  /// left open (or resumed) after midnight kept yesterday's meals, water, steps,
  /// workout minutes and fasting flag — the next water tap then wrote yesterday's
  /// cups into the new day's row, and Ascent scored yesterday's quests as today's.
  /// On a date change, rebuild those providers from the database.
  void _rollDayIfNeeded() {
    final today = _dayKey();
    if (today == _day) return;
    _day = today;
    ref.invalidate(caloriesProvider);
    ref.invalidate(waterProvider);
    ref.invalidate(sleepProvider);
    ref.invalidate(healthProvider);
    ref.invalidate(workoutMinutesProvider);
    ref.invalidate(caloriesBurnedTodayProvider);
    ref.invalidate(fastingProvider);
    ref.read(scanProvider.notifier).refreshDay();
    ref.read(ascentProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final router    = ref.watch(routerProvider);
    final isDark    = ref.watch(themeProvider);
    final isRamadan = ref.watch(ramadanModeProvider);
    final lang      = ref.watch(languageProvider);
    return MaterialApp.router(
      title: 'HalalCalorie',
      debugShowCheckedModeBanner: false,
      theme:     isRamadan ? AppTheme.lightRamadan : AppTheme.light,
      darkTheme: isRamadan ? AppTheme.darkRamadan  : AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(lang),
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar'), Locale('en'), Locale('fr'),
        Locale('tr'), Locale('ms'), Locale('id'), Locale('ur'),
      ],
    );
  }
}
