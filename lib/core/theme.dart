import 'package:flutter/material.dart';

class AppColors {
  static const sunnahGreen  = Color(0xFF0A6B4A);
  static const darkGreen    = Color(0xFF054D34);
  static const barakahGold  = Color(0xFFD4A017);
  static const halalGreen   = Color(0xFF00A86B);
  static const haramRed     = Color(0xFFC62828);
  static const doubtOrange  = Color(0xFFF57C00);
  static const waterBlue    = Color(0xFF2196F3);
  static const sleepPurple  = Color(0xFF7C4DFF);

  static const gradientGreen = LinearGradient(
    colors: [Color(0xFF0A6B4A), Color(0xFF00A86B)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFD4A017), Color(0xFFFFB300)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // Light
  static const lightBg     = Color(0xFFF0F4F8);
  static const lightCard   = Color(0xFFFFFFFF);
  static const lightNav    = Color(0xFFFFFFFF);
  static const lightText   = Color(0xFF1F2A1F);
  static const lightMuted  = Color(0xFF6B7A8D);
  static const lightBorder = Color(0xFFE8E4DF);

  // Dark — GitHub-style deep dark
  static const darkBg     = Color(0xFF0D1117);
  static const darkCard   = Color(0xFF161B22);
  static const darkNav    = Color(0xFF161B22);
  static const darkText   = Color(0xFFE8F0E8);
  static const darkMuted  = Color(0xFF7D8590);
  static const darkBorder = Color(0xFF21262D);
}

class AppTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light, fontFamily: 'Cairo',
    colorScheme: ColorScheme.light(
      primary: AppColors.sunnahGreen,
      secondary: AppColors.barakahGold,
      surface: AppColors.lightCard,
      onPrimary: Colors.white,
      onSurface: AppColors.lightText,
    ),
    scaffoldBackgroundColor: AppColors.lightBg,
    cardColor: AppColors.lightCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBg,
      foregroundColor: AppColors.lightText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo', fontSize: 18,
        fontWeight: FontWeight.w700, color: AppColors.lightText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sunnahGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 4,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.lightCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.sunnahGreen.withOpacity(0.2))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.sunnahGreen.withOpacity(0.2))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sunnahGreen, width: 2)),
      hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.lightMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: AppColors.lightText),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.lightText),
      titleLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.lightText),
      bodyLarge: TextStyle(fontFamily: 'Cairo', color: AppColors.lightText),
      bodyMedium: TextStyle(fontFamily: 'Cairo', color: AppColors.lightMuted),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark, fontFamily: 'Cairo',
    colorScheme: ColorScheme.dark(
      primary: AppColors.sunnahGreen,
      secondary: AppColors.barakahGold,
      surface: AppColors.darkCard,
      onPrimary: Colors.white,
      onSurface: AppColors.darkText,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    cardColor: AppColors.darkCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo', fontSize: 18,
        fontWeight: FontWeight.w700, color: AppColors.darkText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sunnahGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700),
        elevation: 4,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.darkCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.halalGreen.withOpacity(0.25))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.halalGreen.withOpacity(0.25))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.sunnahGreen, width: 2)),
      hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.darkMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: AppColors.darkText),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.darkText),
      titleLarge: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.darkText),
      bodyLarge: TextStyle(fontFamily: 'Cairo', color: AppColors.darkText),
      bodyMedium: TextStyle(fontFamily: 'Cairo', color: AppColors.darkMuted),
    ),
    dividerColor: AppColors.darkBorder,
  );
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final bool hasBorder;

  const AppCard({
    super.key, required this.child,
    this.padding, this.color, this.radius = 14,
    this.onTap, this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? (isDark ? AppColors.darkCard : Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: hasBorder ? Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ) : null,
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: child,
      ),
    );
  }
}
