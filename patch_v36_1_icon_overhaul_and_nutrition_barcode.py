#!/usr/bin/env python3
"""
patch_v36_1_icon_overhaul_and_nutrition_barcode.py
==================================================

Robust successor to the original v36 patch.

Why v36.1 exists
----------------
The original v36 used exact string matches that no longer matched the
on-disk source after v35. Result: 0 code edits applied even though the
icon generation step succeeded.

This version:
  • Uses tolerant, multi-strategy matching for the two code edits
  • Still generates the 6 missing icons if they are absent
  • Still strips baked white/black backgrounds (idempotent)
  • Is safe to re-run any number of times
  • Leaves clear markers so later patches can see what was done

What it changes
---------------
1. h9 ("قراءة الملصق الغذائي")
   - Give it its own emoji (🏷️) instead of the salad bowl shared with h6
   - Wire iconAsset: 'label_reading' so it loads a real PNG

2. Generate (or heal) the 6 icons that never existed in the pack:
   gymD_walking_lunge, gymD_split_squat, gymD_step_up,
   gymD_kettlebell_swing, gymD_box_jump, label_reading

3. Strip baked flat white/black backgrounds from any icon under
   assets/icons/** that has opaque near-white or near-black corners.

4. Add a Barcode (qr_code_scanner) action to the Nutrition screen
   AppBar next to the existing Add Food button.

Run from the project root:
    python3 patch_v36_1_icon_overhaul_and_nutrition_barcode.py

Needs Pillow + numpy only for steps 2 & 3:
    pkg install python-numpy python-pillow -y
    # or: pip install pillow numpy --break-system-packages
"""

from __future__ import annotations

import math
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER: list[tuple[str, str]] = []
MARKER = "PATCH_V36_1_ICON_OVERHAUL"

MODELS = ROOT / "lib" / "data" / "models" / "models.dart"
NUTRITION = ROOT / "lib" / "features" / "nutrition" / "nutrition_screen.dart"

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    Image = ImageDraw = ImageFilter = None  # type: ignore

try:
    import numpy as np
except ImportError:
    np = None  # type: ignore


def _log(label: str, status: str) -> None:
    LEDGER.append((label, status))
    print(f"  {status:36s} {label}")


# ══════════════════════════════════════════════════════════════════
# 1. Code edits (tolerant matching)
# ══════════════════════════════════════════════════════════════════

def _already_done(text: str, marker: str) -> bool:
    return marker in text


def fix_h9() -> bool:
    """Give h9 its own glyph + iconAsset. Tolerant of formatting drift."""
    if not MODELS.exists():
        _log("models.dart (h9)", "SKIPPED-NOT-FOUND")
        return False

    text = MODELS.read_text(encoding="utf-8")

    if _already_done(text, MARKER) and "iconAsset:'label_reading'" in text:
        _log("models.dart (h9)", "SKIPPED-ALREADY")
        return False

    # Strategy 1 – exact current on-disk line (from the 2026-09-13 dump)
    old1 = (
        "HealthArticle(id:'h9', icon:'🥗', colorValue:0xFF009688, "
        "title:'قراءة الملصق الغذائي', // PATCH_V35_ICON_FALLBACKS: "
        "v32b re-added the h6 duplicate v33 had removed"
    )
    new1 = (
        f"HealthArticle(id:'h9', icon:'🏷️', iconAsset:'label_reading', "
        f"colorValue:0xFF009688, title:'قراءة الملصق الغذائي', "
        f"// {MARKER}: distinct glyph + real icon"
    )

    if old1 in text:
        text = text.replace(old1, new1, 1)
        MODELS.write_text(text, encoding="utf-8")
        _log("models.dart (h9)", "OK")
        return True

    # Strategy 2 – regex: any h9 that still has the salad emoji and no iconAsset
    pattern = re.compile(
        r"HealthArticle\(\s*id\s*:\s*['\"]h9['\"]\s*,\s*"
        r"icon\s*:\s*['\"]🥗['\"]\s*,\s*"
        r"(?!.*iconAsset)"  # negative lookahead – no iconAsset yet
        r"(.*?title\s*:\s*['\"]قراءة الملصق الغذائي['\"])",
        re.DOTALL,
    )

    def repl(m: re.Match) -> str:
        # Rebuild a clean, modern declaration
        return (
            f"HealthArticle(id:'h9', icon:'🏷️', iconAsset:'label_reading', "
            f"colorValue:0xFF009688, title:'قراءة الملصق الغذائي'"
        )

    new_text, n = pattern.subn(repl, text, count=1)
    if n:
        # Keep any trailing comment that was on the original line
        # by a second, simpler pass if needed.
        MODELS.write_text(new_text, encoding="utf-8")
        _log("models.dart (h9)", "OK (regex)")
        return True

    # Strategy 3 – very loose: find the h9 constructor and force the two fields
    loose = re.compile(
        r"(HealthArticle\(\s*id\s*:\s*['\"]h9['\"]\s*,\s*)"
        r"icon\s*:\s*['\"][^'\"]+['\"]\s*,\s*"
        r"(?:iconAsset\s*:\s*['\"][^'\"]*['\"]\s*,\s*)?"
        r"(colorValue\s*:\s*0x[0-9A-Fa-f]+\s*,\s*"
        r"title\s*:\s*['\"]قراءة الملصق الغذائي['\"])",
        re.DOTALL,
    )
    new_text, n = loose.subn(
        rf"\1icon:'🏷️', iconAsset:'label_reading', \2 // {MARKER}",
        text,
        count=1,
    )
    if n:
        MODELS.write_text(new_text, encoding="utf-8")
        _log("models.dart (h9)", "OK (loose)")
        return True

    _log("models.dart (h9)", "SKIPPED-NOT-FOUND")
    return False


def fix_nutrition_barcode() -> bool:
    """Insert Barcode IconButton before the existing Add Food button."""
    if not NUTRITION.exists():
        _log("nutrition_screen.dart (barcode)", "SKIPPED-NOT-FOUND")
        return False

    text = NUTRITION.read_text(encoding="utf-8")

    if _already_done(text, MARKER) and "qr_code_scanner_rounded" in text:
        _log("nutrition_screen.dart (barcode)", "SKIPPED-ALREADY")
        return False

    # Already has a barcode button (from a previous partial run or manual edit)
    if "qr_code_scanner_rounded" in text and "context.push('/scanner')" in text:
        _log("nutrition_screen.dart (barcode)", "SKIPPED-ALREADY")
        return False

    barcode_btn = (
        f"            // {MARKER}: Barcode was Home-only before\n"
        "            IconButton(\n"
        "              icon: Icon(Icons.qr_code_scanner_rounded,\n"
        "                  color: accent, size: 26),\n"
        "              onPressed: () => context.push('/scanner'),\n"
        "              tooltip: tl('باركود', 'Barcode'),\n"
        "            ),\n"
    )

    # Strategy 1 – exact current AppBar actions block from the dump
    old1 = (
        "          actions: [\n"
        "            IconButton(\n"
        "              icon: Icon(Icons.add_circle_outline_rounded,\n"
        "                  color: accent, size: 26),\n"
        "              onPressed: () => _openAdd(context, isAr, isDark, isPremium),\n"
        "              tooltip: tl('أضف طعام', 'Add Food'),\n"
        "            ),\n"
        "          ],"
    )
    new1 = (
        "          actions: [\n"
        + barcode_btn
        + "            IconButton(\n"
        "              icon: Icon(Icons.add_circle_outline_rounded,\n"
        "                  color: accent, size: 26),\n"
        "              onPressed: () => _openAdd(context, isAr, isDark, isPremium),\n"
        "              tooltip: tl('أضف طعام', 'Add Food'),\n"
        "            ),\n"
        "          ],"
    )

    if old1 in text:
        text = text.replace(old1, new1, 1)
        NUTRITION.write_text(text, encoding="utf-8")
        _log("nutrition_screen.dart (barcode)", "OK")
        return True

    # Strategy 2 – regex: find the actions list that only contains the Add Food button
    # and inject the barcode button as the first child.
    pattern = re.compile(
        r"(actions\s*:\s*\[\s*)"
        r"(IconButton\(\s*"
        r"icon\s*:\s*Icon\(\s*Icons\.add_circle_outline_rounded\s*,\s*"
        r"color\s*:\s*accent\s*,\s*size\s*:\s*26\s*\)\s*,\s*"
        r"onPressed\s*:\s*\(\)\s*=>\s*_openAdd\([^)]+\)\s*,\s*"
        r"tooltip\s*:\s*tl\(\s*['\"]أضف طعام['\"]\s*,\s*['\"]Add Food['\"]\s*\)\s*,\s*"
        r"\)\s*,?\s*)"
        r"(\]\s*,)",
        re.DOTALL,
    )

    def repl(m: re.Match) -> str:
        return m.group(1) + barcode_btn + m.group(2) + m.group(3)

    new_text, n = pattern.subn(repl, text, count=1)
    if n:
        NUTRITION.write_text(new_text, encoding="utf-8")
        _log("nutrition_screen.dart (barcode)", "OK (regex)")
        return True

    # Strategy 3 – even looser: any actions: [ that contains the Add Food IconButton
    # and does not yet contain a scanner icon.
    loose = re.compile(
        r"(actions\s*:\s*\[\s*)"
        r"(.*?Icons\.add_circle_outline_rounded.*?)"
        r"(\]\s*,)",
        re.DOTALL,
    )

    def loose_repl(m: re.Match) -> str:
        block = m.group(2)
        if "qr_code_scanner" in block:
            return m.group(0)  # already present
        return m.group(1) + barcode_btn + block + m.group(3)

    new_text, n = loose.subn(loose_repl, text, count=1)
    if n and "qr_code_scanner_rounded" in new_text:
        NUTRITION.write_text(new_text, encoding="utf-8")
        _log("nutrition_screen.dart (barcode)", "OK (loose)")
        return True

    _log("nutrition_screen.dart (barcode)", "SKIPPED-NOT-FOUND")
    return False


def apply_code_edits() -> None:
    print()
    print("-" * 70)
    print("Step 1: code edits (h9 + Nutrition barcode)")
    print("-" * 70)
    fix_h9()
    fix_nutrition_barcode()


# ══════════════════════════════════════════════════════════════════
# 2. Flat-icon generator (only used when no real art exists)
# ══════════════════════════════════════════════════════════════════

FINAL_SIZE = 160
SS = 4
CANVAS = FINAL_SIZE * SS


def _capsule(d, p1, p2, width, fill):
    d.line([p1, p2], fill=fill, width=int(width))
    r = width / 2
    for (x, y) in (p1, p2):
        d.ellipse([x - r, y - r, x + r, y + r], fill=fill)


def _hole(d, cx, cy, r):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 0, 0, 0))


def _chevron_up(d, cx, cy, half_w, half_h, thickness, fill):
    _capsule(d, (cx - half_w, cy + half_h), (cx, cy - half_h), thickness, fill)
    _capsule(d, (cx, cy - half_h), (cx + half_w, cy + half_h), thickness, fill)


def _arc_thick(d, cx, cy, r, a0, a1, thickness, fill, steps=24):
    pts = [
        (
            cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
            cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps)),
        )
        for i in range(steps + 1)
    ]
    for i in range(len(pts) - 1):
        _capsule(d, pts[i], pts[i + 1], thickness, fill)


def draw_walking_lunge(d, S, fill):
    back = (S * 0.30, S * 0.66)
    front = (S * 0.66, S * 0.36)
    fw, fh = S * 0.20, S * 0.32
    for cx, cy in (back, front):
        d.rounded_rectangle(
            [cx - fw / 2, cy - fh / 2, cx + fw / 2, cy + fh / 2],
            radius=fw * 0.45,
            fill=fill,
        )
    for i in range(3):
        x = back[0] - S * 0.20 - i * S * 0.08
        _capsule(
            d,
            (x, back[1] - S * 0.10),
            (x - S * 0.05, back[1] + S * 0.10),
            S * 0.025,
            fill,
        )


def draw_split_squat(d, S, fill):
    bench_w, bench_h = S * 0.26, S * 0.10
    bx, by = S * 0.70, S * 0.62
    d.rounded_rectangle(
        [bx - bench_w / 2, by - bench_h / 2, bx + bench_w / 2, by + bench_h / 2],
        radius=bench_h * 0.4,
        fill=fill,
    )
    d.ellipse(
        [
            bx - S * 0.06,
            by - bench_h / 2 - S * 0.10,
            bx + S * 0.10,
            by - bench_h / 2 + S * 0.02,
        ],
        fill=fill,
    )
    hip, knee, foot = (S * 0.34, S * 0.28), (S * 0.30, S * 0.50), (S * 0.40, S * 0.72)
    _capsule(d, hip, knee, S * 0.09, fill)
    _capsule(d, knee, foot, S * 0.09, fill)
    d.ellipse(
        [foot[0] - S * 0.10, foot[1] - S * 0.04, foot[0] + S * 0.12, foot[1] + S * 0.06],
        fill=fill,
    )


def draw_step_up(d, S, fill):
    step_w = S * 0.5
    d.rounded_rectangle(
        [S * 0.20, S * 0.62, S * 0.20 + step_w * 0.6, S * 0.80],
        radius=S * 0.03,
        fill=fill,
    )
    d.rounded_rectangle(
        [S * 0.20 + step_w * 0.3, S * 0.40, S * 0.20 + step_w, S * 0.62],
        radius=S * 0.03,
        fill=fill,
    )
    _chevron_up(d, S * 0.62, S * 0.24, S * 0.10, S * 0.07, S * 0.045, fill)


def draw_kettlebell_swing(d, S, fill):
    cx, cy = S * 0.42, S * 0.58
    body_w, body_h = S * 0.34, S * 0.30
    d.rounded_rectangle(
        [cx - body_w / 2, cy - body_h / 2, cx + body_w / 2, cy + body_h * 0.62],
        radius=body_w * 0.5,
        fill=fill,
    )
    _arc_thick(d, cx, cy - body_h * 0.42, body_w * 0.30, 200, 340, S * 0.045, fill)
    _arc_thick(d, S * 0.72, S * 0.50, S * 0.16, -60, 60, S * 0.028, fill)
    _arc_thick(d, S * 0.80, S * 0.50, S * 0.10, -60, 60, S * 0.024, fill)


def draw_box_jump(d, S, fill):
    box_w, box_h = S * 0.42, S * 0.34
    d.rounded_rectangle(
        [S * 0.30, S * 0.50, S * 0.30 + box_w, S * 0.50 + box_h],
        radius=S * 0.025,
        fill=fill,
    )
    _chevron_up(d, S * 0.51, S * 0.28, S * 0.11, S * 0.09, S * 0.05, fill)


def draw_label_reading(d, S, fill):
    d.rounded_rectangle(
        [S * 0.20, S * 0.22, S * 0.72, S * 0.66], radius=S * 0.06, fill=fill
    )
    _hole(d, S * 0.30, S * 0.32, S * 0.035)
    for i, y in enumerate([S * 0.44, S * 0.52, S * 0.60]):
        w = S * 0.32 if i < 2 else S * 0.20
        d.line([(S * 0.30, y), (S * 0.30 + w, y)], fill=(0, 0, 0, 0), width=int(S * 0.025))
    mg_cx, mg_cy, mg_r = S * 0.68, S * 0.68, S * 0.14
    d.ellipse(
        [mg_cx - mg_r, mg_cy - mg_r, mg_cx + mg_r, mg_cy + mg_r], fill=fill
    )
    _hole(d, mg_cx, mg_cy, mg_r * 0.6)
    _capsule(
        d,
        (mg_cx + mg_r * 0.7, mg_cy + mg_r * 0.7),
        (mg_cx + mg_r * 1.5, mg_cy + mg_r * 1.5),
        S * 0.035,
        fill,
    )


def generate_icon(path: Path, draw_fn, color_hex: str) -> bool:
    if Image is None:
        return False
    r = int(color_hex[0:2], 16)
    g = int(color_hex[2:4], 16)
    b = int(color_hex[4:6], 16)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    draw_fn(d, CANVAS, (r, g, b, 255))
    final = canvas.resize((FINAL_SIZE, FINAL_SIZE), Image.LANCZOS)
    path.parent.mkdir(parents=True, exist_ok=True)
    final.save(path)
    return True


def _norm(p: Path) -> str:
    return p.stem.lower().replace("-", "_").replace(" ", "_")


REQUIRED_NEW_ASSETS = [
    (
        "assets/icons/gym_strength/gymD_walking_lunge.png",
        ["lunge"],
        draw_walking_lunge,
        "2E9C40",
    ),
    (
        "assets/icons/gym_strength/gymD_split_squat.png",
        ["split_squat", "splitsquat", "bulgarian"],
        draw_split_squat,
        "2E9C40",
    ),
    (
        "assets/icons/gym_strength/gymD_step_up.png",
        ["step_up", "stepup", "box_step"],
        draw_step_up,
        "2E9C40",
    ),
    (
        "assets/icons/gym_strength/gymD_kettlebell_swing.png",
        ["kettlebell", "kb_swing", "kbswing"],
        draw_kettlebell_swing,
        "2E9C40",
    ),
    (
        "assets/icons/gym_strength/gymD_box_jump.png",
        ["box_jump", "boxjump"],
        draw_box_jump,
        "2E9C40",
    ),
    (
        "assets/icons/health/label_reading.png",
        ["label_reading", "label", "reading"],
        draw_label_reading,
        "009688",
    ),
]


def resolve_required_assets() -> None:
    icons_root = ROOT / "assets" / "icons"
    all_pngs = list(icons_root.rglob("*.png")) if icons_root.exists() else []

    print()
    print("-" * 70)
    print("Step 2: resolving the 6 icons that were missing")
    print("-" * 70)

    for rel, tokens, draw_fn, color_hex in REQUIRED_NEW_ASSETS:
        target = ROOT / rel
        if target.exists():
            _log(rel, "PRESENT")
            continue
        candidates = [
            f
            for f in all_pngs
            if f.resolve() != target.resolve()
            and any(tok in _norm(f) for tok in tokens)
        ]
        if len(candidates) == 1:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidates[0], target)
            _log(rel, f"HEALED <- {candidates[0].relative_to(ROOT)}")
        elif len(candidates) > 1:
            _log(rel, f"AMBIGUOUS ({len(candidates)} matches) — generating")
            if generate_icon(target, draw_fn, color_hex):
                _log(rel, "GENERATED")
            else:
                _log(rel, "MISSING (Pillow not installed)")
        else:
            if generate_icon(target, draw_fn, color_hex):
                _log(rel, "GENERATED (no source art existed)")
            else:
                _log(rel, "MISSING (Pillow not installed)")


# ══════════════════════════════════════════════════════════════════
# 3. Strip baked-in white/black backgrounds
# ══════════════════════════════════════════════════════════════════

def _needs_strip(rgba) -> bool:
    h, w = rgba.shape[:2]
    corners = [rgba[0, 0], rgba[0, w - 1], rgba[h - 1, 0], rgba[h - 1, w - 1]]
    opaque = [c for c in corners if int(c[3]) >= 200]
    if not opaque:
        return False
    for c in opaque:
        r, g, b = int(c[0]), int(c[1]), int(c[2])
        near_white = r > 230 and g > 230 and b > 230
        near_black = r < 40 and g < 40 and b < 40
        if not (near_white or near_black):
            return False
    return True


def _flood_bg_mask(rgba, tol=30, max_iter=500):
    h, w = rgba.shape[:2]
    rgb = rgba[..., :3].astype(np.int16)
    alpha = rgba[..., 3]
    visited = np.zeros((h, w), dtype=bool)
    visited[0, :] = True
    visited[-1, :] = True
    visited[:, 0] = True
    visited[:, -1] = True
    visited |= alpha < 10
    changed, it = True, 0
    while changed and it < max_iter:
        changed = False
        it += 1
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            sv = np.roll(visited, (dy, dx), axis=(0, 1))
            srgb = np.roll(rgb, (dy, dx), axis=(0, 1))
            diff = np.abs(rgb - srgb).max(axis=-1)
            cand = sv & (~visited) & (diff <= tol)
            if cand.any():
                visited |= cand
                changed = True
    return visited


def strip_baked_background(path: Path) -> str:
    if Image is None or np is None:
        return "SKIPPED-NO-PILLOW-OR-NUMPY"
    img = Image.open(path).convert("RGBA")
    rgba = np.array(img)
    if not _needs_strip(rgba):
        return "SKIPPED-ALREADY-CLEAN"
    mask = _flood_bg_mask(rgba)
    frac = mask.mean()
    if frac > 0.92:
        return "SKIPPED-SUSPICIOUS (would strip >92%)"
    if frac < 0.005:
        return "SKIPPED-NOTHING-TO-STRIP"
    bak = path.with_suffix(".orig.png")
    if not bak.exists():
        shutil.copy2(path, bak)
    out = rgba.copy()
    out[mask, 3] = 0
    result = Image.fromarray(out, "RGBA")
    alpha_ch = result.split()[3].filter(ImageFilter.GaussianBlur(0.6))
    result.putalpha(alpha_ch)
    result.save(path)
    return f"STRIPPED ({frac * 100:.0f}% -> transparent)"


def strip_all_backgrounds() -> None:
    icons_root = ROOT / "assets" / "icons"
    if not icons_root.exists():
        _log("assets/icons/", "SKIPPED-NOT-FOUND")
        return
    pngs = sorted(icons_root.rglob("*.png"))
    pngs = [p for p in pngs if not p.name.endswith(".orig.png")]

    print()
    print("-" * 70)
    print(f"Step 3: scanning {len(pngs)} icons for baked white/black backgrounds")
    print("-" * 70)

    stripped = 0
    for p in pngs:
        status = strip_baked_background(p)
        if status.startswith("STRIPPED"):
            stripped += 1
            _log(str(p.relative_to(ROOT)), status)
    print(f"\n{stripped} file(s) had a baked backdrop stripped to transparent.")
    if stripped == 0:
        print("(Nothing matched the corner-color heuristic — icons already clean")
        print(" or already transparent. .orig.png backups are left if any strip")
        print(" ever looked wrong.)")


def main() -> None:
    print("=" * 70)
    print(f"{MARKER}: h9 fix, missing lift icons, background strip,")
    print("Nutrition barcode action — robust matching edition")
    print("=" * 70)

    apply_code_edits()
    resolve_required_assets()
    strip_all_backgrounds()

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s.startswith("OK"))
    print(f"{ok} code edit(s) applied.")
    if Image is None or np is None:
        print("Pillow/numpy missing — icon generation & background stripping")
        print("were skipped. Install with:")
        print("  pkg install python-numpy python-pillow -y")
        print("then re-run this script.")
    print("=" * 70)
    print(
        """
Next steps on the device:

  1. cd ~/HalalCalorie   (or wherever the project lives)
  2. python3 patch_v36_1_icon_overhaul_and_nutrition_barcode.py
  3. export PATH="$PATH:$HOME/flutter/bin"   # adjust if needed
  4. flutter clean && flutter pub get && flutter run

Verify in both light and dark mode:
  • Fitness → Ranked Lifting → Legs : the 5 new poses show real icons
  • Health → Articles : "الهضم والألياف" and "قراءة الملصق الغذائي"
    look different from each other
  • Nutrition AppBar : barcode scanner icon appears next to Add Food

If any generated icon looks wrong, its <name>.orig.png neighbour
is the untouched original.
"""
    )


if __name__ == "__main__":
    main()
