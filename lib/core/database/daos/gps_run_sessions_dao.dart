import 'package:drift/drift.dart';

import '../app_database.dart';
import '../enums.dart';
import '../tables/gps_run_sessions_table.dart';

part 'gps_run_sessions_dao.g.dart';

@DriftAccessor(tables: [GpsRunSessions])
class GpsRunSessionsDao extends DatabaseAccessor<AppDatabase>
    with _$GpsRunSessionsDaoMixin {
  GpsRunSessionsDao(super.db);

  /// Most recent in-progress run, if any — used to offer "resume", mirrors
  /// `SessionsDao.watchActiveSession()`.
  Stream<GpsRunSession?> watchActiveRun() {
    final query = select(gpsRunSessions)
      ..where((t) => t.status.equalsValue(GpsRunSessionStatus.inProgress))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(1);
    return query.watchSingleOrNull();
  }

  Future<GpsRunSession?> getRunById(int id) =>
      (select(gpsRunSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<GpsRunSession>> getAllRuns() => select(gpsRunSessions).get();

  Future<int> startRun(GpsRunSessionsCompanion entry) =>
      into(gpsRunSessions).insert(entry);

  /// Updates only the running distance total — never a coordinate, and
  /// never the whole row (avoids clobbering `startedAt`/`status` with a
  /// stale in-memory copy from a caller that only knows the new distance).
  Future<void> checkpointDistance(int id, double accumulatedDistanceMeters) =>
      (update(gpsRunSessions)..where((t) => t.id.equals(id))).write(
        GpsRunSessionsCompanion(
          accumulatedDistanceMeters: Value(accumulatedDistanceMeters),
        ),
      );

  Future<void> completeRun(
    int id, {
    required double accumulatedDistanceMeters,
  }) => (update(gpsRunSessions)..where((t) => t.id.equals(id))).write(
    GpsRunSessionsCompanion(
      accumulatedDistanceMeters: Value(accumulatedDistanceMeters),
      status: const Value(GpsRunSessionStatus.completed),
      completedAt: Value(DateTime.now()),
    ),
  );

  Future<void> abandonRun(int id) =>
      (update(gpsRunSessions)..where((t) => t.id.equals(id))).write(
        GpsRunSessionsCompanion(
          status: const Value(GpsRunSessionStatus.abandoned),
          completedAt: Value(DateTime.now()),
        ),
      );
}
