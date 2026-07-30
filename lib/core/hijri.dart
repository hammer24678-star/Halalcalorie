// ════════════════════════════════════════════════════════════════════
//  hijri.dart — tabular Islamic-calendar conversion
//
//  Uses the civil (tabular) Islamic calendar, which tracks observed
//  moon sightings to within about a day. That is plenty for showing
//  "day N of Ramadan" and for drawing a moon at the right phase, and it
//  means nothing has to be hardcoded per year.
//
//  Prayer times and fasting windows always come from the prayer-times
//  service — this file is only ever used for calendar labelling.
// ════════════════════════════════════════════════════════════════════

class HijriDate {
  final int year, month, day;
  const HijriDate(this.year, this.month, this.day);

  static const int ramadanMonth = 9;

  bool get isRamadan => month == ramadanMonth;

  /// Days in this Hijri month under the tabular calendar.
  int get daysInMonth {
    if (month % 2 == 1) return 30; // odd months have 30 days
    // Dhu al-Hijjah (12) gets a 30th day in leap years.
    if (month == 12 && _isLeapYear(year)) return 30;
    return 29;
  }

  static bool _isLeapYear(int year) => ((year * 11) + 14) % 30 < 11;

  static const _monthsEn = [
    'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
    'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Shaban',
    'Ramadan', 'Shawwal', 'Dhu al-Qadah', 'Dhu al-Hijjah',
  ];
  static const _monthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني',
    'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  String monthName({bool arabic = false}) {
    final i = (month - 1).clamp(0, 11);
    return arabic ? _monthsAr[i] : _monthsEn[i];
  }

  /// Converts a Gregorian date to the tabular Hijri equivalent.
  factory HijriDate.fromGregorian(DateTime date) {
    final jd = _julianDay(date.year, date.month, date.day);
    var l = jd - 1948440 + 10632;
    final n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l) ~/ 709;
    final day = l - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }

  /// Gregorian date for 1 Ramadan of the given Hijri year.
  static DateTime gregorianForRamadanStart(int hijriYear) =>
      _gregorianFromHijri(hijriYear, ramadanMonth, 1);

  /// Whole days from [from] until 1 Ramadan next comes around.
  /// Zero while Ramadan is in progress.
  static int daysUntilRamadan(DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final hijri = HijriDate.fromGregorian(today);
    if (hijri.isRamadan) return 0;
    var start = gregorianForRamadanStart(hijri.year);
    if (start.isBefore(today)) {
      start = gregorianForRamadanStart(hijri.year + 1);
    }
    return start.difference(today).inDays;
  }

  static int _julianDay(int year, int month, int day) {
    var y = year;
    var m = month;
    if (m < 3) {
      y -= 1;
      m += 12;
    }
    final a = y ~/ 100;
    final b = 2 - a + (a ~/ 4);
    return (365.25 * (y + 4716)).floor() +
        (30.6001 * (m + 1)).floor() +
        day +
        b -
        1524;
  }

  static DateTime _gregorianFromHijri(int year, int month, int day) {
    final jd = (11 * year + 3) ~/ 30 +
        354 * year +
        30 * month -
        (month - 1) ~/ 2 +
        day +
        1948440 -
        386;
    return _fromJulianDay(jd);
  }

  static DateTime _fromJulianDay(int jd) {
    var l = jd + 68569;
    final n = (4 * l) ~/ 146097;
    l = l - (146097 * n + 3) ~/ 4;
    final i = (4000 * (l + 1)) ~/ 1461001;
    l = l - (1461 * i) ~/ 4 + 31;
    final j = (80 * l) ~/ 2447;
    final day = l - (2447 * j) ~/ 80;
    l = j ~/ 11;
    final month = j + 2 - 12 * l;
    final year = 100 * (n - 49) + i + l;
    return DateTime(year, month, day);
  }
}

/// Fraction of the moon's disc lit, approximated from the Hijri day.
/// 0.0 at new moon, 1.0 at full — used only for drawing.
double moonIllumination(int hijriDay, {int daysInMonth = 30}) {
  final cycle = (hijriDay.clamp(1, daysInMonth) - 1) / daysInMonth;
  // Full moon lands around the middle of the month.
  return (1 - (cycle - 0.5).abs() * 2).clamp(0.0, 1.0);
}
