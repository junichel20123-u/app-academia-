import 'package:drift/drift.dart';

import '../app_database.dart';
import '../enums.dart';
import '../tables/logged_sets_table.dart';
import '../tables/workout_sessions_table.dart';

part 'sessions_dao.g.dart';

@DriftAccessor(tables: [WorkoutSessions, LoggedSets])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.db);

  Stream<List<WorkoutSession>> watchHistory() {
    final query = select(workoutSessions)
      ..where(
        (t) =>
            t.status.equalsValue(WorkoutSessionStatus.completed) |
            t.status.equalsValue(WorkoutSessionStatus.abandoned),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    return query.watch();
  }

  Future<List<WorkoutSession>> getCompletedSessions() {
    final query = select(workoutSessions)
      ..where((t) => t.status.equalsValue(WorkoutSessionStatus.completed));
    return query.get();
  }

  Future<WorkoutSession?> getSessionById(int id) => (select(
    workoutSessions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<WorkoutSession?> watchSessionById(int id) => (select(
    workoutSessions,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Most recent in-progress session, if any — used to offer "resume".
  Stream<WorkoutSession?> watchActiveSession() {
    final query = select(workoutSessions)
      ..where((t) => t.status.equalsValue(WorkoutSessionStatus.inProgress))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<List<LoggedSet>> getSetsForSession(int sessionId) {
    final query = select(loggedSets)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]);
    return query.get();
  }

  Stream<List<LoggedSet>> watchSetsForSession(int sessionId) {
    final query = select(loggedSets)
      ..where((t) => t.sessionId.equals(sessionId))
      ..orderBy([(t) => OrderingTerm.asc(t.setNumber)]);
    return query.watch();
  }

  Future<int> startSession(WorkoutSessionsCompanion entry) =>
      into(workoutSessions).insert(entry);

  Future<bool> updateSession(WorkoutSession entry) =>
      update(workoutSessions).replace(entry);

  Future<int> deleteSession(int id) =>
      (delete(workoutSessions)..where((t) => t.id.equals(id))).go();

  Future<int> logSet(LoggedSetsCompanion entry) =>
      into(loggedSets).insert(entry);

  Future<bool> updateLoggedSet(LoggedSet entry) =>
      update(loggedSets).replace(entry);

  Future<int> deleteLoggedSet(int id) =>
      (delete(loggedSets)..where((t) => t.id.equals(id))).go();
}
