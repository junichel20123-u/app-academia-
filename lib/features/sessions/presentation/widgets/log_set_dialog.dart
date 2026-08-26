import 'package:flutter/material.dart';

class LoggedSetInput {
  const LoggedSetInput({this.weight, this.reps, this.rpe, this.notes});

  final double? weight;
  final int? reps;
  final double? rpe;
  final String? notes;
}

/// Form to log (or edit) a single set's actual weight/reps/RPE/notes.
/// Returns null if the user cancels.
Future<LoggedSetInput?> showLogSetDialog(
  BuildContext context, {
  String title = 'Registrar série',
  LoggedSetInput? initial,
}) {
  final weightController = TextEditingController(
    text: initial?.weight?.toString() ?? '',
  );
  final repsController = TextEditingController(
    text: initial?.reps?.toString() ?? '',
  );
  final rpeController = TextEditingController(
    text: initial?.rpe?.toString() ?? '',
  );
  final notesController = TextEditingController(text: initial?.notes ?? '');

  return showDialog<LoggedSetInput>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Peso em kg (opcional)',
              ),
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
              controller: rpeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'RPE (opcional)'),
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
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
              final weight = double.tryParse(weightController.text.trim());
              final reps = int.tryParse(repsController.text.trim());
              final rpe = double.tryParse(rpeController.text.trim());
              if ((weight != null && !(weight.isFinite && weight >= 0)) ||
                  (reps != null && reps < 0) ||
                  (rpe != null && !(rpe.isFinite && rpe >= 0))) {
                return;
              }
              Navigator.of(dialogContext).pop(
                LoggedSetInput(
                  weight: weight,
                  reps: reps,
                  rpe: rpe,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
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
