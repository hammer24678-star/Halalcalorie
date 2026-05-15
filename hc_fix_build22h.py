
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

# Fix 1: use ringAnim line as unique context to target _CalRing only
patch(HS,
    "ringAnim: _ringVal,\n"
    "isAr: isAr, isDark: isDark, lang: lang,",
    "ringAnim: _ringVal,\n"
    "isAr: isAr, isDark: isDark, isRamadan: isRamadan, lang: lang,",
    "home: pass isRamadan to _CalRing")

# Fix 2: Prophet hint bg — include 8-space indentation
patch(HS,
    "        color: AppColors.sunnahGreen.withOpacity(0.07),\n"
    "        borderRadius: BorderRadius.circular(10),",
    "        color: (isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.07),\n"
    "        borderRadius: BorderRadius.circular(10),",
    "home: _CalRing Prophet hint bg Ramadan gold")

# Fix 3: Prophet hint border — include correct indentation
patch(HS,
    "        border: Border.all(\n"
    "            color: AppColors.sunnahGreen.withOpacity(0.2)),",
    "        border: Border.all(\n"
    "            color: (isRamadan ? AppColors.barakahGold : AppColors.sunnahGreen).withOpacity(0.2)),",
    "home: _CalRing Prophet hint border Ramadan gold")

print("")
if errors:
    print("ERRORS:")
    for e in errors:
        print(f"  !! {e}")
    sys.exit(1)
else:
    print("All patches applied OK")
