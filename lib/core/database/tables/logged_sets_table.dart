import 'package:drift/drift.dart';

import 'exercises_table.dart';
import 'workout_exercises_table.dart';
import 'workout_sessions_table.dart';

class LoggedSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(WorkoutSessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get workoutExerciseId => integer().nullable().references(
    WorkoutExercises,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get setNumber => integer()();
  RealColumn get weight => real().nullable()();
  IntColumn get reps => integer().nullable()();
  RealColumn get rpe => real().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
