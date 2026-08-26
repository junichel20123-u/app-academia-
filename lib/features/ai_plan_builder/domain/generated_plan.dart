/// One exercise entry in an AI-generated plan, as returned by the
/// `generate-plan` Edge Function's structured output (camelCase — this is
/// the function's own response shape, not PostgREST's snake_case).
class GeneratedPlanExercise {
  const GeneratedPlanExercise({
    required this.exerciseSlug,
    required this.targetSets,
    this.targetReps,
    this.targetRestSeconds,
    this.notes,
  });

  final String exerciseSlug;
  final int targetSets;
  final int? targetReps;
  final int? targetRestSeconds;
  final String? notes;

  factory GeneratedPlanExercise.fromJson(Map<String, dynamic> json) {
    return GeneratedPlanExercise(
      exerciseSlug: json['exerciseSlug'] as String,
      targetSets: json['targetSets'] as int,
      targetReps: json['targetReps'] as int?,
      targetRestSeconds: json['targetRestSeconds'] as int?,
      notes: json['notes'] as String?,
    );
  }
}

/// One day of an AI-generated plan.
class GeneratedPlanWorkout {
  const GeneratedPlanWorkout({required this.name, required this.exercises});

  final String name;
  final List<GeneratedPlanExercise> exercises;

  factory GeneratedPlanWorkout.fromJson(Map<String, dynamic> json) {
    return GeneratedPlanWorkout(
      name: json['name'] as String,
      exercises: (json['exercises'] as List)
          .map((e) => GeneratedPlanExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Parses the `generate-plan` Edge Function's response body
/// (`{"workouts": [...]}`) into the day-by-day plan.
List<GeneratedPlanWorkout> parseGeneratedPlanResponse(
  Map<String, dynamic> json,
) {
  return (json['workouts'] as List)
      .map((w) => GeneratedPlanWorkout.fromJson(w as Map<String, dynamic>))
      .toList();
}
