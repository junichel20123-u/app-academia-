import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/weigh_in_providers.dart';
import 'widgets/weigh_in_form.dart';
import 'widgets/weight_chart.dart';

enum _ChartPeriod { d30, d90, d365, all }

extension on _ChartPeriod {
  String get label => switch (this) {
    _ChartPeriod.d30 => '30 dias',
    _ChartPeriod.d90 => '90 dias',
    _ChartPeriod.d365 => '1 ano',
    _ChartPeriod.all => 'Tudo',
  };

  int? get days => switch (this) {
    _ChartPeriod.d30 => 30,
    _ChartPeriod.d90 => 90,
    _ChartPeriod.d365 => 365,
    _ChartPeriod.all => null,
  };
}

class WeighInScreen extends ConsumerStatefulWidget {
  const WeighInScreen({super.key});

  @override
  ConsumerState<WeighInScreen> createState() => _WeighInScreenState();
}

class _WeighInScreenState extends ConsumerState<WeighInScreen> {
  _ChartPeriod _period = _ChartPeriod.d90;

  Future<void> _createEntry() async {
    final input = await showWeighInForm(context);
    if (input == null) return;
    await ref
        .read(weighInRepositoryProvider)
        .createWeighIn(
          weightKg: input.weightKg,
          occurredAt: input.occurredAt,
          notes: input.notes,
        );
  }

  Future<void> _editEntry(WeighIn entry) async {
    final input = await showWeighInForm(
      context,
      initial: WeighInInput(
        weightKg: entry.weightKg,
        occurredAt: entry.occurredAt,
        notes: entry.notes,
      ),
    );
    if (input == null) return;
    await ref
        .read(weighInRepositoryProvider)
        .updateWeighIn(
          entry,
          weightKg: input.weightKg,
          occurredAt: input.occurredAt,
          notes: input.notes,
        );
  }

  Future<void> _confirmDelete(WeighIn entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir pesagem?'),
        content: const Text('Este registro será removido.'),
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
      await ref.read(weighInRepositoryProvider).deleteWeighIn(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(weighInsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pesagem')),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (entries) {
          if (entries.isEmpty) {
            return const EmptyState(
              icon: Icons.monitor_weight_outlined,
              title: 'Nenhuma pesagem ainda.',
            );
          }

          final cutoff = _period.days == null
              ? null
              : DateTime.now().subtract(Duration(days: _period.days!));
          final chartEntries =
              entries
                  .where((e) => cutoff == null || e.occurredAt.isAfter(cutoff))
                  .toList()
                ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final period in _ChartPeriod.values)
                      ChoiceChip(
                        label: Text(period.label),
                        selected: _period == period,
                        onSelected: (_) => setState(() => _period = period),
                      ),
                  ],
                ),
              ),
              WeightChart(entries: chartEntries),
              const Divider(),
              for (final entry in entries)
                TweenAnimationBuilder<double>(
                  key: ValueKey(entry.id),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: ListTile(
                    title: Text('${entry.weightKg} kg'),
                    subtitle: Text(_formatDate(entry.occurredAt)),
                    onTap: () => _editEntry(entry),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _confirmDelete(entry),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createEntry,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
