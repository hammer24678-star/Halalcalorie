
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

DB = "lib/core/database.dart"
SH = "lib/core/shell.dart"

# ── Fix 1 & 2: Add missing AppDatabase methods ──────────────────────
print("\n── Fix 1+2: AppDatabase.getTodayBurnedKcal + getWeeklyWorkoutDays ──")

patch(DB,
    "  static Future<int> getTodayWorkoutMinutes() async {\n"
    "    final d = await db;\n"
    "    final rows = await d.rawQuery('SELECT SUM(minutes) as total FROM workout_log WHERE date_key=?', [_today()]);\n"
    "    return (rows.first['total'] as int?) ?? 0;\n"
    "  }\n"
    "}",
    "  static Future<int> getTodayWorkoutMinutes() async {\n"
    "    final d = await db;\n"
    "    final rows = await d.rawQuery('SELECT SUM(minutes) as total FROM workout_log WHERE date_key=?', [_today()]);\n"
    "    return (rows.first['total'] as int?) ?? 0;\n"
    "  }\n"
    "\n"
    "  // Calories burned today — estimated at 5 kcal per workout minute\n"
    "  static Future<double> getTodayBurnedKcal() async {\n"
    "    final d = await db;\n"
    "    final rows = await d.rawQuery(\n"
    "        'SELECT SUM(minutes) as total FROM workout_log WHERE date_key=?',\n"
    "        [_today()]);\n"
    "    final mins = (rows.first['total'] as int?) ?? 0;\n"
    "    return mins * 5.0;\n"
    "  }\n"
    "\n"
    "  // Distinct workout days in the past 7 days\n"
    "  static Future<Set<String>> getWeeklyWorkoutDays() async {\n"
    "    final d = await db;\n"
    "    final rows = await d.rawQuery(\n"
    "        \"SELECT DISTINCT date_key FROM workout_log \"\n"
    "        \"WHERE date_key >= date('now','-6 days')\");\n"
    "    return rows.map((r) => r['date_key'] as String).toSet();\n"
    "  }\n"
    "}",
    "database: getTodayBurnedKcal + getWeeklyWorkoutDays")

# ── Fix 3: Ramadan mode → golden glow in bottom nav bar ─────────────
print("\n── Fix 3: Ramadan mode → golden & glowing nav bar ─────────────────")

# 3a. Add isRamadan watch in _AppShellState.build() and pass to _PremiumNav
patch(SH,
    "    final isAr   = lang == 'ar' || lang == 'ur';\n"
    "\n"
    "    return Scaffold(\n"
    "      body: FadeTransition(\n"
    "        opacity: CurvedAnimation(parent: _slideIn, curve: Curves.easeOut),\n"
    "        child: SlideTransition(\n"
    "          position: Tween<Offset>(\n"
    "            begin: const Offset(0, 0.015), end: Offset.zero,\n"
    "          ).animate(CurvedAnimation(parent: _slideIn, curve: Curves.easeOutCubic)),\n"
    "          child: widget.child,\n"
    "        ),\n"
    "      ),\n"
    "      bottomNavigationBar: _PremiumNav(\n"
    "        tabs: _tabs, activeIdx: idx,\n"
    "        isDark: isDark, isAr: isAr,",
    "    final isAr      = lang == 'ar' || lang == 'ur';\n"
    "    final isRamadan = ref.watch(ramadanModeProvider);\n"
    "\n"
    "    return Scaffold(\n"
    "      body: FadeTransition(\n"
    "        opacity: CurvedAnimation(parent: _slideIn, curve: Curves.easeOut),\n"
    "        child: SlideTransition(\n"
    "          position: Tween<Offset>(\n"
    "            begin: const Offset(0, 0.015), end: Offset.zero,\n"
    "          ).animate(CurvedAnimation(parent: _slideIn, curve: Curves.easeOutCubic)),\n"
    "          child: widget.child,\n"
    "        ),\n"
    "      ),\n"
    "      bottomNavigationBar: _PremiumNav(\n"
    "        tabs: _tabs, activeIdx: idx,\n"
    "        isDark: isDark, isAr: isAr, isRamadan: isRamadan,",
    "shell: isRamadan watch + nav param")

# 3b. Add isRamadan field to _PremiumNav widget class
patch(SH,
    "  final bool isDark, isAr;\n"
    "  final void Function(String) onTap;\n"
    "  const _PremiumNav({required this.tabs, required this.activeIdx,\n"
    "    required this.isDark, required this.isAr, required this.onTap});",
    "  final bool isDark, isAr, isRamadan;\n"
    "  final void Function(String) onTap;\n"
    "  const _PremiumNav({required this.tabs, required this.activeIdx,\n"
    "    required this.isDark, required this.isAr,\n"
    "    required this.isRamadan, required this.onTap});",
    "shell: isRamadan field on _PremiumNav")

# 3c. In _PremiumNavState.build(), compute activeColor + activeBg after border line
patch(SH,
    "    final bg     = widget.isDark ? const Color(0xFF161B22) : Colors.white;\n"
    "    final border = widget.isDark ? const Color(0xFF21262D) : const Color(0xFFD0D7DE);\n"
    "\n"
    "    return Container(",
    "    final bg         = widget.isDark ? const Color(0xFF161B22) : Colors.white;\n"
    "    final border     = widget.isDark ? const Color(0xFF21262D) : const Color(0xFFD0D7DE);\n"
    "    // Ramadan mode: swap all greens to gold\n"
    "    final activeColor = widget.isRamadan ? AppColors.barakahGold : AppColors.halalGreen;\n"
    "    final activeBg    = widget.isRamadan\n"
    "        ? AppColors.barakahGold.withOpacity(0.15)\n"
    "        : AppColors.sunnahGreen.withOpacity(0.15);\n"
    "\n"
    "    return Container(",
    "shell: activeColor + activeBg vars")

# 3d. Pill background: sunnahGreen.withOpacity(0.15) → activeBg + Ramadan glow
patch(SH,
    "                              decoration: BoxDecoration(\n"
    "                                color: active\n"
    "                                  ? AppColors.sunnahGreen.withOpacity(0.15)\n"
    "                                  : Colors.transparent,\n"
    "                                borderRadius: BorderRadius.circular(24),\n"
    "                              ),",
    "                              decoration: BoxDecoration(\n"
    "                                color: active ? activeBg : Colors.transparent,\n"
    "                                borderRadius: BorderRadius.circular(24),\n"
    "                                boxShadow: active && widget.isRamadan\n"
    "                                    ? [BoxShadow(\n"
    "                                        color: AppColors.barakahGold.withOpacity(0.55),\n"
    "                                        blurRadius: 16,\n"
    "                                        spreadRadius: 2,\n"
    "                                      )]\n"
    "                                    : null,\n"
    "                              ),",
    "shell: pill color + Ramadan glow shadow")

# 3e. Icon active color (unique anchor: fontSize: active ? 20 : 18)
patch(SH,
    "                                fontSize: active ? 20 : 18,\n"
    "                                color: active\n"
    "                                  ? AppColors.halalGreen\n"
    "                                  : (widget.isDark ? AppColors.darkDimmed : AppColors.lightMuted),",
    "                                fontSize: active ? 20 : 18,\n"
    "                                color: active\n"
    "                                  ? activeColor\n"
    "                                  : (widget.isDark ? AppColors.darkDimmed : AppColors.lightMuted),",
    "shell: icon active color → activeColor")

# 3f. Label active color (unique anchor: fontFamily Cairo + fontSize 9 + fontWeight)
patch(SH,
    "                                fontFamily: 'Cairo',\n"
    "                                fontSize: 9,\n"
    "                                fontWeight: active ? FontWeight.w800 : FontWeight.w400,\n"
    "                                color: active\n"
    "                                  ? AppColors.halalGreen\n"
    "                                  : (widget.isDark ? AppColors.darkDimmed : AppColors.lightMuted),",
    "                                fontFamily: 'Cairo',\n"
    "                                fontSize: 9,\n"
    "                                fontWeight: active ? FontWeight.w800 : FontWeight.w400,\n"
    "                                color: active\n"
    "                                  ? activeColor\n"
    "                                  : (widget.isDark ? AppColors.darkDimmed : AppColors.lightMuted),",
    "shell: label active color → activeColor")

# 3g. Active bar color (unique anchor: margin: const EdgeInsets.only(top: 3))
patch(SH,
    "                              margin: const EdgeInsets.only(top: 3),\n"
    "                              width: active ? 20 : 0,\n"
    "                              height: 2.5,\n"
    "                              decoration: BoxDecoration(\n"
    "                                color: AppColors.halalGreen,\n"
    "                                borderRadius: BorderRadius.circular(2),\n"
    "                              ),",
    "                              margin: const EdgeInsets.only(top: 3),\n"
    "                              width: active ? 20 : 0,\n"
    "                              height: 2.5,\n"
    "                              decoration: BoxDecoration(\n"
    "                                color: activeColor,\n"
    "                                borderRadius: BorderRadius.circular(2),\n"
    "                              ),",
    "shell: active bar color → activeColor")

print("")
if errors:
    print("ERRORS:")
    for e in errors:
        print(f"  !! {e}")
    sys.exit(1)
else:
    print("All patches applied OK")
