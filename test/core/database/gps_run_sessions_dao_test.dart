import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('watchActiveRun returns null when nothing is in progress', () async {
    expect(await db.gpsRunSessionsDao.watchActiveRun().first, isNull);
  });

  test('watchActiveRun returns only the most recent in-progress run', () async {
    await db.gpsRunSessionsDao.startRun(
      GpsRunSessionsCompanion.insert(
        activityType: CardioActivityType.walk,
        status: GpsRunSessionStatus.inProgress,
        startedAt: Value(DateTime(2026, 1, 1)),
      ),
    );
    final latestId = await db.gpsRunSessionsDao.startRun(
      GpsRunSessionsCompanion.insert(
        activityType: CardioActivityType.run,
        status: GpsRunSessionStatus.inProgress,
        startedAt: Value(DateTime(2026, 1, 2)),
      ),
    );

    final active = await db.gpsRunSessionsDao.watchActiveRun().first;
    expect(active?.id, latestId);
    expect(active?.activityType, CardioActivityType.run);
  });

  test(
    'checkpointDistance updates only the distance, not other fields',
    () async {
      final id = await db.gpsRunSessionsDao.startRun(
        GpsRunSessionsCompanion.insert(
          activityType: CardioActivityType.run,
          status: GpsRunSessionStatus.inProgress,
        ),
      );

      await db.gpsRunSessionsDao.checkpointDistance(id, 1234.5);

      final run = await db.gpsRunSessionsDao.getRunById(id);
      expect(run?.accumulatedDistanceMeters, 1234.5);
      expect(run?.status, GpsRunSessionStatus.inProgress);
      expect(run?.completedAt, isNull);
    },
  );

  test('completeRun stamps completedAt, freezes distance and status', () async {
    final id = await db.gpsRunSessionsDao.startRun(
      GpsRunSessionsCompanion.insert(
        activityType: CardioActivityType.run,
        status: GpsRunSessionStatus.inProgress,
      ),
    );

    await db.gpsRunSessionsDao.completeRun(id, accumulatedDistanceMeters: 5000);

    final run = await db.gpsRunSessionsDao.getRunById(id);
    expect(run?.status, GpsRunSessionStatus.completed);
    expect(run?.accumulatedDistanceMeters, 5000);
    expect(run?.completedAt, isNotNull);
    expect(await db.gpsRunSessionsDao.watchActiveRun().first, isNull);
  });

  test(
    'abandonRun marks the run abandoned without touching distance',
    () async {
      final id = await db.gpsRunSessionsDao.startRun(
        GpsRunSessionsCompanion.insert(
          activityType: CardioActivityType.walk,
          status: GpsRunSessionStatus.inProgress,
        ),
      );
      await db.gpsRunSessionsDao.checkpointDistance(id, 800);

      await db.gpsRunSessionsDao.abandonRun(id);

      final run = await db.gpsRunSessionsDao.getRunById(id);
      expect(run?.status, GpsRunSessionStatus.abandoned);
      expect(run?.accumulatedDistanceMeters, 800);
      expect(run?.completedAt, isNotNull);
    },
  );
}
