import 'package:drift/drift.dart';

import '../enums.dart';
import 'exercises_table.dart';

class ExerciseVideos extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.cascade)();
  TextColumn get providerId => text()();
  TextColumn get jobId => text().nullable()();
  TextColumn get status => textEnum<ExerciseVideoStatus>()();
  TextColumn get localFilePath => text().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get requestedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();
}
