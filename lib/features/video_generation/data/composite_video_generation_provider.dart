import '../../../core/database/app_database.dart';
import '../domain/video_generation_provider.dart';
import 'stock_video_provider.dart';

/// A [jobId]/[VideoJobStatus.resultUrl] value owned by this provider is
/// tagged with this prefix so `checkStatus`/`fetchResult` can tell a stock
/// video apart from whatever opaque id the wrapped [fallbackProvider]
/// issued — same idiom `RunwayVideoGenerationProvider` already uses to hide
/// its own multi-stage job id, and `MockVideoGenerationProvider` uses to
/// encode a timestamp: the field is just a string the issuing provider
/// controls, so a job started under one active provider still resolves
/// correctly even if the user later switches provider in Settings (the
/// prefix, not object identity, decides how to resolve it).
const _stockJobPrefix = 'stock:';

/// Wraps a user-configured AI [VideoGenerationProvider] with a stock-video
/// check that always runs first and needs no credentials: if the exercise
/// has a pre-hosted stock video (see `StockVideoProvider`), that's returned
/// immediately with no call to [fallbackProvider] at all; otherwise every
/// method delegates to [fallbackProvider] unchanged. This is the only
/// integration point stock videos have with the existing generation
/// pipeline — `ExerciseVideosRepository`, the `ExerciseVideos` table/DAO,
/// and the video panel widgets need no changes at all to support it.
class CompositeVideoGenerationProvider implements VideoGenerationProvider {
  CompositeVideoGenerationProvider({
    required StockVideoProvider stockProvider,
    required VideoGenerationProvider fallbackProvider,
    // Keeps the public param names distinct from the private fields.
    // ignore: prefer_initializing_formals
  }) : _stockProvider = stockProvider,
       // ignore: prefer_initializing_formals
       _fallbackProvider = fallbackProvider;

  final StockVideoProvider _stockProvider;
  final VideoGenerationProvider _fallbackProvider;

  @override
  String get providerId => _fallbackProvider.providerId;

  @override
  String get displayName => _fallbackProvider.displayName;

  @override
  Future<VideoGenerationJob> requestGeneration({
    required Exercise exercise,
    Map<String, String>? credentials,
  }) async {
    if (await _stockProvider.hasVideoFor(exercise)) {
      return VideoGenerationJob('$_stockJobPrefix${exercise.slug}');
    }
    return _fallbackProvider.requestGeneration(
      exercise: exercise,
      credentials: credentials,
    );
  }

  @override
  Future<VideoJobStatus> checkStatus({
    required String jobId,
    Map<String, String>? credentials,
  }) {
    if (jobId.startsWith(_stockJobPrefix)) {
      // Already confirmed to exist by requestGeneration — nothing to poll.
      return Future.value(
        VideoJobStatus(kind: VideoJobStatusKind.ready, resultUrl: jobId),
      );
    }
    return _fallbackProvider.checkStatus(
      jobId: jobId,
      credentials: credentials,
    );
  }

  @override
  Future<List<int>> fetchResult({
    required String resultUrl,
    Map<String, String>? credentials,
  }) {
    if (resultUrl.startsWith(_stockJobPrefix)) {
      return _stockProvider.downloadBytes(
        resultUrl.substring(_stockJobPrefix.length),
      );
    }
    return _fallbackProvider.fetchResult(
      resultUrl: resultUrl,
      credentials: credentials,
    );
  }

  @override
  bool validateCredentials(Map<String, String>? credentials) =>
      _fallbackProvider.validateCredentials(credentials);
}
