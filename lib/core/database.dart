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
      version: 6,
      onCreate: _create,
      onUpgrade: (db, oldV, newV) async {
        await db.execute('DROP TABLE IF EXISTS meal_entries');
        await db.execute('DROP TABLE IF EXISTS weight_log');
        await db.execute('DROP TABLE IF EXISTS daily_summary');
        await db.execute('DROP TABLE IF EXISTS workout_log');
        await db.execute('DROP TABLE IF EXISTS barakah_log');
        await _create(db, newV);
      },
    );
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
    // ── Barakah Engine ──────────────────────────────────
    await db.execute(
      'CREATE TABLE IF NOT EXISTS barakah_log ('
      'date_key TEXT PRIMARY KEY,'
      'nutrition  INTEGER DEFAULT 0,'
      'hydration  INTEGER DEFAULT 0,'
      'sleep      INTEGER DEFAULT 0,'
      'movement   INTEGER DEFAULT 0,'
      'fasting    INTEGER DEFAULT 0,'
      'sunnah_food INTEGER DEFAULT 0,'
      'workout    INTEGER DEFAULT 0,'
      'dhikr      INTEGER DEFAULT 0,'
      'score      INTEGER DEFAULT 0)'
    );
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2,"0")}-${n.day.toString().padLeft(2,"0")}';
  }

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
    final rows = await d.rawQuery("SELECT date_key, SUM(kcal) as total FROM meal_entries WHERE date_key >= date('now','-6 days') GROUP BY date_key ORDER BY date_key ASC");
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
        "SELECT DISTINCT date_key FROM workout_log "
        "WHERE date_key >= date('now','-6 days')");
    return rows.map((r) => r['date_key'] as String).toSet();
  }

  // ── Barakah helpers ─────────────────────────────────────────
  static Future<Map<String,dynamic>?> getTodayBarakah() async {
    final d = await db;
    final rows = await d.query('barakah_log', where:'date_key=?', whereArgs:[_today()]);
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<void> upsertBarakah({
    int? nutrition, int? hydration, int? sleep,
    int? movement, int? fasting, int? sunnahFood,
    int? workout, int? dhikr, int? score,
  }) async {
    final d = await db;
    final key = _today();
    final existing = await getTodayBarakah();
    final data = <String, dynamic>{
      if (nutrition  != null) 'nutrition':   nutrition,
      if (hydration  != null) 'hydration':   hydration,
      if (sleep      != null) 'sleep':       sleep,
      if (movement   != null) 'movement':    movement,
      if (fasting    != null) 'fasting':     fasting,
      if (sunnahFood != null) 'sunnah_food': sunnahFood,
      if (workout    != null) 'workout':     workout,
      if (dhikr      != null) 'dhikr':       dhikr,
      if (score      != null) 'score':       score,
    };
    if (data.isEmpty) return;
    if (existing == null) {
      await d.insert('barakah_log', {'date_key': key, ...data});
    } else {
      await d.update('barakah_log', data, where:'date_key=?', whereArgs:[key]);
    }
  }

  static Future<List<Map<String,dynamic>>> getWeeklyBarakah() async {
    final d = await db;
    return d.rawQuery(
      "SELECT date_key, score FROM barakah_log "
      "WHERE date_key >= date('now','-6 days') "
      "ORDER BY date_key ASC");
  }
}

class _DailyKcal { final String dateKey; final int kcal; _DailyKcal(this.dateKey, this.kcal); }
