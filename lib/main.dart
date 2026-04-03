import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Keep original imports but add error handling
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'core/revenuecat_service.dart';
import 'core/notifications.dart';
import 'core/database.dart';
import 'core/health_service.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    try {
      // Try to run the real app
      await _initAndRun();
    } catch (e, st) {
      // Show error on screen instead of crashing silently
      runApp(ErrorApp(error: e.toString(), stack: st.toString()));
    }
  }, (error, stack) {
    runApp(ErrorApp(error: error.toString(), stack: stack.toString()));
  });
}

class ErrorApp extends StatelessWidget {
  final String error;
  final String stack;
  const ErrorApp({super.key, required this.error, required this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red[900],
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CRASH DETAILS',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(error,
                    style: const TextStyle(color: Colors.yellow, fontSize: 13)),
                const SizedBox(height: 12),
                Text(stack.length > 800 ? stack.substring(0, 800) : stack,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _initAndRun() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Init SQLite with timeout
  try {
    await AppDatabase.db.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('DB timeout'),
    );
  } catch (e) {
    debugPrint('DB init failed: $e');
  }

  // Init notifications with timeout
  try {
    await NotificationService.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('Notifications timeout'),
    );
  } catch (e) {
    debugPrint('Notifications init failed: $e');
  }

  // Init RevenueCat with timeout
  try {
    await RCConfig.configure().timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw Exception('RevenueCat timeout'),
    );
  } catch (e) {
    debugPrint('RevenueCat init failed: $e');
  }

  runApp(const ProviderScope(child: HalalCalorieApp()));
}