import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const sunnahGreen = Color(0xFF238636);
  static const halalGreen  = Color(0xFF3FB950);
  static const darkGreen   = Color(0xFF196127);
  static const barakahGold = Color(0xFFD29922);
  static const haramRed    = Color(0xFFF85149);
  static const doubtOrange = Color(0xFFD1812A);
  static const waterBlue   = Color(0xFF58A6FF);
  static const sleepPurple = Color(0xFFBC8CFF);

  // GitHub-dark canvas
  static const darkBg      = Color(0xFF0D1117);
  static const darkCard    = Color(0xFF161B22);
  static const darkCardAlt = Color(0xFF1C2128);
  static const darkBorder  = Color(0xFF30363D);
  static const darkBorder2 = Color(0xFF21262D);
  static const darkText    = Color(0xFFE6EDF3);
  static const darkMuted   = Color(0xFF8B949E);
  static const darkDimmed  = Color(0xFF484F58);

  // Light canvas
  static const lightBg     = Color(0xFFFFFFFF);
  static const lightCard   = Color(0xFFF6F8FA);
  static const lightBorder = Color(0xFFD0D7DE);
  static const lightText   = Color(0xFF24292F);
  static const lightMuted  = Color(0xFF656D76);

  static const gradientGreen = LinearGradient(
    colors: [Color(0xFF238636), Color(0xFF3FB950)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFD29922), Color(0xFFE3B341)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.sunnahGreen,
      secondary: AppColors.barakahGold,
      surface: AppColors.darkCard,
      onPrimary: Colors.white,
      onSurface: AppColors.darkText,
    ),
    cardColor: AppColors.darkCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.darkText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sunnahGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkBorder2, width: 0.5),
      ),
    ),
    dividerColor: AppColors.darkBorder2,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.sunnahGreen, width: 1.5)),
      hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.darkMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: AppColors.darkText),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.darkText),
      titleLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.darkText),
      bodyLarge:      TextStyle(fontFamily: 'Cairo', color: AppColors.darkText),
      bodyMedium:     TextStyle(fontFamily: 'Cairo', color: AppColors.darkMuted),
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.sunnahGreen,
      secondary: AppColors.barakahGold,
      surface: AppColors.lightCard,
      onPrimary: Colors.white,
      onSurface: AppColors.lightText,
    ),
    cardColor: AppColors.lightCard,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightBg,
      foregroundColor: AppColors.lightText,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sunnahGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: AppColors.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
      ),
    ),
    dividerColor: AppColors.lightBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.lightCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.sunnahGreen, width: 1.5)),
      hintStyle: const TextStyle(fontFamily: 'Cairo', color: AppColors.lightMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: AppColors.lightText),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.lightText),
      titleLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.lightText),
      bodyLarge:      TextStyle(fontFamily: 'Cairo', color: AppColors.lightText),
      bodyMedium:     TextStyle(fontFamily: 'Cairo', color: AppColors.lightMuted),
    ),
  );


  // ── Ramadan mode theme — everything gold ───────────────────────────
  static ThemeData get darkRamadan => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: const Color(0xFF0D0A03),
    colorScheme: const ColorScheme.dark(
      primary: AppColors.barakahGold,
      secondary: Color(0xFFFFD740),
      surface: Color(0xFF1A1200),
      onPrimary: Colors.black,
      onSurface: Color(0xFFFFF8E1),
    ),
    cardColor: const Color(0xFF1A1200),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0D0A03),
      foregroundColor: AppColors.barakahGold,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.barakahGold,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: const Color(0xFF1A1200),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF3A2E00), width: 0.5),
      ),
    ),
    dividerColor: const Color(0xFF3A2E00),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A1200),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3A2E00), width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3A2E00), width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.barakahGold, width: 1.5)),
      hintStyle: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF7A6500)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Color(0xFFFFF8E1)),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Color(0xFFFFF8E1)),
      titleLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Color(0xFFFFF8E1)),
      bodyLarge:      TextStyle(fontFamily: 'Cairo', color: Color(0xFFFFF8E1)),
      bodyMedium:     TextStyle(fontFamily: 'Cairo', color: AppColors.barakahGold),
    ),
  );

  static ThemeData get lightRamadan => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: const Color(0xFFFFFBF0),
    colorScheme: const ColorScheme.light(
      primary: AppColors.barakahGold,
      secondary: Color(0xFFC9963E),
      surface: Color(0xFFFFF8E1),
      onPrimary: Colors.black,
      onSurface: Color(0xFF3E2C00),
    ),
    cardColor: const Color(0xFFFFF8E1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFBF0),
      foregroundColor: Color(0xFF8B6914),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.barakahGold,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0C060), width: 0.5),
      ),
    ),
    dividerColor: const Color(0xFFE0C060),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFF8E1),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0C060), width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE0C060), width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.barakahGold, width: 1.5)),
      hintStyle: const TextStyle(fontFamily: 'Cairo', color: Color(0xFFB8940A)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: Color(0xFF3E2C00)),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Color(0xFF3E2C00)),
      titleLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Color(0xFF3E2C00)),
      bodyLarge:      TextStyle(fontFamily: 'Cairo', color: Color(0xFF3E2C00)),
      bodyMedium:     TextStyle(fontFamily: 'Cairo', color: Color(0xFF8B6914)),
    ),
  );

  // Legacy compat
  static ThemeData get lightTheme => light;
  static ThemeData get darkTheme  => dark;
}

// Reusable glass card
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;
  final VoidCallback? onTap;
  const GlassCard({super.key, required this.child,
    this.padding = const EdgeInsets.all(16), this.radius = 12,
    this.borderColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? AppColors.darkCard : AppColors.lightCard;
    final border = borderColor ?? (isDark ? AppColors.darkBorder2 : AppColors.lightBorder);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: 0.5),
        ),
        child: child,
      ),
    );
  }
}
