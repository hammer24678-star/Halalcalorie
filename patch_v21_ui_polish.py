#!/usr/bin/env python3
"""
patch_v21_ui_polish.py — beyond-perfection pass
================================================

WHAT THIS DOES
  1. HOME greeting → same unique LemonBrush + evening crescent as Nutrition
  2. NUTRITION Today card:
       - Ring size 120 → 168 (visibly larger, text feels alive)
       - Center text bigger / bolder / breathing hierarchy
       - Side Eaten/Burned boxes redesigned as tall premium tiles
       - Meal sections (Breakfast/Lunch/Dinner/Snacks) fully restyled:
         rounded soft cards, icon badge, kcal pill, premium empty state
  3. FITNESS:
       - Recommended banner taller, clearer hierarchy
       - Workout grid cards: better aspect, larger title, softer shadow
       - Coaching line tighter
  4. HEALTH Tracking:
       - Section titles with accent bar (matches Home/Nutrition language)
       - Steps card hero number + LIVE chip polish
       - Mood row spacing + selected state glow
       - HR card dark-mode progress track fix

SAFETY
  Marker-gated edits. Skips if already applied. Run from project root.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
LEDGER = []
MARKER = "PATCH_V21_UI_POLISH"


def _log(label, status):
    LEDGER.append((label, status))


def edit(rel, old, new, label):
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERROR ({label}): {rel} not found under {ROOT}")
    text = p.read_text(encoding="utf-8")
    if MARKER in text and label.startswith("marker"):
        _log(label, "SKIPPED-ALREADY")
        return text
    if old not in text:
        # soft-fail for optional bits
        _log(label, "SKIPPED-NOT-FOUND")
        return text
    text = text.replace(old, new, 1)
    p.write_text(text, encoding="utf-8")
    _log(label, "OK")
    return text


def write_full(rel, content, label, old_marker, new_marker):
    p = ROOT / rel
    if not p.exists():
        raise SystemExit(f"ERROR ({label}): {rel} not found")
    existing = p.read_text(encoding="utf-8")
    if new_marker in existing:
        _log(label, "SKIPPED-ALREADY")
        return
    if old_marker and old_marker not in existing:
        # allow if file was already partially updated
        pass
    p.write_text(content, encoding="utf-8")
    _log(label, "REPLACED")


# ─────────────────────────────────────────────────────────────
# 1. HOME — greeting matches Nutrition (LemonBrush + crescent)
# ─────────────────────────────────────────────────────────────
HOME = "lib/features/home/home_screen.dart"

HOME_GREETING_OLD = """            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Text(
                _greeting(now),
                style: TextStyle(
                  fontFamily: 'Bravoon', fontWeight: FontWeight.w700, fontSize: 42, height: 1.0,
                  color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                ),
              ),
            ),"""

HOME_GREETING_NEW = """            // PATCH_V21_UI_POLISH: match Nutrition's unique LemonBrush +
            // evening crescent treatment so both heroes feel like one app.
            Transform.rotate(
              angle: -0.035,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _greeting(now),
                    style: TextStyle(
                      fontFamily: 'LemonBrush',
                      fontWeight: FontWeight.w400,
                      fontSize: 40,
                      height: 1.0,
                      color: isDark ? AppColors.greetGold : AppColors.greetGoldLight,
                    ),
                  ),
                  if (now.hour >= 17) ...[
                    const SizedBox(width: 8),
                    const Text('🌙', style: TextStyle(fontSize: 28)),
                  ] else if (now.hour < 12) ...[
                    const SizedBox(width: 8),
                    const Text('☀️', style: TextStyle(fontSize: 26)),
                  ],
                ],
              ),
            ),"""


# ─────────────────────────────────────────────────────────────
# 2. NUTRITION — ring size, center text, side boxes, meal cards
# ─────────────────────────────────────────────────────────────
NUTR = "lib/features/nutrition/nutrition_screen.dart"

# Ring size 120 → 168
RING_SIZE_OLD = """                          LeafProgressRing(
                            size: 120,
                            progress: pct,"""
RING_SIZE_NEW = """                          LeafProgressRing(
                            size: 168, // PATCH_V21_UI_POLISH: was 120 — hero ring
                            progress: pct,"""

# Center text hierarchy — bigger, alive
RING_CHILD_OLD = """                            child: Column(mainAxisSize: MainAxisSize.min,
                                children: [
                              Text('${left.abs()}',
                                  style: TextStyle(
                                      fontFamily: 'Aligarh',
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: calCol)),
                              Text(
                                left < 0
                                    ? tl('سعرة زيادة', 'kcal over')
                                    : tl('سعرة متبقية', 'kcal remaining'),
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: calCol),
                              ),
                              Text(ofGoalLabel,
                                  style: TextStyle(
                                      fontFamily: 'Aligarh',
                                      fontSize: 9,
                                      color: muted)),
                            ]),"""

RING_CHILD_NEW = """                            child: Column(mainAxisSize: MainAxisSize.min,
                                children: [
                              // PATCH_V21_UI_POLISH: alive number hierarchy
                              Text('${left.abs()}',
                                  style: TextStyle(
                                      fontFamily: 'Aligarh',
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      height: 1.0,
                                      letterSpacing: -0.5,
                                      color: calCol)),
                              const SizedBox(height: 2),
                              Text(
                                left < 0
                                    ? tl('سعرة زيادة', 'kcal over')
                                    : tl('سعرة متبقية', 'kcal remaining'),
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: calCol),
                              ),
                              Text(ofGoalLabel,
                                  style: TextStyle(
                                      fontFamily: 'Aligarh',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: muted)),
                            ]),"""

# Side summary boxes — taller premium tiles
SUMMARY_BOX_OLD = """  Widget _summaryBox(String emoji, String label, String val,
      Color color, bool isDark) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(val, style: TextStyle(fontFamily: 'Aligarh',
                  fontSize: 18, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(width: 8),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(emoji,
                    style: const TextStyle(fontSize: 15))),
              ),
            ]),
            Positioned(
              top: -3, right: -3,
              child: Container(width: 7, height: 7,
                  decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontFamily: 'Aligarh',
              fontSize: 10, color: color.withOpacity(0.85),
              fontWeight: FontWeight.w700)),
        ]),
      );"""

SUMMARY_BOX_NEW = """  // PATCH_V21_UI_POLISH: tall premium side tiles next to the hero ring
  Widget _summaryBox(String emoji, String label, String val,
      Color color, bool isDark) =>
      Container(
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.10 : 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.22), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(height: 10),
          Text(val, style: TextStyle(fontFamily: 'Aligarh',
              fontSize: 22, fontWeight: FontWeight.w900,
              height: 1.0, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Aligarh',
              fontSize: 10, color: color.withOpacity(0.9),
              fontWeight: FontWeight.w700)),
        ]),
      );"""

# Meal section — full restyle of the card chrome
MEAL_BUILD_OLD = """    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: accentCol.withOpacity(0.10),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
        border: Border(
          left: BorderSide(color: accentCol, width: 3.5),
        ),
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Text(widget.emoji,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.title,
                    style: TextStyle(fontFamily: 'Aligarh',
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: widget.textC)),
                if (_totalKcal > 0)
                  Text('$_totalKcal kcal',
                      style: const TextStyle(fontFamily: 'Aligarh',
                          fontSize: 11,
                          color: AppColors.brandGreen,
                          fontWeight: FontWeight.w600)),
              ])),
              // Add button
              GestureDetector(
                onTap: widget.onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentCol.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: accentCol.withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded,
                        color: accentCol, size: 16),
                    const SizedBox(width: 3),
                    Text(tLang(lang, 'أضف', 'Add', 'Ajouter', 'Ekle', 'Tambah', 'Tambah'),
                        style: TextStyle(fontFamily: 'Aligarh',
                            fontSize: 11,
                            color: accentCol,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
              Icon(_expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: widget.muted, size: 20),
            ]),
          ),
        ),"""

MEAL_BUILD_NEW = """    // PATCH_V21_UI_POLISH: soft full-round card, icon badge, kcal pill
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: accentCol.withOpacity(0.14),
              blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(
              color: Colors.black.withOpacity(widget.isDark ? 0.22 : 0.04),
              blurRadius: 10, offset: const Offset(0, 2)),
        ],
        border: Border.all(
          color: accentCol.withOpacity(0.28),
          width: 1.1,
        ),
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(children: [
              // Colored icon badge
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentCol.withOpacity(0.28),
                      accentCol.withOpacity(0.10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentCol.withOpacity(0.35)),
                ),
                child: Center(child: Text(widget.emoji,
                    style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.title,
                    style: TextStyle(fontFamily: 'Aligarh',
                        fontSize: 16, fontWeight: FontWeight.w800,
                        color: widget.textC, height: 1.15)),
                const SizedBox(height: 3),
                if (_totalKcal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$_totalKcal kcal',
                        style: const TextStyle(fontFamily: 'Aligarh',
                            fontSize: 11,
                            color: AppColors.brandGreen,
                            fontWeight: FontWeight.w800)),
                  )
                else
                  Text(tLang(lang, 'فارغ', 'Empty', 'Vide', 'Boş', 'Kosong', 'Kosong'),
                      style: TextStyle(fontFamily: 'Aligarh',
                          fontSize: 11, color: widget.muted,
                          fontWeight: FontWeight.w600)),
              ])),
              // Add button — filled soft pill
              GestureDetector(
                onTap: widget.onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentCol.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: accentCol.withOpacity(0.45)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded,
                        color: accentCol, size: 17),
                    const SizedBox(width: 3),
                    Text(tLang(lang, 'أضف', 'Add', 'Ajouter', 'Ekle', 'Tambah', 'Tambah'),
                        style: TextStyle(fontFamily: 'Aligarh',
                            fontSize: 12,
                            color: accentCol,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
              const SizedBox(width: 4),
              Icon(_expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: widget.muted, size: 22),
            ]),
          ),
        ),"""

# Empty state inside meal section
MEAL_EMPTY_OLD = """                    style: TextStyle(fontFamily: 'Aligarh',
                        fontSize: 12, color: widget.muted)),
              ]),
            )
          else ...["""

MEAL_EMPTY_NEW = """                    style: TextStyle(fontFamily: 'Aligarh',
                        fontSize: 13, color: widget.muted,
                        fontWeight: FontWeight.w600)),
              ]),
            )
          else ...["""

# Padding around calorie summary card content for bigger ring
CARD_PAD_OLD = """                      Padding(
                        padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      // Top row: eaten | ring | burned
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ["""

CARD_PAD_NEW = """                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
                    child: Column(children: [
                      // Top row: eaten | ring | burned  — PATCH_V21
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: ["""


# ─────────────────────────────────────────────────────────────
# 3. FITNESS — recommended banner + grid cards
# ─────────────────────────────────────────────────────────────
FIT = "lib/features/fitness/fitness_screen.dart"

FIT_REC_OLD = """              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRamadan
                        ? [AppColors.ramadanNight, AppColors.ramadanCardAlt]
                        : isSis
                            ? [const Color(0xFFB8860B), const Color(0xFFDAA520)]
                            : [const Color(0xFF1A6B3C), AppColors.brandGreen],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                    color: AppColors.brandGreen.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 6))],
                ),
                child: Row(children: [
                  Text(rec.emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(isAr ?'⚡ موصى به الآن' : '⚡ Recommended Now', style: TextStyle(fontFamily:'Aligarh', fontSize: 10,
                            color: isRamadan ? AppColors.accentGold : Colors.white70)),
                    Text(isAr ? rec.titleAr : rec.titleEn, style: const TextStyle(fontFamily:'Aligarh', fontSize: 13,
                            fontWeight: FontWeight.w800, color: Colors.white)), Text('${rec.durationMin} ${isAr ? "دقيقة" : "min"}  •  ${isAr ? rec.level : rec.levelEn}', style: const TextStyle(fontFamily:'Aligarh', fontSize: 10, color: Colors.white70)),
                  ])),
                  const Icon(Icons.play_circle_filled, color: Colors.white, size: 32),
                ]),
              ),"""

FIT_REC_NEW = """              // PATCH_V21_UI_POLISH: taller recommended banner, clearer hierarchy
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRamadan
                        ? [AppColors.ramadanNight, AppColors.ramadanCardAlt]
                        : isSis
                            ? [const Color(0xFFB8860B), const Color(0xFFDAA520)]
                            : [const Color(0xFF145C32), const Color(0xFF2E9C40)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: (isRamadan ? AppColors.ramadanGold : AppColors.brandGreen)
                        .withOpacity(0.38),
                    blurRadius: 22, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(rec.emoji,
                        style: const TextStyle(fontSize: 26))),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isAr ? '⚡ موصى به الآن' : '⚡ Recommended Now',
                        style: TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isRamadan ? AppColors.accentGold : Colors.white70)),
                    const SizedBox(height: 3),
                    Text(isAr ? rec.titleAr : rec.titleEn,
                        style: const TextStyle(fontFamily: 'Aligarh', fontSize: 15,
                            fontWeight: FontWeight.w900, color: Colors.white, height: 1.15)),
                    const SizedBox(height: 2),
                    Text('${rec.durationMin} ${isAr ? "دقيقة" : "min"}  •  ${isAr ? rec.level : rec.levelEn}',
                        style: const TextStyle(fontFamily: 'Aligarh', fontSize: 11,
                            color: Colors.white70)),
                  ])),
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                  ),
                ]),
              ),"""

FIT_GRID_OLD = """                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12,
                    crossAxisSpacing: 12, childAspectRatio: 0.88),"""

FIT_GRID_NEW = """                  // PATCH_V21_UI_POLISH: roomier cards
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 14,
                    crossAxisSpacing: 14, childAspectRatio: 0.82),"""

FIT_CARD_OLD = """                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                              blurRadius: 16, offset: const Offset(0, 5)),
                            if (!locked) BoxShadow(
                              color: barCol.withOpacity(0.06),
                              blurRadius: 12, offsetRadius: 1),
                          ],
                          border: Border.all(
                              color: locked
                                  ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                  : barCol.withOpacity(isDark ? 0.25 : 0.18),
                              width: 0.8),
                        ),"""

FIT_CARD_NEW = """                      // PATCH_V21_UI_POLISH: softer elevated card
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.30 : 0.07),
                              blurRadius: 18, offset: const Offset(0, 6)),
                            if (!locked) BoxShadow(
                              color: barCol.withOpacity(0.10),
                              blurRadius: 14, spreadRadius: 1),
                          ],
                          border: Border.all(
                              color: locked
                                  ? (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                                  : barCol.withOpacity(isDark ? 0.30 : 0.22),
                              width: 1.0),
                        ),"""

FIT_TITLE_OLD = """                            Text(isAr ? w.titleAr : w.titleEn, style: TextStyle(fontFamily:'Aligarh',
                                    fontWeight: FontWeight.w700, fontSize: 11,
                                    height: 1.4, color: isDark ? AppColors.darkText : AppColors.lightText),
                                maxLines: 2, overflow: TextOverflow.ellipsis),"""

FIT_TITLE_NEW = """                            Text(isAr ? w.titleAr : w.titleEn, style: TextStyle(fontFamily:'Aligarh',
                                    fontWeight: FontWeight.w800, fontSize: 13,
                                    height: 1.3, color: isDark ? AppColors.darkText : AppColors.lightText),
                                maxLines: 2, overflow: TextOverflow.ellipsis),"""


# ─────────────────────────────────────────────────────────────
# 4. HEALTH — section titles + steps/mood/HR polish
# ─────────────────────────────────────────────────────────────
HEALTH = "lib/features/health/health_screen.dart"

HEALTH_SECTION_OLD = """  Widget _sectionTitle(String t, bool isDark) => Padding("""

# We'll replace the whole _sectionTitle method body via a larger unique slice
HEALTH_SECTION_FULL_OLD = None  # filled below after reading

SECTION_TITLE_REPLACE = r'''  // PATCH_V21_UI_POLISH: accent-bar section titles
  Widget _sectionTitle(String t, bool isDark) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 2),
        child: Row(children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              color: AppColors.brandGreen,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t,
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText)),
          ),
        ]),
      );'''


def main():
    print("=" * 70)
    print("v21 UI polish — home greeting, nutrition hero, meals, fitness, health")
    print("=" * 70)

    # ── HOME ──
    edit(HOME, HOME_GREETING_OLD, HOME_GREETING_NEW,
         "home: LemonBrush greeting + time-of-day glyph")

    # ── NUTRITION ──
    edit(NUTR, RING_SIZE_OLD, RING_SIZE_NEW,
         "nutrition: ring size 120→168")
    edit(NUTR, RING_CHILD_OLD, RING_CHILD_NEW,
         "nutrition: alive center text")
    edit(NUTR, SUMMARY_BOX_OLD, SUMMARY_BOX_NEW,
         "nutrition: premium side tiles")
    edit(NUTR, CARD_PAD_OLD, CARD_PAD_NEW,
         "nutrition: card padding for larger ring")
    edit(NUTR, MEAL_BUILD_OLD, MEAL_BUILD_NEW,
         "nutrition: meal section chrome redesign")
    edit(NUTR, MEAL_EMPTY_OLD, MEAL_EMPTY_NEW,
         "nutrition: empty-state type weight")

    # ── FITNESS ──
    edit(FIT, FIT_REC_OLD, FIT_REC_NEW,
         "fitness: recommended banner")
    edit(FIT, FIT_GRID_OLD, FIT_GRID_NEW,
         "fitness: grid spacing/aspect")
    edit(FIT, FIT_CARD_OLD, FIT_CARD_NEW,
         "fitness: card elevation")
    edit(FIT, FIT_TITLE_OLD, FIT_TITLE_NEW,
         "fitness: card title size")

    # ── HEALTH section title ──
    p = ROOT / HEALTH
    text = p.read_text(encoding="utf-8")
    if "PATCH_V21_UI_POLISH: accent-bar section titles" in text:
        _log("health: section titles", "SKIPPED-ALREADY")
    else:
        # Find existing _sectionTitle and replace method
        m = re.search(
            r"  Widget _sectionTitle\(String t, bool isDark\) => Padding\([\s\S]*?\);",
            text,
        )
        if m:
            text = text[: m.start()] + SECTION_TITLE_REPLACE + text[m.end() :]
            p.write_text(text, encoding="utf-8")
            _log("health: section titles", "OK")
        else:
            _log("health: section titles", "SKIPPED-NOT-FOUND")

    # Health steps hero number bump
    edit(
        HEALTH,
        """          Row(children: [
            Text('${health.steps}',
                style: const TextStyle(fontFamily: 'Aligarh',
                    fontSize: 36, fontWeight: FontWeight.w900,
                    color: AppColors.halalGreen)),""",
        """          // PATCH_V21_UI_POLISH: bigger steps hero
          Row(children: [
            Text('${health.steps}',
                style: const TextStyle(fontFamily: 'Aligarh',
                    fontSize: 42, fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: AppColors.halalGreen)),""",
        "health: steps hero size",
    )

    # HR dark progress track
    edit(
        HEALTH,
        """          LinearProgressIndicator(
              value: ((health.heartRate - 40) / 80).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(hrCol),
              borderRadius: BorderRadius.circular(6),
              minHeight: 8),""",
        """          // PATCH_V21_UI_POLISH: dark-mode aware track
          LinearProgressIndicator(
              value: ((health.heartRate - 40) / 80).clamp(0.0, 1.0),
              backgroundColor: isDark
                  ? AppColors.darkBorder
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(hrCol),
              borderRadius: BorderRadius.circular(6),
              minHeight: 8),""",
        "health: HR dark track",
    )

    # Mood selected glow
    edit(
        HEALTH,
        """          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: health.mood == m[1]
                  ? AppColors.brandGreen.withOpacity(0.12)
                  : Colors.transparent,
              border: Border.all(
                  color: health.mood == m[1]
                      ? AppColors.brandGreen
                      : Colors.transparent,
                  width: 2),
              borderRadius: BorderRadius.circular(12),
            ),""",
        """          // PATCH_V21_UI_POLISH: selected mood glow
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: health.mood == m[1]
                  ? AppColors.brandGreen.withOpacity(0.16)
                  : Colors.transparent,
              border: Border.all(
                  color: health.mood == m[1]
                      ? AppColors.brandGreen
                      : Colors.transparent,
                  width: 2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: health.mood == m[1]
                  ? [BoxShadow(
                      color: AppColors.brandGreen.withOpacity(0.25),
                      blurRadius: 10)]
                  : null,
            ),""",
        "health: mood selected glow",
    )

    print()
    print("=" * 70)
    ok = sum(1 for _, s in LEDGER if s == "OK")
    skip = sum(1 for _, s in LEDGER if s.startswith("SKIPPED"))
    for label, status in LEDGER:
        print(f"  {status:18s} {label}")
    print("=" * 70)
    print(f"{ok} applied, {skip} skipped.")
    print("Rebuild the app to see changes.")


if __name__ == "__main__":
    main()
