// food_detail_screen.dart — HalalCalorie v64 (PATCH_V64_FOOD_DETAIL)
//
// Full-screen page opened when a food is tapped in the Add Food flow. It
// replaces the two small bottom sheets (grams / portions) with one place that
// shows: the food, real local servings (رغيف، طبق، قرص…), a live calorie count,
// a macro ring, how the food fits today's calorie budget, and a one-tap log.
// Everything shown is computed from the food's own numbers — nothing invented.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/l10n.dart';
import '../../core/num_input.dart';
import '../../core/food_emoji.dart';
import '../../core/mena_foods.dart';
import '../../core/providers.dart';

/// Everything the page needs to know about a food.
class FoodDetailSpec {
  final String name;

  /// The same food in the other language; empty when unknown.
  final String altName;

  /// Text handed to [FoodThumb] to pick the picture.
  final String thumbKey;
  final String? imageUrl;

  /// Per 100 g (100 ml for liquids) — or per ONE serving when [perServing].
  final double kcal, protein, carbs, fat;

  /// True when the numbers describe one listed portion (e.g. "Boiled egg").
  final bool perServing;
  final String servingLabelAr, servingLabelEn;

  /// Local servings with their weight; empty for generic gram entry.
  final List<MenaServing> servings;
  final bool isLiquid;

  /// 'mena' | 'builtin' | 'offline' | 'openfoodfacts' | 'ai' | ''.
  final String source;
  final String regionAr, regionEn, categoryAr, categoryEn;

  /// Hero tint.
  final Color tint;

  const FoodDetailSpec({
    required this.name,
    this.altName = '',
    required this.thumbKey,
    this.imageUrl,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.perServing = false,
    this.servingLabelAr = 'حصة',
    this.servingLabelEn = 'serving',
    this.servings = const [],
    this.isLiquid = false,
    this.source = '',
    this.regionAr = '',
    this.regionEn = '',
    this.categoryAr = '',
    this.categoryEn = '',
    this.tint = AppColors.brandGreen,
  });

  /// A food from the Arabic-kitchen database, with its local servings.
  factory FoodDetailSpec.fromMena(MenaFood m, {required bool isAr}) {
    var catAr = '', catEn = '';
    for (final c in kMenaCategories) {
      if (c.$1 == m.cat) {
        catAr = c.$2;
        catEn = c.$3;
      }
    }
    final reg = kMenaRegions[m.region];
    return FoodDetailSpec(
      name: isAr ? m.ar : m.en,
      altName: isAr ? m.en : m.ar,
      thumbKey: '${m.en} ${m.ar}',
      kcal: m.kcal,
      protein: m.protein,
      carbs: m.carbs,
      fat: m.fat,
      servings: m.servings,
      isLiquid: m.isLiquid,
      source: 'mena',
      regionAr: reg?.$1 ?? '',
      regionEn: reg?.$2 ?? '',
      categoryAr: catAr,
      categoryEn: catEn,
      tint: menaTint(m.cat),
    );
  }
}

/// Hero tint per food category.
Color menaTint(String cat) => switch (cat) {
      'drinks' => AppColors.waterBlue,
      'sweets' || 'dates' => AppColors.accentGold,
      'fruit' || 'veg' => AppColors.halalGreen,
      'grills' || 'mains' || 'rice' => AppColors.doubtOrange,
      _ => AppColors.brandGreen,
    };

/// Opens the page. [onLog] runs after the page has closed.
Future<void> openFoodDetail(
  BuildContext context, {
  required FoodDetailSpec spec,
  required bool isDark,
  required Future<void> Function(
          String name, int kcal, double protein, double carbs, double fat)
      onLog,
}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) =>
        FoodDetailScreen(spec: spec, isDark: isDark, onLog: onLog),
    transitionsBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  ));
}

class FoodDetailScreen extends ConsumerStatefulWidget {
  final FoodDetailSpec spec;
  final bool isDark;
  final Future<void> Function(
          String name, int kcal, double protein, double carbs, double fat)
      onLog;

  const FoodDetailScreen({
    super.key,
    required this.spec,
    required this.isDark,
    required this.onLog,
  });

  @override
  ConsumerState<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends ConsumerState<FoodDetailScreen> {
  static const Color _pColor = AppColors.halalGreen;
  static const Color _cColor = AppColors.waterBlue;
  static const Color _fColor = AppColors.accentGold;

  late final List<MenaServing> _chips;
  late int _sel;
  double _qty = 1.0;
  double _customGrams = 100;
  final TextEditingController _gramCtrl = TextEditingController(text: '100');

  FoodDetailSpec get _s => widget.spec;
  bool get _perServing => _s.perServing;
  bool get _custom => !_perServing && _sel >= _chips.length;

  @override
  void initState() {
    super.initState();
    if (_s.servings.isNotEmpty) {
      _chips = _s.servings;
      _sel = 0;
    } else {
      _chips = [
        for (final g in const [50, 100, 150, 200, 250])
          MenaServing('$g ${_s.isLiquid ? "مل" : "جم"}',
              '$g ${_s.isLiquid ? "ml" : "g"}', g.toDouble()),
      ];
      _sel = 1;
    }
  }

  @override
  void dispose() {
    _gramCtrl.dispose();
    super.dispose();
  }

  // ── Numbers ───────────────────────────────────────────────────────────────
  double get _grams =>
      _custom ? _customGrams : _chips[_sel].grams * _qty;
  double get _mult => _perServing ? _qty : _grams / 100.0;
  double get _kcal => _s.kcal * _mult;
  double get _protein => _s.protein * _mult;
  double get _carbs => _s.carbs * _mult;
  double get _fat => _s.fat * _mult;

  String _fmt(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
  String _g1(double v) => '${v.toStringAsFixed(v < 10 ? 1 : 0)} g';

  String _tl(String ar, String en) =>
      tLang(ref.read(languageProvider), ar, en);

  bool get _isAr => ref.read(languageProvider) == 'ar';

  String get _unit => _isAr ? (_s.isLiquid ? 'مل' : 'جم') : (_s.isLiquid ? 'ml' : 'g');

  /// Short text describing the chosen amount, appended to the diary entry.
  String _amountLabel() {
    if (_perServing) {
      return '${_fmt(_qty)} × ${_isAr ? _s.servingLabelAr : _s.servingLabelEn}';
    }
    if (_custom) return '${_fmt(_customGrams)} $_unit';
    final c = _chips[_sel];
    final label = _isAr ? c.ar : c.en;
    return _qty == 1.0 ? label : '${_fmt(_qty)} × $label';
  }

  // ── Interaction ───────────────────────────────────────────────────────────
  void _setSel(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _sel = i;
      if (i < _chips.length) _qty = 1.0;
    });
  }

  void _stepQty(double d) {
    HapticFeedback.selectionClick();
    setState(() => _qty = (_qty + d).clamp(0.5, 20.0).toDouble());
  }

  void _stepGrams(double d) {
    HapticFeedback.selectionClick();
    setState(() {
      _customGrams = (_customGrams + d).clamp(5.0, 5000.0).toDouble();
      _gramCtrl.text = _fmt(_customGrams);
    });
  }

  void _log() {
    final kcal = _kcal.round();
    if (kcal <= 0) return;
    HapticFeedback.mediumImpact();
    final label = _amountLabel();
    final logged = '${_s.name} ($label)';
    final p = _protein, c = _carbs, f = _fat;
    Navigator.of(context).pop();
    widget.onLog(logged, kcal, p, c, f);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bg = isDark ? AppColors.darkBg : AppColors.lightBg;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    final muted = isDark ? AppColors.darkMuted : AppColors.lightMuted;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final border = isDark ? AppColors.darkBorder2 : AppColors.lightBorder2;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _hero(textC, muted),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _amountCard(card, border, textC, muted),
                      const SizedBox(height: 14),
                      _macroCard(card, border, textC, muted),
                      const SizedBox(height: 14),
                      _budgetCard(card, border, textC, muted),
                      const SizedBox(height: 14),
                      _insights(textC, muted),
                      _factsCard(card, border, textC, muted),
                      const SizedBox(height: 10),
                      _sourceNote(muted),
                    ]),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Row(children: [
                _roundBtn(Icons.arrow_back_rounded, () {
                  Navigator.of(context).pop();
                }, isDark),
              ]),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _logBar(isDark, bg)),
      ]),
    );
  }

  Widget _roundBtn(IconData ic, VoidCallback onTap, bool isDark) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
          ),
          child: Icon(ic, color: isDark ? Colors.white : AppColors.lightText),
        ),
      );

  // ── Hero ──────────────────────────────────────────────────────────────────
  Widget _hero(Color textC, Color muted) {
    final s = _s;
    final isAr = _isAr;
    final region = isAr ? s.regionAr : s.regionEn;
    final cat = isAr ? s.categoryAr : s.categoryEn;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            s.tint.withOpacity(widget.isDark ? 0.42 : 0.30),
            s.tint.withOpacity(0.0),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          const SizedBox(height: 44),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.82, end: 1.0),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: s.tint.withOpacity(0.35),
                      blurRadius: 48,
                      spreadRadius: 2),
                ],
              ),
              child: FoodThumb(
                  name: s.thumbKey, imageUrl: s.imageUrl, size: 156),
            ),
          ),
          const SizedBox(height: 16),
          Text(s.name,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: textC)),
          if (s.altName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(s.altName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 13, color: muted)),
          ],
          if (region.isNotEmpty || cat.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (region.isNotEmpty) _tag(region, s.tint),
                if (cat.isNotEmpty) _tag(cat, muted),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color)),
      );

  // ── Amount ────────────────────────────────────────────────────────────────
  BoxDecoration _cardDeco(Color card, Color border) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border, width: 0.9),
      );

  Widget _label(String text, Color muted) => Text(text,
      style: TextStyle(
          fontFamily: 'Aligarh',
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: muted));

  Widget _amountCard(Color card, Color border, Color textC, Color muted) {
    final isAr = _isAr;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _cardDeco(card, border),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: _kcal),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${v.round()}',
                        style: const TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 52,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                            color: AppColors.halalGreen)),
                    const SizedBox(width: 6),
                    Text(_tl('سعرة', 'kcal'),
                        style: TextStyle(
                            fontFamily: 'Aligarh',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: muted)),
                  ]),
            ),
          ),
          if (!_perServing)
            Text('${_fmt(_grams)} $_unit',
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: muted)),
        ]),
        const SizedBox(height: 16),
        _label(
            _perServing
                ? _tl('عدد الحصص', 'Servings')
                : _tl('اختر الكمية', 'Choose an amount'),
            muted),
        const SizedBox(height: 10),
        if (!_perServing)
          SizedBox(
            height: 62,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _chips.length; i++)
                  _servingChip(
                    label: isAr ? _chips[i].ar : _chips[i].en,
                    sub: '${_fmt(_chips[i].grams)} $_unit',
                    active: _sel == i,
                    onTap: () => _setSel(i),
                  ),
                _servingChip(
                  label: _tl('مخصص', 'Custom'),
                  sub: _tl('بالجرام', 'grams'),
                  active: _custom,
                  icon: Icons.tune_rounded,
                  onTap: () => _setSel(_chips.length),
                ),
              ],
            ),
          ),
        if (!_perServing) const SizedBox(height: 14),
        if (_custom) _gramField(textC, muted) else _qtyStepper(textC, muted),
        if (_perServing) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in const [1, 2, 3, 4, 5, 6])
              _servingChip(
                label: '$n',
                sub: '',
                active: (_qty - n).abs() < 0.001,
                compact: true,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _qty = n.toDouble());
                },
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _servingChip({
    required String label,
    required String sub,
    required bool active,
    required VoidCallback onTap,
    IconData? icon,
    bool compact = false,
  }) {
    final isDark = widget.isDark;
    final textC = isDark ? AppColors.darkText : AppColors.lightText;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.brandGreen
              : AppColors.brandGreen.withOpacity(isDark ? 0.14 : 0.08),
          borderRadius: BorderRadius.circular(compact ? 20 : 18),
          border: Border.all(
              color: active
                  ? AppColors.halalGreen
                  : AppColors.brandGreen.withOpacity(0.18),
              width: 1),
        ),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: active ? Colors.white : textC),
                  const SizedBox(width: 4),
                ],
                Text(label,
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: active ? Colors.white : textC)),
              ]),
              if (sub.isNotEmpty)
                Text(sub,
                    style: TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 10,
                        color: active
                            ? Colors.white70
                            : (isDark
                                ? AppColors.darkMuted
                                : AppColors.lightMuted))),
            ]),
      ),
    );
  }

  Widget _stepBtn(IconData ic, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.brandGreen.withOpacity(0.14),
            border: Border.all(color: AppColors.brandGreen.withOpacity(0.3)),
          ),
          child: Icon(ic, color: AppColors.halalGreen),
        ),
      );

  Widget _qtyStepper(Color textC, Color muted) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _stepBtn(Icons.remove_rounded, () => _stepQty(-0.5)),
      SizedBox(
        width: 120,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('× ${_fmt(_qty)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textC)),
          if (!_perServing)
            Text(_tl('عدد المرات', 'times the serving'),
                style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 10, color: muted)),
        ]),
      ),
      _stepBtn(Icons.add_rounded, () => _stepQty(0.5)),
    ]);
  }

  Widget _gramField(Color textC, Color muted) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _stepBtn(Icons.remove_rounded, () => _stepGrams(-10)),
      SizedBox(
        width: 130,
        child: TextField(
          controller: _gramCtrl,
          textAlign: TextAlign.center,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
              fontFamily: 'Aligarh',
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: textC),
          decoration: InputDecoration(
            isDense: true,
            suffixText: _unit,
            suffixStyle: TextStyle(fontFamily: 'Aligarh', color: muted),
            border: InputBorder.none,
          ),
          onChanged: (v) {
            final d = parseDouble(v);
            if (d == null) return;
            setState(() => _customGrams = d.clamp(1.0, 5000.0).toDouble());
          },
        ),
      ),
      _stepBtn(Icons.add_rounded, () => _stepGrams(10)),
    ]);
  }

  // ── Macros ────────────────────────────────────────────────────────────────
  Widget _macroCard(Color card, Color border, Color textC, Color muted) {
    final pk = _protein * 4, ck = _carbs * 4, fk = _fat * 9;
    final tot = pk + ck + fk;
    String pct(double v) => tot <= 0 ? '0%' : '${(v / tot * 100).round()}%';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(card, border),
      child: Row(children: [
        SizedBox(
          width: 132,
          height: 132,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, t, __) => CustomPaint(
              painter: _RingPainter(
                parts: [pk, ck, fk],
                colors: const [_pColor, _cColor, _fColor],
                track: textC.withOpacity(0.08),
                t: t,
              ),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${_kcal.round()}',
                      style: TextStyle(
                          fontFamily: 'Aligarh',
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: textC)),
                  Text(_tl('سعرة', 'kcal'),
                      style: TextStyle(
                          fontFamily: 'Aligarh', fontSize: 11, color: muted)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(children: [
            _macroLine(_tl('بروتين', 'Protein'), _protein, pct(pk), _pColor,
                textC, muted),
            const SizedBox(height: 12),
            _macroLine(_tl('كربوهيدرات', 'Carbs'), _carbs, pct(ck), _cColor,
                textC, muted),
            const SizedBox(height: 12),
            _macroLine(_tl('دهون', 'Fat'), _fat, pct(fk), _fColor, textC,
                muted),
          ]),
        ),
      ]),
    );
  }

  Widget _macroLine(String label, double grams, String pct, Color color,
      Color textC, Color muted) {
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Aligarh',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textC)),
      ),
      Text(_g1(grams),
          style: TextStyle(
              fontFamily: 'Aligarh',
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textC)),
      const SizedBox(width: 8),
      SizedBox(
        width: 38,
        child: Text(pct,
            textAlign: TextAlign.end,
            style: TextStyle(
                fontFamily: 'Aligarh', fontSize: 11.5, color: muted)),
      ),
    ]);
  }

  // ── Daily budget ──────────────────────────────────────────────────────────
  Widget _budgetCard(Color card, Color border, Color textC, Color muted) {
    final cals = ref.watch(caloriesProvider);
    final goal = cals.goal <= 0 ? 2000 : cals.goal;
    final eaten = cals.total;
    final add = _kcal.round();
    final after = eaten + add;
    final over = after > goal;
    final eatenFrac = (eaten / goal).clamp(0.0, 1.0).toDouble();
    final addFrac = (add / goal).clamp(0.0, 1.0 - eatenFrac).toDouble();
    final accent = over ? AppColors.haramRed : AppColors.halalGreen;
    final share = (add / goal * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(card, border),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.flag_rounded, size: 17, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_tl('أثره على هدفك اليوم', 'Effect on today\'s goal'),
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textC)),
          ),
          Text('$share%',
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: accent)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: LayoutBuilder(builder: (_, c) {
              final w = c.maxWidth;
              return Stack(children: [
                Container(color: textC.withOpacity(0.08)),
                AnimatedPositionedDirectional(
                  duration: const Duration(milliseconds: 300),
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: w * eatenFrac,
                  child: Container(color: AppColors.brandGreen),
                ),
                AnimatedPositionedDirectional(
                  duration: const Duration(milliseconds: 300),
                  start: w * eatenFrac,
                  top: 0,
                  bottom: 0,
                  width: w * addFrac,
                  child: Container(color: accent.withOpacity(0.55)),
                ),
              ]);
            }),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
                _tl('تناولت اليوم $eaten من $goal',
                    'Eaten today $eaten of $goal'),
                style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 11.5, color: muted)),
          ),
          Text(
              over
                  ? _tl('تتجاوز الهدف بـ ${after - goal}',
                      'Over goal by ${after - goal}')
                  : _tl('سيتبقى ${goal - after}', '${goal - after} left'),
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: accent)),
        ]),
      ]),
    );
  }

  // ── Insights (derived only from the numbers on this page) ────────────────
  Widget _insights(Color textC, Color muted) {
    final kcal = _kcal;
    if (kcal <= 0) return const SizedBox.shrink();
    final pShare = _protein * 4 / kcal;
    final cShare = _carbs * 4 / kcal;
    final fShare = _fat * 9 / kcal;
    final dens = _perServing ? 0.0 : _s.kcal; // kcal per 100 g/ml
    final goal = ref.watch(caloriesProvider).goal;
    final chips = <(IconData, String, Color)>[];
    if (_protein >= 15 && pShare >= 0.25) {
      chips.add((Icons.fitness_center_rounded,
          _tl('غني بالبروتين', 'High in protein'), _pColor));
    }
    if (_fat >= 15 && fShare >= 0.5) {
      chips.add((Icons.water_drop_rounded,
          _tl('نصف سعراته من الدهون', 'Half its calories are fat'), _fColor));
    }
    if (_carbs >= 40 && cShare >= 0.65) {
      chips.add((Icons.grain_rounded,
          _tl('غني بالكربوهيدرات', 'Carb-heavy'), _cColor));
    }
    if (!_perServing && !_s.isLiquid && dens >= 350) {
      chips.add((Icons.bolt_rounded,
          _tl('كثيف السعرات — كمية صغيرة تكفي', 'Calorie-dense — small portions'),
          AppColors.doubtOrange));
    }
    if (!_perServing && dens > 0 && dens <= 60 && !_s.isLiquid) {
      chips.add((Icons.eco_rounded, _tl('خفيف السعرات', 'Light on calories'),
          AppColors.halalGreen));
    }
    if (goal > 0 && kcal >= goal * 0.3) {
      chips.add((Icons.restaurant_rounded,
          _tl('يعادل وجبة رئيسية', 'Counts as a full meal'),
          AppColors.accentGold));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in chips.take(3))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: c.$3.withOpacity(0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(c.$1, size: 15, color: c.$3),
              const SizedBox(width: 6),
              Text(c.$2,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.$3)),
            ]),
          ),
      ]),
    );
  }

  // ── Facts table ───────────────────────────────────────────────────────────
  Widget _factsCard(Color card, Color border, Color textC, Color muted) {
    final perLabel = _perServing
        ? _tl('لكل حصة', 'Per serving')
        : _tl('لكل ١٠٠ $_unit', 'Per 100 $_unit');
    Widget row(String name, String now, String base, {bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                      color: textC)),
            ),
            SizedBox(
              width: 86,
              child: Text(now,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: textC)),
            ),
            SizedBox(
              width: 86,
              child: Text(base,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontFamily: 'Aligarh', fontSize: 12, color: muted)),
            ),
          ]),
        );
    Widget divider() => Divider(height: 1, color: textC.withOpacity(0.08));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: _cardDeco(card, border),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Text(_tl('القيم الغذائية', 'Nutrition facts'),
                style: TextStyle(
                    fontFamily: 'Aligarh',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: textC)),
          ),
          SizedBox(
            width: 86,
            child: Text(_tl('كميتك', 'Your amount'),
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 11, color: muted)),
          ),
          SizedBox(
            width: 86,
            child: Text(perLabel,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontFamily: 'Aligarh', fontSize: 11, color: muted)),
          ),
        ]),
        const SizedBox(height: 6),
        divider(),
        row(_tl('السعرات', 'Calories'), '${_kcal.round()}',
            '${_s.kcal.round()}',
            bold: true),
        divider(),
        row(_tl('بروتين', 'Protein'), _g1(_protein), _g1(_s.protein)),
        divider(),
        row(_tl('كربوهيدرات', 'Carbs'), _g1(_carbs), _g1(_s.carbs)),
        divider(),
        row(_tl('دهون', 'Fat'), _g1(_fat), _g1(_s.fat)),
      ]),
    );
  }

  Widget _sourceNote(Color muted) {
    final text = switch (_s.source) {
      'mena' || 'builtin' || 'offline' => _tl(
          'قيم تقريبية لوصفة معتادة — تختلف حسب المطعم وطريقة الطهي.',
          'Typical values for a common recipe — they vary by restaurant and cooking method.'),
      'openfoodfacts' => _tl(
          'من Open Food Facts — بيانات يضيفها المستخدمون وقد تحتاج مراجعة.',
          'From Open Food Facts — community data that may need a check.'),
      'ai' => _tl('تقدير بالذكاء الاصطناعي — راجعه قبل الاعتماد عليه.',
          'AI estimate — double-check before relying on it.'),
      _ => '',
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 14, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'Aligarh',
                  fontSize: 11,
                  height: 1.35,
                  color: muted)),
        ),
      ]),
    );
  }

  // ── Log bar ───────────────────────────────────────────────────────────────
  Widget _logBar(bool isDark, Color bg) {
    final kcal = _kcal.round();
    final ok = kcal > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withOpacity(0.0), bg.withOpacity(0.94), bg],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: ok ? _log : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: ok
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2BB567), Color(0xFF1E9E52)])
                  : null,
              color: ok ? null : Colors.grey,
              boxShadow: ok
                  ? [
                      BoxShadow(
                          color: const Color(0xFF1E9E52).withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 6)),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text(_tl('أضف للعداد', 'Log it'),
                  style: const TextStyle(
                      fontFamily: 'Aligarh',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text('$kcal ${_tl("سعرة", "kcal")}',
                    style: const TextStyle(
                        fontFamily: 'Aligarh',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<double> parts;
  final List<Color> colors;
  final Color track;
  final double t;

  const _RingPainter({
    required this.parts,
    required this.colors,
    required this.track,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    final total = parts.fold<double>(0.0, (a, b) => a + b);
    if (total <= 0) return;
    const gap = 0.07;
    var start = -math.pi / 2;
    for (var i = 0; i < parts.length; i++) {
      final sweep = parts[i] / total * math.pi * 2 * t;
      if (sweep > 0.001) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..color = colors[i];
        final drawn = math.max(sweep - gap, 0.02);
        canvas.drawArc(rect, start + gap / 2, drawn, false, paint);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.t != t ||
      old.track != track ||
      old.parts[0] != parts[0] ||
      old.parts[1] != parts[1] ||
      old.parts[2] != parts[2];
}
