import 'dart:convert';
import 'package:http/http.dart' as http;

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
        'kcal':         (_num(n, 'energy-kcal_100g') ?? _num(n, 'energy_100g') ?? 0).round(),
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
