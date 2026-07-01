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

BP = "lib/features/body/body_photo_screen.dart"
patch(BP,
    old="""            ? '• صورتك تُرسل بأمان إلى Claude AI للتحليل فقط\\n'""",
    new="""            ? '• صورتك تُرسل بأمان للتحليل فقط\\n'""",
    tag="body_photo: remove 'Claude AI' (AR)")
patch(BP,
    old="""            : '• Your photo is securely sent to Claude AI for analysis only\\n'""",
    new="""            : '• Your photo is securely sent for analysis only\\n'""",
    tag="body_photo: remove 'Claude AI' (EN)")

NS = "lib/features/nutrition/nutrition_screen.dart"
patch(NS,
    old="""  'حبة سوداء':  ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ', 'Cure for every disease — Prophet ﷺ'),
  'black seed':   ('🌱', 'شفاء من كل داء إلا السام — النبي ﷺ', 'Cure for every disease — Prophet ﷺ'),""",
    new="""  'حبة سوداء':  ('🌱', 'فضل ديني (وليس بديلاً عن الطب) — النبي ﷺ', 'Spiritual significance (not medical advice) — Prophet ﷺ'),
  'black seed':   ('🌱', 'فضل ديني (وليس بديلاً عن الطب) — النبي ﷺ', 'Spiritual significance (not medical advice) — Prophet ﷺ'),""",
    tag="nutrition: soften black seed claim")

patch(NS,
    old="""  'عسل':          ('🍯', 'فيه شفاء للناس — القرآن الكريم', 'In it is healing for people — Quran'),
  'honey':        ('🍯', 'فيه شفاء للناس — القرآن الكريم', 'In it is healing for people — Quran'),""",
    new="""  'عسل':          ('🍯', 'فضل ديني (وليس بديلاً عن الطب) — القرآن الكريم', 'Spiritual significance (not medical advice) — Quran'),
  'honey':        ('🍯', 'فضل ديني (وليس بديلاً عن الطب) — القرآن الكريم', 'Spiritual significance (not medical advice) — Quran'),""",
    tag="nutrition: soften honey claim")

print("\nDone.")
