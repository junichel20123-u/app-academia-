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
    // Keeps the public param name `fileStorage` distinct from `_fileStorage`.
    // ignore: prefer_initializing_formals
  }) : _fileStorage = fileStorage;

  final AppDatabase _db;
  final VideoGenerationProvider _provider;
  final FileStorageService _fileStorage;
  final Duration pollInterval;
  final Duration timeout;

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

    final job = await _provider.requestGeneration(exercise: exercise);
    final row = await _db.exercisesDao.getVideoAttemptById(rowId);
    if (row == null) return;
    await _db.exercisesDao.updateVideoAttempt(
      row.copyWith(jobId: Value(job.jobId)),
    );

    await _pollUntilDone(rowId, exercise.id);
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
