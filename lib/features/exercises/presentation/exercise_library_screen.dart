import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/enum_labels.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/exercises_providers.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercícios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar exercício...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erro: $err')),
              data: (exercises) {
                final query = _query.trim().toLowerCase();
                final filtered = query.isEmpty
                    ? exercises
                    : exercises
                          .where((e) => e.name.toLowerCase().contains(query))
                          .toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'Nenhum exercício encontrado.',
                  );
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final exercise = filtered[index];
                    return TweenAnimationBuilder<double>(
                      key: ValueKey(exercise.id),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(opacity: value, child: child);
                      },
                      child: ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(
                          [
                            muscleGroupLabel(exercise.muscleGroup),
                            if (exercise.equipment != null)
                              equipmentLabel(exercise.equipment!),
                          ].join(' · '),
                        ),
                        onTap: () => context.push('/exercises/${exercise.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
