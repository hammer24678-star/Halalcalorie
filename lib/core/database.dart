// ============================================================
//  database.dart — HalalCalorie v1.0
//  SQLite persistence for:
//    • Daily meal entries (calories log)
//    • Weight history (trend chart)
//    • Sleep log
//    • Daily summaries (water, steps, mood)
// ============================================================
import 'package:sqflite/sqflite.dart'; import'package:path/path.dart'as p;

class AppDatabase {
  static Database? _db;

  static Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase( p.join(dbPath,'halalcalorie.db'),
      version: 3,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
  }

  static Future<void> _create(Database db, int version) async { await db.execute('''CREATE TABLE meal_entries (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT    NOT NULL,
        kcal      INTEGER NOT NULL,
        protein_g REAL    DEFAULT 0,
        carbs_g   REAL    DEFAULT 0,
        fat_g     REAL    DEFAULT 0, date_key  TEXT    NOT NULL,  --'YYYY-MM-DD'created   TEXT    NOT NULL
      ) '''); await db.execute('''CREATE TABLE weight_log (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        weight_kg REAL    NOT NULL,
        note      TEXT,
        created   TEXT    NOT NULL
      ) '''); await db.execute('''CREATE TABLE daily_summary ( date_key   TEXT    PRIMARY KEY,  --'YYYY-MM-DD'water_cups INTEGER DEFAULT 0,
        sleep_hrs  REAL    DEFAULT 0,
        steps      INTEGER DEFAULT 0,
        mood       TEXT
      ) '''); await db.execute('''CREATE TABLE workout_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id TEXT    NOT NULL,
        minutes    INTEGER NOT NULL,
        date_key   TEXT    NOT NULL,
        created    TEXT    NOT NULL
      ) ''');
  }

  static Future<void> _upgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) { await db.execute('ALTER TABLE meal_entries ADD COLUMN protein_g REAL DEFAULT 0'); await db.execute('ALTER TABLE meal_entries ADD COLUMN carbs_g REAL DEFAULT 0'); await db.execute('ALTER TABLE meal_entries ADD COLUMN fat_g REAL DEFAULT 0');
    }
    if (oldV < 3) {
      try { await db.execute('''CREATE TABLE IF NOT EXISTS workout_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            workout_id TEXT NOT NULL,
            minutes INTEGER NOT NULL,
            date_key TEXT NOT NULL,
            created TEXT NOT NULL
          ) ''');
      } catch (_) {}
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  static String _today() {
    final n = DateTime.now(); return'${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
  }

  // ══ MEAL ENTRIES ═══════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getMealsForDate(String dateKey) async {
    final d = await db; return d.query('meal_entries', where: 'date_key = ?', whereArgs: [dateKey], orderBy: 'id ASC');
  }

  static Future<List<Map<String, dynamic>>> getTodayMeals() => getMealsForDate(_today());

  static Future<int> insertMeal({
    required String name, required int kcal,
    double proteinG = 0, double carbsG = 0, double fatG = 0,
  }) async {
    try {
      final d = await db;
      return d.insert('meal_entries', {
        'name': name, 'kcal': kcal,
        'protein_g': proteinG, 'carbs_g': carbsG, 'fat_g': fatG,
        'date_key': _today(),
        'created': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('insertMeal error: $e');
      return -1;
    }
  }

  static Future<void> deleteMeal(int id) async {
    final d = await db; await d.delete('meal_entries', where: 'id = ?', whereArgs: [id]);
  }

  // Last 7 days daily totals for chart
  static Future<List<_DailyKcal>> getWeeklyKcal() async {
    final d = await db; final rows = await d.rawQuery('''SELECT date_key, SUM(kcal) as total
      FROM meal_entries WHERE date_key >= date('now', '-6 days')
      GROUP BY date_key
      ORDER BY date_key ASC '''); return rows.map((r) => _DailyKcal(r['date_key'] as String, (r['total'] as int?) ?? 0)).toList();
  }

  // ══ WEIGHT LOG ═════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>> getWeightLog({int limit = 30}) async {
    final d = await db; return d.query('weight_log', orderBy: 'created ASC', limit: limit);
  }

  static Future<int> insertWeight(double kg, {String? note}) async {
    final d = await db; return d.insert('weight_log', { 'weight_kg': kg, 'note': note, 'created': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteWeight(int id) async {
    final d = await db; await d.delete('weight_log', where: 'id = ?', whereArgs: [id]);
  }

  // ══ DAILY SUMMARY ══════════════════════════════════════════

  static Future<Map<String, dynamic>?> getSummary(String dateKey) async {
    final d = await db; final rows = await d.query('daily_summary', where: 'date_key = ?', whereArgs: [dateKey]);
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<Map<String, dynamic>?> getTodaySummary() => getSummary(_today());

  static Future<void> upsertSummary({
    String? dateKey,
    int? waterCups,
    double? sleepHrs,
    int? steps,
    String? mood,
  }) async {
    final d    = await db;
    final key  = dateKey ?? _today();
    final existing = await getSummary(key);
    if (existing == null) { await d.insert('daily_summary', { 'date_key':    key, 'water_cups':  waterCups  ?? 0, 'sleep_hrs':   sleepHrs   ?? 0, 'steps':       steps      ?? 0, 'mood':        mood,
      });
    } else {
      final updates = <String, dynamic>{}; if (waterCups != null) updates['water_cups'] = waterCups; if (sleepHrs  != null) updates['sleep_hrs']  = sleepHrs; if (steps     != null) updates['steps']       = steps; if (mood      != null) updates['mood']        = mood;
      if (updates.isNotEmpty) { await d.update('daily_summary', updates, where: 'date_key = ?', whereArgs: [key]);
      }
    }
  }

  // ══ WORKOUT LOG ════════════════════════════════════════════

  static Future<void> logWorkout(String workoutId, int minutes) async {
    final d = await db; await d.insert('workout_log', { 'workout_id': workoutId, 'minutes': minutes, 'date_key': _today(), 'created': DateTime.now().toIso8601String(),
    });
  }

  static Future<int> getTodayWorkoutMinutes() async {
    final d = await db;
    final rows = await d.rawQuery(
      "SELECT SUM(minutes) as total FROM workout_log WHERE date_key = ?", [_today()]); return (rows.first['total'] as int?) ?? 0;
  }

  // ══ CLEANUP ════════════════════════════════════════════════

  static Future<void> deleteOlderThan(int days) async {
    final d = await db;
    final cutoff = DateTime.now().subtract(Duration(days: days)); final cutoffStr ='${cutoff.year}-${cutoff.month.toString().padLeft(2,'0')}-${cutoff.day.toString().padLeft(2,'0')}'; await d.delete('meal_entries',  where: 'date_key < ?', whereArgs: [cutoffStr]); await d.delete('daily_summary', where: 'date_key < ?', whereArgs: [cutoffStr]); await d.delete('workout_log',   where: 'date_key < ?', whereArgs: [cutoffStr]);
  }
}

class _DailyKcal {
  final String dateKey;
  final int    kcal;
  _DailyKcal(this.dateKey, this.kcal);
}
