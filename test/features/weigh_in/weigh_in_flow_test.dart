import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:app_academia/features/weigh_in/presentation/weigh_in_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'create two entries (chart appears), edit one, then delete both',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // The chart takes up most of the default test surface height, which
      // would otherwise push the entry list out of the built (visible)
      // range of the ListView. Use a taller surface so everything fits.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: WeighInScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma pesagem ainda.'), findsOneWidget);

      // First entry: still too few for a chart.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Peso em kg'),
        '80',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('80.0 kg'), findsOneWidget);
      expect(
        find.text('Adicione ao menos 2 pesagens para ver o gráfico.'),
        findsOneWidget,
      );

      // Second entry: chart should now render.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Peso em kg'),
        '79',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Adicione ao menos 2 pesagens para ver o gráfico.'),
        findsNothing,
      );
      expect(find.textContaining('79.0 kg'), findsOneWidget);

      // Edit the most recent entry.
      await tester.tap(find.textContaining('79.0 kg'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Peso em kg'),
        '77.5',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('77.5 kg'), findsOneWidget);

      // Delete both entries.
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.delete_outline).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Excluir'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Nenhuma pesagem ainda.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );
}
