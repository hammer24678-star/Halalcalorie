#!/usr/bin/env python3
"""
patch_v28_fix_home_isdark_scope.py
===================================

Same bug class as v27's health fix, two more instances of it.

v26's status-glyph rewrites inserted `isDark: isDark` at call sites
inside `_StatState` and `_QTileState` (small helper StatefulWidgets in
home_screen.dart) that have no `isDark` field/getter of their own:

  home_screen.dart:1195 -> _StatState  (statusGlyphForEmoji(widget.emoji)!, width: 18, height: 18)
  home_screen.dart:1548 -> _QTileState (statusGlyphForEmoji(item.emoji)!, width: 20, height: 20)

Fix: compute brightness locally at each call site via
`Theme.of(context).brightness == Brightness.dark` instead of relying
on an out-of-scope `isDark` variable — same approach as the v27 health
fix.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []

MARKER = "PATCH_V28_FIX_HOME_ISDARK_SCOPE"
HOME = "lib/features/home/home_screen.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def fix_one(text, old, label):
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return text, False
    new = old.replace(
        "isDark: isDark,",
        "isDark: Theme.of(context).brightness == Brightness.dark,",
    )
    text = text.replace(old, new, 1)
    _log(label, "OK")
    return text, True


def main():
    print("=" * 70)
    print("v28 — fix isDark out-of-scope in _StatState / _QTileState")
    print("=" * 70)

    p = ROOT / HOME
    if not p.exists():
        _log(f"{HOME}: file", "SKIPPED-NOT-FOUND")
        return
    text = p.read_text(encoding="utf-8")

    if MARKER in text:
        _log("home: isDark scope fix", "SKIPPED-ALREADY")
    else:
        changed_any = False

        text, changed = fix_one(
            text,
            "darkSafeAsset(statusGlyphForEmoji(widget.emoji)!, width: 18, height: 18, isDark: isDark,",
            "home: _StatState isDark scope (statusGlyphForEmoji(widget.emoji)!)",
        )
        changed_any = changed_any or changed

        text, changed = fix_one(
            text,
            "darkSafeAsset(statusGlyphForEmoji(item.emoji)!, width: 20, height: 20, isDark: isDark,",
            "home: _QTileState isDark scope (statusGlyphForEmoji(item.emoji)!)",
        )
        changed_any = changed_any or changed

        if changed_any:
            if MARKER not in text:
                text = f"// {MARKER}\n" + text
            p.write_text(text, encoding="utf-8")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next: flutter clean && flutter pub get, then rebuild.
If either site still fails because 'context' itself isn't in scope
there (unlikely for a State's build-path method, but possible), paste
the surrounding ~10 lines of that widget and I'll adjust — computing
brightness needs a BuildContext, so it has to be read from wherever
context is available in that class (build(), didChangeDependencies(),
etc.), not from a static/const context.
""")


if __name__ == "__main__":
    main()
