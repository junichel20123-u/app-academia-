import 'package:flutter/material.dart';

class ExerciseTargets {
  const ExerciseTargets({
    required this.sets,
    this.reps,
    this.weight,
    this.restSeconds,
  });

  final int sets;
  final int? reps;
  final double? weight;
  final int? restSeconds;
}

/// Small form to set/edit the target sets/reps/weight/rest for a
/// workout exercise entry. Returns null if the user cancels.
Future<ExerciseTargets?> showExerciseTargetsDialog(
  BuildContext context, {
  ExerciseTargets? initial,
}) {
  final setsController = TextEditingController(
    text: (initial?.sets ?? 3).toString(),
  );
  final repsController = TextEditingController(
    text: initial?.reps?.toString() ?? '',
  );
  final weightController = TextEditingController(
    text: initial?.weight?.toString() ?? '',
  );
  final restController = TextEditingController(
    text: initial?.restSeconds?.toString() ?? '',
  );

  return showDialog<ExerciseTargets>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Metas do exercício'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Séries'),
              autofocus: true,
            ),
            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Repetições (opcional)',
              ),
            ),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Peso alvo em kg (opcional)',
              ),
            ),
            TextField(
              controller: restController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Descanso em segundos (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final sets = int.tryParse(setsController.text.trim());
              if (sets == null || sets <= 0) return;
              Navigator.of(dialogContext).pop(
                ExerciseTargets(
                  sets: sets,
                  reps: int.tryParse(repsController.text.trim()),
                  weight: double.tryParse(weightController.text.trim()),
                  restSeconds: int.tryParse(restController.text.trim()),
                ),
              );
            },
            child: const Text('Salvar'),
          ),
        ],
      );
    },
  );
}
