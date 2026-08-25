import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/enum_labels.dart';
import '../../video_generation/presentation/widgets/video_status_panel.dart';
import '../application/exercises_providers.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final int exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercício')),
      body: exercisesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (exercises) {
          final matches = exercises.where((e) => e.id == exerciseId);
          if (matches.isEmpty) {
            return const Center(child: Text('Exercício não encontrado.'));
          }
          final exercise = matches.first;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    muscleGroupLabel(exercise.muscleGroup),
                    if (exercise.equipment != null)
                      equipmentLabel(exercise.equipment!),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (exercise.instructions != null) ...[
                  const SizedBox(height: 12),
                  Text(exercise.instructions!),
                ],
                const SizedBox(height: 24),
                Text(
                  'Vídeo de execução',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                VideoStatusPanel(exercise: exercise),
              ],
            ),
          );
        },
      ),
    );
  }
}
