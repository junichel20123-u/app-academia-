import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/sessions/data/sessions_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SessionsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = SessionsRepository(db);
  });
  tearDown(() => db.close());

  Future<Workout> firstWorkoutWithExercise() async {
    final exerciseId = (await db.exercisesDao.getAllExercises()).first.id;
    final workoutId = await db.workoutsDao.insertWorkout(
      WorkoutsCompanion.insert(name: 'Treino A'),
    );
    await db.workoutsDao.insertWorkoutExercise(
      WorkoutExercisesCompanion.insert(
        workoutId: workoutId,
        exerciseId: exerciseId,
        orderIndex: 0,
        targetSets: 3,
      ),
    );
    return (await db.workoutsDao.getWorkoutById(workoutId))!;
  }

  test(
    'starting a session from a workout copies its name and links it',
    () async {
      final workout = await firstWorkoutWithExercise();
      final sessionId = await repo.startSessionFromWorkout(workout);

      final session = await db.sessionsDao.getSessionById(sessionId);
      expect(session!.name, workout.name);
      expect(session.workoutId, workout.id);
      expect(session.status, WorkoutSessionStatus.inProgress);
    },
  );

  test('an ad-hoc session has no workoutId', () async {
    final sessionId = await repo.startAdHocSession();
    final session = await db.sessionsDao.getSessionById(sessionId);
    expect(session!.workoutId, isNull);
  });

  test('logs sets and completes the session', () async {
    final workout = await firstWorkoutWithExercise();
    final entries = await db.workoutsDao.getExercisesForWorkout(workout.id);
    final sessionId = await repo.startSessionFromWorkout(workout);

    await repo.logSet(
      sessionId: sessionId,
      exerciseId: entries.first.exerciseId,
      workoutExerciseId: entries.first.id,
      setNumber: 1,
      weight: 40,
      reps: 10,
    );

    final sets = await repo.watchSetsForSession(sessionId).first;
    expect(sets, hasLength(1));

    await repo.completeSession(sessionId);
    final completed = await db.sessionsDao.getSessionById(sessionId);
    expect(completed!.status, WorkoutSessionStatus.completed);
    expect(completed.completedAt, isNotNull);

    final history = await repo.watchHistory().first;
    expect(history.map((s) => s.id), contains(sessionId));
  });

  test('watchActiveSession reflects the current in-progress session', () async {
    expect(await repo.watchActiveSession().first, isNull);

    final sessionId = await repo.startAdHocSession();
    expect((await repo.watchActiveSession().first)!.id, sessionId);

    await repo.completeSession(sessionId);
    expect(await repo.watchActiveSession().first, isNull);
  });

  test('updating and deleting a logged set', () async {
    final sessionId = await repo.startAdHocSession();
    final exerciseId = (await db.exercisesDao.getAllExercises()).first.id;
    await repo.logSet(
      sessionId: sessionId,
      exerciseId: exerciseId,
      setNumber: 1,
      weight: 20,
    );
    final set = (await repo.watchSetsForSession(sessionId).first).first;

    await repo.updateLoggedSet(set, weight: 25, reps: 8);
    final updated = (await repo.watchSetsForSession(sessionId).first).first;
    expect(updated.weight, 25);
    expect(updated.reps, 8);

    await repo.deleteLoggedSet(updated.id);
    expect(await repo.watchSetsForSession(sessionId).first, isEmpty);
  });

  test('deleting a session removes it', () async {
    final sessionId = await repo.startAdHocSession();
    await repo.deleteSession(sessionId);
    expect(await db.sessionsDao.getSessionById(sessionId), isNull);
  });
}
