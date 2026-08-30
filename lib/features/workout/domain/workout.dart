import 'dart:convert';

class WorkoutSplit {
  const WorkoutSplit({
    required this.distanceKm,
    required this.durationSeconds,
    required this.paceMinKm,
    required this.isAuto,
  });

  final double distanceKm;
  final int durationSeconds;
  final double? paceMinKm;
  final bool isAuto;

  factory WorkoutSplit.fromMap(Map<String, Object?> map) => WorkoutSplit(
        distanceKm: (map['distance_km'] as num).toDouble(),
        durationSeconds: (map['duration_seconds'] as num).toInt(),
        paceMinKm: (map['pace_min_km'] as num?)?.toDouble(),
        isAuto: map['is_auto'] == true || map['is_auto'] == 1,
      );

  Map<String, Object?> toMap() => {
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'pace_min_km': paceMinKm,
        'is_auto': isAuto,
      };
}

class Workout {
  const Workout({
    this.id,
    required this.startedAt,
    required this.durationSeconds,
    required this.distanceKm,
    required this.calories,
    required this.avgPaceMinKm,
    required this.avgSpeedKmh,
    required this.intensity,
    required this.workoutType,
    this.notes,
    this.rpe,
    this.splits = const [],
    this.planSessionIndex,
    this.templateId,
    this.autoPausedSeconds = 0,
  });

  final int? id;
  final DateTime startedAt;
  final int durationSeconds;
  final double distanceKm;
  final double calories;
  final double? avgPaceMinKm;
  final double avgSpeedKmh;
  final String intensity;
  final String workoutType;
  final String? notes;
  final int? rpe;
  final List<WorkoutSplit> splits;
  final int? planSessionIndex;
  final String? templateId;
  final int autoPausedSeconds;

  factory Workout.fromMap(Map<String, Object?> map) {
    final rawSplits = map['splits_json'] as String?;
    final decoded = rawSplits == null || rawSplits.isEmpty
        ? const <Object?>[]
        : jsonDecode(rawSplits) as List<Object?>;
    return Workout(
      id: map['id'] as int?,
      startedAt: DateTime.parse(map['started_at'] as String),
      durationSeconds: map['duration_seconds'] as int,
      distanceKm: (map['distance_km'] as num).toDouble(),
      calories: (map['calories'] as num).toDouble(),
      avgPaceMinKm: (map['avg_pace_min_km'] as num?)?.toDouble(),
      avgSpeedKmh: (map['avg_speed_kmh'] as num).toDouble(),
      intensity: map['intensity'] as String,
      workoutType: map['workout_type'] as String,
      notes: map['notes'] as String?,
      rpe: (map['rpe'] as num?)?.toInt(),
      splits: decoded
          .map((item) => WorkoutSplit.fromMap(
                Map<String, Object?>.from(item as Map),
              ))
          .toList(growable: false),
      planSessionIndex: (map['plan_session_index'] as num?)?.toInt(),
      templateId: map['template_id'] as String?,
      autoPausedSeconds: (map['auto_paused_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toMap() => {
        'started_at': startedAt.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_km': distanceKm,
        'calories': calories,
        'avg_pace_min_km': avgPaceMinKm,
        'avg_speed_kmh': avgSpeedKmh,
        'intensity': intensity,
        'workout_type': workoutType,
        'notes': notes,
        'rpe': rpe,
        'splits_json': jsonEncode(splits.map((e) => e.toMap()).toList()),
        'plan_session_index': planSessionIndex,
        'template_id': templateId,
        'auto_paused_seconds': autoPausedSeconds,
      };
}

class DashboardStats {
  const DashboardStats({
    required this.weekDistanceKm,
    required this.weekWorkouts,
    required this.weekDuration,
    required this.monthDistanceKm,
  });

  final double weekDistanceKm;
  final int weekWorkouts;
  final Duration weekDuration;
  final double monthDistanceKm;
}

class PersonalRecords {
  const PersonalRecords({
    this.longestDistance,
    this.longestDuration,
    this.bestAveragePace,
    this.bestOneKmPace,
    this.bestFiveKmPace,
  });

  final Workout? longestDistance;
  final Workout? longestDuration;
  final Workout? bestAveragePace;
  final double? bestOneKmPace;
  final double? bestFiveKmPace;

  bool get hasAny =>
      longestDistance != null ||
      longestDuration != null ||
      bestAveragePace != null ||
      bestOneKmPace != null ||
      bestFiveKmPace != null;
}

class WeeklyTrainingSummary {
  const WeeklyTrainingSummary({
    required this.weekStart,
    required this.distanceKm,
    required this.workouts,
    required this.duration,
    required this.averageRpe,
  });

  final DateTime weekStart;
  final double distanceKm;
  final int workouts;
  final Duration duration;
  final double? averageRpe;
}
