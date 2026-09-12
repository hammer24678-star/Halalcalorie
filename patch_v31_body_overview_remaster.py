#!/usr/bin/env python3
"""
patch_v31_body_overview_remaster.py
=====================================

Remaster of BodyScreen's Overview tab (the "My Body Metrics" screen) --
the part visible in the screenshot: profile hero, the 4-up metric grid,
and the BMI scale card.

1. Profile avatar: swaps the plain 🧔/🧕 Text emoji for the same
   illustrated kAvatarBrothers/kAvatarSisters portrait already used on
   ProfileScreen (icon_assets.dart, v11) -- same ClipOval + soft-tint
   backdrop + errorBuilder-to-emoji convention, just reused here so the
   two screens match instead of one having real art and the other emoji.

2. _metricCard: real bug fix + redesign.
     - Bug: the label text was hardcoded to AppColors.lightMuted
       regardless of theme, so in dark mode it rendered in a muted tone
       built for light backgrounds instead of the screen's own `muted`.
     - The flat emoji + tiny corner dot is replaced with a colored icon
       badge (same language as health_screen.dart's _stepStat chips),
       and every card gets a hairline border (darkBorder2/lightBorder)
       matching how every other remastered card in the app defines
       itself against the background -- these cards had none, which is
       why they read as flat/undefined next to the rest of the app.

3. _bmiScaleCard: same hairline-border + dark-aware shadow treatment.

Run from project root. Marker-gated, idempotent, safe to re-run.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V31_BODY_OVERVIEW_REMASTER"

BODY = "lib/features/body/body_screen.dart"


def _log(label, status):
    LEDGER.append((label, status))
    print(f"  {status:20s} {label}")


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = p.read_text(encoding="utf-8")
    if old not in text:
        _log(label, "SKIPPED-NOT-FOUND")
        return
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")


def main():
    print("=" * 70)
    print("v31 — Body Metrics Overview remaster")
    print("=" * 70)

    p = ROOT / BODY
    if not p.exists():
        _log(f"{BODY}: file", "SKIPPED-NOT-FOUND")
        return
    text = p.read_text(encoding="utf-8")
    if MARKER in text:
        print(f"  {'SKIPPED-ALREADY':20s} body_screen: already patched")
        return

    changed = False

    # ── 1. import icon_assets.dart for the avatar constants ─────────
    old_imports = (
        "import '../../data/models/user_profile.dart';\n"
        "import '../../data/models/models.dart';\n"
    )
    new_imports = (
        "import '../../data/models/user_profile.dart';\n"
        "import '../../data/models/models.dart';\n"
        f"import '../../data/icon_assets.dart'; // {MARKER}\n"
    )
    if old_imports in text:
        text = text.replace(old_imports, new_imports, 1)
        changed = True
        _log("body: import icon_assets.dart", "OK")
    elif "'../../data/icon_assets.dart'" in text:
        _log("body: import icon_assets.dart", "SKIPPED-ALREADY")
    else:
        _log("body: import icon_assets.dart", "SKIPPED-NOT-FOUND")

    # ── 2. Profile hero: emoji -> real illustrated avatar ────────────
    old_avatar = """        child: Column(children: [
          Text(p.isMale ? '🧔' : '🧕', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),"""
    new_avatar = f"""        child: Column(children: [
          // {MARKER}: same avatar art + ClipOval convention as
          // ProfileScreen -- this screen previously used the plain emoji.
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.18)),
            child: ClipOval(child: Image.asset(
              p.isMale ? kAvatarBrothers : kAvatarSisters,
              width: 72, height: 72, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                  child: Text(p.isMale ? '🧔' : '🧕', style: const TextStyle(fontSize: 40))))),
          ),
          const SizedBox(height: 8),"""
    if old_avatar in text:
        text = text.replace(old_avatar, new_avatar, 1)
        changed = True
        _log("body: hero avatar -> illustrated portrait", "OK")
    else:
        _log("body: hero avatar -> illustrated portrait", "SKIPPED-NOT-FOUND")

    # ── 3. Metric grid call sites: pass isDark/muted through ─────────
    old_grid = """          _metricCard(tLang(lang, 'وزنك الحالي', 'Current Weight', 'Poids actuel', 'Mevcut Ağırlık', 'Berat Semasa', 'Berat Saat Ini'), '${p.weightKg.toStringAsFixed(1)} kg', '⚖️', AppColors.brandGreen, cardBg),
          _metricCard(tLang(lang, 'الوزن المثالي', 'Ideal Weight', 'Poids idéal', 'İdeal Ağırlık', 'Berat Ideal', 'Berat Ideal'), '${p.idealWeightKg.toStringAsFixed(1)} kg', '🎯', AppColors.accentGold, cardBg),
          _metricCard(tLang(lang, 'هدف السعرات', 'Calorie Goal', 'Objectif calorique', 'Kalori Hedefi', 'Sasaran Kalori', 'Target Kalori'), '${p.calorieGoalKcal.toInt()} kcal', '🔥', AppColors.haramRed, cardBg),
          _metricCard(tLang(lang, 'الماء اليومي', 'Daily Water', 'Eau quotidienne', 'Günlük Su', 'Air Harian', 'Air Harian'), '${p.waterLiters} L', '💧', AppColors.waterBlue, cardBg),"""
    new_grid = f"""          // {MARKER}: pass isDark/muted through so the card can
          // fix its own dark-mode label color instead of hardcoding one.
          _metricCard(tLang(lang, 'وزنك الحالي', 'Current Weight', 'Poids actuel', 'Mevcut Ağırlık', 'Berat Semasa', 'Berat Saat Ini'), '${{p.weightKg.toStringAsFixed(1)}} kg', '⚖️', AppColors.brandGreen, cardBg, isDark: isDark, muted: muted),
          _metricCard(tLang(lang, 'الوزن المثالي', 'Ideal Weight', 'Poids idéal', 'İdeal Ağırlık', 'Berat Ideal', 'Berat Ideal'), '${{p.idealWeightKg.toStringAsFixed(1)}} kg', '🎯', AppColors.accentGold, cardBg, isDark: isDark, muted: muted),
          _metricCard(tLang(lang, 'هدف السعرات', 'Calorie Goal', 'Objectif calorique', 'Kalori Hedefi', 'Sasaran Kalori', 'Target Kalori'), '${{p.calorieGoalKcal.toInt()}} kcal', '🔥', AppColors.haramRed, cardBg, isDark: isDark, muted: muted),
          _metricCard(tLang(lang, 'الماء اليومي', 'Daily Water', 'Eau quotidienne', 'Günlük Su', 'Air Harian', 'Air Harian'), '${{p.waterLiters}} L', '💧', AppColors.waterBlue, cardBg, isDark: isDark, muted: muted),"""
    if old_grid in text:
        text = text.replace(old_grid, new_grid, 1)
        changed = True
        _log("body: metric grid call sites", "OK")
    else:
        _log("body: metric grid call sites", "SKIPPED-NOT-FOUND")

    # ── 4. _metricCard widget: badge redesign + dark-mode fix ────────
    old_card = """  Widget _metricCard(String label, String value, String emoji, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontFamily: 'Aligarh', fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: const TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: AppColors.lightMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }"""
    new_card = f"""  // {MARKER}: icon badge instead of emoji+dot, hairline border to
  // match every other remastered card, and `label` now actually uses
  // the theme-aware `muted` color instead of a hardcoded light-mode one.
  Widget _metricCard(String label, String value, String emoji, Color color, Color bg,
      {{bool isDark = false, Color muted = AppColors.lightMuted}}) {{
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder2 : AppColors.lightBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.20 : 0.06), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.16 : 0.12), shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 17))),
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontFamily: 'Aligarh', fontSize: 16, fontWeight: FontWeight.w900, color: color)),
        Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 10, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }}"""
    if old_card in text:
        text = text.replace(old_card, new_card, 1)
        changed = True
        _log("body: _metricCard redesign + dark-mode label fix", "OK")
    else:
        _log("body: _metricCard redesign + dark-mode label fix", "SKIPPED-NOT-FOUND")

    # ── 5. _bmiScaleCard: hairline border + dark-aware shadow ────────
    old_bmi = """    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 3))]),"""
    new_bmi = f"""    return Container(
      padding: const EdgeInsets.all(16),
      // {MARKER}: hairline border so the card reads as a card against
      // dark backgrounds instead of nearly matching the scaffold color.
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder2 : Colors.black.withOpacity(0.04)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.20 : 0.06), blurRadius: 14, offset: const Offset(0, 3))],
      ),"""
    if old_bmi in text:
        text = text.replace(old_bmi, new_bmi, 1)
        changed = True
        _log("body: _bmiScaleCard border + dark-aware shadow", "OK")
    else:
        _log("body: _bmiScaleCard border + dark-aware shadow", "SKIPPED-NOT-FOUND")

    if changed:
        p.write_text(text, encoding="utf-8")

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    print(f"{ok} fix(es) applied.")
    print("=" * 70)
    print("""
Next: flutter clean && flutter pub get, then rebuild in both themes.

Scope note: this pass covers exactly what's in the screenshot (hero +
4-up grid + BMI card). The weight-diff / weight-trend-chart / body-photo
cards further down Overview still use the old flat-shadow-only style --
say the word and I'll bring them in line the same way.
""")


if __name__ == "__main__":
    main()
