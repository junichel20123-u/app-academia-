import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../domain/video_generation_provider.dart';
import 'dio_error_message.dart';

const _baseUrl = 'https://api.dev.runwayml.com/v1';
const _apiVersion = '2024-11-06';

/// Parses a Runway `/tasks/{id}` response into a [VideoJobStatus]. Pulled
/// out as a standalone function, same pattern as
/// `http_job_based_provider.dart`'s `parseStatusResponse`, so a field-name
/// mismatch against the real API (this shape wasn't verified against
/// Runway's live docs — see the M9 plan note) is a one-place fix, not a
/// rewrite.
VideoJobStatus parseRunwayTaskStatus(Map<String, dynamic> json) {
  final status = json['status'] as String?;
  return switch (status) {
    'SUCCEEDED' => VideoJobStatus(
      kind: VideoJobStatusKind.ready,
      resultUrl: _firstOutputUrl(json['output']),
    ),
    'FAILED' => VideoJobStatus(
      kind: VideoJobStatusKind.failed,
      errorMessage:
          json['failure'] as String? ?? 'Falha ao gerar o vídeo na Runway.',
    ),
    _ => const VideoJobStatus(kind: VideoJobStatusKind.pending),
  };
}

String? _firstOutputUrl(Object? output) {
  if (output is List && output.isNotEmpty && output.first is String) {
    return output.first as String;
  }
  return null;
}

Map<String, String> buildRunwayHeaders(String apiKey) => {
  'Authorization': 'Bearer $apiKey',
  'X-Runway-Version': _apiVersion,
};

/// Builds the image prompt for an exercise: name plus instructions, when
/// present.
String buildRunwayImagePrompt(Exercise exercise) {
  final instructions = exercise.instructions;
  final base =
      'Ilustração de fitness mostrando a execução do exercício: '
      '${exercise.name}.';
  return instructions == null || instructions.isEmpty
      ? base
      : '$base $instructions';
}

/// Turns a Dio error into a user-facing message, preferring whatever the
/// API's own error payload says over a generic status-code message. Thin
/// wrapper over the shared [describeDioError] — kept as a named function
/// (rather than inlining the call everywhere) since it's already exported
/// and unit-tested by name.
String describeRunwayError(DioException error) =>
    describeDioError(error, genericMessage: 'Erro ao comunicar com a Runway');

/// Real text-to-video vendor: chains Runway's `text_to_image` (turns the
/// exercise name/instructions into a still image) and `image_to_video`
/// (Gen-4 Turbo animates that image) endpoints. Only the video task is
/// exposed as the [VideoGenerationJob] — `ExerciseVideosRepository`'s
/// existing polling/resume machinery only ever sees a single job, exactly
/// like the Mock/HttpJobBasedProvider adapters.
///
/// Known limitation: if the app is killed while [requestGeneration] is
/// still polling the image sub-step (before the video task exists), that
/// attempt has no `jobId` yet and isn't picked up by
/// `resumePendingGeneration` — the user just retries. Fully resumable
/// multi-stage jobs would need `VideoJobStatus`/`ExerciseVideosRepository`
/// to support a job handing off to a new id mid-flight, which isn't worth
/// the complexity for an optional demo-video feature.
class RunwayVideoGenerationProvider implements VideoGenerationProvider {
  RunwayVideoGenerationProvider({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  String get providerId => 'runway';

  @override
  String get displayName => 'Runway (Gen-4 Turbo)';

  @override
  Future<VideoGenerationJob> requestGeneration({
    required Exercise exercise,
    Map<String, String>? credentials,
  }) async {
    final headers = buildRunwayHeaders(_requireApiKey(credentials));
    try {
      final imageTaskId = await _createTask(
        path: '/text_to_image',
        body: {
          'promptText': buildRunwayImagePrompt(exercise),
          'model': 'gen4_image',
          'ratio': '1280:720',
        },
        headers: headers,
      );
      final imageUrl = await _pollImageUntilReady(imageTaskId, headers);

      final videoTaskId = await _createTask(
        path: '/image_to_video',
        body: {
          'promptImage': imageUrl,
          'model': 'gen4_turbo',
          'ratio': '1280:720',
          'duration': 5,
        },
        headers: headers,
      );
      return VideoGenerationJob(videoTaskId);
    } on DioException catch (e) {
      throw StateError(describeRunwayError(e));
    }
  }

  Future<String> _createTask({
    required String path,
    required Map<String, dynamic> body,
    required Map<String, String> headers,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl$path',
      data: body,
      options: Options(headers: headers),
    );
    return response.data!['id'] as String;
  }

  /// Blocks until the `text_to_image` sub-step settles. Not exposed through
  /// [checkStatus]/[VideoGenerationJob] — see the class-level doc comment
  /// on why this sub-step isn't independently resumable.
  Future<String> _pollImageUntilReady(
    String taskId,
    Map<String, String> headers,
  ) async {
    const pollInterval = Duration(seconds: 3);
    final deadline = DateTime.now().add(const Duration(minutes: 2));
    while (true) {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/tasks/$taskId',
        options: Options(headers: headers),
      );
      final status = parseRunwayTaskStatus(response.data!);
      switch (status.kind) {
        case VideoJobStatusKind.ready:
          return status.resultUrl!;
        case VideoJobStatusKind.failed:
          throw StateError(
            status.errorMessage ?? 'Falha ao gerar a imagem do exercício.',
          );
        case VideoJobStatusKind.pending:
          if (DateTime.now().isAfter(deadline)) {
            throw StateError('Tempo esgotado ao gerar a imagem do exercício.');
          }
          await Future<void>.delayed(pollInterval);
      }
    }
  }

  @override
  Future<VideoJobStatus> checkStatus({
    required String jobId,
    Map<String, String>? credentials,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/tasks/$jobId',
        options: Options(
          headers: buildRunwayHeaders(_requireApiKey(credentials)),
        ),
      );
      return parseRunwayTaskStatus(response.data!);
    } on DioException catch (e) {
      return VideoJobStatus(
        kind: VideoJobStatusKind.failed,
        errorMessage: describeRunwayError(e),
      );
    }
  }

  @override
  Future<List<int>> fetchResult({
    required String resultUrl,
    Map<String, String>? credentials,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        resultUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data!;
    } on DioException catch (e) {
      throw StateError(describeRunwayError(e));
    }
  }

  @override
  bool validateCredentials(Map<String, String>? credentials) {
    return credentials?['apiKey']?.isNotEmpty ?? false;
  }

  String _requireApiKey(Map<String, String>? credentials) {
    final apiKey = credentials?['apiKey'];
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('Runway requer uma chave de API configurada.');
    }
    return apiKey;
  }
}
