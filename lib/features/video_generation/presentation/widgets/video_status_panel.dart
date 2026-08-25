import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../application/exercise_video_providers.dart';
import '../../domain/exercise_video_state.dart' as state;
import 'exercise_video_player.dart';

/// Renders the exercise-video state machine: NotConfigured/Idle/Generating/
/// Ready/Failed, driving [exerciseVideoStateProvider].
class VideoStatusPanel extends ConsumerWidget {
  const VideoStatusPanel({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(exerciseVideoStateProvider(exercise.id));

    return stateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Erro: $err'),
      data: (videoState) {
        return switch (videoState) {
          state.NotConfigured() => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Configure um provedor de vídeo em Configurações.'),
            ],
          ),
          state.Idle() => FilledButton.icon(
            icon: const Icon(Icons.videocam),
            label: const Text('Gerar vídeo'),
            onPressed: () =>
                ref.read(exerciseVideosRepositoryProvider).generate(exercise),
          ),
          state.Generating() => const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Gerando vídeo...'),
            ],
          ),
          state.Ready(:final filePath) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExerciseVideoPlayer(filePath: filePath),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Regenerar'),
                onPressed: () => ref
                    .read(exerciseVideosRepositoryProvider)
                    .generate(exercise),
              ),
            ],
          ),
          state.Failed(:final message) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Falha: $message'),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                onPressed: () => ref
                    .read(exerciseVideosRepositoryProvider)
                    .generate(exercise),
              ),
            ],
          ),
        };
      },
    );
  }
}
