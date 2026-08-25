import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/streak_provider.dart';

class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.orange,
              size: 40,
            ),
            const SizedBox(width: 16),
            streakAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (err, _) => Text('Erro: $err'),
              data: (streak) {
                final label = streak == 1 ? 'dia seguido' : 'dias seguidos';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streak',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(label),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
