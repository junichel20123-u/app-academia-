import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/features/workouts/data/workouts_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WorkoutsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WorkoutsRepository(db);
  });
  tearDown(() => db.close());

  Future<int> firstExerciseId() async =>
      (await db.exercisesDao.getAllExercises()).first.id;

  test('creates a workout and adds an exercise to it', () async {
    final workoutId = await repo.createWorkout(name: 'Treino A');
    final exerciseId = await firstExerciseId();

    await repo.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseId: exerciseId,
      orderIndex: 0,
      targetSets: 3,
      targetReps: 10,
    );

    final entries = await repo.watchExercisesForWorkout(workoutId).first;
    expect(entries, hasLength(1));
    expect(entries.first.targetSets, 3);
  });

  test('reorders exercises and persists the new order', () async {
    final workoutId = await repo.createWorkout(name: 'Treino B');
    final exerciseId = await firstExerciseId();

    await repo.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseId: exerciseId,
      orderIndex: 0,
      targetSets: 3,
    );
    await repo.addExerciseToWorkout(
      workoutId: workoutId,
      exerciseId: exerciseId,
      orderIndex: 1,
      targetSets: 4,
    );

    var entries = await repo.watchExercisesForWorkout(workoutId).first;
    expect(entries.map((e) => e.targetSets), [3, 4]);

    await repo.reorderExercises(entries.reversed.toList());

    entries = await repo.watchExercisesForWorkout(workoutId).first;
    expect(entries.map((e) => e.targetSets), [4, 3]);
  });

  test(
    'duplicating a workout updates the parent updatedAt independently',
    () async {
      final workoutId = await repo.createWorkout(name: 'Original');
      final exerciseId = await firstExerciseId();
      await repo.addExerciseToWorkout(
        workoutId: workoutId,
        exerciseId: exerciseId,
        orderIndex: 0,
        targetSets: 5,
      );

      final copyId = await repo.duplicateWorkout(
        workoutId,
        newName: 'Original (cópia)',
      );
      expect(copyId, isNot(workoutId));

      final copyEntries = await repo.watchExercisesForWorkout(copyId).first;
      expect(copyEntries, hasLength(1));
      expect(copyEntries.first.targetSets, 5);
    },
  );

  test('deletes a workout', () async {
    final workoutId = await repo.createWorkout(name: 'A excluir');
    await repo.deleteWorkout(workoutId);
    expect(await repo.getWorkoutById(workoutId), isNull);
  });
}
