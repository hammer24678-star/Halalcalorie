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
        print(f"[FAIL] {tag}: anchor not unique ({src.count(old)}x)"); return False
    p.write_text(src.replace(old, new), encoding="utf-8")
    print(f"[OK]   {tag}")
    return True

NS = "lib/features/nutrition/nutrition_screen.dart"

patch(NS,
    old="""  'حبة سوداء':  ('🌱', 'فضل ديني (وليس بديلاً عن الطب) — النبي ﷺ', 'Spiritual significance (not medical advice) — Prophet ﷺ'),
  'black seed':   ('🌱', 'فضل ديني (وليس بديلاً عن الطب) — النبي ﷺ', 'Spiritual significance (not medical advice) — Prophet ﷺ'),""",
    new="""  'حبة سوداء':  ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ (نص ديني، وليس نصيحة طبية)', 'Cure for every disease — Prophet ﷺ (religious text, not medical advice)'),
  'black seed':   ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ (نص ديني، وليس نصيحة طبية)', 'Cure for every disease — Prophet ﷺ (religious text, not medical advice)'),""",
    tag="nutrition: restore black seed hadith + add religious-context tag")

patch(NS,
    old="""  'عسل':          ('🍯', 'فضل ديني (وليس بديلاً عن الطب) — القرآن الكريم', 'Spiritual significance (not medical advice) — Quran'),
  'honey':        ('🍯', 'فضل ديني (وليس بديلاً عن الطب) — القرآن الكريم', 'Spiritual significance (not medical advice) — Quran'),""",
    new="""  'عسل':          ('🍯', 'فيه شفاء للناس — القرآن الكريم (نص ديني، وليس نصيحة طبية)', 'In it is healing for people — Quran (religious text, not medical advice)'),
  'honey':        ('🍯', 'فيه شفاء للناس — القرآن الكريم (نص ديني، وليس نصيحة طبية)', 'In it is healing for people — Quran (religious text, not medical advice)'),""",
    tag="nutrition: restore honey ayah + add religious-context tag")

print("\nDone.")
