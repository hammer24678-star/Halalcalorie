#!/usr/bin/env python3
"""
patch_v30_workout_outline_and_mood_wrap.py
===========================================

Two unrelated bugs, both visible in the same screenshots:

1. WORKOUT ILLUSTRATION OUTLINE (dark mode only)
   -------------------------------------------
   darkSafeAsset() (icon_assets.dart, v26) fixes PNG fringe by painting
   a flat ColoredBox(0xFF0E1A14) behind the image -- but only mood
   faces, status glyphs, the mosque mark and FoodThumb were ever wired
   to call it (v26-v29). Every workout illustration -- the Fitness
   grid cards, the WorkoutPlayerScreen hero image, and the Ranked
   Lifting exercise rows -- still call a bare Image.asset(), so their
   fringe was never touched. That's the "outline" that's invisible in
   light mode (no fringe issue there) and ugly in dark mode.

   Naively pointing all three at darkSafeAsset with its *default*
   plate wouldn't actually fix it, though: 0xFF0E1A14 only matches the
   specific flat surface v26's targets sit on. The Fitness grid tile
   sits on a translucent brand-color wash over the card, and the
   player illustration sits on its own flat plate (0xFF1A2E22) --
   neither is 0xFF0E1A14, so a flat default box would just swap one
   visible rectangle for a different-colored one. darkSafeAsset now
   takes an optional `plateColor`, and each call site passes its own
   *actual* local surface color (via Color.alphaBlend for the
   translucent ones), so the plate genuinely disappears into the
   surface behind it instead of drawing its own edge.

   NOTE: the checkerboard pattern on the "Back & Core Strength"
   player screen (assets/icons/workouts_brothers/advanced_back_
   shirtless.png) is not this bug -- Image.asset decoded it fine, the
   checkerboard is baked into the PNG's own pixels. No amount of
   plate-color matching fixes that; the source file itself needs to
   be re-exported/replaced.

2. MOOD ROW OVERFLOW
   ------------------
   health_screen.dart's _moodCard lays out all 8 moods in a single
   Row(mainAxisAlignment: spaceAround). spaceAround only distributes
   *leftover* space -- it does nothing once 8 icon+label columns
   don't fit the card width, so the row overflows past the card's
   right edge uncontained (the card has no clipBehavior) instead of
   wrapping or shrinking. Swapping Row -> Wrap keeps every face
   inside the card, dropping to a second line instead of spilling out
   of frame.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V30_DARKSAFE_PLATE_COLOR"
MOOD_MARKER = "PATCH_V30_MOOD_WRAP"

ICON_ASSETS = "lib/data/icon_assets.dart"
HEALTH = "lib/features/health/health_screen.dart"
FITNESS = "lib/features/fitness/fitness_screen.dart"
LIFT = "lib/features/fitness/lift_screen.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = p.read_text(encoding="utf-8")
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")


def main():
    print("=" * 70)
    print("v30 — workout illustration dark-mode outline + mood row overflow")
    print("=" * 70)

    # ── 1a. icon_assets.dart: darkSafeAsset gains `plateColor` ──────
    p = ROOT / ICON_ASSETS
    if not p.exists():
        _log(f"{ICON_ASSETS}: file", "SKIPPED-NOT-FOUND")
    else:
        text = p.read_text(encoding="utf-8")
        if MARKER in text:
            _log("icon_assets: darkSafeAsset already patched", "SKIPPED-ALREADY")
        else:
            old_fn = """Widget darkSafeAsset(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  bool isDark = false,
  Widget? errorChild,
  BorderRadius? radius,
}) {
  final img = Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
    isAntiAlias: true,
    errorBuilder: errorChild == null
        ? null
        : (_, __, ___) => errorChild,
  );
  if (!isDark) return img;
  final child = radius != null
      ? ClipRRect(borderRadius: radius, child: img)
      : img;
  // Soft forest plate ≈ darkCard so residual light fringe blends away.
  return ColoredBox(
    color: const Color(0xFF0E1A14),
    child: child,
  );
}"""
            new_fn = f"""Widget darkSafeAsset(
  String path, {{
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
  bool isDark = false,
  Widget? errorChild,
  BorderRadius? radius,
  Color? plateColor, // {MARKER}
}}) {{
  final img = Image.asset(
    path,
    width: width,
    height: height,
    fit: fit,
    filterQuality: FilterQuality.high,
    gaplessPlayback: true,
    isAntiAlias: true,
    errorBuilder: errorChild == null
        ? null
        : (_, __, ___) => errorChild,
  );
  // {MARKER}: clip now applies in both modes -- previously a light-mode
  // caller passing `radius` silently lost it.
  final clipped = radius != null
      ? ClipRRect(borderRadius: radius, child: img)
      : img;
  if (!isDark) return clipped;
  // Plate defaults to the old flat forest tone for existing callers that
  // don't pass one (mood faces, FoodThumb, status glyphs -- unchanged).
  // New callers should pass the *actual* local surface color (via
  // Color.alphaBlend for a tinted overlay) -- a mismatched flat plate is
  // exactly what drew a visible box instead of hiding the fringe.
  return ColoredBox(
    color: plateColor ?? const Color(0xFF0E1A14),
    child: clipped,
  );
}}"""
            if old_fn in text:
                text = text.replace(old_fn, new_fn, 1)
                p.write_text(text, encoding="utf-8")
                _log("icon_assets: darkSafeAsset(plateColor) + always-clip", "OK")
            else:
                _log("icon_assets: darkSafeAsset(plateColor) + always-clip", "SKIPPED-NOT-FOUND")

    # ── 1b. fitness_screen.dart: grid card illustration ─────────────
    old_grid = """                                Center(
                                  child: iconPath != null
                                      ? Image.asset(iconPath,
                                          width: 88, height: 88, fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              Text(w.emoji, style: const TextStyle(fontSize: 48)))
                                      : Text(w.emoji, style: const TextStyle(fontSize: 48)),
                                ),"""
    new_grid = f"""                                Center(
                                  // {MARKER}: plate matched to this
                                  // tile's own tinted wash, not a flat guess.
                                  child: iconPath != null
                                      ? darkSafeAsset(iconPath,
                                          width: 88, height: 88, fit: BoxFit.contain,
                                          isDark: isDark,
                                          plateColor: Color.alphaBlend(
                                              barCol.withOpacity(0.08), card),
                                          errorChild: Text(w.emoji, style: const TextStyle(fontSize: 48)))
                                      : Text(w.emoji, style: const TextStyle(fontSize: 48)),
                                ),"""
    edit(FITNESS, old_grid, new_grid, "fitness: grid card illustration dark-safe")

    # ── 1c. fitness_screen.dart: WorkoutPlayerScreen hero illustration
    old_player = """              child: Center(
                child: iconPath != null
                    ? Image.asset(iconPath,
                        width: 100, height: 100, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Text(w.emoji, style: const TextStyle(fontSize: 56)))
                    : Text(w.emoji, style: const TextStyle(fontSize: 56)),
              ),"""
    new_player = f"""              child: Center(
                // {MARKER}: plate matches this container's own
                // flat 0xFF1A2E22 fill exactly, so it truly disappears.
                child: iconPath != null
                    ? darkSafeAsset(iconPath,
                        width: 100, height: 100, fit: BoxFit.contain,
                        isDark: isDark,
                        plateColor: const Color(0xFF1A2E22),
                        errorChild: Text(w.emoji, style: const TextStyle(fontSize: 56)))
                    : Text(w.emoji, style: const TextStyle(fontSize: 56)),
              ),"""
    edit(FITNESS, old_player, new_player, "fitness: WorkoutPlayerScreen illustration dark-safe")

    # ── 1d. lift_screen.dart: _ExerciseRow icon ──────────────────────
    old_lift = """            child: Center(
                child: exerciseIconAsset(exercise.id) != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          exerciseIconAsset(exercise.id)!,
                          width: 30,
                          height: 30,
                          fit: BoxFit.contain,
                          // PATCH_LIFT_MUSCLE_ICONS: never let a missing
                          // asset crash the row -- fall back to the emoji.
                          errorBuilder: (_, __, ___) => Text(exercise.glyph,
                              style: const TextStyle(fontSize: 20)),
                        ),
                      )
                    : Text(exercise.glyph,
                        style: const TextStyle(fontSize: 20))),"""
    new_lift = f"""            child: Center(
                // {MARKER}: plate matched to this row's own tinted
                // background instead of the mismatched v26 default.
                child: exerciseIconAsset(exercise.id) != null
                    ? darkSafeAsset(
                        exerciseIconAsset(exercise.id)!,
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                        radius: BorderRadius.circular(10),
                        plateColor: Color.alphaBlend(
                            (logged ? rank.color : muted).withOpacity(0.10), card),
                        // PATCH_LIFT_MUSCLE_ICONS: never let a missing
                        // asset crash the row -- fall back to the emoji.
                        errorChild: Text(exercise.glyph,
                            style: const TextStyle(fontSize: 20)),
                      )
                    : Text(exercise.glyph,
                        style: const TextStyle(fontSize: 20))),"""
    edit(LIFT, old_lift, new_lift, "lift: exercise row icon dark-safe")

    # ── 2. health_screen.dart: mood row Row -> Wrap ──────────────────
    p = ROOT / HEALTH
    if not p.exists():
        _log(f"{HEALTH}: file", "SKIPPED-NOT-FOUND")
    else:
        text = p.read_text(encoding="utf-8")
        if MOOD_MARKER in text:
            _log("health: mood row already patched", "SKIPPED-ALREADY")
        else:
            old_mood = """    return _card(bg, Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: moods.map((m) => GestureDetector("""
            new_mood = f"""    return _card(bg, Column(children: [
      // {MOOD_MARKER}: Row+spaceAround overflowed past the card's
      // right edge at 8 moods (spaceAround only shares *leftover*
      // space -- it doesn't shrink or wrap). Wrap keeps every face
      // inside the card, dropping to a second line instead.
      Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 8,
        children: moods.map((m) => GestureDetector("""
            if old_mood in text:
                text = text.replace(old_mood, new_mood, 1)
                p.write_text(text, encoding="utf-8")
                _log("health: mood row Row -> Wrap", "OK")
            else:
                _log("health: mood row Row -> Wrap", "SKIPPED-NOT-FOUND")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next: flutter clean && flutter pub get, then rebuild in both themes.

Still needs a real fix outside this script:
  assets/icons/workouts_brothers/advanced_back_shirtless.png
  ("Back & Core Strength" / workout w8) decodes fine but its own
  pixels are a checkerboard -- re-export/replace that source file.
  Same applies to any other icon that shows a checkerboard instead
  of falling back to the emoji: that's a broken PNG, not something
  a patch script can repair.
""")


if __name__ == "__main__":
    main()
