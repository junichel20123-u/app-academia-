import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/workout_exercises_table.dart';
import '../tables/workouts_table.dart';

part 'workouts_dao.g.dart';

@DriftAccessor(tables: [Workouts, WorkoutExercises])
class WorkoutsDao extends DatabaseAccessor<AppDatabase>
    with _$WorkoutsDaoMixin {
  WorkoutsDao(super.db);

  Stream<List<Workout>> watchAllWorkouts() => (select(
    workouts,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<Workout?> getWorkoutById(int id) =>
      (select(workouts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<WorkoutExercise>> getExercisesForWorkout(int workoutId) {
    final query = select(workoutExercises)
      ..where((t) => t.workoutId.equals(workoutId))
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);
    return query.get();
  }

  Stream<List<WorkoutExercise>> watchExercisesForWorkout(int workoutId) {
    final query = select(workoutExercises)
      ..where((t) => t.workoutId.equals(workoutId))
      ..orderBy([(t) => OrderingTerm.asc(t.orderIndex)]);
    return query.watch();
  }

  Future<int> insertWorkout(WorkoutsCompanion entry) =>
      into(workouts).insert(entry);

  Future<bool> updateWorkout(Workout entry) => update(workouts).replace(entry);

  Future<int> deleteWorkout(int id) =>
      (delete(workouts)..where((t) => t.id.equals(id))).go();

  Future<int> insertWorkoutExercise(WorkoutExercisesCompanion entry) =>
      into(workoutExercises).insert(entry);

  Future<bool> updateWorkoutExercise(WorkoutExercise entry) =>
      update(workoutExercises).replace(entry);

  Future<int> deleteWorkoutExercise(int id) =>
      (delete(workoutExercises)..where((t) => t.id.equals(id))).go();

  /// Deep-copies a workout (and its exercise entries) into a new template.
  Future<int> duplicateWorkout(int workoutId, {required String newName}) {
    return transaction(() async {
      final original = await getWorkoutById(workoutId);
      if (original == null) {
        throw ArgumentError('Workout $workoutId not found');
      }
      final now = DateTime.now();
      final newWorkoutId = await insertWorkout(
        WorkoutsCompanion.insert(
          name: newName,
          notes: Value(original.notes),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      final entries = await getExercisesForWorkout(workoutId);
      for (final entry in entries) {
        await insertWorkoutExercise(
          WorkoutExercisesCompanion.insert(
            workoutId: newWorkoutId,
            exerciseId: entry.exerciseId,
            orderIndex: entry.orderIndex,
            targetSets: entry.targetSets,
            targetReps: Value(entry.targetReps),
            targetWeight: Value(entry.targetWeight),
            targetRestSeconds: Value(entry.targetRestSeconds),
            notes: Value(entry.notes),
          ),
        );
      }
      return newWorkoutId;
    });
  }
}
