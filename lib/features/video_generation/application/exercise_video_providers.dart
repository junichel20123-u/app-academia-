import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../settings/application/user_settings_providers.dart';
import '../data/composite_video_generation_provider.dart';
import '../data/exercise_videos_repository.dart';
import '../data/provider_registry.dart';
import '../data/stock_video_provider.dart';
import '../domain/exercise_video_state.dart' as state;
import '../domain/video_generation_provider.dart';

/// Resolves `SupabaseConfig` exactly once, at this wiring boundary — see
/// `StockVideoProvider`'s doc comment for why it never reads the (untestable
/// under `flutter_test`) `SupabaseConfig` constants itself. Same idiom
/// `ai_plan_builder_providers.dart`/`template_catalog` use for their own
/// Supabase-backed repositories.
final stockVideoProviderProvider = Provider<StockVideoProvider>((ref) {
  return StockVideoProvider(
    baseUrl: SupabaseConfig.isConfigured ? SupabaseConfig.url : null,
  );
});

/// The active provider, derived from the persisted settings (provider id +
/// base URL), wrapped so a pre-hosted stock video (see `StockVideoProvider`)
/// always takes priority and needs no configuration at all — only an
/// exercise with no stock video ever actually reaches the user-configured
/// AI provider below. Falls back to Mock while settings are still loading
/// or when none was ever configured.
final videoGenerationProviderProvider = Provider<VideoGenerationProvider>((
  ref,
) {
  final settings = ref.watch(userSettingsProvider).value;
  final fallback = ProviderRegistry.create(
    settings?.videoProviderId ?? ProviderRegistry.mock.id,
    baseUrl: settings?.videoProviderBaseUrl,
  );
  return CompositeVideoGenerationProvider(
    stockProvider: ref.watch(stockVideoProviderProvider),
    fallbackProvider: fallback,
  );
});

final exerciseVideosRepositoryProvider = Provider<ExerciseVideosRepository>((
  ref,
) {
  final provider = ref.watch(videoGenerationProviderProvider);
  // The Mock/reference adapters settle almost instantly, so the default
  // 1s/30s poll/timeout keeps tests and manual MVP runs fast. A real vendor
  // call typically takes tens of seconds to a couple of minutes, so it gets
  // a much more patient budget instead.
  final isMock = provider.providerId == ProviderRegistry.mock.id;
  return ExerciseVideosRepository(
    ref.watch(appDatabaseProvider),
    provider,
    pollInterval: isMock
        ? const Duration(seconds: 1)
        : const Duration(seconds: 5),
    timeout: isMock ? const Duration(seconds: 30) : const Duration(minutes: 5),
  );
});

final exerciseVideoStateProvider = StreamProvider.autoDispose
    .family<state.ExerciseVideoState, int>((ref, exerciseId) {
      final settings = ref.watch(userSettingsProvider).value;
      final providerId = settings?.videoProviderId ?? ProviderRegistry.mock.id;
      final descriptor = ProviderRegistry.descriptorFor(providerId);

      if (descriptor.requiresApiKey) {
        final repository = ref.watch(userSettingsRepositoryProvider);
        final db = ref.watch(appDatabaseProvider);
        final stockProvider = ref.watch(stockVideoProviderProvider);
        return Stream.fromFuture(
          repository.getApiKeyFor(providerId),
        ).asyncExpand((apiKey) {
          if (apiKey != null && apiKey.isNotEmpty) {
            return _watchVideoState(ref, exerciseId);
          }
          // No AI key configured — but a stock video needs none, so an
          // exercise that has one must never be blocked by this gate.
          return Stream.fromFuture(db.exercisesDao.getExerciseById(exerciseId))
              .asyncExpand((exercise) {
                if (exercise == null) {
                  return Stream.value(const state.NotConfigured());
                }
                return Stream.fromFuture(stockProvider.hasVideoFor(exercise))
                    .asyncExpand((hasStock) {
                      if (hasStock) return _watchVideoState(ref, exerciseId);
                      return Stream.value(const state.NotConfigured());
                    });
              });
        });
      }

      return _watchVideoState(ref, exerciseId);
    });

Stream<state.ExerciseVideoState> _watchVideoState(Ref ref, int exerciseId) {
  final repo = ref.watch(exerciseVideosRepositoryProvider);
  // Fire-and-forget: resumes a generation left mid-flight (e.g. the app
  // was killed and relaunched) without blocking this stream's first
  // value, which already reflects whatever is currently in the DB.
  repo.resumePendingGeneration(exerciseId);

  return repo.watchLatestVideo(exerciseId).map<state.ExerciseVideoState>((row) {
    if (row == null) return const state.Idle();
    return switch (row.status) {
      ExerciseVideoStatus.idle => const state.Idle(),
      ExerciseVideoStatus.generating => const state.Generating(),
      ExerciseVideoStatus.ready => state.Ready(row.localFilePath!),
      ExerciseVideoStatus.failed => state.Failed(
        row.errorMessage ?? 'Erro desconhecido.',
      ),
    };
  });
}
