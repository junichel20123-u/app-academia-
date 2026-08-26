import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../exercises/application/exercises_providers.dart';
import '../application/template_catalog_providers.dart';
import '../data/template_catalog_repository.dart';
import '../domain/catalog_template.dart';

class TemplateDetailScreen extends ConsumerWidget {
  const TemplateDetailScreen({super.key, required this.slug});

  final String slug;

  Future<void> _copyToMyWorkouts(
    BuildContext context,
    WidgetRef ref,
    CatalogTemplate template,
  ) async {
    final result = await ref
        .read(templateCatalogRepositoryProvider)
        .copyTemplateToMyWorkouts(template);
    if (!context.mounted) return;

    final message = switch (result) {
      CopyTemplateResult(createdWorkoutIds: []) =>
        'Nenhum treino pôde ser criado — todos os exercícios são '
            'desconhecidos neste dispositivo.',
      CopyTemplateResult(hasUnresolved: true) =>
        '${result.createdWorkoutIds.length} treino(s) criado(s) em Meus '
            'treinos. ${result.unresolvedSlugs.length} exercício(s) não '
            'encontrado(s) foram pulados.',
      _ =>
        '${result.createdWorkoutIds.length} treino(s) criado(s) em Meus '
            'treinos.',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(catalogTemplateBySlugProvider(slug));

    if (template == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Modelo de treino')),
        body: const Center(child: Text('Modelo não encontrado.')),
      );
    }

    final exercisesAsync = ref.watch(exercisesListProvider);
    final exercisesBySlug = {
      for (final e in exercisesAsync.value ?? const <Exercise>[])
        if (e.slug != null) e.slug!: e,
    };
    final workouts = parseCatalogWorkouts(template.payloadJson);

    return Scaffold(
      appBar: AppBar(title: Text(template.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (template.description != null) ...[
            Text(template.description!),
            const SizedBox(height: 16),
          ],
          for (final workout in workouts) ...[
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
            onPressed: () => _copyToMyWorkouts(context, ref, template),
            child: const Text('Copiar para meus treinos'),
          ),
        ],
      ),
    );
  }
}
