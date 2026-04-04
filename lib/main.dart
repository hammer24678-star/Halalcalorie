// main.dart — HalalCalorie v1.0
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

void main() {
  // Catch ALL errors before Flutter even starts
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Show any Flutter framework errors on screen
    FlutterError.onError = (FlutterErrorDetails details) {
      runApp(_ErrorApp('Flutter Error:\n${details.exceptionAsString()}\n\n${details.stack}'));
    };

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Step 1: DB
    try {
      await AppDatabase.db.timeout(const Duration(seconds: 5));
    } catch (e, st) {
      runApp(_ErrorApp('DB Error:\n$e\n\n$st'));
      return;
    }

    // Step 2: Notifications
    try {
      await NotificationService.init().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Notif (non-fatal): $e');
    }

    // Step 3: Auth
    try {
      await AuthService.init();
    } catch (e) {
      debugPrint('Auth (non-fatal): $e');
    }

    // Step 4: Run app
    runApp(const ProviderScope(child: HalalCalorieApp()));

  }, (error, stack) {
    // This catches ANY unhandled error in the entire app
    runApp(_ErrorApp('Unhandled Error:\n$error\n\n${stack.toString().substring(0, stack.toString().length.clamp(0, 1200))}'));
  });
}

class HalalCalorieApp extends ConsumerWidget {
  const HalalCalorieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    try {
      final router = ref.watch(routerProvider);
      final isDark = ref.watch(themeProvider);
      return MaterialApp.router(
        title: 'HalalCalorie',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
      );
    } catch (e, st) {
      return _ErrorApp('App Build Error:\n$e\n\n$st');
    }
  }
}

class _ErrorApp extends StatelessWidget {
  final String message;
  const _ErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF8B0000),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              message,
              style: const TextStyle(
                color: Colors.yellow,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
