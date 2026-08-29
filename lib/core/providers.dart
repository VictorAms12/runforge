import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/checklist/data/checklist_repository.dart';
import '../features/checklist/domain/checklist_item.dart';
import '../features/goals/data/goals_repository.dart';
import '../features/goals/domain/goal.dart';
import '../features/profile/data/user_repository.dart';
import '../features/profile/domain/user_profile.dart';
import '../features/workout/data/workout_repository.dart';
import '../features/workout/domain/workout.dart';
import '../features/workout/presentation/workout_session_controller.dart';
import 'database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(databaseProvider)),
);
final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(databaseProvider)),
);
final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(databaseProvider)),
);
final checklistRepositoryProvider = Provider<ChecklistRepository>(
  (ref) => ChecklistRepository(ref.watch(databaseProvider)),
);

final userProfileProvider = FutureProvider<UserProfile>(
  (ref) => ref.watch(userRepositoryProvider).getProfile(),
);

final dashboardStatsProvider = FutureProvider<DashboardStats>(
  (ref) => ref.watch(workoutRepositoryProvider).getDashboardStats(),
);

final workoutHistoryProvider = FutureProvider<List<Workout>>(
  (ref) => ref.watch(workoutRepositoryProvider).getHistory(),
);

final goalsProvider = FutureProvider<List<GoalProgress>>(
  (ref) => ref.watch(goalsRepositoryProvider).getGoalsWithProgress(),
);

final checklistItemsProvider = FutureProvider.family<List<ChecklistItem>, ChecklistCategory>(
  (ref, category) => ref.watch(checklistRepositoryProvider).getByCategory(category),
);

final workoutSessionProvider = StateNotifierProvider.autoDispose
    .family<WorkoutSessionController, WorkoutSessionState, WorkoutMode>(
  (ref, mode) => WorkoutSessionController(
    mode: mode,
    workoutRepository: ref.watch(workoutRepositoryProvider),
    userRepository: ref.watch(userRepositoryProvider),
  ),
);
