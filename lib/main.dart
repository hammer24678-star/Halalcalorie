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

// Global error string - shown on screen if crash occurs
String _crashInfo = '';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = 'FLUTTER ERROR:\n${details.exceptionAsString()}\n\nSTACK:\n${details.stack}';
      debugPrint(msg);
      _crashInfo = msg;
      // Show error widget in place - don't call runApp here
      FlutterError.presentError(details);
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return _buildErrorScreen('WIDGET ERROR:\n${details.exceptionAsString()}');
    };

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Step 1 - DB
    try {
      debugPrint('STEP 1: Opening database...');
      await AppDatabase.db.timeout(const Duration(seconds: 5));
      debugPrint('STEP 1: Database OK');
    } catch (e, st) {
      runApp(_buildErrorApp('STEP 1 DB FAILED:\n$e\n\n$st'));
      return;
    }

    // Step 2 - Notifications
    try {
      debugPrint('STEP 2: Init notifications...');
      await NotificationService.init();
      debugPrint('STEP 2: Notifications OK');
    } catch (e) {
      debugPrint('STEP 2 FAILED (non-fatal): $e');
    }

    // Step 3 - Auth
    try {
      debugPrint('STEP 3: Init auth...');
      await AuthService.init();
      debugPrint('STEP 3: Auth OK');
    } catch (e) {
      debugPrint('STEP 3 FAILED (non-fatal): $e');
    }

    debugPrint('STEP 4: Starting app...');
    runApp(const ProviderScope(child: HalalCalorieApp()));

  }, (error, stack) {
    // This catches ALL unhandled errors - show them on screen
    final msg = 'UNHANDLED CRASH:\n$error\n\nSTACK:\n${stack.toString().substring(0, stack.toString().length.clamp(0, 2000))}';
    debugPrint(msg);
    // Call runApp here - this is the right place for fatal errors
    runApp(_buildErrorApp(msg));
  });
}

Widget _buildErrorScreen(String message) {
  return Material(
    color: const Color(0xFF8B0000),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          message,
          style: const TextStyle(color: Colors.yellow, fontSize: 11, fontFamily: 'monospace'),
        ),
      ),
    ),
  );
}

Widget _buildErrorApp(String message) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF8B0000),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            message,
            style: const TextStyle(color: Colors.yellow, fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
      ),
    ),
  );
}

class HalalCalorieApp extends ConsumerWidget {
  const HalalCalorieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark  = ref.watch(themeProvider);
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
  }
}
