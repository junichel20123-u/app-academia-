import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/video_generation/data/runway_video_generation_provider.dart';
import 'package:app_academia/features/video_generation/domain/video_generation_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

Exercise _exercise({String? instructions}) {
  return Exercise(
    id: 1,
    name: 'Supino reto com barra',
    slug: 'supino-reto-com-barra',
    muscleGroup: MuscleGroup.chest,
    equipment: Equipment.barbell,
    instructions: instructions,
    isCustom: false,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('parseRunwayTaskStatus', () {
    test('parses a SUCCEEDED status with its output url', () {
      final status = parseRunwayTaskStatus({
        'status': 'SUCCEEDED',
        'output': ['https://cdn.runway.example/result.mp4'],
      });
      expect(status.kind, VideoJobStatusKind.ready);
      expect(status.resultUrl, 'https://cdn.runway.example/result.mp4');
    });

    test('parses a FAILED status with its failure message', () {
      final status = parseRunwayTaskStatus({
        'status': 'FAILED',
        'failure': 'content moderation blocked this prompt',
      });
      expect(status.kind, VideoJobStatusKind.failed);
      expect(status.errorMessage, 'content moderation blocked this prompt');
    });

    test(
      'falls back to a generic message when FAILED has no failure field',
      () {
        final status = parseRunwayTaskStatus({'status': 'FAILED'});
        expect(status.errorMessage, 'Falha ao gerar o vídeo na Runway.');
      },
    );

    test('treats PENDING/RUNNING/unknown statuses as pending', () {
      for (final status in ['PENDING', 'RUNNING', 'THROTTLED', null]) {
        expect(
          parseRunwayTaskStatus({'status': status}).kind,
          VideoJobStatusKind.pending,
        );
      }
    });

    test('a SUCCEEDED status with an empty output list has no resultUrl', () {
      final status = parseRunwayTaskStatus({
        'status': 'SUCCEEDED',
        'output': <String>[],
      });
      expect(status.resultUrl, isNull);
    });
  });

  group('buildRunwayHeaders', () {
    test('includes the bearer token and the API version header', () {
      expect(buildRunwayHeaders('secret123'), {
        'Authorization': 'Bearer secret123',
        'X-Runway-Version': '2024-11-06',
      });
    });
  });

  group('buildRunwayImagePrompt', () {
    test('uses just the exercise name when there are no instructions', () {
      expect(
        buildRunwayImagePrompt(_exercise()),
        'Ilustração de fitness mostrando a execução do exercício: '
        'Supino reto com barra.',
      );
    });

    test('appends instructions when present', () {
      final prompt = buildRunwayImagePrompt(
        _exercise(instructions: 'Deitado no banco, barra na altura do peito.'),
      );
      expect(prompt, contains('Supino reto com barra.'));
      expect(prompt, contains('Deitado no banco, barra na altura do peito.'));
    });
  });

  group('describeRunwayError', () {
    test('prefers the error message from the response body', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/tasks/1'),
        response: Response(
          requestOptions: RequestOptions(path: '/tasks/1'),
          statusCode: 401,
          data: {'error': 'Invalid API key.'},
        ),
      );
      expect(describeRunwayError(error), 'Invalid API key.');
    });

    test('falls back to a status-code message with no parseable body', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/tasks/1'),
        response: Response(
          requestOptions: RequestOptions(path: '/tasks/1'),
          statusCode: 500,
        ),
      );
      expect(describeRunwayError(error), contains('500'));
    });
  });

  group('RunwayVideoGenerationProvider.validateCredentials', () {
    test('requires a non-empty apiKey', () {
      final provider = RunwayVideoGenerationProvider();
      expect(provider.validateCredentials({'apiKey': 'k'}), isTrue);
      expect(provider.validateCredentials(null), isFalse);
      expect(provider.validateCredentials({'apiKey': ''}), isFalse);
    });
  });
}
