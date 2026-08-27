import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';

class LoggedSetInput {
  const LoggedSetInput({this.weight, this.reps, this.rpe, this.notes});

  final double? weight;
  final int? reps;
  final double? rpe;
  final String? notes;
}

/// Form to log (or edit) a single set's actual weight/reps/RPE/notes.
/// Returns null if the user cancels. A bottom sheet (not a dialog) — sliding
/// up from the thumb reads more "gym app" than a centered dialog, and gives
/// the stepper buttons/RPE chips room to breathe.
Future<LoggedSetInput?> showLogSetDialog(
  BuildContext context, {
  String title = 'Registrar série',
  LoggedSetInput? initial,
}) {
  return showModalBottomSheet<LoggedSetInput>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _LogSetSheet(title: title, initial: initial),
  );
}

class _LogSetSheet extends StatefulWidget {
  const _LogSetSheet({required this.title, this.initial});

  final String title;
  final LoggedSetInput? initial;

  @override
  State<_LogSetSheet> createState() => _LogSetSheetState();
}

class _LogSetSheetState extends State<_LogSetSheet> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _notesController;
  int? _rpe;
  bool _showNotes = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _weightController = TextEditingController(
      text: initial?.weight?.toString() ?? '',
    );
    _repsController = TextEditingController(
      text: initial?.reps?.toString() ?? '',
    );
    _notesController = TextEditingController(text: initial?.notes ?? '');
    _rpe = initial?.rpe?.round();
    _showNotes = initial?.notes?.isNotEmpty ?? false;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _stepWeight(double delta) {
    HapticFeedback.selectionClick();
    final current = double.tryParse(_weightController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, double.infinity);
    setState(() {
      _weightController.text = next == next.roundToDouble()
          ? next.toStringAsFixed(0)
          : next.toString();
    });
  }

  void _stepReps(int delta) {
    HapticFeedback.selectionClick();
    final current = int.tryParse(_repsController.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 1 << 30);
    setState(() => _repsController.text = next.toString());
  }

  void _selectRpe(int value) {
    HapticFeedback.selectionClick();
    setState(() => _rpe = _rpe == value ? null : value);
  }

  void _save() {
    final weight = double.tryParse(_weightController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    if ((weight != null && !(weight.isFinite && weight >= 0)) ||
        (reps != null && reps < 0)) {
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      LoggedSetInput(
        weight: weight,
        reps: reps,
        rpe: _rpe?.toDouble(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            _SteppedField(
              controller: _weightController,
              label: 'Peso em kg (opcional)',
              decimal: true,
              onDecrement: () => _stepWeight(-2.5),
              onIncrement: () => _stepWeight(2.5),
            ),
            const SizedBox(height: AppSpacing.md),
            _SteppedField(
              controller: _repsController,
              label: 'Repetições (opcional)',
              decimal: false,
              onDecrement: () => _stepReps(-1),
              onIncrement: () => _stepReps(1),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'RPE (opcional)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (var value = 1; value <= 10; value++)
                  _RpeChip(
                    value: value,
                    selected: _rpe == value,
                    onSelected: () => _selectRpe(value),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!_showNotes)
              TextButton.icon(
                onPressed: () => setState(() => _showNotes = true),
                icon: const Icon(Icons.add),
                label: const Text('Nota'),
              )
            else
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                ),
                maxLines: 2,
              ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                    ),
                    onPressed: _save,
                    child: const Text('Salvar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SteppedField extends StatelessWidget {
  const _SteppedField({
    required this.controller,
    required this.label,
    required this.decimal,
    required this.onDecrement,
    required this.onIncrement,
  });

  final TextEditingController controller;
  final String label;
  final bool decimal;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: onDecrement,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            textAlign: TextAlign.center,
            decoration: InputDecoration(labelText: label),
            autofocus: label.startsWith('Peso'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          onPressed: onIncrement,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _RpeChip extends StatelessWidget {
  const _RpeChip({
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final int value;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rampColor = Color.lerp(
      colorScheme.primary,
      AppColors.ember,
      (value - 1) / 9,
    );
    return ChoiceChip(
      label: Text('$value'),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: rampColor,
      labelStyle: selected
          ? Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: colorScheme.onPrimary)
          : null,
    );
  }
}
