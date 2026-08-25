import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class WorkoutsRepository {
  WorkoutsRepository(this._db);

  final AppDatabase _db;

  Stream<List<Workout>> watchAllWorkouts() =>
      _db.workoutsDao.watchAllWorkouts();

  Future<Workout?> getWorkoutById(int id) => _db.workoutsDao.getWorkoutById(id);

  Stream<List<WorkoutExercise>> watchExercisesForWorkout(int workoutId) =>
      _db.workoutsDao.watchExercisesForWorkout(workoutId);

  Future<int> createWorkout({required String name, String? notes}) {
    final now = DateTime.now();
    return _db.workoutsDao.insertWorkout(
      WorkoutsCompanion.insert(
        name: name,
        notes: Value(notes),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> renameWorkout(
    Workout workout, {
    required String name,
    String? notes,
  }) {
    return _db.workoutsDao.updateWorkout(
      workout.copyWith(
        name: name,
        notes: Value(notes),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteWorkout(int id) => _db.workoutsDao.deleteWorkout(id);

  Future<int> duplicateWorkout(int workoutId, {required String newName}) =>
      _db.workoutsDao.duplicateWorkout(workoutId, newName: newName);

  Future<void> addExerciseToWorkout({
    required int workoutId,
    required int exerciseId,
    required int orderIndex,
    required int targetSets,
    int? targetReps,
    double? targetWeight,
    int? targetRestSeconds,
  }) async {
    await _db.workoutsDao.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: workoutId,
        exerciseId: exerciseId,
        orderIndex: orderIndex,
        targetSets: targetSets,
        targetReps: Value(targetReps),
        targetWeight: Value(targetWeight),
        targetRestSeconds: Value(targetRestSeconds),
      ),
    );
    await _touchWorkout(workoutId);
  }

  Future<void> updateWorkoutExercise(WorkoutExercise entry) async {
    await _db.workoutsDao.updateWorkoutExercise(entry);
    await _touchWorkout(entry.workoutId);
  }

  Future<void> removeWorkoutExercise(WorkoutExercise entry) async {
    await _db.workoutsDao.deleteWorkoutExercise(entry.id);
    await _touchWorkout(entry.workoutId);
  }

  /// Persists a new exercise ordering after a drag-and-drop reorder.
  Future<void> reorderExercises(List<WorkoutExercise> newOrder) async {
    for (var i = 0; i < newOrder.length; i++) {
      final entry = newOrder[i];
      if (entry.orderIndex != i) {
        await _db.workoutsDao.updateWorkoutExercise(
          entry.copyWith(orderIndex: i),
        );
      }
    }
    if (newOrder.isNotEmpty) {
      await _touchWorkout(newOrder.first.workoutId);
    }
  }

  Future<void> _touchWorkout(int workoutId) async {
    final workout = await _db.workoutsDao.getWorkoutById(workoutId);
    if (workout != null) {
      await _db.workoutsDao.updateWorkout(
        workout.copyWith(updatedAt: DateTime.now()),
      );
    }
  }
}
