#!/usr/bin/env python3
"""
patch_v55.py
============
HalalCalorie v55 - the food flow rebuilt. Run from the repo root (after v54):

    python3 patch_v55.py

Safe to run twice. No new dependencies; logic and providers unchanged.

ADD FOOD SHEET  new chrome (gradient sheet, glass close button, icon tabs that
                follow the swipe), pill search field with clear button, popular
                foods shown as real illustrated medallions instead of emoji text
FOOD LISTS      search results and Quick list now share one card: medallion,
                name, icon macro row (protein / carbs / fat), kcal, add button
PICKERS         grams / portion sheets use the larger medallion and a cleaner
                macro summary
FOOD DETAIL     centered hero, tag chips with icons, calorie ring + a protein /
                carbs / fat split bar, macro cards with icon badges, micronutrient
                tiles with element symbols (C, Fe, Ca, K, D, Mg) instead of emoji
EMOJI           no emoji left in this flow. Food images sit on a soft round
                medallion (radial tint + hairline ring + gentle shadow); foods
                with no illustration get a restaurant icon, not a flat emoji
pubspec         -> 1.13.0+27
"""
import os, re, sys

ROOT = os.getcwd()
if not os.path.exists(os.path.join(ROOT, 'pubspec.yaml')):
    sys.exit('Run this from the repo root (pubspec.yaml not found).')

ok = skip = 0
def path(p): return os.path.join(ROOT, p)

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

print('== v55 ==')
FE = 'lib/core/food_emoji.dart'
NU = 'lib/features/nutrition/nutrition_screen.dart'

# ───────────────────────────────────────────────────────────
# 1. FoodThumb -> round medallion, no emoji fallback
# ───────────────────────────────────────────────────────────
THUMB_TAIL = r'''  // PATCH_V55_MEDALLION
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final s = widget.size;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.05,
          colors: dark
              ? [primary.withOpacity(0.24), primary.withOpacity(0.05)]
              : [primary.withOpacity(0.15), primary.withOpacity(0.04)],
        ),
        border: Border.all(
            color: primary.withOpacity(dark ? 0.30 : 0.20), width: 0.8),
        boxShadow: s >= 44
            ? [
                BoxShadow(
                    color: primary.withOpacity(dark ? 0.20 : 0.12),
                    blurRadius: s * 0.34,
                    offset: Offset(0, s * 0.08)),
              ]
            : const <BoxShadow>[],
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(s * 0.16),
          child: _content(s * 0.68),
        ),
      ),
    );
  }

  Widget _content(double inner) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_assetPath != null) {
      return darkSafeAsset(
        _assetPath!,
        fit: BoxFit.contain,
        width: inner,
        height: inner,
        isDark: dark,
        errorChild: _fallback(inner),
      );
    }
    if (_url != null) {
      return Image.network(
        _url!,
        fit: BoxFit.cover,
        width: inner,
        height: inner,
        errorBuilder: (_, __, ___) => _fallback(inner),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _fallback(inner),
      );
    }
    return _fallback(inner);
  }

  Widget _fallback(double inner) => Center(
        child: Icon(Icons.restaurant_rounded,
            size: inner * 0.62,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.85)),
      );
}
'''
def thumb(s):
    if 'PATCH_V55_MEDALLION' in s: return s
    i = s.find('  @override\n  Widget build(BuildContext context) {\n    // PATCH_V54_THUMB')
    if i < 0:
        i = s.find('  @override\n  Widget build(BuildContext context) {\n    final bg = widget.background')
    j = s.find('  Widget _glyphView(String glyph) => Center(')
    if i < 0 or j < 0: return None
    k = s.find('}\n', s.find(');\n', j)) + 2   # end of class
    return s[:i] + THUMB_TAIL + s[k:]
edit(FE, thumb, 'FoodThumb medallion')

# ───────────────────────────────────────────────────────────
# 2. nutrition_screen: Add Food sheet
# ───────────────────────────────────────────────────────────
ADD_BUILD_HEAD = r'''  // PATCH_V55_ADDFOOD
  Widget _segTabs(bool isAr, bool isDark, Color muted) {
    final items = <(IconData, String)>[
      (Icons.auto_awesome_rounded, 'AI'),
      (Icons.bolt_rounded, isAr ? 'سريع' : 'Quick'),
      (Icons.edit_rounded, isAr ? 'يدوي' : 'Manual'),
    ];
    final ink = isDark ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ink.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ink.withOpacity(0.07), width: 0.8),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final sel = _tab.index == i;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _tab.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: sel
                      ? const LinearGradient(
                          colors: [Color(0xFF2BB567), Color(0xFF1E9E52)])
                      : null,
                  boxShadow: sel
                      ? [
                          BoxShadow(
                              color: const Color(0xFF1E9E52).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ]
                      : const <BoxShadow>[],
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1,
                          size: 16, color: sel ? Colors.white : muted),
                      const SizedBox(width: 6),
                      Text(items[i].$2,
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : muted)),
                    ]),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _searchField({
    required TextEditingController controller,
    required String hint,
    required bool isAr,
    required bool isDark,
    required Color textC,
    required Color muted,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    IconData icon = Icons.search_rounded,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: textC.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: textC.withOpacity(0.10), width: 0.8),
      ),
      child: Row(children: [
        Icon(icon, color: AppColors.brandGreen, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
            onChanged: onChanged,
            style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 14.5, color: textC),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: TextStyle(
                  fontFamily: 'Aligarh', fontSize: 13.5, color: muted),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: () {
                    controller.clear();
                    if (onChanged != null) onChanged('');
                  },
                  child: Icon(Icons.close_rounded, size: 18, color: muted),
                ),
        ),
      ]),
    );
  }

  Widget _macroInline(num p, num c, num f, Color muted) {
    Widget one(IconData ic, Color col, num v) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 12, color: col),
          const SizedBox(width: 3),
          Text('${v.toStringAsFixed(1)}g',
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: muted)),
        ]);
    return Wrap(spacing: 10, runSpacing: 2, children: [
      one(Icons.fitness_center_rounded, AppColors.halalGreen, p),
      one(Icons.grain_rounded, AppColors.waterBlue, c),
      one(Icons.water_drop_rounded, AppColors.accentGold, f),
    ]);
  }

  Widget _foodRow({
    required String name,
    required String thumb,
    String? imageUrl,
    required num kcal,
    required num protein,
    required num carbs,
    required num fat,
    String sub = '',
    String source = '',
    required VoidCallback onTap,
    required bool isDark,
    required Color textC,
    required Color muted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.045) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: isDark ? AppColors.darkBorder2 : AppColors.lightBorder2,
                width: 0.9),
            boxShadow: isDark
                ? const <BoxShadow>[]
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Row(children: [
            FoodThumb(name: thumb, imageUrl: imageUrl, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: textC)),
                    const SizedBox(height: 4),
                    _macroInline(protein, carbs, fat, muted),
                    if (sub.isNotEmpty || source.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Flexible(
                          child: Text(sub,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: 'Aligarh',
                                  fontSize: 9.5,
                                  color: muted.withOpacity(0.85))),
                        ),
                        if (source.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _sourceBadge(source),
                        ],
                      ]),
                    ],
                  ]),
            ),
            const SizedBox(width: 8),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${kcal.round()}',
                  style: const TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.halalGreen)),
              Text('kcal',
                  style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 9, color: muted)),
            ]),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2BB567), Color(0xFF1E9E52)]),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1E9E52).withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.add_rounded,
                  color: Colors.white, size: 21),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _popular(bool isAr, bool isDark, Color textC, Color muted) {
    const items = <(String, String, String)>[
      ('تمر', 'Dates', 'date'),
      ('عسل', 'Honey', 'honey'),
      ('بيض', 'Egg', 'egg'),
      ('دجاج', 'Chicken', 'chicken'),
      ('حليب', 'Milk', 'milk'),
      ('أرز', 'Rice', 'rice'),
      ('زيتون', 'Olive oil', 'olive'),
      ('شوفان', 'Oats', 'oat'),
      ('حلوى', 'Sweets', 'candy'),
      ('كيك', 'Cake', 'cake'),
      ('شوكولاتة', 'Chocolate', 'chocolate'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.trending_up_rounded,
            size: 16, color: AppColors.accentGold),
        const SizedBox(width: 6),
        Text(isAr ? 'شائع' : 'Popular',
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: muted)),
      ]),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final it in items)
            GestureDetector(
              onTap: () {
                _searchCtrl.text = isAr ? it.$1 : it.$2;
                _search();
              },
              child: Container(
                padding: const EdgeInsetsDirectional.fromSTEB(6, 5, 14, 5),
                decoration: BoxDecoration(
                  color: textC.withOpacity(isDark ? 0.06 : 0.04),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: textC.withOpacity(0.10), width: 0.8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  FoodThumb(name: it.$3, size: 30, allowNetwork: false),
                  const SizedBox(width: 8),
                  Text(isAr ? it.$1 : it.$2,
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: textC)),
                ]),
              ),
            ),
        ],
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isAr   = widget.isAr;
    final isDark = widget.isDark;
    final textC  = isDark ? AppColors.darkText : AppColors.lightText;
    final muted  = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    String tl(String ar, String en) => isAr ? ar : en;
    final bodyH =
        (MediaQuery.of(context).size.height * 0.56).clamp(320.0, 560.0).toDouble();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF12241B), Color(0xFF0A1511)]
              : const [Colors.white, Color(0xFFF3F7F3)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(
            top: BorderSide(
                color: AppColors.brandGreen.withOpacity(isDark ? 0.30 : 0.14),
                width: 1)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 6),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: textC.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2)),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.brandGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.brandGreen.withOpacity(0.20)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.volunteer_activism_rounded,
                size: 15, color: AppColors.accentGold),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                L.fromLang(lang).mindfulEatingTip,
                style: const TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 11,
                    color: AppColors.halalGreen,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.brandGreen.withOpacity(0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.restaurant_menu_rounded,
                  color: AppColors.halalGreen, size: 21),
            ),
            const SizedBox(width: 12),
            Text(tl('أضف طعام', 'Add Food'),
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textC)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                if (context.mounted) Navigator.pop(context);
              },
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: textC.withOpacity(0.07),
                ),
                child: Icon(Icons.close_rounded, size: 19, color: muted),
              ),
            ),
          ]),
        ),
        _segTabs(isAr, isDark, muted),
        SizedBox(
          height: bodyH,
          child: TabBarView(controller: _tab, children: [
            // ── AI SEARCH ────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: _searchField(
                      controller: _searchCtrl,
                      hint: tl('تفاحة، دجاج، أرز...', 'apple, chicken, rice...'),
                      isAr: isAr,
                      isDark: isDark,
                      textC: textC,
                      muted: muted,
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _searching ? null : _search,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: _searching
                            ? null
                            : const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF2BB567), Color(0xFF1E9E52)]),
                        color: _searching ? Colors.grey : null,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF1E9E52).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(15),
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.search_rounded,
                              color: Colors.white, size: 24),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                if (_results.isEmpty && !_searching)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _popular(isAr, isDark, textC, muted),
                  ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: Column(children: [
                      const CircularProgressIndicator(
                          color: AppColors.brandGreen, strokeWidth: 2.5),
                      const SizedBox(height: 12),
                      Text(tl('نبحث في كل المصادر...', 'Searching every source...'),
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 11.5,
                              color: muted)),
                    ]),
                  ),
                if (!_searching && _results.isNotEmpty)
                  _buildResultList(isAr, muted),
                if (!_searching && _searched && _results.isEmpty)
                  _buildNoResults(muted),
              ]),
            ),

            // ── QUICK ADD ────────────────────────────────
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: _searchField(
                  controller: _quickCtrl,
                  hint: tl('بحث سريع...', 'Quick search...'),
                  isAr: isAr,
                  isDark: isDark,
                  textC: textC,
                  muted: muted,
                  icon: Icons.filter_list_rounded,
                  onChanged: (v) => setState(() => _filter = v.toLowerCase()),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  children: [
                    for (final food in kQuickFoods.where((f) =>
                        _filter.isEmpty ||
                        f.name.toLowerCase().contains(_filter) ||
                        f.nameEn.toLowerCase().contains(_filter)))
                      _foodRow(
                        name: isAr ? food.name : food.nameEn,
                        thumb: '${food.nameEn} ${food.name}',
                        kcal: food.kcal,
                        protein: food.proteinG,
                        carbs: food.carbsG,
                        fat: food.fatG,
                        isDark: isDark,
                        textC: textC,
                        muted: muted,
                        onTap: () => _showUnitPicker(
                            name: isAr ? food.name : food.nameEn,
                            kcal100: food.kcal.toDouble(),
                            protein100: food.proteinG,
                            carbs100: food.carbsG,
                            fat100: food.fatG),
                      ),
                  ],
                ),
              ),
            ]),

'''
ADD_BUILD_FOOT = r'''          ]),
        ),
      ]),
    );
  }

'''
RESULT_BLOCK = r'''  // PATCH_V55_ADDFOOD
  Widget _buildResultList(bool isAr, Color muted) {
    String tl(String ar, String en) => tLang(lang, ar, en);
    final isDark = widget.isDark;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(tl('النتائج', 'Results'),
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: muted)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.brandGreen.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${_results.length}',
                style: const TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.halalGreen)),
          ),
        ]),
      ),
      ..._results.map((r) => _resultTile(r, isAr, muted, isDark, textC)),
      const SizedBox(height: 6),
      Center(
        child: TextButton.icon(
          onPressed: () {
            _nameCtrl.text = _searchCtrl.text.trim();
            _tab.animateTo(2);
          },
          icon: const Icon(Icons.edit_rounded,
              size: 16, color: AppColors.halalGreen),
          label: Text(
              tl('لم تجد طعامك؟ أدخله يدوياً', 'Not listed? Enter it manually'),
              style: const TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.halalGreen)),
        ),
      ),
    ]);
  }

  Widget _resultTile(Map<String, dynamic> r, bool isAr, Color muted,
      bool isDark, Color textC) {
    final name = (isAr
            ? (r['name_ar'] ?? r['name_en'] ?? '')
            : (r['name_en'] ?? r['name_ar'] ?? ''))
        .toString();
    final basis = r['basis'] == 'portion'
        ? (r['serving_size']?.toString() ?? '')
        : '100g';
    return _foodRow(
      name: name,
      thumb: name,
      imageUrl: r['image_url'] as String?,
      kcal: (r['kcal'] as num? ?? 0),
      protein: (r['protein_g'] as num? ?? 0),
      carbs: (r['carbs_g'] as num? ?? 0),
      fat: (r['fat_g'] as num? ?? 0),
      sub: basis,
      source: r['source']?.toString() ?? '',
      isDark: isDark,
      textC: textC,
      muted: muted,
      onTap: () => _openResult(r),
    );
  }

'''
GRAM_MACRO = r'''  Widget _gramMacro(String val, String label, Color color) =>
    Column(mainAxisSize: MainAxisSize.min, children: [
      Text(val, style: TextStyle(fontFamily: 'Aligarh', fontSize: 15,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 3),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontFamily: 'Aligarh', fontSize: 9.5,
            color: color.withOpacity(0.85))),
      ]),
    ]);
'''

def add_food(s):
    if 'PATCH_V55_ADDFOOD' in s: return s
    cls = s.find('class _AddFoodSheetState')
    if cls < 0: return None
    # build()
    b0 = s.find('  @override\n  Widget build(BuildContext context) {', cls)
    man = s.find('            // ── MANUAL ENTRY', b0)
    tail_marker = '          ]),\n        ),\n      ]),\n    );\n  }\n'
    b1 = s.find(tail_marker, man)
    if b0 < 0 or man < 0 or b1 < 0: return None
    manual_block = s[man:b1]
    new_build = ADD_BUILD_HEAD + manual_block + ADD_BUILD_FOOT
    s = s[:b0] + new_build + s[b1 + len(tail_marker):]
    # results list/tile
    r0 = s.find('  Widget _buildResultList(bool isAr, Color muted) {', cls)
    r1 = s.find('  /// Tiny label showing where a result came from.', r0)
    if r0 < 0 or r1 < 0: return None
    s = s[:r0] + RESULT_BLOCK + s[r1:]
    # fields / init / dispose
    s = s.replace("  final _searchCtrl  = TextEditingController();\n",
                  "  final _searchCtrl  = TextEditingController();\n  final _quickCtrl   = TextEditingController();\n", 1)
    s = s.replace("    _searchCtrl.dispose(); _nameCtrl.dispose();",
                  "    _searchCtrl.dispose(); _quickCtrl.dispose(); _nameCtrl.dispose();", 1)
    ti = s.find("    _tab = TabController(length: 3, vsync: this);", cls)
    if ti < 0: return None
    s = (s[:ti] + "    _tab = TabController(length: 3, vsync: this);\n"
         "    _tab.addListener(() { if (mounted) setState(() {}); });"
         + s[ti + len("    _tab = TabController(length: 3, vsync: this);"):])
    # pickers: bigger medallion
    s = re.sub(r"FoodThumb\(name: name, size: 52, radius: 14,\s*background: AppColors\.brandGreen\.withOpacity\(0\.1\)\),",
               "FoodThumb(name: name, size: 58),", s)
    # macro summary
    g0 = s.find('  Widget _gramMacro(String val, String label, Color color) =>')
    g1 = s.find('  Widget _vDivider()', g0)
    if g0 >= 0 and g1 >= 0:
        s = s[:g0] + GRAM_MACRO + '\n' + s[g1:]
    return s
edit(NU, add_food, 'Add Food sheet rebuilt')

# ───────────────────────────────────────────────────────────
# 3. nutrition_screen: food detail sheet
# ───────────────────────────────────────────────────────────
DETAIL_BLOCK = r'''              // PATCH_V55_DETAIL
              Center(child: FoodThumb(name: e.name, size: 104)),
              const SizedBox(height: 12),
              Text(e.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textC)),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: tags
                        .map((t) => _detailTag(t['l'] as String,
                            t['c'] as Color, _tagIcon(t['e'] as String)))
                        .toList()),
              ],
              const SizedBox(height: 18),

              // Calories + split
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _acc.withOpacity(isDark ? 0.16 : 0.10),
                      _acc.withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _acc.withOpacity(0.22)),
                ),
                child: Column(children: [
                  Row(children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: Stack(alignment: Alignment.center, children: [
                        SizedBox.expand(
                            child: CircularProgressIndicator(
                                value: pctKcal,
                                strokeWidth: 9,
                                backgroundColor: _acc.withOpacity(0.14),
                                valueColor: AlwaysStoppedAnimation(_acc),
                                strokeCap: StrokeCap.round)),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${e.kcal}',
                              style: TextStyle(
                                  fontFamily: 'Aligarh',
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  color: textC)),
                          Text(
                              tLang(lang, 'سعرة', 'kcal', 'kcal', 'kcal',
                                  'kcal', 'kkal'),
                              style: TextStyle(
                                  fontFamily: 'Aligarh',
                                  fontSize: 10,
                                  color: muted)),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${(pctKcal * 100).toInt()}％',
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    color: _acc)),
                            Text(
                                tLang(
                                    lang,
                                    'من هدفك اليومي',
                                    'of your daily goal',
                                    'de votre objectif quotidien',
                                    'günlük hedefinizin',
                                    'daripada matlamat harian anda',
                                    'dari target harian Anda'),
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 11.5,
                                    color: muted)),
                            const SizedBox(height: 3),
                            Text(
                                '${goal.toInt()} ${isAr ? "سعرة كهدف" : "kcal goal"}',
                                style: TextStyle(
                                    fontFamily: 'Aligarh',
                                    fontSize: 11,
                                    color: muted.withOpacity(0.7))),
                          ]),
                    ),
                  ]),
                  _splitBar(e, isAr, muted),
                ]),
              ),
              const SizedBox(height: 22),

              // Macros
              _sectionHead(
                  Icons.pie_chart_rounded,
                  AppColors.sleepPurple,
                  tLang(lang, 'المغذيات الكبرى', 'Macronutrients',
                      'Macronutriments', 'Makrobesinler', 'Makronutrien',
                      'Makronutrien'),
                  textC),
              const SizedBox(height: 10),
              _detailBar(
                  tLang(lang, 'بروتين', 'Protein', 'Protéines', 'Protein',
                      'Protein', 'Protein'),
                  e.proteinG,
                  pGoal,
                  pctP,
                  AppColors.halalGreen,
                  tLang(lang, 'يبني العضلات', 'Builds muscle',
                      'Construit du muscle', 'Kas yapar', 'Membina otot',
                      'Membangun otot'),
                  isDark,
                  Icons.fitness_center_rounded),
              const SizedBox(height: 10),
              _detailBar(
                  tLang(lang, 'كربوهيدرات', 'Carbs', 'Glucides',
                      'Karbonhidrat', 'Karbohidrat', 'Karbohidrat'),
                  e.carbsG,
                  cGoal,
                  pctC,
                  AppColors.waterBlue,
                  tLang(lang, 'طاقة سريعة', 'Quick energy', 'Énergie rapide',
                      'Hızlı enerji', 'Tenaga pantas', 'Energi cepat'),
                  isDark,
                  Icons.bolt_rounded),
              const SizedBox(height: 10),
              _detailBar(
                  tLang(lang, 'دهون', 'Fat', 'Lipides', 'Yağ', 'Lemak',
                      'Lemak'),
                  e.fatG,
                  fGoal,
                  pctF,
                  AppColors.accentGold,
                  tLang(lang, 'صحة الدماغ', 'Brain health', 'Santé cérébrale',
                      'Beyin sağlığı', 'Kesihatan otak', 'Kesehatan otak'),
                  isDark,
                  Icons.psychology_rounded),
              const SizedBox(height: 22),

              // Micronutrients
              _sectionHead(
                  Icons.science_rounded,
                  AppColors.accentGold,
                  tLang(lang, 'مغذيات دقيقة (تقديرية)',
                      'Micronutrients (estimated)'),
                  textC),
              const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.accentGold
                          .withOpacity(isDark ? 0.07 : 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.accentGold.withOpacity(0.2))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(spacing: 8, runSpacing: 14, children: [
                          _microTile('C', 'Vit C', '–', muted),
                          _microTile('Fe',
                              tLang(lang, 'حديد', 'Iron', 'Fer', 'Demir',
                                  'Zat Besi', 'Zat Besi'),
                              '–', muted),
                          _microTile('Ca',
                              tLang(lang, 'كالسيوم', 'Calcium'), '–', muted),
                          _microTile('K',
                              tLang(lang, 'بوتاسيوم', 'Potassium'), '–',
                              muted),
                          _microTile('D', tLang(lang, 'فيتامين د', 'Vit D'),
                              '–', muted),
                          _microTile('Mg',
                              tLang(lang, 'ماغنيسيوم', 'Magnesium'), '–',
                              muted),
                        ]),
                        const SizedBox(height: 10),
                        Text(
                          tLang(
                              lang,
                              '* القيم التفصيلية متاحة عند التحليل بالكاميرا (مميزات مدفوعة)',
                              '* Detailed values available via AI photo scan (premium)'),
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 9.5,
                              color: muted),
                        ),
                      ])),
              const SizedBox(height: 16),

              // Food note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _acc.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _acc.withOpacity(0.22))),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: _acc.withOpacity(0.16), shape: BoxShape.circle),
                    child: Icon(Icons.menu_book_rounded, size: 18, color: _acc),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(foodNote(),
                          style: TextStyle(
                              fontFamily: 'Aligarh',
                              fontSize: 12,
                              color: isDark ? AppColors.darkText : _acc,
                              height: 1.6))),
                ]),
              ),
              const SizedBox(height: 20),

'''
DETAIL_HELPERS = r'''  // PATCH_V55_DETAIL helpers
  Color get _acc =>
      ref.read(ramadanModeProvider) ? AppColors.accentGold : AppColors.brandGreen;

  IconData _tagIcon(String emoji) {
    switch (emoji) {
      case '💪': return Icons.fitness_center_rounded;
      case '🥗': return Icons.grass_rounded;
      case '✨': return Icons.auto_awesome_rounded;
      case '🌿': return Icons.eco_rounded;
      case '🔥': return Icons.local_fire_department_rounded;
      default:   return Icons.label_rounded;
    }
  }

  Widget _detailTag(String label, Color c, IconData ic) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withOpacity(0.13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withOpacity(0.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 13, color: c),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: c)),
        ]),
      );

  Widget _sectionHead(IconData ic, Color c, String text, Color textC) =>
      Row(children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
              color: c.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(ic, size: 16, color: c),
        ),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: textC)),
      ]);

  Widget _splitBar(MealEntry e, bool isAr, Color muted) {
    final pK = e.proteinG * 4, cK = e.carbsG * 4, fK = e.fatG * 9;
    final tot = pK + cK + fK;
    if (tot <= 0) return const SizedBox.shrink();
    int fl(double v) => (v * 100).round().clamp(1, 100000).toInt();
    String pc(double v) => '${(v / tot * 100).round()}％';
    Widget leg(String l, double v, Color c) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('$l ${pc(v)}',
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: muted)),
        ]);
    return Column(children: [
      const SizedBox(height: 16),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 9,
          child: Row(children: [
            Expanded(flex: fl(pK), child: const ColoredBox(color: AppColors.halalGreen)),
            const SizedBox(width: 2),
            Expanded(flex: fl(cK), child: const ColoredBox(color: AppColors.waterBlue)),
            const SizedBox(width: 2),
            Expanded(flex: fl(fK), child: const ColoredBox(color: AppColors.accentGold)),
          ]),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        leg(isAr ? 'بروتين' : 'Protein', pK, AppColors.halalGreen),
        leg(isAr ? 'كارب' : 'Carbs', cK, AppColors.waterBlue),
        leg(isAr ? 'دهون' : 'Fat', fK, AppColors.accentGold),
      ]),
    ]);
  }

  Widget _detailBar(String label, double val, double goal, double pct,
      Color color, String note, bool isDark, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.07), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: color.withOpacity(0.14), shape: BoxShape.circle),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const Spacer(),
          Text('${val.toStringAsFixed(1)}g',
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: color)),
          Text(' / ${goal.toInt()}g',
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 11,
                  color: color.withOpacity(0.6))),
          const SizedBox(width: 8),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10)),
              child: Text('${(pct * 100).toInt()}％',
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: color))),
        ]),
        const SizedBox(height: 10),
        Stack(children: [
          Container(
              height: 8,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6))),
          LayoutBuilder(
              builder: (_, c) => Container(
                  height: 8,
                  width: c.maxWidth * pct,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color.withOpacity(0.6), color]),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                            color: color.withOpacity(0.3), blurRadius: 4)
                      ]))),
        ]),
        const SizedBox(height: 6),
        Text(note,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 10.5,
                color: color.withOpacity(0.8))),
      ]),
    );
  }

  Widget _microTile(String sym, String label, String val, Color muted) =>
      SizedBox(
          width: 82,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withOpacity(0.14),
                border: Border.all(
                    color: AppColors.accentGold.withOpacity(0.35), width: 0.8),
              ),
              child: Text(sym,
                  style: const TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentGold)),
            ),
            const SizedBox(height: 5),
            Text(val,
                style: const TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentGold)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 9.5, color: muted)),
          ]));

'''
def detail(s):
    if 'PATCH_V55_DETAIL' in s: return s
    h0 = s.find('              // Hero\n')
    h1 = s.find('              // Buttons\n', h0)
    if h0 < 0 or h1 < 0: return None
    s = s[:h0] + DETAIL_BLOCK + s[h1:]
    d0 = s.find('  Widget _detailBar(String label, double val, double goal,')
    d1 = s.find('  Widget _macroCard(', d0)
    if d0 < 0 or d1 < 0: return None
    s = s[:d0] + DETAIL_HELPERS + '\n' + s[d1:]
    s = s.replace("                    const Text('✅ ', style: TextStyle(fontSize: 16)),",
                  "                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),\n"
                  "                    const SizedBox(width: 8),", 1)
    return s
edit(NU, detail, 'Food detail sheet rebuilt')

def ver(s):
    if 'version: 1.13.0+27' in s: return s
    n = re.sub(r"^version: \d+\.\d+\.\d+\+\d+", 'version: 1.13.0+27', s, count=1, flags=re.M)
    return n if n != s else None
edit('pubspec.yaml', ver, 'version 1.13.0+27')

print('\n== sanity ==')
balance_check([FE, NU])
print(f'\nDone: {ok} applied, {skip} skipped.')
print('Next:  git add -A && git commit -m "v55: food flow" && git push')
