import 'package:app_academia/features/ai_plan_builder/domain/generated_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGeneratedPlanResponse', () {
    test('parses the generate-plan Edge Function response body', () {
      final json = {
        'workouts': [
          {
            'name': 'Push',
            'exercises': [
              {
                'exerciseSlug': 'supino-reto-com-barra',
                'targetSets': 3,
                'targetReps': 10,
                'targetRestSeconds': 90,
                'notes': null,
              },
            ],
          },
          {
            'name': 'Legs',
            'exercises': [
              {
                'exerciseSlug': 'agachamento-livre',
                'targetSets': 4,
                'targetReps': null,
                'targetRestSeconds': null,
                'notes': 'Até a falha',
              },
            ],
          },
        ],
      };

      final workouts = parseGeneratedPlanResponse(json);

      expect(workouts, hasLength(2));
      expect(workouts.first.name, 'Push');
      final firstExercise = workouts.first.exercises.single;
      expect(firstExercise.exerciseSlug, 'supino-reto-com-barra');
      expect(firstExercise.targetSets, 3);
      expect(firstExercise.targetReps, 10);
      expect(firstExercise.targetRestSeconds, 90);
      expect(firstExercise.notes, isNull);

      final secondExercise = workouts.last.exercises.single;
      expect(secondExercise.targetReps, isNull);
      expect(secondExercise.notes, 'Até a falha');
    });
  });
}
