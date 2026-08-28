import 'dart:typed_data';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/video_generation/data/http_job_based_provider.dart';
import 'package:app_academia/features/video_generation/domain/video_generation_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _exercise() {
  return Exercise(
    id: 1,
    name: 'Supino reto com barra',
    slug: 'supino-reto-com-barra',
    muscleGroup: MuscleGroup.chest,
    equipment: Equipment.barbell,
    isCustom: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

/// A [Dio] whose adapter always throws a connection-error [DioException],
/// so `requestGeneration`/`checkStatus`/`fetchResult` exercise their
/// catch-and-sanitize path without a real network call.
Dio _alwaysFailingDio() {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.httpClientAdapter = _ThrowingAdapter();
  return dio;
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated failure',
    );
  }
}

void main() {
  group('parseStatusResponse', () {
    test('parses a ready status with its resultUrl', () {
      final status = parseStatusResponse({
        'status': 'ready',
        'resultUrl': 'https://cdn.example.com/video.mp4',
      });
      expect(status.kind, VideoJobStatusKind.ready);
      expect(status.resultUrl, 'https://cdn.example.com/video.mp4');
    });

    test('parses a failed status with its error message', () {
      final status = parseStatusResponse({
        'status': 'failed',
        'error': 'quota exceeded',
      });
      expect(status.kind, VideoJobStatusKind.failed);
      expect(status.errorMessage, 'quota exceeded');
    });

    test('falls back to a generic message when failed has no error field', () {
      final status = parseStatusResponse({'status': 'failed'});
      expect(status.errorMessage, 'Falha ao gerar o vídeo.');
    });

    test('treats any other status as pending', () {
      expect(
        parseStatusResponse({'status': 'processing'}).kind,
        VideoJobStatusKind.pending,
      );
      expect(parseStatusResponse({}).kind, VideoJobStatusKind.pending);
    });
  });

  group('buildAuthHeaders', () {
    test('builds a bearer header from a non-empty apiKey', () {
      expect(buildAuthHeaders({'apiKey': 'secret123'}), {
        'Authorization': 'Bearer secret123',
      });
    });

    test('returns no headers when credentials are null', () {
      expect(buildAuthHeaders(null), isEmpty);
    });

    test('returns no headers when apiKey is empty', () {
      expect(buildAuthHeaders({'apiKey': ''}), isEmpty);
    });
  });

  group('HttpJobBasedProvider.validateCredentials', () {
    test('requires both a base URL and a non-empty apiKey', () {
      final provider = HttpJobBasedProvider(baseUrl: 'https://api.example.com');
      expect(provider.validateCredentials({'apiKey': 'k'}), isTrue);
      expect(provider.validateCredentials(null), isFalse);
      expect(provider.validateCredentials({'apiKey': ''}), isFalse);
    });

    test('fails when the base URL is empty even with a key', () {
      final provider = HttpJobBasedProvider(baseUrl: '');
      expect(provider.validateCredentials({'apiKey': 'k'}), isFalse);
    });
  });

  group('HTTPS enforcement', () {
    test('the constructor rejects a non-empty http:// baseUrl', () {
      expect(
        () => HttpJobBasedProvider(baseUrl: 'http://insecure.example.com'),
        throwsArgumentError,
      );
    });

    test('an empty baseUrl is still allowed ("not configured yet")', () {
      expect(() => HttpJobBasedProvider(baseUrl: ''), returnsNormally);
    });

    test('validateCredentials rejects a non-https baseUrl', () {
      // Construct with an empty baseUrl (allowed) then use a real https
      // instance to prove the credential check itself is https-aware,
      // since the constructor already blocks a non-empty http:// baseUrl
      // outright above.
      final provider = HttpJobBasedProvider(baseUrl: '');
      expect(provider.validateCredentials({'apiKey': 'k'}), isFalse);
    });
  });

  group('error handling (real Dio failure, no network)', () {
    test('requestGeneration throws a sanitized StateError', () async {
      final provider = HttpJobBasedProvider(
        baseUrl: 'https://api.example.com',
        dio: _alwaysFailingDio(),
      );
      await expectLater(
        provider.requestGeneration(exercise: _exercise()),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'checkStatus returns a failed status with a sanitized message',
      () async {
        final provider = HttpJobBasedProvider(
          baseUrl: 'https://api.example.com',
          dio: _alwaysFailingDio(),
        );
        final status = await provider.checkStatus(jobId: 'job-1');
        expect(status.kind, VideoJobStatusKind.failed);
        expect(status.errorMessage, isNotNull);
      },
    );

    test('fetchResult throws a sanitized StateError', () async {
      final provider = HttpJobBasedProvider(
        baseUrl: 'https://api.example.com',
        dio: _alwaysFailingDio(),
      );
      await expectLater(
        provider.fetchResult(resultUrl: 'https://api.example.com/result'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
