#!/usr/bin/env python3
"""
patch_v18_nutrition_banner_copy.py — banner text/icon didn't match the mockup
===========================================================================

WHAT WAS WRONG
  lib/features/nutrition/nutrition_screen.dart — the "no meals logged yet"
  banner said "ابدأ يومك بوجبة فيها بروتين" ("...a meal that HAS protein")
  with a 🌿 herb icon and a redundant trailing 🍽️ inside the sentence
  itself. The mockup's copy is "ابدأ يومك بوجبة غنية بالبروتين" ("...a
  protein-RICH meal"), with a single 🌱 seedling icon and no emoji inside
  the sentence.

FIX
  Wording -> matches mockup exactly (AR + EN). Icon -> 🌱. Dropped the
  in-sentence emoji since the icon already carries it.

SAFETY: same exact-match-or-refuse rule as every other patch in this set.

NOT INCLUDED HERE (see chat reply, needs your call before I touch code):
  - Home/Nutrition greeting font. The mockup's "مساء الخير" is cursive
    gold (LemonBrush) -- that's what v17 changed AWAY from, on your
    explicit instruction to match the AppBar-title look instead. Those
    two directions conflict; I'm not reverting v17 without you saying so.
  - Health screen structure. The mockup's mood/heart/water/BMI/articles
    all sit on one page; current code splits Tracking/Calculators/
    Articles into separate tabs and the mood picker has grown from 5
    plain emoji to 8 purpose-drawn icons. That looks like real feature
    growth past this particular mockup frame, not a regression -- so I
    left it alone rather than guessing you want it collapsed back down.
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


def patch_nutrition_banner():
    apply_one(
        "lib/features/nutrition/nutrition_screen.dart",
        "                      child: Row(children: [\n"
        "                        const Text('🌿',\n"
        "                            style: TextStyle(fontSize: 22)),\n"
        "                        const SizedBox(width: 10),\n"
        "                        Expanded(child: Text(\n"
        "                          tl('ابدأ يومك بوجبة فيها بروتين 🍽️',\n"
        "                             'Start the day with some protein 🍽️'),",
        "                      child: Row(children: [\n"
        "                        const Text('🌱',\n"
        "                            style: TextStyle(fontSize: 22)),\n"
        "                        const SizedBox(width: 10),\n"
        "                        Expanded(child: Text(\n"
        "                          tl('ابدأ يومك بوجبة غنية بالبروتين',\n"
        "                             'Start the day with a protein-rich meal'),",
        "empty-state banner copy + icon -> matches mockup",
    )


def main():
    print("=" * 70)
    print("Nutrition banner copy: match mockup wording exactly")
    print("=" * 70)
    patch_nutrition_banner()

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
    print("See docstring for what's deliberately NOT included (greeting font")
    print("conflict + health-screen structure) -- both need your call.")


if __name__ == "__main__":
    main()
