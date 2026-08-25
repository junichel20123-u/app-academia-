import 'package:flutter/material.dart';

class WeighInInput {
  const WeighInInput({
    required this.weightKg,
    required this.occurredAt,
    this.notes,
  });

  final double weightKg;
  final DateTime occurredAt;
  final String? notes;
}

/// Form to log (or edit) a body-weight entry. Returns null if cancelled.
Future<WeighInInput?> showWeighInForm(
  BuildContext context, {
  WeighInInput? initial,
}) {
  var occurredAt = initial?.occurredAt ?? DateTime.now();
  final weightController = TextEditingController(
    text: initial?.weightKg.toString() ?? '',
  );
  final notesController = TextEditingController(text: initial?.notes ?? '');

  return showDialog<WeighInInput>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(initial == null ? 'Nova pesagem' : 'Editar pesagem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Peso em kg'),
                  autofocus: true,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Data: ${occurredAt.day.toString().padLeft(2, '0')}/'
                    '${occurredAt.month.toString().padLeft(2, '0')}/'
                    '${occurredAt.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: occurredAt,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(
                        () => occurredAt = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          occurredAt.hour,
                          occurredAt.minute,
                        ),
                      );
                    }
                  },
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
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
                  final weight = double.tryParse(weightController.text.trim());
                  if (weight == null || weight <= 0) return;
                  Navigator.of(dialogContext).pop(
                    WeighInInput(
                      weightKg: weight,
                      occurredAt: occurredAt,
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
    },
  );
}
