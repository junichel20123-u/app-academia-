import 'package:app_academia/features/template_catalog/domain/catalog_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encodeCatalogWorkouts / parseCatalogWorkouts', () {
    test('round-trips a list of workouts with their exercises', () {
      const workouts = [
        CatalogWorkout(
          name: 'Push',
          dayIndex: 0,
          exercises: [
            CatalogWorkoutExercise(
              exerciseSlug: 'supino-reto-com-barra',
              orderIndex: 0,
              targetSets: 3,
              targetReps: 10,
              targetRestSeconds: 90,
              notes: 'Pegada média',
            ),
          ],
        ),
      ];

      final decoded = parseCatalogWorkouts(encodeCatalogWorkouts(workouts));

      expect(decoded, hasLength(1));
      expect(decoded.first.name, 'Push');
      expect(
        decoded.first.exercises.single.exerciseSlug,
        'supino-reto-com-barra',
      );
      expect(decoded.first.exercises.single.targetSets, 3);
      expect(decoded.first.exercises.single.notes, 'Pegada média');
    });
  });

  group('parseSupabaseTemplatesResponse', () {
    test('parses a PostgREST embedded response into companions', () {
      final response = [
        {
          'id': 1,
          'slug': 'push-pull-legs',
          'name': 'Push Pull Legs',
          'description': 'Rotina clássica de 3 dias',
          'goal': 'hypertrophy',
          'difficulty': 'intermediate',
          'is_active': true,
          'updated_at': '2026-01-01T00:00:00+00:00',
          'template_program_workouts': [
            {
              'id': 10,
              'day_index': 0,
              'name': 'Push',
              'template_program_workout_exercises': [
                {
                  'id': 100,
                  'exercise_slug': 'supino-reto-com-barra',
                  'order_index': 0,
                  'target_sets': 3,
                  'target_reps': 10,
                  'target_rest_seconds': 90,
                  'notes': null,
                },
              ],
            },
          ],
        },
      ];

      final companions = parseSupabaseTemplatesResponse(response);

      expect(companions, hasLength(1));
      final companion = companions.single;
      expect(companion.slug.value, 'push-pull-legs');
      expect(companion.name.value, 'Push Pull Legs');
      expect(companion.goal.value, 'hypertrophy');

      final workouts = parseCatalogWorkouts(companion.payloadJson.value);
      expect(workouts, hasLength(1));
      expect(workouts.single.name, 'Push');
      expect(
        workouts.single.exercises.single.exerciseSlug,
        'supino-reto-com-barra',
      );
      expect(workouts.single.exercises.single.targetRestSeconds, 90);
    });

    test('handles a program with no workouts embedded', () {
      final response = [
        {
          'id': 2,
          'slug': 'empty-program',
          'name': 'Empty',
          'description': null,
          'goal': null,
          'difficulty': null,
          'is_active': true,
          'updated_at': '2026-01-01T00:00:00+00:00',
        },
      ];

      final companions = parseSupabaseTemplatesResponse(response);

      expect(
        parseCatalogWorkouts(companions.single.payloadJson.value),
        isEmpty,
      );
    });
  });
}
