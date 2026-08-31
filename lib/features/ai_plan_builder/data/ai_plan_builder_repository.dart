import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/workouts_dao.dart';
import '../../../core/database/enums.dart';
import '../domain/generated_plan.dart';

/// Thrown when a generated plan references an exercise slug this install
/// doesn't have. Unlike the free, curated template catalog (which skips one
/// bad entry and warns), an AI plan is generated on demand — a structural
/// failure should be visible, not silently patched over, so the whole plan
/// is rejected.
class UnresolvedPlanExercisesException implements Exception {
  const UnresolvedPlanExercisesException(this.slugs);

  final List<String> slugs;

  @override
  String toString() => 'UnresolvedPlanExercisesException(${slugs.join(', ')})';
}

/// Exercises the AI is allowed to choose from: only those with a stable
/// slug (seeded/catalog exercises — never a user's custom ones, which have
/// no slug and aren't addressable by the server/AI), filtered to what the
/// user says they have access to. An exercise with no equipment
/// requirement (bodyweight-style) is always eligible.
List<Exercise> filterEligibleExercises(
  List<Exercise> allExercises,
  Set<Equipment> availableEquipment,
) {
  return allExercises.where((exercise) {
    if (exercise.slug == null) return false;
    final required = exercise.equipment;
    return required == null || availableEquipment.contains(required);
  }).toList();
}

/// Every `exerciseSlug` in [workouts] that isn't in [knownSlugs].
List<String> findUnresolvedSlugs(
  List<GeneratedPlanWorkout> workouts,
  Set<String> knownSlugs,
) {
  final unresolved = <String>{};
  for (final workout in workouts) {
    for (final exercise in workout.exercises) {
      if (!knownSlugs.contains(exercise.exerciseSlug)) {
        unresolved.add(exercise.exerciseSlug);
      }
    }
  }
  return unresolved.toList();
}

class AiPlanBuilderRepository {
  AiPlanBuilderRepository(
    this._db, {
    String? supabaseUrl,
    String? supabaseAnonKey,
    Dio? dio,
    // Keeps the public param names `supabaseUrl`/`supabaseAnonKey` distinct
    // from `_supabaseUrl`/`_supabaseAnonKey`.
    // ignore: prefer_initializing_formals
  }) : _supabaseUrl = supabaseUrl,
       // ignore: prefer_initializing_formals
       _supabaseAnonKey = supabaseAnonKey,
       // A plain `Dio()` has no timeout at all — a hung request would
       // leave the button spinning forever with no error ever shown.
       // `receiveTimeout` stays a bit above the Edge Function's own Gemini
       // timeout (60s, see gemini_text_generation_provider.ts) so the
       // server's timeout is normally what fires first and the user gets a
       // real error code instead of a generic client-side one; this is the
       // backstop for when the response never arrives at all.
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 65),
             ),
           );

  final AppDatabase _db;
  final String? _supabaseUrl;
  final String? _supabaseAnonKey;
  final Dio _dio;

  Future<bool> isPremiumUnlocked() async {
    final settings = await _db.userSettingsDao.getSettings();
    return settings.aiPlanBuilderPremiumUnlocked;
  }

  /// Calls the `generate-plan` Edge Function and returns the generated
  /// days. Throws [StateError] if the build has no Supabase config, or if
  /// no local exercise matches the requested equipment; throws
  /// [UnresolvedPlanExercisesException] if the AI still referenced a slug
  /// outside the list it was given (shouldn't happen — the Edge Function
  /// constrains generation to a closed enum of the sent slugs — but this is
  /// the client-side safety net either way).
  Future<List<GeneratedPlanWorkout>> generatePlan({
    required String goal,
    required int daysPerWeek,
    required String experienceLevel,
    required Set<Equipment> availableEquipment,
  }) async {
    final url = _supabaseUrl;
    final apiKey = _supabaseAnonKey;
    if (url == null || apiKey == null) {
      throw StateError(
        'O montador de plano por IA não está configurado nesta build.',
      );
    }

    final allExercises = await _db.exercisesDao.getAllExercises();
    final eligible = filterEligibleExercises(allExercises, availableEquipment);
    if (eligible.isEmpty) {
      throw StateError(
        'Nenhum exercício disponível para o equipamento selecionado.',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '$url/functions/v1/generate-plan',
      data: {
        'goal': goal,
        'daysPerWeek': daysPerWeek,
        'experienceLevel': experienceLevel,
        'availableEquipment': availableEquipment.map((e) => e.name).toList(),
        'exercises': [
          for (final exercise in eligible)
            {
              'slug': exercise.slug,
              'name': exercise.name,
              'muscleGroup': exercise.muscleGroup.name,
              'equipment': exercise.equipment?.name,
            },
        ],
      },
      options: Options(
        headers: {'apikey': apiKey, 'Authorization': 'Bearer $apiKey'},
      ),
    );

    final workouts = parseGeneratedPlanResponse(response.data!);
    final knownSlugs = eligible.map((e) => e.slug!).toSet();
    final unresolved = findUnresolvedSlugs(workouts, knownSlugs);
    if (unresolved.isNotEmpty) {
      throw UnresolvedPlanExercisesException(unresolved);
    }

    return workouts;
  }

  /// Imports every day of an already-validated plan as a new local
  /// `Workout`. Only call this with a plan that already passed
  /// [generatePlan]'s slug check.
  Future<List<int>> importPlan(
    List<GeneratedPlanWorkout> workouts, {
    required String planName,
  }) async {
    final createdWorkoutIds = <int>[];
    for (final workout in workouts) {
      final entries = <WorkoutExerciseEntry>[];
      var orderIndex = 0;
      for (final exercise in workout.exercises) {
        final localExercise = await _db.exercisesDao.getExerciseBySlug(
          exercise.exerciseSlug,
        );
        if (localExercise == null) {
          throw UnresolvedPlanExercisesException([exercise.exerciseSlug]);
        }
        entries.add(
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
      final workoutId = await _db.workoutsDao.createWorkoutWithExercises(
        name: '$planName — ${workout.name}',
        entries: entries,
      );
      createdWorkoutIds.add(workoutId);
    }
    return createdWorkoutIds;
  }
}
