import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/enums.dart';
import '../../../core/utils/enum_labels.dart';
import '../application/ai_plan_builder_providers.dart';
import 'generation_error_message.dart';

const _experienceLevels = ['beginner', 'intermediate', 'advanced'];

String _experienceLevelLabel(String level) => switch (level) {
  'beginner' => 'Iniciante',
  'intermediate' => 'Intermediário',
  'advanced' => 'Avançado',
  _ => level,
};

class AiPlanBuilderScreen extends ConsumerStatefulWidget {
  const AiPlanBuilderScreen({super.key});

  @override
  ConsumerState<AiPlanBuilderScreen> createState() =>
      _AiPlanBuilderScreenState();
}

class _AiPlanBuilderScreenState extends ConsumerState<AiPlanBuilderScreen> {
  final _goalController = TextEditingController();
  int _daysPerWeek = 3;
  String _experienceLevel = _experienceLevels.first;
  final Set<Equipment> _availableEquipment = {};
  bool _isGenerating = false;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _isGenerating = true);
    try {
      final workouts = await ref
          .read(aiPlanBuilderRepositoryProvider)
          .generatePlan(
            goal: _goalController.text.trim(),
            daysPerWeek: _daysPerWeek,
            experienceLevel: _experienceLevel,
            availableEquipment: _availableEquipment,
          );
      if (!mounted) return;
      context.push('/plan-builder/preview', extra: workouts);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeGenerationError(error))));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final premiumUnlocked = ref.watch(aiPlanBuilderPremiumUnlockedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Montador de plano por IA')),
      body: !premiumUnlocked
          ? _lockedState(context)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _goalController,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo (ex: hipertrofia, emagrecimento)',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: _daysPerWeek,
                  decoration: const InputDecoration(
                    labelText: 'Dias por semana',
                  ),
                  items: [
                    for (var day = 1; day <= 7; day++)
                      DropdownMenuItem(value: day, child: Text('$day')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _daysPerWeek = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _experienceLevel,
                  decoration: const InputDecoration(
                    labelText: 'Nível de experiência',
                  ),
                  items: [
                    for (final level in _experienceLevels)
                      DropdownMenuItem(
                        value: level,
                        child: Text(_experienceLevelLabel(level)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _experienceLevel = value);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Equipamento disponível',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final equipment in Equipment.values)
                  CheckboxListTile(
                    title: Text(equipmentLabel(equipment)),
                    value: _availableEquipment.contains(equipment),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _availableEquipment.add(equipment);
                        } else {
                          _availableEquipment.remove(equipment);
                        }
                      });
                    },
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isGenerating ? null : _generate,
                  child: _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gerar plano'),
                ),
              ],
            ),
    );
  }

  Widget _lockedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'O montador de plano por IA é um recurso premium.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pagamentos em breve.')),
                );
              },
              child: const Text('Desbloquear'),
            ),
            const SizedBox(height: 8),
            Text(
              'Testando o app? Ative em Configurações → Modo de teste.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
