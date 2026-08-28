import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/video_generation/data/composite_video_generation_provider.dart';
import 'package:app_academia/features/video_generation/data/stock_video_provider.dart';
import 'package:app_academia/features/video_generation/domain/video_generation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _exercise({String? slug = 'burpee'}) {
  return Exercise(
    id: 1,
    name: 'Burpee',
    slug: slug,
    muscleGroup: MuscleGroup.cardio,
    equipment: Equipment.bodyweight,
    isCustom: slug == null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

/// A [StockVideoProvider] subclass that never touches Dio — same
/// subclass-override pattern `FakeFileStorageService` already uses for
/// `FileStorageService` elsewhere in this feature's tests.
class _FakeStockVideoProvider extends StockVideoProvider {
  _FakeStockVideoProvider({required this.available}) : super(baseUrl: null);

  final bool available;

  @override
  Future<bool> hasVideoFor(Exercise exercise) async => available;

  @override
  Future<List<int>> downloadBytes(String slug) async => [1, 2, 3];
}

class _FakeFallbackProvider implements VideoGenerationProvider {
  int requestGenerationCalls = 0;
  int checkStatusCalls = 0;
  int fetchResultCalls = 0;

  @override
  String get providerId => 'fake';

  @override
  String get displayName => 'Fake';

  @override
  Future<VideoGenerationJob> requestGeneration({
    required Exercise exercise,
    Map<String, String>? credentials,
  }) async {
    requestGenerationCalls++;
    return const VideoGenerationJob('fallback-job');
  }

  @override
  Future<VideoJobStatus> checkStatus({
    required String jobId,
    Map<String, String>? credentials,
  }) async {
    checkStatusCalls++;
    return const VideoJobStatus(
      kind: VideoJobStatusKind.ready,
      resultUrl: 'fallback-result',
    );
  }

  @override
  Future<List<int>> fetchResult({
    required String resultUrl,
    Map<String, String>? credentials,
  }) async {
    fetchResultCalls++;
    return [9, 9, 9];
  }

  @override
  bool validateCredentials(Map<String, String>? credentials) => true;
}

void main() {
  group('requestGeneration', () {
    test(
      'returns a stock job and never calls the fallback when available',
      () async {
        final fallback = _FakeFallbackProvider();
        final composite = CompositeVideoGenerationProvider(
          stockProvider: _FakeStockVideoProvider(available: true),
          fallbackProvider: fallback,
        );

        final job = await composite.requestGeneration(exercise: _exercise());

        expect(job.jobId, 'stock:burpee');
        expect(fallback.requestGenerationCalls, 0);
      },
    );

    test(
      'delegates to the fallback when no stock video is available',
      () async {
        final fallback = _FakeFallbackProvider();
        final composite = CompositeVideoGenerationProvider(
          stockProvider: _FakeStockVideoProvider(available: false),
          fallbackProvider: fallback,
        );

        final job = await composite.requestGeneration(exercise: _exercise());

        expect(job.jobId, 'fallback-job');
        expect(fallback.requestGenerationCalls, 1);
      },
    );
  });

  group('checkStatus', () {
    test('resolves ready instantly for a stock-prefixed jobId', () async {
      final fallback = _FakeFallbackProvider();
      final composite = CompositeVideoGenerationProvider(
        stockProvider: _FakeStockVideoProvider(available: true),
        fallbackProvider: fallback,
      );

      final status = await composite.checkStatus(jobId: 'stock:burpee');

      expect(status.kind, VideoJobStatusKind.ready);
      expect(status.resultUrl, 'stock:burpee');
      expect(fallback.checkStatusCalls, 0);
    });

    test('delegates to the fallback for a non-stock jobId', () async {
      final fallback = _FakeFallbackProvider();
      final composite = CompositeVideoGenerationProvider(
        stockProvider: _FakeStockVideoProvider(available: false),
        fallbackProvider: fallback,
      );

      final status = await composite.checkStatus(jobId: 'fallback-job');

      expect(status.resultUrl, 'fallback-result');
      expect(fallback.checkStatusCalls, 1);
    });
  });

  group('fetchResult', () {
    test(
      'downloads from the stock provider for a stock-prefixed resultUrl',
      () async {
        final fallback = _FakeFallbackProvider();
        final composite = CompositeVideoGenerationProvider(
          stockProvider: _FakeStockVideoProvider(available: true),
          fallbackProvider: fallback,
        );

        final bytes = await composite.fetchResult(resultUrl: 'stock:burpee');

        expect(bytes, [1, 2, 3]);
        expect(fallback.fetchResultCalls, 0);
      },
    );

    test('delegates to the fallback for a non-stock resultUrl', () async {
      final fallback = _FakeFallbackProvider();
      final composite = CompositeVideoGenerationProvider(
        stockProvider: _FakeStockVideoProvider(available: false),
        fallbackProvider: fallback,
      );

      final bytes = await composite.fetchResult(resultUrl: 'fallback-result');

      expect(bytes, [9, 9, 9]);
      expect(fallback.fetchResultCalls, 1);
    });
  });

  test(
    'providerId/displayName/validateCredentials delegate to the fallback',
    () {
      final fallback = _FakeFallbackProvider();
      final composite = CompositeVideoGenerationProvider(
        stockProvider: _FakeStockVideoProvider(available: false),
        fallbackProvider: fallback,
      );

      expect(composite.providerId, fallback.providerId);
      expect(composite.displayName, fallback.displayName);
      expect(composite.validateCredentials(null), isTrue);
    },
  );
}
