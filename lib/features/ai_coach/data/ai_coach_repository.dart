import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../ai_plan_builder/data/ai_plan_builder_repository.dart';
import '../../ai_plan_builder/domain/generated_plan.dart';
import '../domain/chat_message.dart';
import '../domain/coach_context.dart';
import '../domain/workout_adjustment.dart';

class AiCoachRepository {
  AiCoachRepository(
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
       // Same timeout convention as AiPlanBuilderRepository: a bit above the
       // Edge Function's own 30s Gemini timeout, as a backstop for a
       // response that never arrives at all.
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 35),
             ),
           );

  final AppDatabase _db;
  final String? _supabaseUrl;
  final String? _supabaseAnonKey;
  final Dio _dio;

  // Reuses the same premium flag as the plan builder — see the app's
  // Settings screen, where the "Modo de teste" switch unlocks both AI
  // features together.
  Future<bool> isPremiumUnlocked() async {
    final settings = await _db.userSettingsDao.getSettings();
    return settings.aiPlanBuilderPremiumUnlocked;
  }

  /// Builds the auto-detected context (goal/level as given, plus
  /// sedentarismo and peso computed from local data) sent with every coach
  /// request — see [CoachContext].
  Future<CoachContext> buildContext({
    String? goal,
    String? experienceLevel,
  }) async {
    final completedSessions = await _db.sessionsDao.getCompletedSessions();
    final activeCutoff = DateTime.now().subtract(const Duration(days: 14));
    final sedentary = !completedSessions.any(
      (session) =>
          (session.completedAt ?? session.startedAt).isAfter(activeCutoff),
    );

    final weighIns = await _db.weighInsDao.watchAllWeighIns().first;
    double? latestWeightKg;
    WeightTrend? weightTrend;
    if (weighIns.isNotEmpty) {
      latestWeightKg = weighIns.first.weightKg;
      if (weighIns.length > 1) {
        // Picks whichever earlier weigh-in is closest to "30 days before
        // the latest one" as the trend baseline — works whether the user
        // has months of dense data or just two entries a few days apart.
        final targetDate = weighIns.first.occurredAt.subtract(
          const Duration(days: 30),
        );
        var baseline = weighIns.last;
        var bestDiff = baseline.occurredAt.difference(targetDate).abs();
        for (final weighIn in weighIns.skip(1)) {
          final diff = weighIn.occurredAt.difference(targetDate).abs();
          if (diff < bestDiff) {
            baseline = weighIn;
            bestDiff = diff;
          }
        }
        final delta = latestWeightKg - baseline.weightKg;
        weightTrend = delta.abs() < 0.5
            ? WeightTrend.stable
            : (delta > 0 ? WeightTrend.up : WeightTrend.down);
      }
    }

    final summaryLines = <String>[
      sedentary
          ? 'Sem treinos completados nas últimas 2 semanas.'
          : 'Treinando com regularidade nas últimas semanas.',
    ];
    if (latestWeightKg != null) {
      final trendLabel = switch (weightTrend) {
        WeightTrend.up => 'tendência de alta',
        WeightTrend.down => 'tendência de queda',
        WeightTrend.stable => 'peso estável',
        null => null,
      };
      summaryLines.add(
        'Peso mais recente: ${latestWeightKg}kg'
        '${trendLabel != null ? ' ($trendLabel)' : ''}.',
      );
    }

    return CoachContext(
      goal: goal,
      experienceLevel: experienceLevel,
      sedentary: sedentary,
      latestWeightKg: latestWeightKg,
      weightTrend: weightTrend,
      summaryText: summaryLines.join(' '),
    );
  }

  /// Sends the conversation so far to the `ai-coach` Edge Function and
  /// returns the assistant's reply. Throws [StateError] if the build has no
  /// Supabase config.
  Future<String> sendMessage({
    required List<ChatMessage> history,
    required CoachContext context,
  }) async {
    final url = _supabaseUrl;
    final apiKey = _supabaseAnonKey;
    if (url == null || apiKey == null) {
      throw StateError('O coach de IA não está configurado nesta build.');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '$url/functions/v1/ai-coach',
      data: {
        'messages': [
          for (final message in history)
            {
              'role': message.role == ChatRole.assistant ? 'assistant' : 'user',
              'content': message.content,
            },
        ],
        'profile': {
          'goal': context.goal,
          'experienceLevel': context.experienceLevel,
        },
        'activitySummary': context.summaryText,
      },
      options: Options(
        headers: {'apikey': apiKey, 'Authorization': 'Bearer $apiKey'},
      ),
    );

    return parseChatReply(response.data!);
  }

  /// Asks the `adjust-workout` Edge Function to revise an existing
  /// workout's exercises according to [instructions] and [context]. Throws
  /// [StateError] if the build has no Supabase config, or if no local
  /// exercise matches [availableEquipment]; throws
  /// [UnresolvedPlanExercisesException] if the AI still referenced a slug
  /// outside the list it was given.
  Future<WorkoutAdjustmentProposal> proposeWorkoutAdjustment({
    required int workoutId,
    required String instructions,
    required CoachContext context,
    required Set<Equipment> availableEquipment,
  }) async {
    final url = _supabaseUrl;
    final apiKey = _supabaseAnonKey;
    if (url == null || apiKey == null) {
      throw StateError('O coach de IA não está configurado nesta build.');
    }

    final allExercises = await _db.exercisesDao.getAllExercises();
    final eligible = filterEligibleExercises(allExercises, availableEquipment);
    if (eligible.isEmpty) {
      throw StateError(
        'Nenhum exercício disponível para o equipamento selecionado.',
      );
    }

    final exercisesById = {for (final e in allExercises) e.id: e};
    final currentEntries = await _db.workoutsDao.getExercisesForWorkout(
      workoutId,
    );
    // Only slugged (catalog/seeded) exercises are addressable by the AI —
    // same constraint AiPlanBuilderRepository already has. A custom
    // exercise with no slug is simply left out of what the AI is told
    // about; it isn't touched by `replaceWorkoutExercises` deleting and
    // re-inserting the workout's rows, since the proposal never mentions
    // it in the first place, so it just won't survive an applied
    // adjustment unless the user re-adds it manually afterwards.
    final currentExercises = [
      for (final entry in currentEntries)
        if (exercisesById[entry.exerciseId]?.slug != null)
          {
            'exerciseSlug': exercisesById[entry.exerciseId]!.slug,
            'targetSets': entry.targetSets,
            'targetReps': entry.targetReps,
            'targetRestSeconds': entry.targetRestSeconds,
            'notes': entry.notes,
          },
    ];

    final response = await _dio.post<Map<String, dynamic>>(
      '$url/functions/v1/adjust-workout',
      data: {
        'instructions': instructions,
        'currentExercises': currentExercises,
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
        'context': {
          'goal': context.goal,
          'experienceLevel': context.experienceLevel,
          'sedentary': context.sedentary,
          'latestWeightKg': context.latestWeightKg,
          'weightTrend': switch (context.weightTrend) {
            WeightTrend.up => 'up',
            WeightTrend.down => 'down',
            WeightTrend.stable => 'stable',
            null => null,
          },
        },
      },
      options: Options(
        headers: {'apikey': apiKey, 'Authorization': 'Bearer $apiKey'},
      ),
    );

    final proposal = WorkoutAdjustmentProposal.fromJson(response.data!);
    final knownSlugs = eligible.map((e) => e.slug!).toSet();
    // findUnresolvedSlugs takes a list of workout-shaped exercise groups —
    // wrapped here since a proposal is really just one such group with no
    // name of its own.
    final unresolved = findUnresolvedSlugs([
      GeneratedPlanWorkout(name: '', exercises: proposal.exercises),
    ], knownSlugs);
    if (unresolved.isNotEmpty) {
      throw UnresolvedPlanExercisesException(unresolved);
    }

    return proposal;
  }
}
