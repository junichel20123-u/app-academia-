import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../exercises/application/exercises_providers.dart';
import '../../exercises/presentation/widgets/exercise_picker_sheet.dart';
import '../../workouts/application/workouts_providers.dart';
import '../application/session_exercise_groups.dart';
import '../application/sessions_providers.dart';
import 'widgets/log_set_dialog.dart';
import 'widgets/session_exercise_card.dart';

class ActiveSessionScreen extends ConsumerWidget {
  const ActiveSessionScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionByIdProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Sessão de treino')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('Sessão não encontrada.'));
          }
          final editable = session.status == WorkoutSessionStatus.inProgress;
          final workoutId = session.workoutId;
          final templateEntriesAsync = workoutId == null
              ? const AsyncValue<List<WorkoutExercise>>.data(
                  <WorkoutExercise>[],
                )
              : ref.watch(workoutExercisesProvider(workoutId));
          final setsAsync = ref.watch(sessionSetsProvider(sessionId));
          final exercisesAsync = ref.watch(exercisesListProvider);

          if (templateEntriesAsync.isLoading ||
              setsAsync.isLoading ||
              exercisesAsync.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final templateEntries = templateEntriesAsync.value ?? const [];
          final sets = setsAsync.value ?? const [];
          final exercisesById = {
            for (final e in exercisesAsync.value ?? []) e.id: e,
          };

          final groups = buildSessionExerciseGroups(
            templateEntries: templateEntries,
            loggedSets: sets,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (!editable)
                      Chip(
                        label: Text(
                          session.status == WorkoutSessionStatus.completed
                              ? 'Concluída'
                              : 'Abandonada',
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: groups.isEmpty
                    ? const Center(
                        child: Text('Nenhum exercício registrado ainda.'),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          for (final group in groups)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SessionExerciseCard(
                                group: group,
                                exerciseName:
                                    exercisesById[group.exerciseId]?.name ??
                                    'Exercício',
                                editable: editable,
                                onAddSet: () => _logSet(
                                  context,
                                  ref,
                                  exerciseId: group.exerciseId,
                                  workoutExerciseId: group.workoutExerciseId,
                                  setNumber: group.loggedSets.length + 1,
                                  defaultReps: group.targetReps,
                                  defaultWeight: group.targetWeight,
                                ),
                                onEditSet: (set) => _editSet(context, ref, set),
                                onDeleteSet: (set) => ref
                                    .read(sessionsRepositoryProvider)
                                    .deleteLoggedSet(set.id),
                              ),
                            ),
                        ],
                      ),
              ),
              if (editable)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar exercício'),
                          onPressed: () => _addExercise(context, ref),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            await ref
                                .read(sessionsRepositoryProvider)
                                .completeSession(sessionId);
                            if (context.mounted) Navigator.of(context).pop();
                          },
                          child: const Text('Finalizar'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logSet(
    BuildContext context,
    WidgetRef ref, {
    required int exerciseId,
    required int? workoutExerciseId,
    required int setNumber,
    int? defaultReps,
    double? defaultWeight,
  }) async {
    final input = await showLogSetDialog(
      context,
      initial: LoggedSetInput(reps: defaultReps, weight: defaultWeight),
    );
    if (input == null) return;
    await ref
        .read(sessionsRepositoryProvider)
        .logSet(
          sessionId: sessionId,
          exerciseId: exerciseId,
          workoutExerciseId: workoutExerciseId,
          setNumber: setNumber,
          weight: input.weight,
          reps: input.reps,
          rpe: input.rpe,
          notes: input.notes,
        );
  }

  Future<void> _editSet(
    BuildContext context,
    WidgetRef ref,
    LoggedSet set,
  ) async {
    final input = await showLogSetDialog(
      context,
      title: 'Editar série',
      initial: LoggedSetInput(
        weight: set.weight,
        reps: set.reps,
        rpe: set.rpe,
        notes: set.notes,
      ),
    );
    if (input == null) return;
    await ref
        .read(sessionsRepositoryProvider)
        .updateLoggedSet(
          set,
          weight: input.weight,
          reps: input.reps,
          rpe: input.rpe,
          notes: input.notes,
        );
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await showExercisePickerSheet(context);
    if (exercise == null || !context.mounted) return;
    await _logSet(
      context,
      ref,
      exerciseId: exercise.id,
      workoutExerciseId: null,
      setNumber: 1,
    );
  }
}
