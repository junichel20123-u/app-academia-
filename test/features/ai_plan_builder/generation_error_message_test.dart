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

    test('falls back to a generic message for anything else', () {
      expect(
        describeGenerationError(Exception('something unexpected')),
        'Falha ao gerar o plano. Tente novamente.',
      );
    });
  });
}
