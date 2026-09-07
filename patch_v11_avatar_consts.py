#!/usr/bin/env python3
"""
patch_v11_avatar_consts.py

Fixes build failure:
  lib/features/profile/profile_screen.dart:100:25:
  Error: The getter 'kAvatarSisters' isn't defined for the type 'ProfileScreen'.
  Error: The getter 'kAvatarBrothers' isn't defined for the type 'ProfileScreen'.

Strategy:
  1. Search the whole lib/ tree for any existing definition of kAvatarSisters /
     kAvatarBrothers (const, final, or getter). If found elsewhere, just add
     the missing import to profile_screen.dart.
  2. If not found anywhere, define them as top-level const lists directly in
     profile_screen.dart (placeholder asset paths — you'll want to swap these
     for your real avatar asset lists).
  3. Idempotent: stamps itself so re-running is a no-op.
  4. Commits and pushes at the end, per usual workflow.

Run from the repo root in Termux:
  cd ~/Halalcalorie
  python3 patch_v11_avatar_consts.py
"""

import os
import re
import subprocess
import sys

REPO_ROOT = os.getcwd()
STAMP_FILE = os.path.join(REPO_ROOT, ".patch_v11_avatar_consts.stamp")
TARGET_REL = "lib/features/profile/profile_screen.dart"
TARGET = os.path.join(REPO_ROOT, TARGET_REL)

CONST_NAMES = ["kAvatarSisters", "kAvatarBrothers"]

PLACEHOLDER_BLOCK = """
// TODO: replace these placeholder paths with your real avatar asset lists.
// Added automatically by patch_v11_avatar_consts.py because no existing
// definition of kAvatarSisters/kAvatarBrothers was found in lib/.
const List<String> kAvatarSisters = [
  'assets/avatars/sisters/avatar_1.png',
  'assets/avatars/sisters/avatar_2.png',
  'assets/avatars/sisters/avatar_3.png',
];

const List<String> kAvatarBrothers = [
  'assets/avatars/brothers/avatar_1.png',
  'assets/avatars/brothers/avatar_2.png',
  'assets/avatars/brothers/avatar_3.png',
];
"""


def die(msg):
    print(f"[patch_v11] ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def sh(cmd, check=True):
    print(f"[patch_v11] $ {cmd}")
    result = subprocess.run(cmd, shell=True, cwd=REPO_ROOT)
    if check and result.returncode != 0:
        die(f"command failed: {cmd}")
    return result.returncode


def find_existing_definitions():
    """Search lib/ for any file (other than the target) that already defines
    kAvatarSisters or kAvatarBrothers. Returns dict name -> (filepath, rel_import)."""
    found = {}
    lib_dir = os.path.join(REPO_ROOT, "lib")
    if not os.path.isdir(lib_dir):
        return found

    def_pattern = re.compile(
        r"\b(const|final|static\s+const|List<[^>]*>)\s+.*\b(kAvatarSisters|kAvatarBrothers)\b"
    )
    getter_pattern = re.compile(r"\bget\s+(kAvatarSisters|kAvatarBrothers)\b")

    for dirpath, _, filenames in os.walk(lib_dir):
        for fn in filenames:
            if not fn.endswith(".dart"):
                continue
            fpath = os.path.join(dirpath, fn)
            if os.path.abspath(fpath) == os.path.abspath(TARGET):
                continue
            try:
                with open(fpath, "r", encoding="utf-8") as f:
                    content = f.read()
            except (UnicodeDecodeError, OSError):
                continue
            for m in def_pattern.finditer(content):
                name = m.group(2)
                found.setdefault(name, fpath)
            for m in getter_pattern.finditer(content):
                name = m.group(1)
                found.setdefault(name, fpath)
    return found


def rel_import_for(fpath):
    rel = os.path.relpath(fpath, os.path.join(REPO_ROOT, "lib"))
    return "package:halalcalorie/" + rel.replace(os.sep, "/")


def apply_fix(rel_path, label, old, new, content_holder):
    """Anchor-based string replace, matching the repo's usual convention."""
    if old not in content_holder[0]:
        print(f"[patch_v11] SKIP ({label}): anchor not found in {rel_path} — "
              f"may already be applied or file differs from expected shape.")
        return False
    content_holder[0] = content_holder[0].replace(old, new, 1)
    print(f"[patch_v11] APPLIED: {label}")
    return True


def main():
    if os.path.exists(STAMP_FILE):
        print("[patch_v11] Already applied (stamp file present). Nothing to do.")
        return

    if not os.path.isfile(TARGET):
        die(f"expected file not found: {TARGET_REL}")

    with open(TARGET, "r", encoding="utf-8") as f:
        original = f.read()
    content = [original]

    # Already fine?
    if all(name in original for name in CONST_NAMES):
        print("[patch_v11] Constants already referenced/defined in target file. "
              "Checking if this is a real definition vs just usage...")

    existing = find_existing_definitions()

    if len(existing) == 2:
        # Both found elsewhere -> just import
        import_paths = sorted(set(rel_import_for(p) for p in existing.values()))
        for imp in import_paths:
            import_line = f"import '{imp}';\n"
            if import_line not in content[0]:
                # Insert after the last existing import line
                import_matches = list(re.finditer(r"^import .*;\n", content[0], re.MULTILINE))
                if import_matches:
                    insert_at = import_matches[-1].end()
                    content[0] = content[0][:insert_at] + import_line + content[0][insert_at:]
                else:
                    content[0] = import_line + content[0]
                print(f"[patch_v11] Added import: {imp}")
        source_desc = f"existing definitions found in: {', '.join(sorted(set(existing.values())))}"
    else:
        # Define inline in the target file, right after the last import line.
        import_matches = list(re.finditer(r"^import .*;\n", content[0], re.MULTILINE))
        if import_matches:
            insert_at = import_matches[-1].end()
        else:
            insert_at = 0
        if "kAvatarSisters" not in content[0] or "kAvatarBrothers" not in content[0] \
                or (len(existing) < 2):
            content[0] = content[0][:insert_at] + PLACEHOLDER_BLOCK + content[0][insert_at:]
            print("[patch_v11] Inserted placeholder const definitions "
                  "(no existing definitions found elsewhere in lib/).")
        source_desc = "no existing definitions found — inserted placeholders"

    if content[0] == original:
        print("[patch_v11] No changes made — file may already be fixed.")
    else:
        with open(TARGET, "w", encoding="utf-8") as f:
            f.write(content[0])
        print(f"[patch_v11] Wrote changes to {TARGET_REL} ({source_desc})")

    # Stamp
    with open(STAMP_FILE, "w") as f:
        f.write("applied\n")

    # Git commit/push per usual workflow
    sh("git add -A")
    commit_rc = sh(
        'git commit -m "fix: define missing kAvatarSisters/kAvatarBrothers avatar '
        'constants (build fix)"',
        check=False,
    )
    if commit_rc != 0:
        print("[patch_v11] Nothing to commit (working tree may already be clean).")
    else:
        sh("git push")

    print("[patch_v11] Done. Re-run your build.")


if __name__ == "__main__":
    main()
