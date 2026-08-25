import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('seeds the starter exercise library on first open', () async {
    final all = await db.exercisesDao.getAllExercises();
    expect(all.length, seedExercises.length);
    expect(all.every((e) => !e.isCustom), isTrue);
  });

  test('inserts, updates and deletes a custom exercise', () async {
    final id = await db.exercisesDao.insertExercise(
      ExercisesCompanion.insert(
        name: 'Exercício customizado',
        muscleGroup: MuscleGroup.core,
        isCustom: const Value(true),
      ),
    );

    final inserted = await db.exercisesDao.getExerciseById(id);
    expect(inserted!.name, 'Exercício customizado');
    expect(inserted.isCustom, isTrue);

    await db.exercisesDao.updateExercise(
      inserted.copyWith(name: 'Nome atualizado'),
    );
    final updated = await db.exercisesDao.getExerciseById(id);
    expect(updated!.name, 'Nome atualizado');

    await db.exercisesDao.deleteExercise(id);
    expect(await db.exercisesDao.getExerciseById(id), isNull);
  });

  test('tracks the latest video attempt per exercise', () async {
    final exercises = await db.exercisesDao.getAllExercises();
    final exerciseId = exercises.first.id;

    expect(await db.exercisesDao.getLatestVideoForExercise(exerciseId), isNull);

    await db.exercisesDao.insertVideoAttempt(
      ExerciseVideosCompanion.insert(
        exerciseId: exerciseId,
        providerId: 'mock',
        status: ExerciseVideoStatus.generating,
      ),
    );
    final secondId = await db.exercisesDao.insertVideoAttempt(
      ExerciseVideosCompanion.insert(
        exerciseId: exerciseId,
        providerId: 'mock',
        status: ExerciseVideoStatus.ready,
        localFilePath: const Value('/tmp/video.mp4'),
      ),
    );

    final latest = await db.exercisesDao.getLatestVideoForExercise(exerciseId);
    expect(latest!.id, secondId);
    expect(latest.status, ExerciseVideoStatus.ready);
  });
}
