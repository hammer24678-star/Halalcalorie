#!/usr/bin/env python3
"""
patch_v52_nutrition_tabs.py
===========================
HalalCalorie v52 - fixes the Nutrition screen showing Today, Recipes and
AI Plan painted on top of each other. Run from the repo root:

    python3 patch_v52_nutrition_tabs.py

Safe to run twice. No new dependencies; no logic or providers touched.

CAUSE      In nutrition_screen.dart the TabBarView was closed right after
           the Today tab (a stray `]),`). The Recipes ListView and the
           _AIPlanTab therefore became plain children of the surrounding
           Stack and were drawn over the Today tab, while the TabBarView
           itself only had 1 child for a 3-tab controller.
FIX        Remove the stray close after Today, and close the TabBarView
           after the AI tab instead, so all three tabs are real pages.
pubspec    1.10.0+23 -> 1.10.1+24
"""
import os, re, sys

ROOT = os.getcwd()
if not os.path.exists(os.path.join(ROOT, 'pubspec.yaml')):
    sys.exit('Run this from the repo root (pubspec.yaml not found).')

ok = skip = 0

def path(p): return os.path.join(ROOT, p)

def edit(p, fn, label):
    """fn(text) -> new text, or None when the anchor is missing."""
    global ok, skip
    if not os.path.exists(path(p)):
        skip += 1; print('  SKIP   ', p, '(missing)', label); return
    with open(path(p), encoding='utf-8') as f:
        s = f.read()
    n = fn(s)
    if n is None:
        skip += 1; print('  SKIP   ', p, '-', label, '(anchor not found)'); return
    if n == s:
        ok += 1; print('  OK     ', p, '-', label, '(already applied)'); return
    with open(path(p), 'w', encoding='utf-8') as f:
        f.write(n)
    ok += 1
    print('  PATCHED', p, '-', label)

def sub_once(old, new):
    def f(s):
        if new in s: return s
        return s.replace(old, new, 1) if old in s else None
    return f

def balance_check(paths):
    bad = 0
    for p in paths:
        if not os.path.exists(path(p)): continue
        t = open(path(p), encoding='utf-8').read()
        t = re.sub(r"//[^\n]*", '', t)
        t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
        t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
        for a, b in ('{}', '()', '[]'):
            if t.count(a) != t.count(b):
                bad += 1
                print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
    print('  all balanced' if not bad else '  !! fix the files above before building')

print('== v52 nutrition tabs ==')
NUT = 'lib/features/nutrition/nutrition_screen.dart'

# 1) stray close between the Today tab and the Recipes tab
STRAY = re.compile(
    r"(\n[ \t]*\),[ \t]*\n)[ \t]*\]\),[ \t]*\n(\s*// ═+ RECIPES TAB)")
# 2) end of the AI tab: _AIPlanTab(...), then the list/Stack/Scaffold closers
TAIL = re.compile(
    r"(isPremium: isPremium\),[ \t]*\n)"
    r"([ \t]*)\],[ \t]*\n"
    r"([ \t]*)\),[ \t]*\n"
    r"([ \t]*)\),[ \t]*\n"
    r"([ \t]*)\);")

def nut(s):
    # sanity: this is the right screen
    if 'RECIPES TAB' not in s or '_AIPlanTab(' not in s:
        return None
    m1 = STRAY.search(s)
    if m1 is None:
        # already fixed? (no stray closer before the Recipes tab)
        return s if re.search(r"\), *\n\s*// ═+ RECIPES TAB", s) else None
    s = s[:m1.start()] + m1.group(1) + '\n' + m1.group(2) + s[m1.end():]
    m2 = TAIL.search(s)
    if m2 is None:
        return None
    ind = m2.group(2)
    new_tail = (m2.group(1)
                + ind + '],\n'              # TabBarView children
                + ind[:-0 or None] + '),\n'  # TabBarView
                + ind[:-2] + ']),\n'         # Stack children + Stack
                + m2.group(4) + '),\n'       # Scaffold
                + m2.group(5) + ');')
    return s[:m2.start()] + new_tail + s[m2.end():]

edit(NUT, nut, 'TabBarView now holds Today / Recipes / AI Plan')
edit('pubspec.yaml', sub_once('version: 1.10.0+23', 'version: 1.10.1+24'),
     'version 1.10.1+24')
print('\n== sanity ==')
balance_check([NUT])
print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git add -A && git commit -m "v52: nutrition tabs fix" && git push')
