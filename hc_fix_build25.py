
import sys
errors = []

def patch(fpath, old, new, label):
    with open(fpath, "r", encoding="utf-8") as f:
        src = f.read()
    n = src.count(old)
    if n == 0:
        errors.append(f"[{label}] anchor not found in {fpath}")
        return
    if n > 1:
        errors.append(f"[{label}] anchor not unique ({n}x) in {fpath}")
        return
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(src.replace(old, new, 1))
    print(f"  [+] {label}")

HOME = "lib/features/home/home_screen.dart"
FIT  = "lib/features/fitness/fitness_screen.dart"
HLT  = "lib/features/health/health_screen.dart"
NUT  = "lib/features/nutrition/nutrition_screen.dart"
SCN  = "lib/features/scanner/scanner_screen.dart"

# ── Fix 1: _CalRing — add `lang` field + constructor param ───────────
print("\n── Fix 1: _CalRing — add lang field ────────────────────────────────")

patch(HOME,
    "final bool isAr, isDark;\n"
    "final UserProfile? profile;\n"
    "final Animation<double> ringAnim;\n"
    "final VoidCallback onAdd;\n"
    "const _CalRing({\n"
    "required this.eaten, required this.goal, required this.remaining,\n"
    "required this.pct, required this.calCol,\n"
    "required this.proteinTotal, required this.carbsTotal,\n"
    "required this.fatTotal, required this.profile,\n"
    "required this.ringAnim, required this.isAr, required this.isDark,\n"
    "required this.card, required this.border, required this.muted,\n"
    "required this.text, required this.onAdd,\n"
    "});",
    "final bool isAr, isDark;\n"
    "final String lang;\n"
    "final UserProfile? profile;\n"
    "final Animation<double> ringAnim;\n"
    "final VoidCallback onAdd;\n"
    "const _CalRing({\n"
    "required this.eaten, required this.goal, required this.remaining,\n"
    "required this.pct, required this.calCol,\n"
    "required this.proteinTotal, required this.carbsTotal,\n"
    "required this.fatTotal, required this.profile,\n"
    "required this.ringAnim, required this.isAr, required this.isDark,\n"
    "required this.lang,\n"
    "required this.card, required this.border, required this.muted,\n"
    "required this.text, required this.onAdd,\n"
    "});",
    "home: _CalRing lang field")

# Fix 1b: Pass lang at the _CalRing call site
patch(HOME,
    "_anim(1, _CalRing(\n"
    "eaten: cals.total, goal: cals.goal,\n"
    "remaining: cals.remaining,\n"
    "pct: pct, calCol: calCol,\n"
    "proteinTotal: cals.proteinTotal,\n"
    "carbsTotal: cals.carbsTotal,\n"
    "fatTotal: cals.fatTotal,\n"
    "profile: profile,\n"
    "ringAnim: _ringVal,\n"
    "isAr: isAr, isDark: isDark,\n"
    "card: card, border: border, muted: muted, text: text,\n"
    "onAdd: () => context.push('/food-photo'),\n"
    ")),",
    "_anim(1, _CalRing(\n"
    "eaten: cals.total, goal: cals.goal,\n"
    "remaining: cals.remaining,\n"
    "pct: pct, calCol: calCol,\n"
    "proteinTotal: cals.proteinTotal,\n"
    "carbsTotal: cals.carbsTotal,\n"
    "fatTotal: cals.fatTotal,\n"
    "profile: profile,\n"
    "ringAnim: _ringVal,\n"
    "isAr: isAr, isDark: isDark, lang: lang,\n"
    "card: card, border: border, muted: muted, text: text,\n"
    "onAdd: () => context.push('/food-photo'),\n"
    ")),",
    "home: _CalRing call site pass lang")

# ── Fix 2: _SunnahFastBanner — add `lang` field + constructor param ──
print("\n── Fix 2: _SunnahFastBanner — add lang field ───────────────────────")

patch(HOME,
    "class _SunnahFastBanner extends StatelessWidget {\n"
    "  final bool isAr, isDark;\n"
    "  final Color card, border;\n"
    "  const _SunnahFastBanner({\n"
    "    required this.isAr, required this.isDark,\n"
    "    required this.card, required this.border,\n"
    "  });",
    "class _SunnahFastBanner extends StatelessWidget {\n"
    "  final bool isAr, isDark;\n"
    "  final String lang;\n"
    "  final Color card, border;\n"
    "  const _SunnahFastBanner({\n"
    "    required this.isAr, required this.isDark,\n"
    "    required this.lang,\n"
    "    required this.card, required this.border,\n"
    "  });",
    "home: _SunnahFastBanner lang field")

# Fix 2b: Pass lang at the _SunnahFastBanner call site
patch(HOME,
    "  _anim(0, _SunnahFastBanner(\n"
    "      isAr: isAr, isDark: isDark,\n"
    "      card: card, border: border)),",
    "  _anim(0, _SunnahFastBanner(\n"
    "      isAr: isAr, isDark: isDark, lang: lang,\n"
    "      card: card, border: border)),",
    "home: _SunnahFastBanner call site pass lang")

# ── Fix 3: _RamadanBanner — fix iftarSoon Python-style `in` syntax ───
print("\n── Fix 3: _RamadanBanner — fix iftarSoon syntax ────────────────────")

patch(HOME,
    "    final iftarSoon   = minsToIftar in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];",
    "    final iftarSoon   = minsToIftar >= 1 && minsToIftar <= 15;",
    "home: iftarSoon Dart syntax fix")

# ── Fix 4: _FitnessState.build() — declare `lang` ────────────────────
print("\n── Fix 4: _FitnessState.build() — declare lang ─────────────────────")

patch(FIT,
    "    final gender    = ref.watch(genderProvider); final isAr      = ref.watch(languageProvider) =='ar';\n"
    "    final isDark    = ref.watch(themeProvider);\n"
    "    final isPremium = ref.watch(premiumProvider);\n"
    "    final isRamadan = ref.watch(ramadanModeProvider);\n"
    "    final workoutMin = ref.watch(workoutMinutesProvider); final isSis     = gender =='sisters';",
    "    final gender    = ref.watch(genderProvider);\n"
    "    final lang      = ref.watch(languageProvider);\n"
    "    final isAr      = lang == 'ar' || lang == 'ur';\n"
    "    final isDark    = ref.watch(themeProvider);\n"
    "    final isPremium = ref.watch(premiumProvider);\n"
    "    final isRamadan = ref.watch(ramadanModeProvider);\n"
    "    final workoutMin = ref.watch(workoutMinutesProvider); final isSis     = gender =='sisters';",
    "fitness: _FitnessState.build declare lang")

# ── Fix 5: _WorkoutPlayerState.build() — declare `lang` ──────────────
print("\n── Fix 5: _WorkoutPlayerState.build() — declare lang ───────────────")

patch(FIT,
    "    final w     = _workout; final isAr  = ref.watch(languageProvider) =='ar';\n"
    "    final isDark = ref.watch(themeProvider); if (w == null) return const Scaffold(body: Center(child: Text('Not found')));",
    "    final w     = _workout;\n"
    "    final lang   = ref.watch(languageProvider);\n"
    "    final isAr   = lang == 'ar' || lang == 'ur';\n"
    "    final isDark = ref.watch(themeProvider); if (w == null) return const Scaffold(body: Center(child: Text('Not found')));",
    "fitness: _WorkoutPlayerState.build declare lang")

# ── Fix 6: health_screen.dart — import l10n.dart ─────────────────────
print("\n── Fix 6: health_screen.dart — add l10n import ─────────────────────")

patch(HLT,
    "import '../../core/theme.dart';\n"
    "import '../../core/providers.dart';\n"
    "import '../../data/models/models.dart';\n"
    "import '../../core/health_service.dart';\n"
    "import '../../core/health_service.dart';",
    "import '../../core/theme.dart';\n"
    "import '../../core/providers.dart';\n"
    "import '../../core/l10n.dart';\n"
    "import '../../data/models/models.dart';\n"
    "import '../../core/health_service.dart';",
    "health: add l10n.dart import + remove dup health_service import")

# ── Fix 7: _AddFoodSheetState._weeklyReportCard — add lang in scope ──
print("\n── Fix 7: nutrition _weeklyReportCard — add lang ───────────────────")

patch(NUT,
    "  Widget _weeklyReportCard(bool isAr, bool isDark, bool isPremium) {\n"
    "    final bg    = isDark ? AppColors.darkCard : Colors.white;\n"
    "    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;\n"
    "    final goal  = ref.read(caloriesProvider).goal;\n"
    "    String t(String ar, String en) => tLang(lang, ar, en);",
    "  Widget _weeklyReportCard(bool isAr, bool isDark, bool isPremium) {\n"
    "    final lang  = ref.read(languageProvider);\n"
    "    final bg    = isDark ? AppColors.darkCard : Colors.white;\n"
    "    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;\n"
    "    final goal  = ref.read(caloriesProvider).goal;\n"
    "    String t(String ar, String en) => tLang(lang, ar, en);",
    "nutrition: _weeklyReportCard add lang")

# ── Fix 8: _ScannerState._resultCard — add lang in scope ─────────────
print("\n── Fix 8: scanner _resultCard — add lang ────────────────────────────")

patch(SCN,
    "  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {\n"
    "    final col   = _statusColor(r.status);\n"
    "    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);\n"
    "    String t(String ar, String en) => tLang(lang, ar, en);",
    "  Widget _resultCard(ScanResult r, bool isAr, bool isDark, Color bg, Color muted) {\n"
    "    final lang  = ref.read(languageProvider);\n"
    "    final col   = _statusColor(r.status);\n"
    "    final label = isAr ? _labelAr(r.status) : _labelEn(r.status);\n"
    "    String t(String ar, String en) => tLang(lang, ar, en);",
    "scanner: _resultCard add lang")

print("")
if errors:
    print("ERRORS:")
    for e in errors:
        print(f"  !! {e}")
    sys.exit(1)
else:
    print("All patches applied OK")
