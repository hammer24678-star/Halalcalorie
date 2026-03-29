// ============================================================
//  prayer_provider.dart — Riverpod prayer state
// ============================================================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'prayer_service.dart';
import 'providers.dart';

// Fetch prayer times based on user's city
final prayerTimesProvider = FutureProvider<PrayerTimes?>((ref) async {
  final city = ref.watch(cityProvider);
  if (city == null || city.isEmpty) {
    // Default to Cairo Egypt
    return PrayerService.getTodayTimes(lat: 30.0444, lng: 31.2357);
  }

  // City-based lookup
  final cityMap = {
    'Cairo':        ['Cairo',        'Egypt'],
    'Alexandria':   ['Alexandria',   'Egypt'],
    'Riyadh':       ['Riyadh',       'Saudi Arabia'],
    'Jeddah':       ['Jeddah',       'Saudi Arabia'],
    'Dubai':        ['Dubai',        'UAE'],
    'Kuwait City':  ['Kuwait City',  'Kuwait'],
    'Doha':         ['Doha',         'Qatar'],
    'Amman':        ['Amman',        'Jordan'],
    'Beirut':       ['Beirut',       'Lebanon'],
    'Baghdad':      ['Baghdad',      'Iraq'],
    'Karachi':      ['Karachi',      'Pakistan'],
    'Jakarta':      ['Jakarta',      'Indonesia'],
    'London':       ['London',       'United Kingdom'],
    'New York':     ['New York',     'United States'],
    'Toronto':      ['Toronto',      'Canada'],
  };

  final entry = cityMap[city];
  if (entry != null) {
    return PrayerService.getTimesByCity(
        city: entry[0], country: entry[1]);
  }

  // Try directly with city name
  return PrayerService.getTimesByCity(city: city, country: '');
});
