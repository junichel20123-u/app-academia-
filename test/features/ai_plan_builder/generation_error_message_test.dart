import 'package:app_academia/features/ai_plan_builder/data/ai_plan_builder_repository.dart';
import 'package:app_academia/features/ai_plan_builder/presentation/generation_error_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('describeGenerationError', () {
    test('uses a StateError\'s own message, without the "Bad state: " '
        'prefix its toString() would add', () {
      final error = StateError('Nenhum exercício disponível.');
      expect(describeGenerationError(error), 'Nenhum exercício disponível.');
    });

    test('gives a friendly message for an unresolved-slug plan', () {
      final error = UnresolvedPlanExercisesException(['ghost-exercise']);
      expect(
        describeGenerationError(error),
        contains('exercícios que não reconhecemos'),
      );
    });

    test(
      'reports a connection error as an offline hint, not a stack trace',
      () {
        final error = DioException(
          requestOptions: RequestOptions(path: '/generate-plan'),
          type: DioExceptionType.connectionError,
          error: 'Failed host lookup',
        );
        expect(describeGenerationError(error), contains('Sem conexão'));
        expect(
          describeGenerationError(error),
          isNot(contains('SocketException')),
        );
      },
    );

    test('reports a timeout distinctly from a generic connection error', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/generate-plan'),
        type: DioExceptionType.receiveTimeout,
      );
      expect(describeGenerationError(error), contains('demorou demais'));
    });

    test('includes the HTTP status code for a bad response', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/generate-plan'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/generate-plan'),
          statusCode: 502,
        ),
      );
      expect(describeGenerationError(error), contains('502'));
    });

    // The Edge Functions answer a failure with `{ error, kind }`. Naming
    // the cause is the whole point: a bare "erro (502)" sent every
    // diagnosis through the Supabase dashboard logs.
    test('names the cause when the response carries a kind', () {
      DioException withKind(String kind) => DioException(
        requestOptions: RequestOptions(path: '/generate-plan'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/generate-plan'),
          statusCode: 502,
          data: {'error': 'Falha ao gerar o plano.', 'kind': kind},
        ),
      );

      expect(describeGenerationError(withKind('auth')), contains('credencial'));
      expect(
        describeGenerationError(withKind('timeout')),
        contains('demorou demais'),
      );
      expect(
        describeGenerationError(withKind('rate_limited')),
        contains('limite de uso'),
      );
      expect(
        describeGenerationError(withKind('unavailable')),
        contains('indisponível'),
      );
      expect(
        describeGenerationError(withKind('invalid_response')),
        contains('formato'),
      );
    });

    // A function deployed before `kind` existed, or a failure raised
    // before it runs at all, must still produce something actionable.
    test('falls back to the status code for an unknown or absent kind', () {
      DioException withData(Object? data) => DioException(
        requestOptions: RequestOptions(path: '/generate-plan'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/generate-plan'),
          statusCode: 503,
          data: data,
        ),
      );

      expect(describeGenerationError(withData(null)), contains('503'));
      expect(
        describeGenerationError(withData({'error': 'x', 'kind': 'unknown'})),
        contains('503'),
      );
      expect(describeGenerationError(withData('texto solto')), contains('503'));
    });

    test('falls back to a generic message for anything else', () {
      expect(
        describeGenerationError(Exception('something unexpected')),
        'Falha ao gerar o plano. Tente novamente.',
      );
    });
  });
}
