import 'package:dio/dio.dart';

import '../../../core/database/app_database.dart';

/// Builds the public object URL for a stock exercise video in the
/// `exercise-videos` Supabase Storage bucket (see
/// `supabase/migrations/..._create_exercise_videos_bucket.sql` and
/// `tools/exercise_videos/upload_to_supabase.py`, which is what actually
/// populates it). Pulled out as a standalone function so it's testable
/// without touching `Dio` at all, same pattern as `parseStatusResponse`/
/// `buildAuthHeaders` elsewhere in this feature.
String buildStockVideoUrl(String baseUrl, String slug) =>
    '$baseUrl/storage/v1/object/public/exercise-videos/$slug.mp4';

/// Checks whether a pre-hosted stock video exists for an exercise (keyed by
/// its stable `slug`, never the local autoincrement id) and downloads it.
///
/// Deliberately takes [baseUrl] as a constructor parameter instead of
/// reading `SupabaseConfig` internally: `SupabaseConfig.url` is a compile-
/// time `String.fromEnvironment` constant that is always empty under
/// `flutter_test` (no `--dart-define` is passed to the test binary) with no
/// way to override it, so a class that read it directly could never be
/// unit-tested in its "configured" branch. Resolving `SupabaseConfig.url`
/// happens once, at the Riverpod-provider wiring site
/// (`exercise_video_providers.dart`) — the same shape already used by
/// `AiPlanBuilderRepository`/`TemplateCatalogRepository`.
class StockVideoProvider {
  StockVideoProvider({
    required String? baseUrl,
    Dio? dio,
    // Keeps the public param name `baseUrl` distinct from `_baseUrl`.
    // ignore: prefer_initializing_formals
  }) : _baseUrl = baseUrl,
       // A plain `Dio()` never times out on its own — a stalled connection
       // would hang the video panel indefinitely instead of just falling
       // through to the AI-generation fallback.
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 8),
               sendTimeout: const Duration(seconds: 8),
               receiveTimeout: const Duration(seconds: 30),
             ),
           );

  final String? _baseUrl;
  final Dio _dio;

  /// `false` when Supabase isn't configured for this build, the exercise
  /// has no stable slug (custom exercises never do), or the object simply
  /// doesn't exist (no `chosen.mp4` was ever uploaded for it) — any of
  /// these just means "fall back to AI generation," never an error.
  Future<bool> hasVideoFor(Exercise exercise) async {
    final baseUrl = _baseUrl;
    final slug = exercise.slug;
    if (baseUrl == null || slug == null) return false;

    try {
      final response = await _dio.head<void>(buildStockVideoUrl(baseUrl, slug));
      final status = response.statusCode;
      return status != null && status >= 200 && status < 300;
    } on DioException {
      return false;
    }
  }

  /// Downloads the stock video's raw bytes. Only meant to be called after
  /// [hasVideoFor] already confirmed the object exists — errors here
  /// propagate, same as every other provider's `fetchResult` today.
  Future<List<int>> downloadBytes(String slug) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      throw StateError('Supabase não configurado neste build.');
    }
    final response = await _dio.get<List<int>>(
      buildStockVideoUrl(baseUrl, slug),
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? const [];
  }
}
