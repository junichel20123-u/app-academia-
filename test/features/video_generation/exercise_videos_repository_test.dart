import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/storage/file_storage_service.dart';
import 'package:app_academia/features/video_generation/data/exercise_videos_repository.dart';
import 'package:app_academia/features/video_generation/data/mock_video_generation_provider.dart';
import 'package:app_academia/features/video_generation/domain/video_generation_provider.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_file_storage_service.dart';

/// Simulates a provider whose `requestGeneration` itself throws — e.g. a
/// misconfigured custom endpoint or an expired Runway key — to prove
/// `generate()` never leaves the DB row stuck at `generating`.
class _RequestGenerationThrowsProvider implements VideoGenerationProvider {
  @override
  String get providerId => 'throws';

  @override
  String get displayName => 'Throws';

  @override
  Future<VideoGenerationJob> requestGeneration({
    required Exercise exercise,
    Map<String, String>? credentials,
  }) {
    throw StateError('Chave de API inválida.');
  }

  @override
  Future<VideoJobStatus> checkStatus({
    required String jobId,
    Map<String, String>? credentials,
  }) async => const VideoJobStatus(kind: VideoJobStatusKind.pending);

  @override
  Future<List<int>> fetchResult({
    required String resultUrl,
    Map<String, String>? credentials,
  }) async => const [];

  @override
  bool validateCredentials(Map<String, String>? credentials) => true;
}

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

  test('generate() marks the row failed when requestGeneration itself throws '
      '(never leaves it stuck at generating)', () async {
    final repo = ExerciseVideosRepository(
      db,
      _RequestGenerationThrowsProvider(),
      fileStorage: FakeFileStorageService(),
    );

    await repo.generate(exercise);

    final latest = await db.exercisesDao.getLatestVideoForExercise(exercise.id);
    expect(latest!.status, ExerciseVideoStatus.failed);
    expect(latest.errorMessage, 'Chave de API inválida.');
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

  test(
    'clearVideoCache clears cached files and resets DB rows to idle',
    () async {
      final fileStorage = FakeFileStorageService();
      final repo = ExerciseVideosRepository(
        db,
        MockVideoGenerationProvider(generationDelay: Duration.zero),
        fileStorage: fileStorage,
        pollInterval: Duration.zero,
      );

      await repo.generate(exercise);
      expect(
        (await db.exercisesDao.getLatestVideoForExercise(exercise.id))!.status,
        ExerciseVideoStatus.ready,
      );

      await repo.clearVideoCache();

      expect(fileStorage.cacheCleared, isTrue);
      final row = await db.exercisesDao.getLatestVideoForExercise(exercise.id);
      expect(row!.status, ExerciseVideoStatus.idle);
      expect(row.localFilePath, isNull);
    },
  );

  group('cache size cap (real filesystem, temp dir)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cache_cap_test');
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test(
      'evicts the oldest ready video once the cache exceeds the cap',
      () async {
        final exercises = await db.exercisesDao.getAllExercises();
        final exerciseA = exercises[0];
        final exerciseB = exercises[1];
        // MockVideoGenerationProvider.fetchResult always returns 256 bytes
        // (see mock_video_generation_provider.dart) — a cap of 300 means a
        // single cached video fits, but a second one pushes the total over.
        final repo = ExerciseVideosRepository(
          db,
          MockVideoGenerationProvider(generationDelay: Duration.zero),
          fileStorage: FileStorageService(cacheDirectoryOverride: tempDir),
          pollInterval: Duration.zero,
          cacheSizeCapBytes: 300,
        );

        await repo.generate(exerciseA);
        final rowA = await db.exercisesDao.getLatestVideoForExercise(
          exerciseA.id,
        );
        expect(rowA!.status, ExerciseVideoStatus.ready);

        await repo.generate(exerciseB);

        final rowAAfter = await db.exercisesDao.getLatestVideoForExercise(
          exerciseA.id,
        );
        final rowBAfter = await db.exercisesDao.getLatestVideoForExercise(
          exerciseB.id,
        );
        // A was oldest, so it's the one evicted; B (just generated) stays.
        expect(rowAAfter!.status, ExerciseVideoStatus.idle);
        expect(rowAAfter.localFilePath, isNull);
        expect(rowBAfter!.status, ExerciseVideoStatus.ready);
        expect(rowBAfter.localFilePath, isNotNull);
      },
    );
  });

  test(
    'sweepOrphanFiles removes a file no row references, keeps the rest',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'sweep_orphan_test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final fileStorage = FileStorageService(cacheDirectoryOverride: tempDir);
      final repo = ExerciseVideosRepository(
        db,
        MockVideoGenerationProvider(generationDelay: Duration.zero),
        fileStorage: fileStorage,
        pollInterval: Duration.zero,
      );

      await repo.generate(exercise);
      final knownPath = (await db.exercisesDao.getLatestVideoForExercise(
        exercise.id,
      ))!.localFilePath!;
      // A file on disk with no DB row referencing it at all.
      final orphanFile = File('${tempDir.path}/orphan.mp4');
      await orphanFile.writeAsBytes([1, 2, 3]);

      await repo.sweepOrphanFiles();

      expect(await File(knownPath).exists(), isTrue);
      expect(await orphanFile.exists(), isFalse);
    },
  );
}
