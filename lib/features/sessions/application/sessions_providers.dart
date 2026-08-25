import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/sessions_repository.dart';

final sessionsRepositoryProvider = Provider<SessionsRepository>((ref) {
  return SessionsRepository(ref.watch(appDatabaseProvider));
});

final sessionHistoryProvider = StreamProvider<List<WorkoutSession>>((ref) {
  return ref.watch(sessionsRepositoryProvider).watchHistory();
});

final activeSessionProvider = StreamProvider<WorkoutSession?>((ref) {
  return ref.watch(sessionsRepositoryProvider).watchActiveSession();
});

final sessionByIdProvider = StreamProvider.autoDispose
    .family<WorkoutSession?, int>((ref, sessionId) {
      return ref.watch(sessionsRepositoryProvider).watchSessionById(sessionId);
    });

final sessionSetsProvider = StreamProvider.autoDispose
    .family<List<LoggedSet>, int>((ref, sessionId) {
      return ref
          .watch(sessionsRepositoryProvider)
          .watchSetsForSession(sessionId);
    });
