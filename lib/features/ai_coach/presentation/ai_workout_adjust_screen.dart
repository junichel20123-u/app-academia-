import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/enums.dart';
import '../../../core/utils/enum_labels.dart';
import '../../ai_plan_builder/presentation/generation_error_message.dart';
import '../../workouts/application/workouts_providers.dart';
import '../application/ai_coach_providers.dart';
import '../domain/coach_context.dart';
import 'workout_adjustment_preview_screen.dart';

/// Lets the user pick one of their existing workouts and describe, in free
/// text, what they want changed — the coach then proposes a revised
/// exercise list (see `AiCoachRepository.proposeWorkoutAdjustment`),
/// previewed before anything is applied.
class AiWorkoutAdjustScreen extends ConsumerStatefulWidget {
  const AiWorkoutAdjustScreen({super.key, this.initialWorkoutId});

  /// Pre-selected workout, when opened directly from `WorkoutEditScreen`.
  final int? initialWorkoutId;

  @override
  ConsumerState<AiWorkoutAdjustScreen> createState() =>
      _AiWorkoutAdjustScreenState();
}

class _AiWorkoutAdjustScreenState extends ConsumerState<AiWorkoutAdjustScreen> {
  final _instructionsController = TextEditingController();
  final Set<Equipment> _availableEquipment = {};
  int? _selectedWorkoutId;
  late Future<CoachContext> _contextFuture;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _selectedWorkoutId = widget.initialWorkoutId;
    // No goal/experienceLevel here — this screen only asks for the one
    // thing specific to an adjustment (the free-text instructions);
    // sedentarismo/peso are detected automatically either way.
    _contextFuture = ref.read(aiCoachRepositoryProvider).buildContext();
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _generate(CoachContext coachContext) async {
    final workoutId = _selectedWorkoutId;
    if (workoutId == null || _instructionsController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isGenerating = true);
    try {
      final proposal = await ref
          .read(aiCoachRepositoryProvider)
          .proposeWorkoutAdjustment(
            workoutId: workoutId,
            instructions: _instructionsController.text.trim(),
            context: coachContext,
            availableEquipment: _availableEquipment,
          );
      if (!mounted) return;
      context.push(
        '/coach/adjust/preview',
        extra: WorkoutAdjustmentPreviewArgs(
          workoutId: workoutId,
          proposal: proposal,
        ),
      );
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
    final workoutsAsync = ref.watch(workoutsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustar treino com IA')),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erro: $err')),
        data: (workouts) {
          final editable = workouts.where((w) => !w.isSystem).toList();
          if (editable.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Crie um treino em "Meus treinos" antes de pedir um '
                  'ajuste por IA.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (_selectedWorkoutId != null &&
              !editable.any((w) => w.id == _selectedWorkoutId)) {
            _selectedWorkoutId = null;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedWorkoutId,
                decoration: const InputDecoration(
                  labelText: 'Qual treino ajustar?',
                ),
                items: [
                  for (final workout in editable)
                    DropdownMenuItem(
                      value: workout.id,
                      child: Text(workout.name),
                    ),
                ],
                onChanged: (value) => setState(() => _selectedWorkoutId = value),
              ),
              const SizedBox(height: 16),
              FutureBuilder<CoachContext>(
                future: _contextFuture,
                builder: (context, snapshot) {
                  final coachContext = snapshot.data;
                  if (coachContext == null) {
                    return const SizedBox.shrink();
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.insights, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Contexto detectado: ${coachContext.summaryText}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _instructionsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'O que você quer mudar nesse treino?',
                  hintText:
                      'Ex: quero mais foco em resistência, ou trocar os '
                      'exercícios de perna por algo sem halteres',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Equipamento disponível',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final equipment in Equipment.values)
                    FilterChip(
                      label: Text(equipmentLabel(equipment)),
                      selected: _availableEquipment.contains(equipment),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _availableEquipment.add(equipment);
                          } else {
                            _availableEquipment.remove(equipment);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 24),
              FutureBuilder<CoachContext>(
                future: _contextFuture,
                builder: (context, snapshot) {
                  final coachContext = snapshot.data;
                  final selectedWorkoutId = _selectedWorkoutId;
                  final buttonChild = _isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gerar sugestão');
                  if (coachContext == null ||
                      selectedWorkoutId == null ||
                      _isGenerating) {
                    return FilledButton(
                      onPressed: null,
                      child: buttonChild,
                    );
                  }
                  return FilledButton(
                    onPressed: () => _generate(coachContext),
                    child: buttonChild,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
