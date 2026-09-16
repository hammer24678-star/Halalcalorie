#!/usr/bin/env python3
"""
patch_v40_16kb_page_size_fix.py
================================

Fixes: Play Console pre-launch report blocks Save with
  "Your app does not support 16 KB memory page sizes."
(version code 13, screenshots from Play Console -> App bundle
explorer -> Errors, warnings and messages.)

ROOT CAUSE
----------
compileSdk/targetSdk are already 36, AGP is already pinned to 9.1.0,
and `ndkVersion flutter.ndkVersion` on Flutter 3.44.7 (see
.github/workflows/build.yml) resolves to an NDK well past r27+, so
Flutter's own libflutter.so / libapp.so are already 16 KB-safe.

The actual offender is a *dependency*, not our own build config:
pubspec.yaml pins `mobile_scanner: ^5.0.0`, which bundles
com.google.mlkit:barcode-scanning ~17.0.x and an old CameraX line.
Those ship libbarhopper_v3.so / libimage_processing_util_jni.so with
4 KB ELF LOAD-segment alignment -- this is a well-documented upstream
issue (googlesamples/mlkit#976, #987; mobile_scanner#1488), fixed
upstream in mobile_scanner 6.0.11 ("Update camerax dependencies to
support 16KB page sizes") and the MLKit 17.3.0 bump that shipped
alongside it. `^5.0.0` in pubspec.yaml never resolves past 5.x, so
`flutter pub upgrade` alone can't reach that fix.

Checked the other native-capable deps in pubspec.yaml (sqflite,
image_picker, permission_handler, purchases_flutter, flutter_local_
notifications, accurate_step_counter, connectivity_plus) -- none of
them bundle prebuilt NDK .so files, so mobile_scanner is the one
dependency actually in play here.

THIS PATCH
----------
1. pubspec.yaml
   mobile_scanner ^5.0.0 -> ^6.0.11. Deliberately the last pre-7.0.0
   release, not latest (7.x): the 6.x line has no Android/Dart-API
   breaking changes vs 5.x (checked against every changelog entry
   5.0.0..6.0.11 and against lib/features/scanner/barcode_scanner_
   widget.dart's actual usage -- errorBuilder's 3-arg signature,
   DetectionSpeed, CameraFacing are all untouched), so this is a
   drop-in version bump. 7.0.0 requires reworking errorBuilder/
   placeholderBuilder (Widget arg removed) and other call sites for
   no benefit here.

2. patch_android.py (the generator CI actually runs after
   `flutter create`, since android/ itself isn't committed)
   Added an explicit `packaging { jniLibs { useLegacyPackaging =
   false } }` block to APP_BUILD_GRADLE. minSdk 24 already implies
   this under AGP 8.3+/9.x by default, so this is belt-and-suspenders
   rather than the primary fix -- but it's what actually makes native
   libs land uncompressed and page-aligned *inside the APK/AAB*, which
   is the other half of 16 KB support beyond the .so files themselves
   being compiled with 16 KB segments. Cheap to make explicit instead
   of relying on an implicit AGP default for a Play-blocking check.

Does NOT touch:
- android/settings.gradle's forced Kotlin-plugin-version regex in
  patch_android.py (currently pins 1.9.0 against a comment that's
  stale -- purchases_flutter is on v10.2.3 now, not v8). It disagrees
  with the 2.0.21 used elsewhere in the same generated build, but the
  fact that v39's build reached Play Console at all proves it isn't
  currently a hard Gradle failure, and I can't build-test a change to
  it from here. Flagging it, not touching it blind.
- buildTypes.release (minifyEnabled/shrinkResources are already
  false) -- the "no deobfuscation file" warning in the screenshots is
  a warning, not the blocking error, and doesn't apply while R8 is
  off.

Run from project root. Idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []

PUBSPEC = "pubspec.yaml"
PATCH_ANDROID = "patch_android.py"

PACKAGING_MARKER = "PATCH_V40_16KB_PAGE_SIZE"


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
    print("v40 — 16 KB memory page size (Play Console error, version code 13)")
    print("=" * 70)

    # ── 1. pubspec.yaml: mobile_scanner past the unaligned MLKit build ──
    p = ROOT / PUBSPEC
    if not p.exists():
        _log(f"{PUBSPEC}: file", "SKIPPED-NOT-FOUND")
    else:
        text = p.read_text(encoding="utf-8")
        if "mobile_scanner: ^6." in text or "mobile_scanner: ^7." in text:
            _log("pubspec: mobile_scanner already >=6.x", "SKIPPED-ALREADY")
        else:
            edit(
                PUBSPEC,
                "  mobile_scanner: ^5.0.0\n",
                "  mobile_scanner: ^6.0.11  # 16KB page size: bundles the fixed CameraX/MLKit build\n",
                "pubspec: mobile_scanner 5.0.0 -> 6.0.11",
            )

    # ── 2. patch_android.py: explicit uncompressed/page-aligned native libs ──
    p = ROOT / PATCH_ANDROID
    if not p.exists():
        _log(f"{PATCH_ANDROID}: file", "SKIPPED-NOT-FOUND")
    else:
        text = p.read_text(encoding="utf-8")
        if PACKAGING_MARKER in text:
            _log("patch_android.py: packaging block already present", "SKIPPED-ALREADY")
        else:
            old_block = """    defaultConfig {
        applicationId "com.ihsanstudio.halalcalorie"
        minSdk 24
        targetSdk 36
        versionCode __VERSION_CODE__
        versionName "__VERSION_NAME__"
    }

    signingConfigs {"""
            new_block = f"""    defaultConfig {{
        applicationId "com.ihsanstudio.halalcalorie"
        minSdk 24
        targetSdk 36
        versionCode __VERSION_CODE__
        versionName "__VERSION_NAME__"
    }}

    // {PACKAGING_MARKER}: keep native libs uncompressed + page-aligned in
    // the APK/AAB so Play's 16 KB check passes regardless of AGP's
    // minSdk-based default. minSdk 24 already implies this under
    // AGP 8.3+/9.x, but don't leave a Play-blocking check implicit.
    packaging {{
        jniLibs {{
            useLegacyPackaging = false
        }}
    }}

    signingConfigs {{"""
            if old_block in text:
                text = text.replace(old_block, new_block, 1)
                p.write_text(text, encoding="utf-8")
                _log("patch_android.py: packaging { jniLibs.useLegacyPackaging = false }", "OK")
            else:
                _log("patch_android.py: packaging { jniLibs.useLegacyPackaging = false }", "SKIPPED-NOT-FOUND")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next: flutter pub get, then let CI build and re-upload to Play.
No local Android toolchain needed for this one -- both changes are
source-text edits (pubspec.yaml + the patch_android.py generator);
the actual android/ folder is regenerated by `flutter create` and
patch_android.py on every CI run.

Once the next version code is up, Play Console's pre-launch report
can take a few hours to re-scan -- the 16 KB error banner won't clear
instantly on re-upload.

Flagged but NOT changed (see docstring): the settings.gradle Kotlin
plugin version regex in patch_android.py still forces 1.9.0 against a
stale "purchases_flutter v8" comment, while the rest of the build
uses 2.0.21. Builds are clearly reaching Play fine as-is, so I left
it alone rather than guess at a Gradle change I can't test-build.
""")


if __name__ == "__main__":
    main()
