import 'package:app_academia/app/router.dart';
import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:app_academia/features/ai_plan_builder/domain/generated_plan.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'locked state shows a "coming soon" snackbar instead of generating',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      appRouter.go('/plan-builder');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('O montador de plano por IA é um recurso premium.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();

      expect(find.text('Pagamentos em breve.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets('previewing and importing a generated plan creates a workout', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final firstExercise = (await db.exercisesDao.getAllExercises()).first;
    final workouts = [
      GeneratedPlanWorkout(
        name: 'Push',
        exercises: [
          GeneratedPlanExercise(
            exerciseSlug: firstExercise.slug!,
            targetSets: 3,
            targetReps: 10,
          ),
        ],
      ),
    ];

    appRouter.go('/plan-builder/preview', extra: workouts);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Push'), findsOneWidget);
    expect(find.text(firstExercise.name), findsOneWidget);

    await tester.tap(find.text('Importar para meus treinos'));
    await tester.pumpAndSettle();

    expect(find.text('Plano gerado por IA — Push'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
