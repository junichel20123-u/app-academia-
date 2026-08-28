import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../../core/storage/file_storage_service.dart';
import '../domain/video_generation_provider.dart';

class ExerciseVideosRepository {
  ExerciseVideosRepository(
    this._db,
    this._provider, {
    FileStorageService fileStorage = const FileStorageService(),
    this.pollInterval = const Duration(seconds: 1),
    this.timeout = const Duration(seconds: 30),
    this.cacheSizeCapBytes = 500 * 1024 * 1024,
    // Keeps the public param name `fileStorage` distinct from `_fileStorage`.
    // ignore: prefer_initializing_formals
  }) : _fileStorage = fileStorage;

  final AppDatabase _db;
  final VideoGenerationProvider _provider;
  final FileStorageService _fileStorage;
  final Duration pollInterval;
  final Duration timeout;

  /// Once the cache exceeds this many bytes, the oldest `ready` videos are
  /// evicted (file deleted, row reset to `idle`) until back under the cap —
  /// checked opportunistically after each successful `generate()`, not on
  /// a schedule. 500MB default: generous enough that a normal user never
  /// notices it, small enough to bound worst-case storage growth.
  final int cacheSizeCapBytes;

  Stream<ExerciseVideo?> watchLatestVideo(int exerciseId) =>
      _db.exercisesDao.watchLatestVideoForExercise(exerciseId);

  /// Starts a new generation attempt for [exercise], deleting any
  /// previously cached video file first ("regenerate" replaces, not
  /// accumulates), then polls until the job settles.
  Future<void> generate(Exercise exercise) async {
    final previous = await _db.exercisesDao.getLatestVideoForExercise(
      exercise.id,
    );
    if (previous?.localFilePath != null) {
      await _fileStorage.deleteIfExists(previous!.localFilePath!);
    }

    final rowId = await _db.exercisesDao.insertVideoAttempt(
      ExerciseVideosCompanion.insert(
        exerciseId: exercise.id,
        providerId: _provider.providerId,
        status: ExerciseVideoStatus.generating,
      ),
    );

    // Every provider can throw here (a bad custom endpoint, an expired
    // Runway key, a network error) — without this catch, the row above is
    // left at `generating` forever, since nothing downstream of the throw
    // ever runs to mark it `failed`. This affects every provider equally,
    // not just one adapter's own internal error handling.
    final VideoGenerationJob job;
    try {
      job = await _provider.requestGeneration(exercise: exercise);
    } catch (error) {
      final row = await _db.exercisesDao.getVideoAttemptById(rowId);
      if (row != null) {
        await _db.exercisesDao.updateVideoAttempt(
          row.copyWith(
            status: ExerciseVideoStatus.failed,
            errorMessage: Value(_describeFailure(error)),
          ),
        );
      }
      return;
    }

    final row = await _db.exercisesDao.getVideoAttemptById(rowId);
    if (row == null) return;
    await _db.exercisesDao.updateVideoAttempt(
      row.copyWith(jobId: Value(job.jobId)),
    );

    await _pollUntilDone(rowId, exercise.id);
  }

  /// Total size, in bytes, of every cached exercise video on disk — shown
  /// in Settings alongside the "Limpar cache" action.
  Future<int> cacheSizeBytes() => _fileStorage.cacheSizeBytes();

  /// Deletes every cached video file and resets the DB rows that reference
  /// them back to `idle` — the two always go together so the database and
  /// filesystem never disagree about what's cached.
  Future<void> clearVideoCache() async {
    await _fileStorage.clearCache();
    await _db.exercisesDao.clearAllVideoCacheRows();
  }

  /// Deletes any cached file on disk that no DB row references — e.g. a
  /// file fully written right before the app was killed, just before the
  /// row's `localFilePath` got updated to point at it. Safe to call
  /// unconditionally (e.g. once at app boot); a no-op when there's nothing
  /// to sweep.
  Future<void> sweepOrphanFiles() async {
    final knownPaths = await _db.exercisesDao.getAllLocalFilePaths();
    await _fileStorage.sweepOrphans(knownPaths.toSet());
  }

  /// Evicts the oldest `ready` videos (file + row) until the cache is back
  /// under [cacheSizeCapBytes]. Called opportunistically after a
  /// successful generation, never on its own schedule.
  Future<void> _enforceCacheSizeCap() async {
    if (await _fileStorage.cacheSizeBytes() <= cacheSizeCapBytes) return;

    final oldestFirst = await _db.exercisesDao.getReadyVideosOldestFirst();
    for (final row in oldestFirst) {
      await _fileStorage.deleteIfExists(row.localFilePath!);
      await _db.exercisesDao.updateVideoAttempt(
        row.copyWith(
          localFilePath: const Value(null),
          status: ExerciseVideoStatus.idle,
        ),
      );
      if (await _fileStorage.cacheSizeBytes() <= cacheSizeCapBytes) return;
    }
  }

  /// A [StateError] (what every provider already throws for a sanitized
  /// failure — see `RunwayVideoGenerationProvider`/`HttpJobBasedProvider`)
  /// carries its own user-facing message; anything else falls back to a
  /// generic message rather than ever surfacing a raw exception's text.
  String _describeFailure(Object error) {
    if (error is StateError) return error.message;
    return 'Falha ao gerar o vídeo.';
  }

  /// Resumes polling a video attempt left mid-generation — e.g. because the
  /// app was killed and relaunched. Safe to call unconditionally: it's a
  /// no-op if there's nothing pending.
  Future<void> resumePendingGeneration(int exerciseId) async {
    final latest = await _db.exercisesDao.getLatestVideoForExercise(exerciseId);
    if (latest != null &&
        latest.status == ExerciseVideoStatus.generating &&
        latest.jobId != null) {
      await _pollUntilDone(latest.id, exerciseId);
    }
  }

  Future<void> _pollUntilDone(int rowId, int exerciseId) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final row = await _db.exercisesDao.getVideoAttemptById(rowId);
      if (row == null || row.status != ExerciseVideoStatus.generating) return;

      final status = await _provider.checkStatus(jobId: row.jobId!);

      switch (status.kind) {
        case VideoJobStatusKind.pending:
          if (DateTime.now().isAfter(deadline)) {
            await _db.exercisesDao.updateVideoAttempt(
              row.copyWith(
                status: ExerciseVideoStatus.failed,
                errorMessage: const Value('Tempo esgotado ao gerar o vídeo.'),
              ),
            );
            return;
          }
          await Future<void>.delayed(pollInterval);
        case VideoJobStatusKind.ready:
          final bytes = await _provider.fetchResult(
            resultUrl: status.resultUrl!,
          );
          final path = await _fileStorage.saveExerciseVideo(
            exerciseId: exerciseId,
            bytes: bytes,
          );
          await _db.exercisesDao.updateVideoAttempt(
            row.copyWith(
              localFilePath: Value(path),
              status: ExerciseVideoStatus.ready,
              completedAt: Value(DateTime.now()),
            ),
          );
          await _enforceCacheSizeCap();
          return;
        case VideoJobStatusKind.failed:
          await _db.exercisesDao.updateVideoAttempt(
            row.copyWith(
              status: ExerciseVideoStatus.failed,
              errorMessage: Value(
                status.errorMessage ?? 'Falha ao gerar o vídeo.',
              ),
            ),
          );
          return;
      }
    }
  }
}
