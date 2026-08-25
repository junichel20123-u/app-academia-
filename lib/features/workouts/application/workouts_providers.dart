import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/workouts_repository.dart';

final workoutsRepositoryProvider = Provider<WorkoutsRepository>((ref) {
  return WorkoutsRepository(ref.watch(appDatabaseProvider));
});

final workoutsListProvider = StreamProvider<List<Workout>>((ref) {
  return ref.watch(workoutsRepositoryProvider).watchAllWorkouts();
});

final workoutByIdProvider = FutureProvider.autoDispose.family<Workout?, int>((
  ref,
  workoutId,
) {
  return ref.watch(workoutsRepositoryProvider).getWorkoutById(workoutId);
});

final workoutExercisesProvider = StreamProvider.autoDispose
    .family<List<WorkoutExercise>, int>((ref, workoutId) {
      return ref
          .watch(workoutsRepositoryProvider)
          .watchExercisesForWorkout(workoutId);
    });
