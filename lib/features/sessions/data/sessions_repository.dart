import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';

class SessionsRepository {
  SessionsRepository(this._db);

  final AppDatabase _db;

  Stream<List<WorkoutSession>> watchHistory() => _db.sessionsDao.watchHistory();

  Stream<WorkoutSession?> watchSessionById(int id) =>
      _db.sessionsDao.watchSessionById(id);

  Stream<WorkoutSession?> watchActiveSession() =>
      _db.sessionsDao.watchActiveSession();

  Stream<List<LoggedSet>> watchSetsForSession(int sessionId) =>
      _db.sessionsDao.watchSetsForSession(sessionId);

  Future<int> startSessionFromWorkout(Workout workout) {
    return _db.sessionsDao.startSession(
      WorkoutSessionsCompanion.insert(
        workoutId: Value(workout.id),
        name: workout.name,
        status: WorkoutSessionStatus.inProgress,
      ),
    );
  }

  Future<int> startAdHocSession({String name = 'Treino livre'}) {
    return _db.sessionsDao.startSession(
      WorkoutSessionsCompanion.insert(
        name: name,
        status: WorkoutSessionStatus.inProgress,
      ),
    );
  }

  Future<void> logSet({
    required int sessionId,
    required int exerciseId,
    int? workoutExerciseId,
    required int setNumber,
    double? weight,
    int? reps,
    double? rpe,
    String? notes,
  }) {
    return _db.sessionsDao.logSet(
      LoggedSetsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        workoutExerciseId: Value(workoutExerciseId),
        setNumber: setNumber,
        weight: Value(weight),
        reps: Value(reps),
        rpe: Value(rpe),
        notes: Value(notes),
      ),
    );
  }

  Future<void> updateLoggedSet(
    LoggedSet set, {
    double? weight,
    int? reps,
    double? rpe,
    String? notes,
  }) {
    return _db.sessionsDao.updateLoggedSet(
      set.copyWith(
        weight: Value(weight),
        reps: Value(reps),
        rpe: Value(rpe),
        notes: Value(notes),
      ),
    );
  }

  Future<void> deleteLoggedSet(int id) => _db.sessionsDao.deleteLoggedSet(id);

  Future<void> completeSession(int sessionId) async {
    final session = await _db.sessionsDao.getSessionById(sessionId);
    if (session == null) return;
    await _db.sessionsDao.updateSession(
      session.copyWith(
        status: WorkoutSessionStatus.completed,
        completedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteSession(int id) => _db.sessionsDao.deleteSession(id);
}
