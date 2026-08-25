import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Saves generated exercise videos under the app's documents directory.
/// Not `final` so tests can subclass and override without touching disk.
class FileStorageService {
  const FileStorageService();

  Future<String> saveExerciseVideo({
    required int exerciseId,
    required List<int> bytes,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
      p.join(docsDir.path, 'exercise_videos', exerciseId.toString()),
    );
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
}
