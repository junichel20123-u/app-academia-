import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

class WorkoutExerciseRow extends StatelessWidget {
  const WorkoutExerciseRow({
    super.key,
    required this.entry,
    required this.exerciseName,
    required this.onEditTargets,
    required this.onRemove,
    this.readOnly = false,
  });

  final WorkoutExercise entry;
  final String exerciseName;
  final VoidCallback onEditTargets;
  final VoidCallback onRemove;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final parts = <String>['${entry.targetSets}x'];
    if (entry.targetReps != null) parts.add('${entry.targetReps} reps');
    if (entry.targetWeight != null) parts.add('${entry.targetWeight}kg');
    if (entry.targetRestSeconds != null) {
      parts.add('${entry.targetRestSeconds}s descanso');
    }

    return ListTile(
      key: ValueKey(entry.id),
      leading: readOnly ? null : const Icon(Icons.drag_handle),
      title: Text(exerciseName),
      subtitle: Text(parts.join(' · ')),
      onTap: readOnly ? null : onEditTargets,
      trailing: readOnly
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remover',
              onPressed: onRemove,
            ),
    );
  }
}
