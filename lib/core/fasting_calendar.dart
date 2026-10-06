// fasting_calendar.dart — HalalCalorie v56 (PATCH_V56_FASTING_CALENDAR)
// Recommended (sunnah) fasting days, derived from the tabular Hijri calendar.
// The tabular calendar can differ from a local moon sighting by about a day, so
// every screen that shows these dates says so.
import 'hijri.dart';

enum FastKind { arafah, ashura, tasua, whiteDay, shawwal, monday, thursday }

class FastDay {
  final DateTime date;
  final FastKind kind;
  final List<FastKind> also;
  final HijriDate hijri;
  const FastDay(this.date, this.kind, this.also, this.hijri);
}

class FastingCalendar {
  static String dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Days on which fasting is not allowed (the two Eids and the days of Tashreeq).
  static bool _forbidden(HijriDate h) =>
      (h.month == 10 && h.day == 1) ||
      (h.month == 12 && h.day >= 10 && h.day <= 13);

  /// Reasons to fast on [d], strongest first. Empty during Ramadan (the fast is
  /// obligatory then) and on the days when fasting is not permitted.
  static List<FastKind> kindsFor(DateTime d, HijriDate h) {
    if (h.month == HijriDate.ramadanMonth || _forbidden(h)) return const [];
    final k = <FastKind>[];
    if (h.month == 12 && h.day == 9) k.add(FastKind.arafah);
    if (h.month == 1 && h.day == 10) k.add(FastKind.ashura);
    if (h.month == 1 && h.day == 9) k.add(FastKind.tasua);
    if (h.day >= 13 && h.day <= 15) k.add(FastKind.whiteDay);
    if (h.month == 10 && h.day >= 2 && h.day <= 7) k.add(FastKind.shawwal);
    if (d.weekday == DateTime.monday) k.add(FastKind.monday);
    if (d.weekday == DateTime.thursday) k.add(FastKind.thursday);
    return k;
  }

  static bool isSunnahFast(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return kindsFor(day, HijriDate.fromGregorian(day)).isNotEmpty;
  }

  static List<FastDay> upcoming({required DateTime from, int days = 60}) {
    final out = <FastDay>[];
    final start = DateTime(from.year, from.month, from.day);
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      final h = HijriDate.fromGregorian(d);
      final k = kindsFor(d, h);
      if (k.isEmpty) continue;
      out.add(FastDay(d, k.first, k.sublist(1), h));
    }
    return out;
  }

  static String titleAr(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'صيام يوم عرفة';
      case FastKind.ashura:
        return 'صيام يوم عاشوراء';
      case FastKind.tasua:
        return 'صيام تاسوعاء';
      case FastKind.whiteDay:
        return 'صيام الأيام البيض';
      case FastKind.shawwal:
        return 'ستٌّ من شوال';
      case FastKind.monday:
        return 'صيام يوم الاثنين';
      case FastKind.thursday:
        return 'صيام يوم الخميس';
    }
  }

  static String titleEn(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'Fast of Arafah';
      case FastKind.ashura:
        return 'Fast of Ashura';
      case FastKind.tasua:
        return 'Fast of Tasu\u2019a';
      case FastKind.whiteDay:
        return 'White Days fast';
      case FastKind.shawwal:
        return 'Six days of Shawwal';
      case FastKind.monday:
        return 'Monday fast';
      case FastKind.thursday:
        return 'Thursday fast';
    }
  }

  static String noteAr(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'يُستحب لغير الحاج، وثوابه عظيم';
      case FastKind.ashura:
        return 'يُكفّر سنة ماضية — ويُستحب صيام يوم قبله أو بعده';
      case FastKind.tasua:
        return 'يوم قبل عاشوراء، يُستحب ضمّه إليه';
      case FastKind.whiteDay:
        return 'الثالث عشر والرابع عشر والخامس عشر من كل شهر هجري';
      case FastKind.shawwal:
        return 'إتباع رمضان بست من شوال كصيام الدهر';
      case FastKind.monday:
        return 'تُعرض الأعمال يوم الاثنين فيُستحب أن تكون صائمًا';
      case FastKind.thursday:
        return 'تُعرض الأعمال يوم الخميس فيُستحب أن تكون صائمًا';
    }
  }

  static String noteEn(FastKind k) {
    switch (k) {
      case FastKind.arafah:
        return 'Recommended for those not on Hajj, with great reward';
      case FastKind.ashura:
        return 'Expiates the previous year; fast a day before or after it too';
      case FastKind.tasua:
        return 'The day before Ashura, recommended alongside it';
      case FastKind.whiteDay:
        return 'The 13th, 14th and 15th of each Hijri month';
      case FastKind.shawwal:
        return 'Following Ramadan with six days of Shawwal';
      case FastKind.monday:
        return 'Deeds are presented on Mondays \u2014 a good day to be fasting';
      case FastKind.thursday:
        return 'Deeds are presented on Thursdays \u2014 a good day to be fasting';
    }
  }
}
