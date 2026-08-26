import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/features/template_catalog/data/template_catalog_repository.dart';
import 'package:app_academia/features/template_catalog/domain/catalog_template.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/database/test_database.dart';

void main() {
  late AppDatabase db;
  late TemplateCatalogRepository repository;

  setUp(() {
    db = openTestDatabase();
    repository = TemplateCatalogRepository(db);
  });
  tearDown(() => db.close());

  test('sync() is a no-op without a configured Supabase client', () async {
    // No restClient passed above (SUPABASE_URL/ANON_KEY not set in this
    // build) — sync() should just return, never throw.
    await repository.sync();
    expect(await db.catalogTemplatesDao.getAllTemplates(), isEmpty);
  });

  group('copyTemplateToMyWorkouts', () {
    Future<CatalogTemplate> seedTemplate(List<CatalogWorkout> workouts) async {
      await db.catalogTemplatesDao.replaceAll([
        CatalogTemplatesCompanion.insert(
          slug: 'push-pull-legs',
          name: 'Push Pull Legs',
          payloadJson: encodeCatalogWorkouts(workouts),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);
      return (await db.catalogTemplatesDao.getBySlug('push-pull-legs'))!;
    }

    test(
      'creates one local workout per day, exercises resolved by slug',
      () async {
        final seeded = await db.exercisesDao.getAllExercises();
        final knownSlug = seeded.first.slug!;

        final template = await seedTemplate([
          CatalogWorkout(
            name: 'Push',
            dayIndex: 0,
            exercises: [
              CatalogWorkoutExercise(
                exerciseSlug: knownSlug,
                orderIndex: 0,
                targetSets: 3,
                targetReps: 10,
              ),
            ],
          ),
        ]);

        final result = await repository.copyTemplateToMyWorkouts(template);

        expect(result.createdWorkoutIds, hasLength(1));
        expect(result.unresolvedSlugs, isEmpty);
        final workout = await db.workoutsDao.getWorkoutById(
          result.createdWorkoutIds.single,
        );
        expect(workout!.name, 'Push Pull Legs — Push');
        final entries = await db.workoutsDao.getExercisesForWorkout(workout.id);
        expect(entries, hasLength(1));
        expect(entries.first.targetSets, 3);
      },
    );

    test(
      'skips an unresolved exercise slug without failing the whole day',
      () async {
        final seeded = await db.exercisesDao.getAllExercises();
        final knownSlug = seeded.first.slug!;

        final template = await seedTemplate([
          CatalogWorkout(
            name: 'Push',
            dayIndex: 0,
            exercises: [
              CatalogWorkoutExercise(
                exerciseSlug: knownSlug,
                orderIndex: 0,
                targetSets: 3,
              ),
              const CatalogWorkoutExercise(
                exerciseSlug: 'not-in-this-install',
                orderIndex: 1,
                targetSets: 3,
              ),
            ],
          ),
        ]);

        final result = await repository.copyTemplateToMyWorkouts(template);

        expect(result.createdWorkoutIds, hasLength(1));
        expect(result.unresolvedSlugs, ['not-in-this-install']);
        final entries = await db.workoutsDao.getExercisesForWorkout(
          result.createdWorkoutIds.single,
        );
        expect(entries, hasLength(1));
      },
    );

    test(
      'does not create a workout for a day where every exercise is unresolved',
      () async {
        final template = await seedTemplate([
          const CatalogWorkout(
            name: 'Push',
            dayIndex: 0,
            exercises: [
              CatalogWorkoutExercise(
                exerciseSlug: 'not-in-this-install',
                orderIndex: 0,
                targetSets: 3,
              ),
            ],
          ),
        ]);

        final result = await repository.copyTemplateToMyWorkouts(template);

        expect(result.createdWorkoutIds, isEmpty);
        expect(result.unresolvedSlugs, ['not-in-this-install']);
      },
    );
  });
}
