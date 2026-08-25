import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sessions/application/sessions_providers.dart';
import 'streak_calculator.dart';

final streakProvider = StreamProvider<int>((ref) {
  return ref
      .watch(sessionsRepositoryProvider)
      .watchCompletedSessions()
      .map(
        (sessions) => calculateStreak(
          sessions
              .where((s) => s.completedAt != null)
              .map((s) => s.completedAt!.toLocal()),
          now: DateTime.now(),
        ),
      );
});
