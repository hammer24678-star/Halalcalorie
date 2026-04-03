// main.dart — HalalCalorie v1.0
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'core/providers.dart';
import 'core/revenuecat_service.dart';
import 'core/notifications.dart';
import 'core/database.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      runApp(_ErrorApp(details.exceptionAsString()));
    };

    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    try {
      await AppDatabase.db.timeout(const Duration(seconds: 5));
    } catch (e) { debugPrint('DB: $e'); }

    try {
      await NotificationService.init().timeout(const Duration(seconds: 5));
    } catch (e) { debugPrint('Notif: $e'); }

    try {
      await RCConfig.configure().timeout(const Duration(seconds: 5));
    } catch (e) { debugPrint('RC: $e'); }

    runApp(const ProviderScope(child: HalalCalorieApp()));
  }, (error, stack) {
    runApp(_ErrorApp('$error\n\n$stack'));
  });
}

// ── HalalCalorieApp ───────────────────────────────────────
class HalalCalorieApp extends ConsumerWidget {
  const HalalCalorieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark  = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'HalalCalorie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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

// ── Error display ────────────────────────────────────────
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CRASH', style: TextStyle(
                    color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  message.length > 1500 ? message.substring(0, 1500) : message,
                  style: const TextStyle(color: Colors.yellow, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
