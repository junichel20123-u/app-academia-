import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/ai_plan_builder/data/ai_plan_builder_repository.dart';
import 'package:app_academia/features/ai_plan_builder/domain/generated_plan.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/database/test_database.dart';

void main() {
  group('filterEligibleExercises', () {
    test('keeps exercises with no equipment and exercises whose equipment is available', () {
      final bodyweight = _exercise(1, 'Flexão', null, slug: 'flexao');
      final withBarbell = _exercise(
        2,
        'Supino',
        Equipment.barbell,
        slug: 'supino',
      );
      final withDumbbell = _exercise(
        3,
        'Rosca',
        Equipment.dumbbell,
        slug: 'rosca',
      );

      final eligible = filterEligibleExercises(
        [bodyweight, withBarbell, withDumbbell],
        {Equipment.barbell},
      );

      expect(eligible, containsAll([bodyweight, withBarbell]));
      expect(eligible, isNot(contains(withDumbbell)));
    });

    test('excludes exercises with no slug (custom exercises)', () {
      final custom = _exercise(1, 'Personalizado', null, slug: null);
      expect(filterEligibleExercises([custom], {}), isEmpty);
    });
  });

  group('findUnresolvedSlugs', () {
    test('returns slugs not present in knownSlugs, deduplicated', () {
      const workouts = [
        GeneratedPlanWorkout(
          name: 'Push',
          exercises: [
            GeneratedPlanExercise(exerciseSlug: 'known', targetSets: 3),
            GeneratedPlanExercise(exerciseSlug: 'unknown', targetSets: 3),
          ],
        ),
        GeneratedPlanWorkout(
          name: 'Pull',
          exercises: [
            GeneratedPlanExercise(exerciseSlug: 'unknown', targetSets: 3),
          ],
        ),
      ];

      final unresolved = findUnresolvedSlugs(workouts, {'known'});

      expect(unresolved, ['unknown']);
    });

    test('returns an empty list when every slug resolves', () {
      const workouts = [
        GeneratedPlanWorkout(
          name: 'Push',
          exercises: [
            GeneratedPlanExercise(exerciseSlug: 'known', targetSets: 3),
          ],
        ),
      ];

      expect(findUnresolvedSlugs(workouts, {'known'}), isEmpty);
    });
  });

  group('AiPlanBuilderRepository', () {
    late AppDatabase db;
    late AiPlanBuilderRepository repository;

    setUp(() {
      db = openTestDatabase();
      repository = AiPlanBuilderRepository(db);
    });
    tearDown(() => db.close());

    test('isPremiumUnlocked reflects the stored settings flag', () async {
      expect(await repository.isPremiumUnlocked(), isFalse);

      await db.userSettingsDao.saveSettings(
        const UserSettingsTableCompanion(
          aiPlanBuilderPremiumUnlocked: Value(true),
        ),
      );

      expect(await repository.isPremiumUnlocked(), isTrue);
    });

    group('generatePlan', () {
      test('throws StateError when Supabase is not configured', () {
        expect(
          () => repository.generatePlan(
            goal: 'hipertrofia',
            daysPerWeek: 3,
            experienceLevel: 'beginner',
            availableEquipment: {},
          ),
          throwsStateError,
        );
      });
    });

    group('importPlan', () {
      test('creates one workout per day, exercises resolved by slug', () async {
        final seeded = await db.exercisesDao.getAllExercises();
        final knownSlug = seeded.first.slug!;

        final workouts = [
          GeneratedPlanWorkout(
            name: 'Push',
            exercises: [
              GeneratedPlanExercise(
                exerciseSlug: knownSlug,
                targetSets: 3,
                targetReps: 10,
                targetRestSeconds: 90,
              ),
            ],
          ),
        ];

        final createdWorkoutIds = await repository.importPlan(
          workouts,
          planName: 'Meu plano',
        );

        expect(createdWorkoutIds, hasLength(1));
        final workout = await db.workoutsDao.getWorkoutById(
          createdWorkoutIds.single,
        );
        expect(workout!.name, 'Meu plano — Push');
        final entries = await db.workoutsDao.getExercisesForWorkout(workout.id);
        expect(entries, hasLength(1));
        expect(entries.first.targetSets, 3);
        expect(entries.first.targetReps, 10);
      });

      test(
        'throws UnresolvedPlanExercisesException for an unknown slug',
        () async {
          const workouts = [
            GeneratedPlanWorkout(
              name: 'Push',
              exercises: [
                GeneratedPlanExercise(
                  exerciseSlug: 'not-in-this-install',
                  targetSets: 3,
                ),
              ],
            ),
          ];

          expect(
            () => repository.importPlan(workouts, planName: 'Meu plano'),
            throwsA(isA<UnresolvedPlanExercisesException>()),
          );
        },
      );
    });
  });
}

Exercise _exercise(
  int id,
  String name,
  Equipment? equipment, {
  required String? slug,
}) {
  return Exercise(
    id: id,
    name: name,
    slug: slug,
    muscleGroup: MuscleGroup.chest,
    equipment: equipment,
    isCustom: slug == null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}
