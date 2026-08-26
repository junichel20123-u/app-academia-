import 'package:flutter/material.dart';

import '../../../../core/database/enums.dart';
import '../../../../core/utils/enum_labels.dart';

class CardioEntryInput {
  const CardioEntryInput({
    required this.activityType,
    required this.durationSeconds,
    this.distanceMeters,
    this.calories,
    required this.occurredAt,
    this.notes,
  });

  final CardioActivityType activityType;
  final int durationSeconds;
  final double? distanceMeters;
  final int? calories;
  final DateTime occurredAt;
  final String? notes;
}

/// Form to log (or edit) a cardio entry. Returns null if cancelled.
Future<CardioEntryInput?> showCardioEntryForm(
  BuildContext context, {
  CardioEntryInput? initial,
}) {
  var activityType = initial?.activityType ?? CardioActivityType.run;
  var occurredAt = initial?.occurredAt ?? DateTime.now();
  final durationController = TextEditingController(
    text: initial != null
        ? (initial.durationSeconds / 60).round().toString()
        : '',
  );
  final distanceController = TextEditingController(
    text: initial?.distanceMeters != null
        ? (initial!.distanceMeters! / 1000).toString()
        : '',
  );
  final caloriesController = TextEditingController(
    text: initial?.calories?.toString() ?? '',
  );
  final notesController = TextEditingController(text: initial?.notes ?? '');

  return showDialog<CardioEntryInput>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: Text(initial == null ? 'Novo cardio' : 'Editar cardio'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CardioActivityType>(
                    initialValue: activityType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de atividade',
                    ),
                    items: CardioActivityType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(cardioActivityTypeLabel(type)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => activityType = value);
                      }
                    },
                  ),
                  TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Duração em minutos',
                    ),
                  ),
                  TextField(
                    controller: distanceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Distância em km (opcional)',
                    ),
                  ),
                  TextField(
                    controller: caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calorias (opcional)',
                    ),
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
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final minutes = int.tryParse(durationController.text.trim());
                  if (minutes == null || minutes <= 0) return;
                  final km = double.tryParse(distanceController.text.trim());
                  if (km != null && !(km.isFinite && km >= 0)) return;
                  final calories = int.tryParse(caloriesController.text.trim());
                  if (calories != null && calories < 0) return;
                  Navigator.of(dialogContext).pop(
                    CardioEntryInput(
                      activityType: activityType,
                      durationSeconds: minutes * 60,
                      distanceMeters: km != null ? km * 1000 : null,
                      calories: calories,
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
