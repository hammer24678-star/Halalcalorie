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
        print(f"[FAIL] {tag}: anchor not unique ({src.count(old)}x) in {path} — fix manually"); return False
    p.write_text(src.replace(old, new), encoding="utf-8")
    print(f"[OK]   {tag}")
    return True

RC = "lib/core/revenuecat_service.dart"
PW = "lib/features/paywall/paywall_screen.dart"

patch(RC,
    old="""        bool   isYearly = id.contains('annual') || id.contains('yearly');
        bool   isLife   = id.contains('lifetime');
        result.add(RCOffering(""",
    new="""        bool   isYearly = id.contains('annual') || id.contains('yearly');
        bool   isLife   = id.contains('lifetime');
        if (isLife) continue; // CAP: lifetime tier removed — unlimited AI cost risk
        result.add(RCOffering(""",
    tag="getOfferings(): skip lifetime packages")

patch(RC,
    old="""    RCOffering(
      identifier:  RCProducts.lifetime,
      titleAr: 'مدى الحياة', titleEn: 'Lifetime',
      priceString: 'EGP 1,999',
      periodAr: 'مرة واحدة', periodEn: 'one-time',
    ),
  ];""",
    new="""  ];""",
    tag="_localStubOfferings(): remove lifetime entry")

patch(PW,
    old="""    _FP(tLang(lang, 'مدى الحياة', 'Lifetime', 'À vie', 'Ömür boyu', 'Seumur Hidup', 'Seumur Hidup'), tLang(lang, '٤٩.٩٩ \\$', '\\$49.99', '\\$49.99', '\\$49.99', '\\$49.99', '\\$49.99'), tLang(lang, 'مرة واحدة', 'one-time', 'unique', 'tek seferlik', 'sekali sahaja', 'sekali bayar'), false, null),
""",
    new="",
    tag="_fallback(): remove lifetime entry")

print("\nDone. Now: flutter analyze, then your usual build command.")
