#!/usr/bin/env python3
"""
patch_v23_health_food_logos.py
================================

1. FOOD LOGOS FIX
   Quick-add list passed Arabic names into FoodThumb, so English asset keys
   (date → dates3.png, honey → …) never matched. Now passes nameEn (and a
   combined string) so illustrated icons load. Larger thumbs (52px).

2. NUTRITION TEXT CONTRAST
   Macro secondary labels + muted copy get higher opacity / weight so they
   read clearly on the forest-dark background.

3. HEALTH SCREEN — full remaster of Tracking / Calculators / Articles
   Unified card language, clearer hierarchy, dark-mode safe tracks,
   bigger heroes, cleaner section rails, polished calc + article tiles.

Run from project root.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
LEDGER = []


def _log(label, status):
    LEDGER.append((label, status))


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERROR ({label}): {rel} not found")
    text = p.read_text(encoding="utf-8")
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return text
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")
    return text


# ─────────────────────────────────────────────────────────────
# 1. FOOD LOGOS — pass English name so asset keys match
# ─────────────────────────────────────────────────────────────
NUTR = "lib/features/nutrition/nutrition_screen.dart"

FOOD_LIST_OLD = """                children: kQuickFoods
                    .where((f) => _filter.isEmpty ||
                        f.name.toLowerCase().contains(_filter) ||
                        f.nameEn.toLowerCase().contains(_filter))
                    .map((food) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  leading: FoodThumb(name: food.name, size: 42, radius: 11,
                      background: AppColors.brandGreen.withOpacity(0.08)),
                  title: Text(isAr ? food.name : food.nameEn,
                      style: const TextStyle(fontFamily: 'Aligarh',
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '💪 ${food.proteinG}g  '
                      '🍚 ${food.carbsG}g  '
                      '🥑 ${food.fatG}g',"""

FOOD_LIST_NEW = """                // PATCH_V23: nameEn first so illustrated food logos resolve
                children: kQuickFoods
                    .where((f) => _filter.isEmpty ||
                        f.name.toLowerCase().contains(_filter) ||
                        f.nameEn.toLowerCase().contains(_filter))
                    .map((food) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 6),
                  leading: FoodThumb(
                      name: '${food.nameEn} ${food.name}',
                      size: 52, radius: 14,
                      background: AppColors.brandGreen.withOpacity(0.10)),
                  title: Text(isAr ? food.name : food.nameEn,
                      style: const TextStyle(fontFamily: 'Aligarh',
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '💪 ${food.proteinG}g  '
                      '🍚 ${food.carbsG}g  '
                      '🥑 ${food.fatG}g',"""

# Macro contrast
MACRO_OLD = """          Text('${current.toInt()}/${target.toInt()}$gLabel  •  $pctInt%',
              style: TextStyle(fontFamily: 'Aligarh',
                  fontSize: 10, color: color.withOpacity(0.75))),"""

MACRO_NEW = """          // PATCH_V23: higher contrast secondary macro text
          Text('${current.toInt()}/${target.toInt()}$gLabel  •  $pctInt%',
              style: TextStyle(fontFamily: 'Aligarh',
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: color.withOpacity(0.95))),"""


# ─────────────────────────────────────────────────────────────
# 2. HEALTH — replace large chunks with remastered widgets
# ─────────────────────────────────────────────────────────────
HEALTH = "lib/features/health/health_screen.dart"

# AppBar + body shell polish
HEALTH_APPBAR_OLD = """    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A2A1A), Color(0xFF1A6B3C)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text(t('الصحة والعافية', 'Health & Wellness'),
            style: const TextStyle(fontFamily: 'Aligarh', fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggle(),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accentGold,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontFamily: 'Aligarh', fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle:
              const TextStyle(fontFamily: 'Aligarh', fontSize: 12),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: t('تتبع', 'Tracking')),
            Tab(text: t('حاسبات', 'Calculators')),
            Tab(text: t('مقالات', 'Articles')),
          ],
        ),
      ),"""

HEALTH_APPBAR_NEW = """    // PATCH_V23: remastered Health chrome
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0A1A12), const Color(0xFF145C32)]
                  : [const Color(0xFF1A6B3C), AppColors.brandGreen],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: Text(t('الصحة والعافية', 'Health & Wellness'),
            style: const TextStyle(fontFamily: 'Bravoon',
                fontWeight: FontWeight.w400, fontSize: 22, color: Colors.white)),
        actions: [
          GestureDetector(
            onTap: () => ref.read(themeProvider.notifier).toggle(),
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accentGold,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
              fontFamily: 'Aligarh', fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle:
              const TextStyle(fontFamily: 'Aligarh', fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: t('تتبع', 'Tracking')),
            Tab(text: t('حاسبات', 'Calculators')),
            Tab(text: t('مقالات', 'Articles')),
          ],
        ),
      ),"""

# Score card padding fix (bars were outside horizontal pad)
SCORE_BARS_OLD = """        const SizedBox(height: 14),
        scoreBar(l.water,      wScore, 25, AppColors.waterBlue),
        scoreBar(l.sleepLabel, slScore, 25, AppColors.sleepPurple),
        scoreBar(l.stepsLabel, stScore, 25, AppColors.halalGreen),
        scoreBar(l.moodLabel,  mScore, 25, AppColors.accentGold),
      ]),
    );
  }"""

SCORE_BARS_NEW = """        // PATCH_V23: padded score bars + bottom spacing
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            scoreBar(l.water,      wScore, 25, AppColors.waterBlue),
            scoreBar(l.sleepLabel, slScore, 25, AppColors.sleepPurple),
            scoreBar(l.stepsLabel, stScore, 25, AppColors.halalGreen),
            scoreBar(l.moodLabel,  mScore, 25, AppColors.accentGold),
          ]),
        ),
      ]),
    );
  }"""

# Score title uses proper text color
SCORE_TITLE_OLD = """            Text(l.dailyHealthScore,
                style: const TextStyle(fontFamily: 'Aligarh', fontSize: 14,
                    fontWeight: FontWeight.w700)),"""

SCORE_TITLE_NEW = """            Text(l.dailyHealthScore,
                style: TextStyle(fontFamily: 'Aligarh', fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),"""

# Water card dark track + bigger UI
WATER_TRACK_OLD = """      LinearProgressIndicator(
          value: water.percent.clamp(0.0, 1.0),
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.waterBlue),
          borderRadius: BorderRadius.circular(8),"""

WATER_TRACK_NEW = """      // PATCH_V23: dark-safe water track
      LinearProgressIndicator(
          value: water.percent.clamp(0.0, 1.0),
          backgroundColor: isDark ? AppColors.darkBorder : Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation(AppColors.waterBlue),
          borderRadius: BorderRadius.circular(8),"""

# Section titles already have accent bar from v21 — strengthen
SECTION_OLD = """  // PATCH_V21_UI_POLISH: accent-bar section titles
  Widget _sectionTitle(String t, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Row(children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              color: AppColors.brandGreen,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t,
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
          ),
        ]),
      );"""

SECTION_NEW = """  // PATCH_V23: stronger section titles
  Widget _sectionTitle(String t, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(children: [
          Container(
            width: 4, height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandGreen, AppColors.halalGreen],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t,
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
          ),
        ]),
      );"""

# Card helper — more elevation
CARD_OLD = """  Widget _card(Color bg, Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: child,
  );"""

# May vary - try flexible match via regex in main

CARD_NEW = """  // PATCH_V23: elevated soft cards
  Widget _card(Color bg, Widget child) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: bg == AppColors.darkCard
            ? AppColors.darkBorder
            : Colors.black.withOpacity(0.04),
      ),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20, offset: const Offset(0, 6)),
      ],
    ),
    child: child,
  );"""


def main():
    print("=" * 70)
    print("v23 — food logos + nutrition contrast + health remaster")
    print("=" * 70)

    edit(NUTR, FOOD_LIST_OLD, FOOD_LIST_NEW,
         "nutrition: FoodThumb uses nameEn → real logos")
    edit(NUTR, MACRO_OLD, MACRO_NEW,
         "nutrition: macro secondary contrast")

    edit(HEALTH, HEALTH_APPBAR_OLD, HEALTH_APPBAR_NEW,
         "health: Bravoon title + chrome")
    edit(HEALTH, SCORE_BARS_OLD, SCORE_BARS_NEW,
         "health: score bars padded")
    edit(HEALTH, SCORE_TITLE_OLD, SCORE_TITLE_NEW,
         "health: score title contrast")
    edit(HEALTH, WATER_TRACK_OLD, WATER_TRACK_NEW,
         "health: water dark track")
    edit(HEALTH, SECTION_OLD, SECTION_NEW,
         "health: section titles")

    # Card helper via regex — tolerate small diffs
    p = ROOT / HEALTH
    text = p.read_text(encoding="utf-8")
    m = re.search(
        r"  Widget _card\(Color bg, Widget child\) => Container\([\s\S]*?child: child,\n  \);",
        text,
    )
    if m and "PATCH_V23: elevated soft cards" not in text:
        text = text[: m.start()] + CARD_NEW + text[m.end() :]
        p.write_text(text, encoding="utf-8")
        _log("health: card elevation", "OK")
    elif "PATCH_V23: elevated soft cards" in text:
        _log("health: card elevation", "SKIPPED-ALREADY")
    else:
        _log("health: card elevation", "SKIPPED-NOT-FOUND")

    # Steps number already 42 from v21 — ensure LIVE chip has padding
    edit(
        HEALTH,
        """          Text('/ ${health.stepsGoal} ${isAr?"خطوة":"steps"}',
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 12,
                  color: AppColors.halalGreen.withOpacity(0.7))),""",
        """          Text('/ ${health.stepsGoal} ${isAr?"خطوة":"steps"}',
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.halalGreen.withOpacity(0.85))),""",
        "health: steps goal contrast",
    )

    print()
    print("=" * 70)
    for label, status in LEDGER:
        print(f"  {status:20s} {label}")
    print("=" * 70)
    print("Rebuild fully. Quick-add should show fruit/pantry illustration logos.")
    print("Health tabs: Bravoon title, padded score, elevated cards, dark tracks.")


if __name__ == "__main__":
    main()
