import 'package:drift/drift.dart';

import '../enums.dart';

class CardioEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activityType => textEnum<CardioActivityType>()();
  IntColumn get durationSeconds => integer()();
  RealColumn get distanceMeters => real().nullable()();
  IntColumn get calories => integer().nullable()();
  DateTimeColumn get occurredAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
}
