import 'package:app_academia/app/router.dart';
import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'start a session from a workout, log a set, finish, see it in history',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      appRouter.go('/workouts');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: appRouter),
        ),
      );
      await tester.pumpAndSettle();

      // Create a workout with one exercise.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Treino de Perna');
      await tester.tap(find.text('Criar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Adicionar exercício'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supino reto com barra'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar')); // default targets
      await tester.pumpAndSettle();

      // Back to the library, then start a session from the workout.
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pumpAndSettle();

      expect(find.text('Sessão de treino'), findsOneWidget);
      expect(find.text('Treino de Perna'), findsOneWidget);
      expect(find.text('Supino reto com barra'), findsOneWidget);

      // Log a set.
      await tester.tap(find.text('Registrar série'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Peso em kg (opcional)'),
        '60',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Repetições (opcional)'),
        '10',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Série 1'), findsOneWidget);

      // Finish the session.
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();

      // Should be back at the library (the session screen was popped).
      expect(find.text('Meus treinos'), findsOneWidget);

      // Check history shows the completed session.
      appRouter.go('/history');
      await tester.pumpAndSettle();
      expect(find.text('Treino de Perna'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets('ad-hoc session: add an exercise live, log a set, finish', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    appRouter.go('/');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Treino livre'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum exercício registrado ainda.'), findsOneWidget);

    await tester.tap(find.text('Adicionar exercício'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supino reto com barra'));
    await tester.pumpAndSettle();

    // First-set dialog for the newly added exercise.
    expect(find.text('Registrar série'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Peso em kg (opcional)'),
      '40',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Supino reto com barra'), findsOneWidget);
    expect(find.textContaining('Série 1'), findsOneWidget);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
