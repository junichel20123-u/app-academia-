enum WeightTrend { up, down, stable }

/// The auto-detected context an `AiCoachRepository` builds from the local
/// database before every coach request — the "de acordo com o objetivo e
/// sedentarismo/peso" personalization the chat and the workout-adjustment
/// tool both rely on, computed once instead of asked from the user every
/// time.
class CoachContext {
  const CoachContext({
    required this.goal,
    required this.experienceLevel,
    required this.sedentary,
    required this.latestWeightKg,
    required this.weightTrend,
    required this.summaryText,
  });

  final String? goal;
  final String? experienceLevel;

  /// True when no workout session was completed in the last 14 days.
  final bool sedentary;
  final double? latestWeightKg;
  final WeightTrend? weightTrend;

  /// Short, human-readable summary of [sedentary]/[latestWeightKg]/
  /// [weightTrend] — sent to the `ai-coach` chat endpoint as
  /// `activitySummary` (free text, provider-agnostic), while the structured
  /// fields above are sent as-is to `adjust-workout`'s `context`.
  final String summaryText;
}
