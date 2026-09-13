#!/usr/bin/env python3
"""
patch_v36_icon_overhaul_and_nutrition_barcode.py
=================================================

Scope note up front: this does NOT rewrite screen layouts. There's no
spec to redesign to, and blind-rewriting working screens is how a
30-minute patch turns into a week of new bugs. What this DOES do is
find and fix every concrete thing visible in your screenshots, and it
does it in the shared icon plumbing (icon_assets.dart / darkSafeAsset),
so the fix reaches every screen that uses it -- Health, Fitness,
Nutrition, Home, Body -- not just one.

1. h9 ("قراءة الملصق الغذائي") still visually matches h6's salad bowl.
   v35 stopped it from loading h6's PNG, but left it on h6's *emoji*
   ('🥗'), so the fallback still looked identical. This gives h9 its
   own glyph and its own generated icon.

2. The 5 new Ranked Lift poses (walking lunge, split squat, step-up,
   kettlebell swing, box jump) have never had art anywhere in your
   assets/icons/** pack -- that's not a wiring bug, there's just
   nothing to wire to. v35's auto-heal correctly reported them
   MISSING. This generates real flat, transparent, single-colour PNGs
   for them instead of leaving them on emoji.

3. Root-cause fix for the white-square icons AND the dark-mode
   artifacts AND the black outlines -- these are three symptoms of
   one thing: some PNGs in assets/icons/** have a baked-in flat
   white or flat black backdrop instead of a transparent one. Against
   a white app background that's invisible; against your dark green
   cards it shows up as a white box, and against light mode a black
   one. darkSafeAsset's plate-colour trick (v30) can't fix this --
   it composites BEHIND the image, and an opaque baked backdrop just
   covers it up. This scans every PNG under assets/icons/**, and for
   any file whose opaque corners are flat white or flat black, strips
   that backdrop to transparency (flood fill from the border,
   feathered edge) so the real plate colour underneath finally shows
   through, in both themes. Files whose edges already touch real
   illustration colour, or are already transparent, are left alone.

4. Adds a Barcode action to the Nutrition screen's app bar. It already
   exists on Home's quick grid but wasn't reachable from Nutrition.

Run from project root:
    python3 patch_v36_icon_overhaul_and_nutrition_barcode.py

Needs Pillow + numpy for steps 2 and 3 (the code edits in 1 and 4
apply either way):
    pip install pillow numpy --break-system-packages

Marker-gated, idempotent, safe to re-run. Backs up any PNG it edits
as <name>.orig.png before touching it (first run only).

IMPORTANT: if you haven't rebuilt since applying v35, do that now too
-- v35's dim/shrink fallback fix and the h9 un-wiring are already in
your source (confirmed against your dump), but an app still running
an older build won't show any of it. After this script:
    flutter clean && flutter pub get && flutter run
"""
import math
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V36_ICON_OVERHAUL"

MODELS = "lib/data/models/models.dart"
NUTRITION_SCREEN = "lib/features/nutrition/nutrition_screen.dart"

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    Image = ImageDraw = ImageFilter = None

try:
    import numpy as np
except ImportError:
    np = None


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:32s} {label}")


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


# ══════════════════════════════════════════════════════════════════
# 1 & 4. Small, exact code edits
# ══════════════════════════════════════════════════════════════════

def apply_code_edits():
    edit(MODELS,
         "HealthArticle(id:'h9', icon:'🥗', colorValue:0xFF009688, title:'قراءة الملصق الغذائي', "
         "// PATCH_V35_ICON_FALLBACKS: v32b re-added the h6 duplicate v33 had removed",
         "HealthArticle(id:'h9', icon:'🏷️', iconAsset:'label_reading', colorValue:0xFF009688, "
         f"title:'قراءة الملصق الغذائي', // {MARKER}: distinct glyph + real icon, "
         "stops matching h6's salad bowl even on fallback",
         "models: h9 gets its own glyph + icon (not just un-wired from h6)")

    edit(NUTRITION_SCREEN,
         "          actions: [\n"
         "            IconButton(\n"
         "              icon: Icon(Icons.add_circle_outline_rounded,\n"
         "                  color: accent, size: 26),\n"
         "              onPressed: () => _openAdd(context, isAr, isDark, isPremium),\n"
         "              tooltip: tl('أضف طعام', 'Add Food'),\n"
         "            ),\n"
         "          ],",
         f"          actions: [\n"
         f"            // {MARKER}: Barcode was Home-only before -- wasn't reachable from Nutrition.\n"
         "            IconButton(\n"
         "              icon: Icon(Icons.qr_code_scanner_rounded,\n"
         "                  color: accent, size: 26),\n"
         "              onPressed: () => context.push('/scanner'),\n"
         "              tooltip: tl('باركود', 'Barcode'),\n"
         "            ),\n"
         "            IconButton(\n"
         "              icon: Icon(Icons.add_circle_outline_rounded,\n"
         "                  color: accent, size: 26),\n"
         "              onPressed: () => _openAdd(context, isAr, isDark, isPremium),\n"
         "              tooltip: tl('أضف طعام', 'Add Food'),\n"
         "            ),\n"
         "          ],",
         "nutrition_screen: add Barcode action to app bar")


# ══════════════════════════════════════════════════════════════════
# 2. Flat-icon generator (only used when no real art exists to heal from)
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
        (cx + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
         cy + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps)))
        for i in range(steps + 1)
    ]
    for i in range(len(pts) - 1):
        _capsule(d, pts[i], pts[i + 1], thickness, fill)


def draw_walking_lunge(d, S, fill):
    back = (S * 0.30, S * 0.66)
    front = (S * 0.66, S * 0.36)
    fw, fh = S * 0.20, S * 0.32
    for cx, cy in (back, front):
        d.rounded_rectangle([cx - fw / 2, cy - fh / 2, cx + fw / 2, cy + fh / 2],
                             radius=fw * 0.45, fill=fill)
    for i in range(3):
        x = back[0] - S * 0.20 - i * S * 0.08
        _capsule(d, (x, back[1] - S * 0.10), (x - S * 0.05, back[1] + S * 0.10),
                  S * 0.025, fill)


def draw_split_squat(d, S, fill):
    bench_w, bench_h = S * 0.26, S * 0.10
    bx, by = S * 0.70, S * 0.62
    d.rounded_rectangle([bx - bench_w / 2, by - bench_h / 2, bx + bench_w / 2, by + bench_h / 2],
                         radius=bench_h * 0.4, fill=fill)
    d.ellipse([bx - S * 0.06, by - bench_h / 2 - S * 0.10, bx + S * 0.10, by - bench_h / 2 + S * 0.02],
               fill=fill)
    hip, knee, foot = (S * 0.34, S * 0.28), (S * 0.30, S * 0.50), (S * 0.40, S * 0.72)
    _capsule(d, hip, knee, S * 0.09, fill)
    _capsule(d, knee, foot, S * 0.09, fill)
    d.ellipse([foot[0] - S * 0.10, foot[1] - S * 0.04, foot[0] + S * 0.12, foot[1] + S * 0.06], fill=fill)


def draw_step_up(d, S, fill):
    step_w = S * 0.5
    d.rounded_rectangle([S * 0.20, S * 0.62, S * 0.20 + step_w * 0.6, S * 0.80],
                         radius=S * 0.03, fill=fill)
    d.rounded_rectangle([S * 0.20 + step_w * 0.3, S * 0.40, S * 0.20 + step_w, S * 0.62],
                         radius=S * 0.03, fill=fill)
    _chevron_up(d, S * 0.62, S * 0.24, S * 0.10, S * 0.07, S * 0.045, fill)


def draw_kettlebell_swing(d, S, fill):
    cx, cy = S * 0.42, S * 0.58
    body_w, body_h = S * 0.34, S * 0.30
    d.rounded_rectangle([cx - body_w / 2, cy - body_h / 2, cx + body_w / 2, cy + body_h * 0.62],
                         radius=body_w * 0.5, fill=fill)
    _arc_thick(d, cx, cy - body_h * 0.42, body_w * 0.30, 200, 340, S * 0.045, fill)
    _arc_thick(d, S * 0.72, S * 0.50, S * 0.16, -60, 60, S * 0.028, fill)
    _arc_thick(d, S * 0.80, S * 0.50, S * 0.10, -60, 60, S * 0.024, fill)


def draw_box_jump(d, S, fill):
    box_w, box_h = S * 0.42, S * 0.34
    d.rounded_rectangle([S * 0.30, S * 0.50, S * 0.30 + box_w, S * 0.50 + box_h],
                         radius=S * 0.025, fill=fill)
    _chevron_up(d, S * 0.51, S * 0.28, S * 0.11, S * 0.09, S * 0.05, fill)


def draw_label_reading(d, S, fill):
    d.rounded_rectangle([S * 0.20, S * 0.22, S * 0.72, S * 0.66], radius=S * 0.06, fill=fill)
    _hole(d, S * 0.30, S * 0.32, S * 0.035)
    for i, y in enumerate([S * 0.44, S * 0.52, S * 0.60]):
        w = S * 0.32 if i < 2 else S * 0.20
        d.line([(S * 0.30, y), (S * 0.30 + w, y)], fill=(0, 0, 0, 0), width=int(S * 0.025))
    mg_cx, mg_cy, mg_r = S * 0.68, S * 0.68, S * 0.14
    d.ellipse([mg_cx - mg_r, mg_cy - mg_r, mg_cx + mg_r, mg_cy + mg_r], fill=fill)
    _hole(d, mg_cx, mg_cy, mg_r * 0.6)
    _capsule(d, (mg_cx + mg_r * 0.7, mg_cy + mg_r * 0.7), (mg_cx + mg_r * 1.5, mg_cy + mg_r * 1.5),
              S * 0.035, fill)


def generate_icon(path: Path, draw_fn, color_hex: str) -> bool:
    if Image is None:
        return False
    r, g, b = int(color_hex[0:2], 16), int(color_hex[2:4], 16), int(color_hex[4:6], 16)
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
    ("assets/icons/gym_strength/gymD_walking_lunge.png",
     ["lunge"], draw_walking_lunge, "2E9C40"),
    ("assets/icons/gym_strength/gymD_split_squat.png",
     ["split_squat", "splitsquat", "bulgarian"], draw_split_squat, "2E9C40"),
    ("assets/icons/gym_strength/gymD_step_up.png",
     ["step_up", "stepup", "box_step"], draw_step_up, "2E9C40"),
    ("assets/icons/gym_strength/gymD_kettlebell_swing.png",
     ["kettlebell", "kb_swing", "kbswing"], draw_kettlebell_swing, "2E9C40"),
    ("assets/icons/gym_strength/gymD_box_jump.png",
     ["box_jump", "boxjump"], draw_box_jump, "2E9C40"),
    ("assets/icons/health/label_reading.png",
     ["label_reading", "label", "reading"], draw_label_reading, "009688"),
]


def resolve_required_assets():
    icons_root = ROOT / "assets" / "icons"
    all_pngs = list(icons_root.rglob("*.png")) if icons_root.exists() else []

    print()
    print("-" * 70)
    print("Step 2: resolving the 6 icons your screenshots show as missing")
    print("-" * 70)

    for rel, tokens, draw_fn, color_hex in REQUIRED_NEW_ASSETS:
        target = ROOT / rel
        if target.exists():
            _log(rel, "PRESENT")
            continue
        candidates = [
            f for f in all_pngs
            if f.resolve() != target.resolve() and any(tok in _norm(f) for tok in tokens)
        ]
        if len(candidates) == 1:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidates[0], target)
            _log(rel, f"HEALED <- {candidates[0].relative_to(ROOT)}")
        elif len(candidates) > 1:
            _log(rel, f"AMBIGUOUS ({len(candidates)} matches) -- generating instead")
            if generate_icon(target, draw_fn, color_hex):
                _log(rel, "GENERATED")
        else:
            if generate_icon(target, draw_fn, color_hex):
                _log(rel, "GENERATED (no source art existed anywhere in the pack)")
            else:
                _log(rel, "MISSING (Pillow not installed -- pip install pillow --break-system-packages)")


# ══════════════════════════════════════════════════════════════════
# 3. Strip baked-in white/black backgrounds from existing PNGs
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
            return False  # edge touches real illustration colour -- don't touch it
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
        return "SKIPPED-SUSPICIOUS (would strip >92% of the image)"
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
    return f"STRIPPED ({frac * 100:.0f}% of pixels -> transparent)"


def strip_all_backgrounds():
    icons_root = ROOT / "assets" / "icons"
    if not icons_root.exists():
        _log("assets/icons/", "SKIPPED-NOT-FOUND")
        return
    pngs = sorted(icons_root.rglob("*.png"))
    pngs = [p for p in pngs if not p.name.endswith(".orig.png")]

    print()
    print("-" * 70)
    print(f"Step 3: scanning {len(pngs)} existing icons for baked white/black backgrounds")
    print("-" * 70)

    stripped = 0
    for p in pngs:
        status = strip_baked_background(p)
        if status.startswith("STRIPPED"):
            stripped += 1
            _log(str(p.relative_to(ROOT)), status)
    print(f"\n{stripped} file(s) had a baked backdrop stripped to transparent.")
    if stripped == 0:
        print("(Nothing matched the corner-color heuristic -- see the note in the")
        print(" script header if you still see white boxes after rebuilding; the")
        print(" .orig.png backups mean nothing is lost if a strip ever looks wrong.)")


def main():
    print("=" * 70)
    print(f"{MARKER}: h9 fix, generate missing lift icons, strip baked")
    print("icon backgrounds app-wide, add Nutrition barcode action")
    print("=" * 70)

    apply_code_edits()
    resolve_required_assets()
    strip_all_backgrounds()

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} code edit(s) applied.")
    if Image is None or np is None:
        print("Pillow/numpy missing -- icon generation and background-stripping were")
        print("skipped. Run: pip install pillow numpy --break-system-packages")
        print("then re-run this script to finish steps 2 and 3.")
    print("=" * 70)
    print("""
Next:
  1. flutter clean && flutter pub get
  2. flutter run  (or reinstall the APK -- if you applied v35 but never
     rebuilt, this step alone will already fix a chunk of what's in
     your screenshots: the dimmed/shrunk emoji fallback and the h9
     un-wiring are both already in your source from v35.)
  3. Check in BOTH light and dark mode:
     - Fitness > Ranked Lifting > Legs: the 5 new poses should show
       real icons now, not emoji.
     - Health > Articles: "الهضم والألياف" and "قراءة الملصق الغذائي"
       should look different from each other, and neither should sit
       in a white or black box.
     - Nutrition app bar should now have a barcode action next to Add Food.
  4. If any icon still looks wrong, check for its <name>.orig.png next
     to it -- that's the untouched original, safe to compare against
     or restore from.

Not in this patch: a layout/navigation redesign of any screen. Say
which screen and what should change and that's a separate, focused
pass -- doing it blind here would risk the screens that already work.
""")


if __name__ == "__main__":
    main()
