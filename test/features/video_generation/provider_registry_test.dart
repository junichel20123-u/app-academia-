import 'package:app_academia/features/video_generation/data/http_job_based_provider.dart';
import 'package:app_academia/features/video_generation/data/mock_video_generation_provider.dart';
import 'package:app_academia/features/video_generation/data/provider_registry.dart';
import 'package:app_academia/features/video_generation/data/runway_video_generation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('descriptorFor', () {
    test('resolves each known provider id to its own descriptor', () {
      expect(ProviderRegistry.descriptorFor('mock'), ProviderRegistry.mock);
      expect(
        ProviderRegistry.descriptorFor('http_custom'),
        ProviderRegistry.httpCustom,
      );
      expect(ProviderRegistry.descriptorFor('runway'), ProviderRegistry.runway);
    });

    test('falls back to mock for an unknown id', () {
      expect(
        ProviderRegistry.descriptorFor('some_removed_or_invalid_id'),
        ProviderRegistry.mock,
      );
    });
  });

  group('create', () {
    test('builds a MockVideoGenerationProvider for "mock"', () {
      expect(
        ProviderRegistry.create('mock'),
        isA<MockVideoGenerationProvider>(),
      );
    });

    test('builds an HttpJobBasedProvider with the given base URL for '
        '"http_custom"', () {
      final provider = ProviderRegistry.create(
        'http_custom',
        baseUrl: 'https://x.test',
      ) as HttpJobBasedProvider;
      expect(provider.baseUrl, 'https://x.test');
    });

    test('builds a RunwayVideoGenerationProvider for "runway"', () {
      expect(
        ProviderRegistry.create('runway'),
        isA<RunwayVideoGenerationProvider>(),
      );
    });

    test('falls back to MockVideoGenerationProvider for an unknown id', () {
      expect(
        ProviderRegistry.create('some_removed_or_invalid_id'),
        isA<MockVideoGenerationProvider>(),
      );
    });
  });
}
