import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/enum_labels.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/cardio_providers.dart';
import 'widgets/cardio_entry_form.dart';

class CardioScreen extends ConsumerWidget {
  const CardioScreen({super.key});

  Future<void> _createEntry(BuildContext context, WidgetRef ref) async {
    final input = await showCardioEntryForm(context);
    if (input == null) return;
    await ref
        .read(cardioRepositoryProvider)
        .createEntry(
          activityType: input.activityType,
          durationSeconds: input.durationSeconds,
          distanceMeters: input.distanceMeters,
          calories: input.calories,
          occurredAt: input.occurredAt,
          notes: input.notes,
        );
  }

  Future<void> _editEntry(
    BuildContext context,
    WidgetRef ref,
    CardioEntry entry,
  ) async {
    final input = await showCardioEntryForm(
      context,
      initial: CardioEntryInput(
        activityType: entry.activityType,
        durationSeconds: entry.durationSeconds,
        distanceMeters: entry.distanceMeters,
        calories: entry.calories,
        occurredAt: entry.occurredAt,
        notes: entry.notes,
      ),
    );
    if (input == null) return;
    await ref
        .read(cardioRepositoryProvider)
        .updateEntry(
          entry,
          activityType: input.activityType,
          durationSeconds: input.durationSeconds,
          distanceMeters: input.distanceMeters,
          calories: input.calories,
          occurredAt: input.occurredAt,
          notes: input.notes,
        );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CardioEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir registro?'),
        content: const Text('Este registro de cardio será removido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cardioRepositoryProvider).deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(cardioEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cardio')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.directions_run,
              title: 'Nenhum registro de cardio ainda.',
            );
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final parts = <String>[
                '${(entry.durationSeconds / 60).round()} min',
                if (entry.distanceMeters != null)
                  '${(entry.distanceMeters! / 1000).toStringAsFixed(2)} km',
                if (entry.calories != null) '${entry.calories} kcal',
                _formatDate(entry.occurredAt),
              ];
              return TweenAnimationBuilder<double>(
                key: ValueKey(entry.id),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(opacity: value, child: child);
                },
                child: ListTile(
                  title: Text(cardioActivityTypeLabel(entry.activityType)),
                  subtitle: Text(parts.join(' · ')),
                  onTap: () => _editEntry(context, ref, entry),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref, entry),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createEntry(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
