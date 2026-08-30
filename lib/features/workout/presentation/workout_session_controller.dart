import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/utils/calorie_estimator.dart';
import '../../profile/data/user_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/workout_repository.dart';
import '../domain/interval_workout_config.dart';
import '../domain/workout.dart';
import '../domain/workout_mode.dart';

class IntervalSegment {
  const IntervalSegment({
    required this.label,
    required this.duration,
    required this.intense,
    required this.cycle,
  });

  final String label;
  final Duration duration;
  final bool intense;
  final int cycle;
}

class WorkoutSessionState {
  const WorkoutSessionState({
    required this.mode,
    this.status = WorkoutStatus.idle,
    this.elapsed = Duration.zero,
    this.distanceKm = 0,
    this.currentPaceMinKm,
    this.avgPaceMinKm,
    this.calories = 0,
    this.splits = const [],
    this.isLocked = false,
    this.gpsActive = false,
    this.locationMessage,
    this.intervalStepIndex = 0,
    this.intervalRemaining = Duration.zero,
    this.intervalLabel = '',
    this.intervalIntense = false,
    this.currentCycle = 0,
    this.totalCycles = 0,
    this.intervalCompleted = false,
    this.startedAt,
    this.autoPauseEnabled = true,
    this.autoSplitEnabled = true,
    this.planSessionIndex,
    this.planTitle,
    this.planTargetDuration,
    this.planTargetDistanceKm,
    this.templateId,
  });

  final WorkoutMode mode;
  final WorkoutStatus status;
  final Duration elapsed;
  final double distanceKm;
  final double? currentPaceMinKm;
  final double? avgPaceMinKm;
  final double calories;
  final List<WorkoutSplit> splits;
  final bool isLocked;
  final bool gpsActive;
  final String? locationMessage;
  final int intervalStepIndex;
  final Duration intervalRemaining;
  final String intervalLabel;
  final bool intervalIntense;
  final int currentCycle;
  final int totalCycles;
  final bool intervalCompleted;
  final DateTime? startedAt;
  final bool autoPauseEnabled;
  final bool autoSplitEnabled;
  final int? planSessionIndex;
  final String? planTitle;
  final Duration? planTargetDuration;
  final double? planTargetDistanceKm;
  final String? templateId;

  bool get isRunning => status == WorkoutStatus.running;
  bool get isAutoPaused => status == WorkoutStatus.autoPaused;

  WorkoutSessionState copyWith({
    WorkoutStatus? status,
    Duration? elapsed,
    double? distanceKm,
    double? currentPaceMinKm,
    bool clearCurrentPace = false,
    double? avgPaceMinKm,
    bool clearAvgPace = false,
    double? calories,
    List<WorkoutSplit>? splits,
    bool? isLocked,
    bool? gpsActive,
    String? locationMessage,
    bool clearLocationMessage = false,
    int? intervalStepIndex,
    Duration? intervalRemaining,
    String? intervalLabel,
    bool? intervalIntense,
    int? currentCycle,
    int? totalCycles,
    bool? intervalCompleted,
    DateTime? startedAt,
    bool? autoPauseEnabled,
    bool? autoSplitEnabled,
    int? planSessionIndex,
    String? planTitle,
    Duration? planTargetDuration,
    double? planTargetDistanceKm,
    String? templateId,
  }) {
    return WorkoutSessionState(
      mode: mode,
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      distanceKm: distanceKm ?? this.distanceKm,
      currentPaceMinKm:
          clearCurrentPace ? null : currentPaceMinKm ?? this.currentPaceMinKm,
      avgPaceMinKm:
          clearAvgPace ? null : avgPaceMinKm ?? this.avgPaceMinKm,
      calories: calories ?? this.calories,
      splits: splits ?? this.splits,
      isLocked: isLocked ?? this.isLocked,
      gpsActive: gpsActive ?? this.gpsActive,
      locationMessage: clearLocationMessage
          ? null
          : locationMessage ?? this.locationMessage,
      intervalStepIndex: intervalStepIndex ?? this.intervalStepIndex,
      intervalRemaining: intervalRemaining ?? this.intervalRemaining,
      intervalLabel: intervalLabel ?? this.intervalLabel,
      intervalIntense: intervalIntense ?? this.intervalIntense,
      currentCycle: currentCycle ?? this.currentCycle,
      totalCycles: totalCycles ?? this.totalCycles,
      intervalCompleted: intervalCompleted ?? this.intervalCompleted,
      startedAt: startedAt ?? this.startedAt,
      autoPauseEnabled: autoPauseEnabled ?? this.autoPauseEnabled,
      autoSplitEnabled: autoSplitEnabled ?? this.autoSplitEnabled,
      planSessionIndex: planSessionIndex ?? this.planSessionIndex,
      planTitle: planTitle ?? this.planTitle,
      planTargetDuration: planTargetDuration ?? this.planTargetDuration,
      planTargetDistanceKm:
          planTargetDistanceKm ?? this.planTargetDistanceKm,
      templateId: templateId ?? this.templateId,
    );
  }
}

class WorkoutSessionController extends StateNotifier<WorkoutSessionState> {
  WorkoutSessionController({
    required WorkoutMode mode,
    required WorkoutRepository workoutRepository,
    required UserRepository userRepository,
  })  : _workoutRepository = workoutRepository,
        _userRepository = userRepository,
        super(
          WorkoutSessionState(
            mode: mode,
            intervalRemaining: mode == WorkoutMode.interval
                ? WorkoutTemplateCatalog.beginnerOneTwo.warmup
                : Duration.zero,
            intervalLabel:
                mode == WorkoutMode.interval ? 'AQUECIMENTO' : '',
            totalCycles: mode == WorkoutMode.interval
                ? WorkoutTemplateCatalog.beginnerOneTwo.cycles
                : 0,
            templateId: mode == WorkoutMode.interval
                ? WorkoutTemplateCatalog.beginnerOneTwo.id
                : null,
          ),
        );

  final WorkoutRepository _workoutRepository;
  final UserRepository _userRepository;
  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _lastCalorieTick = Duration.zero;
  Duration _lastSplitElapsed = Duration.zero;
  double _lastSplitDistanceKm = 0;
  double _nextAutoSplitKm = 1;
  DateTime? _lowSpeedSince;
  DateTime? _movingSince;
  DateTime? _autoPauseWallStart;
  Duration _autoPausedTotal = Duration.zero;
  bool _intervalCompletionAlerted = false;

  UserProfile _profile = const UserProfile(
    name: 'Corredor',
    weightKg: 70,
    heightCm: 175,
    age: 25,
    sex: 'not_informed',
  );

  IntervalWorkoutConfig _intervalConfig =
      WorkoutTemplateCatalog.beginnerOneTwo;

  IntervalWorkoutConfig get intervalConfig => _intervalConfig;

  List<IntervalSegment> get intervals => List.unmodifiable(_segmentsForConfig());

  IntervalSegment get currentInterval {
    final segments = _segmentsForConfig();
    final index = state.intervalStepIndex.clamp(0, segments.length - 1).toInt();
    return segments[index];
  }

  void configureIntervals(IntervalWorkoutConfig config) {
    if (state.status != WorkoutStatus.idle ||
        config.run.inSeconds <= 0 ||
        config.recovery.inSeconds <= 0 ||
        config.cycles <= 0) {
      return;
    }
    _intervalConfig = config;
    final first = _segmentsForConfig().first;
    state = state.copyWith(
      intervalStepIndex: 0,
      intervalRemaining: first.duration,
      intervalLabel: first.label,
      intervalIntense: first.intense,
      currentCycle: first.cycle,
      totalCycles: config.cycles,
      intervalCompleted: false,
      templateId: config.id,
    );
  }

  void configurePlanSession({
    required int index,
    required String title,
    Duration? targetDuration,
    double? targetDistanceKm,
  }) {
    if (state.status != WorkoutStatus.idle) return;
    state = state.copyWith(
      planSessionIndex: index,
      planTitle: title,
      planTargetDuration: targetDuration,
      planTargetDistanceKm: targetDistanceKm,
    );
  }

  void setAutoPauseEnabled(bool value) {
    if (state.status != WorkoutStatus.idle) return;
    state = state.copyWith(autoPauseEnabled: value);
  }

  void setAutoSplitEnabled(bool value) {
    if (state.status != WorkoutStatus.idle) return;
    state = state.copyWith(autoSplitEnabled: value);
  }

  Future<void> start() async {
    if (state.status == WorkoutStatus.running) return;
    if (state.intervalCompleted) return;

    if (state.status == WorkoutStatus.idle) {
      _profile = await _userRepository.getProfile();
      await _startLocation();
      _stopwatch
        ..reset()
        ..start();
      _lastCalorieTick = Duration.zero;
      _lastSplitElapsed = Duration.zero;
      _lastSplitDistanceKm = 0;
      _nextAutoSplitKm = 1;
      _autoPausedTotal = Duration.zero;
      _intervalCompletionAlerted = false;
      state = state.copyWith(startedAt: DateTime.now());
    } else if (state.status == WorkoutStatus.autoPaused) {
      _exitAutoPause(force: true);
      return;
    } else {
      _lastPosition = null;
      _positionSub?.resume();
      _stopwatch.start();
      _lastCalorieTick = _stopwatch.elapsed;
    }

    state = state.copyWith(status: WorkoutStatus.running);
    HapticFeedback.mediumImpact();
    _ensureTimer();
  }

  void pause() {
    if (state.status != WorkoutStatus.running &&
        state.status != WorkoutStatus.autoPaused) {
      return;
    }
    if (state.status == WorkoutStatus.autoPaused) {
      _finalizeAutoPauseDuration();
    } else {
      _stopwatch.stop();
    }
    _timer?.cancel();
    _timer = null;
    _positionSub?.pause();
    _lastPosition = null;
    _lowSpeedSince = null;
    _movingSince = null;
    state = state.copyWith(
      status: WorkoutStatus.paused,
      clearCurrentPace: true,
    );
    HapticFeedback.selectionClick();
  }

  void addLap() {
    if (state.status == WorkoutStatus.idle || state.distanceKm <= 0) return;
    _recordSplit(cumulativeDistanceKm: state.distanceKm, isAuto: false);
    HapticFeedback.lightImpact();
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
    HapticFeedback.selectionClick();
  }

  Future<int?> finish({String? notes, int? rpe}) async {
    if (state.status == WorkoutStatus.idle || state.elapsed.inSeconds == 0) {
      return null;
    }
    if (state.status == WorkoutStatus.autoPaused) {
      _finalizeAutoPauseDuration();
    }
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    await _positionSub?.cancel();
    _positionSub = null;

    final seconds = state.elapsed.inSeconds;
    final speed = seconds == 0
        ? 0.0
        : state.distanceKm / (seconds / Duration.secondsPerHour);
    final avgPace = state.distanceKm > .02
        ? (seconds / 60) / state.distanceKm
        : null;
    final workout = Workout(
      startedAt: state.startedAt ?? DateTime.now(),
      durationSeconds: seconds,
      distanceKm: state.distanceKm,
      calories: state.calories,
      avgPaceMinKm: avgPace,
      avgSpeedKmh: speed,
      intensity: _intensityFromSpeed(speed),
      workoutType: state.mode.name,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      rpe: rpe,
      splits: state.splits,
      planSessionIndex: _planTargetMet ? state.planSessionIndex : null,
      templateId: state.templateId,
      autoPausedSeconds: _autoPausedTotal.inSeconds,
    );
    final id = await _workoutRepository.insert(workout);
    state = state.copyWith(status: WorkoutStatus.finished, isLocked: false);
    HapticFeedback.heavyImpact();
    return id;
  }

  void _ensureTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!state.isRunning) return;
    final elapsed = _stopwatch.elapsed;
    final delta = elapsed - _lastCalorieTick;
    _lastCalorieTick = elapsed;

    var intervalStepIndex = state.intervalStepIndex;
    var intervalRemaining = state.intervalRemaining;
    var intervalLabel = state.intervalLabel;
    var intervalIntense = state.intervalIntense;
    var currentCycle = state.currentCycle;
    var intervalCompleted = state.intervalCompleted;

    if (state.mode == WorkoutMode.interval) {
      final resolved = _resolveInterval(elapsed);
      if (resolved.completed) {
        intervalCompleted = true;
        intervalRemaining = Duration.zero;
        intervalLabel = 'TREINO CONCLUÍDO';
        intervalIntense = false;
        currentCycle = _intervalConfig.cycles;
      } else {
        intervalStepIndex = resolved.index;
        intervalRemaining = resolved.remaining;
        intervalLabel = resolved.segment.label;
        intervalIntense = resolved.segment.intense;
        currentCycle = resolved.segment.cycle;
        if (resolved.index != state.intervalStepIndex && elapsed.inSeconds > 0) {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.heavyImpact();
        }
      }
    }

    final speed = _speedKmhFromPace(state.currentPaceMinKm) ??
        (elapsed.inSeconds > 0
            ? state.distanceKm /
                (elapsed.inSeconds / Duration.secondsPerHour)
            : 0);
    final deltaCalories = CalorieEstimator.kcalForDuration(
      profile: _profile,
      speedKmh: speed,
      duration: delta,
      intervalIntense: state.mode == WorkoutMode.interval && intervalIntense,
    );
    final avgPace = state.distanceKm > .02
        ? (elapsed.inSeconds / 60) / state.distanceKm
        : null;

    state = state.copyWith(
      elapsed: elapsed,
      calories: state.calories + deltaCalories,
      avgPaceMinKm: avgPace,
      intervalStepIndex: intervalStepIndex,
      intervalRemaining: intervalRemaining,
      intervalLabel: intervalLabel,
      intervalIntense: intervalIntense,
      currentCycle: currentCycle,
      intervalCompleted: intervalCompleted,
    );

    if (intervalCompleted) {
      _completeIntervalSession();
    }
  }

  void _completeIntervalSession() {
    if (_intervalCompletionAlerted) return;
    _intervalCompletionAlerted = true;
    _stopwatch.stop();
    _timer?.cancel();
    _timer = null;
    _positionSub?.pause();
    _lastPosition = null;
    state = state.copyWith(
      status: WorkoutStatus.paused,
      intervalCompleted: true,
      clearCurrentPace: true,
    );
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  List<IntervalSegment> _segmentsForConfig() {
    final segments = <IntervalSegment>[];
    if (_intervalConfig.warmup.inSeconds > 0) {
      segments.add(
        IntervalSegment(
          label: 'AQUECIMENTO',
          duration: _intervalConfig.warmup,
          intense: false,
          cycle: 0,
        ),
      );
    }
    for (var cycle = 1; cycle <= _intervalConfig.cycles; cycle++) {
      segments.add(
        IntervalSegment(
          label: 'CORRIDA',
          duration: _intervalConfig.run,
          intense: true,
          cycle: cycle,
        ),
      );
      segments.add(
        IntervalSegment(
          label: 'RECUPERAÇÃO',
          duration: _intervalConfig.recovery,
          intense: false,
          cycle: cycle,
        ),
      );
    }
    if (_intervalConfig.cooldown.inSeconds > 0) {
      segments.add(
        IntervalSegment(
          label: 'DESAQUECIMENTO',
          duration: _intervalConfig.cooldown,
          intense: false,
          cycle: _intervalConfig.cycles,
        ),
      );
    }
    return segments;
  }

  _ResolvedInterval _resolveInterval(Duration elapsed) {
    final segments = _segmentsForConfig();
    var cursor = 0;
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final end = cursor + segment.duration.inSeconds;
      if (elapsed.inSeconds < end) {
        final used = elapsed.inSeconds - cursor;
        return _ResolvedInterval(
          index: i,
          segment: segment,
          remaining: segment.duration - Duration(seconds: used),
          completed: false,
        );
      }
      cursor = end;
    }
    return _ResolvedInterval(
      index: segments.length - 1,
      segment: segments.last,
      remaining: Duration.zero,
      completed: true,
    );
  }

  Future<void> _startLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        state = state.copyWith(
          gpsActive: false,
          locationMessage: 'Ative a localização para medir distância e pace.',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(
          gpsActive: false,
          locationMessage: 'Permissão de localização não concedida.',
        );
        return;
      }

      state = state.copyWith(gpsActive: true, clearLocationMessage: true);
      const settings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      );
      _positionSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        _onPosition,
        onError: (_) => state = state.copyWith(
          gpsActive: false,
          locationMessage: 'GPS temporariamente indisponível.',
        ),
      );
    } catch (_) {
      state = state.copyWith(
        gpsActive: false,
        locationMessage: 'Não foi possível iniciar o GPS.',
      );
    }
  }

  void _onPosition(Position position) {
    if (state.status != WorkoutStatus.running &&
        state.status != WorkoutStatus.autoPaused) {
      return;
    }
    if (position.accuracy > 50) return;

    final speedMps = position.speed > 0 ? position.speed : 0.0;
    _handleAutoPause(speedMps);
    if (state.status == WorkoutStatus.autoPaused) {
      _lastPosition = null;
      return;
    }

    var distanceKm = state.distanceKm;
    if (_lastPosition != null) {
      final meters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (meters >= 1 && meters <= 120) {
        distanceKm += meters / 1000;
      }
    }
    _lastPosition = position;

    final currentPace = speedMps >= .6 ? (1000 / speedMps) / 60 : null;
    final avgPace = distanceKm > .02
        ? (state.elapsed.inSeconds / 60) / distanceKm
        : null;

    state = state.copyWith(
      distanceKm: distanceKm,
      currentPaceMinKm: currentPace,
      avgPaceMinKm: avgPace,
    );

    if (state.autoSplitEnabled && distanceKm >= _nextAutoSplitKm) {
      _recordSplit(cumulativeDistanceKm: distanceKm, isAuto: true);
      _nextAutoSplitKm = distanceKm.floorToDouble() + 1;
      HapticFeedback.mediumImpact();
    }
  }

  void _handleAutoPause(double speedMps) {
    if (!state.autoPauseEnabled || state.status == WorkoutStatus.paused) {
      _lowSpeedSince = null;
      _movingSince = null;
      return;
    }
    final now = DateTime.now();
    if (state.status == WorkoutStatus.running) {
      if (speedMps < .35) {
        _lowSpeedSince ??= now;
        if (now.difference(_lowSpeedSince!) >= const Duration(seconds: 10)) {
          _enterAutoPause();
        }
      } else {
        _lowSpeedSince = null;
      }
      return;
    }

    if (state.status == WorkoutStatus.autoPaused) {
      if (speedMps > .75) {
        _movingSince ??= now;
        if (now.difference(_movingSince!) >= const Duration(seconds: 2)) {
          _exitAutoPause();
        }
      } else {
        _movingSince = null;
      }
    }
  }

  void _enterAutoPause() {
    if (state.status != WorkoutStatus.running) return;
    _stopwatch.stop();
    _autoPauseWallStart = DateTime.now();
    _lastPosition = null;
    _movingSince = null;
    state = state.copyWith(
      status: WorkoutStatus.autoPaused,
      clearCurrentPace: true,
    );
    HapticFeedback.selectionClick();
  }

  void _exitAutoPause({bool force = false}) {
    if (state.status != WorkoutStatus.autoPaused) return;
    _finalizeAutoPauseDuration();
    _lastPosition = null;
    _lowSpeedSince = null;
    _movingSince = null;
    _stopwatch.start();
    _lastCalorieTick = _stopwatch.elapsed;
    state = state.copyWith(status: WorkoutStatus.running);
    if (!force) HapticFeedback.mediumImpact();
    _ensureTimer();
  }

  void _finalizeAutoPauseDuration() {
    if (_autoPauseWallStart != null) {
      _autoPausedTotal += DateTime.now().difference(_autoPauseWallStart!);
      _autoPauseWallStart = null;
    }
  }

  void _recordSplit({
    required double cumulativeDistanceKm,
    required bool isAuto,
  }) {
    final splitDistance = cumulativeDistanceKm - _lastSplitDistanceKm;
    final splitDuration = state.elapsed - _lastSplitElapsed;
    if (splitDistance < .05 || splitDuration.inSeconds <= 0) return;
    final pace = (splitDuration.inSeconds / 60) / splitDistance;
    final split = WorkoutSplit(
      distanceKm: splitDistance,
      durationSeconds: splitDuration.inSeconds,
      paceMinKm: pace,
      isAuto: isAuto,
    );
    _lastSplitElapsed = state.elapsed;
    _lastSplitDistanceKm = cumulativeDistanceKm;
    state = state.copyWith(splits: [...state.splits, split]);
  }

  bool get _planTargetMet {
    if (state.planSessionIndex == null) return true;
    if (state.mode == WorkoutMode.interval) return state.intervalCompleted;
    if (state.planTargetDistanceKm != null) {
      return state.distanceKm >= state.planTargetDistanceKm!;
    }
    if (state.planTargetDuration != null) {
      return state.elapsed >= state.planTargetDuration!;
    }
    return true;
  }

  double? _speedKmhFromPace(double? pace) {
    if (pace == null || pace <= 0) return null;
    return 60 / pace;
  }

  String _intensityFromSpeed(double kmh) {
    if (kmh < 6) return 'light';
    if (kmh < 10) return 'moderate';
    return 'high';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }
}

class _ResolvedInterval {
  const _ResolvedInterval({
    required this.index,
    required this.segment,
    required this.remaining,
    required this.completed,
  });

  final int index;
  final IntervalSegment segment;
  final Duration remaining;
  final bool completed;
}
