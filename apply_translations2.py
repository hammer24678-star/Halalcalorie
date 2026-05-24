#!/usr/bin/env python3
# apply_translations.py — HalalCalorie build 79
# Loads translations from translations.json and applies to all dart files
import re, json, os

script_dir = os.path.dirname(os.path.abspath(__file__))
json_path  = os.path.join(script_dir, "translations.json")

with open(json_path, "r", encoding="utf-8") as f:
    TRANSLATIONS = json.load(f)

TARGET_FILES = [
    "lib/core/notification_service.dart",
    "lib/features/body/body_photo_screen.dart",
    "lib/features/body/body_screen.dart",
    "lib/features/health/health_screen.dart",
    "lib/features/home/home_screen.dart",
    "lib/features/nutrition/nutrition_screen.dart",
    "lib/features/onboarding/onboarding_screen.dart",
    "lib/features/paywall/paywall_screen.dart",
    "lib/features/profile/profile_screen.dart",
    "lib/features/scanner/food_photo_screen.dart",
    "lib/features/scanner/scanner_screen.dart",
    "lib/features/settings/donation_card.dart",
    "lib/features/settings/settings_screen.dart",
    "lib/features/barakah/barakah_screen.dart",
]

PATTERN = re.compile(
    r"tLang\(lang,\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'\)"
)

def esc(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")

total = 0
for path in TARGET_FILES:
    if not os.path.exists(path):
        print(f"  [~] {path} not found")
        continue

    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    original = src
    count    = 0

    for m in PATTERN.finditer(original):
        en_raw = m.group(2)
        t = TRANSLATIONS.get(en_raw)
        if not t:
            continue

        ar_raw = m.group(1)
        fr_new = esc(t.get("fr", en_raw))
        tr_new = esc(t.get("tr", en_raw))
        ms_new = esc(t.get("ms", en_raw))
        id_new = esc(t.get("id", en_raw))

        old = m.group(0)
        new = f"tLang(lang, '{esc(ar_raw)}', '{esc(en_raw)}', '{fr_new}', '{tr_new}', '{ms_new}', '{id_new}')"

        if old != new:
            src = src.replace(old, new, 1)
            count += 1

    if src != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(src)
        print(f"  [+] {path.split('/')[-1]}: {count} translations applied")
        total += count
    else:
        print(f"  [~] {path.split('/')[-1]}: no changes")

print(f"\n  Total: {total} strings updated with real translations")
