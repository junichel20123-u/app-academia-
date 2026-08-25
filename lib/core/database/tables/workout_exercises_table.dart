import 'package:drift/drift.dart';

import 'exercises_table.dart';
import 'workouts_table.dart';

class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutId =>
      integer().references(Workouts, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId =>
      integer().references(Exercises, #id, onDelete: KeyAction.restrict)();
  IntColumn get orderIndex => integer()();
  IntColumn get targetSets => integer()();
  IntColumn get targetReps => integer().nullable()();
  RealColumn get targetWeight => real().nullable()();
  IntColumn get targetRestSeconds => integer().nullable()();
  TextColumn get notes => text().nullable()();
}
