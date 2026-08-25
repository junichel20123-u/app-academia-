import '../../../core/database/app_database.dart';

/// One exercise's worth of logged sets within an active/past session.
///
/// [workoutExerciseId] is set when this row comes from the session's
/// template (so target sets/reps/weight/rest are known); it is null for
/// exercises added ad-hoc during the session (no plan to compare against).
class SessionExerciseGroup {
  const SessionExerciseGroup({
    required this.exerciseId,
    required this.workoutExerciseId,
    required this.targetSets,
    required this.targetReps,
    required this.targetWeight,
    required this.loggedSets,
  });

  final int exerciseId;
  final int? workoutExerciseId;
  final int? targetSets;
  final int? targetReps;
  final double? targetWeight;
  final List<LoggedSet> loggedSets;
}

/// Builds the ordered list of exercise groups shown in a session screen:
/// template exercises first (in their planned order), followed by any
/// exercises logged ad-hoc that aren't part of the template, ordered by
/// when they were first logged.
List<SessionExerciseGroup> buildSessionExerciseGroups({
  required List<WorkoutExercise> templateEntries,
  required List<LoggedSet> loggedSets,
}) {
  final setsByWorkoutExerciseId = <int, List<LoggedSet>>{};
  final setsByExerciseIdOnly = <int, List<LoggedSet>>{};

  for (final set in loggedSets) {
    final weId = set.workoutExerciseId;
    if (weId != null) {
      setsByWorkoutExerciseId.putIfAbsent(weId, () => []).add(set);
    } else {
      setsByExerciseIdOnly.putIfAbsent(set.exerciseId, () => []).add(set);
    }
  }

  final groups = <SessionExerciseGroup>[
    for (final entry in templateEntries)
      SessionExerciseGroup(
        exerciseId: entry.exerciseId,
        workoutExerciseId: entry.id,
        targetSets: entry.targetSets,
        targetReps: entry.targetReps,
        targetWeight: entry.targetWeight,
        loggedSets: setsByWorkoutExerciseId[entry.id] ?? const [],
      ),
  ];

  final adHocExerciseIds = setsByExerciseIdOnly.keys.toList()
    ..sort((a, b) {
      final aFirst = setsByExerciseIdOnly[a]!.first.id;
      final bFirst = setsByExerciseIdOnly[b]!.first.id;
      return aFirst.compareTo(bFirst);
    });

  for (final exerciseId in adHocExerciseIds) {
    groups.add(
      SessionExerciseGroup(
        exerciseId: exerciseId,
        workoutExerciseId: null,
        targetSets: null,
        targetReps: null,
        targetWeight: null,
        loggedSets: setsByExerciseIdOnly[exerciseId]!,
      ),
    );
  }

  return groups;
}
