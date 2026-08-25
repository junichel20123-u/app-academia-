import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';

class WorkoutExerciseRow extends StatelessWidget {
  const WorkoutExerciseRow({
    super.key,
    required this.entry,
    required this.exerciseName,
    required this.onEditTargets,
    required this.onRemove,
  });

  final WorkoutExercise entry;
  final String exerciseName;
  final VoidCallback onEditTargets;
  final VoidCallback onRemove;

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
      leading: const Icon(Icons.drag_handle),
      title: Text(exerciseName),
      subtitle: Text(parts.join(' · ')),
      onTap: onEditTargets,
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remover',
        onPressed: onRemove,
      ),
    );
  }
}
