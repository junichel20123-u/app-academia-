import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../data/exercise_videos_repository.dart';
import '../data/mock_video_generation_provider.dart';
import '../domain/exercise_video_state.dart' as state;
import '../domain/video_generation_provider.dart';

/// The active provider. Hardcoded to Mock for now — provider selection and
/// real API key configuration land in M8.
final videoGenerationProviderProvider = Provider<VideoGenerationProvider>((
  ref,
) {
  return MockVideoGenerationProvider();
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
      final repo = ref.watch(exerciseVideosRepositoryProvider);
      // Fire-and-forget: resumes a generation left mid-flight (e.g. the app
      // was killed and relaunched) without blocking this stream's first
      // value, which already reflects whatever is currently in the DB.
      repo.resumePendingGeneration(exerciseId);

      return repo.watchLatestVideo(exerciseId).map<state.ExerciseVideoState>((
        row,
      ) {
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
    });
