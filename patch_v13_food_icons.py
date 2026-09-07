#!/usr/bin/env python3
"""
patch_v13_food_icons.py — wire fruits/vegetables/proteins/pantry_and_dishes
into the app's EXISTING food-recognition system
=============================================================================

WHAT THIS DOES
  Extends kFoodAssetOverrides in lib/core/food_emoji.dart with ~70 new
  entries pointing at the icon pack (fruits/vegetables/proteins/
  pantry_and_dishes), plus upgrades ~10 existing entries that pointed at
  the old generic clipart pack to the new purpose-drawn icons instead.

  IMPORTANT CONTEXT: this isn't new plumbing. lib/core/food_emoji.dart
  already has a full asset->glyph->online-photo fallback chain
  (FoodThumb widget, lookupFoodAsset(), kFoodAssetOverrides), built by
  an earlier patch (comments there say PATCH_NEW_ASSET_PACKS). Every
  screen that renders food through FoodThumb picks this up automatically
  -- this patch only had to touch the one lookup table, not any screen.

  The 4 spots that call foodEmoji(name) directly in Text() (bypassing
  FoodThumb entirely, always plain emoji) are NOT touched here -- listed
  at the bottom of this file as a follow-up, since upgrading those means
  editing each render call site individually and I haven't verified
  those 4 locations in this pass.

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


_OLD_OVERRIDES = """const Map<String, String> kFoodAssetOverrides = {
  'apple':      'assets/emoji/clipart_foods/689338-clipapple.png',
  'banana':     'assets/emoji/clipart_foods/992116-clipbanana.png',
  'orange':     'assets/emoji/clipart_foods/138331-cliporange.png',
  'strawberry': 'assets/emoji/clipart_foods/339716-clipstrawberry.png',
  'watermelon': 'assets/emoji/clipart_foods/339716-clipwatermelon.png',
  'cherry':     'assets/emoji/clipart_foods/689338-clipcherry.png',
  'tomato':     'assets/emoji/clipart_foods/419781-cliptomato.png',
  'broccoli':   'assets/emoji/clipart_foods/568900-clipbroccoli.png',
  'mushroom':   'assets/emoji/clipart_foods/334711-clipmushroom.png',
  'chicken':    'assets/emoji/clipart_foods/568868-clipchicken.png',
  'shrimp':     'assets/emoji/clipart_foods/740457-clipshrimp.png',
  'egg':        'assets/emoji/clipart_foods/744157-clipegg.png',
  'sushi':      'assets/emoji/clipart_foods/484824-clipsushi.png',
  'sausage':    'assets/emoji/clipart_foods/811566-clipsausage.png',
  'pizza':      'assets/emoji/fast_food/2137-pizza.png',
  'burger':     'assets/emoji/fast_food/6862-burger.png',
  'fries':      'assets/emoji/fast_food/4100-fries.png',
  'donut':      'assets/emoji/food_drink/19292-pinkcutedonut.png',
  'ice cream':  'assets/emoji/food_drink/8541-icecreamx.png',
  'milkshake':  'assets/emoji/food_drink/53175-milkshakecutex.png',
  'cupcake':    'assets/emoji/cupcakes/84120-redvelvetcupcake.png',
  'muffin':     'assets/emoji/food_drink/89974-pinkmuffin.png',
};"""

_NEW_OVERRIDES = """const Map<String, String> kFoodAssetOverrides = {
  // ── Upgraded from the old generic clipart pack to the new icon pack ──
  'apple':      'assets/icons/fruits/apple.png',
  'banana':     'assets/icons/fruits/banana.png',
  'orange':     'assets/icons/fruits/orange.png',
  'strawberry': 'assets/icons/fruits/strawberry.png',
  'watermelon': 'assets/icons/fruits/watermelon.png',
  'cherry':     'assets/icons/fruits/cherry.png',
  'tomato':     'assets/icons/vegetables/tomato.png',
  'broccoli':   'assets/icons/vegetables/broccoli.png',
  'chicken':    'assets/icons/proteins/chicken.png',
  'shrimp':     'assets/icons/proteins/shrimp.png',
  // No matching photo in the new pack for these -- kept on the old pack.
  'mushroom':   'assets/emoji/clipart_foods/334711-clipmushroom.png',
  'egg':        'assets/emoji/clipart_foods/744157-clipegg.png',
  'sushi':      'assets/emoji/clipart_foods/484824-clipsushi.png',
  'sausage':    'assets/emoji/clipart_foods/811566-clipsausage.png',
  'pizza':      'assets/emoji/fast_food/2137-pizza.png',
  'burger':     'assets/emoji/fast_food/6862-burger.png',
  'fries':      'assets/emoji/fast_food/4100-fries.png',
  'donut':      'assets/emoji/food_drink/19292-pinkcutedonut.png',
  'ice cream':  'assets/emoji/food_drink/8541-icecreamx.png',
  'milkshake':  'assets/emoji/food_drink/53175-milkshakecutex.png',
  'cupcake':    'assets/emoji/cupcakes/84120-redvelvetcupcake.png',
  'muffin':     'assets/emoji/food_drink/89974-pinkmuffin.png',

  // ── Fruits (assets/icons/fruits/) ──
  'avocado':     'assets/icons/fruits/avocado.png',
  'coconut':     'assets/icons/fruits/coconut.png',
  'date':        'assets/icons/fruits/dates3.png',
  'grape':       'assets/icons/fruits/grapes.png',
  'guava':       'assets/icons/fruits/guava.png',
  'kiwi':        'assets/icons/fruits/kiwi.png',
  'lemon':       'assets/icons/fruits/lemon.png',
  'mango':       'assets/icons/fruits/mango.png',
  'melon':       'assets/icons/fruits/melon.png',
  'papaya':      'assets/icons/fruits/papaya.png',
  'peach':       'assets/icons/fruits/peach.png',
  'pear':        'assets/icons/fruits/pear.png',
  'pineapple':   'assets/icons/fruits/pineapple.png',
  'pomegranate': 'assets/icons/fruits/pomegranate.png',

  // ── Vegetables (assets/icons/vegetables/) ──
  'beetroot':      'assets/icons/vegetables/beet.png',
  'carrot':        'assets/icons/vegetables/carrot.png',
  'cauliflower':   'assets/icons/vegetables/cauliflower.png',
  'chili':         'assets/icons/vegetables/chili.png',
  'cucumber':      'assets/icons/vegetables/cucumber.png',
  'eggplant':      'assets/icons/vegetables/eggplant.png',
  'garlic':        'assets/icons/vegetables/garlic.png',
  'green bean':    'assets/icons/vegetables/green_beans.png',
  'pepper':        'assets/icons/vegetables/green_pepper.png',
  'lettuce':       'assets/icons/vegetables/lettuce.png',
  'onion':         'assets/icons/vegetables/onion.png',
  'pea':           'assets/icons/vegetables/peas.png',
  'potato':        'assets/icons/vegetables/potato.png',
  'radish':        'assets/icons/vegetables/radish.png',
  'spinach':       'assets/icons/vegetables/spinach.png',
  'sweet potato':  'assets/icons/vegetables/sweet_potato.png',
  'zucchini':      'assets/icons/vegetables/zucchini.png',

  // ── Proteins (assets/icons/proteins/) ──
  'beef':   'assets/icons/proteins/beef.png',
  'steak':  'assets/icons/proteins/beef_cut.png',
  'cheese': 'assets/icons/proteins/cheese1.png',
  'lamb':   'assets/icons/proteins/lamb.png',
  'salmon': 'assets/icons/proteins/salmon.png',
  'tuna':   'assets/icons/proteins/tuna.png',

  // ── Pantry & dishes (assets/icons/pantry_and_dishes/) ──
  'hummus':      'assets/icons/pantry_and_dishes/hummus.png',
  'baba ghanoush': 'assets/icons/pantry_and_dishes/baba_ghanoush.png',
  'falafel':     'assets/icons/pantry_and_dishes/falafel.png',
  'shawarma':    'assets/icons/pantry_and_dishes/shawarma.png',
  'kebab':       'assets/icons/pantry_and_dishes/kebab.png',
  'tabbouleh':   'assets/icons/pantry_and_dishes/tabbouleh.png',
  'fattoush':    'assets/icons/pantry_and_dishes/fattoush.png',
  'baklava':     'assets/icons/pantry_and_dishes/baklava1.png',
  'basbousa':    'assets/icons/pantry_and_dishes/basbousa.png',
  'kunafa':      'assets/icons/pantry_and_dishes/kunafa.png',
  'mahalabia':   'assets/icons/pantry_and_dishes/mahalabia.png',
  'majboos':     'assets/icons/pantry_and_dishes/majboos.png',
  'mansaf':      'assets/icons/pantry_and_dishes/mansaf.png',
  'grilled fish':'assets/icons/pantry_and_dishes/grilled_fish.png',
  'om ali':      'assets/icons/pantry_and_dishes/om_ali.png',
  'edamame':     'assets/icons/pantry_and_dishes/edamame.png',
  'couscous':    'assets/icons/pantry_and_dishes/couscous.png',
  'noodle':      'assets/icons/pantry_and_dishes/noodles.png',
  'bread':       'assets/icons/pantry_and_dishes/bread_loaf.png',
  'pita':        'assets/icons/pantry_and_dishes/pita.png',
  'cookie':      'assets/icons/pantry_and_dishes/cookie.png',
  'cake':        'assets/icons/pantry_and_dishes/cake.png',
  'chocolate':   'assets/icons/pantry_and_dishes/chocolate.png',
  'coffee':      'assets/icons/pantry_and_dishes/coffee.png',
  'tea':         'assets/icons/pantry_and_dishes/tea.png',
  'butter':      'assets/icons/pantry_and_dishes/butter.png',
  'cream':       'assets/icons/pantry_and_dishes/cream.png',
  'jam':         'assets/icons/pantry_and_dishes/jam.png',
  'ketchup':     'assets/icons/pantry_and_dishes/ketchup.png',
  'mustard':     'assets/icons/pantry_and_dishes/mustard.png',
  'mayonnaise':  'assets/icons/pantry_and_dishes/mayo.png',
  'soy sauce':   'assets/icons/pantry_and_dishes/soy_sauce.png',
  'vinegar':     'assets/icons/pantry_and_dishes/vinegar.png',
  'olive oil':   'assets/icons/pantry_and_dishes/olive_oil.png',
  'peanut':      'assets/icons/pantry_and_dishes/peanuts.png',
  'sesame':      'assets/icons/pantry_and_dishes/sesame.png',
  'tahini':      'assets/icons/pantry_and_dishes/sesame.png',
  'tofu':        'assets/icons/pantry_and_dishes/tofu.png',
  'tamarind':    'assets/icons/pantry_and_dishes/tamarind.png',
  'saffron':     'assets/icons/pantry_and_dishes/saffron.png',
  'cinnamon':    'assets/icons/pantry_and_dishes/cinnamon.png',
  'cumin':       'assets/icons/pantry_and_dishes/cumin_spoon.png',
  'ginger':      'assets/icons/pantry_and_dishes/ginger.png',
  'turmeric':    'assets/icons/pantry_and_dishes/turmeric.png',
  'mint':        'assets/icons/pantry_and_dishes/mint.png',
  'parsley':     'assets/icons/pantry_and_dishes/parsley.png',
  'salt':        'assets/icons/pantry_and_dishes/salt_bowl.png',
  'sugar':       'assets/icons/pantry_and_dishes/sugar_bowl.png',
  'rice':        'assets/icons/pantry_and_dishes/rice_bowl.png',
  'water':       'assets/icons/pantry_and_dishes/water_glass.png',
};"""


def patch_food_overrides():
    apply_one(
        "lib/core/food_emoji.dart", _OLD_OVERRIDES, _NEW_OVERRIDES,
        "kFoodAssetOverrides: +~70 icon-pack entries, upgraded 10 existing ones",
    )


def main():
    print("=" * 70)
    print("Wire icon pack into food recognition (kFoodAssetOverrides)")
    print("=" * 70)
    patch_food_overrides()

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
    print("Not touched (bypass FoodThumb, always plain emoji) -- flagging")
    print("for a follow-up pass once I've read their exact context:")
    print("  nutrition_screen.dart lines ~317, ~1634, ~2079, ~2356")


if __name__ == "__main__":
    main()
