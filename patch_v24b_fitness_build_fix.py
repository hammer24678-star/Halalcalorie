#!/usr/bin/env python3
"""
patch_v24b_fitness_build_fix.py
================================
Fixes CI build failure from v24:

1. Trailing dump separator lines (====) left in fitness_screen.dart
2. Null-safety: rec.emoji on Workout? — promote to non-null local

Run from project root after v24 was applied.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
TARGET = ROOT / "lib/features/fitness/fitness_screen.dart"
SIDECAR = Path(__file__).with_name("fitness_screen_v24_fixed.dart")


def main():
    if SIDECAR.exists():
        # Preferred: full clean file
        if not TARGET.exists():
            raise SystemExit(f"ERROR: {TARGET} not found")
        TARGET.write_text(SIDECAR.read_text(encoding="utf-8"), encoding="utf-8")
        print("REPLACED with clean fitness_screen_v24_fixed.dart")
        print("  - no trailing ==== separators")
        print("  - null-safe recommended workout")
        return

    # Fallback: surgical fix on existing file
    if not TARGET.exists():
        raise SystemExit(f"ERROR: {TARGET} not found")
    text = TARGET.read_text(encoding="utf-8")

    # 1) Strip separator junk
    lines = [L for L in text.splitlines() if not re.match(r"^=+$", L.strip())]
    text = "\n".join(lines).rstrip() + "\n"

    # 2) Null-safety: promote rec after null check
    if "final Workout recommended = rec;" not in text:
        text = text.replace(
            "if (rec == null) return const SizedBox.shrink();\n"
            "            // PATCH_V24: recommended as a true hero card",
            "if (rec == null) return const SizedBox.shrink();\n"
            "            final Workout recommended = rec; // promote for null-safety\n"
            "            // PATCH_V24: recommended as a true hero card",
            1,
        )
        # Replace remaining rec. / rec! with recommended in the hero block only
        # Narrow: from hero card start until next const SizedBox after hero
        start = text.find("// PATCH_V24: recommended as a true hero card")
        end = text.find("const SizedBox(height: 6),", start)
        if start > 0 and end > start:
            block = text[start:end]
            block = block.replace("rec!.id", "recommended.id")
            block = block.replace("rec.id", "recommended.id")
            block = block.replace("rec.emoji", "recommended.emoji")
            block = block.replace("rec.titleAr", "recommended.titleAr")
            block = block.replace("rec.titleEn", "recommended.titleEn")
            block = block.replace("rec.durationMin", "recommended.durationMin")
            block = block.replace("rec.levelEn", "recommended.levelEn")
            block = block.replace("rec.level", "recommended.level")
            text = text[:start] + block + text[end:]

    TARGET.write_text(text, encoding="utf-8")
    print("SURGICAL FIX applied to fitness_screen.dart")
    print("  - stripped ==== lines")
    print("  - null-safe recommended")


if __name__ == "__main__":
    main()
