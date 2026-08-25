import 'package:app_academia/app/router.dart';
import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create workout, add/edit/remove exercise, duplicate, delete', (
    tester,
  ) async {
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

    // Starts empty.
    expect(
      find.text('Nenhum treino ainda. Toque em + para criar.'),
      findsOneWidget,
    );

    // Create a workout via the FAB dialog.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Treino de Peito');
    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();

    // Navigated straight into the edit screen for the new workout.
    expect(find.text('Editar treino'), findsOneWidget);

    // Add an exercise via the picker.
    await tester.tap(find.text('Adicionar exercício'));
    await tester.pumpAndSettle();
    expect(find.text('Escolher exercício'), findsOneWidget);
    await tester.tap(find.text('Supino reto com barra'));
    await tester.pumpAndSettle();

    // Fill in the targets dialog.
    expect(find.text('Metas do exercício'), findsOneWidget);
    final setsField = find.widgetWithText(TextField, 'Séries');
    await tester.enterText(setsField, '4');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Supino reto com barra'), findsOneWidget);
    expect(find.textContaining('4x'), findsOneWidget);

    // Edit the targets by tapping the row.
    await tester.tap(find.text('Supino reto com barra'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Séries'), '5');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5x'), findsOneWidget);

    // Remove the exercise.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum exercício adicionado ainda.'), findsOneWidget);

    // Back to the library: the workout should be listed with 0 exercises.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Treino de Peito'), findsOneWidget);
    expect(find.text('0 exercício(s)'), findsOneWidget);

    // Duplicate it.
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Treino de Peito (cópia)'), findsOneWidget);

    // Delete the original.
    final originalTile = find.widgetWithText(ListTile, 'Treino de Peito');
    await tester.tap(
      find.descendant(
        of: originalTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();

    expect(find.text('Treino de Peito'), findsNothing);
    expect(find.text('Treino de Peito (cópia)'), findsOneWidget);

    // Dispose the widget tree ourselves and let Drift's stream-cancellation
    // debounce timer fire before the test framework's teardown checks for
    // pending timers (see drift's QueryStream._onCancelOrPause).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
