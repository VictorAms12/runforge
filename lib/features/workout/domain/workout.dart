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

  factory Workout.fromMap(Map<String, Object?> map) => Workout(
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
      );

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
