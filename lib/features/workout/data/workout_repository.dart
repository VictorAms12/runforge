import '../../../core/database/app_database.dart';
import '../domain/workout.dart';

class WorkoutRepository {
  WorkoutRepository(this._db);
  final AppDatabase _db;

  Future<int> insert(Workout workout) async {
    final db = await _db.database;
    return db.insert('workouts', workout.toMap());
  }

  Future<List<Workout>> getHistory({int limit = 100}) async {
    final db = await _db.database;
    final rows = await db.query(
      'workouts',
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(Workout.fromMap).toList();
  }

  Future<DashboardStats> getDashboardStats() async {
    final db = await _db.database;
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final week = await db.rawQuery('''
      SELECT COALESCE(SUM(distance_km), 0) AS distance,
             COUNT(*) AS sessions,
             COALESCE(SUM(duration_seconds), 0) AS seconds
      FROM workouts
      WHERE started_at >= ?
    ''', [weekStart.toIso8601String()]);

    final month = await db.rawQuery('''
      SELECT COALESCE(SUM(distance_km), 0) AS distance
      FROM workouts
      WHERE started_at >= ?
    ''', [monthStart.toIso8601String()]);

    return DashboardStats(
      weekDistanceKm: (week.first['distance'] as num).toDouble(),
      weekWorkouts: (week.first['sessions'] as num).toInt(),
      weekDuration: Duration(seconds: (week.first['seconds'] as num).toInt()),
      monthDistanceKm: (month.first['distance'] as num).toDouble(),
    );
  }
}
