#!/usr/bin/env python3
"""
patch_v10_home_remaster.py — HalalCalorie home screen, pass 2
===============================================================

RUN THIS AFTER patch_v10_redesign.py (it assumes 'Aligarh' + icon_assets.dart
are already in place — this script does not repeat that work).

WHAT THIS FIXES / ADDS
  1. BUGFIX: the mosque emoji I patched last time in prayer_card.dart was
     dead code — that PrayerTimesCard widget is never imported or used
     anywhere. The prayer card you actually see on the home screen is the
     private _PrayerCard class defined inside home_screen.dart itself,
     which still had its own separate 🕌 emoji. This patches the real one.
  2. NEW: a hero greeting section at the top of the home screen (streak
     badge, time-of-day greeting in LemonBrush, date) — this is the one
     thing the v10 mockup uses LemonBrush for, and the current app has no
     equivalent element at all, so this is new UI, not a reskin.
  3. NEW: a "wholesome foods" chip strip at the bottom of the home screen,
     using the wholesome_foods_10 icon pack — also didn't exist before.

Everything else on the home screen (prayer card layout, calorie ring,
4-stat row, ascent card, quick actions) was already structurally close to
the v10 mockup once fonts/colors/icons were in place, so it's untouched
here.

SAFETY: same as before — exact-match-or-refuse, per file.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
LEDGER = []
FAILED = []


def _p(relpath):
    return ROOT / relpath


def apply_one(relpath, old, new, note):
    path = _p(relpath)
    if not path.exists():
        FAILED.append(f"{relpath}: file not found")
        print(f"REFUSING {relpath}: file not found — {note}")
        return False
    text = path.read_text(encoding="utf-8")
    n = text.count(old)
    if n != 1:
        FAILED.append(f"{relpath}: {note} (expected 1 match, found {n})")
        print(f"REFUSING {relpath}: expected exactly 1 match for {note!r}, found {n}. "
              f"No changes made to this file. (Did patch_v10_redesign.py run first?)")
        return False
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
    LEDGER.append(f"OK   {relpath}: {note}")
    return True


# ═════════════════════════════════════════════════════════════════
# 1. The REAL prayer-card mosque icon (inside home_screen.dart)
# ═════════════════════════════════════════════════════════════════
def patch_real_mosque_icon():
    old = """child: const Center(
child: Text('🕌', style: TextStyle(fontSize: 22))),
),"""
    new = """child: ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.asset('assets/icons/mosque_mark/mosque_small.png',
        width: 26, height: 26, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
            child: Text('🕌', style: TextStyle(fontSize: 22))))),
),"""
    apply_one(
        "lib/features/home/home_screen.dart", old, new,
        "REAL home-screen prayer-card mosque icon -> mosque_mark (prayer_card.dart's copy was dead code)",
    )


# ═════════════════════════════════════════════════════════════════
# 2. Hero greeting section (new) — streak badge + LemonBrush greeting + date
# ═════════════════════════════════════════════════════════════════
_HERO_CLASS = """
// ════════════════════════════════════════════════════════════
// HOME HERO — PATCH_V10_HOME_REMASTER
// The v10 mockup's only use of LemonBrush: a big cursive time-of-day
// greeting, with a streak badge and today's date. Didn't exist before.
// ════════════════════════════════════════════════════════════
class _HomeHero extends StatelessWidget {
  final bool isAr, isDark;
  final String lang;
  final int streak;
  final Color card, border;
  const _HomeHero({
    required this.isAr, required this.isDark, required this.lang,
    required this.streak, required this.card, required this.border,
  });

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return tLang(lang, 'ليلة سعيدة', 'Good night', 'Bonne nuit', 'İyi geceler', 'Selamat malam', 'Selamat malam');
    if (h < 12) return tLang(lang, 'صباح الخير', 'Good morning', 'Bonjour', 'Günaydın', 'Selamat pagi', 'Selamat pagi');
    if (h < 17) return tLang(lang, 'مساء الخير', 'Good afternoon', 'Bon après-midi', 'İyi günler', 'Selamat tengah hari', 'Selamat siang');
    return tLang(lang, 'مساء الخير', 'Good evening', 'Bonsoir', 'İyi akşamlar', 'Selamat petang', 'Selamat malam');
  }

  String _dateStr(DateTime now) {
    const wkAr = ['الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت','الأحد'];
    const wkEn = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    const moAr = ['يناير','فبراير','مارس','أبريل','مايو','يونيو','يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    const moEn = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final wk = isAr ? wkAr[now.weekday - 1] : wkEn[now.weekday - 1];
    final mo = isAr ? moAr[now.month - 1] : moEn[now.month - 1];
    return isAr ? '$wk، ${now.day} $mo' : '$wk, $mo ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Stack(clipBehavior: Clip.none, children: [
        if (streak > 0)
          Positioned(
            top: 0, left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: card,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 5),
                Text(
                  tLang(lang, '$streak يوم تتابع', '$streak day streak',
                      '$streak jours de suite', '$streak gün seri',
                      '$streak hari berturut', '$streak hari berturut'),
                  style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                  ),
                ),
              ]),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: streak > 0 ? 40 : 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Text(
                _greeting(now),
                style: TextStyle(
                  fontFamily: 'LemonBrush', fontSize: 42, height: 1.0,
                  color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(_dateStr(now), style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 12,
                color: isDark ? AppColors.darkMuted : AppColors.lightMuted)),
          ]),
        ),
      ]),
    );
  }
}
"""


def add_hero_class():
    # Anchor on the medical-disclaimer class comment header, which is
    # unique and sits right after the closing of the main _HomeScreenState
    # build method — appending the new class right before it keeps it out
    # of the middle of an already-large widget tree.
    old = """// ════════════════════════════════════════════════════════════
// MEDICAL DISCLAIMER — required by Google Play Health policy
// ════════════════════════════════════════════════════════════"""
    new = _HERO_CLASS + "\n" + old
    apply_one(
        "lib/features/home/home_screen.dart", old, new,
        "add new _HomeHero widget class",
    )


def wire_hero_into_build():
    old = """sliver: SliverList(delegate: SliverChildListDelegate([

// ── 1 PRAYER CARD ───────────────────────────"""
    new = """sliver: SliverList(delegate: SliverChildListDelegate([

// ── 0 HERO GREETING ─────────────────────────
_HomeHero(
  isAr: isAr, isDark: isDark, lang: lang, streak: streak,
  card: card, border: border,
),

// ── 1 PRAYER CARD ───────────────────────────"""
    apply_one(
        "lib/features/home/home_screen.dart", old, new,
        "wire _HomeHero into the home screen's sliver list",
    )


# ═════════════════════════════════════════════════════════════════
# 3. Wholesome-foods chip strip (new) — after quick actions
# ═════════════════════════════════════════════════════════════════
_FOOD_STRIP_CLASS = """
// ════════════════════════════════════════════════════════════
// WHOLESOME FOODS STRIP — PATCH_V10_HOME_REMASTER
// Static reference strip (not tied to what's actually logged today —
// see nutrition_screen.dart's _checkWholesomeFood for that). Uses the
// same 10 foods and asset paths as the nutrition snackbar.
// ════════════════════════════════════════════════════════════
class _WholesomeFoodStrip extends StatelessWidget {
  final bool isAr, isDark;
  final String lang;
  final Color card, cardAlt, border, text, muted;
  const _WholesomeFoodStrip({
    required this.isAr, required this.isDark, required this.lang,
    required this.card, required this.cardAlt, required this.border,
    required this.text, required this.muted,
  });

  static const List<Map<String, String>> _foods = [
    {'asset': 'assets/icons/wholesome_foods_10/tamr.png', 'ar': 'تمر', 'en': 'Dates'},
    {'asset': 'assets/icons/wholesome_foods_10/asal.png', 'ar': 'عسل', 'en': 'Honey'},
    {'asset': 'assets/icons/wholesome_foods_10/zaytoon.png', 'ar': 'زيتون', 'en': 'Olive'},
    {'asset': 'assets/icons/wholesome_foods_10/haleeb.png', 'ar': 'حليب', 'en': 'Milk'},
    {'asset': 'assets/icons/wholesome_foods_10/zabadi.png', 'ar': 'زبادي', 'en': 'Yogurt'},
    {'asset': 'assets/icons/wholesome_foods_10/teen.png', 'ar': 'تين', 'en': 'Fig'},
    {'asset': 'assets/icons/wholesome_foods_10/ads.png', 'ar': 'عدس', 'en': 'Lentil'},
    {'asset': 'assets/icons/wholesome_foods_10/samak.png', 'ar': 'سمك', 'en': 'Fish'},
    {'asset': 'assets/icons/wholesome_foods_10/bayd.png', 'ar': 'بيض', 'en': 'Egg'},
    {'asset': 'assets/icons/wholesome_foods_10/mukassarat.png', 'ar': 'مكسرات', 'en': 'Nuts'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(tLang(lang, 'أطعمة طيّبة', 'Wholesome foods', 'Aliments sains',
                  'Sağlıklı besinler', 'Makanan sihat', 'Makanan sehat'),
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 14,
                  fontWeight: FontWeight.w700, color: text)),
          Text(tLang(lang, 'للمهمة اليومية 🌿', 'for today\\'s quest 🌿',
                  'pour la quête du jour 🌿', 'günlük görev için 🌿',
                  'untuk misi harian 🌿', 'untuk misi harian 🌿'),
              style: TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                  fontWeight: FontWeight.w600, color: muted)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _foods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _foods[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: cardAlt,
                  border: Border.all(color: border, width: 0.5),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset(f['asset']!, width: 18, height: 18,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 18, height: 18)),
                  const SizedBox(width: 7),
                  Text(isAr ? f['ar']! : f['en']!, style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 12.5,
                      fontWeight: FontWeight.w800, color: text)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
"""


def add_food_strip_class():
    old = """// ════════════════════════════════════════════════════════════
// MEDICAL DISCLAIMER — required by Google Play Health policy
// ════════════════════════════════════════════════════════════"""
    new = _FOOD_STRIP_CLASS + "\n" + old
    apply_one(
        "lib/features/home/home_screen.dart", old, new,
        "add new _WholesomeFoodStrip widget class",
    )


def wire_food_strip_into_build():
    old = """// ── MEDICAL DISCLAIMER ──────────────────────────────
_MedDisclaimer(isAr: isAr),"""
    new = """// ── FOOD STRIP ───────────────────────────────
_WholesomeFoodStrip(
  isAr: isAr, isDark: isDark, lang: lang,
  card: card, cardAlt: isDark ? AppColors.darkCardAlt : AppColors.lightCardAlt,
  border: border, text: text, muted: muted,
),

// ── MEDICAL DISCLAIMER ──────────────────────────────
_MedDisclaimer(isAr: isAr),"""
    apply_one(
        "lib/features/home/home_screen.dart", old, new,
        "wire _WholesomeFoodStrip into the home screen's sliver list",
    )


def main():
    print("=" * 70)
    print("HalalCalorie v10 home screen remaster — pass 2")
    print("=" * 70)
    patch_real_mosque_icon()
    add_hero_class()
    wire_hero_into_build()
    add_food_strip_class()
    wire_food_strip_into_build()

    print()
    print("=" * 70)
    print(f"{len(LEDGER)} edit(s) applied, {len(FAILED)} refused.")
    for line in LEDGER:
        print(" ", line)
    if FAILED:
        print()
        print("REFUSED (no changes made — did patch_v10_redesign.py run first?):")
        for line in FAILED:
            print(" ", line)
        sys.exit(1)
    print("=" * 70)
    print("Done. Full rebuild required (new widgets, not hot-reloadable text).")


if __name__ == "__main__":
    main()
