import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/providers/database_provider.dart';
import 'package:app_academia/features/settings/application/user_settings_providers.dart';
import 'package:app_academia/features/settings/data/user_settings_repository.dart';
import 'package:app_academia/features/settings/presentation/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_secure_storage_service.dart';

void main() {
  testWidgets(
    'switching to a provider that requires credentials reveals the fields, '
    'and saving persists the config',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final secureStorage = FakeSecureStorageService();
      final repository = UserSettingsRepository(
        db,
        secureStorage: secureStorage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            userSettingsRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mock (para testes)'), findsOneWidget);
      expect(find.text('URL base da API'), findsNothing);
      expect(find.text('Chave de API'), findsNothing);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Provedor HTTP customizado').last);
      await tester.pumpAndSettle();

      expect(find.text('URL base da API'), findsOneWidget);
      expect(find.text('Chave de API'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'URL base da API'),
        'https://api.example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Chave de API'),
        'super-secret',
      );

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Configurações salvas.'), findsOneWidget);

      final settings = await repository.getSettings();
      expect(settings.videoProviderId, 'http_custom');
      expect(settings.videoProviderBaseUrl, 'https://api.example.com');
      expect(await repository.getApiKeyFor('http_custom'), 'super-secret');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    },
  );

  testWidgets('Testar conexão reports missing required fields', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = UserSettingsRepository(
      db,
      secureStorage: FakeSecureStorageService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          userSettingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Provedor HTTP customizado').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Testar conexão'));
    await tester.pump();

    expect(
      find.text('Preencha os campos obrigatórios para este provedor.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('switching the appearance segment persists the theme mode', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = UserSettingsRepository(
      db,
      secureStorage: FakeSecureStorageService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          userSettingsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      (await repository.getSettings()).themeModePreference,
      AppThemeMode.dark,
    );

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getSettings()).themeModePreference,
      AppThemeMode.light,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
