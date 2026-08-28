import 'package:app_academia/core/storage/file_storage_service.dart';

/// Avoids touching the real filesystem (and the `path_provider` platform
/// channel, unavailable in tests) when exercising video-generation code.
class FakeFileStorageService extends FileStorageService {
  final List<String> deletedPaths = [];
  bool cacheCleared = false;
  int _counter = 0;

  @override
  Future<String> saveExerciseVideo({
    required int exerciseId,
    required List<int> bytes,
  }) async {
    return '/fake/exercise_videos/$exerciseId/${_counter++}.mp4';
  }

  @override
  Future<void> deleteIfExists(String path) async {
    deletedPaths.add(path);
  }

  @override
  Future<int> cacheSizeBytes() async => 0;

  @override
  Future<void> clearCache() async {
    cacheCleared = true;
  }

  @override
  Future<void> sweepOrphans(Set<String> knownPaths) async {}
}
