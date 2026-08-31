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
      DioExceptionType.badResponse => _describeBadResponse(error),
      _ => 'Falha de conexão. Verifique sua internet e tente novamente.',
    };
  }
  return 'Falha ao gerar o plano. Tente novamente.';
}

/// Names the actual cause when the Edge Function reports one.
///
/// The functions answer a failure with `{ error, kind }`, where `kind` is
/// the sanitized error category (`auth`, `timeout`, ...) — never the
/// provider's raw message, which could carry request details. Reading it
/// here is what lets someone act on the failure: a bare "erro (502)" sent
/// every diagnosis through the Supabase logs, which is exactly the loop
/// this avoids. Falls back to the status code when `kind` is absent —
/// an older deployed function, or an error raised before it runs at all.
String _describeBadResponse(DioException error) {
  final data = error.response?.data;
  final kind = data is Map ? data['kind'] : null;
  return switch (kind) {
    'auth' =>
      'O serviço de IA recusou nossa credencial. Isso é uma configuração '
          'do app, não algo que você possa resolver — reporte o problema.',
    'timeout' =>
      'O serviço de IA demorou demais para responder. Tente novamente.',
    'rate_limited' =>
      'O serviço de IA atingiu o limite de uso por agora. Tente de novo '
          'daqui a alguns minutos.',
    'unavailable' =>
      'O serviço de IA está indisponível no momento. Tente novamente '
          'mais tarde.',
    'invalid_response' =>
      'O serviço de IA respondeu em um formato que não conseguimos ler. '
          'Tente novamente.',
    _ =>
      'O servidor retornou um erro '
          '(${error.response?.statusCode ?? '?'}). Tente novamente '
          'mais tarde.',
  };
}
