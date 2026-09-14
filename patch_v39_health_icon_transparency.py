#!/usr/bin/env python3
"""
patch_v39_health_icon_transparency.py

Fixes: Health > Articles icon tiles show a solid white square behind
every glyph (water drop, moon, heart, brain, bone, salad bowl...),
in BOTH light and dark mode. This isn't the darkSafeAsset plate
(PATCH_V30/35) -- it's the PNGs themselves: assets/icons/health/*.png
were exported with an opaque white (or, for a couple, near-black)
matte instead of real alpha transparency.

This patch does NOT touch any .dart source. It rewrites the PNG
bytes in place: flood-fills the background from each of the four
corners (per-file, using that file's own corner colour so it works
for both white- and black-matted icons) and sets those pixels'
alpha to 0, with a short feathered ramp at the boundary so you don't
get a hard cutout ring or a light/dark fringe.

Originals are backed up to assets/icons/health/_pre_v39_backup/
before anything is overwritten, so this is safe to re-run.

Requires Pillow:
    pip install pillow
    # Termux, if that fails:
    pip install pillow --break-system-packages

Run from the repo root:
    python3 patch_v39_health_icon_transparency.py
"""

import os
import sys
import shutil
from collections import deque

try:
    from PIL import Image
except ImportError:
    sys.exit(
        "Pillow is required.\n"
        "  pip install pillow\n"
        "  (Termux fallback: pip install pillow --break-system-packages)"
    )

ICON_DIR = os.path.join("assets", "icons", "health")
BACKUP_DIR = os.path.join(ICON_DIR, "_pre_v39_backup")

# How close a pixel's colour has to be to the sampled corner colour
# to be treated as "definitely background" (hard transparent).
BG_TOLERANCE = 30
# Pixels further than BG_TOLERANCE but within BG_TOLERANCE + FEATHER
# of the corner colour get a proportionally scaled-down alpha instead
# of a hard 0/255 cut -- this kills the light/dark fringe that a hard
# cutout leaves against a coloured app background.
FEATHER = 26


def color_dist(a, b):
    return sum((ac - bc) ** 2 for ac, bc in zip(a, b)) ** 0.5


def flood_fill_transparent(img):
    """Return a new RGBA image with the corner-connected background
    matte flood-filled to transparent, edges feathered."""
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    visited = bytearray(w * h)
    alpha_scale = [1.0] * (w * h)  # 1.0 = untouched, 0.0 = fully cleared

    for cx, cy in corners:
        bg_color = px[cx, cy][:3]
        q = deque([(cx, cy)])
        idx0 = cy * w + cx
        if visited[idx0]:
            continue
        while q:
            x, y = q.popleft()
            idx = y * w + x
            if visited[idx]:
                continue
            r, g, b, a = px[x, y]
            dist = color_dist((r, g, b), bg_color)
            if dist <= BG_TOLERANCE:
                visited[idx] = 1
                alpha_scale[idx] = 0.0
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx]:
                        q.append((nx, ny))
            elif dist <= BG_TOLERANCE + FEATHER:
                # Boundary pixel: don't flood through it (so we don't eat
                # into the glyph itself), but soften its alpha so the
                # matte's edge anti-aliasing doesn't leave a ring.
                visited[idx] = 1
                scale = (dist - BG_TOLERANCE) / FEATHER
                alpha_scale[idx] = min(alpha_scale[idx], scale)
            # else: solid glyph pixel, leave it and don't expand through it

    out = Image.new("RGBA", (w, h))
    opx = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            scale = alpha_scale[y * w + x]
            opx[x, y] = (r, g, b, int(a * scale))
    return out


def main():
    if not os.path.isdir(ICON_DIR):
        sys.exit(f"Can't find {ICON_DIR} -- run this from the repo root.")

    pngs = sorted(f for f in os.listdir(ICON_DIR) if f.lower().endswith(".png"))
    if not pngs:
        sys.exit(f"No .png files in {ICON_DIR}")

    os.makedirs(BACKUP_DIR, exist_ok=True)

    changed = 0
    for name in pngs:
        path = os.path.join(ICON_DIR, name)
        backup_path = os.path.join(BACKUP_DIR, name)
        if not os.path.exists(backup_path):
            shutil.copy2(path, backup_path)

        with Image.open(backup_path) as src:
            result = flood_fill_transparent(src)
            result.save(path, "PNG")
        print(f"  fixed: {name}")
        changed += 1

    print(f"\nDone. {changed} icon(s) processed in {ICON_DIR}")
    print(f"Originals kept in {BACKUP_DIR} (safe to delete once you've checked the app).")


if __name__ == "__main__":
    main()
