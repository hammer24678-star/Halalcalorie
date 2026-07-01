#!/usr/bin/env python3
import pathlib

def patch(path, old, new, tag):
    p = pathlib.Path(path)
    if not p.exists():
        print(f"[SKIP] {tag}: {path} not found"); return False
    src = p.read_text(encoding="utf-8")
    if old not in src:
        if new and new in src:
            print(f"[SKIP] {tag}: already applied"); return True
        print(f"[FAIL] {tag}: anchor not found in {path}"); return False
    if src.count(old) != 1:
        print(f"[FAIL] {tag}: anchor not unique ({src.count(old)}x) in {path}"); return False
    p.write_text(src.replace(old, new), encoding="utf-8")
    print(f"[OK]   {tag}")
    return True

PA = "patch_android.py"

# 1. Stop self-injecting READ_MEDIA_IMAGES
patch(PA,
    old="""        # Media (Android 13+)
        ('READ_MEDIA_IMAGES',
         '    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />'),
        # Pedometer / health""",
    new="""        # Pedometer / health""",
    tag="needed[]: remove self-injected READ_MEDIA_IMAGES")

# 2. After the existing manifest patch block, explicitly strip both
#    READ_MEDIA_IMAGES and READ_MEDIA_VIDEO via tools:node="remove" so
#    permission_handler's bundled manifest can't merge them back in.
patch(PA,
    old="""else:
    print("WARNING: AndroidManifest.xml not found — run after flutter create")

# ── Kotlin version upgrade (required by purchases_flutter v8) ─────────""",
    new="""else:
    print("WARNING: AndroidManifest.xml not found — run after flutter create")

# ── Strip READ_MEDIA_IMAGES / READ_MEDIA_VIDEO merged in by plugins ────
# permission_handler bundles these in its own AAR manifest for every
# permission group it supports, regardless of whether Dart code actually
# requests them. Play flags this as invalid use of photo/video permissions
# since this app only does occasional one-shot photo picks via
# image_picker's system picker — it never needs broad media-library access.
if os.path.exists(manifest_path):
    with open(manifest_path, "r") as f: manifest = f.read()
    changed = False

    if 'xmlns:tools=' not in manifest:
        manifest = manifest.replace(
            'xmlns:android="http://schemas.android.com/apk/res/android"',
            'xmlns:android="http://schemas.android.com/apk/res/android"\\n    xmlns:tools="http://schemas.android.com/tools"',
            1
        )
        changed = True

    for perm in ['READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO']:
        full_name = f'android.permission.{perm}'
        if full_name not in manifest:
            line = f'    <uses-permission android:name="{full_name}" tools:node="remove" />'
            manifest = manifest.replace('<application', line + '\\n    <application', 1)
            changed = True

    if changed:
        with open(manifest_path, 'w') as f: f.write(manifest)
        print('AndroidManifest: stripped READ_MEDIA_IMAGES/VIDEO via tools:node=remove')
    else:
        print('AndroidManifest: media-permission removal already present')

# ── Kotlin version upgrade (required by purchases_flutter v8) ─────────""",
    tag="manifest: add tools:node=remove for READ_MEDIA_IMAGES/VIDEO")

print("\nDone. Commit, push, let CI rebuild, then re-upload the new .aab.")
