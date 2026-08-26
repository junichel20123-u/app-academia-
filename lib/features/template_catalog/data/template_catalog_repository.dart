import '../../../core/database/app_database.dart';
import '../../../core/database/daos/workouts_dao.dart';
import '../../../core/supabase/supabase_rest_client.dart';
import '../domain/catalog_template.dart';

/// Outcome of copying a whole template's days into local workouts.
class CopyTemplateResult {
  const CopyTemplateResult({
    required this.createdWorkoutIds,
    required this.unresolvedSlugs,
  });

  final List<int> createdWorkoutIds;
  final List<String> unresolvedSlugs;

  bool get hasUnresolved => unresolvedSlugs.isNotEmpty;
}

class TemplateCatalogRepository {
  TemplateCatalogRepository(
    this._db, {
    SupabaseRestClient? restClient,
    // Keeps the public param name `restClient` distinct from `_restClient`.
    // ignore: prefer_initializing_formals
  }) : _restClient = restClient;

  final AppDatabase _db;
  final SupabaseRestClient? _restClient;

  Stream<List<CatalogTemplate>> watchAllTemplates() =>
      _db.catalogTemplatesDao.watchAllTemplates();

  Future<CatalogTemplate?> getBySlug(String slug) =>
      _db.catalogTemplatesDao.getBySlug(slug);

  /// Fetches the latest catalog from Supabase and replaces the local cache.
  /// A no-op when the build has no `SUPABASE_URL`/`SUPABASE_ANON_KEY`
  /// (`--dart-define`) — the app stays fully usable offline/local-only,
  /// just without an online catalog. Network/parsing errors propagate to
  /// the caller, which keeps showing whatever is already cached.
  Future<void> sync() async {
    final client = _restClient;
    if (client == null) return;
    final raw = await client.fetchTemplatePrograms();
    final entries = parseSupabaseTemplatesResponse(raw);
    await _db.catalogTemplatesDao.replaceAll(entries);
  }

  /// Copies every day of [template] into a new local `Workout`. An
  /// `exerciseSlug` this install doesn't have (e.g. added to the catalog
  /// after this install last synced its own exercise library) is skipped,
  /// not fatal — curated, free content shouldn't fail entirely over one
  /// stale exercise. A day left with no resolvable exercises isn't created.
  Future<CopyTemplateResult> copyTemplateToMyWorkouts(
    CatalogTemplate template,
  ) async {
    final workouts = parseCatalogWorkouts(template.payloadJson);
    final createdWorkoutIds = <int>[];
    final unresolvedSlugs = <String>[];

    for (final workout in workouts) {
      final resolvedEntries = <WorkoutExerciseEntry>[];
      var orderIndex = 0;
      for (final exercise in workout.exercises) {
        final localExercise = await _db.exercisesDao.getExerciseBySlug(
          exercise.exerciseSlug,
        );
        if (localExercise == null) {
          unresolvedSlugs.add(exercise.exerciseSlug);
          continue;
        }
        resolvedEntries.add(
          WorkoutExerciseEntry(
            exerciseId: localExercise.id,
            orderIndex: orderIndex++,
            targetSets: exercise.targetSets,
            targetReps: exercise.targetReps,
            targetRestSeconds: exercise.targetRestSeconds,
            notes: exercise.notes,
          ),
        );
      }
      if (resolvedEntries.isEmpty) continue;
      final workoutId = await _db.workoutsDao.createWorkoutWithExercises(
        name: '${template.name} — ${workout.name}',
        entries: resolvedEntries,
      );
      createdWorkoutIds.add(workoutId);
    }

    return CopyTemplateResult(
      createdWorkoutIds: createdWorkoutIds,
      unresolvedSlugs: unresolvedSlugs,
    );
  }
}
