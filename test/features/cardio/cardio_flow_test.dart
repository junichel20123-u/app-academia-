import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:app_academia/features/cardio/presentation/cardio_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create, edit and delete a cardio entry', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CardioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum registro de cardio ainda.'), findsOneWidget);

    // Create an entry.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Duração em minutos'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Distância em km (opcional)'),
      '5',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Corrida'), findsOneWidget);
    expect(find.textContaining('30 min'), findsOneWidget);
    expect(find.textContaining('5.00 km'), findsOneWidget);

    // Edit it.
    await tester.tap(find.text('Corrida'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Duração em minutos'),
      '45',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('45 min'), findsOneWidget);

    // Delete it.
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum registro de cardio ainda.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('negative distance or calories does not save the entry', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CardioScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Duração em minutos'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Distância em km (opcional)'),
      '-5',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    // Dialog stays open — the entry was not saved.
    expect(find.text('Novo cardio'), findsOneWidget);
    expect(find.text('Nenhum registro de cardio ainda.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
