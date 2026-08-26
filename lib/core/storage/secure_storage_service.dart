import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps Keychain/Keystore for the one thing the app keeps out of the
/// Drift database: a video-provider API key. Not `final` so tests can
/// subclass and override without touching the real secure-storage plugin
/// (unavailable in the test VM).
class SecureStorageService {
  const SecureStorageService();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  String _keyFor(String providerId) => 'video_provider_api_key_$providerId';

  Future<String?> getApiKey(String providerId) =>
      _storage.read(key: _keyFor(providerId));

  Future<void> setApiKey(String providerId, String apiKey) =>
      _storage.write(key: _keyFor(providerId), value: apiKey);

  Future<void> deleteApiKey(String providerId) =>
      _storage.delete(key: _keyFor(providerId));
}
