import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/models/models.dart';
import 'halal_engine.dart';

// ──────────────────────────────────────────────────────────────
// Open Food Facts — free, open, 3M+ products
// Used for:
//   • Barcode lookup  → scanner_screen.dart (already inline)
//   • Name search     → ai_service.lookupFood() (this file)
// ──────────────────────────────────────────────────────────────
class OpenFoodFactsService {
  static const _ua = 'HalalCalorie/1.0 (Android; halal-tracking)';

  // ── Barcode lookup ──────────────────────────────────────────
  // Returns full product info including halal ingredient check.
  static Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
        '?fields=product_name,product_name_ar,brands,nutriments,ingredients_text,image_front_small_url,image_url',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null;

      final p   = body['product'] as Map<String, dynamic>;
      final n   = (p['nutriments'] ?? {}) as Map<String, dynamic>;
      final ing = _str(p['ingredients_text']);

      final nameAr = _str(p['product_name_ar'])
          .ifEmpty(() => _str(p['product_name']));
      final nameEn = _str(p['product_name']);
      final brand  = _str(p['brands']);

      return {
        'name_ar':      nameAr.isEmpty ? barcode : nameAr,
        'name_en':      nameEn.isEmpty ? barcode : nameEn,
        'brand':        brand,
        'kcal':         (_num(n, 'energy-kcal_100g') ??
                         ((_num(n, 'energy_100g') ?? 0) / 4.184)).round(), // energy_100g is kJ
        'protein_g':    (_num(n, 'proteins_100g')      ?? 0.0).toDouble(),
        'carbs_g':      (_num(n, 'carbohydrates_100g') ?? 0.0).toDouble(),
        'fat_g':        (_num(n, 'fat_100g')           ?? 0.0).toDouble(),
        'ingredients':  ing,
        'serving_size': '100g',
        'source':       'openfoodfacts',
        'image_url':    _str(p['image_front_small_url']).ifEmpty(() => _str(p['image_url'])),
      };
    } catch (_) {
      return null;
    }
  }

  // ── Name search (used by AIService.lookupFood) ──────────────
  // Picks the first result that actually has calorie data.
  // Returns per-100g nutrition or null if nothing useful found.
  static Future<Map<String, dynamic>?> searchByName(String query) async {
    if (query.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query.trim())}'
        '&json=1&page_size=8&page=1'
        '&fields=product_name,product_name_ar,brands,nutriments,image_front_small_url,image_url',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 9));
      if (resp.statusCode != 200) return null;

      final body     = jsonDecode(resp.body) as Map<String, dynamic>;
      final products = body['products'] as List<dynamic>? ?? [];
      if (products.isEmpty) return null;

      for (final raw in products) {
        final p   = raw as Map<String, dynamic>;
        final nut = (p['nutriments'] ?? {}) as Map<String, dynamic>;

        final kcal = (_num(nut, 'energy-kcal_100g') ?? 0).toDouble();
        if (kcal <= 0) continue; // skip entries with no calorie data

        final nameEn = _str(p['product_name']).ifEmpty(() => query);
        final nameAr = _str(p['product_name_ar']).ifEmpty(() => nameEn);
        final brand  = _str(p['brands']);

        return {
          'name_ar':    nameAr,
          'name_en':    brand.isNotEmpty ? '$nameEn ($brand)' : nameEn,
          'kcal':       kcal.round(),
          'protein_g':  (_num(nut, 'proteins_100g')      ?? 0.0).toDouble(),
          'carbs_g':    (_num(nut, 'carbohydrates_100g') ?? 0.0).toDouble(),
          'fat_g':      (_num(nut, 'fat_100g')           ?? 0.0).toDouble(),
          'serving_size': '100g',
          'halal':      true,
          'source':     'openfoodfacts',
          'image_url':  _str(p['image_front_small_url']).ifEmpty(() => _str(p['image_url'])),
        };
      }
      return null; // no result with nutrition data
    } catch (_) {
      return null; // network error — caller falls back to AI
    }
  }

  // ── Name search, all usable matches ─────────────────────────
  // The single-result [searchByName] above kept only the first hit, which
  // is why search felt like a lookup rather than a search. This returns
  // every product that carries calorie data, de-duplicated by name.
  static Future<List<Map<String, dynamic>>> searchManyByName(
    String query, {
    int limit = 20,
  }) async {
    if (query.trim().isEmpty) return const [];
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl'
        '?search_terms=${Uri.encodeComponent(query.trim())}'
        '&json=1&page_size=${(limit * 2).clamp(10, 50)}&page=1'
        '&fields=product_name,product_name_ar,brands,nutriments,'
        'image_front_small_url,image_url,serving_size',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final products = body['products'] as List<dynamic>? ?? const [];

      final out = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final raw in products) {
        if (out.length >= limit) break;
        if (raw is! Map<String, dynamic>) continue;
        final nut = (raw['nutriments'] ?? {}) as Map<String, dynamic>;

        final kcal = (_num(nut, 'energy-kcal_100g') ?? 0).toDouble();
        if (kcal <= 0) continue;

        final nameEn = _str(raw['product_name']);
        if (nameEn.isEmpty) continue;
        final brand = _str(raw['brands']);
        final label = brand.isNotEmpty ? '$nameEn ($brand)' : nameEn;

        // Skip near-duplicate listings of the same product.
        final dedupeKey = label.toLowerCase();
        if (!seen.add(dedupeKey)) continue;

        final nameAr = _str(raw['product_name_ar']).ifEmpty(() => nameEn);
        out.add({
          'name_ar': nameAr,
          'name_en': label,
          'brand': brand,
          'kcal': kcal.round(),
          'protein_g': (_num(nut, 'proteins_100g') ?? 0.0).toDouble(),
          'carbs_g': (_num(nut, 'carbohydrates_100g') ?? 0.0).toDouble(),
          'fat_g': (_num(nut, 'fat_100g') ?? 0.0).toDouble(),
          'serving_size': '100g',
          'halal': true,
          'source': 'openfoodfacts',
          'image_url': _str(raw['image_front_small_url'])
              .ifEmpty(() => _str(raw['image_url'])),
        });
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  // ── v55: rich barcode lookup ─────────────────────────────────
  // Same endpoint as above plus the fields the smart scanner needs.
  // [failed] = network/server problem (caller may use the offline cache);
  // data == null && !failed = the product really isn't in the database.
  static Future<({Map<String, dynamic>? data, bool failed})> lookupBarcodeFull(
      String barcode) async {
    if (barcode.trim().isEmpty) return (data: null, failed: false);
    try {
      final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/${barcode.trim()}.json'
        '?fields=product_name,product_name_ar,brands,nutriments,ingredients_text,'
        'image_front_small_url,image_url,serving_size,serving_quantity,quantity,'
        'nutriscore_grade,nova_group,allergens_tags,labels_tags,'
        'ingredients_analysis_tags,categories_tags,additives_tags',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 404) return (data: null, failed: false);
      if (resp.statusCode != 200) return (data: null, failed: true);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (body['status'] != 1) return (data: null, failed: false);

      final p = body['product'] as Map<String, dynamic>;
      final n = (p['nutriments'] ?? {}) as Map<String, dynamic>;
      final nameEn = _str(p['product_name']);
      final nameAr = _str(p['product_name_ar']);
      List<String> tags(dynamic v) => v is List
          ? [for (final e in v) '$e'.replaceFirst(RegExp(r'^[a-z]{2}:'), '')]
          : <String>[];

      double? servingG = _num(p, 'serving_quantity')?.toDouble();
      if (servingG == null) {
        final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*g\b')
            .firstMatch(_str(p['serving_size']).toLowerCase());
        if (m != null) {
          servingG = double.tryParse(m.group(1)!.replaceAll(',', '.'));
        }
      }
      final nova = _num(p, 'nova_group')?.toInt();
      final grade = _str(p['nutriscore_grade']).toLowerCase();

      return (
        failed: false,
        data: {
          'name': nameAr.isNotEmpty ? nameAr : nameEn,
          'brand': _str(p['brands']),
          'kcal': (_num(n, 'energy-kcal_100g') ??
                  ((_num(n, 'energy_100g') ?? 0) / 4.184))
              .round(),
          'protein_g': (_num(n, 'proteins_100g') ?? 0).toDouble(),
          'carbs_g': (_num(n, 'carbohydrates_100g') ?? 0).toDouble(),
          'fat_g': (_num(n, 'fat_100g') ?? 0).toDouble(),
          'sugar_g': _num(n, 'sugars_100g')?.toDouble(),
          'salt_g': _num(n, 'salt_100g')?.toDouble(),
          'satfat_g': _num(n, 'saturated-fat_100g')?.toDouble(),
          'fiber_g': _num(n, 'fiber_100g')?.toDouble(),
          'ingredients': _str(p['ingredients_text']),
          'image_url': _str(p['image_front_small_url'])
              .ifEmpty(() => _str(p['image_url'])),
          'serving_g': servingG,
          'quantity': _str(p['quantity']),
          'nutri': ['a', 'b', 'c', 'd', 'e'].contains(grade) ? grade : '',
          'nova': (nova != null && nova >= 1 && nova <= 4) ? nova : null,
          'allergens': tags(p['allergens_tags']),
          'labels': tags(p['labels_tags']),
          'analysis': tags(p['ingredients_analysis_tags']),
          'categories': p['categories_tags'] is List
              ? [for (final e in p['categories_tags'] as List) '$e']
              : <String>[],
        },
      );
    } catch (_) {
      return (data: null, failed: true);
    }
  }

  // ── v55: better products from the same category ──────────────
  // Nutri-Score A/B products in [categoryTag] whose ingredient list passes
  // the halal check. Returns at most [limit] entries.
  static Future<List<Map<String, dynamic>>> alternatives({
    required String categoryTag,
    String? excludeCode,
    int limit = 4,
  }) async {
    if (categoryTag.isEmpty) return const [];
    Future<List<Map<String, dynamic>>> one(String grade) async {
      try {
        final uri = Uri.parse(
          'https://world.openfoodfacts.org/api/v2/search'
          '?categories_tags=${Uri.encodeComponent(categoryTag)}'
          '&nutrition_grades_tags=$grade&sort_by=unique_scans_n&page_size=20'
          '&fields=code,product_name,brands,nutriscore_grade,ingredients_text,'
          'ingredients_analysis_tags,labels_tags,nutriments',
        );
        final resp = await http
            .get(uri, headers: {'User-Agent': _ua})
            .timeout(const Duration(seconds: 10));
        if (resp.statusCode != 200) return const [];
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = body['products'] as List<dynamic>? ?? const [];
        final out = <Map<String, dynamic>>[];
        for (final raw in list) {
          if (raw is! Map<String, dynamic>) continue;
          final code = _str(raw['code']);
          final name = _str(raw['product_name']);
          if (code.isEmpty || name.isEmpty || code == excludeCode) continue;
          final ing = _str(raw['ingredients_text']);
          if (ing.isEmpty) continue; // can't verify → don't recommend
          final analysis = raw['ingredients_analysis_tags'];
          final vegan = analysis is List && analysis.contains('en:vegan');
          final labels = raw['labels_tags'];
          final cert = labels is List &&
              labels.any((e) => '$e'.toLowerCase().contains('halal'));
          final rep = HalalEngine.analyze(ing, vegan: vegan, certified: cert);
          if (rep.status != HalalStatus.halal) continue;
          final nut = (raw['nutriments'] ?? {}) as Map<String, dynamic>;
          out.add({
            'code': code,
            'name': name,
            'brand': _str(raw['brands']),
            'grade': grade,
            'kcal': (_num(nut, 'energy-kcal_100g') ?? 0).round(),
          });
        }
        return out;
      } catch (_) {
        return const [];
      }
    }

    final res = await Future.wait([one('a'), one('b')]);
    return [...res[0], ...res[1]].take(limit).toList();
  }

  // ── Helpers ─────────────────────────────────────────────────
  static String _str(dynamic v) =>
      (v is String ? v : '').trim();

  static num? _num(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}

extension _StrExt on String {
  String ifEmpty(String Function() fallback) =>
      isEmpty ? fallback() : this;
}
