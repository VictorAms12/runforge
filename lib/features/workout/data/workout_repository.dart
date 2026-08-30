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

  Future<int> getCompletedPlanSessions() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT MAX(plan_session_index) AS last_session
      FROM workouts
      WHERE plan_session_index IS NOT NULL
    ''');
    final last = (rows.first['last_session'] as num?)?.toInt();
    return last == null ? 0 : last + 1;
  }

  Future<PersonalRecords> getPersonalRecords() async {
    final history = await getHistory(limit: 500);
    if (history.isEmpty) return const PersonalRecords();

    Workout? longestDistance;
    Workout? longestDuration;
    Workout? bestAveragePace;
    double? bestOneKmPace;
    double? bestFiveKmPace;

    for (final workout in history) {
      if (longestDistance == null ||
          workout.distanceKm > longestDistance.distanceKm) {
        longestDistance = workout;
      }
      if (longestDuration == null ||
          workout.durationSeconds > longestDuration.durationSeconds) {
        longestDuration = workout;
      }
      if (workout.distanceKm >= 1 && workout.avgPaceMinKm != null) {
        if (bestAveragePace == null ||
            workout.avgPaceMinKm! < bestAveragePace.avgPaceMinKm!) {
          bestAveragePace = workout;
        }
      }
      for (final split in workout.splits) {
        if (split.distanceKm >= .95 && split.paceMinKm != null) {
          if (bestOneKmPace == null || split.paceMinKm! < bestOneKmPace) {
            bestOneKmPace = split.paceMinKm;
          }
        }
      }
      if (workout.distanceKm >= 5 && workout.avgPaceMinKm != null) {
        if (bestFiveKmPace == null ||
            workout.avgPaceMinKm! < bestFiveKmPace) {
          bestFiveKmPace = workout.avgPaceMinKm;
        }
      }
    }

    return PersonalRecords(
      longestDistance: longestDistance,
      longestDuration: longestDuration,
      bestAveragePace: bestAveragePace,
      bestOneKmPace: bestOneKmPace,
      bestFiveKmPace: bestFiveKmPace,
    );
  }

  Future<List<WeeklyTrainingSummary>> getWeeklyProgress({int weeks = 8}) async {
    final db = await _db.database;
    final now = DateTime.now();
    final currentWeekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final firstWeekStart = currentWeekStart.subtract(
      Duration(days: (weeks - 1) * 7),
    );
    final rows = await db.query(
      'workouts',
      where: 'started_at >= ?',
      whereArgs: [firstWeekStart.toIso8601String()],
      orderBy: 'started_at ASC',
    );
    final workouts = rows.map(Workout.fromMap).toList();

    final result = <WeeklyTrainingSummary>[];
    for (var i = 0; i < weeks; i++) {
      final start = firstWeekStart.add(Duration(days: i * 7));
      final end = start.add(const Duration(days: 7));
      final items = workouts.where(
        (w) => !w.startedAt.isBefore(start) && w.startedAt.isBefore(end),
      );
      var distance = 0.0;
      var seconds = 0;
      var rpeTotal = 0;
      var rpeCount = 0;
      var count = 0;
      for (final item in items) {
        distance += item.distanceKm;
        seconds += item.durationSeconds;
        count++;
        if (item.rpe != null) {
          rpeTotal += item.rpe!;
          rpeCount++;
        }
      }
      result.add(
        WeeklyTrainingSummary(
          weekStart: start,
          distanceKm: distance,
          workouts: count,
          duration: Duration(seconds: seconds),
          averageRpe: rpeCount == 0 ? null : rpeTotal / rpeCount,
        ),
      );
    }
    return result;
  }
}
