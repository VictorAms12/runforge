import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/utils/calorie_estimator.dart';
import '../../profile/data/user_repository.dart';
import '../../profile/domain/user_profile.dart';
import '../data/workout_repository.dart';
import '../domain/workout.dart';

enum WorkoutMode { free, interval }
enum WorkoutStatus { idle, running, paused, finished }

class IntervalSegment {
  const IntervalSegment({required this.label, required this.duration, required this.intense});
  final String label;
  final Duration duration;
  final bool intense;
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
    this.laps = const [],
    this.isLocked = false,
    this.gpsActive = false,
    this.locationMessage,
    this.intervalIndex = 0,
    this.intervalRemaining = Duration.zero,
    this.startedAt,
  });

  final WorkoutMode mode;
  final WorkoutStatus status;
  final Duration elapsed;
  final double distanceKm;
  final double? currentPaceMinKm;
  final double? avgPaceMinKm;
  final double calories;
  final List<Duration> laps;
  final bool isLocked;
  final bool gpsActive;
  final String? locationMessage;
  final int intervalIndex;
  final Duration intervalRemaining;
  final DateTime? startedAt;

  bool get isRunning => status == WorkoutStatus.running;

  WorkoutSessionState copyWith({
    WorkoutStatus? status,
    Duration? elapsed,
    double? distanceKm,
    double? currentPaceMinKm,
    bool clearCurrentPace = false,
    double? avgPaceMinKm,
    bool clearAvgPace = false,
    double? calories,
    List<Duration>? laps,
    bool? isLocked,
    bool? gpsActive,
    String? locationMessage,
    bool clearLocationMessage = false,
    int? intervalIndex,
    Duration? intervalRemaining,
    DateTime? startedAt,
  }) {
    return WorkoutSessionState(
      mode: mode,
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      distanceKm: distanceKm ?? this.distanceKm,
      currentPaceMinKm: clearCurrentPace ? null : currentPaceMinKm ?? this.currentPaceMinKm,
      avgPaceMinKm: clearAvgPace ? null : avgPaceMinKm ?? this.avgPaceMinKm,
      calories: calories ?? this.calories,
      laps: laps ?? this.laps,
      isLocked: isLocked ?? this.isLocked,
      gpsActive: gpsActive ?? this.gpsActive,
      locationMessage: clearLocationMessage ? null : locationMessage ?? this.locationMessage,
      intervalIndex: intervalIndex ?? this.intervalIndex,
      intervalRemaining: intervalRemaining ?? this.intervalRemaining,
      startedAt: startedAt ?? this.startedAt,
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
        super(WorkoutSessionState(
          mode: mode,
          intervalRemaining: mode == WorkoutMode.interval
              ? _defaultIntervals.first.duration
              : Duration.zero,
        ));

  final WorkoutRepository _workoutRepository;
  final UserRepository _userRepository;
  Timer? _timer;
  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  final Stopwatch _stopwatch = Stopwatch();
  Duration _lastCalorieTick = Duration.zero;
  UserProfile _profile = const UserProfile(
    name: 'Corredor',
    weightKg: 70,
    heightCm: 175,
    age: 25,
    sex: 'not_informed',
  );

  static const _defaultIntervals = <IntervalSegment>[
    IntervalSegment(label: 'CORRIDA FORTE', duration: Duration(minutes: 1), intense: true),
    IntervalSegment(label: 'CAMINHADA', duration: Duration(minutes: 2), intense: false),
  ];

  List<IntervalSegment> _intervals = List.of(_defaultIntervals);

  List<IntervalSegment> get intervals => List.unmodifiable(_intervals);
  IntervalSegment get currentInterval => _intervals[state.intervalIndex];

  void configureIntervals({required Duration run, required Duration walk}) {
    if (state.status != WorkoutStatus.idle || run.inSeconds <= 0 || walk.inSeconds <= 0) return;
    _intervals = [
      IntervalSegment(label: 'CORRIDA FORTE', duration: run, intense: true),
      IntervalSegment(label: 'CAMINHADA', duration: walk, intense: false),
    ];
    state = state.copyWith(intervalIndex: 0, intervalRemaining: run);
  }

  Future<void> start() async {
    if (state.status == WorkoutStatus.running) return;

    if (state.status == WorkoutStatus.idle) {
      _profile = await _userRepository.getProfile();
      await _startLocation();
      _stopwatch
        ..reset()
        ..start();
      _lastCalorieTick = Duration.zero;
      state = state.copyWith(startedAt: DateTime.now());
    } else {
      _lastPosition = null;
      _positionSub?.resume();
      _stopwatch.start();
      _lastCalorieTick = _stopwatch.elapsed;
    }

    state = state.copyWith(status: WorkoutStatus.running);
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pause() {
    if (!state.isRunning) return;
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
    _positionSub?.pause();
    _lastPosition = null;
    state = state.copyWith(status: WorkoutStatus.paused, clearCurrentPace: true);
    HapticFeedback.selectionClick();
  }

  void addLap() {
    if (state.status == WorkoutStatus.idle) return;
    final previous = state.laps.fold<int>(0, (sum, lap) => sum + lap.inSeconds);
    final lap = Duration(seconds: (state.elapsed.inSeconds - previous).clamp(0, 1 << 31).toInt());
    state = state.copyWith(laps: [...state.laps, lap]);
    HapticFeedback.lightImpact();
  }

  void toggleLock() {
    state = state.copyWith(isLocked: !state.isLocked);
    HapticFeedback.selectionClick();
  }

  Future<int?> finish({String? notes}) async {
    if (state.status == WorkoutStatus.idle || state.elapsed.inSeconds == 0) return null;
    _timer?.cancel();
    _timer = null;
    await _positionSub?.cancel();
    _positionSub = null;

    final seconds = state.elapsed.inSeconds;
    final speed = seconds == 0 ? 0.0 : state.distanceKm / (seconds / 3600);
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
    );
    final id = await _workoutRepository.insert(workout);
    state = state.copyWith(status: WorkoutStatus.finished, isLocked: false);
    HapticFeedback.heavyImpact();
    return id;
  }

  void _tick() {
    if (!state.isRunning) return;
    final elapsed = _stopwatch.elapsed;
    final delta = elapsed - _lastCalorieTick;
    _lastCalorieTick = elapsed;

    var index = state.intervalIndex;
    var remaining = state.intervalRemaining;
    if (state.mode == WorkoutMode.interval) {
      final cycle = _intervals.fold<int>(0, (sum, item) => sum + item.duration.inSeconds);
      final offset = cycle == 0 ? 0 : elapsed.inSeconds % cycle;
      final first = _intervals.first.duration.inSeconds;
      final newIndex = offset < first ? 0 : 1;
      final segmentOffset = newIndex == 0 ? offset : offset - first;
      remaining = _intervals[newIndex].duration - Duration(seconds: segmentOffset);
      if (newIndex != index && elapsed.inSeconds > 0) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
      index = newIndex;
    }

    final speed = _speedKmhFromPace(state.currentPaceMinKm) ??
        (elapsed.inSeconds > 0 ? state.distanceKm / (elapsed.inSeconds / 3600) : 0);
    final deltaCalories = CalorieEstimator.kcalForDuration(
      profile: _profile,
      speedKmh: speed,
      duration: delta,
      intervalIntense: state.mode == WorkoutMode.interval && _intervals[index].intense,
    );
    final avgPace = state.distanceKm > .02
        ? (elapsed.inSeconds / 60) / state.distanceKm
        : null;

    state = state.copyWith(
      elapsed: elapsed,
      calories: state.calories + deltaCalories,
      avgPaceMinKm: avgPace,
      intervalIndex: index,
      intervalRemaining: remaining,
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
      _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
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
    if (!state.isRunning) return;
    if (position.accuracy > 50) return;

    double distanceKm = state.distanceKm;
    if (_lastPosition != null) {
      final meters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (meters >= 1 && meters <= 120) distanceKm += meters / 1000;
    }
    _lastPosition = position;

    final speedMps = position.speed > 0 ? position.speed : 0.0;
    final currentPace = speedMps >= .6 ? (1000 / speedMps) / 60 : null;
    final avgPace = distanceKm > .02
        ? (state.elapsed.inSeconds / 60) / distanceKm
        : null;

    state = state.copyWith(
      distanceKm: distanceKm,
      currentPaceMinKm: currentPace,
      avgPaceMinKm: avgPace,
    );
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
