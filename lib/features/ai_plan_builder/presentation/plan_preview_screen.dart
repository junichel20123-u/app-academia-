import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../exercises/application/exercises_providers.dart';
import '../application/ai_plan_builder_providers.dart';
import '../domain/generated_plan.dart';

class PlanPreviewScreen extends ConsumerStatefulWidget {
  const PlanPreviewScreen({super.key, required this.workouts});

  final List<GeneratedPlanWorkout> workouts;

  @override
  ConsumerState<PlanPreviewScreen> createState() => _PlanPreviewScreenState();
}

class _PlanPreviewScreenState extends ConsumerState<PlanPreviewScreen> {
  final _planNameController = TextEditingController(
    text: 'Plano gerado por IA',
  );
  bool _isImporting = false;

  @override
  void dispose() {
    _planNameController.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      final createdWorkoutIds = await ref
          .read(aiPlanBuilderRepositoryProvider)
          .importPlan(
            widget.workouts,
            planName: _planNameController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${createdWorkoutIds.length} treino(s) criado(s) em Meus treinos.',
          ),
        ),
      );
      context.go('/workouts');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao importar o plano: $error')),
      );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesListProvider);
    final exercisesBySlug = {
      for (final e in exercisesAsync.value ?? const <Exercise>[])
        if (e.slug != null) e.slug!: e,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Plano gerado')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _planNameController,
            decoration: const InputDecoration(labelText: 'Nome do plano'),
          ),
          const SizedBox(height: 16),
          for (final workout in widget.workouts) ...[
            Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
            for (final exercise in workout.exercises)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  exercisesBySlug[exercise.exerciseSlug]?.name ??
                      exercise.exerciseSlug,
                ),
                subtitle: Text(
                  '${exercise.targetSets}x${exercise.targetReps ?? '-'}',
                ),
              ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isImporting ? null : _import,
            child: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Importar para meus treinos'),
          ),
        ],
      ),
    );
  }
}
