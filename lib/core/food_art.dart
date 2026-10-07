// food_art.dart — HalalCalorie v60 (PATCH_V60_FOODART)
//
// Hand-drawn food illustrations, painted in code, so every food in the list has
// a picture that matches the app (soft gradients, warm colours, green/gold) and
// works offline with no image files. [FoodThumb] shows one whenever there is no
// curated PNG and no photo. The picture is chosen from the same keyword table as
// the old emoji glyphs (Arabic, English, French, Turkish, Malay, Urdu).
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum FoodArtKind {
  milk, cheese, bowl, bread, flatbread, drumstick, steak, fish, shrimp, egg,
  apple, citrus, lemon, banana, grapes, berry, melon, pear, pineapple, cherry,
  date, leaf, sprout, broccoli, carrot, tomato, bulb, potato, capsule, mushroom,
  bean, cupcake, cookie, donut, chocolate, candy, jar, icecream, cup, glass,
  bottle, can, burger, pizza, fries, plate,
}

class FoodArtSpec {
  final FoodArtKind kind;
  final Color a;
  final Color b;
  final int v;
  const FoodArtSpec(this.kind,
      [this.a = const Color(0xFFFFFFFF), this.b = const Color(0xFFCCCCCC), this.v = 0]);
}

const FoodArtSpec kFoodArtPlate = FoodArtSpec(
    FoodArtKind.plate, Color(0xFFF7EFD9), Color(0xFFDBA75D), 0);

FoodArtSpec _sp(FoodArtKind k, int a, int b, [int v = 0]) =>
    FoodArtSpec(k, Color(a), Color(b), v);

// Emoji glyph (see kFoodGlyphs) -> illustration.
final Map<String, FoodArtSpec> _glyphArt = <String, FoodArtSpec>{
  // dairy
  '🥛': _sp(FoodArtKind.milk, 0xFFFFFFFF, 0xFFDCE6EE),
  '🧀': _sp(FoodArtKind.cheese, 0xFFFFD45E, 0xFFF2A81D),
  '🧈': _sp(FoodArtKind.cheese, 0xFFFFF1A8, 0xFFF6D24A),
  '🍥': _sp(FoodArtKind.cheese, 0xFFFFFBEF, 0xFFEFE3C2),
  '🍦': _sp(FoodArtKind.icecream, 0xFFFFB3C7, 0xFFE9B872),
  // bowls
  '🥣': _sp(FoodArtKind.bowl, 0xFFFFFBEF, 0xFFB377D6, 0),
  '🍲': _sp(FoodArtKind.bowl, 0xFFE8873B, 0xFF4CAF50, 1),
  '🍚': _sp(FoodArtKind.bowl, 0xFFFFFFFF, 0xFFE9E1CC, 2),
  '🍛': _sp(FoodArtKind.bowl, 0xFFF2B33D, 0xFFD6702C, 2),
  '🍜': _sp(FoodArtKind.bowl, 0xFFF5D56B, 0xFFE8873B, 3),
  '🍝': _sp(FoodArtKind.bowl, 0xFFF5D56B, 0xFFE0453A, 3),
  '🥗': _sp(FoodArtKind.bowl, 0xFF7BD66B, 0xFFE0453A, 4),
  '🌾': _sp(FoodArtKind.bowl, 0xFFE7C77A, 0xFFB98B3E, 2),
  // bread
  '🍞': _sp(FoodArtKind.bread, 0xFFF2B866, 0xFFC27D34),
  '🥖': _sp(FoodArtKind.bread, 0xFFEBB05A, 0xFFB86F2A, 1),
  '🥐': _sp(FoodArtKind.bread, 0xFFF0AE55, 0xFFC4742C, 2),
  '🥨': _sp(FoodArtKind.bread, 0xFFD9904A, 0xFF9A5A25, 2),
  '🫓': _sp(FoodArtKind.flatbread, 0xFFF3D9A4, 0xFFD2A55E),
  '🥟': _sp(FoodArtKind.flatbread, 0xFFF6E3B8, 0xFFD9B26C),
  // meat & fish
  '🍗': _sp(FoodArtKind.drumstick, 0xFFE58B4B, 0xFFA5481F),
  '🦃': _sp(FoodArtKind.drumstick, 0xFFE58B4B, 0xFFA5481F),
  '🦆': _sp(FoodArtKind.drumstick, 0xFFD6783C, 0xFF8E3A17),
  '🥩': _sp(FoodArtKind.steak, 0xFFE0605A, 0xFF8E2A2A),
  '🍖': _sp(FoodArtKind.steak, 0xFFD9774B, 0xFF8A3A1C),
  '🍢': _sp(FoodArtKind.steak, 0xFFD9774B, 0xFF8A3A1C),
  '🌭': _sp(FoodArtKind.steak, 0xFFE0705A, 0xFF9B2F2F),
  '🐟': _sp(FoodArtKind.fish, 0xFF7ED3E6, 0xFF2C8DB0),
  '🍣': _sp(FoodArtKind.fish, 0xFFFFA58A, 0xFFE0654F),
  '🦐': _sp(FoodArtKind.shrimp, 0xFFFF9B7A, 0xFFE0654F),
  '🦞': _sp(FoodArtKind.shrimp, 0xFFFF7A6B, 0xFFC93A2B),
  '🦀': _sp(FoodArtKind.shrimp, 0xFFFF7A6B, 0xFFC93A2B),
  '🦑': _sp(FoodArtKind.shrimp, 0xFFE9B5D0, 0xFFB5679A),
  '🥚': _sp(FoodArtKind.egg, 0xFFFFD24D, 0xFFF4A11D),
  '🍳': _sp(FoodArtKind.egg, 0xFFFFD24D, 0xFFF4A11D),
  // fruit
  '🍎': _sp(FoodArtKind.apple, 0xFFFF7A6B, 0xFFD8362B),
  '🍑': _sp(FoodArtKind.apple, 0xFFFFC09A, 0xFFF08A6A),
  '🍊': _sp(FoodArtKind.citrus, 0xFFFFB347, 0xFFF08A24),
  '🥝': _sp(FoodArtKind.citrus, 0xFFB5E36B, 0xFF6BAA2F),
  '🥥': _sp(FoodArtKind.citrus, 0xFFB98B63, 0xFF7A4B2A),
  '🍈': _sp(FoodArtKind.citrus, 0xFFC9E58A, 0xFF8DBE4A),
  '🍋': _sp(FoodArtKind.lemon, 0xFFFFE566, 0xFFF5B700),
  '🥭': _sp(FoodArtKind.lemon, 0xFFFFC857, 0xFFF08A24, 1),
  '🍌': _sp(FoodArtKind.banana, 0xFFFFE066, 0xFFF2B600),
  '🍇': _sp(FoodArtKind.grapes, 0xFFB388EB, 0xFF6A3FA0),
  '🫐': _sp(FoodArtKind.grapes, 0xFF7C9CF0, 0xFF3C4FA8),
  '🍓': _sp(FoodArtKind.berry, 0xFFFF6B6B, 0xFFD62F3F),
  '🍉': _sp(FoodArtKind.melon, 0xFFFF5A6B, 0xFF2F9E44),
  '🍐': _sp(FoodArtKind.pear, 0xFFC8E86A, 0xFF8DBE2F),
  '🥑': _sp(FoodArtKind.pear, 0xFF7DBB4E, 0xFF2F6B2A, 1),
  '🍍': _sp(FoodArtKind.pineapple, 0xFFFFD34D, 0xFFE09B1D),
  '🍒': _sp(FoodArtKind.cherry, 0xFFE0394F, 0xFF9E1B30),
  '🌴': _sp(FoodArtKind.date, 0xFF8A4F2A, 0xFF4A2512),
  // vegetables
  '🥬': _sp(FoodArtKind.leaf, 0xFF8BE070, 0xFF2F9E44),
  '🌿': _sp(FoodArtKind.leaf, 0xFF8BE070, 0xFF2F9E44),
  '🫒': _sp(FoodArtKind.cherry, 0xFF9DBA4A, 0xFF5A7A1E),
  '🌱': _sp(FoodArtKind.sprout, 0xFF8BE070, 0xFF2F9E44),
  '🌻': _sp(FoodArtKind.sprout, 0xFF8BE070, 0xFF2F9E44),
  '🥦': _sp(FoodArtKind.broccoli, 0xFF5CC264, 0xFF237A33),
  '🥕': _sp(FoodArtKind.carrot, 0xFFFFA24D, 0xFFE36F1B),
  '🍅': _sp(FoodArtKind.tomato, 0xFFFF6B5E, 0xFFD92D20),
  '🎃': _sp(FoodArtKind.tomato, 0xFFFFA24D, 0xFFE0701B, 1),
  '🧅': _sp(FoodArtKind.bulb, 0xFFF3C77A, 0xFFC98A3A),
  '🧄': _sp(FoodArtKind.bulb, 0xFFFFFBEF, 0xFFE2D6B5),
  '🥔': _sp(FoodArtKind.potato, 0xFFD9B27A, 0xFF9A6E3A),
  '🍠': _sp(FoodArtKind.potato, 0xFFD6785F, 0xFF8E3A3A),
  '🥒': _sp(FoodArtKind.capsule, 0xFF8BD05A, 0xFF2F8A3A, 0),
  '🌽': _sp(FoodArtKind.capsule, 0xFFFFE066, 0xFFF2B600, 1),
  '🍆': _sp(FoodArtKind.capsule, 0xFFA16AD6, 0xFF4E2A84, 2),
  '🫑': _sp(FoodArtKind.capsule, 0xFF7BD66B, 0xFF2F9E44, 3),
  '🌶': _sp(FoodArtKind.capsule, 0xFFFF6B5E, 0xFFC4281B, 3),
  '🍄': _sp(FoodArtKind.mushroom, 0xFFE2554A, 0xFFB3322A),
  // legumes & nuts
  '🫘': _sp(FoodArtKind.bean, 0xFFB5523B, 0xFF7A2E1F, 0),
  '🫛': _sp(FoodArtKind.bean, 0xFF8BD05A, 0xFF3F9A3A, 0),
  '🥜': _sp(FoodArtKind.bean, 0xFFE0B77A, 0xFFB8803F, 1),
  '🌰': _sp(FoodArtKind.bean, 0xFFC99560, 0xFF8A5A2B, 2),
  '🧆': _sp(FoodArtKind.cookie, 0xFFB5793F, 0xFF6F7A2A),
  // sweets
  '🍰': _sp(FoodArtKind.cupcake, 0xFFFFE1EA, 0xFFE8A0B4),
  '🧁': _sp(FoodArtKind.cupcake, 0xFFFFB3C7, 0xFF5CC264),
  '🍮': _sp(FoodArtKind.cupcake, 0xFFF3C77A, 0xFFB86F2A),
  '🍪': _sp(FoodArtKind.cookie, 0xFFE8B66A, 0xFF5A3320),
  '🥞': _sp(FoodArtKind.cookie, 0xFFEFC27A, 0xFFB86F2A),
  '🧇': _sp(FoodArtKind.cookie, 0xFFEFC27A, 0xFFB86F2A),
  '🍩': _sp(FoodArtKind.donut, 0xFFFF9BBB, 0xFFD9A15E),
  '🍫': _sp(FoodArtKind.chocolate, 0xFF8A5236, 0xFF4E2A1B),
  '🍬': _sp(FoodArtKind.candy, 0xFFFF7BAC, 0xFFFFC2D8),
  '🍭': _sp(FoodArtKind.candy, 0xFF7BC8FF, 0xFFFFC2D8, 1),
  '🍯': _sp(FoodArtKind.jar, 0xFFF5B83D, 0xFF8A5A2B),
  '🍿': _sp(FoodArtKind.fries, 0xFFFFF1B8, 0xFFE0453A, 1),
  // drinks & pantry
  '☕': _sp(FoodArtKind.cup, 0xFF6F4327, 0xFFF4EEDF),
  '🍵': _sp(FoodArtKind.cup, 0xFFB5C95A, 0xFFF4EEDF),
  '🧃': _sp(FoodArtKind.glass, 0xFFFFA24D, 0xFF5CC264),
  '🥤': _sp(FoodArtKind.glass, 0xFFE0654F, 0xFFFFD24D),
  '💧': _sp(FoodArtKind.bottle, 0xFF7ED3E6, 0xFF2C8DB0, 0),
  '🫗': _sp(FoodArtKind.bottle, 0xFFE0B43A, 0xFF4C8A3A, 1),
  '🧂': _sp(FoodArtKind.bottle, 0xFFF4F4F4, 0xFFB0B7BE, 2),
  '🥫': _sp(FoodArtKind.can, 0xFFE0453A, 0xFFF3EAD2),
  // fast food
  '🍔': _sp(FoodArtKind.burger, 0xFFF0B15A, 0xFFB86F2A),
  '🥪': _sp(FoodArtKind.burger, 0xFFEBC27A, 0xFFB98B3E),
  '🌯': _sp(FoodArtKind.burger, 0xFFEBC27A, 0xFFB98B3E),
  '🌮': _sp(FoodArtKind.burger, 0xFFEBC27A, 0xFFB98B3E),
  '🍕': _sp(FoodArtKind.pizza, 0xFFFFD24D, 0xFFE0453A),
  '🍟': _sp(FoodArtKind.fries, 0xFFFFD24D, 0xFFE0453A),
};

/// Illustration for a glyph from [kFoodGlyphs]; a themed plate when unknown.
FoodArtSpec foodArtForGlyph(String? glyph) {
  if (glyph == null || glyph.isEmpty) return kFoodArtPlate;
  final g = glyph.replaceAll('️', '');
  return _glyphArt[g] ?? kFoodArtPlate;
}

/// A food picture of [size] logical pixels.
class FoodArt extends StatelessWidget {
  final FoodArtSpec spec;
  final double size;
  const FoodArt({super.key, required this.spec, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _FoodArtPainter(spec)),
      );
}

// ── painting helpers (everything is drawn in a 0..1 square) ─────────────
const Rect _u = Rect.fromLTWH(0, 0, 1, 1);

Paint _p(Color c) => Paint()
  ..isAntiAlias = true
  ..color = c;

Paint _lg(Rect r, Color a, Color b,
        [Alignment from = Alignment.topCenter, Alignment to = Alignment.bottomCenter]) =>
    Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(begin: from, end: to, colors: <Color>[a, b]).createShader(r);

Paint _rg(Rect r, Color a, Color b) => Paint()
  ..isAntiAlias = true
  ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4), radius: 0.95, colors: <Color>[a, b])
      .createShader(r);

Paint _st(Color c, double w) => Paint()
  ..isAntiAlias = true
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t) ?? a;
Color _lighten(Color c, double t) => _mix(c, Colors.white, t);
Color _darken(Color c, double t) => _mix(c, Colors.black, t);

Path _poly(List<Offset> pts) {
  final p = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    p.lineTo(pts[i].dx, pts[i].dy);
  }
  return p..close();
}

void _shadow(Canvas c, [double w = 0.56, double y = 0.91]) =>
    c.drawOval(Rect.fromCenter(center: Offset(0.5, y), width: w, height: 0.07),
        _p(Colors.black.withOpacity(0.20)));

void _edge(Canvas c, Path p, Color base) =>
    c.drawPath(p, _st(_darken(base, 0.38).withOpacity(0.55), 0.016));

void _gloss(Canvas c, Rect r) =>
    c.drawOval(r, _p(Colors.white.withOpacity(0.30)));

/// A leaf of [len] x [wid] growing from [base] at [angle] radians.
void _leafAt(Canvas c, Offset base, double angle, double len, double wid, Color a, Color b) {
  final path = Path()
    ..moveTo(0, 0)
    ..cubicTo(len * 0.30, -wid, len * 0.80, -wid * 0.6, len, 0)
    ..cubicTo(len * 0.80, wid * 0.6, len * 0.30, wid, 0, 0)
    ..close();
  c.save();
  c.translate(base.dx, base.dy);
  c.rotate(angle);
  c.drawPath(path, _lg(Rect.fromLTRB(0, -wid, len, wid), a, b, Alignment.topCenter, Alignment.bottomCenter));
  c.drawLine(Offset.zero, Offset(len * 0.92, 0), _st(Colors.white.withOpacity(0.35), 0.012));
  c.restore();
}

class _FoodArtPainter extends CustomPainter {
  final FoodArtSpec spec;
  _FoodArtPainter(this.spec);

  @override
  bool shouldRepaint(_FoodArtPainter old) => old.spec != spec;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    if (s <= 0) return;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    canvas.scale(s, s);
    if (spec.kind != FoodArtKind.plate) _shadow(canvas);
    switch (spec.kind) {
      case FoodArtKind.milk: _milk(canvas); break;
      case FoodArtKind.cheese: _cheese(canvas); break;
      case FoodArtKind.bowl: _bowl(canvas); break;
      case FoodArtKind.bread: _bread(canvas); break;
      case FoodArtKind.flatbread: _flatbread(canvas); break;
      case FoodArtKind.drumstick: _drumstick(canvas); break;
      case FoodArtKind.steak: _steak(canvas); break;
      case FoodArtKind.fish: _fish(canvas); break;
      case FoodArtKind.shrimp: _shrimp(canvas); break;
      case FoodArtKind.egg: _egg(canvas); break;
      case FoodArtKind.apple: _apple(canvas); break;
      case FoodArtKind.citrus: _citrus(canvas); break;
      case FoodArtKind.lemon: _lemon(canvas); break;
      case FoodArtKind.banana: _banana(canvas); break;
      case FoodArtKind.grapes: _grapes(canvas); break;
      case FoodArtKind.berry: _berry(canvas); break;
      case FoodArtKind.melon: _melon(canvas); break;
      case FoodArtKind.pear: _pear(canvas); break;
      case FoodArtKind.pineapple: _pineapple(canvas); break;
      case FoodArtKind.cherry: _cherry(canvas); break;
      case FoodArtKind.date: _date(canvas); break;
      case FoodArtKind.leaf: _leaf(canvas); break;
      case FoodArtKind.sprout: _sprout(canvas); break;
      case FoodArtKind.broccoli: _broccoli(canvas); break;
      case FoodArtKind.carrot: _carrot(canvas); break;
      case FoodArtKind.tomato: _tomato(canvas); break;
      case FoodArtKind.bulb: _bulb(canvas); break;
      case FoodArtKind.potato: _potato(canvas); break;
      case FoodArtKind.capsule: _capsule(canvas); break;
      case FoodArtKind.mushroom: _mushroom(canvas); break;
      case FoodArtKind.bean: _bean(canvas); break;
      case FoodArtKind.cupcake: _cupcake(canvas); break;
      case FoodArtKind.cookie: _cookie(canvas); break;
      case FoodArtKind.donut: _donut(canvas); break;
      case FoodArtKind.chocolate: _chocolate(canvas); break;
      case FoodArtKind.candy: _candy(canvas); break;
      case FoodArtKind.jar: _jar(canvas); break;
      case FoodArtKind.icecream: _icecream(canvas); break;
      case FoodArtKind.cup: _cup(canvas); break;
      case FoodArtKind.glass: _glass(canvas); break;
      case FoodArtKind.bottle: _bottle(canvas); break;
      case FoodArtKind.can: _can(canvas); break;
      case FoodArtKind.burger: _burger(canvas); break;
      case FoodArtKind.pizza: _pizza(canvas); break;
      case FoodArtKind.fries: _fries(canvas); break;
      case FoodArtKind.plate: _plate(canvas); break;
    }
    canvas.restore();
  }

  // ── dairy ─────────────────────────────────────────────────
  void _milk(Canvas c) {
    final glass = Path()
      ..moveTo(0.25, 0.14)
      ..lineTo(0.75, 0.14)
      ..lineTo(0.69, 0.88)
      ..lineTo(0.31, 0.88)
      ..close();
    c.drawPath(glass, _p(const Color(0xFFBFD3E3).withOpacity(0.30)));
    final milk = Path()
      ..moveTo(0.268, 0.32)
      ..lineTo(0.732, 0.32)
      ..lineTo(0.69, 0.88)
      ..lineTo(0.31, 0.88)
      ..close();
    c.drawPath(milk, _lg(_u, spec.a, spec.b));
    c.drawOval(const Rect.fromLTRB(0.268, 0.285, 0.732, 0.355), _p(spec.a));
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(0.62, 0.42, 0.665, 0.80), const Radius.circular(0.02)),
        _p(const Color(0xFF9FB3C8).withOpacity(0.22)));
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(0.30, 0.17, 0.345, 0.29), const Radius.circular(0.02)),
        _p(Colors.white.withOpacity(0.75)));
    c.drawPath(glass, _st(const Color(0xFF8FA6BC).withOpacity(0.85), 0.022));
  }

  void _cheese(Canvas c) {
    final top = _poly(const <Offset>[Offset(0.10, 0.56), Offset(0.78, 0.24), Offset(0.92, 0.50)]);
    final front = _poly(const <Offset>[
      Offset(0.10, 0.56), Offset(0.92, 0.50), Offset(0.92, 0.76), Offset(0.10, 0.76)
    ]);
    c.drawPath(front, _lg(front.getBounds(), spec.a, spec.b));
    c.drawPath(top, _p(_lighten(spec.a, 0.35)));
    _edge(c, front, spec.b);
    _edge(c, top, spec.b);
    final hole = _p(_darken(spec.b, 0.22).withOpacity(0.55));
    c.drawCircle(const Offset(0.28, 0.66), 0.05, hole);
    c.drawCircle(const Offset(0.55, 0.62), 0.04, hole);
    c.drawCircle(const Offset(0.76, 0.67), 0.045, hole);
    c.drawCircle(const Offset(0.62, 0.40), 0.028, hole);
  }

  // ── bowls (v: 0 yogurt, 1 soup, 2 rice, 3 noodles, 4 salad) ──
  void _bowl(Canvas c) {
    const cream = Color(0xFFF8F1E0);
    const creamDark = Color(0xFFD9CDAE);
    final body = Path()
      ..moveTo(0.10, 0.52)
      ..cubicTo(0.12, 0.84, 0.30, 0.92, 0.50, 0.92)
      ..cubicTo(0.70, 0.92, 0.88, 0.84, 0.90, 0.52)
      ..close();
    c.drawPath(body, _lg(const Rect.fromLTRB(0.1, 0.5, 0.9, 0.92), cream, creamDark));
    c.drawPath(
        Path()
          ..moveTo(0.14, 0.64)
          ..quadraticBezierTo(0.5, 0.78, 0.86, 0.64),
        _st(const Color(0xFFDBA75D), 0.024));
    c.drawOval(const Rect.fromLTRB(0.10, 0.44, 0.90, 0.60), _p(_darken(cream, 0.10)));
    c.drawOval(const Rect.fromLTRB(0.13, 0.455, 0.87, 0.585), _p(spec.a));
    switch (spec.v) {
      case 1: // soup: steam and herbs
        for (final x in <double>[0.36, 0.50, 0.64]) {
          c.drawPath(
              Path()
                ..moveTo(x, 0.40)
                ..cubicTo(x - 0.05, 0.32, x + 0.05, 0.26, x, 0.17),
              _st(Colors.white.withOpacity(0.55), 0.03));
        }
        c.drawCircle(const Offset(0.40, 0.52), 0.022, _p(spec.b));
        c.drawCircle(const Offset(0.56, 0.50), 0.026, _p(spec.b));
        c.drawCircle(const Offset(0.66, 0.53), 0.02, _p(spec.b));
        break;
      case 2: // rice / grains mound
        final mound = Path()
          ..moveTo(0.18, 0.52)
          ..cubicTo(0.20, 0.22, 0.80, 0.22, 0.82, 0.52)
          ..close();
        c.drawPath(mound, _lg(mound.getBounds(), spec.a, spec.b));
        for (var i = 0; i < 9; i++) {
          final x = 0.30 + 0.05 * (i % 5) + (i ~/ 5) * 0.025;
          final y = 0.34 + 0.045 * (i ~/ 5) + 0.02 * (i % 3);
          c.save();
          c.translate(x, y);
          c.rotate(0.6 * (i % 3) - 0.5);
          c.drawOval(const Rect.fromLTRB(-0.018, -0.008, 0.018, 0.008),
              _p(_darken(spec.b, 0.10).withOpacity(0.55)));
          c.restore();
        }
        break;
      case 3: // noodles
        final mound3 = Path()
          ..moveTo(0.18, 0.52)
          ..cubicTo(0.20, 0.24, 0.80, 0.24, 0.82, 0.52)
          ..close();
        c.drawPath(mound3, _p(spec.a));
        for (var k = 0; k < 4; k++) {
          final y = 0.34 + k * 0.04;
          c.drawPath(
              Path()
                ..moveTo(0.26, y)
                ..cubicTo(0.38, y - 0.05, 0.46, y + 0.05, 0.56, y)
                ..cubicTo(0.64, y - 0.04, 0.70, y + 0.03, 0.76, y),
              _st(_darken(spec.a, 0.18), 0.018));
        }
        c.drawCircle(const Offset(0.62, 0.34), 0.04, _p(spec.b));
        break;
      case 4: // salad
        _leafAt(c, const Offset(0.50, 0.54), -2.5, 0.30, 0.10, spec.a, _darken(spec.a, 0.25));
        _leafAt(c, const Offset(0.50, 0.54), -0.64, 0.30, 0.10, spec.a, _darken(spec.a, 0.25));
        _leafAt(c, const Offset(0.50, 0.54), -1.57, 0.32, 0.11, _lighten(spec.a, 0.15), spec.a);
        c.drawCircle(const Offset(0.36, 0.44), 0.05, _p(spec.b));
        c.drawCircle(const Offset(0.62, 0.42), 0.045, _p(spec.b));
        c.drawCircle(const Offset(0.50, 0.50), 0.035, _p(const Color(0xFFFFE066)));
        break;
      default: // yogurt, honey swirl and berries
        c.drawPath(
            Path()
              ..moveTo(0.30, 0.52)
              ..cubicTo(0.40, 0.44, 0.48, 0.58, 0.58, 0.50)
              ..cubicTo(0.64, 0.46, 0.68, 0.52, 0.72, 0.50),
            _st(const Color(0xFFF5B83D), 0.026));
        c.drawCircle(const Offset(0.40, 0.49), 0.03, _p(spec.b));
        c.drawCircle(const Offset(0.48, 0.55), 0.026, _p(spec.b));
        c.drawCircle(const Offset(0.62, 0.55), 0.03, _p(spec.b));
        break;
    }
  }

  // ── bread ─────────────────────────────────────────────────
  void _bread(Canvas c) {
    if (spec.v == 1) {
      // baguette
      c.save();
      c.translate(0.5, 0.54);
      c.rotate(-0.55);
      final r = RRect.fromRectAndRadius(const Rect.fromLTRB(-0.44, -0.12, 0.44, 0.12), const Radius.circular(0.12));
      c.drawRRect(r, _lg(const Rect.fromLTRB(-0.44, -0.12, 0.44, 0.12), spec.a, spec.b));
      for (final x in <double>[-0.26, -0.06, 0.14, 0.32]) {
        c.drawLine(Offset(x, -0.07), Offset(x + 0.07, 0.05), _st(_lighten(spec.a, 0.5), 0.032));
      }
      c.restore();
      return;
    }
    if (spec.v == 2) {
      // croissant / pretzel: golden crescent
      final cr = Path()
        ..moveTo(0.10, 0.62)
        ..cubicTo(0.12, 0.28, 0.40, 0.18, 0.50, 0.20)
        ..cubicTo(0.60, 0.18, 0.88, 0.28, 0.90, 0.62)
        ..cubicTo(0.80, 0.70, 0.74, 0.66, 0.70, 0.56)
        ..cubicTo(0.62, 0.44, 0.38, 0.44, 0.30, 0.56)
        ..cubicTo(0.26, 0.66, 0.20, 0.70, 0.10, 0.62)
        ..close();
      c.drawPath(cr, _lg(cr.getBounds(), spec.a, spec.b));
      _edge(c, cr, spec.b);
      c.drawPath(Path()..moveTo(0.30, 0.34)..quadraticBezierTo(0.34, 0.44, 0.34, 0.50), _st(_lighten(spec.a, 0.4), 0.022));
      c.drawPath(Path()..moveTo(0.50, 0.27)..lineTo(0.50, 0.42), _st(_lighten(spec.a, 0.4), 0.022));
      c.drawPath(Path()..moveTo(0.70, 0.34)..quadraticBezierTo(0.66, 0.44, 0.66, 0.50), _st(_lighten(spec.a, 0.4), 0.022));
      return;
    }
    final loaf = Path()
      ..moveTo(0.12, 0.72)
      ..cubicTo(0.08, 0.40, 0.28, 0.24, 0.50, 0.24)
      ..cubicTo(0.72, 0.24, 0.92, 0.40, 0.88, 0.72)
      ..quadraticBezierTo(0.88, 0.82, 0.78, 0.82)
      ..lineTo(0.22, 0.82)
      ..quadraticBezierTo(0.12, 0.82, 0.12, 0.72)
      ..close();
    c.drawPath(loaf, _lg(loaf.getBounds(), spec.a, spec.b));
    _edge(c, loaf, spec.b);
    for (final x in <double>[0.34, 0.50, 0.66]) {
      c.drawLine(Offset(x - 0.04, 0.40), Offset(x + 0.03, 0.58), _st(_lighten(spec.a, 0.55), 0.04));
    }
    _gloss(c, const Rect.fromLTRB(0.20, 0.30, 0.42, 0.38));
  }

  void _flatbread(Canvas c) {
    c.drawCircle(const Offset(0.5, 0.52), 0.36, _lg(const Rect.fromLTRB(0.14, 0.16, 0.86, 0.88), spec.a, spec.b));
    c.drawCircle(const Offset(0.5, 0.52), 0.36, _st(_darken(spec.b, 0.3).withOpacity(0.5), 0.016));
    final spot = _p(_darken(spec.b, 0.28).withOpacity(0.55));
    c.drawCircle(const Offset(0.36, 0.42), 0.03, spot);
    c.drawCircle(const Offset(0.60, 0.38), 0.025, spot);
    c.drawCircle(const Offset(0.50, 0.58), 0.032, spot);
    c.drawCircle(const Offset(0.68, 0.62), 0.024, spot);
    c.drawCircle(const Offset(0.34, 0.66), 0.022, spot);
  }

  // ── meat, fish, eggs ──────────────────────────────────────
  void _drumstick(Canvas c) {
    final bone = _p(const Color(0xFFFFF6E2));
    c.drawLine(const Offset(0.52, 0.58), const Offset(0.78, 0.80), _st(const Color(0xFFFFF6E2), 0.075));
    c.drawCircle(const Offset(0.83, 0.78), 0.05, bone);
    c.drawCircle(const Offset(0.77, 0.86), 0.05, bone);
    final meat = Path()
      ..moveTo(0.18, 0.46)
      ..cubicTo(0.14, 0.22, 0.40, 0.10, 0.58, 0.22)
      ..cubicTo(0.74, 0.32, 0.66, 0.54, 0.52, 0.62)
      ..cubicTo(0.40, 0.68, 0.22, 0.68, 0.18, 0.46)
      ..close();
    c.drawPath(meat, _rg(meat.getBounds(), spec.a, spec.b));
    _edge(c, meat, spec.b);
    _gloss(c, const Rect.fromLTRB(0.24, 0.22, 0.42, 0.32));
  }

  void _steak(Canvas c) {
    final s = Path()
      ..moveTo(0.14, 0.50)
      ..cubicTo(0.12, 0.28, 0.34, 0.16, 0.54, 0.20)
      ..cubicTo(0.80, 0.24, 0.90, 0.44, 0.82, 0.62)
      ..cubicTo(0.74, 0.80, 0.46, 0.84, 0.28, 0.76)
      ..cubicTo(0.18, 0.70, 0.15, 0.60, 0.14, 0.50)
      ..close();
    c.drawPath(s, _rg(s.getBounds(), spec.a, spec.b));
    c.drawPath(s, _st(const Color(0xFFFFE9C9).withOpacity(0.85), 0.03));
    _edge(c, s, spec.b);
    final fat = _st(const Color(0xFFFFD9D0).withOpacity(0.55), 0.022);
    c.drawPath(Path()..moveTo(0.30, 0.66)..lineTo(0.46, 0.46), fat);
    c.drawPath(Path()..moveTo(0.42, 0.72)..lineTo(0.60, 0.50), fat);
    c.drawCircle(const Offset(0.30, 0.38), 0.06, _p(const Color(0xFFFFF1DD)));
    c.drawCircle(const Offset(0.30, 0.38), 0.03, _p(_darken(spec.b, 0.1)));
  }

  void _fish(Canvas c) {
    final tail = _poly(const <Offset>[Offset(0.66, 0.50), Offset(0.92, 0.30), Offset(0.92, 0.70)]);
    c.drawPath(tail, _p(_darken(spec.b, 0.08)));
    final fin = _poly(const <Offset>[Offset(0.34, 0.34), Offset(0.52, 0.18), Offset(0.62, 0.38)]);
    c.drawPath(fin, _p(_darken(spec.b, 0.08)));
    final body = Rect.fromCenter(center: const Offset(0.42, 0.52), width: 0.64, height: 0.42);
    c.drawOval(body, _lg(body, spec.a, spec.b));
    c.drawOval(body, _st(_darken(spec.b, 0.35).withOpacity(0.5), 0.016));
    c.drawArc(const Rect.fromLTRB(0.14, 0.34, 0.46, 0.70), -0.9, 1.8, false, _st(Colors.white.withOpacity(0.35), 0.022));
    for (final p in const <Offset>[Offset(0.50, 0.46), Offset(0.58, 0.54), Offset(0.50, 0.60)]) {
      c.drawArc(Rect.fromCenter(center: p, width: 0.10, height: 0.10), 2.2, 2.2, false, _st(Colors.white.withOpacity(0.35), 0.014));
    }
    c.drawCircle(const Offset(0.24, 0.46), 0.036, _p(Colors.white));
    c.drawCircle(const Offset(0.235, 0.46), 0.018, _p(const Color(0xFF23313A)));
  }

  void _shrimp(Canvas c) {
    final body = Path()
      ..moveTo(0.26, 0.28)
      ..cubicTo(0.70, 0.08, 0.94, 0.48, 0.62, 0.72)
      ..quadraticBezierTo(0.46, 0.82, 0.30, 0.70);
    c.drawPath(body, _st(spec.b, 0.17));
    c.drawPath(body, _st(spec.a, 0.13));
    final m = body.computeMetrics().first;
    for (var i = 1; i < 6; i++) {
      final tan = m.getTangentForOffset(m.length * i / 6);
      if (tan == null) continue;
      final n = Offset(-tan.vector.dy, tan.vector.dx);
      final d = n / n.distance;
      c.drawLine(tan.position - d * 0.065, tan.position + d * 0.065, _st(_darken(spec.b, 0.15).withOpacity(0.7), 0.014));
    }
    c.drawPath(_poly(const <Offset>[Offset(0.30, 0.68), Offset(0.16, 0.62), Offset(0.20, 0.84), Offset(0.34, 0.80)]), _p(spec.b));
    c.drawCircle(const Offset(0.27, 0.28), 0.03, _p(Colors.white));
    c.drawCircle(const Offset(0.268, 0.28), 0.014, _p(const Color(0xFF23313A)));
    c.drawPath(Path()..moveTo(0.22, 0.24)..quadraticBezierTo(0.14, 0.14, 0.06, 0.16), _st(spec.b, 0.014));
  }

  void _egg(Canvas c) {
    final white = Path()
      ..moveTo(0.14, 0.50)
      ..cubicTo(0.10, 0.28, 0.34, 0.16, 0.52, 0.22)
      ..cubicTo(0.70, 0.14, 0.92, 0.30, 0.86, 0.52)
      ..cubicTo(0.92, 0.74, 0.66, 0.86, 0.50, 0.80)
      ..cubicTo(0.34, 0.88, 0.12, 0.72, 0.14, 0.50)
      ..close();
    c.drawPath(white, _lg(white.getBounds(), const Color(0xFFFFFFFF), const Color(0xFFE9E4D8)));
    _edge(c, white, const Color(0xFFE9E4D8));
    final yolk = Rect.fromCircle(center: const Offset(0.50, 0.50), radius: 0.17);
    c.drawOval(yolk, _rg(yolk, spec.a, spec.b));
    c.drawCircle(const Offset(0.45, 0.44), 0.04, _p(Colors.white.withOpacity(0.55)));
  }

  // ── fruit ─────────────────────────────────────────────────
  void _apple(Canvas c) {
    final body = Path()
      ..moveTo(0.50, 0.28)
      ..cubicTo(0.62, 0.18, 0.90, 0.26, 0.88, 0.54)
      ..cubicTo(0.86, 0.78, 0.68, 0.90, 0.50, 0.82)
      ..cubicTo(0.32, 0.90, 0.14, 0.78, 0.12, 0.54)
      ..cubicTo(0.10, 0.26, 0.38, 0.18, 0.50, 0.28)
      ..close();
    c.drawPath(body, _rg(body.getBounds(), spec.a, spec.b));
    _edge(c, body, spec.b);
    c.drawLine(const Offset(0.50, 0.28), const Offset(0.53, 0.13), _st(const Color(0xFF6B4226), 0.03));
    _leafAt(c, const Offset(0.54, 0.18), -0.5, 0.26, 0.08, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    _gloss(c, const Rect.fromLTRB(0.20, 0.34, 0.34, 0.50));
  }

  void _citrus(Canvas c) {
    final r = Rect.fromCircle(center: const Offset(0.5, 0.54), radius: 0.34);
    c.drawOval(r, _rg(r, spec.a, spec.b));
    c.drawOval(r, _st(_darken(spec.b, 0.35).withOpacity(0.5), 0.016));
    c.drawCircle(const Offset(0.5, 0.22), 0.02, _p(_darken(spec.b, 0.3)));
    _leafAt(c, const Offset(0.50, 0.21), -0.6, 0.24, 0.07, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    final dot = _p(_darken(spec.b, 0.15).withOpacity(0.35));
    c.drawCircle(const Offset(0.40, 0.60), 0.012, dot);
    c.drawCircle(const Offset(0.58, 0.66), 0.012, dot);
    c.drawCircle(const Offset(0.66, 0.50), 0.012, dot);
    _gloss(c, const Rect.fromLTRB(0.24, 0.36, 0.40, 0.50));
  }

  void _lemon(Canvas c) {
    c.save();
    c.translate(0.5, 0.54);
    c.rotate(-0.5);
    final p = Path()
      ..moveTo(-0.40, 0)
      ..cubicTo(-0.40, -0.22, -0.20, -0.28, 0, -0.28)
      ..cubicTo(0.20, -0.28, 0.40, -0.22, 0.40, 0)
      ..cubicTo(0.40, 0.22, 0.20, 0.28, 0, 0.28)
      ..cubicTo(-0.20, 0.28, -0.40, 0.22, -0.40, 0)
      ..close();
    c.drawPath(p, _rg(const Rect.fromLTRB(-0.4, -0.28, 0.4, 0.28), spec.a, spec.b));
    c.drawPath(p, _st(_darken(spec.b, 0.35).withOpacity(0.5), 0.016));
    c.drawCircle(const Offset(-0.41, 0), 0.04, _p(spec.b));
    c.drawCircle(const Offset(0.41, 0), 0.04, _p(spec.b));
    if (spec.v == 1) {
      _leafAt(c, const Offset(0.32, -0.20), -0.3, 0.22, 0.07, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    }
    c.drawOval(const Rect.fromLTRB(-0.26, -0.18, -0.06, -0.10), _p(Colors.white.withOpacity(0.32)));
    c.restore();
  }

  void _banana(Canvas c) {
    final b = Path()
      ..moveTo(0.12, 0.38)
      ..cubicTo(0.22, 0.80, 0.74, 0.92, 0.90, 0.28)
      ..lineTo(0.80, 0.26)
      ..cubicTo(0.70, 0.62, 0.34, 0.66, 0.20, 0.28)
      ..close();
    c.drawPath(b, _lg(b.getBounds(), spec.a, spec.b));
    _edge(c, b, spec.b);
    c.drawPath(Path()..moveTo(0.22, 0.42)..cubicTo(0.36, 0.70, 0.64, 0.72, 0.80, 0.40),
        _st(_darken(spec.b, 0.12).withOpacity(0.5), 0.016));
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(0.80, 0.18, 0.92, 0.30), const Radius.circular(0.02)),
        _p(const Color(0xFF6B4226)));
    c.drawCircle(const Offset(0.14, 0.38), 0.022, _p(const Color(0xFF6B4226)));
  }

  void _grapes(Canvas c) {
    const pts = <Offset>[
      Offset(0.34, 0.36), Offset(0.50, 0.34), Offset(0.66, 0.36),
      Offset(0.42, 0.52), Offset(0.58, 0.52), Offset(0.50, 0.68),
    ];
    c.drawLine(const Offset(0.50, 0.28), const Offset(0.50, 0.16), _st(const Color(0xFF6B4226), 0.03));
    _leafAt(c, const Offset(0.52, 0.20), -0.4, 0.28, 0.09, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    for (final p in pts) {
      final r = Rect.fromCircle(center: p, radius: 0.105);
      c.drawOval(r, _rg(r, spec.a, spec.b));
      c.drawCircle(p + const Offset(-0.035, -0.04), 0.022, _p(Colors.white.withOpacity(0.5)));
    }
  }

  void _berry(Canvas c) {
    final body = Path()
      ..moveTo(0.50, 0.88)
      ..cubicTo(0.20, 0.70, 0.12, 0.40, 0.22, 0.32)
      ..cubicTo(0.34, 0.24, 0.44, 0.30, 0.50, 0.34)
      ..cubicTo(0.56, 0.30, 0.66, 0.24, 0.78, 0.32)
      ..cubicTo(0.88, 0.40, 0.80, 0.70, 0.50, 0.88)
      ..close();
    c.drawPath(body, _rg(body.getBounds(), spec.a, spec.b));
    _edge(c, body, spec.b);
    final seed = _p(const Color(0xFFFFE9A8).withOpacity(0.9));
    for (final p in const <Offset>[
      Offset(0.34, 0.46), Offset(0.50, 0.44), Offset(0.66, 0.46),
      Offset(0.42, 0.58), Offset(0.58, 0.58), Offset(0.50, 0.72), Offset(0.30, 0.56), Offset(0.70, 0.56)
    ]) {
      c.drawOval(Rect.fromCenter(center: p, width: 0.025, height: 0.04), seed);
    }
    for (var i = 0; i < 5; i++) {
      _leafAt(c, const Offset(0.50, 0.32), -1.57 + (i - 2) * 0.62, 0.17, 0.05, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    }
  }

  void _melon(Canvas c) {
    Path half(double r) => Path()
      ..addArc(Rect.fromCircle(center: const Offset(0.5, 0.38), radius: r), 0, math.pi)
      ..close();
    c.drawPath(half(0.42), _p(const Color(0xFF2F9E44)));
    c.drawPath(half(0.375), _p(const Color(0xFFEAF6D8)));
    final flesh = half(0.345);
    c.drawPath(flesh, _lg(flesh.getBounds(), spec.a, _darken(spec.a, 0.12)));
    final seed = _p(const Color(0xFF3A2A22));
    for (final p in const <Offset>[Offset(0.34, 0.50), Offset(0.50, 0.56), Offset(0.66, 0.50), Offset(0.42, 0.66), Offset(0.60, 0.68)]) {
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(0.5);
      c.drawOval(const Rect.fromLTRB(-0.014, -0.026, 0.014, 0.026), seed);
      c.restore();
    }
  }

  void _pear(Canvas c) {
    final body = Path()
      ..moveTo(0.50, 0.14)
      ..cubicTo(0.60, 0.14, 0.60, 0.30, 0.64, 0.38)
      ..cubicTo(0.86, 0.50, 0.84, 0.86, 0.50, 0.88)
      ..cubicTo(0.16, 0.86, 0.14, 0.50, 0.36, 0.38)
      ..cubicTo(0.40, 0.30, 0.40, 0.14, 0.50, 0.14)
      ..close();
    c.drawPath(body, _rg(body.getBounds(), spec.a, spec.b));
    _edge(c, body, spec.b);
    if (spec.v == 1) {
      c.drawCircle(const Offset(0.50, 0.66), 0.09, _p(const Color(0xFFB5E36B)));
      c.drawCircle(const Offset(0.50, 0.66), 0.055, _p(const Color(0xFF7A4B2A)));
    }
    c.drawLine(const Offset(0.50, 0.15), const Offset(0.52, 0.05), _st(const Color(0xFF6B4226), 0.028));
    _leafAt(c, const Offset(0.53, 0.12), -0.35, 0.22, 0.07, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    _gloss(c, const Rect.fromLTRB(0.28, 0.52, 0.38, 0.68));
  }

  void _pineapple(Canvas c) {
    for (var i = 0; i < 5; i++) {
      _leafAt(c, const Offset(0.50, 0.28), -1.57 + (i - 2) * 0.42, 0.26, 0.06, const Color(0xFF6BC24A), const Color(0xFF237A33));
    }
    final body = Rect.fromCenter(center: const Offset(0.50, 0.60), width: 0.50, height: 0.58);
    c.drawOval(body, _rg(body, spec.a, spec.b));
    c.drawOval(body, _st(_darken(spec.b, 0.35).withOpacity(0.5), 0.016));
    c.save();
    c.clipPath(Path()..addOval(body));
    final g = _st(_darken(spec.b, 0.25).withOpacity(0.55), 0.014);
    for (var i = -3; i <= 3; i++) {
      c.drawLine(Offset(0.50 + i * 0.09 - 0.30, 0.30), Offset(0.50 + i * 0.09 + 0.30, 0.90), g);
      c.drawLine(Offset(0.50 + i * 0.09 + 0.30, 0.30), Offset(0.50 + i * 0.09 - 0.30, 0.90), g);
    }
    c.restore();
  }

  void _cherry(Canvas c) {
    c.drawPath(Path()..moveTo(0.34, 0.62)..quadraticBezierTo(0.40, 0.30, 0.54, 0.14), _st(const Color(0xFF5A7A1E), 0.026));
    c.drawPath(Path()..moveTo(0.66, 0.60)..quadraticBezierTo(0.62, 0.30, 0.54, 0.14), _st(const Color(0xFF5A7A1E), 0.026));
    _leafAt(c, const Offset(0.54, 0.15), -0.1, 0.26, 0.08, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    for (final p in const <Offset>[Offset(0.34, 0.72), Offset(0.66, 0.70)]) {
      final r = Rect.fromCircle(center: p, radius: 0.15);
      c.drawOval(r, _rg(r, spec.a, spec.b));
      c.drawCircle(p + const Offset(-0.05, -0.05), 0.03, _p(Colors.white.withOpacity(0.5)));
    }
  }

  void _date(Canvas c) {
    final frond = _st(const Color(0xFF3FA34D), 0.05);
    c.drawPath(Path()..moveTo(0.50, 0.46)..quadraticBezierTo(0.30, 0.10, 0.10, 0.22), frond);
    c.drawPath(Path()..moveTo(0.50, 0.46)..quadraticBezierTo(0.50, 0.08, 0.50, 0.06), frond);
    c.drawPath(Path()..moveTo(0.50, 0.46)..quadraticBezierTo(0.70, 0.10, 0.90, 0.22), frond);
    final leafy = _st(const Color(0xFF6BC24A), 0.026);
    c.drawPath(Path()..moveTo(0.34, 0.24)..lineTo(0.22, 0.30), leafy);
    c.drawPath(Path()..moveTo(0.66, 0.24)..lineTo(0.78, 0.30), leafy);
    c.drawPath(Path()..moveTo(0.50, 0.20)..lineTo(0.42, 0.28), leafy);
    c.drawPath(Path()..moveTo(0.50, 0.20)..lineTo(0.58, 0.28), leafy);
    void one(Offset p, double ang) {
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(ang);
      const r = Rect.fromLTRB(-0.11, -0.19, 0.11, 0.19);
      c.drawOval(r, _lg(r, spec.a, spec.b, Alignment.topLeft, Alignment.bottomRight));
      c.drawOval(const Rect.fromLTRB(-0.07, -0.14, -0.03, 0.0), _p(Colors.white.withOpacity(0.30)));
      c.restore();
    }
    one(const Offset(0.36, 0.68), -0.45);
    one(const Offset(0.62, 0.70), 0.40);
  }

  // ── greens & vegetables ───────────────────────────────────
  void _leaf(Canvas c) {
    final l = Path()
      ..moveTo(0.50, 0.88)
      ..cubicTo(0.08, 0.70, 0.10, 0.24, 0.50, 0.10)
      ..cubicTo(0.90, 0.24, 0.92, 0.70, 0.50, 0.88)
      ..close();
    c.drawPath(l, _lg(l.getBounds(), spec.a, spec.b, Alignment.topLeft, Alignment.bottomRight));
    _edge(c, l, spec.b);
    final vein = _st(Colors.white.withOpacity(0.45), 0.018);
    c.drawLine(const Offset(0.50, 0.86), const Offset(0.50, 0.20), vein);
    for (final y in <double>[0.36, 0.50, 0.64]) {
      c.drawLine(Offset(0.50, y + 0.08), Offset(0.50 - 0.18, y - 0.04), vein);
      c.drawLine(Offset(0.50, y + 0.08), Offset(0.50 + 0.18, y - 0.04), vein);
    }
  }

  void _sprout(Canvas c) {
    c.drawPath(Path()..moveTo(0.50, 0.88)..quadraticBezierTo(0.48, 0.64, 0.50, 0.46), _st(const Color(0xFF3FA34D), 0.04));
    _leafAt(c, const Offset(0.50, 0.50), -0.45, 0.34, 0.12, spec.a, spec.b);
    _leafAt(c, const Offset(0.50, 0.58), -2.7, 0.30, 0.11, spec.a, spec.b);
    c.drawOval(const Rect.fromLTRB(0.30, 0.86, 0.70, 0.92), _p(const Color(0xFF8A5A2B).withOpacity(0.7)));
  }

  void _broccoli(Canvas c) {
    final stalk = _poly(const <Offset>[Offset(0.42, 0.56), Offset(0.58, 0.56), Offset(0.64, 0.88), Offset(0.36, 0.88)]);
    c.drawPath(stalk, _lg(stalk.getBounds(), const Color(0xFFB5E36B), const Color(0xFF6BAA2F)));
    for (final p in const <Offset>[Offset(0.30, 0.48), Offset(0.70, 0.48), Offset(0.38, 0.30), Offset(0.62, 0.30), Offset(0.50, 0.22), Offset(0.50, 0.46)]) {
      final r = Rect.fromCircle(center: p, radius: 0.15);
      c.drawOval(r, _rg(r, spec.a, spec.b));
    }
    final dot = _p(_lighten(spec.a, 0.35).withOpacity(0.7));
    for (final p in const <Offset>[Offset(0.30, 0.44), Offset(0.50, 0.18), Offset(0.66, 0.30), Offset(0.42, 0.40), Offset(0.60, 0.50)]) {
      c.drawCircle(p, 0.014, dot);
    }
  }

  void _carrot(Canvas c) {
    c.save();
    c.translate(0.5, 0.54);
    c.rotate(0.55);
    c.scale(0.92, 0.92);
    for (final a in <double>[-2.2, -1.57, -0.95]) {
      _leafAt(c, const Offset(0, -0.30), a, 0.24, 0.06, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    }
    final body = Path()
      ..moveTo(-0.16, -0.30)
      ..cubicTo(-0.16, -0.38, 0.16, -0.38, 0.16, -0.30)
      ..cubicTo(0.16, -0.05, 0.06, 0.30, 0, 0.44)
      ..cubicTo(-0.06, 0.30, -0.16, -0.05, -0.16, -0.30)
      ..close();
    c.drawPath(body, _lg(const Rect.fromLTRB(-0.16, -0.36, 0.16, 0.44), spec.a, spec.b, Alignment.topLeft, Alignment.bottomRight));
    final ridge = _st(_darken(spec.b, 0.2).withOpacity(0.55), 0.016);
    c.drawLine(const Offset(-0.09, -0.18), const Offset(0.02, -0.18), ridge);
    c.drawLine(const Offset(-0.02, -0.02), const Offset(0.09, -0.02), ridge);
    c.drawLine(const Offset(-0.07, 0.14), const Offset(0.02, 0.14), ridge);
    c.restore();
  }

  void _tomato(Canvas c) {
    final r = Rect.fromCenter(center: const Offset(0.5, 0.57), width: 0.74, height: 0.62);
    c.drawOval(r, _rg(r, spec.a, spec.b));
    c.drawOval(r, _st(_darken(spec.b, 0.4).withOpacity(0.5), 0.016));
    if (spec.v == 1) {
      final rib = _st(_darken(spec.b, 0.2).withOpacity(0.5), 0.016);
      c.drawPath(Path()..moveTo(0.50, 0.30)..quadraticBezierTo(0.36, 0.57, 0.50, 0.86), rib);
      c.drawPath(Path()..moveTo(0.50, 0.30)..quadraticBezierTo(0.64, 0.57, 0.50, 0.86), rib);
    }
    for (var i = 0; i < 5; i++) {
      _leafAt(c, const Offset(0.50, 0.30), -1.57 + (i - 2) * 0.72, 0.18, 0.05, const Color(0xFF6BC24A), const Color(0xFF237A33));
    }
    c.drawLine(const Offset(0.50, 0.30), const Offset(0.50, 0.19), _st(const Color(0xFF237A33), 0.03));
    _gloss(c, const Rect.fromLTRB(0.22, 0.40, 0.36, 0.52));
  }

  void _bulb(Canvas c) {
    final p = Path()
      ..moveTo(0.50, 0.12)
      ..cubicTo(0.58, 0.30, 0.88, 0.40, 0.86, 0.62)
      ..cubicTo(0.84, 0.82, 0.66, 0.90, 0.50, 0.90)
      ..cubicTo(0.34, 0.90, 0.16, 0.82, 0.14, 0.62)
      ..cubicTo(0.12, 0.40, 0.42, 0.30, 0.50, 0.12)
      ..close();
    c.drawPath(p, _rg(p.getBounds(), spec.a, spec.b));
    _edge(c, p, spec.b);
    final line = _st(_darken(spec.b, 0.15).withOpacity(0.45), 0.016);
    c.drawPath(Path()..moveTo(0.50, 0.22)..quadraticBezierTo(0.30, 0.56, 0.42, 0.88), line);
    c.drawPath(Path()..moveTo(0.50, 0.22)..quadraticBezierTo(0.70, 0.56, 0.58, 0.88), line);
    c.drawLine(const Offset(0.50, 0.12), const Offset(0.52, 0.05), _st(_darken(spec.b, 0.1), 0.026));
  }

  void _potato(Canvas c) {
    final p = Path()
      ..moveTo(0.16, 0.50)
      ..cubicTo(0.14, 0.28, 0.40, 0.22, 0.58, 0.24)
      ..cubicTo(0.82, 0.26, 0.90, 0.46, 0.84, 0.64)
      ..cubicTo(0.78, 0.82, 0.50, 0.88, 0.32, 0.80)
      ..cubicTo(0.20, 0.74, 0.16, 0.62, 0.16, 0.50)
      ..close();
    c.drawPath(p, _rg(p.getBounds(), spec.a, spec.b));
    _edge(c, p, spec.b);
    final eye = _p(_darken(spec.b, 0.25).withOpacity(0.6));
    c.drawOval(const Rect.fromLTRB(0.30, 0.40, 0.35, 0.44), eye);
    c.drawOval(const Rect.fromLTRB(0.58, 0.54, 0.64, 0.58), eye);
    c.drawOval(const Rect.fromLTRB(0.44, 0.68, 0.49, 0.72), eye);
    c.drawOval(const Rect.fromLTRB(0.68, 0.36, 0.72, 0.40), eye);
  }

  // v: 0 cucumber, 1 corn, 2 eggplant, 3 pepper / chilli
  void _capsule(Canvas c) {
    c.save();
    c.translate(0.5, 0.54);
    c.rotate(-0.6);
    const body = Rect.fromLTRB(-0.40, -0.17, 0.40, 0.17);
    if (spec.v == 3) {
      final p = Path()
        ..moveTo(-0.38, -0.14)
        ..cubicTo(-0.10, -0.26, 0.24, -0.14, 0.44, 0.10)
        ..cubicTo(0.22, 0.12, -0.08, 0.26, -0.38, 0.14)
        ..close();
      c.drawPath(p, _lg(body, spec.a, spec.b, Alignment.topCenter, Alignment.bottomCenter));
      c.drawPath(p, _st(_darken(spec.b, 0.35).withOpacity(0.5), 0.016));
    } else {
      final r = RRect.fromRectAndRadius(body, const Radius.circular(0.17));
      c.drawRRect(r, _lg(body, spec.a, spec.b, Alignment.topCenter, Alignment.bottomCenter));
      c.drawRRect(r, _st(_darken(spec.b, 0.35).withOpacity(0.5), 0.016));
    }
    if (spec.v == 1) {
      final k = _p(const Color(0xFFFFF3B0).withOpacity(0.8));
      for (var i = 0; i < 6; i++) {
        for (var j = 0; j < 3; j++) {
          c.drawCircle(Offset(-0.26 + i * 0.1, -0.08 + j * 0.08), 0.022, k);
        }
      }
      _leafAt(c, const Offset(-0.36, 0.06), 3.4, 0.30, 0.09, const Color(0xFF8BE070), const Color(0xFF2F9E44));
    }
    if (spec.v == 2 || spec.v == 3) {
      final cal = Path()
        ..moveTo(-0.34, 0)
        ..cubicTo(-0.34, -0.14, -0.46, -0.16, -0.50, -0.06)
        ..cubicTo(-0.46, 0.02, -0.46, 0.10, -0.50, 0.14)
        ..cubicTo(-0.40, 0.18, -0.34, 0.12, -0.34, 0)
        ..close();
      c.drawPath(cal, _p(const Color(0xFF3FA34D)));
    }
    c.drawOval(const Rect.fromLTRB(-0.24, -0.12, 0.0, -0.07), _p(Colors.white.withOpacity(0.28)));
    c.restore();
  }

  void _mushroom(Canvas c) {
    final stem = RRect.fromRectAndRadius(const Rect.fromLTRB(0.38, 0.50, 0.62, 0.86), const Radius.circular(0.08));
    c.drawRRect(stem, _lg(const Rect.fromLTRB(0.38, 0.5, 0.62, 0.86), const Color(0xFFFFF8E6), const Color(0xFFE2D6B5)));
    final cap = Path()
      ..moveTo(0.10, 0.56)
      ..cubicTo(0.08, 0.16, 0.92, 0.16, 0.90, 0.56)
      ..quadraticBezierTo(0.50, 0.66, 0.10, 0.56)
      ..close();
    c.drawPath(cap, _rg(cap.getBounds(), spec.a, spec.b));
    _edge(c, cap, spec.b);
    final d = _p(Colors.white.withOpacity(0.85));
    c.drawCircle(const Offset(0.32, 0.40), 0.05, d);
    c.drawCircle(const Offset(0.54, 0.30), 0.06, d);
    c.drawCircle(const Offset(0.70, 0.44), 0.045, d);
    c.drawCircle(const Offset(0.46, 0.50), 0.03, d);
  }

  // v: 0 beans / peas, 1 peanuts, 2 almonds
  void _bean(Canvas c) {
    void one(Offset p, double ang, double scale) {
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(ang);
      c.scale(scale, scale);
      if (spec.v == 2) {
        final a = Path()
          ..moveTo(-0.17, 0)
          ..cubicTo(-0.13, -0.15, 0.10, -0.17, 0.20, 0)
          ..cubicTo(0.10, 0.17, -0.13, 0.15, -0.17, 0)
          ..close();
        c.drawPath(a, _lg(const Rect.fromLTRB(-0.17, -0.17, 0.2, 0.17), spec.a, spec.b));
        c.drawPath(a, _st(_darken(spec.b, 0.3).withOpacity(0.5), 0.02));
        c.drawLine(const Offset(-0.1, 0), const Offset(0.12, 0), _st(_darken(spec.b, 0.15).withOpacity(0.5), 0.014));
      } else if (spec.v == 1) {
        const r = Rect.fromLTRB(-0.20, -0.11, 0.20, 0.11);
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(0.11));
        c.drawRRect(rr, _lg(r, spec.a, spec.b));
        c.drawRRect(rr, _st(_darken(spec.b, 0.3).withOpacity(0.5), 0.02));
        c.drawLine(const Offset(0, -0.09), const Offset(0, 0.09), _st(_darken(spec.b, 0.1).withOpacity(0.5), 0.016));
      } else {
        const r = Rect.fromLTRB(-0.17, -0.11, 0.17, 0.11);
        c.drawOval(r, _lg(r, spec.a, spec.b));
        c.drawOval(r, _st(_darken(spec.b, 0.3).withOpacity(0.5), 0.02));
        c.drawOval(const Rect.fromLTRB(-0.10, -0.07, -0.02, -0.03), _p(Colors.white.withOpacity(0.35)));
      }
      c.restore();
    }
    one(const Offset(0.34, 0.40), -0.5, 1.0);
    one(const Offset(0.66, 0.46), 0.6, 1.0);
    one(const Offset(0.44, 0.70), 0.15, 1.0);
  }

  // ── sweets ────────────────────────────────────────────────
  void _cupcake(Canvas c) {
    final wrap = _poly(const <Offset>[Offset(0.22, 0.54), Offset(0.78, 0.54), Offset(0.70, 0.88), Offset(0.30, 0.88)]);
    c.drawPath(wrap, _lg(wrap.getBounds(), spec.b, _darken(spec.b, 0.18)));
    for (final x in <double>[0.36, 0.50, 0.64]) {
      c.drawLine(Offset(x - (x - 0.5) * 0.1, 0.57), Offset(x - (x - 0.5) * 0.35, 0.86), _st(Colors.white.withOpacity(0.28), 0.02));
    }
    for (final e in const <List<double>>[
      <double>[0.50, 0.50, 0.58, 0.18],
      <double>[0.50, 0.38, 0.46, 0.16],
      <double>[0.50, 0.27, 0.32, 0.14],
    ]) {
      final r = Rect.fromCenter(center: Offset(e[0], e[1]), width: e[2], height: e[3]);
      c.drawOval(r, _lg(r, _lighten(spec.a, 0.25), spec.a));
      c.drawOval(r, _st(_darken(spec.a, 0.3).withOpacity(0.4), 0.012));
    }
    c.drawCircle(const Offset(0.50, 0.17), 0.045, _p(const Color(0xFFE0394F)));
  }

  void _cookie(Canvas c) {
    c.drawCircle(const Offset(0.5, 0.52), 0.37, _rg(const Rect.fromLTRB(0.13, 0.15, 0.87, 0.89), spec.a, _darken(spec.a, 0.22)));
    c.drawCircle(const Offset(0.5, 0.52), 0.37, _st(_darken(spec.a, 0.4).withOpacity(0.5), 0.016));
    final chip = _p(spec.b);
    for (final p in const <Offset>[Offset(0.36, 0.38), Offset(0.60, 0.34), Offset(0.68, 0.56), Offset(0.46, 0.60), Offset(0.30, 0.62), Offset(0.54, 0.76), Offset(0.52, 0.48)]) {
      c.drawOval(Rect.fromCenter(center: p, width: 0.07, height: 0.055), chip);
    }
  }

  void _donut(Canvas c) {
    const ctr = Offset(0.5, 0.52);
    c.drawCircle(ctr, 0.25, _st(spec.b, 0.26));
    c.drawCircle(ctr + const Offset(0, -0.02), 0.25, _st(spec.a, 0.21));
    final sp = <Color>[Colors.white, const Color(0xFFFFE066), const Color(0xFF7BC8FF), const Color(0xFF8BE070)];
    for (var i = 0; i < 9; i++) {
      final a = i * 0.7;
      final p = ctr + Offset(math.cos(a) * 0.25, math.sin(a) * 0.25 - 0.02);
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a * 2);
      c.drawLine(const Offset(-0.022, 0), const Offset(0.022, 0), _st(sp[i % sp.length], 0.016));
      c.restore();
    }
  }

  void _chocolate(Canvas c) {
    const r = Rect.fromLTRB(0.22, 0.14, 0.78, 0.86);
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(0.06));
    c.drawRRect(rr, _lg(r, spec.a, spec.b));
    final g = _st(_darken(spec.b, 0.25).withOpacity(0.7), 0.014);
    for (final x in <double>[0.405, 0.59]) {
      c.drawLine(Offset(x, 0.16), Offset(x, 0.50), g);
    }
    for (final y in <double>[0.27, 0.38]) {
      c.drawLine(Offset(0.24, y), Offset(0.76, y), g);
    }
    final foil = _poly(const <Offset>[Offset(0.22, 0.50), Offset(0.78, 0.50), Offset(0.78, 0.80), Offset(0.22, 0.80)]);
    c.drawPath(foil, _lg(foil.getBounds(), const Color(0xFFFFE08A), const Color(0xFFDBA75D)));
    c.drawLine(const Offset(0.22, 0.50), const Offset(0.78, 0.50), _st(const Color(0xFFFFF3C4), 0.02));
    c.drawRRect(rr, _st(_darken(spec.b, 0.3).withOpacity(0.6), 0.016));
  }

  void _candy(Canvas c) {
    if (spec.v == 1) {
      c.drawLine(const Offset(0.50, 0.58), const Offset(0.50, 0.90), _st(const Color(0xFFF4EEDF), 0.04));
      final r = Rect.fromCircle(center: const Offset(0.5, 0.36), radius: 0.26);
      c.drawOval(r, _rg(r, spec.a, _darken(spec.a, 0.2)));
      c.drawArc(Rect.fromCircle(center: const Offset(0.5, 0.36), radius: 0.15), 0.4, 4.6, false, _st(spec.b, 0.04));
      return;
    }
    final l = _poly(const <Offset>[Offset(0.32, 0.50), Offset(0.10, 0.34), Offset(0.10, 0.66)]);
    final rt = _poly(const <Offset>[Offset(0.68, 0.50), Offset(0.90, 0.34), Offset(0.90, 0.66)]);
    c.drawPath(l, _p(spec.b));
    c.drawPath(rt, _p(spec.b));
    final body = Rect.fromCenter(center: const Offset(0.5, 0.5), width: 0.46, height: 0.36);
    c.drawOval(body, _rg(body, spec.b, spec.a));
    c.drawOval(body, _st(_darken(spec.a, 0.3).withOpacity(0.5), 0.016));
    c.drawLine(const Offset(0.42, 0.36), const Offset(0.36, 0.64), _st(Colors.white.withOpacity(0.45), 0.03));
    c.drawLine(const Offset(0.56, 0.34), const Offset(0.50, 0.66), _st(Colors.white.withOpacity(0.45), 0.03));
  }

  void _jar(Canvas c) {
    const body = Rect.fromLTRB(0.24, 0.28, 0.76, 0.88);
    final rr = RRect.fromRectAndRadius(body, const Radius.circular(0.10));
    c.drawRRect(rr, _p(const Color(0xFFBFD3E3).withOpacity(0.30)));
    final fill = RRect.fromRectAndRadius(const Rect.fromLTRB(0.255, 0.40, 0.745, 0.875), const Radius.circular(0.09));
    c.drawRRect(fill, _lg(const Rect.fromLTRB(0.25, 0.4, 0.75, 0.88), _lighten(spec.a, 0.15), _darken(spec.a, 0.12)));
    c.drawRRect(rr, _st(const Color(0xFF8FA6BC).withOpacity(0.85), 0.02));
    final lid = RRect.fromRectAndRadius(const Rect.fromLTRB(0.28, 0.16, 0.72, 0.30), const Radius.circular(0.04));
    c.drawRRect(lid, _lg(const Rect.fromLTRB(0.28, 0.16, 0.72, 0.30), _lighten(spec.b, 0.2), spec.b));
    final label = RRect.fromRectAndRadius(const Rect.fromLTRB(0.34, 0.52, 0.66, 0.74), const Radius.circular(0.04));
    c.drawRRect(label, _p(const Color(0xFFFFF8E6)));
    _leafAt(c, const Offset(0.50, 0.66), -0.9, 0.12, 0.04, const Color(0xFF6BC24A), const Color(0xFF237A33));
    _leafAt(c, const Offset(0.50, 0.66), -2.2, 0.12, 0.04, const Color(0xFF6BC24A), const Color(0xFF237A33));
  }

  void _icecream(Canvas c) {
    final cone = _poly(const <Offset>[Offset(0.32, 0.50), Offset(0.68, 0.50), Offset(0.50, 0.92)]);
    c.drawPath(cone, _lg(cone.getBounds(), spec.b, _darken(spec.b, 0.18)));
    final g = _st(_darken(spec.b, 0.35).withOpacity(0.55), 0.014);
    c.drawLine(const Offset(0.38, 0.54), const Offset(0.58, 0.80), g);
    c.drawLine(const Offset(0.46, 0.52), const Offset(0.62, 0.72), g);
    c.drawLine(const Offset(0.62, 0.54), const Offset(0.42, 0.80), g);
    c.drawLine(const Offset(0.54, 0.52), const Offset(0.38, 0.72), g);
    final scoop = Rect.fromCircle(center: const Offset(0.5, 0.38), radius: 0.22);
    c.drawOval(scoop, _rg(scoop, _lighten(spec.a, 0.2), spec.a));
    c.drawOval(const Rect.fromLTRB(0.27, 0.44, 0.73, 0.56), _p(spec.a));
    c.drawCircle(const Offset(0.5, 0.15), 0.04, _p(const Color(0xFFE0394F)));
    _gloss(c, const Rect.fromLTRB(0.34, 0.26, 0.44, 0.34));
  }

  // ── drinks & pantry ───────────────────────────────────────
  void _cup(Canvas c) {
    for (final x in <double>[0.34, 0.46]) {
      c.drawPath(Path()..moveTo(x, 0.30)..cubicTo(x - 0.05, 0.22, x + 0.05, 0.16, x, 0.08), _st(Colors.white.withOpacity(0.55), 0.03));
    }
    c.drawOval(const Rect.fromLTRB(0.10, 0.78, 0.80, 0.90), _p(spec.b.withOpacity(0.9)));
    c.drawPath(Path()..moveTo(0.70, 0.46)..cubicTo(0.90, 0.44, 0.90, 0.70, 0.66, 0.70), _st(spec.b, 0.065));
    const body = Rect.fromLTRB(0.20, 0.36, 0.70, 0.82);
    final rr = RRect.fromRectAndRadius(body, const Radius.circular(0.10));
    c.drawRRect(rr, _lg(body, spec.b, _darken(spec.b, 0.14), Alignment.centerLeft, Alignment.centerRight));
    c.drawOval(const Rect.fromLTRB(0.20, 0.32, 0.70, 0.44), _p(_darken(spec.b, 0.12)));
    c.drawOval(const Rect.fromLTRB(0.23, 0.335, 0.67, 0.425), _p(spec.a));
    c.drawPath(Path()..moveTo(0.26, 0.60)..quadraticBezierTo(0.45, 0.70, 0.64, 0.60), _st(const Color(0xFFDBA75D), 0.022));
  }

  void _glass(Canvas c) {
    final g = Path()
      ..moveTo(0.26, 0.22)
      ..lineTo(0.70, 0.22)
      ..lineTo(0.64, 0.88)
      ..lineTo(0.32, 0.88)
      ..close();
    c.drawPath(g, _p(const Color(0xFFBFD3E3).withOpacity(0.30)));
    c.drawLine(const Offset(0.56, 0.52), const Offset(0.66, 0.08), _st(spec.b, 0.045));
    final fill = Path()
      ..moveTo(0.272, 0.38)
      ..lineTo(0.688, 0.38)
      ..lineTo(0.64, 0.88)
      ..lineTo(0.32, 0.88)
      ..close();
    c.drawPath(fill, _lg(fill.getBounds(), _lighten(spec.a, 0.12), _darken(spec.a, 0.12)));
    c.drawOval(const Rect.fromLTRB(0.272, 0.35, 0.688, 0.41), _p(_lighten(spec.a, 0.3)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.31, 0.26, 0.345, 0.36), const Radius.circular(0.015)), _p(Colors.white.withOpacity(0.7)));
    c.drawPath(g, _st(const Color(0xFF8FA6BC).withOpacity(0.85), 0.02));
  }

  // v: 0 water, 1 oil, 2 salt shaker
  void _bottle(Canvas c) {
    if (spec.v == 2) {
      final d = Path()
        ..moveTo(0.28, 0.40)
        ..cubicTo(0.28, 0.12, 0.72, 0.12, 0.72, 0.40)
        ..lineTo(0.72, 0.86)
        ..quadraticBezierTo(0.72, 0.90, 0.68, 0.90)
        ..lineTo(0.32, 0.90)
        ..quadraticBezierTo(0.28, 0.90, 0.28, 0.86)
        ..close();
      c.drawPath(d, _lg(d.getBounds(), spec.a, spec.b, Alignment.centerLeft, Alignment.centerRight));
      c.drawPath(d, _st(_darken(spec.b, 0.3).withOpacity(0.6), 0.018));
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.34, 0.14, 0.66, 0.28), const Radius.circular(0.05)), _p(const Color(0xFFB0B7BE)));
      for (final p in const <Offset>[Offset(0.44, 0.21), Offset(0.50, 0.19), Offset(0.56, 0.21)]) {
        c.drawCircle(p, 0.012, _p(const Color(0xFF6B737B)));
      }
      return;
    }
    final neckTop = spec.v == 1 ? 0.08 : 0.12;
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(0.42, neckTop + 0.04, 0.58, 0.30), const Radius.circular(0.03)), _p(const Color(0xFFBFD3E3).withOpacity(0.55)));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(0.40, neckTop - 0.04, 0.60, neckTop + 0.04), const Radius.circular(0.025)), _p(spec.b));
    const body = Rect.fromLTRB(0.28, 0.26, 0.72, 0.90);
    final rr = RRect.fromRectAndRadius(body, const Radius.circular(0.12));
    c.drawRRect(rr, _p(const Color(0xFFBFD3E3).withOpacity(0.30)));
    final liquid = RRect.fromRectAndRadius(const Rect.fromLTRB(0.295, 0.40, 0.705, 0.885), const Radius.circular(0.11));
    c.drawRRect(liquid, _lg(const Rect.fromLTRB(0.3, 0.4, 0.7, 0.9), _lighten(spec.a, 0.15), _darken(spec.a, 0.10)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.28, 0.54, 0.72, 0.72), const Radius.circular(0.02)), _p(Colors.white.withOpacity(0.88)));
    _leafAt(c, const Offset(0.50, 0.64), -0.5, 0.11, 0.035, const Color(0xFF6BC24A), const Color(0xFF237A33));
    _leafAt(c, const Offset(0.50, 0.64), -2.6, 0.11, 0.035, const Color(0xFF6BC24A), const Color(0xFF237A33));
    c.drawRRect(rr, _st(const Color(0xFF8FA6BC).withOpacity(0.85), 0.02));
  }

  void _can(Canvas c) {
    const body = Rect.fromLTRB(0.24, 0.22, 0.76, 0.86);
    c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(0.05)), _lg(body, spec.a, _darken(spec.a, 0.2), Alignment.centerLeft, Alignment.centerRight));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.24, 0.42, 0.76, 0.68), const Radius.circular(0.01)), _p(spec.b));
    c.drawCircle(const Offset(0.50, 0.55), 0.07, _p(const Color(0xFFE0453A)));
    _leafAt(c, const Offset(0.50, 0.49), -1.2, 0.08, 0.03, const Color(0xFF6BC24A), const Color(0xFF237A33));
    c.drawOval(const Rect.fromLTRB(0.24, 0.17, 0.76, 0.28), _lg(const Rect.fromLTRB(0.24, 0.17, 0.76, 0.28), const Color(0xFFF2F4F6), const Color(0xFFB0B7BE)));
    c.drawOval(const Rect.fromLTRB(0.24, 0.80, 0.76, 0.91), _p(const Color(0xFFB0B7BE)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.24, 0.22, 0.76, 0.84), const Radius.circular(0.05)), _st(Colors.black.withOpacity(0.12), 0.012));
  }

  // ── fast food ─────────────────────────────────────────────
  void _burger(Canvas c) {
    final bunB = RRect.fromRectAndRadius(const Rect.fromLTRB(0.16, 0.68, 0.84, 0.82), const Radius.circular(0.07));
    c.drawRRect(bunB, _lg(const Rect.fromLTRB(0.16, 0.68, 0.84, 0.82), spec.a, spec.b));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.14, 0.56, 0.86, 0.68), const Radius.circular(0.06)), _lg(const Rect.fromLTRB(0.14, 0.56, 0.86, 0.68), const Color(0xFF8A4F2A), const Color(0xFF5A3320)));
    c.drawPath(
        Path()
          ..moveTo(0.12, 0.54)
          ..quadraticBezierTo(0.20, 0.62, 0.28, 0.54)
          ..quadraticBezierTo(0.36, 0.62, 0.44, 0.54)
          ..quadraticBezierTo(0.52, 0.62, 0.60, 0.54)
          ..quadraticBezierTo(0.68, 0.62, 0.76, 0.54)
          ..quadraticBezierTo(0.82, 0.60, 0.88, 0.54)
          ..lineTo(0.88, 0.50)
          ..lineTo(0.12, 0.50)
          ..close(),
        _p(const Color(0xFF6BC24A)));
    c.drawPath(_poly(const <Offset>[Offset(0.20, 0.48), Offset(0.80, 0.48), Offset(0.50, 0.60)]), _p(const Color(0xFFFFC83D)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(0.22, 0.42, 0.78, 0.49), const Radius.circular(0.03)), _p(const Color(0xFFE0453A)));
    final top = Path()
      ..moveTo(0.14, 0.44)
      ..cubicTo(0.14, 0.12, 0.86, 0.12, 0.86, 0.44)
      ..quadraticBezierTo(0.50, 0.50, 0.14, 0.44)
      ..close();
    c.drawPath(top, _lg(top.getBounds(), _lighten(spec.a, 0.12), spec.b));
    _edge(c, top, spec.b);
    final seed = _p(const Color(0xFFFFF3D0));
    for (final p in const <Offset>[Offset(0.34, 0.26), Offset(0.50, 0.20), Offset(0.66, 0.27), Offset(0.42, 0.35), Offset(0.60, 0.36)]) {
      c.drawOval(Rect.fromCenter(center: p, width: 0.05, height: 0.028), seed);
    }
  }

  void _pizza(Canvas c) {
    final slice = Path()
      ..moveTo(0.50, 0.90)
      ..lineTo(0.12, 0.26)
      ..quadraticBezierTo(0.50, 0.10, 0.88, 0.26)
      ..close();
    c.drawPath(slice, _lg(slice.getBounds(), spec.a, _darken(spec.a, 0.12)));
    c.drawPath(Path()..moveTo(0.12, 0.26)..quadraticBezierTo(0.50, 0.10, 0.88, 0.26), _st(const Color(0xFFE0A85A), 0.085));
    _edge(c, slice, const Color(0xFFE0A85A));
    final pep = _p(spec.b);
    c.drawCircle(const Offset(0.38, 0.37), 0.06, pep);
    c.drawCircle(const Offset(0.62, 0.35), 0.06, pep);
    c.drawCircle(const Offset(0.50, 0.55), 0.052, pep);
    c.drawCircle(const Offset(0.50, 0.73), 0.03, pep);
    c.drawCircle(const Offset(0.50, 0.34), 0.016, _p(const Color(0xFF6BC24A)));
  }

  // v: 0 fries, 1 popcorn
  void _fries(Canvas c) {
    if (spec.v == 1) {
      final kern = _p(const Color(0xFFFFF8D6));
      for (final p in const <Offset>[Offset(0.30, 0.44), Offset(0.44, 0.34), Offset(0.58, 0.30), Offset(0.70, 0.42), Offset(0.36, 0.30), Offset(0.52, 0.44), Offset(0.62, 0.20), Offset(0.46, 0.20)]) {
        c.drawCircle(p, 0.075, kern);
        c.drawCircle(p + const Offset(0.02, 0.025), 0.03, _p(const Color(0xFFFFD24D).withOpacity(0.8)));
      }
    } else {
      for (var i = 0; i < 6; i++) {
        final x = 0.30 + i * 0.075;
        c.save();
        c.translate(x, 0.52);
        c.rotate((i - 2.5) * 0.09);
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(-0.032, -0.30 - (i % 3) * 0.04, 0.032, 0.0), const Radius.circular(0.016)), _lg(const Rect.fromLTRB(-0.03, -0.38, 0.03, 0), _lighten(spec.a, 0.15), spec.a));
        c.restore();
      }
    }
    final box = _poly(const <Offset>[Offset(0.26, 0.50), Offset(0.74, 0.50), Offset(0.68, 0.88), Offset(0.32, 0.88)]);
    c.drawPath(box, _lg(box.getBounds(), spec.b, _darken(spec.b, 0.18)));
    c.drawPath(Path()..moveTo(0.50, 0.55)..lineTo(0.50, 0.84), _st(const Color(0xFFFFE066), 0.05));
    c.drawPath(box, _st(_darken(spec.b, 0.35).withOpacity(0.5), 0.014));
  }

  // ── themed plate: cream plate, gold crescent, green leaf ───
  void _plate(Canvas c) {
    _shadow(c, 0.7, 0.88);
    final outer = Rect.fromCircle(center: const Offset(0.5, 0.5), radius: 0.40);
    c.drawOval(outer, _lg(outer, spec.a, _darken(spec.a, 0.12), Alignment.topLeft, Alignment.bottomRight));
    c.drawOval(outer, _st(_darken(spec.a, 0.3).withOpacity(0.55), 0.016));
    c.drawCircle(const Offset(0.5, 0.5), 0.29, _st(_darken(spec.a, 0.18).withOpacity(0.6), 0.016));
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: const Offset(0.46, 0.50), radius: 0.16)),
      Path()..addOval(Rect.fromCircle(center: const Offset(0.53, 0.46), radius: 0.14)),
    );
    c.drawPath(moon, _lg(moon.getBounds(), const Color(0xFFFFE08A), spec.b));
    _leafAt(c, const Offset(0.56, 0.60), -0.55, 0.20, 0.06, const Color(0xFF8BE070), const Color(0xFF2F9E44));
  }
}
