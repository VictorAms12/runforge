import 'package:flutter_test/flutter_test.dart';
import 'package:runforge/features/workout/domain/interval_workout_config.dart';

void main() {
  test('calculates programmed interval duration', () {
    const config = IntervalWorkoutConfig(
      id: 'test',
      title: 'Test',
      warmup: Duration(minutes: 5),
      run: Duration(minutes: 1),
      recovery: Duration(minutes: 2),
      cycles: 8,
      cooldown: Duration(minutes: 5),
    );

    expect(config.intervalBlock, const Duration(minutes: 24));
    expect(config.totalDuration, const Duration(minutes: 34));
  });
}
