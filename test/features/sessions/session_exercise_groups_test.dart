import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/features/sessions/application/session_exercise_groups.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutExercise _templateEntry({
  required int id,
  required int exerciseId,
  int targetSets = 3,
}) {
  return WorkoutExercise(
    id: id,
    workoutId: 1,
    exerciseId: exerciseId,
    orderIndex: id,
    targetSets: targetSets,
    targetReps: 10,
    targetWeight: null,
    targetRestSeconds: null,
    notes: null,
  );
}

LoggedSet _set({
  required int id,
  required int exerciseId,
  int? workoutExerciseId,
  required int setNumber,
}) {
  return LoggedSet(
    id: id,
    sessionId: 1,
    exerciseId: exerciseId,
    workoutExerciseId: workoutExerciseId,
    setNumber: setNumber,
    weight: null,
    reps: null,
    rpe: null,
    notes: null,
    completedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('template exercises appear in order, even with no logged sets yet', () {
    final entries = [
      _templateEntry(id: 1, exerciseId: 10),
      _templateEntry(id: 2, exerciseId: 20),
    ];

    final groups = buildSessionExerciseGroups(
      templateEntries: entries,
      loggedSets: [],
    );

    expect(groups, hasLength(2));
    expect(groups[0].exerciseId, 10);
    expect(groups[0].workoutExerciseId, 1);
    expect(groups[0].loggedSets, isEmpty);
    expect(groups[1].exerciseId, 20);
  });

  test('logged sets are grouped under their template entry', () {
    final entries = [_templateEntry(id: 1, exerciseId: 10)];
    final sets = [
      _set(id: 100, exerciseId: 10, workoutExerciseId: 1, setNumber: 1),
      _set(id: 101, exerciseId: 10, workoutExerciseId: 1, setNumber: 2),
    ];

    final groups = buildSessionExerciseGroups(
      templateEntries: entries,
      loggedSets: sets,
    );

    expect(groups, hasLength(1));
    expect(groups.first.loggedSets, hasLength(2));
  });

  test('ad-hoc exercises (no workoutExerciseId) appear after the template, '
      'ordered by first logged', () {
    final entries = [_templateEntry(id: 1, exerciseId: 10)];
    final sets = [
      _set(id: 100, exerciseId: 10, workoutExerciseId: 1, setNumber: 1),
      _set(id: 200, exerciseId: 99, setNumber: 1), // ad-hoc, logged later
      _set(id: 150, exerciseId: 88, setNumber: 1), // ad-hoc, logged earlier
    ];

    final groups = buildSessionExerciseGroups(
      templateEntries: entries,
      loggedSets: sets,
    );

    expect(groups.map((g) => g.exerciseId), [10, 88, 99]);
    expect(groups[1].workoutExerciseId, isNull);
    expect(groups[2].workoutExerciseId, isNull);
  });

  test('pure ad-hoc session (no template) groups purely by exerciseId', () {
    final sets = [
      _set(id: 1, exerciseId: 5, setNumber: 1),
      _set(id: 2, exerciseId: 5, setNumber: 2),
    ];

    final groups = buildSessionExerciseGroups(
      templateEntries: [],
      loggedSets: sets,
    );

    expect(groups, hasLength(1));
    expect(groups.first.loggedSets, hasLength(2));
  });

  group('nextSetNumber', () {
    test('starts at 1 for an empty group', () {
      expect(nextSetNumber(const []), 1);
    });

    test('is one past the highest existing set number', () {
      final sets = [
        _set(id: 1, exerciseId: 10, setNumber: 1),
        _set(id: 2, exerciseId: 10, setNumber: 2),
        _set(id: 3, exerciseId: 10, setNumber: 3),
      ];
      expect(nextSetNumber(sets), 4);
    });

    test(
      'does not collide with a remaining set after a middle one was deleted',
      () {
        // Sets 1/2/3 logged, then set 2 deleted — only 1 and 3 remain.
        final remaining = [
          _set(id: 1, exerciseId: 10, setNumber: 1),
          _set(id: 3, exerciseId: 10, setNumber: 3),
        ];
        expect(nextSetNumber(remaining), 4);
      },
    );
  });
}
