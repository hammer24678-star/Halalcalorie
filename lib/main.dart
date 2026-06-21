import 'dart:async';
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

    ErrorWidget.builder = (FlutterErrorDetails details) {
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
      final _p = await SharedPreferences.getInstance();
      if (!(_p.getBool('notifs_scheduled') ?? false)) {
        await NotificationService.scheduleMealReminder();
        await NotificationService.scheduleWaterReminder();
        await NotificationService.scheduleBarakahNudge();
        await _p.setBool('notifs_scheduled', true);
      }
    } catch (e) { debugPrint('Notif schedule: $e'); }
    try { await AuthService.init(); } catch (e) { debugPrint('Auth init: $e'); }
    try { await RCConfig.configure(); } catch (e) { debugPrint('RevenueCat init: $e'); }

    runApp(const ProviderScope(child: HalalCalorieApp()));

  }, (error, stack) {
    debugPrint('Unhandled: $error\n$stack');
  });
}

class HalalCalorieApp extends ConsumerWidget {
  const HalalCalorieApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
