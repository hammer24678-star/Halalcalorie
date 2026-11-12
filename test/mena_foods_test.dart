import 'package:flutter_test/flutter_test.dart';
import 'package:halalcalorie/core/mena_foods.dart';

void main() {
  List<String> ids(String q) => [for (final f in MenaFoods.search(q)) f.id];

  group('MenaFoods.fold', () {
    test('unifies alef, ya, ta marbuta and strips tashkeel', () {
      expect(MenaFoods.fold('كُشَري'), MenaFoods.fold('كشرى'));
      expect(MenaFoods.fold('أم علي'), MenaFoods.fold('ام علي'));
      expect(MenaFoods.fold('كنافة'), MenaFoods.fold('كنافه'));
    });
  });

  group('MenaFoods.search', () {
    test('finds koshari in every spelling', () {
      for (final q in ['كشري', 'كشرى', 'الكشري', 'koshary', 'Kushari', 'kosheri']) {
        expect(ids(q), contains('koshari'), reason: q);
      }
    });
    test('finds dishes by transliteration', () {
      expect(ids('shawarma'), containsAll(['shawarma_chicken', 'shawarma_beef']));
      expect(ids('kabsa'), contains('kabsa_chicken'));
      expect(ids('molokhia'), contains('molokhia'));
      expect(ids('كنافة'), contains('kunafa_cheese'));
      expect(ids('عجوة'), contains('date_ajwa'));
    });
    test('multi-word queries must match every word', () {
      expect(ids('كبسة لحم').first, 'kabsa_lamb');
      expect(ids('chicken kabsa'), contains('kabsa_chicken'));
    });
    test('empty and unknown queries return nothing', () {
      expect(MenaFoods.search('   '), isEmpty);
      expect(MenaFoods.search('zzzzqq'), isEmpty);
    });
    test('names starting with the query rank first', () {
      expect(ids('فول').first, 'ful_medames');
    });
  });

  group('kMenaFoods data', () {
    test('ids are unique and every category/region is declared', () {
      final seen = <String>{};
      final cats = {for (final c in kMenaCategories) c.$1};
      for (final f in kMenaFoods) {
        expect(seen.add(f.id), isTrue, reason: 'duplicate ${f.id}');
        expect(cats, contains(f.cat), reason: f.id);
        expect(kMenaRegions.containsKey(f.region), isTrue, reason: f.id);
        expect(f.servings, isNotEmpty, reason: f.id);
      }
    });
    test('macros agree with the stated energy (Atwater, 13% tolerance)', () {
      for (final f in kMenaFoods) {
        final atwater = 4 * f.protein + 4 * f.carbs + 9 * f.fat;
        if (f.kcal < 5) continue;
        expect((atwater - f.kcal).abs() / f.kcal, lessThan(0.13), reason: f.id);
      }
    });
    test('featured ids all exist', () {
      expect(MenaFoods.featured().length, kMenaFeatured.length);
    });
    test('every category has at least one food', () {
      for (final c in kMenaCategories) {
        expect(MenaFoods.inCategory(c.$1), isNotEmpty, reason: c.$1);
      }
    });
  });
}
