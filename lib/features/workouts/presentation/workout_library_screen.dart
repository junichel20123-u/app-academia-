import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sessions/application/sessions_providers.dart';
import '../application/workouts_providers.dart';

class WorkoutLibraryScreen extends ConsumerWidget {
  const WorkoutLibraryScreen({super.key});

  Future<void> _createWorkout(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Novo treino'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Nome do treino'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
    if (name == null || name.isEmpty || !context.mounted) return;

    final id = await ref
        .read(workoutsRepositoryProvider)
        .createWorkout(name: name);
    if (context.mounted) context.push('/workouts/$id');
  }

  Future<void> _duplicateWorkout(WidgetRef ref, Workout workout) {
    return ref
        .read(workoutsRepositoryProvider)
        .duplicateWorkout(workout.id, newName: '${workout.name} (cópia)');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Workout workout,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir treino?'),
        content: Text('"${workout.name}" será removido permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(workoutsRepositoryProvider).deleteWorkout(workout.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meus treinos')),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (workouts) {
          if (workouts.isEmpty) {
            return const EmptyState(
              icon: Icons.fitness_center,
              title: 'Nenhum treino ainda. Toque em + para criar.',
            );
          }
          return ListView.builder(
            itemCount: workouts.length,
            itemBuilder: (context, index) {
              final workout = workouts[index];
              final exerciseCount = ref.watch(
                workoutExercisesProvider(workout.id),
              );
              return TweenAnimationBuilder<double>(
                key: ValueKey(workout.id),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: ListTile(
                  title: Text(workout.name),
                  subtitle: Text(
                    exerciseCount.maybeWhen(
                      data: (entries) => '${entries.length} exercício(s)',
                      orElse: () => '...',
                    ),
                  ),
                  onTap: () => context.push('/workouts/${workout.id}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Iniciar',
                        onPressed: () async {
                          final id = await ref
                              .read(sessionsRepositoryProvider)
                              .startSessionFromWorkout(workout);
                          if (context.mounted) {
                            context.push('/sessions/$id');
                          }
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (action) {
                          switch (action) {
                            case 'duplicate':
                              _duplicateWorkout(ref, workout);
                            case 'delete':
                              _confirmDelete(context, ref, workout);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'duplicate',
                            child: Text('Duplicar'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Excluir'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createWorkout(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
