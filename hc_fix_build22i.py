
import sys
errors = []

def patch(fpath, old, new, label):
    with open(fpath, "r", encoding="utf-8") as f:
        src = f.read()
    n = src.count(old)
    if n == 0:
        errors.append(f"[{label}] anchor not found in {fpath}")
        return
    if n > 1:
        errors.append(f"[{label}] anchor not unique ({n}x) in {fpath}")
        return
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(src.replace(old, new, 1))
    print(f"  [+] {label}")

HS = "lib/features/home/home_screen.dart"

with open(HS, "r", encoding="utf-8") as f:
    src = f.read()

print("\n── _CalRing: add isRamadan field + constructor param ────")

# Only patch field if not already there
if "final bool isAr, isDark, isRamadan;" in src:
    print("  [=] _CalRing isRamadan field already present (skip)")
else:
    patch(HS,
        "final bool isAr, isDark;\n"
        "final String lang;",
        "final bool isAr, isDark, isRamadan;\n"
        "final String lang;",
        "_CalRing: add isRamadan field")

# Reload after possible change
with open(HS, "r", encoding="utf-8") as f:
    src = f.read()

# Only patch constructor if not already there
if "required this.isRamadan, required this.lang," in src:
    print("  [=] _CalRing constructor isRamadan already present (skip)")
else:
    patch(HS,
        "required this.ringAnim, required this.isAr, required this.isDark,\n"
        "required this.lang,",
        "required this.ringAnim, required this.isAr, required this.isDark,\n"
        "required this.isRamadan, required this.lang,",
        "_CalRing: add isRamadan to constructor")

print("")
if errors:
    print("ERRORS:")
    for e in errors:
        print(f"  !! {e}")
    sys.exit(1)
else:
    print("All patches applied OK")
