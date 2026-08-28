import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_spacing.dart';
import '../../sessions/application/sessions_providers.dart';
import 'widgets/dashboard_tile.dart';
import 'widgets/streak_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    final tiles = <({IconData icon, String label, VoidCallback onTap})>[
      (
        icon: Icons.fitness_center,
        label: 'Meus treinos',
        onTap: () => context.push('/workouts'),
      ),
      (
        icon: Icons.bolt,
        label: 'Treino livre',
        onTap: () async {
          final id = await ref
              .read(sessionsRepositoryProvider)
              .startAdHocSession();
          if (context.mounted) context.push('/sessions/$id');
        },
      ),
      (
        icon: Icons.history,
        label: 'Histórico',
        onTap: () => context.push('/history'),
      ),
      (
        icon: Icons.directions_run,
        label: 'Cardio',
        onTap: () => context.push('/cardio'),
      ),
      (
        icon: Icons.satellite_alt,
        label: 'Corrida/caminhada GPS',
        onTap: () => context.push('/gps-run'),
      ),
      (
        icon: Icons.monitor_weight_outlined,
        label: 'Pesagem',
        onTap: () => context.push('/weigh-in'),
      ),
      (
        icon: Icons.list_alt,
        label: 'Exercícios',
        onTap: () => context.push('/exercises'),
      ),
      (
        icon: Icons.auto_stories,
        label: 'Catálogo de treinos',
        onTap: () => context.push('/templates'),
      ),
      (
        icon: Icons.auto_awesome,
        label: 'Montador de plano por IA',
        onTap: () => context.push('/plan-builder'),
      ),
      (
        icon: Icons.settings,
        label: 'Configurações',
        onTap: () => context.push('/settings'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('App Academia')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const StreakCard(),
          const SizedBox(height: AppSpacing.md),
          activeSession.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (session) {
              if (session == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Continuar: ${session.name}'),
                  onPressed: () => context.push('/sessions/${session.id}'),
                ),
              );
            },
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tiles.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.3,
            ),
            itemBuilder: (context, index) {
              final tile = tiles[index];
              return DashboardTile(
                icon: tile.icon,
                label: tile.label,
                onTap: tile.onTap,
                index: index,
              );
            },
          ),
        ],
      ),
    );
  }
}
