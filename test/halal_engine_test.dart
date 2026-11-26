// halal_engine_test.dart - PATCH_V62
// Fixtures for the ingredient engine: English, other languages (the false-halal
// bug), unreadable lists and Open Food Facts tags.
import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/halal_engine.dart';
import 'package:halalcalorie/data/models/models.dart';

void main() {
  group('HalalEngine: English', () {
    test('plain list with nothing flagged is halal and reliable', () {
      final r = HalalEngine.analyze('Sugar, wheat flour, palm oil, salt', lang: 'en');
      expect(r.status, HalalStatus.halal);
      expect(r.reliable, isTrue);
    });
    test('pork is haram', () {
      expect(HalalEngine.analyze('Water, pork gelatin, sugar').status, HalalStatus.haram);
    });
    test('gelatin alone is doubtful, halal label rescues it', () {
      expect(HalalEngine.analyze('Sugar, gelatin').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Sugar, gelatin', certified: true).status, HalalStatus.halal);
    });
    test('sugar alcohol and wine vinegar are not haram', () {
      expect(HalalEngine.analyze('sugar alcohol, xylitol').status, isNot(HalalStatus.haram));
      expect(HalalEngine.analyze('wine vinegar, olive oil').status, HalalStatus.doubtful);
    });
    test('empty list is unknown unless certified', () {
      expect(HalalEngine.analyze('').status, HalalStatus.unknown);
      expect(HalalEngine.analyze('', certified: true).status, HalalStatus.halal);
    });
  });

  group('HalalEngine: other languages (the false-halal bug)', () {
    test('French lard and pork', () {
      expect(HalalEngine.analyze('Farine, sucre, saindoux, sel', lang: 'fr').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Jambon cuit, eau', lang: 'fr').status, HalalStatus.haram);
    });
    test('French alcohol is doubtful, "sans alcool" is not flagged', () {
      expect(HalalEngine.analyze('Eau, sucre, alcool', lang: 'fr').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Boisson sans alcool, eau, sucre', lang: 'fr').status, HalalStatus.halal);
    });
    test('French wine vinegar is doubtful, not haram', () {
      expect(HalalEngine.analyze('Vinaigre de vin, huile', lang: 'fr').status, HalalStatus.doubtful);
    });
    test('French gelatin and meat', () {
      expect(HalalEngine.analyze('Sucre, gélatine', lang: 'fr').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Poulet, eau, sel', lang: 'fr').status, HalalStatus.doubtful);
    });
    test('Spanish, German, Turkish, Indonesian pork', () {
      expect(HalalEngine.analyze('Pan, jamón serrano, sal', lang: 'es').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Wasser, Schweinefleisch', lang: 'de').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Şeker, buğday unu, domuz yağı', lang: 'tr').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Gula, tepung, lemak babi', lang: 'id').status, HalalStatus.haram);
    });
    test('wine and beer words', () {
      expect(HalalEngine.analyze('Salsa, vino tinto', lang: 'es').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Wasser, Bier, Malz', lang: 'de').status, HalalStatus.haram);
    });
    test('Arabic labels', () {
      expect(HalalEngine.analyze('سكر، دقيق، جيلاتين', lang: 'ar').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('ماء، لحم الخنزير', lang: 'ar').status, HalalStatus.haram);
      expect(HalalEngine.analyze('سكر، دقيق، ملح', lang: 'ar').status, HalalStatus.halal);
    });
    test('porcini mushrooms are not pork', () {
      expect(HalalEngine.analyze('Porcini mushrooms, olive oil', lang: 'en').status, HalalStatus.halal);
    });
    test('clean French list is halal and reliable', () {
      final r = HalalEngine.analyze('Sucre, farine de blé, huile de palme, sel', lang: 'fr');
      expect(r.status, HalalStatus.halal);
      expect(r.reliable, isTrue);
    });
  });

  group('HalalEngine: v63 pork/lard terms in more languages', () {
    test('French jambonneau and cochonnaille', () {
      expect(HalalEngine.analyze('Jambonneau, eau, sel', lang: 'fr').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Cochonnaille, sel', lang: 'fr').status, HalalStatus.haram);
    });
    test('Italian, Portuguese, Dutch, Polish lard/pork with no language given', () {
      expect(HalalEngine.analyze('farina, strutto, sale').status, HalalStatus.haram);
      expect(HalalEngine.analyze('farinha, banha, sal').status, HalalStatus.haram);
      expect(HalalEngine.analyze('water, varkensvlees, zout').status, HalalStatus.haram);
      expect(HalalEngine.analyze('woda, wieprzowina, sol').status, HalalStatus.haram);
    });
    test('porcini and porcelain-like words are still not pork', () {
      expect(HalalEngine.analyze('Porcini mushrooms, cream', lang: 'en').status, HalalStatus.halal);
    });
    test('sausage products are doubtful; halal label clears them', () {
      expect(HalalEngine.analyze('Chorizo, paprika', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Beef pepperoni', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Chorizo, paprika', lang: 'en', certified: true).status, HalalStatus.halal);
      expect(HalalEngine.analyze('Chorizo, paprika', lang: 'en', vegan: true).status, HalalStatus.halal);
    });
  });

  group('HalalEngine: unreadable lists never say halal', () {
    test('Russian text without tags is unknown and unreliable', () {
      final r = HalalEngine.analyze('сахар, мука, соль', lang: 'ru');
      expect(r.status, HalalStatus.unknown);
      expect(r.reliable, isFalse);
    });
    test('Italian is not covered, so unknown', () {
      expect(HalalEngine.analyze('zucchero, farina, sale', lang: 'it').status, HalalStatus.unknown);
    });
    test('Cyrillic with no language given is unknown', () {
      expect(HalalEngine.analyze('сахар, мука').status, HalalStatus.unknown);
    });
    test('enough en: tags make an unreadable list judgeable', () {
      final r = HalalEngine.analyze('сахар, мука, соль', lang: 'ru',
          tags: ['en:sugar', 'en:wheat-flour', 'en:salt']);
      expect(r.status, HalalStatus.halal);
      expect(r.reliable, isTrue);
    });
    test('a flag in an unreadable list still counts', () {
      final r = HalalEngine.analyze('сахар, свинина', lang: 'ru', tags: ['en:pork']);
      expect(r.status, HalalStatus.haram);
    });
    test('certified halal label wins over unreadable text', () {
      expect(HalalEngine.analyze('zucchero', lang: 'it', certified: true).status, HalalStatus.halal);
    });
  });

  group('HalalEngine: tags and English rendering', () {
    test('tags alone can be judged', () {
      expect(HalalEngine.analyze('', tags: ['en:pork', 'en:salt']).status, HalalStatus.haram);
    });
    test('English rendering is used when the original is in another language', () {
      final r = HalalEngine.analyze('сахар, свинина', lang: 'ru', englishText: 'sugar, pork');
      expect(r.status, HalalStatus.haram);
    });
    test('E-numbers still work in any language', () {
      expect(HalalEngine.analyze('Sucre, E120', lang: 'fr').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Sucre, E441', lang: 'fr').status, HalalStatus.doubtful);
    });
  });

  // v66: wrong "halal" verdicts are the costly kind for this app, so each of
  // these used to come back halal (or, for the last group, wrongly haram).
  group('HalalEngine: v66 false-halal fixes', () {
    test('E-numbers with a space are read: E 120 is haram, E 471 doubtful', () {
      expect(HalalEngine.analyze('Sugar, colour (E 120)', lang: 'en').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Sugar, Emulgator (E 471), Salz', lang: 'de').status, HalalStatus.doubtful);
    });
    test('L-cystine, E921 and the nucleotide family are doubtful', () {
      expect(HalalEngine.analyze('Sugar, L-cystine', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Flour, E921', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Soup, E634', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Stock, E 626, E 630', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Sauce, E1000', lang: 'en').status, HalalStatus.doubtful);
    });
    test('plurals, meatballs and sausages are no longer halal by default', () {
      expect(HalalEngine.analyze('Chickens, water', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Meatballs, tomato sauce', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Wheat flour, sausage, onion', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Frankfurter, mustard', lang: 'en').status, HalalStatus.doubtful);
      expect(HalalEngine.analyze('Wheat flour, sausage, onion', lang: 'en', certified: true).status, HalalStatus.halal);
    });
  });

  group('HalalEngine: v66 false alarms', () {
    test('goat dairy is not meat, goat meat is', () {
      expect(HalalEngine.analyze('Goat milk, salt, cultures', lang: 'en').status, HalalStatus.halal);
      expect(HalalEngine.analyze('Goat’s milk cheese, salt', lang: 'en').status, HalalStatus.halal);
      expect(HalalEngine.analyze('Goat\'s milk, salt', lang: 'en').status, HalalStatus.halal);
      expect(HalalEngine.analyze('Goat meat, salt', lang: 'en').status, HalalStatus.doubtful);
    });
    test('root beer and "non alcoholic" are not alcohol; real alcohol still is', () {
      expect(HalalEngine.analyze('Carbonated water, sugar, root beer flavour', lang: 'en').status, isNot(HalalStatus.haram));
      expect(HalalEngine.analyze('Water, non alcoholic malt, sugar', lang: 'en').status, isNot(HalalStatus.haram));
      expect(HalalEngine.analyze('Water, beer, malt', lang: 'en').status, HalalStatus.haram);
      expect(HalalEngine.analyze('Water, sugar, alcohol', lang: 'en').status, HalalStatus.haram);
    });
    test('chickpeas are not chicken', () {
      expect(HalalEngine.analyze('Chickpeas, tahini, lemon', lang: 'en').status, HalalStatus.halal);
    });
  });
}
