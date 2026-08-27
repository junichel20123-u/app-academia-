import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/empty_state.dart';
import '../../exercises/application/exercises_providers.dart';
import '../../exercises/presentation/widgets/exercise_picker_sheet.dart';
import '../application/workouts_providers.dart';
import 'widgets/exercise_targets_dialog.dart';
import 'widgets/workout_exercise_row.dart';

class WorkoutEditScreen extends ConsumerStatefulWidget {
  const WorkoutEditScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  ConsumerState<WorkoutEditScreen> createState() => _WorkoutEditScreenState();
}

class _WorkoutEditScreenState extends ConsumerState<WorkoutEditScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  bool _controllersInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveName() {
    final workout = ref.read(workoutByIdProvider(widget.workoutId)).value;
    if (workout == null) return;
    ref
        .read(workoutsRepositoryProvider)
        .renameWorkout(
          workout,
          name: _nameController.text.trim().isEmpty
              ? 'Treino sem nome'
              : _nameController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );
  }

  Future<void> _addExercise(List<WorkoutExercise> existingEntries) async {
    final exercise = await showExercisePickerSheet(context);
    if (exercise == null || !mounted) return;
    final targets = await showExerciseTargetsDialog(context);
    if (targets == null) return;
    await ref
        .read(workoutsRepositoryProvider)
        .addExerciseToWorkout(
          workoutId: widget.workoutId,
          exerciseId: exercise.id,
          orderIndex: existingEntries.length,
          targetSets: targets.sets,
          targetReps: targets.reps,
          targetWeight: targets.weight,
          targetRestSeconds: targets.restSeconds,
        );
  }

  @override
  Widget build(BuildContext context) {
    final workoutAsync = ref.watch(workoutByIdProvider(widget.workoutId));
    final entriesAsync = ref.watch(workoutExercisesProvider(widget.workoutId));
    final exercisesAsync = ref.watch(exercisesListProvider);

    ref.listen(workoutByIdProvider(widget.workoutId), (previous, next) {
      final workout = next.value;
      if (workout != null && !_controllersInitialized) {
        _nameController.text = workout.name;
        _notesController.text = workout.notes ?? '';
        _controllersInitialized = true;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Editar treino')),
      body: workoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (workout) {
          if (workout == null) {
            return const Center(child: Text('Treino não encontrado.'));
          }
          if (!_controllersInitialized) {
            _nameController.text = workout.name;
            _notesController.text = workout.notes ?? '';
            _controllersInitialized = true;
          }

          final exercisesById = {
            for (final e in exercisesAsync.value ?? []) e.id: e,
          };

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do treino',
                  ),
                  onEditingComplete: _saveName,
                  onTapOutside: (_) => _saveName(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                  ),
                  onEditingComplete: _saveName,
                  onTapOutside: (_) => _saveName(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Exercícios',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Expanded(
                  child: entriesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Erro: $err')),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return const EmptyState(
                          icon: Icons.playlist_add,
                          title: 'Nenhum exercício adicionado ainda.',
                        );
                      }
                      return ReorderableListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final exerciseName =
                              exercisesById[entry.exerciseId]?.name ??
                              'Exercício';
                          return WorkoutExerciseRow(
                            key: ValueKey(entry.id),
                            entry: entry,
                            exerciseName: exerciseName,
                            onEditTargets: () async {
                              final targets = await showExerciseTargetsDialog(
                                context,
                                initial: ExerciseTargets(
                                  sets: entry.targetSets,
                                  reps: entry.targetReps,
                                  weight: entry.targetWeight,
                                  restSeconds: entry.targetRestSeconds,
                                ),
                              );
                              if (targets == null) return;
                              await ref
                                  .read(workoutsRepositoryProvider)
                                  .updateWorkoutExercise(
                                    entry.copyWith(
                                      targetSets: targets.sets,
                                      targetReps: Value(targets.reps),
                                      targetWeight: Value(targets.weight),
                                      targetRestSeconds: Value(
                                        targets.restSeconds,
                                      ),
                                    ),
                                  );
                            },
                            onRemove: () => ref
                                .read(workoutsRepositoryProvider)
                                .removeWorkoutExercise(entry),
                          );
                        },
                        onReorderItem: (oldIndex, newIndex) {
                          final newList = [...entries];
                          final moved = newList.removeAt(oldIndex);
                          newList.insert(newIndex, moved);
                          ref
                              .read(workoutsRepositoryProvider)
                              .reorderExercises(newList);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar exercício'),
                  onPressed: () => _addExercise(entriesAsync.value ?? const []),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
