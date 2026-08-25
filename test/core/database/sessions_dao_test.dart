import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  Future<int> firstExerciseId() async =>
      (await db.exercisesDao.getAllExercises()).first.id;

  test('logs sets for an ad-hoc session and completes it', () async {
    final exerciseId = await firstExerciseId();
    final sessionId = await db.sessionsDao.startSession(
      WorkoutSessionsCompanion.insert(
        name: 'Sessão ad-hoc',
        status: WorkoutSessionStatus.inProgress,
      ),
    );

    await db.sessionsDao.logSet(
      LoggedSetsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: 1,
        weight: const Value(40.0),
        reps: const Value(12),
      ),
    );
    await db.sessionsDao.logSet(
      LoggedSetsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: 2,
        weight: const Value(42.5),
        reps: const Value(10),
      ),
    );

    final sets = await db.sessionsDao.getSetsForSession(sessionId);
    expect(sets, hasLength(2));
    expect(sets.last.weight, 42.5);

    final session = await db.sessionsDao.getSessionById(sessionId);
    await db.sessionsDao.updateSession(
      session!.copyWith(
        status: WorkoutSessionStatus.completed,
        completedAt: Value(DateTime.now()),
      ),
    );

    final completed = await db.sessionsDao.getCompletedSessions();
    expect(completed.map((s) => s.id), contains(sessionId));
  });

  test('deleting a session cascades to its logged sets', () async {
    final exerciseId = await firstExerciseId();
    final sessionId = await db.sessionsDao.startSession(
      WorkoutSessionsCompanion.insert(
        name: 'Sessão a excluir',
        status: WorkoutSessionStatus.inProgress,
      ),
    );
    await db.sessionsDao.logSet(
      LoggedSetsCompanion.insert(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: 1,
      ),
    );

    await db.sessionsDao.deleteSession(sessionId);

    expect(await db.sessionsDao.getSessionById(sessionId), isNull);
    expect(await db.sessionsDao.getSetsForSession(sessionId), isEmpty);
  });
}
