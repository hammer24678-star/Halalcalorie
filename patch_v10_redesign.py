#!/usr/bin/env python3
"""
patch_v10_redesign.py — HalalCalorie v10 redesign
==================================================

WHAT THIS DOES
  1. Registers the new fonts (Aligarh, LemonBrush, Alyamama) and the new
     icon pack in pubspec.yaml.
  2. Rewrites AppColors in lib/core/theme.dart to the v10 forest-green /
     desert-gold / ramadan-purple-gold palette, and adds a new AppFonts
     class. Every existing AppColors.* constant name is kept (700+ call
     sites across the app reference these by name) — only values change,
     plus a handful of new additive tokens.
  3. Globally replaces fontFamily: 'Cairo' -> fontFamily: 'Aligarh' across
     every .dart file under lib/ (701 occurrences as of the dump this was
     built against). Cairo was never actually bundled — no fonts: entry
     existed for it — so this is the app's first real embedded font.
  4. Creates lib/data/icon_assets.dart, mapping the new icon pack to
     specific features.
  5. Wires the new assets into 7 verified, exact-match spots: splash logo,
     prayer-card mosque badge, profile avatar, home screen's 4 stat icons
     + 2 quick-action icons + wordmark, health screen's mood picker (5
     mismatched placeholders -> 8 purpose-built moods) + step-stat fire
     icon, nutrition's wholesome-food snackbar, and lift_screen's exercise
     row icons (13 muscle-diagram placeholders -> real exercise photos,
     with the muscle art kept as an automatic fallback).

BEFORE RUNNING
  Extract v10_assets_bundle.zip at the project root first:
      unzip v10_assets_bundle.zip -d .
  This drops the real font/icon files into assets/fonts/ and
  assets/icons/ — this script only edits code, it does not know how to
  fetch the binaries itself.

SAFETY
  Same rule as patch_lift_muscle_icons.py: every text edit requires an
  exact match (a single occurrence for one-off edits, an exact count for
  blanket replaces). On any mismatch, nothing in that file is touched and
  a REFUSED line explains what was expected vs. found, so a partial run
  never leaves a file half-patched.

Run from the project root:  python3 patch_v10_redesign.py
"""
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent
LEDGER = []
FAILED = []


def _p(relpath):
    return ROOT / relpath


def apply_one(relpath, old, new, note):
    """Replace exactly one occurrence of `old`. Refuses on 0 or 2+ matches."""
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


def apply_all(relpath, old, new, note, expect):
    """Replace every occurrence of `old`. Refuses unless the count matches `expect`."""
    path = _p(relpath)
    if not path.exists():
        FAILED.append(f"{relpath}: file not found")
        print(f"REFUSING {relpath}: file not found — {note}")
        return False
    text = path.read_text(encoding="utf-8")
    n = text.count(old)
    if n != expect:
        FAILED.append(f"{relpath}: {note} (expected {expect} matches, found {n})")
        print(f"REFUSING {relpath}: expected exactly {expect} matches for {note!r}, "
              f"found {n}. No changes made to this file.")
        return False
    path.write_text(text.replace(old, new), encoding="utf-8")
    LEDGER.append(f"OK   {relpath}: {note} ({n}x)")
    return True


def sweep_cairo_to_aligarh():
    """Blanket 'Cairo' -> 'Aligarh' across every .dart file under lib/,
    file by file, so one unexpected file doesn't block the rest."""
    lib_dir = ROOT / "lib"
    if not lib_dir.exists():
        print("REFUSING font sweep: lib/ not found — is this the project root?")
        return
    total = 0
    files_touched = 0
    for f in sorted(lib_dir.rglob("*.dart")):
        text = f.read_text(encoding="utf-8")
        n = text.count("'Cairo'")
        if n == 0:
            continue
        f.write_text(text.replace("'Cairo'", "'Aligarh'"), encoding="utf-8")
        rel = f.relative_to(ROOT)
        LEDGER.append(f"OK   {rel}: 'Cairo' -> 'Aligarh' ({n}x)")
        total += n
        files_touched += 1
    print(f"Font sweep: replaced {total} occurrence(s) of 'Cairo' across {files_touched} file(s).")


def check_bundle_assets():
    expected = [
        "assets/fonts/AligarhArabicFREEPERSONALUSE-Regular.otf",
        "assets/fonts/AligarhArabicFREEPERSONALUSE-Black.otf",
        "assets/fonts/LemonBrush-Regular.otf",
        "assets/fonts/Alyamama-Bold.ttf",
        "assets/icons/mood_faces/mumtaz.png",
        "assets/icons/status_glyphs/glyph_fire.png",
        "assets/icons/mosque_mark/mosque_medium.png",
        "assets/icons/wholesome_foods_10/tamr.png",
        "assets/icons/avatars/avatar_sisters_1.png",
        "assets/icons/gym_strength/gymA_deadlift.png",
    ]
    missing = [e for e in expected if not _p(e).exists()]
    if missing:
        print("WARNING: some expected asset files are missing. Did you extract "
              "v10_assets_bundle.zip at the project root first?")
        for m in missing:
            print(f"  missing: {m}")
        print("Continuing anyway — code edits don't require the binaries to be "
              "present, but the app will show fallback emoji/art until they are.")
    else:
        print("Asset bundle looks present.")


# ═════════════════════════════════════════════════════════════════
# 1. pubspec.yaml — register fonts + new asset directories
# ═════════════════════════════════════════════════════════════════
def patch_pubspec():
    old = "    - assets/store/"
    new = """    - assets/store/
    - assets/icons/mood_faces/
    - assets/icons/status_glyphs/
    - assets/icons/mosque_mark/
    - assets/icons/wholesome_foods_10/
    - assets/icons/avatars/
    - assets/icons/fruits/
    - assets/icons/vegetables/
    - assets/icons/proteins/
    - assets/icons/pantry_and_dishes/
    - assets/icons/gym_strength/
    - assets/icons/workouts_brothers/
    - assets/icons/workouts_sisters_hijab/

  fonts:
    - family: Aligarh
      fonts:
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-Thin.otf
          weight: 100
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-ExtraLight.otf
          weight: 200
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-Light.otf
          weight: 300
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-Regular.otf
          weight: 400
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-Medium.otf
          weight: 500
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-SemiBold.otf
          weight: 600
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-Bold.otf
          weight: 700
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-ExtraBold.otf
          weight: 800
        - asset: assets/fonts/AligarhArabicFREEPERSONALUSE-Black.otf
          weight: 900
    - family: LemonBrush
      fonts:
        - asset: assets/fonts/LemonBrush-Regular.otf
    - family: Alyamama
      fonts:
        - asset: assets/fonts/Alyamama-Bold.ttf
          weight: 700"""
    apply_one("pubspec.yaml", old, new, "register v10 fonts + icon asset directories")


# ═════════════════════════════════════════════════════════════════
# 2. theme.dart — palette overhaul + new AppFonts class
# ═════════════════════════════════════════════════════════════════
_OLD_APPCOLORS = """class AppColors {
  // Brand
  static const brandGreen = Color(0xFF238636);
  static const halalGreen  = Color(0xFF3FB950);
  static const darkGreen   = Color(0xFF196127);
  static const accentGold = Color(0xFFD29922);
  static const haramRed    = Color(0xFFF85149);
  static const doubtOrange = Color(0xFFD1812A);
  static const waterBlue   = Color(0xFF58A6FF);
  static const sleepPurple = Color(0xFFBC8CFF);

  // GitHub-dark canvas
  static const darkBg      = Color(0xFF0D1117);
  static const darkCard    = Color(0xFF161B22);
  static const darkCardAlt = Color(0xFF1C2128);
  static const darkBorder  = Color(0xFF30363D);
  static const darkBorder2 = Color(0xFF21262D);
  static const darkText    = Color(0xFFE6EDF3);
  static const darkMuted   = Color(0xFF8B949E);
  static const darkDimmed  = Color(0xFF484F58);

  // Light canvas
  static const lightBg     = Color(0xFFFFFFFF);
  static const lightCard   = Color(0xFFF6F8FA);
  static const lightBorder = Color(0xFFD0D7DE);
  static const lightText   = Color(0xFF24292F);
  static const lightMuted  = Color(0xFF656D76);

  static const gradientGreen = LinearGradient(
    colors: [Color(0xFF238636), Color(0xFF3FB950)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFD29922), Color(0xFFE3B341)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ── Ramadan Night-Sky palette (dark mode) ──────────────────────
  static const ramadanNight   = Color(0xFF0B0919); // deep cosmic indigo
  static const ramadanCard    = Color(0xFF12102A); // card surface
  static const ramadanCardAlt = Color(0xFF1A1838); // elevated card
  static const ramadanBorder  = Color(0xFF2A2650); // subtle indigo border
  static const ramadanBorder2 = Color(0xFF1E1C3A); // faint border
  static const ramadanGold    = Color(0xFFE8B84B); // rich warm gold
  static const ramadanGoldDim = Color(0xFFB88E2A); // dimmed gold
  static const ramadanText    = Color(0xFFF0E6C8); // warm parchment
  static const ramadanMuted   = Color(0xFFA89878); // warm sand
  static const ramadanDimmed  = Color(0xFF5C5040); // muted amber

  // ── Ramadan Desert-Sunrise palette (light mode) ────────────────
  static const ramadanDay     = Color(0xFFFEF5E4); // warm parchment bg
  static const ramadanDayCard = Color(0xFFFDF0D0); // honey cream card
  static const ramadanDayText = Color(0xFF2C1800); // deep warm brown
  static const ramadanDayMuted= Color(0xFF7A5500); // amber muted

  static const gradientRamadan = LinearGradient(
    colors: [Color(0xFF0B0919), Color(0xFFE8B84B)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientRamadanDay = LinearGradient(
    colors: [Color(0xFFEE9D2A), Color(0xFFD29922)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}"""

_NEW_APPCOLORS = """class AppColors {
  // Brand
  static const brandGreen = Color(0xFF238636);
  static const halalGreen  = Color(0xFF3FB950);
  static const darkGreen   = Color(0xFF196127);
  static const accentGold = Color(0xFFDBA75D);
  static const haramRed    = Color(0xFFEF6A60);
  static const doubtOrange = Color(0xFFD1812A);
  static const waterBlue   = Color(0xFF6FB3FF);
  static const sleepPurple = Color(0xFFBC8CFF);
  // v10: brighter mint + deep accent, used for dark-mode highlights
  static const accentBright   = Color(0xFF78E08E);
  static const accentDeepDark = Color(0xFF2E9C40);
  static const accentInkDark  = Color(0xFF06210C);

  // v10 forest-night canvas (was GitHub-dark gray)
  static const darkBg      = Color(0xFF071310);
  static const darkCard    = Color(0xFF0F1E18);
  static const darkCardAlt = Color(0xFF152C21);
  static const darkBorder  = Color(0x2B94C9A9);
  static const darkBorder2 = Color(0x1A94C9A9);
  static const darkText    = Color(0xFFEEF6F0);
  static const darkMuted   = Color(0xFF8BA095);
  static const darkDimmed  = Color(0xFF556458);
  static const greetGold   = Color(0xFFF0CF98); // cursive-greeting accent, dark mode

  // v10 canvas (was flat white)
  static const lightBg      = Color(0xFFF5F8F5);
  static const lightCard    = Color(0xFFF6F8F6);
  static const lightCardAlt = Color(0xFFEEF3EE);
  static const lightBorder  = Color(0x1F1B2420);
  static const lightBorder2 = Color(0x121B2420);
  static const lightText    = Color(0xFF182420);
  static const lightMuted   = Color(0xFF5C6B62);
  static const lightMuted2  = Color(0xFF8B988F);
  static const greetGoldLight = Color(0xFFA9761F); // cursive-greeting accent, light mode

  static const gradientGreen = LinearGradient(
    colors: [Color(0xFF238636), Color(0xFF3FB950)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientGold = LinearGradient(
    colors: [Color(0xFFDBA75D), Color(0xFFEBCB8E)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ── Ramadan Night-Sky palette (dark mode) — v10 purple-gold ────
  static const ramadanNight   = Color(0xFF0B0919); // deep cosmic indigo
  static const ramadanCard    = Color(0xFF150F2C); // card surface
  static const ramadanCardAlt = Color(0xFF1C1640); // elevated card
  static const ramadanBorder  = Color(0x38E8B84B); // gold hairline, visible
  static const ramadanBorder2 = Color(0x1FE8B84B); // gold hairline, faint
  static const ramadanGold    = Color(0xFFE8B84B); // rich warm gold
  static const ramadanGoldDim = Color(0xFFB88E2A); // dimmed gold
  static const ramadanText    = Color(0xFFF3ECD6); // warm parchment
  static const ramadanMuted   = Color(0xFFB9A37E); // warm sand
  static const ramadanDimmed  = Color(0xFF6D5F46); // muted amber
  static const ramadanAccentBright = Color(0xFFFFD97A); // bright gold highlight
  static const ramadanInk     = Color(0xFF1A0800); // text-on-gold

  // ── Ramadan Desert-Sunrise palette (light mode) — unchanged; v10's
  // mockup only shows a night-mode Ramadan theme, so this keeps its
  // existing values rather than guessing at a redesign for it. ────
  static const ramadanDay     = Color(0xFFFEF5E4); // warm parchment bg
  static const ramadanDayCard = Color(0xFFFDF0D0); // honey cream card
  static const ramadanDayText = Color(0xFF2C1800); // deep warm brown
  static const ramadanDayMuted= Color(0xFF7A5500); // amber muted

  static const gradientRamadan = LinearGradient(
    colors: [Color(0xFF0B0919), Color(0xFFE8B84B)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const gradientRamadanDay = LinearGradient(
    colors: [Color(0xFFEE9D2A), Color(0xFFD29922)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

/// v10 redesign fonts. 'Cairo' was referenced 701 times across the app but
/// never actually bundled (pubspec had no fonts: entry for it), so every
/// fontFamily: 'Cairo' silently fell back to the system default. This patch
/// changes every one of those to 'Aligarh' — the app's first real embedded
/// font — and adds two more for specific accent roles.
class AppFonts {
  /// Workhorse UI font — headings, numbers and body text app-wide.
  static const aligarh = 'Aligarh';
  /// Cursive accent — reserved for one-off flourishes, not body copy
  /// or buttons (e.g. a home-screen greeting, if one is added later).
  static const lemonBrush = 'LemonBrush';
  /// Decorative display font — reserved for the "HalalCalorie" wordmark.
  static const alyamama = 'Alyamama';

  static const TextStyle greeting = TextStyle(
    fontFamily: lemonBrush, fontSize: 34, height: 1.0,
  );
  static const TextStyle wordmark = TextStyle(
    fontFamily: alyamama, fontWeight: FontWeight.w700,
    color: Colors.white, letterSpacing: 0.2,
  );
}"""


def patch_theme():
    apply_one(
        "lib/core/theme.dart", _OLD_APPCOLORS, _NEW_APPCOLORS,
        "AppColors -> v10 palette (dark/light/ramadan-night) + new AppFonts class"
    )


# ═════════════════════════════════════════════════════════════════
# 3. icon_assets.dart — new file
# ═════════════════════════════════════════════════════════════════
def write_icon_assets():
    src = pathlib.Path(__file__).resolve().parent / "icon_assets.dart"
    dest = _p("lib/data/icon_assets.dart")
    if not src.exists():
        print("REFUSING icon_assets.dart: source file missing next to this "
              "script — did you unzip the whole delivery together?")
        FAILED.append("lib/data/icon_assets.dart: source missing")
        return
    if dest.exists():
        print("SKIPPING lib/data/icon_assets.dart: already exists — not overwriting. "
              "Delete it first if you want this patch to regenerate it.")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dest)
    LEDGER.append("OK   lib/data/icon_assets.dart: created")


# ═════════════════════════════════════════════════════════════════
# 4. Splash screen — logo -> mosque mark
# ═════════════════════════════════════════════════════════════════
def patch_splash():
    apply_one(
        "lib/features/splash/splash_screen.dart",
        "'assets/logo.png',",
        "'assets/icons/mosque_mark/mosque_medium.png',",
        "splash mark -> mosque_mark/mosque_medium.png",
    )


# ═════════════════════════════════════════════════════════════════
# 5. Prayer card — 🕌 emoji -> mosque mark badge
# ═════════════════════════════════════════════════════════════════
def patch_prayer_card():
    apply_one(
        "lib/features/home/prayer_card.dart",
        "                const Text('🕌', style: TextStyle(fontSize: 22)),",
        """                Image.asset('assets/icons/mosque_mark/mosque_small.png',
                    width: 22, height: 22,
                    errorBuilder: (_, __, ___) =>
                        const Text('🕌', style: TextStyle(fontSize: 22))),""",
        "prayer card badge: emoji -> mosque_mark/mosque_small.png",
    )


# ═════════════════════════════════════════════════════════════════
# 6. Profile avatar — 🧕/🧔 emoji -> avatar illustrations
# ═════════════════════════════════════════════════════════════════
def patch_profile_avatar():
    old = """            Container(width: 96, height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: isSis ? AppColors.accentGold.withOpacity(0.15) : AppColors.brandGreen.withOpacity(0.12)),
              child: Center(child: Text(isSis ? '🧕' : '🧔', style: const TextStyle(fontSize: 44)))),"""
    new = """            Container(width: 96, height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: isSis ? AppColors.accentGold.withOpacity(0.15) : AppColors.brandGreen.withOpacity(0.12)),
              child: ClipOval(child: Image.asset(
                isSis ? kAvatarSisters : kAvatarBrothers,
                width: 96, height: 96, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                    child: Text(isSis ? '🧕' : '🧔', style: const TextStyle(fontSize: 44)))))),"""
    apply_one(
        "lib/features/profile/profile_screen.dart", old, new,
        "profile avatar: emoji -> avatars/avatar_{brothers,sisters}_1.png",
    )


# ═════════════════════════════════════════════════════════════════
# 7. Home screen — wordmark font, 4-stat icons, quick-action icons
# ═════════════════════════════════════════════════════════════════
def patch_home_screen():
    # 7a. Wordmark: Cairo -> Alyamama (must run BEFORE the global Cairo
    # sweep, since this one spot should not become Aligarh like the rest).
    apply_one(
        "lib/features/home/home_screen.dart",
        """const Text('HalalCalorie', style: TextStyle(
fontFamily: 'Cairo', fontSize: 13,
fontWeight: FontWeight.w800, color: Colors.white,
letterSpacing: 0.2,
)),""",
        """const Text('HalalCalorie', style: TextStyle(
fontFamily: 'Alyamama', fontSize: 13,
fontWeight: FontWeight.w800, color: Colors.white,
letterSpacing: 0.2,
)),""",
        "wordmark 'HalalCalorie' -> Alyamama",
    )

    # 7b. _Stat row (water/sleep/streak/steps) — shared render spot.
    apply_one(
        "lib/features/home/home_screen.dart",
        "Text(widget.emoji, style: const TextStyle(fontSize: 18)),",
        """statusGlyphForEmoji(widget.emoji) != null
    ? Image.asset(statusGlyphForEmoji(widget.emoji)!, width: 18, height: 18,
        errorBuilder: (_, __, ___) =>
            Text(widget.emoji, style: const TextStyle(fontSize: 18)))
    : Text(widget.emoji, style: const TextStyle(fontSize: 18)),""",
        "4-stat row icons (💧😴🔥🏃) -> status_glyphs",
    )

    # 7c. _QTile quick actions (photo food / barcode / workouts / body).
    apply_one(
        "lib/features/home/home_screen.dart",
        """child: Center(child: Text(item.emoji,
style: const TextStyle(fontSize: 17))),""",
        """child: Center(child: statusGlyphForEmoji(item.emoji) != null
    ? Image.asset(statusGlyphForEmoji(item.emoji)!, width: 20, height: 20,
        errorBuilder: (_, __, ___) =>
            Text(item.emoji, style: const TextStyle(fontSize: 17)))
    : Text(item.emoji, style: const TextStyle(fontSize: 17))),""",
        "quick-action icons (📸🏃) -> status_glyphs",
    )

    # 7d. Import.
    apply_one(
        "lib/features/home/home_screen.dart",
        "import '../../data/models/user_profile.dart';",
        "import '../../data/models/user_profile.dart';\nimport '../../data/icon_assets.dart';",
        "add icon_assets.dart import",
    )


# ═════════════════════════════════════════════════════════════════
# 8. Health screen — mood picker + fire glyph in _stepStat
# ═════════════════════════════════════════════════════════════════
def patch_health_screen():
    old_moods = """    // PATCH_NEW_ASSET_PACKS: mood faces -> assets/emoji/face_emojis/
    final moods = isAr
        ? [['assets/emoji/face_emojis/kirakira.png', 'ممتاز'], ['assets/emoji/face_emojis/uwu.png', 'جيد'], ['assets/emoji/face_emojis/wat.png', 'عادي'], ['assets/emoji/face_emojis/yawn.png', 'تعبان'], ['assets/emoji/face_emojis/nervous.png', 'متوتر']]
        : [['assets/emoji/face_emojis/kirakira.png', 'Great'], ['assets/emoji/face_emojis/uwu.png', 'Good'], ['assets/emoji/face_emojis/wat.png', 'Okay'], ['assets/emoji/face_emojis/yawn.png', 'Low'], ['assets/emoji/face_emojis/nervous.png', 'Stressed']];"""
    new_moods = """    // PATCH_V10_REDESIGN: mood faces -> assets/icons/mood_faces/ (8 purpose-drawn moods)
    final moods = isAr
        ? kMoodFacesAr.map((m) => [m['asset']!, m['label']!]).toList()
        : kMoodFacesEn.map((m) => [m['asset']!, m['label']!]).toList();"""
    apply_one(
        "lib/features/health/health_screen.dart", old_moods, new_moods,
        "mood picker: 5 mismatched face_emojis -> 8 mood_faces",
    )

    apply_one(
        "lib/features/health/health_screen.dart",
        "          Text(emoji, style: const TextStyle(fontSize: 20)),",
        """          statusGlyphForEmoji(emoji) != null
              ? Image.asset(statusGlyphForEmoji(emoji)!, width: 20, height: 20,
                  errorBuilder: (_, __, ___) =>
                      Text(emoji, style: const TextStyle(fontSize: 20)))
              : Text(emoji, style: const TextStyle(fontSize: 20)),""",
        "_stepStat icon (🔥 kcal burned) -> status_glyphs",
    )

    apply_one(
        "lib/features/health/health_screen.dart",
        "import '../../core/health_service.dart';",
        "import '../../core/health_service.dart';\nimport '../../data/icon_assets.dart';",
        "add icon_assets.dart import",
    )


# ═════════════════════════════════════════════════════════════════
# 9. Nutrition screen — wholesome-food snackbar glyph
# ═════════════════════════════════════════════════════════════════
def patch_nutrition_screen():
    old_fn = """/// Returns the glyph and note for a recognised whole food, else null.
(String, String, String)? _checkWholesomeFood(String name) {
  final n = name.toLowerCase();
  for (final e in _kWholesomeFoods.entries) {
    if (n.contains(e.key)) return e.value;
  }
  return null;
}"""
    new_fn = """/// Returns the glyph, notes, and matched key for a recognised whole food,
/// else null. The key lets the caller look up an icon-pack asset without
/// re-deriving it from the (possibly duplicated) emoji glyph.
(String, String, String, String)? _checkWholesomeFood(String name) {
  final n = name.toLowerCase();
  for (final e in _kWholesomeFoods.entries) {
    if (n.contains(e.key)) return (e.value.$1, e.value.$2, e.value.$3, e.key);
  }
  return null;
}"""
    apply_one(
        "lib/features/nutrition/nutrition_screen.dart", old_fn, new_fn,
        "_checkWholesomeFood: return matched key alongside glyph/notes",
    )

    old_render = """                      Text(wholesome.$1,
                        style: const TextStyle(fontSize: 20)),"""
    new_render = """                      wholesomeFoodAsset(wholesome.$4) != null
                        ? Image.asset(wholesomeFoodAsset(wholesome.$4)!,
                            width: 20, height: 20,
                            errorBuilder: (_, __, ___) => Text(wholesome.$1,
                                style: const TextStyle(fontSize: 20)))
                        : Text(wholesome.$1,
                            style: const TextStyle(fontSize: 20)),"""
    apply_one(
        "lib/features/nutrition/nutrition_screen.dart", old_render, new_render,
        "wholesome-food snackbar glyph -> wholesome_foods_10",
    )

    apply_one(
        "lib/features/nutrition/nutrition_screen.dart",
        "import 'widgets/leaf_progress_ring.dart';",
        "import 'widgets/leaf_progress_ring.dart';\nimport '../../data/icon_assets.dart';",
        "add icon_assets.dart import",
    )


# ═════════════════════════════════════════════════════════════════
# 10. Lift screen — exercise photos instead of muscle diagrams
# ═════════════════════════════════════════════════════════════════
def patch_lift_screen():
    apply_all(
        "lib/features/fitness/lift_screen.dart",
        "muscleAssetForExercise(exercise.id)",
        "exerciseIconAsset(exercise.id)",
        "exercise row icon: muscle diagram -> gym_strength photo (falls back to muscle art)",
        expect=2,
    )
    apply_one(
        "lib/features/fitness/lift_screen.dart",
        "import '../../data/muscle_assets.dart';",
        "import '../../data/muscle_assets.dart';\nimport '../../data/icon_assets.dart';",
        "add icon_assets.dart import",
    )


# ═════════════════════════════════════════════════════════════════
def main():
    print("=" * 70)
    print("HalalCalorie v10 redesign patch")
    print("=" * 70)
    check_bundle_assets()
    print()

    patch_pubspec()
    patch_theme()
    write_icon_assets()
    patch_splash()
    patch_prayer_card()
    patch_profile_avatar()
    patch_home_screen()
    patch_health_screen()
    patch_nutrition_screen()
    patch_lift_screen()

    # Global font sweep runs LAST, after the one wordmark spot has already
    # been carved out to Alyamama above.
    print()
    sweep_cairo_to_aligarh()

    print()
    print("=" * 70)
    print(f"{len(LEDGER)} edit(s) applied, {len(FAILED)} refused.")
    for line in LEDGER:
        print(" ", line)
    if FAILED:
        print()
        print("REFUSED (no changes made to these — investigate and re-run):")
        for line in FAILED:
            print(" ", line)
        sys.exit(1)
    print("=" * 70)
    print("Done. Run `flutter pub get` then a full rebuild (fonts/assets")
    print("changes aren't picked up by hot reload).")


if __name__ == "__main__":
    main()
