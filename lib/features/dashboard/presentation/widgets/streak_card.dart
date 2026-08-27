import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../application/streak_provider.dart';

class StreakCard extends ConsumerStatefulWidget {
  const StreakCard({super.key});

  @override
  ConsumerState<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends ConsumerState<StreakCard> {
  int? _previousStreak;
  // Re-keys the icon's TweenAnimationBuilder to replay its entrance
  // animation from scratch — bumped only when the streak actually goes up,
  // never on every rebuild.
  int _pulseKey = 0;

  @override
  Widget build(BuildContext context) {
    final streakAsync = ref.watch(streakProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            streakAsync.when(
              loading: () => const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(),
              ),
              error: (err, _) =>
                  const Icon(Icons.local_fire_department, size: 40),
              data: (streak) {
                final increased =
                    _previousStreak != null && streak > _previousStreak!;
                if (increased) {
                  HapticFeedback.mediumImpact();
                  _pulseKey++;
                }
                _previousStreak = streak;
                return TweenAnimationBuilder<double>(
                  key: ValueKey(_pulseKey),
                  tween: Tween(begin: _pulseKey == 0 ? 1.0 : 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: const Icon(
                    Icons.local_fire_department,
                    color: AppColors.ember,
                    size: 40,
                  ),
                );
              },
            ),
            const SizedBox(width: AppSpacing.md),
            streakAsync.maybeWhen(
              data: (streak) {
                final label = streak == 1 ? 'dia seguido' : 'dias seguidos';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<int>(
                      tween: IntTween(end: streak),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, child) {
                        return Text(
                          '$value',
                          style: Theme.of(context).textTheme.headlineMedium,
                        );
                      },
                    ),
                    Text(label),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
