import 'package:app_academia/features/ai_coach/domain/workout_adjustment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('WorkoutAdjustmentProposal.fromJson parses summary and exercises', () {
    final proposal = WorkoutAdjustmentProposal.fromJson({
      'summary': 'Troquei um exercício para dar mais foco em resistência.',
      'exercises': [
        {
          'exerciseSlug': 'agachamento-livre',
          'targetSets': 4,
          'targetReps': 15,
          'targetRestSeconds': 60,
          'notes': null,
        },
      ],
    });

    expect(
      proposal.summary,
      'Troquei um exercício para dar mais foco em resistência.',
    );
    expect(proposal.exercises, hasLength(1));
    expect(proposal.exercises.single.exerciseSlug, 'agachamento-livre');
    expect(proposal.exercises.single.targetSets, 4);
    expect(proposal.exercises.single.targetReps, 15);
  });
}
