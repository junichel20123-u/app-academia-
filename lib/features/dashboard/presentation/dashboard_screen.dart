import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../sessions/application/sessions_providers.dart';
import 'widgets/streak_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSession = ref.watch(activeSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('App Academia')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StreakCard(),
          const SizedBox(height: 16),
          activeSession.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (session) {
              if (session == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: Text('Continuar: ${session.name}'),
                  onPressed: () => context.push('/sessions/${session.id}'),
                ),
              );
            },
          ),
          FilledButton(
            onPressed: () => context.push('/workouts'),
            child: const Text('Meus treinos'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              final id = await ref
                  .read(sessionsRepositoryProvider)
                  .startAdHocSession();
              if (context.mounted) context.push('/sessions/$id');
            },
            child: const Text('Treino livre'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push('/history'),
            child: const Text('Histórico'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push('/cardio'),
            child: const Text('Cardio'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.push('/weigh-in'),
            child: const Text('Pesagem'),
          ),
        ],
      ),
    );
  }
}
