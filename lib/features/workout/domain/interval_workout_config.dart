class IntervalWorkoutConfig {
  const IntervalWorkoutConfig({
    required this.id,
    required this.title,
    required this.run,
    required this.recovery,
    required this.cycles,
    this.warmup = Duration.zero,
    this.cooldown = Duration.zero,
  });

  final String id;
  final String title;
  final Duration warmup;
  final Duration run;
  final Duration recovery;
  final int cycles;
  final Duration cooldown;

  Duration get intervalBlock => Duration(
        seconds: (run.inSeconds + recovery.inSeconds) * cycles,
      );

  Duration get totalDuration => Duration(
        seconds: warmup.inSeconds + intervalBlock.inSeconds + cooldown.inSeconds,
      );

  IntervalWorkoutConfig copyWith({
    String? id,
    String? title,
    Duration? warmup,
    Duration? run,
    Duration? recovery,
    int? cycles,
    Duration? cooldown,
  }) {
    return IntervalWorkoutConfig(
      id: id ?? this.id,
      title: title ?? this.title,
      warmup: warmup ?? this.warmup,
      run: run ?? this.run,
      recovery: recovery ?? this.recovery,
      cycles: cycles ?? this.cycles,
      cooldown: cooldown ?? this.cooldown,
    );
  }
}

abstract final class WorkoutTemplateCatalog {
  static const beginnerOneTwo = IntervalWorkoutConfig(
    id: 'beginner_1_2',
    title: '1/2 Iniciante',
    warmup: Duration(minutes: 5),
    run: Duration(minutes: 1),
    recovery: Duration(minutes: 2),
    cycles: 8,
    cooldown: Duration(minutes: 5),
  );

  static const progressTwoOne = IntervalWorkoutConfig(
    id: 'progress_2_1',
    title: '2/1 Progressão',
    warmup: Duration(minutes: 5),
    run: Duration(minutes: 2),
    recovery: Duration(minutes: 1),
    cycles: 8,
    cooldown: Duration(minutes: 5),
  );

  static const steadyFiveTwo = IntervalWorkoutConfig(
    id: 'steady_5_2',
    title: '5/2 Resistência',
    warmup: Duration(minutes: 5),
    run: Duration(minutes: 5),
    recovery: Duration(minutes: 2),
    cycles: 5,
    cooldown: Duration(minutes: 5),
  );

  static const hiitShort = IntervalWorkoutConfig(
    id: 'hiit_30_60',
    title: 'HIIT curto',
    warmup: Duration(minutes: 5),
    run: Duration(seconds: 30),
    recovery: Duration(minutes: 1),
    cycles: 12,
    cooldown: Duration(minutes: 5),
  );

  static const all = [
    beginnerOneTwo,
    progressTwoOne,
    steadyFiveTwo,
    hiitShort,
  ];
}
