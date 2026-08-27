import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/database/app_database.dart';
import '../../application/session_exercise_groups.dart';

class SessionExerciseCard extends StatefulWidget {
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
  State<SessionExerciseCard> createState() => _SessionExerciseCardState();
}

class _SessionExerciseCardState extends State<SessionExerciseCard> {
  /// Sets a [Dismissible] has already finished sliding away. Dismissible
  /// requires the parent to stop rendering an item at the same key/position
  /// the very next frame after `onDismissed` fires, but the real removal
  /// only lands once the DB write completes and the stream re-emits — this
  /// bridges that gap so Dismissible's contract holds regardless of how
  /// long the round-trip takes.
  final Set<int> _dismissedIds = {};

  void _delete(LoggedSet set) {
    HapticFeedback.lightImpact();
    widget.onDeleteSet(set);
  }

  @override
  Widget build(BuildContext context) {
    final targetParts = <String>[];
    if (widget.group.targetSets != null) {
      targetParts.add('meta ${widget.group.targetSets}x');
    }
    if (widget.group.targetReps != null) {
      targetParts.add('${widget.group.targetReps} reps');
    }
    if (widget.group.targetWeight != null) {
      targetParts.add('${widget.group.targetWeight}kg');
    }

    final visibleSets = widget.group.loggedSets
        .where((s) => !_dismissedIds.contains(s.id))
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.exerciseName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (targetParts.isNotEmpty)
              Text(
                targetParts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: AppSpacing.sm),
            for (final set in visibleSets)
              _LoggedSetRow(
                key: ValueKey(set.id),
                set: set,
                onTap: () => widget.onEditSet(set),
                onDelete: () => _delete(set),
                onDismissed: () => setState(() => _dismissedIds.add(set.id)),
              ),
            if (widget.editable)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: const Text('Registrar série'),
                onPressed: widget.onAddSet,
              ),
          ],
        ),
      ),
    );
  }
}

/// One logged set's row. Wrapped in a [TweenAnimationBuilder] keyed by the
/// set's stable DB id — a newly-inserted set is a brand new widget instance
/// (Flutter can't match it to any prior element), so it plays its entrance
/// animation once; an existing set re-rendered (e.g. after editing) keeps
/// its identity and skips straight to the settled state.
class _LoggedSetRow extends StatelessWidget {
  const _LoggedSetRow({
    super.key,
    required this.set,
    required this.onTap,
    required this.onDelete,
    required this.onDismissed,
  });

  final LoggedSet set;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      // Swipe-to-delete, in addition to the trailing icon button below —
      // Dismissible plays its own slide-away animation before calling
      // onDismissed, so no extra removal animation is needed here.
      child: Dismissible(
        key: ValueKey('dismissible-${set.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          color: colorScheme.error,
          // Deliberately a different icon than the trailing delete button
          // below: session_flow_test.dart selects a specific set's delete
          // button via `find.byIcon(Icons.delete_outline).at(index)`, which
          // must keep resolving to exactly one match per row.
          child: Icon(Icons.delete_forever, color: colorScheme.onError),
        ),
        onDismissed: (_) {
          onDismissed();
          onDelete();
        },
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          onTap: onTap,
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: colorScheme.surfaceContainer,
            child: Text(
              '${set.setNumber}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          title: Text(
            'Série ${set.setNumber}: '
            '${set.weight != null ? '${set.weight}kg' : '-'} x '
            '${set.reps ?? '-'}',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: set.rpe != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _RpePill(rpe: set.rpe!),
                )
              : null,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }
}

class _RpePill extends StatelessWidget {
  const _RpePill({required this.rpe});

  final double rpe;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rampColor = Color.lerp(
      colorScheme.primary,
      AppColors.ember,
      ((rpe - 1) / 9).clamp(0, 1),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: rampColor?.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(
        'RPE ${rpe.toStringAsFixed(rpe == rpe.roundToDouble() ? 0 : 1)}',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: rampColor),
      ),
    );
  }
}
