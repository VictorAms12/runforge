import '../../features/profile/domain/user_profile.dart';

class CalorieEstimator {
  const CalorieEstimator._();

  /// Sports-oriented estimate. It combines MET-based active expenditure with
  /// a Mifflin-St Jeor resting component so age, sex, height and weight all
  /// participate in the result. This is not a medical-grade measurement.
  static double kcalForDuration({
    required UserProfile profile,
    required double speedKmh,
    required Duration duration,
    bool intervalIntense = false,
  }) {
    if (duration <= Duration.zero) return 0;
    final met = _metForSpeed(speedKmh, intervalIntense: intervalIntense);
    final grossMetKcalPerMinute = met * 3.5 * profile.weightKg / 200;
    final restingMetKcalPerMinute = 3.5 * profile.weightKg / 200;
    final bmrPerMinute = _bmr(profile) / 1440;

    // Replace the generic resting 1-MET component with the user's BMR.
    final personalizedPerMinute =
        (grossMetKcalPerMinute - restingMetKcalPerMinute).clamp(0.0, double.infinity).toDouble() +
            bmrPerMinute;
    return personalizedPerMinute * (duration.inMilliseconds / 60000);
  }

  static double _bmr(UserProfile p) {
    final base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age;
    return switch (p.sex) {
      'male' => base + 5,
      'female' => base - 161,
      _ => base - 78,
    };
  }

  static double _metForSpeed(double kmh, {required bool intervalIntense}) {
    double met;
    if (kmh < 5.5) {
      met = 3.5;
    } else if (kmh < 8) {
      met = 7.0;
    } else if (kmh < 10) {
      met = 9.8;
    } else if (kmh < 12) {
      met = 11.0;
    } else if (kmh < 14) {
      met = 12.8;
    } else {
      met = 14.5;
    }
    return intervalIntense ? met + .8 : met;
  }
}
