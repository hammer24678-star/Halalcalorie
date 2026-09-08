#!/usr/bin/env python3
"""patch_v25_player_health.py — fix player checkerboard + health remaster"""
from pathlib import Path
ROOT = Path(__file__).resolve().parent
MARKER = "PATCH_V25_PLAYER_HEALTH"

def apply(rel, sidecar):
    target = ROOT / rel
    side = ROOT / sidecar
    if not target.exists():
        raise SystemExit(f"ERROR: {rel} missing")
    if not side.exists():
        raise SystemExit(f"ERROR: {sidecar} missing — copy it next to this script")
    cur = target.read_text(encoding="utf-8")
    if MARKER in cur and "solid plate" in cur:
        print(f"SKIPPED {rel} (already applied)")
        return
    target.write_text(side.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"REPLACED {rel}")

def main():
    apply("lib/features/fitness/fitness_screen.dart", "fitness_screen_v25.dart")
    apply("lib/features/health/health_screen.dart", "health_screen_v25.dart")
    print()
    print("Fixes:")
    print("  • Workout player: solid plate under illustration (no checkerboard)")
    print("  • Player uses workout art when available")
    print("  • Health: larger score ring, stronger section rails, bigger water #")
    print("  • Articles: color rail + elevated cards")
    print("Full rebuild recommended.")

if __name__ == "__main__":
    main()
