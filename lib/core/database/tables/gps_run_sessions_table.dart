import 'package:drift/drift.dart';

import '../enums.dart';

/// A GPS-tracked outdoor run/walk, in progress or finished. Deliberately
/// holds no coordinate columns — only the aggregate the user actually asked
/// to see (distance, time), checkpointed periodically while tracking so an
/// OS-killed foreground service loses at most the gap since the last
/// checkpoint, never the whole session. `startedAt` is the source of truth
/// for elapsed time (recomputed as `now - startedAt` on every read), so
/// duration never depends on any in-memory state surviving a restart.
class GpsRunSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activityType => textEnum<CardioActivityType>()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  RealColumn get accumulatedDistanceMeters =>
      real().withDefault(const Constant(0))();
  TextColumn get status => textEnum<GpsRunSessionStatus>()();
}
