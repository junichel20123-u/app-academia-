import 'package:dio/dio.dart';

import '../data/ai_plan_builder_repository.dart';

/// Turns whatever `generatePlan()` throws into a message someone can
/// actually act on — the raw exception (e.g. a `DioException`'s technical
/// `SocketException: Failed host lookup: ...` text) isn't useful to an end
/// user, and `StateError.toString()`/`Error.toString()` prepend
/// "Bad state: "/the class name, which reads as a crash even though these
/// specific messages were already written to be user-facing.
String describeGenerationError(Object error) {
  if (error is StateError) return error.message;
  if (error is UnresolvedPlanExercisesException) {
    return 'O plano gerado incluiu exercícios que não reconhecemos. '
        'Tente novamente.';
  }
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionError =>
        'Sem conexão com a internet. Verifique o Wi-Fi ou os dados '
            'móveis e tente novamente.',
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'A conexão demorou demais para responder. Tente novamente.',
      DioExceptionType.badResponse =>
        'O servidor retornou um erro '
            '(${error.response?.statusCode ?? '?'}). Tente novamente '
            'mais tarde.',
      _ => 'Falha de conexão. Verifique sua internet e tente novamente.',
    };
  }
  return 'Falha ao gerar o plano. Tente novamente.';
}
