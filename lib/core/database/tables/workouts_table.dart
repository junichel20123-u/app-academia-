import 'package:drift/drift.dart';

class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  // Built-in, fixed workouts (e.g. the "Treinos iniciante" category) that
  // the user can duplicate but never edit or delete directly.
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
}
