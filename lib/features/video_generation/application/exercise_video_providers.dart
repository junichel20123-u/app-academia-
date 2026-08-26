import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../../settings/application/user_settings_providers.dart';
import '../data/exercise_videos_repository.dart';
import '../data/provider_registry.dart';
import '../domain/exercise_video_state.dart' as state;
import '../domain/video_generation_provider.dart';

/// The active provider, derived from the persisted settings (provider id +
/// base URL). Falls back to Mock while settings are still loading or when
/// none was ever configured.
final videoGenerationProviderProvider = Provider<VideoGenerationProvider>((
  ref,
) {
  final settings = ref.watch(userSettingsProvider).value;
  return ProviderRegistry.create(
    settings?.videoProviderId ?? ProviderRegistry.mock.id,
    baseUrl: settings?.videoProviderBaseUrl,
  );
});

final exerciseVideosRepositoryProvider = Provider<ExerciseVideosRepository>((
  ref,
) {
  return ExerciseVideosRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(videoGenerationProviderProvider),
  );
});

final exerciseVideoStateProvider = StreamProvider.autoDispose
    .family<state.ExerciseVideoState, int>((ref, exerciseId) {
      final settings = ref.watch(userSettingsProvider).value;
      final providerId = settings?.videoProviderId ?? ProviderRegistry.mock.id;
      final descriptor = ProviderRegistry.descriptorFor(providerId);

      if (descriptor.requiresApiKey) {
        final repository = ref.watch(userSettingsRepositoryProvider);
        return Stream.fromFuture(repository.getApiKeyFor(providerId))
            .asyncExpand((apiKey) {
              if (apiKey == null || apiKey.isEmpty) {
                return Stream.value(const state.NotConfigured());
              }
              return _watchVideoState(ref, exerciseId);
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
