import 'package:flutter_test/flutter_test.dart';
import 'package:runforge/features/plans/domain/training_plan.dart';
import 'package:runforge/features/workout/domain/workout_mode.dart';

void main() {
  test('beginner 5k plan has eight weeks and 24 sessions', () {
    final sessions = Beginner5kPlan.sessions;

    expect(sessions.length, 24);
    expect(sessions.first.week, 1);
    expect(sessions.last.week, 8);
    expect(sessions.last.targetDistanceKm, 5);
    expect(sessions.last.mode, WorkoutMode.free);
  });

  test('first plan workout is a closed eight-cycle interval', () {
    final first = Beginner5kPlan.sessions.first;
    final config = first.intervalConfig!;

    expect(first.mode, WorkoutMode.interval);
    expect(config.cycles, 8);
    expect(config.run, const Duration(minutes: 1));
    expect(config.recovery, const Duration(minutes: 2));
    expect(config.totalDuration, const Duration(minutes: 34));
  });
}
