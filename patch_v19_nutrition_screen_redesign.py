#!/usr/bin/env python3
"""
patch_v19_nutrition_screen_redesign.py — full nutrition-screen rework
=======================================================================

WHAT THIS DOES
  lib/features/nutrition/nutrition_screen.dart — rebuilt to match the new
  mockup set (5 screenshots: light, dark, and Ramadan states). Two parts:

  1. NEW: فاتح/داكن/رمضان (Light/Dark/Ramadan) pill switcher, added to the
     AppBar. This is a SCREEN-LOCAL preview override (_NutriTheme enum +
     _previewTheme field) — confirmed with you that it should NOT touch
     the app-wide themeProvider/ramadanModeProvider. It opens on whatever
     the real app theme currently is, then only changes how this one
     screen renders. Also confirmed: دارك = green (existing dark palette,
     unchanged), رمضان = the purple/gold night palette (already coded,
     just newly reachable here) — so no new colors were invented, only
     the existing isDark/isRamadan color logic was reused, and extended
     to branch on ramadan where it didn't before (bg/cardBg/muted/textC
     only branched on isDark previously; the AppBar was a fixed gradient
     regardless of either flag).

  2. RESTYLE: card header now shows "الهدف اليومي {goal} سعرة" (this text
     didn't exist before) next to a grouped plan-name+emoji badge (was
     two separate widgets pinned to opposite ends of the row, not a
     single badge). Ring's center text -> full phrases ("سعرة متبقية" /
     "من {goal} سعرة") instead of the old terse "متبقي" / "/ {goal}".
     Eaten/Burned boxes get an icon badge + corner dot. The diet-plan
     pills (متوازن/عالي البروتين/عالي الكارب/كيتو) moved OUT of the card
     and got bigger/bolder, accent-filled when selected — was a thin
     bordered-chip row squeezed inside the card. Macro bars (protein/
     carbs/fat) moved out of the card too, each gets an icon badge, and
     the hardcoded 'g' unit suffix is now localized ('جم'/'g' — it was
     never translated before). Values shown (eaten/burned/macros) are
     still the real bound numbers — the mockup's "١٩" etc. reads like
     placeholder sample data, not something to hardcode.

  3. One reversal, flagged explicitly: the greeting font goes back to
     LemonBrush (was Bravoon). v17 moved it to Bravoon on your explicit
     call, and v18's docstring refused to touch it for exactly that
     reason. This mockup set is unambiguous (cursive gold script, shown
     5 times across light/dark/ramadan) so I've reverted it — flagging
     it here in case that wasn't what you meant.

CONFIRMED WITH YOU BEFORE WRITING THIS:
  - داكن = the existing green dark palette (the very first screenshot).
    رمضان = the purple/gold palette (the other four screenshots).
  - The switcher affects the Nutrition screen only, not the whole app.

NOT INCLUDED HERE (see chat reply):
  - The "⭐ / 🔑الدخول / 📝الأسئلة / 🖐️الترحيب" chip row visible in one
    screenshot, above the تغذية tabs. That reads like a QA/screens-index
    overlay rather than real Nutrition-screen UI, so I left it out —
    say the word if it's actually meant to ship.
  - No second full-width "أضف طعام" button. The mockup shows one inline
    in the flow, but the screen already has a working FloatingAction
    button doing the same job — didn't want two entry points for one
    action.
  - Ramadan-mode light/"day" variant. Only a night-mode Ramadan reference
    exists (in this set and the original theme.dart comment), so رمضان
    always renders the night palette here, same precedent theme.dart
    already sets for ramadanDay.

SAFETY: same exact-match-or-refuse rule as every other patch in this set.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
LEDGER = []
FAILED = []


def _p(relpath):
    return ROOT / relpath


def apply_one(relpath, old, new, note):
    path = _p(relpath)
    if not path.exists():
        FAILED.append(f"{relpath}: file not found")
        print(f"REFUSING {relpath}: file not found — {note}")
        return False
    text = path.read_text(encoding="utf-8")
    n = text.count(old)
    if n != 1:
        FAILED.append(f"{relpath}: {note} (expected 1 match, found {n})")
        print(f"REFUSING {relpath}: expected exactly 1 match for {note!r}, found {n}. "
              f"No changes made to this file.")
        return False
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    LEDGER.append(f"OK   {relpath}: {note}")
    return True


NUTRITION = "lib/features/nutrition/nutrition_screen.dart"


def patch_enum():
    apply_one(
        NUTRITION,
        "enum MealType { breakfast, lunch, dinner, snack }\n",
        "enum MealType { breakfast, lunch, dinner, snack }\n"
        "\n"
        "// Screen-local theme preview — overrides how THIS screen renders\n"
        "// without touching the app-wide themeProvider/ramadanModeProvider\n"
        "// (those are still read once, in initState, to pick the opening pill).\n"
        "enum _NutriTheme { light, dark, ramadan }\n",
        "add _NutriTheme enum for the light/dark/ramadan pill switcher",
    )


def patch_field():
    apply_one(
        NUTRITION,
        "  late TabController _tab;\n"
        "  late AnimationController _stagger;\n",
        "  late TabController _tab;\n"
        "  late AnimationController _stagger;\n"
        "  late _NutriTheme _previewTheme;\n",
        "add _previewTheme field",
    )


def patch_init_state():
    apply_one(
        NUTRITION,
        "  void initState() {\n"
        "    super.initState();\n"
        "    _tab = TabController(length: 3, vsync: this);\n"
        "    _tab.addListener(() {\n"
        "      setState(() {});\n"
        "      _stagger.forward(from: 0);\n"
        "    });\n"
        "    _stagger = AnimationController(\n"
        "        vsync: this,\n"
        "        duration: const Duration(milliseconds: 700))\n"
        "      ..forward();\n"
        "  }\n",
        "  void initState() {\n"
        "    super.initState();\n"
        "    // One-time read of the real app theme so the pills open on the\n"
        "    // mode you're already in. From here on they're a local override\n"
        "    // only — they never write back to the global providers.\n"
        "    _previewTheme = ref.read(ramadanModeProvider)\n"
        "        ? _NutriTheme.ramadan\n"
        "        : (ref.read(themeProvider) ? _NutriTheme.dark : _NutriTheme.light);\n"
        "    _tab = TabController(length: 3, vsync: this);\n"
        "    _tab.addListener(() {\n"
        "      setState(() {});\n"
        "      _stagger.forward(from: 0);\n"
        "    });\n"
        "    _stagger = AnimationController(\n"
        "        vsync: this,\n"
        "        duration: const Duration(milliseconds: 700))\n"
        "      ..forward();\n"
        "  }\n",
        "initState: seed _previewTheme from the real app theme once",
    )


def patch_switcher_widget():
    apply_one(
        NUTRITION,
        "  @override\n"
        "  void dispose() {\n"
        "    _tab.dispose();\n"
        "    _stagger.dispose();\n"
        "    super.dispose();\n"
        "  }\n",
        "  @override\n"
        "  void dispose() {\n"
        "    _tab.dispose();\n"
        "    _stagger.dispose();\n"
        "    super.dispose();\n"
        "  }\n"
        "\n"
        "  // v19: فاتح/داكن/رمضان preview switcher — local to this screen only.\n"
        "  Widget _themeSwitcherPills(\n"
        "      bool isAr, String Function(String, String) tl, Color textC) {\n"
        "    Widget pill(_NutriTheme mode, {IconData? icon, String? emoji,\n"
        "        required String labelAr, required String labelEn,\n"
        "        required Color fillColor, Color selTextColor = Colors.white}) {\n"
        "      final sel = _previewTheme == mode;\n"
        "      final unselFg = textC.withOpacity(0.65);\n"
        "      return GestureDetector(\n"
        "        onTap: () => setState(() => _previewTheme = mode),\n"
        "        child: AnimatedContainer(\n"
        "          duration: const Duration(milliseconds: 200),\n"
        "          margin: const EdgeInsets.symmetric(horizontal: 4),\n"
        "          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),\n"
        "          decoration: BoxDecoration(\n"
        "            color: sel ? fillColor : textC.withOpacity(0.06),\n"
        "            borderRadius: BorderRadius.circular(22),\n"
        "            border: sel ? null : Border.all(color: textC.withOpacity(0.15)),\n"
        "          ),\n"
        "          child: Row(mainAxisSize: MainAxisSize.min, children: [\n"
        "            if (icon != null)\n"
        "              Icon(icon, size: 15, color: sel ? selTextColor : unselFg)\n"
        "            else\n"
        "              Text(emoji!, style: const TextStyle(fontSize: 13)),\n"
        "            const SizedBox(width: 6),\n"
        "            Text(tl(labelAr, labelEn), style: TextStyle(\n"
        "                fontFamily: 'Aligarh', fontSize: 12,\n"
        "                fontWeight: sel ? FontWeight.w800 : FontWeight.w600,\n"
        "                color: sel ? selTextColor : unselFg)),\n"
        "          ]),\n"
        "        ),\n"
        "      );\n"
        "    }\n"
        "\n"
        "    return Padding(\n"
        "      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),\n"
        "      child: SingleChildScrollView(\n"
        "        scrollDirection: Axis.horizontal,\n"
        "        child: Row(children: [\n"
        "          pill(_NutriTheme.light, emoji: '☀️',\n"
        "              labelAr: 'فاتح', labelEn: 'Light',\n"
        "              fillColor: AppColors.brandGreen),\n"
        "          pill(_NutriTheme.dark, icon: Icons.nightlight_round,\n"
        "              labelAr: 'داكن', labelEn: 'Dark',\n"
        "              fillColor: AppColors.darkCardAlt),\n"
        "          pill(_NutriTheme.ramadan, emoji: '🌙',\n"
        "              labelAr: 'رمضان', labelEn: 'Ramadan',\n"
        "              fillColor: AppColors.ramadanGold,\n"
        "              selTextColor: AppColors.ramadanInk),\n"
        "        ]),\n"
        "      ),\n"
        "    );\n"
        "  }\n",
        "add _themeSwitcherPills widget",
    )


def patch_providers_and_colors():
    apply_one(
        NUTRITION,
        "    final isDark  = ref.watch(themeProvider);\n"
        "    final cals    = ref.watch(caloriesProvider);\n"
        "    final profile = ref.watch(userProfileProvider);\n"
        "    final plan      = ref.watch(macroPlanProvider);\n"
        "    final isRamadan = ref.watch(ramadanModeProvider);\n"
        "    final isPremium  = ref.watch(premiumProvider);\n"
        "    final burnedKcal = ref.watch(caloriesBurnedTodayProvider).round();\n"
        "    final bg         = isDark ? AppColors.darkBg : const Color(0xFFF2F4F7);\n"
        "    final cardBg  = isDark ? AppColors.darkCard : Colors.white;\n"
        "    final muted   = isDark ? AppColors.darkMuted : const Color(0xFF9E9E9E);\n"
        "    final textC   = isDark ? AppColors.darkText : AppColors.lightText;\n",
        "    // Screen-local preview override (see _NutriTheme) — NOT the global\n"
        "    // themeProvider/ramadanModeProvider, so these pills only change how\n"
        "    // the Nutrition screen itself looks; they don't write back globally.\n"
        "    final isDark    = _previewTheme != _NutriTheme.light;\n"
        "    final isRamadan = _previewTheme == _NutriTheme.ramadan;\n"
        "    final cals    = ref.watch(caloriesProvider);\n"
        "    final profile = ref.watch(userProfileProvider);\n"
        "    final plan      = ref.watch(macroPlanProvider);\n"
        "    final isPremium  = ref.watch(premiumProvider);\n"
        "    final burnedKcal = ref.watch(caloriesBurnedTodayProvider).round();\n"
        "    final bg         = isRamadan ? AppColors.ramadanNight\n"
        "        : isDark ? AppColors.darkBg : const Color(0xFFF2F4F7);\n"
        "    final cardBg  = isRamadan ? AppColors.ramadanCard\n"
        "        : isDark ? AppColors.darkCard : Colors.white;\n"
        "    final muted   = isRamadan ? AppColors.ramadanMuted\n"
        "        : isDark ? AppColors.darkMuted : const Color(0xFF9E9E9E);\n"
        "    final textC   = isRamadan ? AppColors.ramadanText\n"
        "        : isDark ? AppColors.darkText : AppColors.lightText;\n",
        "isDark/isRamadan now come from _previewTheme; bg/cardBg/muted/textC branch on ramadan too",
    )
    apply_one(
        NUTRITION,
        "    // Ramadan accent — gold when Ramadan, green otherwise\n"
        "    final accent = isRamadan ? AppColors.accentGold : AppColors.brandGreen;\n"
        "    final accentDark = isRamadan ? const Color(0xFFB88E2A) : const Color(0xFF1A6B3C);\n",
        "    // Ramadan accent — gold when Ramadan, green otherwise\n"
        "    final accent = isRamadan ? AppColors.accentGold : AppColors.brandGreen;\n"
        "    final accentDark = isRamadan ? const Color(0xFFB88E2A) : const Color(0xFF1A6B3C);\n"
        "    final goalLabel = '${tl('الهدف اليومي', 'Daily goal')} $goal ${tl('سعرة', 'kcal')}';\n"
        "    final ofGoalLabel = '${tl('من', 'of')} $goal ${tl('سعرة', 'kcal')}';\n",
        "add goalLabel/ofGoalLabel strings for the card header + ring",
    )


def patch_appbar():
    apply_one(
        NUTRITION,
        "        appBar: AppBar(\n"
        "          flexibleSpace: Container(\n"
        "            decoration: BoxDecoration(\n"
        "              gradient: LinearGradient(\n"
        "                colors: isRamadan\n"
        "                    ? [AppColors.ramadanNight, AppColors.ramadanCard]\n"
        "                    : [const Color(0xFF1A6B3C), AppColors.brandGreen],\n"
        "                begin: Alignment.topLeft,\n"
        "                end: Alignment.bottomRight,\n"
        "              ),\n"
        "            ),\n"
        "          ),\n"
        "          title: Text(tl('التغذية', 'Nutrition'),\n"
        "              style: const TextStyle(fontFamily: 'Aligarh',\n"
        "                  fontWeight: FontWeight.w800, fontSize: 18)),\n"
        "          backgroundColor: Colors.transparent,\n"
        "          foregroundColor: Colors.white,\n"
        "          elevation: 0,\n"
        "          actions: [\n"
        "            IconButton(\n"
        "              icon: const Icon(Icons.add_circle_outline_rounded,\n"
        "                  color: Colors.white, size: 26),\n"
        "              onPressed: () => _openAdd(context, isAr, isDark, isPremium),\n"
        "              tooltip: tl('أضف طعام', 'Add Food'),\n"
        "            ),\n"
        "          ],\n"
        "          bottom: TabBar(\n"
        "            controller: _tab,\n"
        "            indicatorColor: isRamadan ? AppColors.accentGold : Colors.white,\n"
        "            indicatorWeight: 3,\n"
        "            indicatorSize: TabBarIndicatorSize.label,\n"
        "            labelStyle: const TextStyle(fontFamily: 'Aligarh',\n"
        "                fontWeight: FontWeight.w700, fontSize: 14),\n"
        "            unselectedLabelStyle: const TextStyle(\n"
        "                fontFamily: 'Aligarh', fontSize: 14),\n"
        "            labelColor: Colors.white,\n"
        "            unselectedLabelColor: Colors.white54,\n"
        "            tabs: [\n"
        "              Tab(text: tl('اليوم', 'Today')),\n"
        "              Tab(text: tl('الوصفات', 'Recipes')),\n"
        "              Tab(text: tl('مخطط AI', 'AI Plan')),\n"
        "            ],\n"
        "          ),\n"
        "        ),\n",
        "        appBar: AppBar(\n"
        "          // v19: flat bar in the screen's own bg/text colors, matching\n"
        "          // the mockup (was a fixed green/ramadan gradient with white\n"
        "          // text no matter what the light/dark/ramadan pill was set to).\n"
        "          title: Text(tl('التغذية', 'Nutrition'),\n"
        "              style: TextStyle(fontFamily: 'Aligarh',\n"
        "                  fontWeight: FontWeight.w800, fontSize: 18, color: textC)),\n"
        "          backgroundColor: bg,\n"
        "          foregroundColor: textC,\n"
        "          elevation: 0,\n"
        "          actions: [\n"
        "            IconButton(\n"
        "              icon: Icon(Icons.add_circle_outline_rounded,\n"
        "                  color: accent, size: 26),\n"
        "              onPressed: () => _openAdd(context, isAr, isDark, isPremium),\n"
        "              tooltip: tl('أضف طعام', 'Add Food'),\n"
        "            ),\n"
        "          ],\n"
        "          bottom: PreferredSize(\n"
        "            preferredSize: const Size.fromHeight(92),\n"
        "            child: Column(children: [\n"
        "              _themeSwitcherPills(isAr, tl, textC),\n"
        "              TabBar(\n"
        "                controller: _tab,\n"
        "                indicatorColor: accent,\n"
        "                indicatorWeight: 3,\n"
        "                indicatorSize: TabBarIndicatorSize.label,\n"
        "                labelStyle: const TextStyle(fontFamily: 'Aligarh',\n"
        "                    fontWeight: FontWeight.w700, fontSize: 14),\n"
        "                unselectedLabelStyle: const TextStyle(\n"
        "                    fontFamily: 'Aligarh', fontSize: 14),\n"
        "                labelColor: textC,\n"
        "                unselectedLabelColor: muted,\n"
        "                tabs: [\n"
        "                  Tab(text: tl('اليوم', 'Today')),\n"
        "                  Tab(text: tl('الوصفات', 'Recipes')),\n"
        "                  Tab(text: tl('مخطط AI', 'AI Plan')),\n"
        "                ],\n"
        "              ),\n"
        "            ]),\n"
        "          ),\n"
        "        ),\n",
        "AppBar: flatten to theme colors, add pill switcher above the TabBar",
    )


def patch_greeting_and_goal_badge():
    apply_one(
        NUTRITION,
        "                            Text(() {\n"
        "                              final h = DateTime.now().hour;\n"
        "                              if (h < 12) return l.goodMorning;\n"
        "                              if (h < 17) return l.goodAfternoon;\n"
        "                              return l.goodEvening;\n"
        "                            }(),\n"
        "                            style: TextStyle(fontFamily: 'Bravoon', fontWeight: FontWeight.w700,\n"
        "                                fontSize: 30, height: 1.0,\n"
        "                                color: isDark ? AppColors.greetGold : AppColors.greetGoldLight)),\n"
        "                            Text(\n"
        "                              DateFormat(tLang(lang, 'EEEE، d MMMM', 'EEEE, MMMM d', 'EEEE, MMMM d', 'EEEE, MMMM d', 'EEEE, MMMM d', 'EEEE, MMMM d'),\n"
        "                                  tLang(lang, 'ar', 'en', 'en', 'en', 'en', 'en')).format(DateTime.now()),\n"
        "                              style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                  fontSize: 11, color: muted)),\n"
        "                          ]),\n"
        "                        Container(\n"
        "                          padding: const EdgeInsets.symmetric(\n"
        "                              horizontal: 12, vertical: 6),\n"
        "                          decoration: BoxDecoration(\n"
        "                            color: accent.withOpacity(0.1),\n"
        "                            borderRadius: BorderRadius.circular(20),\n"
        "                            border: Border.all(\n"
        "                                color: accent.withOpacity(0.3)),\n"
        "                          ),\n"
        "                          child: Text('🎯 $goal ${tl(\" سعرة\", \"kcal\")}',\n"
        "                            style: const TextStyle(fontFamily: 'Aligarh',\n"
        "                                fontSize: 12, fontWeight: FontWeight.w700,\n"
        "                                color: AppColors.brandGreen)),\n"
        "                        ),\n",
        "                            Text(() {\n"
        "                              final h = DateTime.now().hour;\n"
        "                              if (h < 12) return l.goodMorning;\n"
        "                              if (h < 17) return l.goodAfternoon;\n"
        "                              return l.goodEvening;\n"
        "                            }(),\n"
        "                            // v19: back to LemonBrush per the new mockup\n"
        "                            // set (v17 moved this to Bravoon on your\n"
        "                            // explicit call — flagging the reversal since\n"
        "                            // it undoes that, per the v18 patch note).\n"
        "                            style: TextStyle(fontFamily: 'LemonBrush',\n"
        "                                fontSize: 34, height: 1.0,\n"
        "                                color: isRamadan ? AppColors.ramadanGold\n"
        "                                    : isDark ? AppColors.greetGold\n"
        "                                              : AppColors.greetGoldLight)),\n"
        "                            Text(\n"
        "                              DateFormat(tLang(lang, 'EEEE، d MMMM', 'EEEE, MMMM d', 'EEEE, MMMM d', 'EEEE, MMMM d', 'EEEE, MMMM d', 'EEEE, MMMM d'),\n"
        "                                  tLang(lang, 'ar', 'en', 'en', 'en', 'en', 'en')).format(DateTime.now()),\n"
        "                              style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                  fontSize: 11, color: muted)),\n"
        "                          ]),\n"
        "                        Container(\n"
        "                          padding: const EdgeInsets.symmetric(\n"
        "                              horizontal: 12, vertical: 6),\n"
        "                          decoration: BoxDecoration(\n"
        "                            color: accent.withOpacity(0.1),\n"
        "                            borderRadius: BorderRadius.circular(20),\n"
        "                            border: Border.all(\n"
        "                                color: accent.withOpacity(0.3)),\n"
        "                          ),\n"
        "                          child: Text('🎯 $goal ${tl(\" سعرة\", \"kcal\")}',\n"
        "                            style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                fontSize: 12, fontWeight: FontWeight.w700,\n"
        "                                color: accent)),\n"
        "                        ),\n",
        "greeting -> LemonBrush (+ ramadan gold), goal badge text -> accent-aware",
    )


def patch_card_header():
    apply_one(
        NUTRITION,
        "                      // Plan badge\n"
        "                      Padding(\n"
        "                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),\n"
        "                        child: Row(\n"
        "                          mainAxisAlignment: MainAxisAlignment.spaceBetween,\n"
        "                          children: [\n"
        "                            Text(\n"
        "                              isAr ? plan.nameAr() : plan.nameEn(),\n"
        "                              style: const TextStyle(fontFamily: 'Aligarh',\n"
        "                                  fontSize: 12, fontWeight: FontWeight.w700,\n"
        "                                  color: AppColors.brandGreen)),\n"
        "                            Text(plan.emoji(),\n"
        "                                style: const TextStyle(fontSize: 16)),\n"
        "                          ],\n"
        "                        ),\n"
        "                      ),\n",
        "                      // Plan badge + daily-goal label, matching mockup\n"
        "                      // (goal text at RTL-start/right, plan pill at end/left)\n"
        "                      Padding(\n"
        "                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),\n"
        "                        child: Row(\n"
        "                          mainAxisAlignment: MainAxisAlignment.spaceBetween,\n"
        "                          children: [\n"
        "                            Text(goalLabel,\n"
        "                                style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                    fontSize: 12, fontWeight: FontWeight.w600,\n"
        "                                    color: muted)),\n"
        "                            Row(mainAxisSize: MainAxisSize.min, children: [\n"
        "                              Text(\n"
        "                                isAr ? plan.nameAr() : plan.nameEn(),\n"
        "                                style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                    fontSize: 12, fontWeight: FontWeight.w800,\n"
        "                                    color: accent)),\n"
        "                              const SizedBox(width: 5),\n"
        "                              Text(plan.emoji(),\n"
        "                                  style: const TextStyle(fontSize: 15)),\n"
        "                            ]),\n"
        "                          ],\n"
        "                        ),\n"
        "                      ),\n",
        "card header: add الهدف اليومي label, group plan name+emoji into one badge",
    )


def patch_ring_text():
    apply_one(
        NUTRITION,
        "                            child: Column(mainAxisSize: MainAxisSize.min,\n"
        "                                children: [\n"
        "                              Text('${left.abs()}',\n"
        "                                  style: TextStyle(\n"
        "                                      fontFamily: 'Aligarh',\n"
        "                                      fontSize: 30,\n"
        "                                      fontWeight: FontWeight.w900,\n"
        "                                      color: calCol)),\n"
        "                              Text(\n"
        "                                left < 0\n"
        "                                    ? tl('تجاوزت!', 'Over!')\n"
        "                                    : tl('متبقي', 'left'),\n"
        "                                style: TextStyle(\n"
        "                                    fontFamily: 'Aligarh',\n"
        "                                    fontSize: 10,\n"
        "                                    fontWeight: FontWeight.w700,\n"
        "                                    color: calCol),\n"
        "                              ),\n"
        "                              Text('/ $goal',\n"
        "                                  style: TextStyle(\n"
        "                                      fontFamily: 'Aligarh',\n"
        "                                      fontSize: 9,\n"
        "                                      color: muted)),\n"
        "                            ]),\n",
        "                            child: Column(mainAxisSize: MainAxisSize.min,\n"
        "                                children: [\n"
        "                              Text('${left.abs()}',\n"
        "                                  style: TextStyle(\n"
        "                                      fontFamily: 'Aligarh',\n"
        "                                      fontSize: 30,\n"
        "                                      fontWeight: FontWeight.w900,\n"
        "                                      color: calCol)),\n"
        "                              Text(\n"
        "                                left < 0\n"
        "                                    ? tl('سعرة زيادة', 'kcal over')\n"
        "                                    : tl('سعرة متبقية', 'kcal remaining'),\n"
        "                                style: TextStyle(\n"
        "                                    fontFamily: 'Aligarh',\n"
        "                                    fontSize: 10,\n"
        "                                    fontWeight: FontWeight.w700,\n"
        "                                    color: calCol),\n"
        "                              ),\n"
        "                              Text(ofGoalLabel,\n"
        "                                  style: TextStyle(\n"
        "                                      fontFamily: 'Aligarh',\n"
        "                                      fontSize: 9,\n"
        "                                      color: muted)),\n"
        "                            ]),\n",
        "ring center text -> full phrases matching mockup",
    )


def patch_summary_box_calls():
    apply_one(
        NUTRITION,
        "                          _summaryBox(\n"
        "                              tl('المأكول', 'Eaten'),\n"
        "                              '$eaten',\n"
        "                              AppColors.brandGreen, isDark),\n",
        "                          _summaryBox('🍴',\n"
        "                              tl('المأكول', 'Eaten'),\n"
        "                              '$eaten',\n"
        "                              AppColors.brandGreen, isDark),\n",
        "eaten box: pass fork emoji into restyled _summaryBox",
    )
    apply_one(
        NUTRITION,
        "                          _summaryBox(\n"
        "                              tl('المحروق', 'Burned'),\n"
        "                              '$burnedKcal',\n"
        "                              AppColors.haramRed, isDark),\n",
        "                          _summaryBox('🔥',\n"
        "                              tl('المحروق', 'Burned'),\n"
        "                              '$burnedKcal',\n"
        "                              AppColors.haramRed, isDark),\n",
        "burned box: pass flame emoji into restyled _summaryBox",
    )


def patch_remove_chips_and_macros_from_card():
    apply_one(
        NUTRITION,
        "                      const SizedBox(height: 20),\n"
        "                      const Divider(height: 1),\n"
        "                      const SizedBox(height: 16),\n"
        "                      // Macro plan chips\n"
        "                      SingleChildScrollView(\n"
        "                        scrollDirection: Axis.horizontal,\n"
        "                        child: Row(\n"
        "                          children: MacroPlan.values.map((p) {\n"
        "                            final sel = p == plan;\n"
        "                            return GestureDetector(\n"
        "                              onTap: () => ref.read(macroPlanProvider.notifier).set(p),\n"
        "                              child: AnimatedContainer(\n"
        "                                duration: const Duration(milliseconds: 200),\n"
        "                                margin: const EdgeInsets.only(right: 6, bottom: 10),\n"
        "                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),\n"
        "                                decoration: BoxDecoration(\n"
        "                                  color: sel ? AppColors.brandGreen : Colors.transparent,\n"
        "                                  border: Border.all(\n"
        "                                    color: sel ? AppColors.brandGreen : AppColors.lightMuted.withOpacity(0.4),\n"
        "                                  ),\n"
        "                                  borderRadius: BorderRadius.circular(20),\n"
        "                                ),\n"
        "                                child: Text(\n"
        "                                  '${p.emoji()} ${isAr ? p.nameAr() : p.nameEn()}',\n"
        "                                  style: TextStyle(\n"
        "                                    fontFamily: 'Aligarh', fontSize: 11,\n"
        "                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w400,\n"
        "                                    color: sel ? Colors.white : muted,\n"
        "                                  ),\n"
        "                                ),\n"
        "                              ),\n"
        "                            );\n"
        "                          }).toList(),\n"
        "                        ),\n"
        "                      ),\n"
        "                      // Macro progress bars (plan-based goals)\n"
        "                      _macroRow(\n"
        "                        tl('بروتين', 'Protein'),\n"
        "                        cals.proteinTotal,\n"
        "                        (goal * plan.proteinPct / 100) / 4,\n"
        "                        AppColors.halalGreen,\n"
        "                      ),\n"
        "                      const SizedBox(height: 10),\n"
        "                      _macroRow(\n"
        "                        tl('كربوهيدرات', 'Carbs'),\n"
        "                        cals.carbsTotal,\n"
        "                        (goal * plan.carbsPct / 100) / 4,\n"
        "                        AppColors.waterBlue,\n"
        "                      ),\n"
        "                      const SizedBox(height: 10),\n"
        "                      _macroRow(\n"
        "                        tl('دهون', 'Fat'),\n"
        "                        cals.fatTotal,\n"
        "                        (goal * plan.fatPct / 100) / 9,\n"
        "                        AppColors.accentGold,\n"
        "                      ),\n"
        "                      const SizedBox(height: 14),\n"
        "                      Row(children: [\n"
        "                        const Text('💧', style: TextStyle(fontSize: 14)),\n"
        "                        const SizedBox(width: 8),\n"
        "                        Expanded(child: Column(\n"
        "                          crossAxisAlignment: CrossAxisAlignment.start,\n"
        "                          children: [\n"
        "                            Row(\n"
        "                              mainAxisAlignment: MainAxisAlignment.spaceBetween,\n"
        "                              children: [\n"
        "                                Text(tl('الماء', 'Water'),\n"
        "                                  style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                    fontSize: 12, fontWeight: FontWeight.w600,\n"
        "                                    color: AppColors.waterBlue)),\n"
        "                                Text('${ref.watch(waterProvider).cups} / ${ref.watch(waterProvider).goal}  •  ${(ref.watch(waterProvider).percent * 100).toInt()}%',\n"
        "                                  style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                    fontSize: 10,\n"
        "                                    color: AppColors.waterBlue.withOpacity(0.75))),\n"
        "                              ],\n"
        "                            ),\n"
        "                            const SizedBox(height: 5),\n"
        "                            ClipRRect(\n"
        "                              borderRadius: BorderRadius.circular(8),\n"
        "                              child: LinearProgressIndicator(\n"
        "                                value: ref.watch(waterProvider).percent,\n"
        "                                backgroundColor: AppColors.waterBlue.withOpacity(0.12),\n"
        "                                valueColor: const AlwaysStoppedAnimation(\n"
        "                                    AppColors.waterBlue),\n"
        "                                minHeight: 10,\n"
        "                              ),\n"
        "                            ),\n"
        "                          ],\n"
        "                        )),\n"
        "                        const SizedBox(width: 8),\n"
        "                        GestureDetector(\n"
        "                          onTap: () => ref.read(waterProvider.notifier).add(),\n"
        "                          child: Container(\n"
        "                            width: 32, height: 32,\n"
        "                            decoration: BoxDecoration(\n"
        "                              color: AppColors.waterBlue.withOpacity(0.15),\n"
        "                              shape: BoxShape.circle),\n"
        "                            child: const Icon(Icons.add,\n"
        "                                color: AppColors.waterBlue, size: 18)),\n"
        "                        ),\n"
        "                      ]),\n"
        "                    ]),          // end macro Column\n",
        "                      const SizedBox(height: 20),\n"
        "                    ]),          // end macro Column\n",
        "card: drop divider/diet-pills/macro-bars/water (moving them outside the card next)",
    )


def patch_insert_pills_and_macros_below_card():
    apply_one(
        NUTRITION,
        "                )),             // end Container + _anim\n"
        "\n"
        "                  const SizedBox(height: 16),\n"
        "\n"
        "                  // ── Meal Sections ───────────────────────\n",
        "                )),             // end Container + _anim\n"
        "\n"
        "                  const SizedBox(height: 16),\n"
        "\n"
        "                  // ── Diet plan pills — moved out of the card, restyled\n"
        "                  // as bold accent-filled pills to match the mockup ──\n"
        "                  _anim(1, SingleChildScrollView(\n"
        "                    scrollDirection: Axis.horizontal,\n"
        "                    child: Row(\n"
        "                      children: MacroPlan.values.map((p) {\n"
        "                        final sel = p == plan;\n"
        "                        return GestureDetector(\n"
        "                          onTap: () => ref.read(macroPlanProvider.notifier).set(p),\n"
        "                          child: AnimatedContainer(\n"
        "                            duration: const Duration(milliseconds: 200),\n"
        "                            margin: const EdgeInsets.only(left: 8),\n"
        "                            padding: const EdgeInsets.symmetric(\n"
        "                                horizontal: 16, vertical: 10),\n"
        "                            decoration: BoxDecoration(\n"
        "                              color: sel ? accent : cardBg,\n"
        "                              borderRadius: BorderRadius.circular(24),\n"
        "                              border: sel ? null\n"
        "                                  : Border.all(color: muted.withOpacity(0.35)),\n"
        "                            ),\n"
        "                            child: Row(mainAxisSize: MainAxisSize.min, children: [\n"
        "                              Text(p.emoji(), style: const TextStyle(fontSize: 15)),\n"
        "                              const SizedBox(width: 6),\n"
        "                              Text(isAr ? p.nameAr() : p.nameEn(),\n"
        "                                style: TextStyle(\n"
        "                                  fontFamily: 'Aligarh', fontSize: 13,\n"
        "                                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,\n"
        "                                  color: sel\n"
        "                                      ? (isRamadan ? AppColors.ramadanInk : Colors.white)\n"
        "                                      : textC,\n"
        "                                ),\n"
        "                              ),\n"
        "                            ]),\n"
        "                          ),\n"
        "                        );\n"
        "                      }).toList(),\n"
        "                    ),\n"
        "                  )),\n"
        "\n"
        "                  const SizedBox(height: 16),\n"
        "\n"
        "                  // ── Macro bars + water — moved out of the card, flat\n"
        "                  // on the page bg with thin dividers, per mockup ──\n"
        "                  _anim(2, Column(children: [\n"
        "                    _macroRow('🍀', tl('بروتين', 'Protein'),\n"
        "                        cals.proteinTotal,\n"
        "                        (goal * plan.proteinPct / 100) / 4,\n"
        "                        AppColors.halalGreen),\n"
        "                    Divider(height: 28, color: muted.withOpacity(0.15)),\n"
        "                    _macroRow('🌾', tl('كربوهيدرات', 'Carbs'),\n"
        "                        cals.carbsTotal,\n"
        "                        (goal * plan.carbsPct / 100) / 4,\n"
        "                        AppColors.waterBlue),\n"
        "                    Divider(height: 28, color: muted.withOpacity(0.15)),\n"
        "                    _macroRow('💧', tl('دهون', 'Fat'),\n"
        "                        cals.fatTotal,\n"
        "                        (goal * plan.fatPct / 100) / 9,\n"
        "                        AppColors.accentGold),\n"
        "                    const SizedBox(height: 18),\n"
        "                    Row(children: [\n"
        "                      const Text('💧', style: TextStyle(fontSize: 14)),\n"
        "                      const SizedBox(width: 8),\n"
        "                      Expanded(child: Column(\n"
        "                        crossAxisAlignment: CrossAxisAlignment.start,\n"
        "                        children: [\n"
        "                          Row(\n"
        "                            mainAxisAlignment: MainAxisAlignment.spaceBetween,\n"
        "                            children: [\n"
        "                              Text(tl('الماء', 'Water'),\n"
        "                                style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                  fontSize: 12, fontWeight: FontWeight.w600,\n"
        "                                  color: AppColors.waterBlue)),\n"
        "                              Text('${ref.watch(waterProvider).cups} / ${ref.watch(waterProvider).goal}  •  ${(ref.watch(waterProvider).percent * 100).toInt()}%',\n"
        "                                style: TextStyle(fontFamily: 'Aligarh',\n"
        "                                  fontSize: 10,\n"
        "                                  color: AppColors.waterBlue.withOpacity(0.75))),\n"
        "                            ],\n"
        "                          ),\n"
        "                          const SizedBox(height: 5),\n"
        "                          ClipRRect(\n"
        "                            borderRadius: BorderRadius.circular(8),\n"
        "                            child: LinearProgressIndicator(\n"
        "                              value: ref.watch(waterProvider).percent,\n"
        "                              backgroundColor: AppColors.waterBlue.withOpacity(0.12),\n"
        "                              valueColor: const AlwaysStoppedAnimation(\n"
        "                                  AppColors.waterBlue),\n"
        "                              minHeight: 10,\n"
        "                            ),\n"
        "                          ),\n"
        "                        ],\n"
        "                      )),\n"
        "                      const SizedBox(width: 8),\n"
        "                      GestureDetector(\n"
        "                        onTap: () => ref.read(waterProvider.notifier).add(),\n"
        "                        child: Container(\n"
        "                          width: 32, height: 32,\n"
        "                          decoration: BoxDecoration(\n"
        "                            color: AppColors.waterBlue.withOpacity(0.15),\n"
        "                            shape: BoxShape.circle),\n"
        "                          child: const Icon(Icons.add,\n"
        "                              color: AppColors.waterBlue, size: 18)),\n"
        "                      ),\n"
        "                    ]),\n"
        "                  ])),\n"
        "\n"
        "                  const SizedBox(height: 16),\n"
        "\n"
        "                  // ── Meal Sections ───────────────────────\n",
        "insert restyled diet-plan pills + flat macro-bars/water section below the card",
    )


def patch_summary_box_and_macro_row_defs():
    apply_one(
        NUTRITION,
        "  Widget _summaryBox(String label, String val,\n"
        "      Color color, bool isDark) =>\n"
        "      Container(\n"
        "        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),\n"
        "        decoration: BoxDecoration(\n"
        "          color: color.withOpacity(0.07),\n"
        "          borderRadius: BorderRadius.circular(16),\n"
        "        ),\n"
        "        child: Column(mainAxisSize: MainAxisSize.min, children: [\n"
        "          Text(val, style: TextStyle(fontFamily: 'Aligarh',\n"
        "              fontSize: 24, fontWeight: FontWeight.w900, color: color)),\n"
        "          const SizedBox(height: 2),\n"
        "          Text(label, style: TextStyle(fontFamily: 'Aligarh',\n"
        "              fontSize: 10, color: color.withOpacity(0.85),\n"
        "              fontWeight: FontWeight.w700)),\n"
        "        ]),\n"
        "      );\n"
        "\n"
        "  Widget _macroRow(String label, double current,\n"
        "      double target, Color color) {\n"
        "    final pct = target > 0\n"
        "        ? (current / target).clamp(0.0, 1.0) : 0.0;\n"
        "    final pctInt = (pct * 100).toInt();\n"
        "    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n"
        "      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [\n"
        "        Text(label, style: TextStyle(fontFamily: 'Aligarh',\n"
        "            fontSize: 12, fontWeight: FontWeight.w600, color: color)),\n"
        "        Text('${current.toInt()}g / ${target.toInt()}g  •  $pctInt%',\n"
        "            style: TextStyle(fontFamily: 'Aligarh',\n"
        "                fontSize: 10, color: color.withOpacity(0.75))),\n"
        "      ]),\n"
        "      const SizedBox(height: 5),\n"
        "      Stack(children: [\n"
        "        Container(\n"
        "          height: 10,\n"
        "          decoration: BoxDecoration(\n"
        "            color: color.withOpacity(0.12),\n"
        "            borderRadius: BorderRadius.circular(8),\n"
        "          ),\n"
        "        ),\n"
        "        LayoutBuilder(builder: (_, constraints) => AnimatedContainer(\n"
        "          duration: const Duration(milliseconds: 600),\n"
        "          curve: Curves.easeOut,\n"
        "          height: 10,\n"
        "          width: constraints.maxWidth * pct,\n"
        "          decoration: BoxDecoration(\n"
        "            gradient: LinearGradient(\n"
        "              colors: [color.withOpacity(0.7), color],\n"
        "              begin: Alignment.centerLeft, end: Alignment.centerRight,\n"
        "            ),\n"
        "            borderRadius: BorderRadius.circular(8),\n"
        "            boxShadow: [BoxShadow(\n"
        "              color: color.withOpacity(0.3),\n"
        "              blurRadius: 4, offset: const Offset(0, 1),\n"
        "            )],\n"
        "          ),\n"
        "        )),\n"
        "      ]),\n"
        "    ]);\n"
        "  }\n",
        "  Widget _summaryBox(String emoji, String label, String val,\n"
        "      Color color, bool isDark) =>\n"
        "      Container(\n"
        "        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),\n"
        "        decoration: BoxDecoration(\n"
        "          color: color.withOpacity(0.07),\n"
        "          borderRadius: BorderRadius.circular(16),\n"
        "        ),\n"
        "        child: Column(mainAxisSize: MainAxisSize.min, children: [\n"
        "          Stack(clipBehavior: Clip.none, children: [\n"
        "            Row(mainAxisSize: MainAxisSize.min, children: [\n"
        "              Text(val, style: TextStyle(fontFamily: 'Aligarh',\n"
        "                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),\n"
        "              const SizedBox(width: 8),\n"
        "              Container(\n"
        "                width: 30, height: 30,\n"
        "                decoration: BoxDecoration(\n"
        "                  color: color.withOpacity(0.18),\n"
        "                  borderRadius: BorderRadius.circular(10)),\n"
        "                child: Center(child: Text(emoji,\n"
        "                    style: const TextStyle(fontSize: 15))),\n"
        "              ),\n"
        "            ]),\n"
        "            Positioned(\n"
        "              top: -3, right: -3,\n"
        "              child: Container(width: 7, height: 7,\n"
        "                  decoration: BoxDecoration(\n"
        "                      color: color, shape: BoxShape.circle)),\n"
        "            ),\n"
        "          ]),\n"
        "          const SizedBox(height: 6),\n"
        "          Text(label, style: TextStyle(fontFamily: 'Aligarh',\n"
        "              fontSize: 10, color: color.withOpacity(0.85),\n"
        "              fontWeight: FontWeight.w700)),\n"
        "        ]),\n"
        "      );\n"
        "\n"
        "  Widget _macroRow(String emoji, String label, double current,\n"
        "      double target, Color color) {\n"
        "    final pct = target > 0\n"
        "        ? (current / target).clamp(0.0, 1.0) : 0.0;\n"
        "    final pctInt = (pct * 100).toInt();\n"
        "    final langNow = ref.read(languageProvider);\n"
        "    final gLabel = (langNow == 'ar' || langNow == 'ur') ? 'جم' : 'g';\n"
        "    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [\n"
        "      Container(\n"
        "        width: 34, height: 34,\n"
        "        margin: const EdgeInsets.only(left: 10),\n"
        "        decoration: BoxDecoration(\n"
        "            color: color.withOpacity(0.15),\n"
        "            borderRadius: BorderRadius.circular(10)),\n"
        "        child: Center(child: Text(emoji,\n"
        "            style: const TextStyle(fontSize: 16))),\n"
        "      ),\n"
        "      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,\n"
        "          children: [\n"
        "        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [\n"
        "          Text(label, style: TextStyle(fontFamily: 'Aligarh',\n"
        "              fontSize: 13, fontWeight: FontWeight.w700, color: color)),\n"
        "          Text('${current.toInt()}/${target.toInt()}$gLabel  •  $pctInt%',\n"
        "              style: TextStyle(fontFamily: 'Aligarh',\n"
        "                  fontSize: 10, color: color.withOpacity(0.75))),\n"
        "        ]),\n"
        "        const SizedBox(height: 5),\n"
        "        Stack(children: [\n"
        "          Container(\n"
        "            height: 10,\n"
        "            decoration: BoxDecoration(\n"
        "              color: color.withOpacity(0.12),\n"
        "              borderRadius: BorderRadius.circular(8),\n"
        "            ),\n"
        "          ),\n"
        "          LayoutBuilder(builder: (_, constraints) => AnimatedContainer(\n"
        "            duration: const Duration(milliseconds: 600),\n"
        "            curve: Curves.easeOut,\n"
        "            height: 10,\n"
        "            width: constraints.maxWidth * pct,\n"
        "            decoration: BoxDecoration(\n"
        "              gradient: LinearGradient(\n"
        "                colors: [color.withOpacity(0.7), color],\n"
        "                begin: Alignment.centerLeft, end: Alignment.centerRight,\n"
        "              ),\n"
        "              borderRadius: BorderRadius.circular(8),\n"
        "              boxShadow: [BoxShadow(\n"
        "                color: color.withOpacity(0.3),\n"
        "                blurRadius: 4, offset: const Offset(0, 1),\n"
        "              )],\n"
        "            ),\n"
        "          )),\n"
        "        ]),\n"
        "      ])),\n"
        "    ]);\n"
        "  }\n",
        "_summaryBox: icon badge + corner dot; _macroRow: icon badge + localized g/جم unit",
    )


def main():
    print("=" * 70)
    print("Nutrition screen: v19 redesign (theme switcher + mockup restyle)")
    print("=" * 70)
    patch_enum()
    patch_field()
    patch_init_state()
    patch_switcher_widget()
    patch_providers_and_colors()
    patch_appbar()
    patch_greeting_and_goal_badge()
    patch_card_header()
    patch_ring_text()
    patch_summary_box_calls()
    patch_remove_chips_and_macros_from_card()
    patch_insert_pills_and_macros_below_card()
    patch_summary_box_and_macro_row_defs()

    print()
    print("=" * 70)
    print(f"{len(LEDGER)} edit(s) applied, {len(FAILED)} refused.")
    for line in LEDGER:
        print(" ", line)
    if FAILED:
        for line in FAILED:
            print(" ", line)
        sys.exit(1)
    print("=" * 70)
    print("See docstring for what's deliberately NOT included (debug chip row,")
    print("duplicate Add-Food button, Ramadan day/light variant) -- all need")
    print("your call if you actually want them.")


if __name__ == "__main__":
    main()
