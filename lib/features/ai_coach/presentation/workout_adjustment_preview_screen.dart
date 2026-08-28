import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../ai_plan_builder/domain/generated_plan.dart';
import '../../ai_plan_builder/presentation/generation_error_message.dart';
import '../../exercises/application/exercises_providers.dart';
import '../../workouts/application/workouts_providers.dart';
import '../domain/workout_adjustment.dart';

/// Route arguments for `/coach/adjust/preview` — the workout being edited
/// plus the AI's proposed revision, passed via `state.extra` the same way
/// `/plan-builder/preview` passes its generated plan.
class WorkoutAdjustmentPreviewArgs {
  const WorkoutAdjustmentPreviewArgs({
    required this.workoutId,
    required this.proposal,
  });

  final int workoutId;
  final WorkoutAdjustmentProposal proposal;
}

enum _DiffKind { added, removed, changed, unchanged }

class _DiffRow {
  const _DiffRow({
    required this.kind,
    required this.name,
    this.currentLabel,
    this.proposedLabel,
  });

  final _DiffKind kind;
  final String name;
  final String? currentLabel;
  final String? proposedLabel;
}

class WorkoutAdjustmentPreviewScreen extends ConsumerStatefulWidget {
  const WorkoutAdjustmentPreviewScreen({super.key, required this.args});

  final WorkoutAdjustmentPreviewArgs args;

  @override
  ConsumerState<WorkoutAdjustmentPreviewScreen> createState() =>
      _WorkoutAdjustmentPreviewScreenState();
}

class _WorkoutAdjustmentPreviewScreenState
    extends ConsumerState<WorkoutAdjustmentPreviewScreen> {
  bool _isApplying = false;

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      await ref
          .read(workoutsRepositoryProvider)
          .applyAdjustedExercises(
            workoutId: widget.args.workoutId,
            exercises: widget.args.proposal.exercises,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treino atualizado.')),
      );
      context.go('/workouts/${widget.args.workoutId}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeGenerationError(error))));
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  List<_DiffRow> _buildDiff(
    List<WorkoutExercise> currentEntries,
    Map<int, Exercise> exercisesById,
    Map<String, Exercise> exercisesBySlug,
    List<GeneratedPlanExercise> proposedExercises,
  ) {
    final currentBySlug = <String, WorkoutExercise>{
      for (final entry in currentEntries)
        if (exercisesById[entry.exerciseId]?.slug != null)
          exercisesById[entry.exerciseId]!.slug!: entry,
    };
    final proposedBySlug = {
      for (final exercise in proposedExercises) exercise.exerciseSlug: exercise,
    };

    String label(int sets, int? reps) => '${sets}x${reps ?? '-'}';
    String nameFor(String slug) => exercisesBySlug[slug]?.name ?? slug;

    final rows = <_DiffRow>[];
    for (final slug in proposedBySlug.keys) {
      final proposed = proposedBySlug[slug]!;
      final current = currentBySlug[slug];
      if (current == null) {
        rows.add(
          _DiffRow(
            kind: _DiffKind.added,
            name: nameFor(slug),
            proposedLabel: label(proposed.targetSets, proposed.targetReps),
          ),
        );
      } else {
        final currentLabel = label(current.targetSets, current.targetReps);
        final proposedLabel = label(proposed.targetSets, proposed.targetReps);
        rows.add(
          _DiffRow(
            kind: currentLabel == proposedLabel
                ? _DiffKind.unchanged
                : _DiffKind.changed,
            name: nameFor(slug),
            currentLabel: currentLabel,
            proposedLabel: proposedLabel,
          ),
        );
      }
    }
    for (final slug in currentBySlug.keys) {
      if (proposedBySlug.containsKey(slug)) continue;
      final current = currentBySlug[slug]!;
      rows.add(
        _DiffRow(
          kind: _DiffKind.removed,
          name: nameFor(slug),
          currentLabel: label(current.targetSets, current.targetReps),
        ),
      );
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(
      workoutExercisesProvider(widget.args.workoutId),
    );
    final exercisesAsync = ref.watch(exercisesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sugestão do coach de IA')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (currentEntries) {
          final exercises = exercisesAsync.value ?? const <Exercise>[];
          final exercisesById = {for (final e in exercises) e.id: e};
          final exercisesBySlug = {
            for (final e in exercises)
              if (e.slug != null) e.slug!: e,
          };
          final diff = _buildDiff(
            currentEntries,
            exercisesById,
            exercisesBySlug,
            widget.args.proposal.exercises,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(widget.args.proposal.summary),
                ),
              ),
              const SizedBox(height: 16),
              for (final row in diff) _DiffTile(row: row),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _isApplying ? null : _apply,
                child: _isApplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Aplicar alterações'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiffTile extends StatelessWidget {
  const _DiffTile({required this.row});

  final _DiffRow row;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color, subtitle) = switch (row.kind) {
      _DiffKind.added => (
        Icons.add_circle_outline,
        colorScheme.primary,
        'Novo: ${row.proposedLabel}',
      ),
      _DiffKind.removed => (
        Icons.remove_circle_outline,
        colorScheme.error,
        'Removido (era ${row.currentLabel})',
      ),
      _DiffKind.changed => (
        Icons.sync_alt,
        colorScheme.secondary,
        '${row.currentLabel} → ${row.proposedLabel}',
      ),
      _DiffKind.unchanged => (
        Icons.check_circle_outline,
        colorScheme.onSurfaceVariant,
        row.currentLabel ?? '',
      ),
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(row.name),
      subtitle: Text(subtitle),
    );
  }
}
