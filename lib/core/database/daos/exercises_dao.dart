import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exercise_videos_table.dart';
import '../tables/exercises_table.dart';

part 'exercises_dao.g.dart';

@DriftAccessor(tables: [Exercises, ExerciseVideos])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  Future<List<Exercise>> getAllExercises() => select(exercises).get();

  Stream<List<Exercise>> watchAllExercises() => select(exercises).watch();

  Future<Exercise?> getExerciseById(int id) =>
      (select(exercises)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Resolves a catalog/server exercise reference to the local row with the
  /// same stable slug — null if this install doesn't have it (e.g. the
  /// catalog references an exercise added to the seed after this install).
  Future<Exercise?> getExerciseBySlug(String slug) =>
      (select(exercises)..where((t) => t.slug.equals(slug))).getSingleOrNull();

  Future<int> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry);

  Future<bool> updateExercise(Exercise entry) =>
      update(exercises).replace(entry);

  Future<int> deleteExercise(int id) =>
      (delete(exercises)..where((t) => t.id.equals(id))).go();

  /// Latest video attempt for an exercise (highest id = most recent), if any.
  Future<ExerciseVideo?> getLatestVideoForExercise(int exerciseId) {
    final query = select(exerciseVideos)
      ..where((t) => t.exerciseId.equals(exerciseId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Stream<ExerciseVideo?> watchLatestVideoForExercise(int exerciseId) {
    final query = select(exerciseVideos)
      ..where((t) => t.exerciseId.equals(exerciseId))
      ..orderBy([(t) => OrderingTerm.desc(t.id)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<ExerciseVideo?> getVideoAttemptById(int id) =>
      (select(exerciseVideos)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertVideoAttempt(ExerciseVideosCompanion entry) =>
      into(exerciseVideos).insert(entry);

  Future<bool> updateVideoAttempt(ExerciseVideo entry) =>
      update(exerciseVideos).replace(entry);
}
