import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../application/session_exercise_groups.dart';

class SessionExerciseCard extends StatelessWidget {
  const SessionExerciseCard({
    super.key,
    required this.group,
    required this.exerciseName,
    required this.editable,
    required this.onAddSet,
    required this.onEditSet,
    required this.onDeleteSet,
  });

  final SessionExerciseGroup group;
  final String exerciseName;
  final bool editable;
  final Future<void> Function() onAddSet;
  final Future<void> Function(LoggedSet set) onEditSet;
  final Future<void> Function(LoggedSet set) onDeleteSet;

  @override
  Widget build(BuildContext context) {
    final targetParts = <String>[];
    if (group.targetSets != null) targetParts.add('meta ${group.targetSets}x');
    if (group.targetReps != null) targetParts.add('${group.targetReps} reps');
    if (group.targetWeight != null) {
      targetParts.add('${group.targetWeight}kg');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(exerciseName, style: Theme.of(context).textTheme.titleMedium),
            if (targetParts.isNotEmpty)
              Text(
                targetParts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            for (final set in group.loggedSets)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Série ${set.setNumber}: '
                  '${set.weight != null ? '${set.weight}kg' : '-'} x '
                  '${set.reps ?? '-'}'
                  '${set.rpe != null ? ' · RPE ${set.rpe}' : ''}',
                ),
                onTap: () => onEditSet(set),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => onDeleteSet(set),
                ),
              ),
            if (editable)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Registrar série'),
                onPressed: onAddSet,
              ),
          ],
        ),
      ),
    );
  }
}
