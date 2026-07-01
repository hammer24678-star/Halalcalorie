#!/data/data/com.termux/files/usr/bin/bash
# fix_foreground_permission_and_bump.sh
# 1. Removes FOREGROUND_SERVICE / FOREGROUND_SERVICE_HEALTH from
#    patch_android.py's permission list (unused — no real foreground
#    service exists in the app, avoids Play's justification/video review).
# 2. Strips the same two permissions from the already-generated
#    AndroidManifest.xml if present (in case a previous patch run baked
#    them in already).
# 3. Bumps pubspec.yaml version from 1.0.0+6 -> 1.0.0+7.
#
# Usage:
#   cd ~/hc_fix_build   # adjust path to your repo checkout
#   bash fix_foreground_permission_and_bump.sh

set -euo pipefail

PATCH_FILE="patch_android.py"
MANIFEST="android/app/src/main/AndroidManifest.xml"
PUBSPEC="pubspec.yaml"

echo "== Step 1: Removing FOREGROUND_SERVICE permissions from $PATCH_FILE =="
if [ -f "$PATCH_FILE" ]; then
  cp "$PATCH_FILE" "$PATCH_FILE.bak"

  python3 - "$PATCH_FILE" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    src = f.read()

# Remove the two tuple entries (and the preceding comment line) for
# FOREGROUND_SERVICE and FOREGROUND_SERVICE_HEALTH from the `needed` list.
pattern = re.compile(
    r'[ \t]*#\s*Foreground service \(workout timer\)\n'
    r'[ \t]*\(\'FOREGROUND_SERVICE"\',\n'
    r'[ \t]*\'    <uses-permission android:name="android\.permission\.FOREGROUND_SERVICE" />\'\),\n'
    r'[ \t]*\(\'FOREGROUND_SERVICE_HEALTH\',\n'
    r'[ \t]*\'    <uses-permission android:name="android\.permission\.FOREGROUND_SERVICE_HEALTH" />\'\),\n'
)

new_src, n = pattern.subn('', src)

if n == 0:
    print(f"WARNING: pattern not found in {path} — no changes made (check manually)")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(new_src)
    print(f"OK: removed FOREGROUND_SERVICE / FOREGROUND_SERVICE_HEALTH block ({n} match) from {path}")
PYEOF

else
  echo "SKIP: $PATCH_FILE not found in $(pwd)"
fi

echo ""
echo "== Step 2: Stripping permissions from existing $MANIFEST (if present) =="
if [ -f "$MANIFEST" ]; then
  cp "$MANIFEST" "$MANIFEST.bak"
  sed -i '/android:name="android\.permission\.FOREGROUND_SERVICE"/d' "$MANIFEST"
  sed -i '/android:name="android\.permission\.FOREGROUND_SERVICE_HEALTH"/d' "$MANIFEST"
  echo "OK: stripped from $MANIFEST (backup at $MANIFEST.bak)"
  echo "-- remaining FOREGROUND_SERVICE references (should be none) --"
  grep -n "FOREGROUND_SERVICE" "$MANIFEST" || echo "none found — clean"
else
  echo "SKIP: $MANIFEST not found (fine — patch_android.py regenerates it on next build without the permission now)"
fi

echo ""
echo "== Step 3: Bumping version in $PUBSPEC =="
if [ -f "$PUBSPEC" ]; then
  cp "$PUBSPEC" "$PUBSPEC.bak"

  CURRENT_LINE=$(grep -E "^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\s*$" "$PUBSPEC" || true)
  if [ -z "$CURRENT_LINE" ]; then
    echo "ERROR: couldn't find 'version: X.Y.Z+N' line in $PUBSPEC — bump it manually."
  else
    NAME=$(echo "$CURRENT_LINE" | sed -E 's/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$/\1/')
    CODE=$(echo "$CURRENT_LINE" | sed -E 's/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$/\2/')
    NEW_CODE=$((CODE + 1))
    sed -i -E "s/^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+\s*$/version: ${NAME}+${NEW_CODE}/" "$PUBSPEC"
    echo "OK: version bumped ${NAME}+${CODE} -> ${NAME}+${NEW_CODE}"
  fi
else
  echo "SKIP: $PUBSPEC not found in $(pwd)"
fi

echo ""
echo "== Done. Backups saved as *.bak next to each modified file. =="
echo "Next steps:"
echo "  1. git add -A"
echo "  2. git commit -m 'Remove unused FOREGROUND_SERVICE_HEALTH permission, bump build to +7'"
echo "  3. git push"
echo "  4. Trigger CI build, upload the new AAB as the release artifact."
echo "     The permissions-justification screen should no longer appear"
echo "     since the manifest will no longer declare FOREGROUND_SERVICE_HEALTH."
