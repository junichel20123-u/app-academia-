// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gps_run_sessions_dao.dart';

// ignore_for_file: type=lint
mixin _$GpsRunSessionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $GpsRunSessionsTable get gpsRunSessions => attachedDatabase.gpsRunSessions;
  GpsRunSessionsDaoManager get managers => GpsRunSessionsDaoManager(this);
}

class GpsRunSessionsDaoManager {
  final _$GpsRunSessionsDaoMixin _db;
  GpsRunSessionsDaoManager(this._db);
  $$GpsRunSessionsTableTableManager get gpsRunSessions =>
      $$GpsRunSessionsTableTableManager(
        _db.attachedDatabase,
        _db.gpsRunSessions,
      );
}
