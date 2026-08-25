import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/enums.dart';
import '../../../../core/utils/enum_labels.dart';
import '../../application/exercises_providers.dart';

/// Modal picker: returns the selected [Exercise], or null if dismissed.
Future<Exercise?> showExercisePickerSheet(BuildContext context) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ExercisePickerSheet(),
  );
}

class ExercisePickerSheet extends ConsumerWidget {
  const ExercisePickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredExercisesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escolher exercício',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar exercício...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) =>
                    ref.read(exerciseSearchQueryProvider.notifier).set(value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: filtered.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Erro: $err')),
                  data: (exercises) {
                    if (exercises.isEmpty) {
                      return const Center(
                        child: Text('Nenhum exercício encontrado.'),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: exercises.length,
                      itemBuilder: (context, index) {
                        final exercise = exercises[index];
                        return ListTile(
                          title: Text(exercise.name),
                          subtitle: Text(
                            [
                              muscleGroupLabel(exercise.muscleGroup),
                              if (exercise.equipment != null)
                                equipmentLabel(exercise.equipment!),
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.of(context).pop(exercise),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Criar exercício customizado'),
                onPressed: () => _showCreateCustomExerciseDialog(context, ref),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showCreateCustomExerciseDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  var selectedGroup = MuscleGroup.fullBody;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: const Text('Novo exercício'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MuscleGroup>(
                  initialValue: selectedGroup,
                  decoration: const InputDecoration(
                    labelText: 'Grupo muscular',
                  ),
                  items: MuscleGroup.values
                      .map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(muscleGroupLabel(g)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedGroup = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  await ref
                      .read(exercisesRepositoryProvider)
                      .createCustomExercise(
                        name: name,
                        muscleGroup: selectedGroup,
                      );
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Criar'),
              ),
            ],
          );
        },
      );
    },
  );
}
