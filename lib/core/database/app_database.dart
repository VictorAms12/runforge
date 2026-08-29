import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static const _dbName = 'runforge.db';
  static const version = 3;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), _dbName);
    _database = await openDatabase(
      path,
      version: version,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int _) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        height_cm REAL NOT NULL,
        age INTEGER NOT NULL,
        sex TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        distance_km REAL NOT NULL,
        calories REAL NOT NULL,
        avg_pace_min_km REAL,
        avg_speed_kmh REAL NOT NULL DEFAULT 0,
        intensity TEXT NOT NULL DEFAULT 'moderate',
        notes TEXT,
        workout_type TEXT NOT NULL DEFAULT 'free'
      )
    ''');

    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        metric TEXT NOT NULL,
        target REAL NOT NULL,
        period TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE checklists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        title TEXT NOT NULL,
        is_checked INTEGER NOT NULL DEFAULT 0,
        is_custom INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await _ensureIndexes(db);

    final now = DateTime.now().toIso8601String();
    await db.insert('users', {
      'id': 1,
      'name': 'Corredor',
      'weight_kg': 70.0,
      'height_cm': 175.0,
      'age': 25,
      'sex': 'not_informed',
      'created_at': now,
      'updated_at': now,
    });
    await _seedChecklist(db, now);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var targetVersion = oldVersion + 1;
        targetVersion <= newVersion;
        targetVersion++) {
      switch (targetVersion) {
        case 2:
          await db.execute(
            "ALTER TABLE workouts ADD COLUMN avg_speed_kmh REAL NOT NULL DEFAULT 0",
          );
          await db.execute(
            "ALTER TABLE workouts ADD COLUMN intensity TEXT NOT NULL DEFAULT 'moderate'",
          );
          break;
        case 3:
          await db.execute('ALTER TABLE goals ADD COLUMN completed_at TEXT');
          await db.execute(
            'ALTER TABLE checklists ADD COLUMN position INTEGER NOT NULL DEFAULT 0',
          );
          break;
      }
    }
    await _ensureIndexes(db);
  }

  Future<void> _ensureIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_workouts_started_at ON workouts(started_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_goals_end_date ON goals(end_date)',
    );
  }

  Future<void> _seedChecklist(DatabaseExecutor db, String now) async {
    const pre = [
      'Beber água',
      'Mobilidade / aquecimento',
      'Conferir calçado e cadarço',
      'Separar fones / relógio',
      'Nutrição pré-treino',
    ];
    const post = [
      'Desacelerar e caminhar',
      'Reidratar',
      'Refeição pós-treino',
      'Alongamento leve',
      'Registrar dor e cansaço',
    ];

    for (var i = 0; i < pre.length; i++) {
      await db.insert('checklists', {
        'category': 'pre',
        'title': pre[i],
        'is_checked': 0,
        'is_custom': 0,
        'position': i,
        'created_at': now,
      });
    }
    for (var i = 0; i < post.length; i++) {
      await db.insert('checklists', {
        'category': 'post',
        'title': post[i],
        'is_checked': 0,
        'is_custom': 0,
        'position': i,
        'created_at': now,
      });
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
