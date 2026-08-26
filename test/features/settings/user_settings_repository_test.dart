import 'package:app_academia/features/settings/data/user_settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../core/database/test_database.dart';
import '../../support/fake_secure_storage_service.dart';

void main() {
  test(
    'saves the provider id/base URL to the DB and only a marker for the key',
    () async {
      final db = openTestDatabase();
      addTearDown(db.close);
      final secureStorage = FakeSecureStorageService();
      final repository = UserSettingsRepository(
        db,
        secureStorage: secureStorage,
      );

      await repository.saveVideoProviderConfig(
        providerId: 'http_custom',
        baseUrl: 'https://api.example.com',
        apiKey: 'super-secret',
      );

      final settings = await repository.getSettings();
      expect(settings.videoProviderId, 'http_custom');
      expect(settings.videoProviderBaseUrl, 'https://api.example.com');
      // Only a non-secret marker goes to the Drift/SQLite row — never the
      // real key.
      expect(settings.videoProviderApiKeyRef, 'stored');

      // The real secret only lives behind the secure-storage service.
      expect(await repository.getApiKeyFor('http_custom'), 'super-secret');
    },
  );

  test('does not touch secure storage when no key is provided', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final secureStorage = FakeSecureStorageService();
    final repository = UserSettingsRepository(db, secureStorage: secureStorage);

    await repository.saveVideoProviderConfig(providerId: 'mock');

    final settings = await repository.getSettings();
    expect(settings.videoProviderId, 'mock');
    expect(settings.videoProviderApiKeyRef, isNull);
    expect(await repository.getApiKeyFor('mock'), isNull);
  });

  test('an empty apiKey is treated as "no key provided"', () async {
    final db = openTestDatabase();
    addTearDown(db.close);
    final secureStorage = FakeSecureStorageService();
    final repository = UserSettingsRepository(db, secureStorage: secureStorage);

    await repository.saveVideoProviderConfig(providerId: 'mock', apiKey: '');

    final settings = await repository.getSettings();
    expect(settings.videoProviderApiKeyRef, isNull);
  });
}
