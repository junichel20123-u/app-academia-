import '../../../core/database/app_database.dart';
import '../domain/video_generation_provider.dart';

/// Simulated provider used before a real one is wired in (M9). No API key
/// required. Useful for exercising the full generation state machine and
/// UI without any network dependency.
///
/// Deliberately stateless: the job's start time is encoded in the jobId
/// itself (rather than kept in an instance field), so `checkStatus` gives
/// the same answer whether it's called right after `requestGeneration` or
/// after the app was killed and relaunched mid-generation.
class MockVideoGenerationProvider implements VideoGenerationProvider {
  MockVideoGenerationProvider({
    this.alwaysFail = false,
    this.generationDelay = const Duration(seconds: 2),
  });

  /// When true, every job reports failure once [generationDelay] elapses —
  /// used to exercise the Failed+Retry UI path.
  final bool alwaysFail;
  final Duration generationDelay;

  @override
  String get providerId => 'mock';

  @override
  String get displayName => 'Mock (para testes)';

  @override
  Future<VideoGenerationJob> requestGeneration({
    required Exercise exercise,
    Map<String, String>? credentials,
  }) async {
    final jobId = 'mock-${DateTime.now().millisecondsSinceEpoch}';
    return VideoGenerationJob(jobId);
  }

  @override
  Future<VideoJobStatus> checkStatus({
    required String jobId,
    Map<String, String>? credentials,
  }) async {
    final startedAtMs = int.tryParse(jobId.split('-').last);
    final startedAt = startedAtMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startedAtMs)
        : DateTime.now();

    if (DateTime.now().difference(startedAt) < generationDelay) {
      return const VideoJobStatus(kind: VideoJobStatusKind.pending);
    }
    if (alwaysFail) {
      return const VideoJobStatus(
        kind: VideoJobStatusKind.failed,
        errorMessage: 'Falha simulada (modo de teste).',
      );
    }
    return VideoJobStatus(
      kind: VideoJobStatusKind.ready,
      resultUrl: 'mock://$jobId',
    );
  }

  @override
  Future<List<int>> fetchResult({
    required String resultUrl,
    Map<String, String>? credentials,
  }) async {
    // Placeholder bytes standing in for a real generated video. Not a
    // decodable video file — the player UI handles that gracefully. Once a
    // real provider is wired in (M9), this returns actual video bytes.
    return List<int>.filled(256, 0);
  }
}
