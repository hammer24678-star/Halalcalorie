#!/usr/bin/env python3
"""
patch_v32_health_article_icons.py
===================================

1. BUG: "الهضم والألياف" (Digestion & Fiber, h6) used a lungs emoji
   (🫁) as its icon in kHealthArticles -- a copy/paste mismatch, not a
   respiratory topic. That's the lungs badge visible on the Articles
   tab in the screenshot next to a digestion/fiber article.

2. REMASTER: every Health Articles icon (Articles tab, health_screen.dart)
   swaps its flat emoji for a real illustrated PNG badge from the new
   assets/icons/health/ pack, following the same asset-path +
   errorBuilder-to-emoji fallback convention already used for avatars
   and workout illustrations elsewhere in the app -- so a missing file
   degrades to the emoji instead of crashing the row.
   h6's new icon is the salad/fiber illustration, fixing bug #1 in the
   same pass. h9 (reading the nutrition label) reuses the same salad
   asset since both are food-composition topics.

3. Bumps pubspec.yaml version 1.2.0+12 -> 1.2.1+13.

BEFORE RUNNING: copy the 9 files from new_workout_icons/../assets/icons/health/
(water.png, sleep.png, heart.png, brain.png, bones.png, digestion_fiber.png,
stress_relax.png, weight_bmi.png, checkup_blood.png) into your repo at
assets/icons/health/ first -- this script only edits Dart/yaml source.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V32_HEALTH_ARTICLE_ICONS"

PUBSPEC = "pubspec.yaml"
ICON_ASSETS = "lib/data/icon_assets.dart"
HEALTH = "lib/features/health/health_screen.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        _log(label, "SKIPPED-NOT-FOUND")
        return False
    text = p.read_text(encoding="utf-8")
    if MARKER in text and label.startswith("marker-gate"):
        _log(label, "SKIPPED-ALREADY")
        return False
    if old not in text:
        if new in text:
            _log(label, "SKIPPED-ALREADY")
        else:
            _log(label, "SKIPPED-NOT-FOUND")
        return False
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")
    return True


def main():
    print("=" * 70)
    print("v32 — Health Article icon remaster + digestion icon bug fix")
    print("=" * 70)

    # ── 1. pubspec.yaml: version bump ────────────────────────────────
    edit(PUBSPEC, "version: 1.2.0+12", "version: 1.2.1+13",
         "pubspec: version 1.2.0+12 -> 1.2.1+13")

    # ── 2. pubspec.yaml: register assets/icons/health/ ───────────────
    edit(PUBSPEC,
         "    - assets/icons/workouts_sisters_hijab/\n",
         "    - assets/icons/workouts_sisters_hijab/\n"
         "    - assets/icons/health/\n",
         "pubspec: register assets/icons/health/")

    # ── 3. icon_assets.dart: helper for the new health icon path ─────
    edit(ICON_ASSETS,
         "String workoutBrotherAsset(String name) => '$_kIcons/workouts_brothers/$name.png';",
         "String workoutBrotherAsset(String name) => '$_kIcons/workouts_brothers/$name.png';\n\n"
         f"// {MARKER}\n"
         "String healthArticleAsset(String name) => '$_kIcons/health/$name.png';",
         "icon_assets: add healthArticleAsset() helper")

    # ── 4. health_screen.dart: HealthArticle gets an iconAsset field ─
    edit(HEALTH,
         "class HealthArticle {\n"
         "  final String id, icon, title, summary, body;\n"
         "  final int colorValue;\n"
         "  const HealthArticle({\n"
         "    required this.id, required this.icon, required this.title,\n"
         "    required this.summary, required this.body, required this.colorValue,\n"
         "  });\n"
         "}",
         f"// {MARKER}: iconAsset is the new illustrated badge; `icon` (the\n"
         "// original emoji) is KEPT as the errorBuilder fallback, not removed.\n"
         "class HealthArticle {\n"
         "  final String id, icon, title, summary, body;\n"
         "  final String? iconAsset;\n"
         "  final int colorValue;\n"
         "  const HealthArticle({\n"
         "    required this.id, required this.icon, required this.title,\n"
         "    required this.summary, required this.body, required this.colorValue,\n"
         "    this.iconAsset,\n"
         "  });\n"
         "}",
         "health: HealthArticle.iconAsset field")

    # ── 5. kHealthArticles: wire each article to its new asset ───────
    replacements = [
        ("h1", "icon:'💧', colorValue:0xFF2196F3, title:'الماء والإماهة',",
               "icon:'💧', iconAsset:'water', colorValue:0xFF2196F3, title:'الماء والإماهة',"),
        ("h2", "icon:'😴', colorValue:0xFF7C4DFF, title:'النوم والتعافي',",
               "icon:'😴', iconAsset:'sleep', colorValue:0xFF7C4DFF, title:'النوم والتعافي',"),
        ("h3", "icon:'❤️', colorValue:0xFFE53935, title:'أرقام القلب التي تُقاس',",
               "icon:'❤️', iconAsset:'heart', colorValue:0xFFE53935, title:'أرقام القلب التي تُقاس',"),
        ("h4", "icon:'🧠', colorValue:0xFF00ACC1, title:'التركيز والذاكرة',",
               "icon:'🧠', iconAsset:'brain', colorValue:0xFF00ACC1, title:'التركيز والذاكرة',"),
        ("h5", "icon:'🦴', colorValue:0xFFFF7043, title:'العظام والمفاصل',",
               "icon:'🦴', iconAsset:'bones', colorValue:0xFFFF7043, title:'العظام والمفاصل',"),
        # BUG FIX: was the lungs emoji on a digestion/fiber article.
        ("h6", "icon:'🫁', colorValue:0xFF4CAF50, title:'الهضم والألياف',",
               "icon:'🥗', iconAsset:'digestion_fiber', colorValue:0xFF4CAF50, title:'الهضم والألياف',"),
        ("h7", "icon:'🧘', colorValue:0xFF9C27B0, title:'الضغط النفسي والاسترخاء',",
               "icon:'🧘', iconAsset:'stress_relax', colorValue:0xFF9C27B0, title:'الضغط النفسي والاسترخاء',"),
        ("h8", "icon:'⚖️', colorValue:0xFFFF5722, title:'الوزن ومؤشر كتلة الجسم',",
               "icon:'⚖️', iconAsset:'weight_bmi', colorValue:0xFFFF5722, title:'الوزن ومؤشر كتلة الجسم',"),
        ("h9", "icon:'🥗', colorValue:0xFF009688, title:'قراءة الملصق الغذائي',",
               "icon:'🥗', iconAsset:'digestion_fiber', colorValue:0xFF009688, title:'قراءة الملصق الغذائي',"),
        ("h10", "icon:'🩸', colorValue:0xFFF44336, title:'المتابعة الدورية',",
                "icon:'🩸', iconAsset:'checkup_blood', colorValue:0xFFF44336, title:'المتابعة الدورية',"),
    ]
    for hid, old, new in replacements:
        edit(HEALTH, old, new, f"health: {hid} -> iconAsset")

    # ── 6. Article tile: render the asset instead of the bare emoji ──
    edit(HEALTH,
         "                    child: Center(child: Text(a.icon,\n"
         "                        style: const TextStyle(fontSize: 24))),",
         f"                    // {MARKER}: illustrated badge, emoji stays\n"
         "                    // as the errorBuilder fallback.\n"
         "                    child: Center(child: a.iconAsset != null\n"
         "                        ? Image.asset(healthArticleAsset(a.iconAsset!),\n"
         "                            width: 28, height: 28, fit: BoxFit.contain,\n"
         "                            errorBuilder: (_, __, ___) => Text(a.icon,\n"
         "                                style: const TextStyle(fontSize: 24)))\n"
         "                        : Text(a.icon,\n"
         "                            style: const TextStyle(fontSize: 24))),",
         "health: article tile renders Image.asset badge")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next:
  1. Drop the 9 PNGs into assets/icons/health/ (see script docstring).
  2. flutter clean && flutter pub get
  3. Rebuild and check the Articles tab in both themes.
""")


if __name__ == "__main__":
    main()
