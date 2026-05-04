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
    try { await AuthService.init(); } catch (e) { debugPrint('Auth init: $e'); }

    runApp(const ProviderScope(child: HalalCalorieApp()));

  }, (error, stack) {
    debugPrint('Unhandled: $error\n$stack');
  });
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
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
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
