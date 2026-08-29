import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/goal.dart';

class GoalsRepository {
  GoalsRepository(this._db);
  final AppDatabase _db;

  Future<int> insert(Goal goal) async {
    final db = await _db.database;
    return db.insert('goals', goal.toMap());
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('goals', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GoalProgress>> getGoalsWithProgress() async {
    final db = await _db.database;
    final rows = await db.query('goals', orderBy: 'is_completed ASC, end_date ASC');
    final result = <GoalProgress>[];

    for (final row in rows) {
      var goal = Goal.fromMap(row);
      final current = await _calculateProgress(db, goal);
      if (!goal.isCompleted && current >= goal.target) {
        final completedAt = DateTime.now();
        await db.update(
          'goals',
          {'is_completed': 1, 'completed_at': completedAt.toIso8601String()},
          where: 'id = ?',
          whereArgs: [goal.id],
        );
        goal = Goal(
          id: goal.id,
          title: goal.title,
          metric: goal.metric,
          target: goal.target,
          period: goal.period,
          startDate: goal.startDate,
          endDate: goal.endDate,
          isCompleted: true,
          completedAt: completedAt,
        );
      }
      result.add(GoalProgress(goal: goal, current: current));
    }
    return result;
  }

  Future<double> _calculateProgress(DatabaseExecutor db, Goal goal) async {
    if (goal.metric == GoalMetric.distanceKm) {
      final rows = await db.rawQuery('''
        SELECT COALESCE(SUM(distance_km), 0) AS value
        FROM workouts
        WHERE started_at >= ? AND started_at <= ?
      ''', [goal.startDate.toIso8601String(), goal.endDate.toIso8601String()]);
      return (rows.first['value'] as num).toDouble();
    }

    final rows = await db.rawQuery('''
      SELECT COUNT(DISTINCT substr(started_at, 1, 10)) AS value
      FROM workouts
      WHERE started_at >= ? AND started_at <= ?
    ''', [goal.startDate.toIso8601String(), goal.endDate.toIso8601String()]);
    return (rows.first['value'] as num).toDouble();
  }
}
