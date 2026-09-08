#!/usr/bin/env python3
"""patch_v24_fitness_remaster.py — complete Fitness screen redesign"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TARGET = ROOT / "lib/features/fitness/fitness_screen.dart"
MARKER = "PATCH_V24_FITNESS_REMASTER"
SIDECAR = Path(__file__).with_name("fitness_screen_v24.dart")

def main():
    if not TARGET.exists():
        raise SystemExit(f"ERROR: {TARGET} not found — run from project root")
    existing = TARGET.read_text(encoding="utf-8")
    if MARKER in existing:
        print("SKIPPED — already applied")
        return
    if not SIDECAR.exists():
        raise SystemExit(f"ERROR: missing {SIDECAR.name} next to this patch")
    TARGET.write_text(SIDECAR.read_text(encoding="utf-8"), encoding="utf-8")
    print("REPLACED lib/features/fitness/fitness_screen.dart")
    print()
    print("What changed:")
    print("  • Bravoon AppBar title + gold tab indicator")
    print("  • Stronger rank card (58px badge)")
    print("  • Recommended = 120px hero with art + white play button")
    print("  • Coaching quote removed")
    print("  • Magazine workout cards (illustration zone + footer)")
    print("  • Section header 'Workouts'")
    print("Rebuild fully to see it.")

if __name__ == "__main__":
    main()
