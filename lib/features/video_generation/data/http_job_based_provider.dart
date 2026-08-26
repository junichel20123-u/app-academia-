import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';
import '../domain/video_generation_provider.dart';

/// Parses a job-status JSON payload shaped `{"status": ..., "resultUrl": ...,
/// "error": ...}` into a [VideoJobStatus]. Pulled out as a standalone
/// function so it's testable without a real HTTP round trip.
VideoJobStatus parseStatusResponse(Map<String, dynamic> json) {
  final status = json['status'] as String?;
  return switch (status) {
    'ready' => VideoJobStatus(
      kind: VideoJobStatusKind.ready,
      resultUrl: json['resultUrl'] as String?,
    ),
    'failed' => VideoJobStatus(
      kind: VideoJobStatusKind.failed,
      errorMessage: json['error'] as String? ?? 'Falha ao gerar o vídeo.',
    ),
    _ => const VideoJobStatus(kind: VideoJobStatusKind.pending),
  };
}

/// Builds the bearer-auth header from the `apiKey` credential, if present.
Map<String, String> buildAuthHeaders(Map<String, String>? credentials) {
  final apiKey = credentials?['apiKey'];
  return apiKey == null || apiKey.isEmpty
      ? const {}
      : {'Authorization': 'Bearer $apiKey'};
}

/// Reference adapter showing the shape of a real job-based text-to-video
/// API: POST to start a job, GET to poll it, GET to download the result.
/// Not wired to any specific vendor — that's a post-MVP milestone (M9);
/// this exists so adding a real provider means registering a class like
/// this one, not touching the rest of the app.
class HttpJobBasedProvider implements VideoGenerationProvider {
  HttpJobBasedProvider({required this.baseUrl, Dio? dio}) : _dio = dio ?? Dio();

  final String baseUrl;
  final Dio _dio;

  @override
  String get providerId => 'http_custom';

  @override
  String get displayName => 'Provedor HTTP customizado';

  @override
  Future<VideoGenerationJob> requestGeneration({
    required Exercise exercise,
    Map<String, String>? credentials,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/generate',
      data: {'exerciseName': exercise.name},
      options: Options(headers: buildAuthHeaders(credentials)),
    );
    return VideoGenerationJob(response.data!['jobId'] as String);
  }

  @override
  Future<VideoJobStatus> checkStatus({
    required String jobId,
    Map<String, String>? credentials,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$baseUrl/jobs/$jobId',
      options: Options(headers: buildAuthHeaders(credentials)),
    );
    return parseStatusResponse(response.data!);
  }

  @override
  Future<List<int>> fetchResult({
    required String resultUrl,
    Map<String, String>? credentials,
  }) async {
    final response = await _dio.get<List<int>>(
      resultUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: buildAuthHeaders(credentials),
      ),
    );
    return response.data!;
  }

  @override
  bool validateCredentials(Map<String, String>? credentials) {
    return baseUrl.isNotEmpty && (credentials?['apiKey']?.isNotEmpty ?? false);
  }
}
