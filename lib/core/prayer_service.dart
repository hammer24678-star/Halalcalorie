// ============================================================
//  prayer_service.dart — HalalCalorie
//  Real prayer times via Aladhan API (free, no key needed)
//  Shows Fajr, Dhuhr, Asr, Maghrib, Isha on home screen
// ============================================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PrayerService {
  static const _base = 'https://api.aladhan.com/v1';

  // ── Fetch today's prayer times ────────────────────────────
  static Future<PrayerTimes?> getTodayTimes({
    required double lat,
    required double lng,
    int method = 5,  // 5 = Egypt GODAA, 4 = UmmAlQura, 2 = ISNA
  }) async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
        '$_base/timings/${now.day}-${now.month}-${now.year}'
        '?latitude=$lat&longitude=$lng&method=$method'
      );

      final resp = await http.get(url,
          headers: {'User-Agent': 'HalalCalorie/1.0'})
          .timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 200) return null;

      final timings = data['data']['timings'] as Map<String, dynamic>;
      return PrayerTimes.fromMap(timings, now);
    } catch (e) {
      debugPrint('PrayerService error: $e');
      return null;
    }
  }

  // ── Get times by city name (fallback) ─────────────────────
  static Future<PrayerTimes?> getTimesByCity({
    required String city,
    required String country,
    int method = 5,
  }) async {
    try {
      final now = DateTime.now();
      final url = Uri.parse(
        '$_base/timingsByCity/${now.day}-${now.month}-${now.year}'
        '?city=${Uri.encodeComponent(city)}'
        '&country=${Uri.encodeComponent(country)}'
        '&method=$method'
      );

      final resp = await http.get(url)
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['code'] != 200) return null;

      final timings = data['data']['timings'] as Map<String, dynamic>;
      return PrayerTimes.fromMap(timings, now);
    } catch (e) {
      debugPrint('PrayerService city error: $e');
      return null;
    }
  }
}

// ── Prayer times model ────────────────────────────────────────────
class PrayerTimes {
  final DateTime fajr;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final DateTime sunrise;
  final DateTime date;

  const PrayerTimes({
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.sunrise,
    required this.date,
  });

  factory PrayerTimes.fromMap(Map<String, dynamic> t, DateTime date) {
    DateTime parse(String time) {
      final parts = time.split(':');
      return DateTime(date.year, date.month, date.day,
          int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1].split(' ')[0]) ?? 0);
    }
    return PrayerTimes(
      fajr:    parse(t['Fajr']    as String),
      sunrise: parse(t['Sunrise'] as String),
      dhuhr:   parse(t['Dhuhr']   as String),
      asr:     parse(t['Asr']     as String),
      maghrib: parse(t['Maghrib'] as String),
      isha:    parse(t['Isha']    as String),
      date:    date,
    );
  }

  // Next prayer from now
  PrayerInfo get nextPrayer {
    final now = DateTime.now();
    final prayers = [
      PrayerInfo('الفجر',    'Fajr',    fajr),
      PrayerInfo('الشروق',   'Sunrise', sunrise),
      PrayerInfo('الظهر',    'Dhuhr',   dhuhr),
      PrayerInfo('العصر',    'Asr',     asr),
      PrayerInfo('المغرب',   'Maghrib', maghrib),
      PrayerInfo('العشاء',   'Isha',    isha),
    ];
    for (final p in prayers) {
      if (p.time.isAfter(now)) return p;
    }
    // All done today — return Fajr tomorrow
    return PrayerInfo('الفجر', 'Fajr',
        fajr.add(const Duration(days: 1)));
  }

  Duration get timeToNextPrayer {
    return nextPrayer.time.difference(DateTime.now());
  }

  List<PrayerInfo> get allPrayers => [
    PrayerInfo('الفجر',   'Fajr',    fajr),
    PrayerInfo('الظهر',   'Dhuhr',   dhuhr),
    PrayerInfo('العصر',   'Asr',     asr),
    PrayerInfo('المغرب',  'Maghrib', maghrib),
    PrayerInfo('العشاء',  'Isha',    isha),
  ];

  String formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:$m $ampm';
  }
}

class PrayerInfo {
  final String nameAr;
  final String nameEn;
  final DateTime time;
  const PrayerInfo(this.nameAr, this.nameEn, this.time);
}
