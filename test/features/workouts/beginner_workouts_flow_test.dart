import 'package:app_academia/app/router.dart';
import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixed "Treinos iniciante" workouts are read-only, startable and '
      'duplicable, but never deletable', (tester) async {
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

    // The 3 fixed workouts always appear, even on a brand-new install —
    // this is the whole point: someone with no plan of their own still
    // sees something to start with.
    expect(find.text('Treinos iniciante'), findsOneWidget);
    expect(find.text('Iniciante — Queima Total'), findsOneWidget);
    expect(find.text('Iniciante — Intervalado Leve'), findsOneWidget);
    expect(find.text('Iniciante — Ativação Full Body'), findsOneWidget);

    // No user workouts yet — the "Meus treinos" section still shows its
    // own empty state alongside the always-present fixed ones.
    expect(find.text('Meus treinos'), findsOneWidget);
    expect(
      find.text('Nenhum treino ainda. Toque em + para criar.'),
      findsOneWidget,
    );

    // Opening a fixed workout shows a read-only detail: no "Editar
    // treino" title, no "Adicionar exercício", an "Iniciar" button
    // instead, and its exercises listed.
    await tester.tap(find.text('Iniciante — Queima Total'));
    await tester.pumpAndSettle();
    expect(find.text('Editar treino'), findsNothing);
    expect(find.text('Adicionar exercício'), findsNothing);
    expect(find.text('Iniciar'), findsOneWidget);
    expect(find.text('Polichinelo'), findsOneWidget);

    // The name field can't be edited.
    final nameField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Nome do treino'),
    );
    expect(nameField.enabled, isFalse);

    // No remove/reorder affordance on any exercise row.
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    // Only "Duplicar" is offered for a fixed workout — never "Excluir".
    final fixedTile = find.widgetWithText(ListTile, 'Iniciante — Queima Total');
    await tester.tap(
      find.descendant(
        of: fixedTile,
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Excluir'), findsNothing);
    expect(find.text('Duplicar'), findsOneWidget);

    // Duplicating creates an independent, editable copy under "Meus
    // treinos" — the fixed original is never touched.
    await tester.tap(find.text('Duplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciante — Queima Total (cópia)'), findsOneWidget);
    expect(
      find.text('Nenhum treino ainda. Toque em + para criar.'),
      findsNothing,
    );

    await tester.tap(find.text('Iniciante — Queima Total (cópia)'));
    await tester.pumpAndSettle();
    expect(find.text('Editar treino'), findsOneWidget);
    expect(find.text('Adicionar exercício'), findsOneWidget);
    expect(find.text('Polichinelo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
