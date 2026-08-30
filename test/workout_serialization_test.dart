import 'package:flutter_test/flutter_test.dart';
import 'package:runforge/features/workout/domain/workout.dart';

void main() {
  test('persists v1.1 workout metadata and splits', () {
    final workout = Workout(
      startedAt: DateTime(2026, 8, 30, 7),
      durationSeconds: 600,
      distanceKm: 1.5,
      calories: 100,
      avgPaceMinKm: 6.66,
      avgSpeedKmh: 9,
      intensity: 'moderate',
      workoutType: 'interval',
      rpe: 6,
      planSessionIndex: 2,
      templateId: 'beginner_1_2',
      autoPausedSeconds: 18,
      splits: const [
        WorkoutSplit(
          distanceKm: 1,
          durationSeconds: 400,
          paceMinKm: 6.66,
          isAuto: true,
        ),
      ],
    );

    final map = workout.toMap();
    final restored = Workout.fromMap({'id': 1, ...map});

    expect(restored.rpe, 6);
    expect(restored.planSessionIndex, 2);
    expect(restored.templateId, 'beginner_1_2');
    expect(restored.autoPausedSeconds, 18);
    expect(restored.splits, hasLength(1));
    expect(restored.splits.single.isAuto, isTrue);
  });
}
