import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/daos/workouts_dao.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<int> firstExerciseId() async =>
      (await db.exercisesDao.getAllExercises()).first.id;

  test('creates a workout with ordered exercises', () async {
    final exerciseId = await firstExerciseId();
    final now = DateTime.now();
    final workoutId = await db.workoutsDao.insertWorkout(
      WorkoutsCompanion.insert(
        name: 'Treino A',
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.workoutsDao.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: workoutId,
        exerciseId: exerciseId,
        orderIndex: 0,
        targetSets: 3,
        targetReps: const Value(10),
      ),
    );

    final entries = await db.workoutsDao.getExercisesForWorkout(workoutId);
    expect(entries, hasLength(1));
    expect(entries.first.targetSets, 3);
  });

  test('duplicates a workout as a deep copy', () async {
    final exerciseId = await firstExerciseId();
    final now = DateTime.now();
    final workoutId = await db.workoutsDao.insertWorkout(
      WorkoutsCompanion.insert(
        name: 'Treino Original',
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.workoutsDao.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: workoutId,
        exerciseId: exerciseId,
        orderIndex: 0,
        targetSets: 4,
      ),
    );

    final copyId = await db.workoutsDao.duplicateWorkout(
      workoutId,
      newName: 'Treino Original (cópia)',
    );

    expect(copyId, isNot(workoutId));
    final copyExercises = await db.workoutsDao.getExercisesForWorkout(copyId);
    expect(copyExercises, hasLength(1));
    expect(copyExercises.first.targetSets, 4);

    // Editing the copy must not affect the original.
    await db.workoutsDao.deleteWorkoutExercise(copyExercises.first.id);
    final originalExercises = await db.workoutsDao.getExercisesForWorkout(
      workoutId,
    );
    expect(originalExercises, hasLength(1));
  });

  test('deleting a workout cascades to its exercise entries', () async {
    final exerciseId = await firstExerciseId();
    final now = DateTime.now();
    final workoutId = await db.workoutsDao.insertWorkout(
      WorkoutsCompanion.insert(
        name: 'Treino a excluir',
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await db.workoutsDao.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: workoutId,
        exerciseId: exerciseId,
        orderIndex: 0,
        targetSets: 3,
      ),
    );

    await db.workoutsDao.deleteWorkout(workoutId);

    expect(await db.workoutsDao.getWorkoutById(workoutId), isNull);
    expect(await db.workoutsDao.getExercisesForWorkout(workoutId), isEmpty);
  });

  test(
    'createWorkoutWithExercises builds a workout from resolved entries',
    () async {
      final exerciseId = await firstExerciseId();

      final workoutId = await db.workoutsDao.createWorkoutWithExercises(
        name: 'Push (do catálogo)',
        entries: [
          WorkoutExerciseEntry(
            exerciseId: exerciseId,
            orderIndex: 0,
            targetSets: 3,
            targetReps: 10,
            targetRestSeconds: 90,
          ),
        ],
      );

      final workout = await db.workoutsDao.getWorkoutById(workoutId);
      expect(workout!.name, 'Push (do catálogo)');
      final entries = await db.workoutsDao.getExercisesForWorkout(workoutId);
      expect(entries, hasLength(1));
      expect(entries.first.targetSets, 3);
      expect(entries.first.targetRestSeconds, 90);
    },
  );
}
