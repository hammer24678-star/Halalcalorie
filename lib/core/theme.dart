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

  // ── Ramadan Night-Sky palette (dark mode) ──────────────────────
  static const ramadanNight   = Color(0xFF0B0919); // deep cosmic indigo
  static const ramadanCard    = Color(0xFF12102A); // card surface
  static const ramadanCardAlt = Color(0xFF1A1838); // elevated card
  static const ramadanBorder  = Color(0xFF2A2650); // subtle indigo border
  static const ramadanBorder2 = Color(0xFF1E1C3A); // faint border
  static const ramadanGold    = Color(0xFFE8B84B); // rich warm gold
  static const ramadanGoldDim = Color(0xFFB88E2A); // dimmed gold
  static const ramadanText    = Color(0xFFF0E6C8); // warm parchment
  static const ramadanMuted   = Color(0xFFA89878); // warm sand
  static const ramadanDimmed  = Color(0xFF5C5040); // muted amber

  // ── Ramadan Desert-Sunrise palette (light mode) ────────────────
  static const ramadanDay     = Color(0xFFFEF5E4); // warm parchment bg
  static const ramadanDayCard = Color(0xFFFDF0D0); // honey cream card
  static const ramadanDayText = Color(0xFF2C1800); // deep warm brown
  static const ramadanDayMuted= Color(0xFF7A5500); // amber muted

  static const gradientRamadan = LinearGradient(
    colors: [Color(0xFF0B0919), Color(0xFFE8B84B)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientRamadanDay = LinearGradient(
    colors: [Color(0xFFEE9D2A), Color(0xFFD29922)],
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
    // ── Night Sky over Mecca ────────────────────────────────────────
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.ramadanNight,
    colorScheme: const ColorScheme.dark(
      primary:     AppColors.ramadanGold,
      secondary:   Color(0xFFFFD166),
      surface:     AppColors.ramadanCard,
      onPrimary:   Color(0xFF1A0800),
      onSecondary: Color(0xFF1A0800),
      onSurface:   AppColors.ramadanText,
      outline:     AppColors.ramadanBorder,
    ),
    cardColor: AppColors.ramadanCard,
    appBarTheme: const AppBarTheme(
      backgroundColor:  AppColors.ramadanNight,
      foregroundColor:  AppColors.ramadanGold,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo', fontWeight: FontWeight.w800,
        fontSize: 18, color: AppColors.ramadanGold,
      ),
      iconTheme: IconThemeData(color: AppColors.ramadanGold),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ramadanGold,
        foregroundColor: Color(0xFF1A0800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(vertical: 14),
        textStyle: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ramadanGold,
        side: BorderSide(color: AppColors.ramadanGold, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(vertical: 14),
        textStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: AppColors.ramadanCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.ramadanBorder, width: 0.8),
      ),
    ),
    dividerColor: AppColors.ramadanBorder,
    tabBarTheme: const TabBarTheme(
      indicatorColor:     AppColors.ramadanGold,
      labelColor:         AppColors.ramadanGold,
      unselectedLabelColor: AppColors.ramadanMuted,
      dividerColor:       Colors.transparent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:      AppColors.ramadanCard,
      selectedItemColor:    AppColors.ramadanGold,
      unselectedItemColor:  AppColors.ramadanMuted,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ramadanCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.ramadanBorder, width: 0.8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.ramadanBorder, width: 0.8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.ramadanGold, width: 1.6)),
      hintStyle: TextStyle(fontFamily: 'Cairo', color: AppColors.ramadanMuted),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor:   AppColors.ramadanGold,
      textColor:   AppColors.ramadanText,
      tileColor:   Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: AppColors.ramadanText),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.ramadanText),
      titleLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.ramadanText),
      bodyLarge:      TextStyle(fontFamily: 'Cairo', color: AppColors.ramadanText),
      bodyMedium:     TextStyle(fontFamily: 'Cairo', color: AppColors.ramadanMuted),
      labelLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Color(0xFF1A0800)),
    ),
  );

  static ThemeData get lightRamadan => ThemeData(
    // ── Desert Sunrise ──────────────────────────────────────────────
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Cairo',
    scaffoldBackgroundColor: AppColors.ramadanDay,
    colorScheme: const ColorScheme.light(
      primary:     AppColors.barakahGold,
      secondary:   Color(0xFFB85C1A),
      surface:     AppColors.ramadanDayCard,
      onPrimary:   Colors.white,
      onSecondary: Colors.white,
      onSurface:   AppColors.ramadanDayText,
      outline:     Color(0xFFD4A043),
    ),
    cardColor: AppColors.ramadanDayCard,
    appBarTheme: const AppBarTheme(
      backgroundColor:  Color(0xFFEE9D2A),
      foregroundColor:  Colors.white,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo', fontWeight: FontWeight.w800,
        fontSize: 18, color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.barakahGold,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(vertical: 14),
        textStyle: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.barakahGold,
        side: BorderSide(color: AppColors.barakahGold, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(vertical: 14),
        textStyle: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      color: AppColors.ramadanDayCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Color(0xFFD4A043), width: 0.8),
      ),
    ),
    dividerColor: const Color(0xFFD4A043),
    tabBarTheme: const TabBarTheme(
      indicatorColor:       AppColors.barakahGold,
      labelColor:           AppColors.barakahGold,
      unselectedLabelColor: Color(0xFFB8940A),
      dividerColor:         Colors.transparent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:     AppColors.ramadanDayCard,
      selectedItemColor:   AppColors.barakahGold,
      unselectedItemColor: Color(0xFFB8940A),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.ramadanDayCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFFD4A043), width: 0.8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Color(0xFFD4A043), width: 0.8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.barakahGold, width: 1.6)),
      hintStyle: TextStyle(fontFamily: 'Cairo', color: Color(0xFF9A7000)),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.barakahGold,
      textColor: AppColors.ramadanDayText,
      tileColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, color: AppColors.ramadanDayText),
      headlineMedium: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.ramadanDayText),
      titleLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: AppColors.ramadanDayText),
      bodyLarge:      TextStyle(fontFamily: 'Cairo', color: AppColors.ramadanDayText),
      bodyMedium:     TextStyle(fontFamily: 'Cairo', color: AppColors.ramadanDayMuted),
      labelLarge:     TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, color: Colors.white),
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
