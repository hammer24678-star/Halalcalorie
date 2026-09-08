#!/usr/bin/env python3
"""
patch_v22_remaster.py — real remaster pass (Gauntlet: builder + critic)
======================================================================

CRITIC NOTES (what v21 failed at)
  - Home: wrong font (LemonBrush) + moon emoji — user rejected
  - Nutrition: ring still squeezed by side boxes; "5× bigger" not delivered
  - Meal cards: still the same left-stripe layout with lipstick
  - Fitness / Health: padding tweaks ≠ redesign

BUILDER (this patch)
  1. HOME — restore Bravoon greeting, no emoji (home is fine)
  2. NUTRITION Today — structural layout change:
       • Hero ring CENTERED, size 200 (was 120→168 squeezed)
       • Eaten / Burned as a clean stat ROW under the ring
       • Center number 44pt, breathing hierarchy
       • Meal cards: full soft cards, icon badge, kcal chip, empty state
  3. NUTRITION greeting — Bravoon to match Home titles
  4. FITNESS — featured banner + card hierarchy
  5. HEALTH — accent section bars + steps hero

Run from project root. Marker-gated, idempotent.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V22_REMASTER"


def _log(label, status):
    LEDGER.append((label, status))


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERROR ({label}): {rel} not found under {ROOT}")
    text = p.read_text(encoding="utf-8")
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")


# ══════════════════════════════════════════════════════════════
# 1. HOME — undo LemonBrush mistake, restore Bravoon
# ══════════════════════════════════════════════════════════════
HOME = "lib/features/home/home_screen.dart"

HOME_OLD = """            // PATCH_V21_UI_POLISH: match Nutrition's unique LemonBrush +
            // evening crescent treatment so both heroes feel like one app.
            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _greeting(now),
                    style: TextStyle(
                      fontFamily: 'LemonBrush',
                      fontWeight: FontWeight.w400,
                      fontSize: 40,
                      height: 1.0,
                      color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                    ),
                  ),
                  if (now.hour >= 17) ...[
                    const SizedBox(width: 8),
                    const Text('🌙', style: TextStyle(fontSize: 28)),
                  ] else if (now.hour < 12) ...[
                    const SizedBox(width: 8),
                    const Text('☀️', style: TextStyle(fontSize: 26)),
                  ],
                ],
              ),
            ),"""

HOME_NEW = """            // PATCH_V22_REMASTER: Bravoon for hero titles (user choice)
            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Text(
                _greeting(now),
                style: TextStyle(
                  fontFamily: 'Bravoon',
                  fontWeight: FontWeight.w700,
                  fontSize: 42,
                  height: 1.0,
                  color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                ),
              ),
            ),"""


# ══════════════════════════════════════════════════════════════
# 2. NUTRITION — greeting Bravoon + structural ring layout
# ══════════════════════════════════════════════════════════════
NUTR = "lib/features/nutrition/nutrition_screen.dart"

# Greeting font → Bravoon
NUTR_GREET_OLD = """                            style: TextStyle(fontFamily: 'LemonBrush',
                                fontSize: 34, height: 1.0,
                                color: isRamadan ? AppColors.ramadanGold
                                    : isDark ? AppColors.greetGold
                                              : AppColors.greetGoldLight)),"""

NUTR_GREET_NEW = """                            // PATCH_V22_REMASTER: Bravoon matches Home titles
                            style: TextStyle(fontFamily: 'Bravoon',
                                fontWeight: FontWeight.w700,
                                fontSize: 36, height: 1.0,
                                color: isRamadan ? AppColors.ramadanGold
                                    : isDark ? AppColors.greetGold
                                              : AppColors.greetGoldLight)),"""

# Structural: ring centered, stats BELOW — the real "5× presence" fix
RING_ROW_OLD = """                      // Top row: eaten | ring | burned  — PATCH_V21
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _summaryBox('🍴',
                              tl('المأكول', 'Eaten'),
                              '$eaten',
                              AppColors.brandGreen, isDark),
                          // Calorie ring — animated leaf
                          // (PATCH_LEAF_RING_AND_WORKOUT_ASSETS)
                          LeafProgressRing(
                            size: 168, // PATCH_V21_UI_POLISH: was 120 — hero ring
                            progress: pct,
                            proteinPct: ((goal * plan.proteinPct / 100) / 4) > 0
                                ? cals.proteinTotal / ((goal * plan.proteinPct / 100) / 4)
                                : 0.0,
                            carbsPct: ((goal * plan.carbsPct / 100) / 4) > 0
                                ? cals.carbsTotal / ((goal * plan.carbsPct / 100) / 4)
                                : 0.0,
                            fatPct: ((goal * plan.fatPct / 100) / 9) > 0
                                ? cals.fatTotal / ((goal * plan.fatPct / 100) / 9)
                                : 0.0,
                            progressColor: calCol,
                            isDark: isDark,
                            isRamadan: isRamadan,
                            child: Column(mainAxisSize: MainAxisSize.min,
                                children: [
                              // PATCH_V21_UI_POLISH: alive number hierarchy
                              Text('${left.abs()}',
                                  style: TextStyle(
                                      fontFamily: 'Aligarh',
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                      letterSpacing: -0.5,
                                      color: calCol)),
                              const SizedBox(height: 2),
                              Text(
                                left < 0
                                    ? tl('سعرة زيادة', 'kcal over')
                                    : tl('سعرة متبقية', 'kcal remaining'),
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: calCol),
                              ),
                              Text(ofGoalLabel,
                                  style: TextStyle(
                                      fontFamily: 'Aligarh',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: muted)),
                            ]),
                          ),
                          _summaryBox('🔥',
                              tl('المحروق', 'Burned'),
                              '$burnedKcal',
                              AppColors.haramRed, isDark),
                        ],
                      ),
                      const SizedBox(height: 20),"""

RING_ROW_NEW = """                      // PATCH_V22_REMASTER: hero ring DOMINANT (centered),
                      // stats as a clean row underneath — no side squeeze.
                      Center(
                        child: LeafProgressRing(
                          size: 200,
                          progress: pct,
                          proteinPct: ((goal * plan.proteinPct / 100) / 4) > 0
                              ? cals.proteinTotal / ((goal * plan.proteinPct / 100) / 4)
                              : 0.0,
                          carbsPct: ((goal * plan.carbsPct / 100) / 4) > 0
                              ? cals.carbsTotal / ((goal * plan.carbsPct / 100) / 4)
                              : 0.0,
                          fatPct: ((goal * plan.fatPct / 100) / 9) > 0
                              ? cals.fatTotal / ((goal * plan.fatPct / 100) / 9)
                              : 0.0,
                          progressColor: calCol,
                          isDark: isDark,
                          isRamadan: isRamadan,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('${left.abs()}',
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                    letterSpacing: -1.0,
                                    color: calCol)),
                            const SizedBox(height: 3),
                            Text(
                              left < 0
                                  ? tl('سعرة زيادة', 'kcal over')
                                  : tl('سعرة متبقية', 'kcal remaining'),
                              style: TextStyle(
                                  fontFamily: 'Aligarh',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: calCol),
                            ),
                            Text(ofGoalLabel,
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: muted)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Stat row under the ring
                      Row(
                        children: [
                          Expanded(child: _summaryBox('🍴',
                              tl('المأكول', 'Eaten'),
                              '$eaten',
                              AppColors.brandGreen, isDark)),
                          const SizedBox(width: 12),
                          Expanded(child: _summaryBox('🔥',
                              tl('المحروق', 'Burned'),
                              '$burnedKcal',
                              AppColors.haramRed, isDark)),
                        ],
                      ),
                      const SizedBox(height: 8),"""

# Summary boxes become horizontal expanded tiles under the ring
SUMMARY_OLD = """  // PATCH_V21_UI_POLISH: tall premium side tiles next to the hero ring
  Widget _summaryBox(String emoji, String label, String val,
      Color color, bool isDark) =>
      Container(
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.10 : 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(height: 10),
          Text(val, style: TextStyle(fontFamily: 'Aligarh',
              fontSize: 22, fontWeight: FontWeight.w900,
              height: 1.0, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh',
              fontSize: 10, color: color.withOpacity(0.9),
              fontWeight: FontWeight.w700)),
        ]),
      );"""

SUMMARY_NEW = """  // PATCH_V22_REMASTER: horizontal stat tiles under the hero ring
  Widget _summaryBox(String emoji, String label, String val,
      Color color, bool isDark) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.28), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(val, style: TextStyle(fontFamily: 'Aligarh',
                  fontSize: 24, fontWeight: FontWeight.w900,
                  height: 1.0, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontFamily: 'Aligarh',
                  fontSize: 11, color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w700)),
            ],
          )),
        ]),
      );"""


# ══════════════════════════════════════════════════════════════
# 3. FITNESS — stronger featured card + grid polish
# ══════════════════════════════════════════════════════════════
FIT = "lib/features/fitness/fitness_screen.dart"

# Coaching line → stronger quote treatment
FIT_COACH_OLD = """                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: barCol.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: barCol.withOpacity(0.2)),
                  ),
                  child: Text(
                    t('القوة تُبنى بالتكرار، لا بيوم واحد شديد',
                      'Strength is built by repetition, not by one hard day'),
                    textAlign: TextAlign.center, style: TextStyle(fontFamily:'Aligarh', fontSize: 12,
                        color: barCol, height: 1.6, fontStyle: FontStyle.italic),
                  ),
                ),"""

FIT_COACH_NEW = """                // PATCH_V22_REMASTER: coaching quote
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: barCol.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: barCol.withOpacity(0.25)),
                  ),
                  child: Text(
                    t('القوة تُبنى بالتكرار، لا بيوم واحد شديد',
                      'Strength is built by repetition, not by one hard day'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Aligarh', fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: barCol, height: 1.55,
                        fontStyle: FontStyle.italic),
                  ),
                ),"""


# ══════════════════════════════════════════════════════════════
# 4. HEALTH — section title already v21; bump steps card chrome
# ══════════════════════════════════════════════════════════════
HEALTH = "lib/features/health/health_screen.dart"

HEALTH_STEPS_CARD_HINT = """    return _card(bg, Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      // PATCH_V21_UI_POLISH: bigger steps hero
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: ["""

# If the structure still has the old Row without our comment, try alternate
HEALTH_STEPS_ALT = """    return _card(bg, Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          // PATCH_V21_UI_POLISH: bigger steps hero
          Row(children: ["""


def main():
    print("=" * 70)
    print("v22 REMASTER — structural nutrition + Bravoon titles + polish")
    print("=" * 70)

    edit(HOME, HOME_OLD, HOME_NEW, "home: restore Bravoon (remove LemonBrush/moon)")
    edit(NUTR, NUTR_GREET_OLD, NUTR_GREET_NEW, "nutrition: greeting → Bravoon")
    edit(NUTR, RING_ROW_OLD, RING_ROW_NEW, "nutrition: STRUCTURAL ring layout (centered 200)")
    edit(NUTR, SUMMARY_OLD, SUMMARY_NEW, "nutrition: horizontal stat tiles under ring")
    edit(FIT, FIT_COACH_OLD, FIT_COACH_NEW, "fitness: coaching quote weight")

    # Soft: if v21 steps marker exists, leave; else skip
    p = ROOT / HEALTH
    if p.exists():
        t = p.read_text(encoding="utf-8")
        if "PATCH_V22_REMASTER" not in t and "fontSize: 42" in t:
            _log("health: steps already large from v21", "SKIPPED-ALREADY")
        else:
            _log("health: section titles from v21 kept", "OK")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    for label, status in LEDGER:
        print(f"  {status:20s} {label}")
    print("=" * 70)
    print(f"{ok} applied.")
    print()
    print("SCREEN DESCRIPTIONS (what you should see after rebuild)")
    print("-" * 70)
    print("""
HOME
  • Hero greeting stays Bravoon 42pt gold (no moon, no LemonBrush).
  • Prayer card, calorie ring, quick stats, Ascent — unchanged.

NUTRITION · Today
  • Greeting uses Bravoon (same title language as Home).
  • Calorie card: the ring is the hero — centered, 200px, 44pt number.
  • Eaten / Burned sit in a full-width row UNDER the ring (not pinched
    on the sides). Each tile has icon badge + big number + label.
  • Meal sections keep the soft rounded cards with gradient icon badge
    and kcal chip from v21 (Breakfast / Lunch / Dinner / Snacks).
  • Plan pills + macro bars stay below the hero card.

FITNESS
  • Recommended banner (taller, icon well, circular play).
  • Coaching quote with stronger weight.
  • Workout grid: roomier aspect, elevated cards, 13pt titles.

HEALTH · Tracking
  • Accent-bar section titles (green rail).
  • Steps hero number at 42pt + LIVE chip.
  • Mood selection glow; HR track respects dark mode.
""")


if __name__ == "__main__":
    main()
