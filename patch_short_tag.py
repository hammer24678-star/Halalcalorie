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
    old="""  'حبة سوداء':  ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ (نص ديني، وليس نصيحة طبية)', 'Cure for every disease — Prophet ﷺ (religious text, not medical advice)'),
  'black seed':   ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ (نص ديني، وليس نصيحة طبية)', 'Cure for every disease — Prophet ﷺ (religious text, not medical advice)'),""",
    new="""  'حبة سوداء':  ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ (نص ديني)', 'Cure for every disease — Prophet ﷺ (religious text)'),
  'black seed':   ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ (نص ديني)', 'Cure for every disease — Prophet ﷺ (religious text)'),""",
    tag="nutrition: shorten black seed tag to نص ديني")

patch(NS,
    old="""  'عسل':          ('🍯', 'فيه شفاء للناس — القرآن الكريم (نص ديني، وليس نصيحة طبية)', 'In it is healing for people — Quran (religious text, not medical advice)'),
  'honey':        ('🍯', 'فيه شفاء للناس — القرآن الكريم (نص ديني، وليس نصيحة طبية)', 'In it is healing for people — Quran (religious text, not medical advice)'),""",
    new="""  'عسل':          ('🍯', 'فيه شفاء للناس — القرآن الكريم (نص ديني)', 'In it is healing for people — Quran (religious text)'),
  'honey':        ('🍯', 'فيه شفاء للناس — القرآن الكريم (نص ديني)', 'In it is healing for people — Quran (religious text)'),""",
    tag="nutrition: shorten honey tag to نص ديني")

print("\nDone.")
