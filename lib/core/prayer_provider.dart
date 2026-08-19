// ════════════════════════════════════════════════════════════════════
//  prayer_provider.dart — prayer times for the selected city
//
//  The city is stored in whatever language the user picked it in, so
//  the lookup matches on both the Arabic and English spellings and
//  falls back to coordinates. An unrecognised city used to be sent to
//  the API with an empty country, which simply failed and left the
//  whole card blank.
// ════════════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'prayer_service.dart';
import 'providers.dart';

/// City → (english name, country, latitude, longitude).
/// Arabic spellings map to the same entry so either form resolves.
const _kCities = <String, (String, String, double, double)>{
  'cairo': ('Cairo', 'Egypt', 30.0444, 31.2357),
  'القاهرة': ('Cairo', 'Egypt', 30.0444, 31.2357),
  'alexandria': ('Alexandria', 'Egypt', 31.2001, 29.9187),
  'الإسكندرية': ('Alexandria', 'Egypt', 31.2001, 29.9187),
  'giza': ('Giza', 'Egypt', 30.0131, 31.2089),
  'الجيزة': ('Giza', 'Egypt', 30.0131, 31.2089),
  'riyadh': ('Riyadh', 'Saudi Arabia', 24.7136, 46.6753),
  'الرياض': ('Riyadh', 'Saudi Arabia', 24.7136, 46.6753),
  'jeddah': ('Jeddah', 'Saudi Arabia', 21.4858, 39.1925),
  'جدة': ('Jeddah', 'Saudi Arabia', 21.4858, 39.1925),
  'mecca': ('Makkah', 'Saudi Arabia', 21.3891, 39.8579),
  'مكة': ('Makkah', 'Saudi Arabia', 21.3891, 39.8579),
  'medina': ('Madinah', 'Saudi Arabia', 24.5247, 39.5692),
  'المدينة': ('Madinah', 'Saudi Arabia', 24.5247, 39.5692),
  'dubai': ('Dubai', 'United Arab Emirates', 25.2048, 55.2708),
  'دبي': ('Dubai', 'United Arab Emirates', 25.2048, 55.2708),
  'abu dhabi': ('Abu Dhabi', 'United Arab Emirates', 24.4539, 54.3773),
  'أبوظبي': ('Abu Dhabi', 'United Arab Emirates', 24.4539, 54.3773),
  'doha': ('Doha', 'Qatar', 25.2854, 51.5310),
  'الدوحة': ('Doha', 'Qatar', 25.2854, 51.5310),
  'kuwait city': ('Kuwait City', 'Kuwait', 29.3759, 47.9774),
  'الكويت': ('Kuwait City', 'Kuwait', 29.3759, 47.9774),
  'manama': ('Manama', 'Bahrain', 26.2285, 50.5860),
  'المنامة': ('Manama', 'Bahrain', 26.2285, 50.5860),
  'muscat': ('Muscat', 'Oman', 23.5880, 58.3829),
  'مسقط': ('Muscat', 'Oman', 23.5880, 58.3829),
  'amman': ('Amman', 'Jordan', 31.9454, 35.9284),
  'عمان': ('Amman', 'Jordan', 31.9454, 35.9284),
  'beirut': ('Beirut', 'Lebanon', 33.8938, 35.5018),
  'بيروت': ('Beirut', 'Lebanon', 33.8938, 35.5018),
  'damascus': ('Damascus', 'Syria', 33.5138, 36.2765),
  'دمشق': ('Damascus', 'Syria', 33.5138, 36.2765),
  'baghdad': ('Baghdad', 'Iraq', 33.3152, 44.3661),
  'بغداد': ('Baghdad', 'Iraq', 33.3152, 44.3661),
  'istanbul': ('Istanbul', 'Turkey', 41.0082, 28.9784),
  'إسطنبول': ('Istanbul', 'Turkey', 41.0082, 28.9784),
  'ankara': ('Ankara', 'Turkey', 39.9334, 32.8597),
  'karachi': ('Karachi', 'Pakistan', 24.8607, 67.0011),
  'كراتشي': ('Karachi', 'Pakistan', 24.8607, 67.0011),
  'lahore': ('Lahore', 'Pakistan', 31.5204, 74.3587),
  'islamabad': ('Islamabad', 'Pakistan', 33.6844, 73.0479),
  'jakarta': ('Jakarta', 'Indonesia', -6.2088, 106.8456),
  'kuala lumpur': ('Kuala Lumpur', 'Malaysia', 3.1390, 101.6869),
  'casablanca': ('Casablanca', 'Morocco', 33.5731, -7.5898),
  'الدار البيضاء': ('Casablanca', 'Morocco', 33.5731, -7.5898),
  'tunis': ('Tunis', 'Tunisia', 36.8065, 10.1815),
  'تونس': ('Tunis', 'Tunisia', 36.8065, 10.1815),
  'algiers': ('Algiers', 'Algeria', 36.7538, 3.0588),
  'الجزائر': ('Algiers', 'Algeria', 36.7538, 3.0588),
  'khartoum': ('Khartoum', 'Sudan', 15.5007, 32.5599),
  'الخرطوم': ('Khartoum', 'Sudan', 15.5007, 32.5599),
  'london': ('London', 'United Kingdom', 51.5074, -0.1278),
  'لندن': ('London', 'United Kingdom', 51.5074, -0.1278),
  'paris': ('Paris', 'France', 48.8566, 2.3522),
  'باريس': ('Paris', 'France', 48.8566, 2.3522),
  'berlin': ('Berlin', 'Germany', 52.5200, 13.4050),
  'new york': ('New York', 'United States', 40.7128, -74.0060),
  'toronto': ('Toronto', 'Canada', 43.6532, -79.3832),
  'sydney': ('Sydney', 'Australia', -33.8688, 151.2093),
};

/// Cairo, used when the stored city cannot be resolved at all.
const _fallback = (30.0444, 31.2357);

/// Today's prayer times for the selected city.
final prayerTimesProvider = FutureProvider<PrayerTimes?>((ref) async {
  final city = ref.watch(cityProvider).trim();
  final entry = _kCities[city.toLowerCase()];

  if (entry != null) {
    // Coordinates are more reliable than name matching, so try them
    // first and only fall back to the name lookup.
    final byCoords = await PrayerService.getTodayTimes(
        lat: entry.$3, lng: entry.$4);
    if (byCoords != null) return byCoords;
    return PrayerService.getTimesByCity(city: entry.$1, country: entry.$2);
  }

  // Unknown city: try the name as typed, then fall back to coordinates
  // so the card still shows something useful.
  if (city.isNotEmpty) {
    final byName = await PrayerService.getTimesByCity(city: city, country: '');
    if (byName != null) return byName;
  }
  return PrayerService.getTodayTimes(lat: _fallback.$1, lng: _fallback.$2);
});
