
import sys
errors = []

def patch(fpath, old, new, label, allow_multi=False):
    with open(fpath, "r", encoding="utf-8") as f:
        src = f.read()
    n = src.count(old)
    if n == 0:
        errors.append(f"[{label}] anchor not found in {fpath}")
        return
    if n > 1 and not allow_multi:
        errors.append(f"[{label}] anchor not unique ({n}x) in {fpath}")
        return
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(src.replace(old, new, 1 if not allow_multi else n))
    print(f"  [+] {label}")

HS  = "lib/features/home/home_screen.dart"
FIT = "lib/features/fitness/fitness_screen.dart"
OB  = "lib/features/onboarding/onboarding_screen.dart"

# ── Fix 1: \${h}/\${m} escaped dollar in _cd (shows literal ${h}) ──
print("\n── Fix 1: Ramadan countdown \${h} → ${h} ────────────────")

with open(HS, "r", encoding="utf-8") as f:
    hs = f.read()

# The file has backslash-dollar which Dart treats as literal $.
# We need to remove the backslashes so Dart interpolates the variables.
if r"'\${m}" in hs:
    hs = hs.replace(
        r"return h == 0 ? '\${m}" + "\u062f' : '\\${h}\u0633 \\${m}\u062f';",
        "return h == 0 ? '${m}\u062f' : '${h}\u0633 ${m}\u062f';")
    # Also fix $day in the same pass
    hs = hs.replace(
        "Text(t('\u0627\u0644\u064a\u0648\u0645 \\$day', 'Day \\$day \u2605'),",
        "Text(t('\u0627\u0644\u064a\u0648\u0645 $day', 'Day $day \u2605'),")
    with open(HS, "w", encoding="utf-8") as f:
        f.write(hs)
    print("  [+] home: _cd \\${h}/\\${m} → ${h}/${m}")
    print("  [+] home: \\$day → $day in progress label")
else:
    # Try alternative: maybe already fixed or different escaping
    if "${m}\u062f' : '${h}" in hs:
        print("  [=] _cd interpolation already correct (skip)")
    else:
        errors.append("[home: _cd backslash] could not find anchor — check file manually")

# ── Fix 2: Ramadan greens → gold in _PrayerCard ──────────────
print("\n── Fix 2a: _PrayerCard — add isRamadan field + pass it ──")

# 2a: add isRamadan field to _PrayerCard
patch(HS,
    "final bool isAr, isDark;\n"
    "final Color card, border, muted;\n"
    "final Animation<double> mosqueScale;\n"
    "const _PrayerCard({",
    "final bool isAr, isDark, isRamadan;\n"
    "final Color card, border, muted;\n"
    "final Animation<double> mosqueScale;\n"
    "const _PrayerCard({",
    "home: _PrayerCard add isRamadan field")

# 2b: add isRamadan to constructor
patch(HS,
    "required this.isAr, required this.isDark,\n"
    "required this.card, required this.border, required this.muted,\n"
    "required this.mosqueScale,\n"
    "});",
    "required this.isAr, required this.isDark, required this.isRamadan,\n"
    "required this.card, required this.border, required this.muted,\n"
    "required this.mosqueScale,\n"
    "});",
    "home: _PrayerCard constructor isRamadan param")

# 2c: pass isRamadan from home build to _PrayerCard
patch(HS,
    "    isAr: isAr, isDark: isDark,\n"
    "    card: card, border: border, muted: muted,\n"
    "    mosqueScale: _mosqueScale,\n"
    "  ));",
    "    isAr: isAr, isDark: isDark, isRamadan: isRamadan,\n"
    "    card: card, border: border, muted: muted,\n"
    "    mosqueScale: _mosqueScale,\n"
    "  ));",
    "home: pass isRamadan to _PrayerCard")

# 2d: mosque icon gradient conditional
patch(HS,
    "gradient: const LinearGradient(\n"
    "colors: [Color(0xFF238636), Color(0xFF3FB950)],\n"
    "begin: Alignment.topLeft, end: Alignment.bottomRight,\n"
    "),\n"
    "borderRadius: BorderRadius.circular(12),\n"
    "boxShadow: [BoxShadow(\n"
    "color: AppColors.sunnahGreen.withOpacity(0.4),",
    "gradient: LinearGradient(\n"
    "colors: isRamadan\n"
    "    ? [const Color(0xFF7A5010), const Color(0xFFD4A017)]\n"
    "    : [const Color(0xFF238636), const Color(0xFF3FB950)],\n"
    "begin: Alignment.topLeft, end: Alignment.bottomRight,\n"
    "),\n"
    "borderRadius: BorderRadius.circular(12),\n"
    "boxShadow: [BoxShadow(\n"
    "color: (isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.4),",
    "home: _PrayerCard mosque gradient + shadow Ramadan gold")

# 2e: prayer name text color (halalGreen → conditional)
patch(HS,
    "Text(nm, style: const TextStyle(\n"
    "fontFamily: 'Cairo', fontSize: 20,\n"
    "fontWeight: FontWeight.w900, color: AppColors.halalGreen,\n"
    ")),",
    "Text(nm, style: TextStyle(\n"
    "fontFamily: 'Cairo', fontSize: 20,\n"
    "fontWeight: FontWeight.w900,\n"
    "color: isRamadan ? AppColors.barakahGold : AppColors.halalGreen,\n"
    ")),",
    "home: _PrayerCard prayer name color Ramadan gold")

# 2f: countdown chip background + border + text color
patch(HS,
    "Container(\n"
    "padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),\n"
    "decoration: BoxDecoration(\n"
    "color: AppColors.sunnahGreen.withOpacity(0.1),\n"
    "borderRadius: BorderRadius.circular(24),\n"
    "border: Border.all(\n"
    "color: AppColors.sunnahGreen.withOpacity(0.3), width: 0.5),\n"
    "),\n"
    "child: Text(countdown, style: const TextStyle(\n"
    "fontFamily: 'Cairo', fontSize: 14,\n"
    "fontWeight: FontWeight.w900, color: AppColors.halalGreen,\n"
    ")),\n"
    "),",
    "Container(\n"
    "padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),\n"
    "decoration: BoxDecoration(\n"
    "color: (isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.1),\n"
    "borderRadius: BorderRadius.circular(24),\n"
    "border: Border.all(\n"
    "color: (isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.3), width: 0.5),\n"
    "),\n"
    "child: Text(countdown, style: TextStyle(\n"
    "fontFamily: 'Cairo', fontSize: 14,\n"
    "fontWeight: FontWeight.w900,\n"
    "color: isRamadan ? AppColors.barakahGold : AppColors.halalGreen,\n"
    ")),\n"
    "),",
    "home: _PrayerCard countdown chip Ramadan gold")

print("\n── Fix 2b: _CalRing — add isRamadan field + pass it ─────")

# 2g: add isRamadan to _CalRing fields
patch(HS,
    "final bool isAr, isDark;\n"
    "final String lang;",
    "final bool isAr, isDark, isRamadan;\n"
    "final String lang;",
    "home: _CalRing add isRamadan field")

# 2h: add isRamadan to _CalRing constructor
patch(HS,
    "required this.ringAnim, required this.isAr, required this.isDark,\n"
    "required this.lang,",
    "required this.ringAnim, required this.isAr, required this.isDark,\n"
    "required this.isRamadan, required this.lang,",
    "home: _CalRing constructor isRamadan param")

# 2i: pass isRamadan to _CalRing call
patch(HS,
    "isAr: isAr, isDark: isDark, lang: lang,",
    "isAr: isAr, isDark: isDark, isRamadan: isRamadan, lang: lang,",
    "home: pass isRamadan to _CalRing")

# 2j: Add button color
patch(HS,
    "color: AppColors.sunnahGreen,\n"
    "borderRadius: BorderRadius.circular(20),",
    "color: isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen,\n"
    "borderRadius: BorderRadius.circular(20),",
    "home: _CalRing Add button Ramadan gold")

# 2k: Prophet hint box colors
patch(HS,
    "color: AppColors.sunnahGreen.withOpacity(0.07),\n"
    "borderRadius: BorderRadius.circular(10),",
    "color: (isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.07),\n"
    "borderRadius: BorderRadius.circular(10),",
    "home: _CalRing Prophet hint bg Ramadan gold")

patch(HS,
    "color: AppColors.sunnahGreen.withOpacity(0.2))),\n"
    "      ),\n"
    "      child: Text(",
    "color: (isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.2))),\n"
    "      ),\n"
    "      child: Text(",
    "home: _CalRing Prophet hint border Ramadan gold")

patch(HS,
    "style: const TextStyle(fontFamily: 'Cairo', fontSize: 10,\n"
    "          color: AppColors.sunnahGreen,\n"
    "          fontWeight: FontWeight.w600, height: 1.4),",
    "style: TextStyle(fontFamily: 'Cairo', fontSize: 10,\n"
    "          color: isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen,\n"
    "          fontWeight: FontWeight.w600, height: 1.4),",
    "home: _CalRing Prophet hint text Ramadan gold")

# ── Fix 3: _finish() MET-based kcal burned ───────────────────
print("\n── Fix 3: Fitness _finish() MET calculation ─────────────")

patch(FIT,
    "  void _finish() {\n"
    "    _timer?.cancel();\n"
    "    _running = false;\n"
    "    _done    = true;\n"
    "    final w = _workout;\n"
    "    if (w != null) {\n"
    "      ref.read(streakProvider.notifier).increment();\n"
    "      ref.read(workoutMinutesProvider.notifier).add(w.id, w.durationMin);\n"
    "    }\n"
    "  }",
    "  void _finish() {\n"
    "    _timer?.cancel();\n"
    "    _running = false;\n"
    "    _done    = true;\n"
    "    final w = _workout;\n"
    "    if (w != null) {\n"
    "      final double met = switch (w.category) {\n"
    "        'walking'   => 3.5, 'strength' => 6.0,\n"
    "        'gentle'    => 2.5, 'ramadan'  => 2.5,\n"
    "        'breathing' => 2.0, 'family'   => 3.0,\n"
    "        _           => 4.0,\n"
    "      };\n"
    "      final wKg = ref.read(userProfileProvider)?.weightKg ?? 70.0;\n"
    "      final burned = (met * wKg * w.durationMin / 60).roundToDouble();\n"
    "      ref.read(streakProvider.notifier).increment();\n"
    "      ref.read(workoutMinutesProvider.notifier)\n"
    "          .add(w.id, w.durationMin, kcalBurned: burned);\n"
    "      ref.read(caloriesBurnedTodayProvider.notifier).addBurned(burned);\n"
    "    }\n"
    "  }",
    "fitness: MET-based _finish()")

# ── Fix 4: Onboarding _BottomBar bilingual labels ────────────
print("\n── Fix 4: Onboarding _BottomBar bilingual ───────────────")

# 4a: add isAr field to _BottomBar
patch(OB,
    "  final int page;\n"
    "  final bool isLast, isQuestion, isDark;\n"
    "  final VoidCallback onNext;\n"
    "  const _BottomBar({\n"
    "    required this.page, required this.isLast,\n"
    "    required this.isQuestion, required this.isDark, required this.onNext,\n"
    "  });",
    "  final int page;\n"
    "  final bool isLast, isQuestion, isDark, isAr;\n"
    "  final VoidCallback onNext;\n"
    "  const _BottomBar({\n"
    "    required this.page, required this.isLast,\n"
    "    required this.isQuestion, required this.isDark,\n"
    "    required this.isAr, required this.onNext,\n"
    "  });",
    "onboarding: _BottomBar add isAr field")

# 4b: bilingual label in _BottomBar.build()
patch(OB,
    "    final label = isLast ? '\u0627\u0628\u062f\u0623 \u0631\u062d\u0644\u062a\u0643 \U0001F33F'\n"
    "      : isQuestion ? '\u0627\u0644\u062a\u0627\u0644\u064a \u2192'\n"
    "      : '\u0627\u0644\u062a\u0627\u0644\u064a \u2192';",
    "    final label = isLast\n"
    "      ? (isAr ? '\u0627\u0628\u062f\u0623 \u0631\u062d\u0644\u062a\u0643 \U0001F33F' : 'Start Your Journey \U0001F33F')\n"
    "      : (isAr ? '\u0627\u0644\u062a\u0627\u0644\u064a \u2192' : 'Next \u2192');",
    "onboarding: _BottomBar bilingual label")

# 4c: add isAr to _BottomBar instantiation in build()
# First add isAr definition to _OnboardingState.build()
patch(OB,
    "    final isDark = ref.watch(themeProvider);\n"
    "    final lang   = ref.watch(languageProvider);",
    "    final isDark = ref.watch(themeProvider);\n"
    "    final lang   = ref.watch(languageProvider);\n"
    "    final isAr   = lang == 'ar' || lang == 'ur';",
    "onboarding: add isAr to build()")

# 4d: pass isAr to _BottomBar
patch(OB,
    "            _BottomBar(\n"
    "              page: _page,\n"
    "              isLast: _isLast,\n"
    "              isQuestion: _isQuestion,\n"
    "              isDark: isDark,\n"
    "              onNext: _next,\n"
    "            ),",
    "            _BottomBar(\n"
    "              page: _page,\n"
    "              isLast: _isLast,\n"
    "              isQuestion: _isQuestion,\n"
    "              isDark: isDark,\n"
    "              isAr: isAr,\n"
    "              onNext: _next,\n"
    "            ),",
    "onboarding: pass isAr to _BottomBar")

print("")
if errors:
    print("ERRORS:")
    for e in errors:
        print(f"  !! {e}")
    sys.exit(1)
else:
    print("All patches applied OK")
