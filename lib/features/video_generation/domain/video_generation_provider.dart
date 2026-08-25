import '../../../core/database/app_database.dart';

class VideoGenerationJob {
  const VideoGenerationJob(this.jobId);

  final String jobId;
}

enum VideoJobStatusKind { pending, ready, failed }

class VideoJobStatus {
  const VideoJobStatus({required this.kind, this.resultUrl, this.errorMessage});

  final VideoJobStatusKind kind;
  final String? resultUrl;
  final String? errorMessage;
}

/// A pluggable text-to-video generation backend. Implementations are
/// expected to be async/job-based (the common shape for these APIs): start
/// a job, poll it, then fetch the finished asset once ready. A provider
/// whose API happens to be synchronous can simply resolve immediately.
abstract class VideoGenerationProvider {
  String get providerId;

  String get displayName;

  Future<VideoGenerationJob> requestGeneration({
    required Exercise exercise,
    Map<String, String>? credentials,
  });

  Future<VideoJobStatus> checkStatus({
    required String jobId,
    Map<String, String>? credentials,
  });

  Future<List<int>> fetchResult({
    required String resultUrl,
    Map<String, String>? credentials,
  });
}
