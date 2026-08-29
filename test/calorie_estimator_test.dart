import 'package:flutter_test/flutter_test.dart';
import 'package:runforge/core/utils/calorie_estimator.dart';
import 'package:runforge/features/profile/domain/user_profile.dart';

void main() {
  const profile = UserProfile(
    name: 'Runner',
    weightKg: 70,
    heightCm: 175,
    age: 25,
    sex: 'male',
  );

  test('calorie estimate grows with duration', () {
    final ten = CalorieEstimator.kcalForDuration(
      profile: profile,
      speedKmh: 10,
      duration: const Duration(minutes: 10),
    );
    final twenty = CalorieEstimator.kcalForDuration(
      profile: profile,
      speedKmh: 10,
      duration: const Duration(minutes: 20),
    );
    expect(twenty, greaterThan(ten));
  });

  test('higher intensity estimates more calories', () {
    final easy = CalorieEstimator.kcalForDuration(
      profile: profile,
      speedKmh: 6,
      duration: const Duration(minutes: 30),
    );
    final hard = CalorieEstimator.kcalForDuration(
      profile: profile,
      speedKmh: 12,
      duration: const Duration(minutes: 30),
    );
    expect(hard, greaterThan(easy));
  });
}
