import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:app_academia/core/utils/slugify.dart';
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

  test('seeded exercises get a stable slug derived from their name', () async {
    final all = await db.exercisesDao.getAllExercises();
    for (final exercise in all) {
      expect(exercise.slug, slugify(exercise.name));
    }
  });

  test('getExerciseBySlug resolves a seeded exercise by its slug', () async {
    final all = await db.exercisesDao.getAllExercises();
    final expected = all.first;

    final resolved = await db.exercisesDao.getExerciseBySlug(expected.slug!);

    expect(resolved!.id, expected.id);
  });

  test('getExerciseBySlug returns null for an unknown slug', () async {
    expect(
      await db.exercisesDao.getExerciseBySlug('not-a-real-exercise'),
      isNull,
    );
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
    // Custom exercises are personal and never addressable by a server/LLM.
    expect(inserted.slug, isNull);

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
