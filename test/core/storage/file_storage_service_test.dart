import 'dart:io';

import 'package:app_academia/core/storage/file_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late FileStorageService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exercise_videos_test');
    service = FileStorageService(cacheDirectoryOverride: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('cacheSizeBytes is 0 for an empty/nonexistent cache dir', () async {
    expect(await service.cacheSizeBytes(), 0);
  });

  test(
    'cacheSizeBytes sums every cached file, across subdirectories',
    () async {
      await service.saveExerciseVideo(exerciseId: 1, bytes: List.filled(10, 0));
      await service.saveExerciseVideo(exerciseId: 2, bytes: List.filled(20, 0));

      expect(await service.cacheSizeBytes(), 30);
    },
  );

  test('clearCache removes the whole cache directory', () async {
    await service.saveExerciseVideo(exerciseId: 1, bytes: List.filled(5, 0));
    expect(await service.cacheSizeBytes(), 5);

    await service.clearCache();

    expect(await service.cacheSizeBytes(), 0);
    expect(await tempDir.exists(), isFalse);
  });

  test(
    'sweepOrphans deletes files not in knownPaths, keeps the rest',
    () async {
      final keptPath = await service.saveExerciseVideo(
        exerciseId: 1,
        bytes: List.filled(5, 0),
      );
      final orphanPath = await service.saveExerciseVideo(
        exerciseId: 2,
        bytes: List.filled(5, 0),
      );

      await service.sweepOrphans({keptPath});

      expect(await File(keptPath).exists(), isTrue);
      expect(await File(orphanPath).exists(), isFalse);
    },
  );
}
