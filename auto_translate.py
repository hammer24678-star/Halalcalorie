#!/usr/bin/env python3
"""
auto_translate.py — HalalCalorie build 78
Extracts all isAr ? 'arabic' : 'english' pairs from Dart files,
translates to FR/TR/UR/MS/ID via Groq, replaces with tLang() calls.
"""
import re, json, time, urllib.request, urllib.error, sys, os

GROQ_KEY  = "GROQ_API_KEY_REMOVED"
MODEL     = "llama-3.1-8b-instant"
ENDPOINT  = "https://api.groq.com/openai/v1/chat/completions"

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

# Pattern: isAr ? 'arabic text' : 'english text'
PATTERN = re.compile(r"isAr\s*\?\s*'([^']+)'\s*:\s*'([^']+)'")

def groq_translate(pairs):
    """Send a batch of (ar, en) pairs to Groq, get FR/TR/UR/MS/ID back."""
    prompt = """You are a professional translator for a Muslim halal food & fitness app.
Translate each item to French (fr), Turkish (tr), Urdu (ur), Malay (ms), and Indonesian (id).
Keep translations natural, short, and suitable for a mobile app UI.
For Islamic terms (Bismillah, Barakah, Sunnah, Halal, Haram etc) keep them as-is or use the standard local form.
Return ONLY a JSON array, no markdown, no extra text.
Each element: {"ar":"...","en":"...","fr":"...","tr":"...","ur":"...","ms":"...","id":"..."}

Items to translate:
""" + json.dumps([{"ar": a, "en": e} for a, e in pairs], ensure_ascii=False)

    body = json.dumps({
        "model": MODEL,
        "max_tokens": 4000,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
    }).encode()

    req = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {GROQ_KEY}",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            data = json.loads(r.read())
            text = data["choices"][0]["message"]["content"]
            # Strip markdown if present
            text = re.sub(r"```json|```", "", text).strip()
            return json.loads(text)
    except Exception as e:
        print(f"  [!] Groq error: {e}")
        return None

def process_file(path, translations):
    """Replace isAr ? 'ar' : 'en' with tLang(lang, 'ar','en','fr','tr','ms','id') in file."""
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    original = src
    count = 0

    for match in PATTERN.finditer(original):
        ar_text = match.group(1)
        en_text = match.group(2)
        key = (ar_text, en_text)

        if key not in translations:
            continue

        t = translations[key]
        fr = t.get("fr", en_text).replace("'", "\\'")
        tr = t.get("tr", en_text).replace("'", "\\'")
        ur = t.get("ur", ar_text).replace("'", "\\'")
        ms = t.get("ms", en_text).replace("'", "\\'")
        id_ = t.get("id", en_text).replace("'", "\\'")
        ar  = ar_text.replace("'", "\\'")
        en  = en_text.replace("'", "\\'")

        old = match.group(0)
        new = f"tLang(lang, '{ar}', '{en}', '{fr}', '{tr}', '{ms}', '{id_}')"

        src = src.replace(old, new, 1)
        count += 1

    # Make sure tLang and lang are available in files that use them
    # Add lang variable if not present
    if count > 0 and "tLang(lang," in src:
        # Check if lang is declared
        if "final lang" not in src and "var lang" not in src:
            # Add lang read after common ref.watch patterns
            src = src.replace(
                "final isAr",
                "final lang = ref.watch(languageProvider); final isAr",
                1
            )

    if src != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(src)
        print(f"  [+] {path.split('/')[-1]}: {count} strings replaced")
    else:
        print(f"  [~] {path.split('/')[-1]}: no changes")

    return count

def main():
    print("=" * 55)
    print("  HalalCalorie Auto-Translator")
    print("  Extracting strings from all screens...")
    print("=" * 55)

    # Step 1: collect all unique (ar, en) pairs
    all_pairs = set()
    for path in TARGET_FILES:
        if not os.path.exists(path):
            print(f"  [~] {path} not found — skipping")
            continue
        with open(path, "r", encoding="utf-8") as f:
            src = f.read()
        for m in PATTERN.finditer(src):
            all_pairs.add((m.group(1), m.group(2)))

    pairs_list = list(all_pairs)
    print(f"\n  Found {len(pairs_list)} unique string pairs")

    # Step 2: translate in batches of 20
    translations = {}
    batch_size = 20
    total_batches = (len(pairs_list) + batch_size - 1) // batch_size

    for i in range(0, len(pairs_list), batch_size):
        batch = pairs_list[i:i+batch_size]
        batch_num = i // batch_size + 1
        print(f"\n  Translating batch {batch_num}/{total_batches} ({len(batch)} strings)...")

        result = groq_translate(batch)
        if result is None:
            print("  [!] Batch failed — using English fallback for this batch")
            for ar, en in batch:
                translations[(ar, en)] = {"fr": en, "tr": en, "ur": ar, "ms": en, "id": en}
            continue

        for item in result:
            ar = item.get("ar", "")
            en = item.get("en", "")
            if ar and en:
                translations[(ar, en)] = item
                print(f"    ✓ {en[:40]}")

        # Respect rate limit — 30 RPM = 1 per 2 seconds
        if batch_num < total_batches:
            print("  [~] Waiting 3s for rate limit...")
            time.sleep(3)

    print(f"\n  Translated {len(translations)} pairs")

    # Step 3: apply to all files
    print("\n  Applying translations to source files...")
    total = 0
    for path in TARGET_FILES:
        if os.path.exists(path):
            total += process_file(path, translations)

    print(f"\n  Done — {total} strings replaced across {len(TARGET_FILES)} files")
    print("\n  Now run: git add -A && git commit -m 'feat: full 7-lang translations (#build78)' && git push origin master")

if __name__ == "__main__":
    main()
