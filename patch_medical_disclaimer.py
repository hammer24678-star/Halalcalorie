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

H = "lib/features/home/home_screen.dart"

# 1. Inject disclaimer widget before the SliverChildListDelegate closes
patch(H,
    old="""if (needsPush) context.push(r); else context.go(r);
},
)),

])),
),
],
),
);
}
}""",
    new="""if (needsPush) context.push(r); else context.go(r);
},
)),

// ── MEDICAL DISCLAIMER ──────────────────────────────
_MedDisclaimer(isAr: isAr),

])),
),
],
),
);
}
}

// ════════════════════════════════════════════════════════════
// MEDICAL DISCLAIMER — required by Google Play Health policy
// ════════════════════════════════════════════════════════════
class _MedDisclaimer extends StatelessWidget {
  final bool isAr;
  const _MedDisclaimer({required this.isAr});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF30363D), width: 0.5),
      ),
      child: Text(
        isAr
          ? '⚕️ هذا التطبيق لأغراض المعلومات العامة فقط وليس بديلاً عن الاستشارة الطبية المتخصصة. استشر طبيبك أو أخصائياً معتمداً قبل اتخاذ أي قرارات صحية.'
          : '⚕️ This app is for general informational purposes only and is not a substitute for professional medical advice, diagnosis or treatment. Always consult a qualified healthcare professional before making health decisions.',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 10.5,
          color: Color(0xFF8B949E),
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}""",
    tag="home_screen: inject _MedDisclaimer widget")

print("\nDone.")
