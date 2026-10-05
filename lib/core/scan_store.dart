// scan_store.dart — persistent scan history, favourites and offline cache (v55)
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/models.dart';

class ScanStore {
  static const _kHistory = 'scan_history_v2';
  static const _kFavs    = 'scan_favs_v1';
  static const _kCache   = 'scan_cache_v1';
  static const _cacheMax = 80;

  static Map<String, dynamic> toJson(ScanResult r) => {
        'b': r.barcode, 'n': r.name, 'br': r.brand,
        's': r.status.index, 'c': r.certs, 'no': r.notes,
        'at': r.scannedAt.toIso8601String(),
        'k': r.kcal, 'p': r.proteinG, 'ca': r.carbsG, 'f': r.fatG,
        'd': r.details,
      };

  static ScanResult fromJson(Map<String, dynamic> j) => ScanResult(
        barcode: (j['b'] ?? '') as String,
        name: (j['n'] ?? '') as String,
        brand: j['br'] as String?,
        status: HalalStatus.values[((j['s'] ?? 3) as int)
            .clamp(0, HalalStatus.values.length - 1)],
        certs: ((j['c'] ?? const []) as List).map((e) => '$e').toList(),
        notes: j['no'] as String?,
        scannedAt: DateTime.tryParse((j['at'] ?? '') as String),
        kcal: (j['k'] as num?)?.toInt(),
        proteinG: (j['p'] as num?)?.toDouble(),
        carbsG: (j['ca'] as num?)?.toDouble(),
        fatG: (j['f'] as num?)?.toDouble(),
        details: j['d'] == null
            ? null
            : Map<String, dynamic>.from(j['d'] as Map),
      );

  // ── History ────────────────────────────────────────────
  static Future<List<ScanResult>> loadHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kHistory);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          if (e is Map) fromJson(Map<String, dynamic>.from(e))
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveHistory(List<ScanResult> h) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _kHistory, jsonEncode([for (final r in h.take(100)) toJson(r)]));
    } catch (_) {}
  }

  // ── Offline cache (barcode → last good lookup) ─────────
  static Future<ScanResult?> cacheGet(String barcode) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kCache);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final e = m[barcode];
      if (e is! Map) return null;
      return fromJson(Map<String, dynamic>.from(e));
    } catch (_) {
      return null;
    }
  }

  static Future<void> cachePut(ScanResult r) async {
    try {
      final p = await SharedPreferences.getInstance();
      Map<String, dynamic> m = {};
      final raw = p.getString(_kCache);
      if (raw != null) m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      m.remove(r.barcode);
      m[r.barcode] = toJson(r);
      while (m.length > _cacheMax) {
        m.remove(m.keys.first);
      }
      await p.setString(_kCache, jsonEncode(m));
    } catch (_) {}
  }

  // ── Favourites ─────────────────────────────────────────
  static Future<Set<String>> loadFavs() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_kFavs) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavs(Set<String> s) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_kFavs, s.toList());
    } catch (_) {}
  }
}

class ScanFavsNotifier extends StateNotifier<Set<String>> {
  ScanFavsNotifier() : super(const {}) {
    ScanStore.loadFavs().then((s) {
      if (mounted) state = {...state, ...s};
    });
  }
  bool has(String barcode) => state.contains(barcode);
  void toggle(String barcode) {
    final n = {...state};
    if (!n.remove(barcode)) n.add(barcode);
    state = n;
    ScanStore.saveFavs(n);
  }
}

final scanFavsProvider =
    StateNotifierProvider<ScanFavsNotifier, Set<String>>(
        (ref) => ScanFavsNotifier());
