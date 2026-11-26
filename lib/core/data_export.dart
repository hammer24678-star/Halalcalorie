// data_export.dart — the user's own logs as CSV text (v66).
//
// People had no way to take their data out of the app (the backup methods in
// auth_service.dart are empty stubs). This builds one plain-text document, a
// short block per table separated by a blank line, that the share sheet can
// hand to Sheets, Notes, e-mail or a file manager. Column names stay English
// so the text is machine-readable whatever language the app is in.
import 'database.dart';

class ExportBundle {
  final String csv;

  /// Data rows across all blocks (headers not counted). 0 = nothing to export.
  final int rows;
  const ExportBundle(this.csv, this.rows);
}

class DataExport {
  /// How far back meals, summaries and workouts reach, and the row caps that
  /// keep the text comfortably inside what the share sheet can carry.
  static const int days = 365;
  static const int maxMeals = 4000;
  static const int maxWeights = 2000;
  static const int maxWorkouts = 2000;

  /// One text field. Quoted when it holds a comma, quote or line break, and
  /// given a leading apostrophe when it would start with a formula character
  /// (= + - @): product names come from third-party databases and must not run
  /// as a formula when the text is pasted into a spreadsheet.
  static String field(Object? v) {
    var s = (v ?? '').toString();
    if (s.isEmpty) return '';
    if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
    if (RegExp(r'[",\n\r]').hasMatch(s)) s = '"${s.replaceAll('"', '""')}"';
    return s;
  }

  static String _n(Object? v) {
    if (v is int) return '$v';
    if (v is double) {
      if (!v.isFinite) return '';
      return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    }
    return '';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _ymd(Object? iso) {
    final t = DateTime.tryParse('${iso ?? ''}');
    if (t == null) return '';
    return '${t.year}-${_two(t.month)}-${_two(t.day)}';
  }

  static String _hm(Object? iso) {
    final t = DateTime.tryParse('${iso ?? ''}');
    if (t == null) return '';
    return '${_two(t.hour)}:${_two(t.minute)}';
  }

  static Future<ExportBundle> build() async {
    final d = await AppDatabase.db;
    final now = DateTime.now();
    // Calendar arithmetic, like the rest of the database layer.
    final from = DateTime(now.year, now.month, now.day - days);
    final sinceKey = '${from.year}-${_two(from.month)}-${_two(from.day)}';

    // Newest rows first so the caps drop the oldest; reversed again below.
    final meals = await d.rawQuery(
        'SELECT date_key, created, name, kcal, protein_g, carbs_g, fat_g '
        'FROM meal_entries WHERE date_key >= ? ORDER BY id DESC LIMIT ?',
        [sinceKey, maxMeals]);
    final weights = await d.rawQuery(
        'SELECT created, weight_kg, note FROM weight_log '
        'ORDER BY id DESC LIMIT ?',
        [maxWeights]);
    final summaries = await d.rawQuery(
        'SELECT date_key, water_cups, sleep_hrs, steps, mood '
        'FROM daily_summary WHERE date_key >= ? ORDER BY date_key ASC',
        [sinceKey]);
    final workouts = await d.rawQuery(
        'SELECT date_key, workout_id, minutes, kcal FROM workout_log '
        'WHERE date_key >= ? ORDER BY id DESC LIMIT ?',
        [sinceKey, maxWorkouts]);

    final b = StringBuffer()
      ..writeln('# HalalCalorie data export')
      ..writeln('# generated ${now.toIso8601String()}')
      ..writeln('# meals, daily summaries and workouts: last $days days');
    var rows = 0;

    void block(String title, String header, Iterable<List<String>> data) {
      final list = data.toList();
      if (list.isEmpty) return;
      b
        ..writeln()
        ..writeln('# $title')
        ..writeln(header);
      for (final r in list) {
        b.writeln(r.join(','));
      }
      rows += list.length;
    }

    block(
        'meals',
        'date,time,name,kcal,protein_g,carbs_g,fat_g',
        meals.reversed.map((r) => [
              field(r['date_key']),
              _hm(r['created']),
              field(r['name']),
              _n(r['kcal']),
              _n(r['protein_g']),
              _n(r['carbs_g']),
              _n(r['fat_g']),
            ]));
    block(
        'weight',
        'date,weight_kg,note',
        weights.reversed.map((r) => [
              _ymd(r['created']),
              _n(r['weight_kg']),
              field(r['note']),
            ]));
    block(
        'daily summary',
        'date,water_cups,sleep_hours,steps,mood',
        summaries.map((r) => [
              field(r['date_key']),
              _n(r['water_cups']),
              _n(r['sleep_hrs']),
              _n(r['steps']),
              field(r['mood']),
            ]));
    block(
        'workouts',
        'date,workout,minutes,kcal',
        workouts.reversed.map((r) => [
              field(r['date_key']),
              field(r['workout_id']),
              _n(r['minutes']),
              _n(r['kcal']),
            ]));

    return ExportBundle(b.toString(), rows);
  }
}
