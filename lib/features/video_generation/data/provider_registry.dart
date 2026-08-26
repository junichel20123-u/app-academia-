import '../domain/video_generation_provider.dart';
import 'http_job_based_provider.dart';
import 'mock_video_generation_provider.dart';

class VideoProviderDescriptor {
  const VideoProviderDescriptor({
    required this.id,
    required this.displayName,
    required this.requiresApiKey,
    required this.requiresBaseUrl,
  });

  final String id;
  final String displayName;
  final bool requiresApiKey;
  final bool requiresBaseUrl;
}

/// Every video-generation provider the Settings screen can offer, plus how
/// to build a live instance from the persisted id/base URL. Adding a real
/// vendor means adding one descriptor here and one branch in [create] —
/// nothing else in the app needs to change.
class ProviderRegistry {
  const ProviderRegistry._();

  static const mock = VideoProviderDescriptor(
    id: 'mock',
    displayName: 'Mock (para testes)',
    requiresApiKey: false,
    requiresBaseUrl: false,
  );

  static const httpCustom = VideoProviderDescriptor(
    id: 'http_custom',
    displayName: 'Provedor HTTP customizado',
    requiresApiKey: true,
    requiresBaseUrl: true,
  );

  static const List<VideoProviderDescriptor> all = [mock, httpCustom];

  static VideoProviderDescriptor descriptorFor(String id) {
    return all.firstWhere((d) => d.id == id, orElse: () => mock);
  }

  static VideoGenerationProvider create(String id, {String? baseUrl}) {
    return switch (id) {
      'http_custom' => HttpJobBasedProvider(baseUrl: baseUrl ?? ''),
      _ => MockVideoGenerationProvider(),
    };
  }
}
