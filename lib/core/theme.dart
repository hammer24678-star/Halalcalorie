import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const brandGreen = Color(0xFF238636);
  static const halalGreen  = Color(0xFF3FB950);
  static const darkGreen   = Color(0xFF196127);
  static const accentGold = Color(0xFFDBA75D);
  static const haramRed    = Color(0xFFEF6A60);
  static const doubtOrange = Color(0xFFD1812A);
  static const waterBlue   = Color(0xFF6FB3FF);
  static const sleepPurple = Color(0xFFBC8CFF);
  // v10: brighter mint + deep accent, used for dark-mode highlights
  static const accentBright   = Color(0xFF78E08E);
  static const accentDeepDark = Color(0xFF2E9C40);
  static const accentInkDark  = Color(0xFF06210C);

  // v10 forest-night canvas (was GitHub-dark gray)
  static const darkBg      = Color(0xFF071310);
  static const darkCard    = Color(0xFF0F1E18);
  static const darkCardAlt = Color(0xFF152C21);
  static const darkBorder  = Color(0x2B94C9A9);
  static const darkBorder2 = Color(0x1A94C9A9);
  static const darkText    = Color(0xFFEEF6F0);
  static const darkMuted   = Color(0xFF8BA095);
  static const darkDimmed  = Color(0xFF556458);
  static const greetGold   = Color(0xFFF0CF98); // cursive-greeting accent, dark mode

  // v10 canvas (was flat white)
  static const lightBg      = Color(0xFFF5F8F5);
  static const lightCard    = Color(0xFFF6F8F6);
  static const lightCardAlt = Color(0xFFEEF3EE);
  static const lightBorder  = Color(0x1F1B2420);
  static const lightBorder2 = Color(0x121B2420);
  static const lightText    = Color(0xFF182420);
  static const lightMuted   = Color(0xFF5C6B62);
  static const lightMuted2  = Color(0xFF8B988F);
  static const greetGoldLight = Color(0xFFA9761F); // cursive-greeting accent, light mode

  static const gradientGreen = LinearGradient(
    colors: [Color(0xFF238636), Color(0xFF3FB950)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFDBA75D), Color(0xFFEBCB8E)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ── Ramadan Night-Sky palette (dark mode) — v10 purple-gold ────
  static const ramadanNight   = Color(0xFF0B0919); // deep cosmic indigo
  static const ramadanCard    = Color(0xFF150F2C); // card surface
  static const ramadanCardAlt = Color(0xFF1C1640); // elevated card
  static const ramadanBorder  = Color(0x38E8B84B); // gold hairline, visible
  static const ramadanBorder2 = Color(0x1FE8B84B); // gold hairline, faint
  static const ramadanGold    = Color(0xFFE8B84B); // rich warm gold
  static const ramadanGoldDim = Color(0xFFB88E2A); // dimmed gold
  static const ramadanText    = Color(0xFFF3ECD6); // warm parchment
  static const ramadanMuted   = Color(0xFFB9A37E); // warm sand
  static const ramadanDimmed  = Color(0xFF6D5F46); // muted amber
  static const ramadanAccentBright = Color(0xFFFFD97A); // bright gold highlight
  static const ramadanInk     = Color(0xFF1A0800); // text-on-gold

  // ── Ramadan Desert-Sunrise palette (light mode) — unchanged; v10's
  // mockup only shows a night-mode Ramadan theme, so this keeps its
  // existing values rather than guessing at a redesign for it. ────
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

/// v10 redesign fonts. 'Aligarh' was referenced 701 times across the app but
/// never actually bundled (pubspec had no fonts: entry for it), so every
/// fontFamily: 'Aligarh' silently fell back to the system default. This patch
/// changes every one of those to 'Aligarh' — the app's first real embedded
/// font — and adds two more for specific accent roles.
class AppFonts {
  /// Workhorse UI font — headings, numbers and body text app-wide.
  static const aligarh = 'Aligarh';
  /// Title font -- headlineLarge/headlineMedium/titleLarge and
  /// AppBar titles app-wide. Added by patch_v12.
  static const bravoon = 'Bravoon';
  /// Cursive accent -- not currently used anywhere (the home/nutrition
  /// greetings that used to reference this moved to Bravoon in v17).
  /// Left registered in pubspec in case a future flourish wants it.
  static const lemonBrush = 'LemonBrush';
  /// Decorative display font — reserved for the "HalalCalorie" wordmark.
  static const alyamama = 'Alyamama';

  static const TextStyle greeting = TextStyle(
    fontFamily: lemonBrush, fontSize: 34, height: 1.0,
  );
  static const TextStyle wordmark = TextStyle(
    fontFamily: alyamama, fontWeight: FontWeight.w700,
    color: Colors.white, letterSpacing: 0.2,
  );
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Aligarh',
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.brandGreen,
      secondary: AppColors.accentGold,
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
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Aligarh', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
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
        borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5)),
      hintStyle: const TextStyle(fontFamily: 'Aligarh', color: AppColors.darkMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w900, color: AppColors.darkText),
      headlineMedium: TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.darkText),
      titleLarge:     TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.darkText),
      bodyLarge:      TextStyle(fontFamily: 'Aligarh', color: AppColors.darkText),
      bodyMedium:     TextStyle(fontFamily: 'Aligarh', color: AppColors.darkMuted),
    ),
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Aligarh',
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.brandGreen,
      secondary: AppColors.accentGold,
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
        backgroundColor: AppColors.brandGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Aligarh', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    cardTheme: CardThemeData(
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
        borderSide: const BorderSide(color: AppColors.brandGreen, width: 1.5)),
      hintStyle: const TextStyle(fontFamily: 'Aligarh', color: AppColors.lightMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w900, color: AppColors.lightText),
      headlineMedium: TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.lightText),
      titleLarge:     TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.lightText),
      bodyLarge:      TextStyle(fontFamily: 'Aligarh', color: AppColors.lightText),
      bodyMedium:     TextStyle(fontFamily: 'Aligarh', color: AppColors.lightMuted),
    ),
  );


  // ── Ramadan mode theme — everything gold ───────────────────────────
  static ThemeData get darkRamadan => ThemeData(
    // ── Night Sky over Mecca ────────────────────────────────────────
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Aligarh',
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
        fontFamily: 'Bravoon', fontWeight: FontWeight.w800,
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
        textStyle: TextStyle(fontFamily: 'Aligarh', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ramadanGold,
        side: BorderSide(color: AppColors.ramadanGold, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(vertical: 14),
        textStyle: TextStyle(fontFamily: 'Aligarh', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.ramadanCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.ramadanBorder, width: 0.8),
      ),
    ),
    dividerColor: AppColors.ramadanBorder,
    tabBarTheme: const TabBarThemeData(
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
      hintStyle: TextStyle(fontFamily: 'Aligarh', color: AppColors.ramadanMuted),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor:   AppColors.ramadanGold,
      textColor:   AppColors.ramadanText,
      tileColor:   Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w900, color: AppColors.ramadanText),
      headlineMedium: TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.ramadanText),
      titleLarge:     TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.ramadanText),
      bodyLarge:      TextStyle(fontFamily: 'Aligarh', color: AppColors.ramadanText),
      bodyMedium:     TextStyle(fontFamily: 'Aligarh', color: AppColors.ramadanMuted),
      labelLarge:     TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w700, color: Color(0xFF1A0800)),
    ),
  );

  static ThemeData get lightRamadan => ThemeData(
    // ── Desert Sunrise ──────────────────────────────────────────────
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Aligarh',
    scaffoldBackgroundColor: AppColors.ramadanDay,
    colorScheme: const ColorScheme.light(
      primary:     AppColors.accentGold,
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
        fontFamily: 'Bravoon', fontWeight: FontWeight.w800,
        fontSize: 18, color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentGold,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(vertical: 14),
        textStyle: TextStyle(fontFamily: 'Aligarh', fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentGold,
        side: BorderSide(color: AppColors.accentGold, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: EdgeInsets.symmetric(vertical: 14),
        textStyle: TextStyle(fontFamily: 'Aligarh', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.ramadanDayCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Color(0xFFD4A043), width: 0.8),
      ),
    ),
    dividerColor: const Color(0xFFD4A043),
    tabBarTheme: const TabBarThemeData(
      indicatorColor:       AppColors.accentGold,
      labelColor:           AppColors.accentGold,
      unselectedLabelColor: Color(0xFFB8940A),
      dividerColor:         Colors.transparent,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor:     AppColors.ramadanDayCard,
      selectedItemColor:   AppColors.accentGold,
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
        borderSide: BorderSide(color: AppColors.accentGold, width: 1.6)),
      hintStyle: TextStyle(fontFamily: 'Aligarh', color: Color(0xFF9A7000)),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.accentGold,
      textColor: AppColors.ramadanDayText,
      tileColor: Colors.transparent,
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w900, color: AppColors.ramadanDayText),
      headlineMedium: TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.ramadanDayText),
      titleLarge:     TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700, color: AppColors.ramadanDayText),
      bodyLarge:      TextStyle(fontFamily: 'Aligarh', color: AppColors.ramadanDayText),
      bodyMedium:     TextStyle(fontFamily: 'Aligarh', color: AppColors.ramadanDayMuted),
      labelLarge:     TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w700, color: Colors.white),
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
