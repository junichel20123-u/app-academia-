import 'package:drift/drift.dart';

import '../enums.dart';
import 'workouts_table.dart';

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId => integer().nullable().references(
    Workouts,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get status => textEnum<WorkoutSessionStatus>()();
  TextColumn get notes => text().nullable()();
}
