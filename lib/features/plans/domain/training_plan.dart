import '../../workout/domain/interval_workout_config.dart';
import '../../workout/domain/workout_mode.dart';

class TrainingPlanSession {
  const TrainingPlanSession({
    required this.index,
    required this.week,
    required this.day,
    required this.title,
    required this.description,
    required this.mode,
    this.intervalConfig,
    this.targetDuration,
    this.targetDistanceKm,
  });

  final int index;
  final int week;
  final int day;
  final String title;
  final String description;
  final WorkoutMode mode;
  final IntervalWorkoutConfig? intervalConfig;
  final Duration? targetDuration;
  final double? targetDistanceKm;
}

class TrainingPlanProgress {
  const TrainingPlanProgress({
    required this.completedSessions,
    required this.totalSessions,
    required this.nextSession,
  });

  final int completedSessions;
  final int totalSessions;
  final TrainingPlanSession? nextSession;

  double get ratio => totalSessions == 0
      ? 0
      : (completedSessions / totalSessions).clamp(0.0, 1.0);

  bool get isCompleted => completedSessions >= totalSessions;
}

abstract final class Beginner5kPlan {
  static const id = 'beginner_5k_v1';
  static const title = 'Do zero aos 5 km';
  static const weeks = 8;

  static List<TrainingPlanSession> get sessions => _sessions;

  static TrainingPlanSession? sessionAt(int index) {
    if (index < 0 || index >= _sessions.length) return null;
    return _sessions[index];
  }

  static final List<TrainingPlanSession> _sessions = _build();

  static List<TrainingPlanSession> _build() {
    const weekConfigs = <IntervalWorkoutConfig>[
      IntervalWorkoutConfig(
        id: 'plan_w1',
        title: '1 min / 2 min',
        warmup: Duration(minutes: 5),
        run: Duration(minutes: 1),
        recovery: Duration(minutes: 2),
        cycles: 8,
        cooldown: Duration(minutes: 5),
      ),
      IntervalWorkoutConfig(
        id: 'plan_w2',
        title: '2 min / 2 min',
        warmup: Duration(minutes: 5),
        run: Duration(minutes: 2),
        recovery: Duration(minutes: 2),
        cycles: 7,
        cooldown: Duration(minutes: 5),
      ),
      IntervalWorkoutConfig(
        id: 'plan_w3',
        title: '3 min / 2 min',
        warmup: Duration(minutes: 5),
        run: Duration(minutes: 3),
        recovery: Duration(minutes: 2),
        cycles: 6,
        cooldown: Duration(minutes: 5),
      ),
      IntervalWorkoutConfig(
        id: 'plan_w4',
        title: '5 min / 2 min',
        warmup: Duration(minutes: 5),
        run: Duration(minutes: 5),
        recovery: Duration(minutes: 2),
        cycles: 5,
        cooldown: Duration(minutes: 5),
      ),
      IntervalWorkoutConfig(
        id: 'plan_w5',
        title: '8 min / 2 min',
        warmup: Duration(minutes: 5),
        run: Duration(minutes: 8),
        recovery: Duration(minutes: 2),
        cycles: 4,
        cooldown: Duration(minutes: 5),
      ),
      IntervalWorkoutConfig(
        id: 'plan_w6',
        title: '12 min / 2 min',
        warmup: Duration(minutes: 5),
        run: Duration(minutes: 12),
        recovery: Duration(minutes: 2),
        cycles: 3,
        cooldown: Duration(minutes: 5),
      ),
    ];

    final result = <TrainingPlanSession>[];
    var index = 0;
    for (var week = 1; week <= 6; week++) {
      for (var day = 1; day <= 3; day++) {
        final config = weekConfigs[week - 1];
        result.add(
          TrainingPlanSession(
            index: index++,
            week: week,
            day: day,
            title: 'Semana $week · Treino $day',
            description:
                '${config.run.inMinutes} min correndo / ${config.recovery.inMinutes} min recuperando × ${config.cycles}',
            mode: WorkoutMode.interval,
            intervalConfig: config,
          ),
        );
      }
    }

    const continuous = <Duration>[
      Duration(minutes: 22),
      Duration(minutes: 25),
      Duration(minutes: 28),
      Duration(minutes: 30),
      Duration(minutes: 32),
    ];
    for (var i = 0; i < continuous.length; i++) {
      result.add(
        TrainingPlanSession(
          index: index++,
          week: i < 3 ? 7 : 8,
          day: i < 3 ? i + 1 : i - 2,
          title: 'Semana ${i < 3 ? 7 : 8} · Treino ${i < 3 ? i + 1 : i - 2}',
          description: 'Corrida contínua confortável por ${continuous[i].inMinutes} min',
          mode: WorkoutMode.free,
          targetDuration: continuous[i],
        ),
      );
    }

    result.add(
      TrainingPlanSession(
        index: index,
        week: 8,
        day: 3,
        title: 'Semana 8 · Desafio 5K',
        description: 'Corra 5 km em ritmo confortável. O objetivo é completar.',
        mode: WorkoutMode.free,
        targetDistanceKm: 5,
      ),
    );
    return List.unmodifiable(result);
  }
}
