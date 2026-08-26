import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/secure_storage_service.dart';

class UserSettingsRepository {
  UserSettingsRepository(
    this._db, {
    SecureStorageService secureStorage = const SecureStorageService(),
    // Keeps the public param name `secureStorage` distinct from `_secureStorage`.
    // ignore: prefer_initializing_formals
  }) : _secureStorage = secureStorage;

  final AppDatabase _db;
  final SecureStorageService _secureStorage;

  Stream<UserSettingsTableData> watchSettings() =>
      _db.userSettingsDao.watchSettings();

  Future<UserSettingsTableData> getSettings() =>
      _db.userSettingsDao.getSettings();

  Future<String?> getApiKeyFor(String providerId) =>
      _secureStorage.getApiKey(providerId);

  /// Persists the non-secret provider config (id + base URL) to the local
  /// database, and — only if a new key was entered — the secret itself to
  /// secure storage. The key is never written to the Drift/SQLite file.
  Future<void> saveVideoProviderConfig({
    required String providerId,
    String? baseUrl,
    String? apiKey,
  }) async {
    await _db.userSettingsDao.saveSettings(
      UserSettingsTableCompanion(
        videoProviderId: Value(providerId),
        videoProviderBaseUrl: Value(baseUrl),
        videoProviderApiKeyRef: Value(
          apiKey != null && apiKey.isNotEmpty ? 'stored' : null,
        ),
      ),
    );
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStorage.setApiKey(providerId, apiKey);
    }
  }
}
