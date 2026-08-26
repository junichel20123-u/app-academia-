import 'package:app_academia/features/video_generation/data/http_job_based_provider.dart';
import 'package:app_academia/features/video_generation/domain/video_generation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
