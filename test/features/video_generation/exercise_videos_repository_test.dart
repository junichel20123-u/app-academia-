import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/video_generation/data/exercise_videos_repository.dart';
import 'package:app_academia/features/video_generation/data/mock_video_generation_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_file_storage_service.dart';

void main() {
  late AppDatabase db;
  late Exercise exercise;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    exercise = (await db.exercisesDao.getAllExercises()).first;
  });
  tearDown(() => db.close());

  test('generate() polls until ready and saves a file', () async {
    final repo = ExerciseVideosRepository(
      db,
      MockVideoGenerationProvider(
        generationDelay: const Duration(milliseconds: 30),
      ),
      fileStorage: FakeFileStorageService(),
      pollInterval: const Duration(milliseconds: 10),
    );

    await repo.generate(exercise);

    final latest = await db.exercisesDao.getLatestVideoForExercise(exercise.id);
    expect(latest!.status, ExerciseVideoStatus.ready);
    expect(latest.localFilePath, isNotNull);
    expect(latest.completedAt, isNotNull);
  });

  test('generate() marks failed when the provider reports failure', () async {
    final repo = ExerciseVideosRepository(
      db,
      MockVideoGenerationProvider(
        alwaysFail: true,
        generationDelay: const Duration(milliseconds: 20),
      ),
      fileStorage: FakeFileStorageService(),
      pollInterval: const Duration(milliseconds: 10),
    );

    await repo.generate(exercise);

    final latest = await db.exercisesDao.getLatestVideoForExercise(exercise.id);
    expect(latest!.status, ExerciseVideoStatus.failed);
    expect(latest.errorMessage, isNotNull);
  });

  test('regenerating deletes the previously cached file', () async {
    final fileStorage = FakeFileStorageService();
    final repo = ExerciseVideosRepository(
      db,
      MockVideoGenerationProvider(
        generationDelay: const Duration(milliseconds: 10),
      ),
      fileStorage: fileStorage,
      pollInterval: const Duration(milliseconds: 5),
    );

    await repo.generate(exercise);
    final firstPath = (await db.exercisesDao.getLatestVideoForExercise(
      exercise.id,
    ))!.localFilePath;

    await repo.generate(exercise);

    expect(fileStorage.deletedPaths, contains(firstPath));
  });

  test('resumePendingGeneration finishes a job left mid-generation '
      '(e.g. after the app was killed and relaunched)', () async {
    final repo = ExerciseVideosRepository(
      db,
      MockVideoGenerationProvider(
        generationDelay: const Duration(milliseconds: 10),
      ),
      fileStorage: FakeFileStorageService(),
      pollInterval: const Duration(milliseconds: 5),
    );

    final staleJobId =
        'mock-${DateTime.now().subtract(const Duration(seconds: 5)).millisecondsSinceEpoch}';
    await db.exercisesDao.insertVideoAttempt(
      ExerciseVideosCompanion.insert(
        exerciseId: exercise.id,
        providerId: 'mock',
        status: ExerciseVideoStatus.generating,
        jobId: const Value('placeholder'), // overwritten just below via update
      ),
    );
    final inserted = await db.exercisesDao.getLatestVideoForExercise(
      exercise.id,
    );
    await db.exercisesDao.updateVideoAttempt(
      inserted!.copyWith(jobId: Value(staleJobId)),
    );

    await repo.resumePendingGeneration(exercise.id);

    final latest = await db.exercisesDao.getLatestVideoForExercise(exercise.id);
    expect(latest!.status, ExerciseVideoStatus.ready);
  });

  test('resumePendingGeneration is a no-op when nothing is pending', () async {
    final repo = ExerciseVideosRepository(
      db,
      MockVideoGenerationProvider(),
      fileStorage: FakeFileStorageService(),
    );

    await repo.resumePendingGeneration(exercise.id);

    expect(
      await db.exercisesDao.getLatestVideoForExercise(exercise.id),
      isNull,
    );
  });

  test('times out and marks failed if the job never settles in time', () async {
    final repo = ExerciseVideosRepository(
      db,
      MockVideoGenerationProvider(
        generationDelay: const Duration(seconds: 999),
      ),
      fileStorage: FakeFileStorageService(),
      pollInterval: const Duration(milliseconds: 5),
      timeout: const Duration(milliseconds: 30),
    );

    await repo.generate(exercise);

    final latest = await db.exercisesDao.getLatestVideoForExercise(exercise.id);
    expect(latest!.status, ExerciseVideoStatus.failed);
    expect(latest.errorMessage, contains('esgotado'));
  });
}
