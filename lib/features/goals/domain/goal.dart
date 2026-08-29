enum GoalMetric { distanceKm, workoutDays }
enum GoalPeriod { daily, weekly, monthly }

class Goal {
  const Goal({
    this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.isCompleted,
    this.completedAt,
  });

  final int? id;
  final String title;
  final GoalMetric metric;
  final double target;
  final GoalPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCompleted;
  final DateTime? completedAt;

  factory Goal.fromMap(Map<String, Object?> map) => Goal(
        id: map['id'] as int?,
        title: map['title'] as String,
        metric: GoalMetric.values.byName(map['metric'] as String),
        target: (map['target'] as num).toDouble(),
        period: GoalPeriod.values.byName(map['period'] as String),
        startDate: DateTime.parse(map['start_date'] as String),
        endDate: DateTime.parse(map['end_date'] as String),
        isCompleted: (map['is_completed'] as int) == 1,
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.parse(map['completed_at'] as String),
      );

  Map<String, Object?> toMap() => {
        'title': title,
        'metric': metric.name,
        'target': target,
        'period': period.name,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };
}

class GoalProgress {
  const GoalProgress({required this.goal, required this.current});
  final Goal goal;
  final double current;

  double get ratio => goal.target <= 0 ? 0.0 : (current / goal.target).clamp(0.0, 1.0).toDouble();
  bool get reached => current >= goal.target;
}
