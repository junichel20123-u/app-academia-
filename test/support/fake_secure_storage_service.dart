import 'package:app_academia/core/storage/secure_storage_service.dart';

/// Avoids touching the real Keychain/Keystore (the `flutter_secure_storage`
/// platform channel is unavailable in the test VM) when exercising
/// settings/video-generation code that needs an API key.
class FakeSecureStorageService extends SecureStorageService {
  final Map<String, String> _store = {};

  @override
  Future<String?> getApiKey(String providerId) async => _store[providerId];

  @override
  Future<void> setApiKey(String providerId, String apiKey) async {
    _store[providerId] = apiKey;
  }

  @override
  Future<void> deleteApiKey(String providerId) async {
    _store.remove(providerId);
  }
}
