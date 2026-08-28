import '../../ai_plan_builder/domain/generated_plan.dart';

/// The `adjust-workout` Edge Function's response: an explanation plus the
/// revised exercise list for one existing workout. `exercises` reuses
/// [GeneratedPlanExercise] — same exact shape as a day in a generated plan
/// (`exerciseSlug`/`targetSets`/`targetReps`/`targetRestSeconds`/`notes`),
/// so there's no reason to redeclare an identical class here.
class WorkoutAdjustmentProposal {
  const WorkoutAdjustmentProposal({
    required this.summary,
    required this.exercises,
  });

  final String summary;
  final List<GeneratedPlanExercise> exercises;

  factory WorkoutAdjustmentProposal.fromJson(Map<String, dynamic> json) {
    return WorkoutAdjustmentProposal(
      summary: json['summary'] as String,
      exercises: (json['exercises'] as List)
          .map((e) => GeneratedPlanExercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
