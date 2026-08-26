import 'package:app_academia/app/router.dart';
import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:app_academia/features/template_catalog/domain/catalog_template.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'browse the catalog, open a template, copy it into Meus treinos',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final firstExercise = (await db.exercisesDao.getAllExercises()).first;
      await db.catalogTemplatesDao.replaceAll([
        CatalogTemplatesCompanion.insert(
          slug: 'push-pull-legs',
          name: 'Push Pull Legs',
          goal: const Value('hypertrofia'),
          payloadJson: encodeCatalogWorkouts([
            CatalogWorkout(
              name: 'Push',
              dayIndex: 0,
              exercises: [
                CatalogWorkoutExercise(
                  exerciseSlug: firstExercise.slug!,
                  orderIndex: 0,
                  targetSets: 3,
                  targetReps: 10,
                ),
              ],
            ),
          ]),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ]);

      appRouter.go('/templates');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Push Pull Legs'), findsOneWidget);
      expect(find.textContaining('hypertrofia'), findsOneWidget);

      await tester.tap(find.text('Push Pull Legs'));
      await tester.pumpAndSettle();

      expect(find.text('Push'), findsOneWidget);
      expect(find.text(firstExercise.name), findsOneWidget);

      await tester.tap(find.text('Copiar para meus treinos'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 treino(s) criado(s)'), findsOneWidget);

      appRouter.go('/workouts');
      await tester.pumpAndSettle();
      expect(find.text('Push Pull Legs — Push'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}
