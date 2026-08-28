import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Saves generated exercise videos under the app's documents directory.
/// Not `final` so tests can subclass and override without touching disk.
class FileStorageService {
  /// [cacheDirectoryOverride], when given, is used instead of
  /// `<app documents dir>/exercise_videos` for every method below — lets
  /// tests exercise real filesystem behavior (size, deletion, orphan sweep)
  /// against a temp directory without touching `path_provider`'s platform
  /// channel, which plain `flutter_test` can't reach.
  const FileStorageService({
    Directory? cacheDirectoryOverride,
    // Keeps the public param name distinct from the private field.
    // ignore: prefer_initializing_formals
  }) : _cacheDirectoryOverride = cacheDirectoryOverride;

  final Directory? _cacheDirectoryOverride;

  Future<String> saveExerciseVideo({
    required int exerciseId,
    required List<int> bytes,
  }) async {
    final cacheDir = await _cacheDir();
    final dir = Directory(p.join(cacheDir.path, exerciseId.toString()));
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, '${const Uuid().v4()}.mp4'));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _cacheDir() async {
    final override = _cacheDirectoryOverride;
    if (override != null) return override;
    final docsDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docsDir.path, 'exercise_videos'));
  }

  /// Total size, in bytes, of every cached exercise video on disk.
  Future<int> cacheSizeBytes() async {
    final dir = await _cacheDir();
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  /// Deletes the entire video-cache directory. Always call this together
  /// with resetting the DB rows that reference it (see
  /// `ExerciseVideosRepository.clearVideoCache`) — never in isolation, or
  /// `ExerciseVideos.localFilePath` would point at files that no longer
  /// exist.
  Future<void> clearCache() async {
    final dir = await _cacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Deletes any cached video file whose path isn't in [knownPaths] — e.g.
  /// a file written to disk right before the app was killed, just before
  /// the DB row was updated with its path, and so is now referenced by
  /// nothing. Safe to call anytime; never touches a path present in
  /// [knownPaths].
  Future<void> sweepOrphans(Set<String> knownPaths) async {
    final dir = await _cacheDir();
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && !knownPaths.contains(entity.path)) {
        await entity.delete();
      }
    }
  }
}
