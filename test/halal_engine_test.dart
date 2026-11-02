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
}
