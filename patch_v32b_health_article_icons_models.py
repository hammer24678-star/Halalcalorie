#!/usr/bin/env python3
"""
patch_v32b_health_article_icons_models.py
=============================================

Follow-up to patch_v32_health_article_icons.py: that script's
health_screen.dart edit (article tile -> Image.asset(a.iconAsset...))
landed fine, but its HealthArticle-class and h1..h10 edits all
SKIPPED-NOT-FOUND because HealthArticle and kHealthArticles actually
live in lib/data/models/models.dart, not health_screen.dart. This
script targets the right file.

Safe to run even though v32 already ran once -- doesn't touch
health_screen.dart or icon_assets.dart again (both already patched),
only models.dart.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V32_HEALTH_ARTICLE_ICONS"

MODELS = "lib/data/models/models.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        _log(label, "SKIPPED-NOT-FOUND")
        return False
    text = p.read_text(encoding="utf-8")
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
    print("v32b — HealthArticle.iconAsset field + h1..h10 wiring (models.dart)")
    print("=" * 70)

    # ── 1. HealthArticle class: add iconAsset field ───────────────────
    edit(MODELS,
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
         "models: HealthArticle.iconAsset field")

    # ── 2. kHealthArticles: wire each article to its new asset ────────
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
        edit(MODELS, old, new, f"models: {hid} -> iconAsset")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next:
  1. flutter clean && flutter pub get
  2. flutter analyze (should be clean)
  3. Rebuild and check the Articles tab in both themes.
""")


if __name__ == "__main__":
    main()
