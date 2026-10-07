#!/usr/bin/env python3
"""
patch_v61_ai.py
===============
HalalCalorie v61 - AI works again (free Google Gemini key).
Run from the repo root (after v60):

    python3 patch_v61_ai.py

WHY THE AI WAS DEAD
  * GROQ_API_KEY was never set in the build, and
  * Groq has shut down both models the app used (llama-3.1-8b-instant on 2026-08-16,
    llama-4-scout on 2026-07-17, llama-3.3-70b on 2026-08-16); the replacements are
    text-only, so photo analysis cannot stay on Groq.

WHAT THIS DOES
  * New lib/core/ai_config.dart: ONE place for endpoint, key and model names, all
    overridable at build time (AI_ENDPOINT, AI_TEXT_MODEL, AI_VISION_MODEL,
    AI_REASONING) so a retired model never needs a code change again.
  * Default provider: Google Gemini (free tier, OpenAI-compatible endpoint, supports
    images). Key name: GEMINI_API_KEY.
  * ai_service, coach and meal plan all use it; token caps get headroom because
    Gemini counts internal reasoning against max_tokens.
  * build.yml passes GEMINI_API_KEY to the APK and AAB builds.

YOU DO:  get a key at https://aistudio.google.com/apikey, then GitHub repo ->
         Settings -> Secrets and variables -> Actions -> New secret:
         name GEMINI_API_KEY, value the key.  Then push and rebuild.
"""
import os, re, sys

ROOT = os.getcwd()
if not os.path.exists(os.path.join(ROOT, 'pubspec.yaml')):
    sys.exit('Run this from the repo root (pubspec.yaml not found).')

ok = skip = 0
def path(p): return os.path.join(ROOT, p)

def write(p, content):
    global ok
    os.makedirs(os.path.dirname(path(p)), exist_ok=True)
    old = open(path(p), encoding='utf-8').read() if os.path.exists(path(p)) else None
    if old == content:
        ok += 1; print('  OK     ', p, '(already applied)'); return
    open(path(p), 'w', encoding='utf-8').write(content)
    ok += 1; print('  WROTE  ', p)

def edit(p, fn, label):
    global ok, skip
    if not os.path.exists(path(p)):
        skip += 1; print('  SKIP   ', p, '(missing)', label); return
    s = open(path(p), encoding='utf-8').read()
    n = fn(s)
    if n is None:
        skip += 1; print('  SKIP   ', p, '-', label, '(anchor not found)'); return
    if n == s:
        ok += 1; print('  OK     ', p, '-', label, '(already applied)'); return
    open(path(p), 'w', encoding='utf-8').write(n)
    ok += 1; print('  PATCHED', p, '-', label)

def rep(old, new, marker):
    """Replace the first `old` with `new`; no-op when `marker` is already present."""
    def f(s):
        if marker in s: return s
        return s.replace(old, new, 1) if old in s else None
    return f

def chain(*fns):
    def f(s):
        for fn in fns:
            r = fn(s)
            if r is None: return None
            s = r
        return s
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
                bad += 1; print('  UNBALANCED', p, a, t.count(a), b, t.count(b))
    print('  all balanced' if not bad else '  !! fix the files above before building')


print('== v61 ==')

write('lib/core/ai_config.dart', r"""// ai_config.dart — HalalCalorie v61 (PATCH_V61_AI)
// One place for the AI provider. Everything is a build-time --dart-define, so
// switching provider or model never needs a code change:
//   --dart-define=GEMINI_API_KEY=...        (free key from aistudio.google.com)
//   --dart-define=AI_ENDPOINT=...           any OpenAI-compatible chat/completions URL
//   --dart-define=AI_TEXT_MODEL=...         default gemini-flash-latest
//   --dart-define=AI_VISION_MODEL=...       default gemini-flash-latest
//   --dart-define=AI_REASONING=...          low | none | minimal | '' (omit the field)
class AiConfig {
  static const String _gemini = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _generic = String.fromEnvironment('AI_API_KEY', defaultValue: '');
  static const String apiKey = _gemini != '' ? _gemini : _generic;

  static const String endpoint = String.fromEnvironment('AI_ENDPOINT',
      defaultValue: 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');
  static const String textModel =
      String.fromEnvironment('AI_TEXT_MODEL', defaultValue: 'gemini-flash-latest');
  static const String visionModel =
      String.fromEnvironment('AI_VISION_MODEL', defaultValue: 'gemini-flash-latest');
  static const String reasoning = String.fromEnvironment('AI_REASONING', defaultValue: 'low');

  /// Gemini counts internal reasoning against max_tokens, so leave headroom.
  static int cap(int n) => n + 1024;
}
""")

REASON = "if (AiConfig.reasoning.isNotEmpty) 'reasoning_effort': AiConfig.reasoning,"

def _ai(s):
    if 'AiConfig' in s: return s
    pairs = [
      ("  static const _endpoint    = 'https://api.groq.com/openai/v1/chat/completions';", "  static const _endpoint    = AiConfig.endpoint;"),
      ("  static const _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';", "  static const _visionModel = AiConfig.visionModel;"),
      ("  static const _textModel   = 'llama-3.1-8b-instant';", "  static const _textModel   = AiConfig.textModel;"),
      ("  static const _apiKey      = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');", "  static const _apiKey      = AiConfig.apiKey;"),
      ("'GROQ_API_KEY is not set. Add it to your GitHub Secrets and rebuild.'", "'GEMINI_API_KEY is not set. Add it to your GitHub Secrets and rebuild.'"),
      ("import '../data/models/models.dart';\n", "import '../data/models/models.dart';\nimport 'ai_config.dart'; // PATCH_V61_AI\n"),
    ]
    for a, b in pairs:
        if a not in s: return None
        s = s.replace(a, b, 1)
    old = "      'max_tokens': maxTokens,\n"
    if s.count(old) != 2: return None
    return s.replace(old, "      'max_tokens': AiConfig.cap(maxTokens),\n      " + REASON + "\n")
edit('lib/core/ai_service.dart', _ai, 'use AiConfig (Gemini)')

def _coach(s):
    if 'AiConfig' in s: return s
    pairs = [
      ("  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';", "  static const _endpoint = AiConfig.endpoint;"),
      ("  static const _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');", "  static const _apiKey = AiConfig.apiKey;"),
      ("  static const _models = ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant'];", "  static const _models = [AiConfig.textModel];"),
      ("import '../../core/fasting_calendar.dart';\n", "import '../../core/ai_config.dart'; // PATCH_V61_AI\nimport '../../core/fasting_calendar.dart';\n"),
      ("                'max_tokens': 450,\n", "                'max_tokens': AiConfig.cap(450),\n                " + REASON + "\n"),
    ]
    for a, b in pairs:
        if a not in s: return None
        s = s.replace(a, b, 1)
    return s
edit('lib/features/premium/coach_screen.dart', _coach, 'use AiConfig (Gemini)')

def _meal(s):
    if 'AiConfig' in s: return s
    pairs = [
      ("  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';", "  static const _endpoint = AiConfig.endpoint;"),
      ("  static const _apiKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');", "  static const _apiKey = AiConfig.apiKey;"),
      ("for (final model in const ['llama-3.3-70b-versatile', 'llama-3.1-8b-instant']) {", "for (final model in <String>[AiConfig.textModel]) {"),
      ("import '../../core/fasting_calendar.dart';\n", "import '../../core/ai_config.dart'; // PATCH_V61_AI\nimport '../../core/fasting_calendar.dart';\n"),
      ("                'max_tokens': 1100,\n", "                'max_tokens': AiConfig.cap(1100),\n                " + REASON + "\n"),
    ]
    for a, b in pairs:
        if a not in s: return None
        s = s.replace(a, b, 1)
    return s
edit('lib/features/premium/meal_plan_screen.dart', _meal, 'use AiConfig (Gemini)')

edit('lib/features/scanner/food_photo_screen.dart', rep("raw.contains('GROQ_API_KEY')", "raw.contains('API_KEY')", "raw.contains('API_KEY')"), 'key-missing detection')

def _yml(s):
    if 'GEMINI_API_KEY' in s: return s
    a = "          GROQ_API_KEY:         ${{ secrets.GROQ_API_KEY }}\n"
    b = "          --dart-define=GROQ_API_KEY=$GROQ_API_KEY\n"
    if a not in s or b not in s: return None
    s = s.replace(a, a + "          GEMINI_API_KEY:       ${{ secrets.GEMINI_API_KEY }}\n")
    return s.replace(b, b + "          --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY\n")
edit('.github/workflows/build.yml', _yml, 'pass GEMINI_API_KEY to builds')

edit('pubspec.yaml', lambda s: re.sub(r'^version:\s*[\d.]+\+\d+', 'version: 1.17.2+33', s, count=1, flags=re.M) if re.search(r'^version:', s, re.M) else None, 'version -> 1.17.2+33')

balance_check(['lib/core/ai_config.dart', 'lib/core/ai_service.dart', 'lib/features/premium/coach_screen.dart',
               'lib/features/premium/meal_plan_screen.dart', 'lib/features/scanner/food_photo_screen.dart'])
print('done:', ok, 'ok,', skip, 'skipped')
print('Next: add the GEMINI_API_KEY secret on GitHub (aistudio.google.com/apikey), then push.')
