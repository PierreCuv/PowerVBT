import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/athlete.dart';
import '../../models/session.dart';
import '../../models/training_set.dart';
import '../../models/rep.dart';

class DatabaseService {
  DatabaseService._();
  static final instance = DatabaseService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<void> init() async => await db;

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'powervbt.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE athletes (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        nickname     TEXT NOT NULL,
        bodyweight_kg REAL NOT NULL,
        photo_path   TEXT,
        category     TEXT,
        created_at   TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        athlete_id  INTEGER NOT NULL,
        date        TEXT NOT NULL,
        notes       TEXT,
        FOREIGN KEY (athlete_id) REFERENCES athletes(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sets (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id  INTEGER NOT NULL,
        exercise    TEXT NOT NULL,
        load_kg     REAL NOT NULL,
        mode        TEXT NOT NULL DEFAULT 'strength',
        rpe         REAL,
        rir         INTEGER,
        is_manual   INTEGER NOT NULL DEFAULT 0,
        created_at  TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE reps (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        set_id               INTEGER NOT NULL,
        rep_index            INTEGER NOT NULL,
        peak_velocity        REAL NOT NULL,
        mean_velocity        REAL NOT NULL,
        tut_ms               INTEGER NOT NULL,
        tempo_concentric_ms  INTEGER NOT NULL DEFAULT 0,
        tempo_eccentric_ms   INTEGER NOT NULL DEFAULT 0,
        is_manual            INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (set_id) REFERENCES sets(id) ON DELETE CASCADE
      )
    ''');

    // Indexes for performance
    await db.execute('CREATE INDEX idx_sessions_athlete ON sessions(athlete_id)');
    await db.execute('CREATE INDEX idx_sets_session ON sets(session_id)');
    await db.execute('CREATE INDEX idx_reps_set ON reps(set_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations go here
  }

  // ── ATHLETES ─────────────────────────────────────────────

  Future<int> insertAthlete(Athlete a) async {
    final d = await db;
    return d.insert('athletes', a.toMap()..remove('id'));
  }

  Future<Athlete?> getAthlete(int id) async {
    final d = await db;
    final rows = await d.query('athletes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Athlete.fromMap(rows.first);
  }

  Future<List<Athlete>> getAllAthletes() async {
    final d = await db;
    final rows = await d.query('athletes', orderBy: 'created_at ASC');
    return rows.map(Athlete.fromMap).toList();
  }

  Future<void> updateAthlete(Athlete a) async {
    final d = await db;
    await d.update('athletes', a.toMap(), where: 'id = ?', whereArgs: [a.id]);
  }

  // ── SESSIONS ─────────────────────────────────────────────

  Future<int> insertSession(Session s) async {
    final d = await db;
    return d.insert('sessions', s.toMap()..remove('id'));
  }

  Future<List<Session>> getSessionsForAthlete(int athleteId) async {
    final d = await db;
    final rows = await d.query(
      'sessions',
      where: 'athlete_id = ?',
      whereArgs: [athleteId],
      orderBy: 'date DESC',
    );
    final sessions = <Session>[];
    for (final row in rows) {
      final s = Session.fromMap(row);
      final sets = await getSetsForSession(s.id!);
      sessions.add(Session.fromMap(row, sets: sets));
    }
    return sessions;
  }

  // ── SETS ─────────────────────────────────────────────────

  Future<int> insertSet(TrainingSet s) async {
    final d = await db;
    return d.insert('sets', s.toMap()..remove('id'));
  }

  Future<List<TrainingSet>> getSetsForSession(int sessionId) async {
    final d = await db;
    final rows = await d.query(
      'sets',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
    final sets = <TrainingSet>[];
    for (final row in rows) {
      final reps = await getRepsForSet(row['id'] as int);
      sets.add(TrainingSet.fromMap(row, reps: reps));
    }
    return sets;
  }

  Future<void> updateSetRpe(int setId, double rpe, int rir) async {
    final d = await db;
    await d.update('sets', {'rpe': rpe, 'rir': rir}, where: 'id = ?', whereArgs: [setId]);
  }

  // ── REPS ─────────────────────────────────────────────────

  Future<int> insertRep(Rep r) async {
    final d = await db;
    return d.insert('reps', r.toMap()..remove('id'));
  }

  Future<List<Rep>> getRepsForSet(int setId) async {
    final d = await db;
    final rows = await d.query(
      'reps',
      where: 'set_id = ?',
      whereArgs: [setId],
      orderBy: 'rep_index ASC',
    );
    return rows.map(Rep.fromMap).toList();
  }

  // ── STATS ────────────────────────────────────────────────

  // All-time best estimated 1RM per exercise for an athlete
  Future<Map<String, double>> getPersonalRecords(int athleteId) async {
    final d = await db;
    final result = <String, double>{};
    for (final ex in ['squat', 'bench', 'deadlift']) {
      final rows = await d.rawQuery('''
        SELECT s.load_kg, COUNT(r.id) as rep_count
        FROM sets s
        JOIN sessions ss ON s.session_id = ss.id
        LEFT JOIN reps r ON r.set_id = s.id
        WHERE ss.athlete_id = ? AND s.exercise = ?
        GROUP BY s.id
        ORDER BY (s.load_kg * (1 + COUNT(r.id) / 30.0)) DESC
        LIMIT 1
      ''', [athleteId, ex]);
      if (rows.isNotEmpty) {
        final load = rows.first['load_kg'] as double;
        final reps = rows.first['rep_count'] as int;
        result[ex] = load * (1 + reps / 30.0);
      }
    }
    return result;
  }

  // Peak velocity per exercise for velocity trend chart
  Future<List<Map<String, dynamic>>> getVelocityTrend(
    int athleteId,
    String exercise, {
    int limitDays = 30,
  }) async {
    final d = await db;
    final since = DateTime.now().subtract(Duration(days: limitDays)).toIso8601String();
    return d.rawQuery('''
      SELECT ss.date, MAX(r.peak_velocity) as peak_vel
      FROM reps r
      JOIN sets s ON r.set_id = s.id
      JOIN sessions ss ON s.session_id = ss.id
      WHERE ss.athlete_id = ? AND s.exercise = ? AND ss.date >= ?
      GROUP BY DATE(ss.date)
      ORDER BY ss.date ASC
    ''', [athleteId, exercise, since]);
  }
}
