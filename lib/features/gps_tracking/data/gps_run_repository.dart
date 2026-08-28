import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';

class GpsRunRepository {
  GpsRunRepository(this._db);

  final AppDatabase _db;

  Stream<GpsRunSession?> watchActiveRun() =>
      _db.gpsRunSessionsDao.watchActiveRun();

  Future<GpsRunSession?> getRunById(int id) =>
      _db.gpsRunSessionsDao.getRunById(id);

  Future<int> startRun({required CardioActivityType activityType}) {
    return _db.gpsRunSessionsDao.startRun(
      GpsRunSessionsCompanion.insert(
        activityType: activityType,
        status: GpsRunSessionStatus.inProgress,
      ),
    );
  }

  Future<void> checkpoint({
    required int runId,
    required double accumulatedDistanceMeters,
  }) => _db.gpsRunSessionsDao.checkpointDistance(
    runId,
    accumulatedDistanceMeters,
  );

  Future<void> completeRun({
    required int runId,
    required double accumulatedDistanceMeters,
  }) => _db.gpsRunSessionsDao.completeRun(
    runId,
    accumulatedDistanceMeters: accumulatedDistanceMeters,
  );

  Future<void> abandonRun(int runId) => _db.gpsRunSessionsDao.abandonRun(runId);
}
