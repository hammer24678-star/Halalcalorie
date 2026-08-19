// database.dart — HalalCalorie v1.0
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'halalcalorie.db'),
      version: 8,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  // Migrations are additive from v6 on — a user's meals, weights and
  // summaries survive an app update instead of being wiped.
  static Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 6) {
      // Pre-v6 schemas predate the shipped release; rebuild from scratch.
      await db.execute('DROP TABLE IF EXISTS meal_entries');
      await db.execute('DROP TABLE IF EXISTS weight_log');
      await db.execute('DROP TABLE IF EXISTS daily_summary');
      await db.execute('DROP TABLE IF EXISTS workout_log');
      await db.execute('DROP TABLE IF EXISTS barakah_log');
      await _create(db, newV);
      return;
    }
    await _create(db, newV);
    if (oldV < 7) await _migrateLegacyProgress(db);
  }

  // v7 renamed the progress table and added an xp column. Carry the old
  // daily rows across so long-time users keep their history.
  static Future<void> _migrateLegacyProgress(Database db) async {
    try {
      final legacy = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='barakah_log'");
      if (legacy.isEmpty) return;
      await db.execute(
        'INSERT OR IGNORE INTO ascent_log '
        '(date_key, nourish, hydrate, rest, move, train, stillness, '
        'restraint, wholesome, score, xp) '
        'SELECT date_key, nutrition, hydration, sleep, movement, workout, '
        'dhikr, fasting, sunnah_food, score, 0 FROM barakah_log',
      );
      await db.execute('DROP TABLE barakah_log');
    } catch (e) {
      debugPrint('progress migration: $e');
    }
  }

  static Future<void> _create(Database db, int version) async {
    await db.execute(
      'CREATE TABLE IF NOT EXISTS meal_entries ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'name TEXT NOT NULL,'
      'kcal INTEGER NOT NULL,'
      'protein_g REAL DEFAULT 0,'
      'carbs_g REAL DEFAULT 0,'
      'fat_g REAL DEFAULT 0,'
      'date_key TEXT NOT NULL,'
      'created TEXT NOT NULL)'
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS weight_log ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'weight_kg REAL NOT NULL,'
      'note TEXT,'
      'created TEXT NOT NULL)'
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS daily_summary ('
      'date_key TEXT PRIMARY KEY,'
      'water_cups INTEGER DEFAULT 0,'
      'sleep_hrs REAL DEFAULT 0,'
      'steps INTEGER DEFAULT 0,'
      'mood TEXT)'
    );
    await db.execute(
      'CREATE TABLE IF NOT EXISTS workout_log ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'workout_id TEXT NOT NULL,'
      'minutes INTEGER NOT NULL,'
      'date_key TEXT NOT NULL,'
      'created TEXT NOT NULL)'
    );
    // ── Ascent System — one row per day ─────────────────
    await db.execute(
      'CREATE TABLE IF NOT EXISTS ascent_log ('
      'date_key TEXT PRIMARY KEY,'
      'nourish   INTEGER DEFAULT 0,'
      'hydrate   INTEGER DEFAULT 0,'
      'rest      INTEGER DEFAULT 0,'
      'move      INTEGER DEFAULT 0,'
      'train     INTEGER DEFAULT 0,'
      'stillness INTEGER DEFAULT 0,'
      'restraint INTEGER DEFAULT 0,'
      'wholesome INTEGER DEFAULT 0,'
      'score     INTEGER DEFAULT 0,'
      'xp        INTEGER DEFAULT 0)'
    );
    // ── Lift log — one row per performed set ────────────
    await db.execute(
      'CREATE TABLE IF NOT EXISTS lift_sets ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT,'
      'exercise_id TEXT NOT NULL,'
      'weight_kg REAL DEFAULT 0,'
      'reps INTEGER DEFAULT 0,'
      'seconds INTEGER DEFAULT 0,'
      'bodyweight_kg REAL DEFAULT 0,'
      'lp INTEGER DEFAULT 0,'
      'date_key TEXT NOT NULL,'
      'created TEXT NOT NULL)'
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_lift_sets_exercise '
      'ON lift_sets(exercise_id)'
    );
  }

  static String _today() => _dateKey(DateTime.now());

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, "0")}'
      '-${d.day.toString().padLeft(2, "0")}';

  /// Cutoff for a rolling window, computed in the device's own timezone.
  /// SQLite's date('now') is UTC, which shifted the window by a day for
  /// anyone far enough from it, so the bound is calculated here instead.
  static String _daysAgoKey(int days) =>
      _dateKey(DateTime.now().subtract(Duration(days: days)));

  static Future<List<Map<String,dynamic>>> getTodayMeals() async {
    final d = await db;
    return d.query('meal_entries', where: 'date_key=?', whereArgs: [_today()], orderBy: 'id ASC');
  }

  static Future<int> insertMeal({required String name, required int kcal, double proteinG=0, double carbsG=0, double fatG=0}) async {
    try {
      final d = await db;
      return d.insert('meal_entries', {'name':name,'kcal':kcal,'protein_g':proteinG,'carbs_g':carbsG,'fat_g':fatG,'date_key':_today(),'created':DateTime.now().toIso8601String()});
    } catch(e) { debugPrint('insertMeal: $e'); return -1; }
  }

  static Future<void> deleteMeal(int id) async {
    final d = await db;
    await d.delete('meal_entries', where:'id=?', whereArgs:[id]);
  }

  static Future<List<_DailyKcal>> getWeeklyKcal() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT date_key, SUM(kcal) as total FROM meal_entries '
        'WHERE date_key >= ? GROUP BY date_key ORDER BY date_key ASC',
        [_daysAgoKey(6)]);
    return rows.map((r) => _DailyKcal(r['date_key'] as String, (r['total'] as int?) ?? 0)).toList();
  }

  static Future<List<Map<String,dynamic>>> getWeightLog({int limit=30}) async {
    final d = await db;
    return d.query('weight_log', orderBy:'created ASC', limit:limit);
  }

  static Future<int> insertWeight(double kg, {String? note}) async {
    final d = await db;
    return d.insert('weight_log', {'weight_kg':kg,'note':note,'created':DateTime.now().toIso8601String()});
  }

  static Future<void> deleteWeight(int id) async {
    final d = await db;
    await d.delete('weight_log', where:'id=?', whereArgs:[id]);
  }

  static Future<Map<String,dynamic>?> getTodaySummary() async {
    final d = await db;
    final rows = await d.query('daily_summary', where:'date_key=?', whereArgs:[_today()]);
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<void> upsertSummary({int? waterCups, double? sleepHrs, int? steps, String? mood}) async {
    final d = await db;
    final key = _today();
    final existing = await getTodaySummary();
    if (existing == null) {
      await d.insert('daily_summary', {'date_key':key,'water_cups':waterCups??0,'sleep_hrs':sleepHrs??0,'steps':steps??0,'mood':mood});
    } else {
      final u = <String,dynamic>{};
      if (waterCups!=null) u['water_cups']=waterCups;
      if (sleepHrs!=null)  u['sleep_hrs']=sleepHrs;
      if (steps!=null)     u['steps']=steps;
      if (mood!=null)      u['mood']=mood;
      if (u.isNotEmpty) await d.update('daily_summary', u, where:'date_key=?', whereArgs:[key]);
    }
  }

  static Future<void> logWorkout(String workoutId, int minutes) async {
    final d = await db;
    await d.insert('workout_log', {'workout_id':workoutId,'minutes':minutes,'date_key':_today(),'created':DateTime.now().toIso8601String()});
  }

  static Future<int> getTodayWorkoutMinutes() async {
    final d = await db;
    final rows = await d.rawQuery('SELECT SUM(minutes) as total FROM workout_log WHERE date_key=?', [_today()]);
    return (rows.first['total'] as int?) ?? 0;
  }

  // Calories burned today — estimated at 5 kcal per workout minute
  static Future<double> getTodayBurnedKcal() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT SUM(minutes) as total FROM workout_log WHERE date_key=?',
        [_today()]);
    final mins = (rows.first['total'] as int?) ?? 0;
    return mins * 5.0;
  }

  // Distinct workout days in the past 7 days
  static Future<Set<String>> getWeeklyWorkoutDays() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT DISTINCT date_key FROM workout_log WHERE date_key >= ?',
        [_daysAgoKey(6)]);
    return rows.map((r) => r['date_key'] as String).toSet();
  }

  // ── Ascent helpers ──────────────────────────────────────────
  static Future<Map<String,dynamic>?> getTodayAscent() async {
    final d = await db;
    final rows = await d.query('ascent_log',
        where:'date_key=?', whereArgs:[_today()]);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Writes only the columns passed in — everything else is left alone.
  static Future<void> upsertAscent(Map<String, int> values) async {
    if (values.isEmpty) return;
    final d = await db;
    final key = _today();
    final existing = await getTodayAscent();
    if (existing == null) {
      await d.insert('ascent_log', {'date_key': key, ...values});
    } else {
      await d.update('ascent_log', values,
          where:'date_key=?', whereArgs:[key]);
    }
  }

  static Future<List<Map<String,dynamic>>> getWeeklyAscent() async {
    final d = await db;
    return d.rawQuery(
      'SELECT date_key, score, xp FROM ascent_log '
      'WHERE date_key >= ? ORDER BY date_key ASC',
      [_daysAgoKey(6)]);
  }

  /// Lifetime XP is the sum of every day's awarded XP, so recomputing a
  /// day's value can never double-count it.
  static Future<int> getLifetimeXp() async {
    final d = await db;
    final rows = await d.rawQuery('SELECT SUM(xp) as total FROM ascent_log');
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Days that cleared the chain threshold, newest first.
  static Future<List<String>> getQualifyingDays({int minScore = 400}) async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT date_key FROM ascent_log WHERE score >= ? '
        'ORDER BY date_key DESC LIMIT 400', [minScore]);
    return rows.map((r) => r['date_key'] as String).toList();
  }

  // ── Lift log helpers ────────────────────────────────────────
  static Future<int> insertLiftSet({
    required String exerciseId,
    required double weightKg,
    required int reps,
    required int seconds,
    required double bodyweightKg,
    required int lp,
  }) async {
    try {
      final d = await db;
      return d.insert('lift_sets', {
        'exercise_id': exerciseId,
        'weight_kg': weightKg,
        'reps': reps,
        'seconds': seconds,
        'bodyweight_kg': bodyweightKg,
        'lp': lp,
        'date_key': _today(),
        'created': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('insertLiftSet: \$e');
      return -1;
    }
  }

  static Future<void> deleteLiftSet(int id) async {
    final d = await db;
    await d.delete('lift_sets', where: 'id=?', whereArgs: [id]);
  }

  /// Best LP recorded per exercise, which is what the ranks are built on.
  static Future<Map<String, int>> getLiftBests() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT exercise_id, MAX(lp) AS best FROM lift_sets '
        'GROUP BY exercise_id');
    return {
      for (final r in rows)
        (r['exercise_id'] as String): (r['best'] as int? ?? 0),
    };
  }

  /// The single best set per exercise, for showing what earned the rank.
  static Future<List<Map<String, dynamic>>> getLiftBestSets() async {
    final d = await db;
    return d.rawQuery(
        'SELECT s.* FROM lift_sets s '
        'JOIN (SELECT exercise_id, MAX(lp) AS best FROM lift_sets '
        '      GROUP BY exercise_id) b '
        '  ON s.exercise_id = b.exercise_id AND s.lp = b.best '
        'GROUP BY s.exercise_id');
  }

  static Future<List<Map<String, dynamic>>> getRecentLiftSets(
      {int limit = 60}) async {
    final d = await db;
    return d.query('lift_sets', orderBy: 'id DESC', limit: limit);
  }

  static Future<List<Map<String, dynamic>>> getLiftHistory(
      String exerciseId, {int limit = 40}) async {
    final d = await db;
    return d.query('lift_sets',
        where: 'exercise_id=?', whereArgs: [exerciseId],
        orderBy: 'id DESC', limit: limit);
  }

  static Future<int> getTodayLiftSetCount() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT COUNT(*) AS c FROM lift_sets WHERE date_key=?', [_today()]);
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Total volume (weight x reps) lifted today, in kilos.
  static Future<double> getTodayLiftVolume() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT SUM(weight_kg * reps) AS v FROM lift_sets WHERE date_key=?',
        [_today()]);
    return ((rows.first['v'] as num?) ?? 0).toDouble();
  }

  static Future<int> getLoggedDayCount() async {
    final d = await db;
    final rows = await d.rawQuery(
        'SELECT COUNT(*) as c FROM ascent_log WHERE score > 0');
    return (rows.first['c'] as int?) ?? 0;
  }
}

class _DailyKcal { final String dateKey; final int kcal; _DailyKcal(this.dateKey, this.kcal); }
