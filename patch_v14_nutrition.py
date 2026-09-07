#!/usr/bin/env python3
"""
patch_v14_nutrition.py — Nutrition screen: hero font + real food icons
========================================================================

WHAT I FOUND FIRST (read before assuming this needed a rebuild)
  The v10 mockup's nutrition screen is much smaller than I expected --
  it's just a summary dashboard (greeting, calorie ring, diet-mode chips,
  macro bars, water bar). Comparing it against nutrition_screen.dart's
  "Today" tab, the structure is *already* a near-exact match -- calorie
  ring (a nicer animated LeafProgressRing, even better than the mockup's
  plain SVG ring), eaten/burned boxes, diet-plan chips, macro rows with
  icon+bar, water row. Someone already built this screen with the same
  design language in mind (see the PATCH_LEAF_RING_AND_WORKOUT_ASSETS
  comment already in there). So this patch is deliberately small:

  1. The greeting text ("Good morning" / good afternoon / good evening)
     was still small Aligarh body text, not the big LemonBrush hero
     treatment used on the home screen. Upgraded for consistency --
     layout untouched, just the TextStyle.

  2. 4 places render a food's icon as plain Text(foodEmoji(name)) instead
     of the FoodThumb widget (which prefers the icon-pack asset wired in
     patch_v13, falling back to emoji automatically). These are the 4
     spots flagged as a follow-up last time. Each is swapped to FoodThumb
     wrapped in the exact same outer container so nothing about the
     layout/shape changes -- only the icon content gets smarter.

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


F = "lib/features/nutrition/nutrition_screen.dart"


def patch_hero_greeting():
    old = """                            Text(() {
                              final h = DateTime.now().hour;
                              if (h < 12) return l.goodMorning;
                              if (h < 17) return l.goodAfternoon;
                              return l.goodEvening;
                            }(),
                            style: TextStyle(fontFamily: 'Aligarh',
                                fontSize: 18, fontWeight: FontWeight.w800,
                                color: textC)),"""
    new = """                            Text(() {
                              final h = DateTime.now().hour;
                              if (h < 12) return l.goodMorning;
                              if (h < 17) return l.goodAfternoon;
                              return l.goodEvening;
                            }(),
                            style: TextStyle(fontFamily: 'LemonBrush',
                                fontSize: 30, height: 1.0,
                                color: isDark ? AppColors.greetGold : AppColors.greetGoldLight)),"""
    apply_one(F, old, new, "nutrition hero greeting -> LemonBrush (matches home screen)")


def patch_food_icon_1():
    # Food detail page hero icon (68x68, gradient, radius 20)
    old = """                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      (ref.read(ramadanModeProvider) ? AppColors.accentGold : AppColors.brandGreen).withOpacity(0.18),
                      (ref.read(ramadanModeProvider) ? AppColors.accentGold : AppColors.brandGreen).withOpacity(0.04)]),
                    borderRadius: BorderRadius.circular(20)),
                  child: Center(child: Text(foodEmoji(e.name),
                      style: const TextStyle(fontSize: 36)))),"""
    new = """                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      (ref.read(ramadanModeProvider) ? AppColors.accentGold : AppColors.brandGreen).withOpacity(0.18),
                      (ref.read(ramadanModeProvider) ? AppColors.accentGold : AppColors.brandGreen).withOpacity(0.04)]),
                    borderRadius: BorderRadius.circular(20)),
                  child: Center(child: FoodThumb(name: e.name, size: 56, radius: 16,
                      background: Colors.transparent))),"""
    apply_one(F, old, new, "food detail hero icon -> FoodThumb")


def patch_food_icon_2():
    # Food-history log row icon (46x46, gradient, radius 12)
    old = """                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brandGreen.withOpacity(0.15),
                            AppColors.brandGreen.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: Text(
                          foodEmoji(e.name),
                          style: const TextStyle(fontSize: 22))),
                    ),"""
    new = """                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.brandGreen.withOpacity(0.15),
                            AppColors.brandGreen.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: FoodThumb(name: e.name, size: 38, radius: 9,
                          background: Colors.transparent)),
                    ),"""
    apply_one(F, old, new, "food-history row icon -> FoodThumb")


def patch_food_icon_3():
    # Food search-results ListTile leading icon (42x42, flat color, radius 11)
    old = """                  leading: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(child: Text(
                        foodEmoji(food.name),
                        style: const TextStyle(fontSize: 20))),
                  ),"""
    new = """                  leading: FoodThumb(name: food.name, size: 42, radius: 11,
                      background: AppColors.brandGreen.withOpacity(0.08)),"""
    apply_one(F, old, new, "food search-result icon -> FoodThumb")


def patch_food_icon_4():
    # Food row (52x52, flat color, radius 14) -- same size FoodThumb is
    # already used at elsewhere in this file, so this just brings it
    # in line with that existing usage.
    old = """                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14)),
                    child: Center(child: Text(foodEmoji(name),
                        style: const TextStyle(fontSize: 26)))),"""
    new = """                  FoodThumb(name: name, size: 52, radius: 14,
                      background: AppColors.brandGreen.withOpacity(0.1)),"""
    apply_one(F, old, new, "food row icon -> FoodThumb")


def main():
    print("=" * 70)
    print("Nutrition screen: hero font + real food icons")
    print("=" * 70)
    patch_hero_greeting()
    patch_food_icon_1()
    patch_food_icon_2()
    patch_food_icon_3()
    patch_food_icon_4()

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


if __name__ == "__main__":
    main()
