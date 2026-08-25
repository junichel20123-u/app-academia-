// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workouts_dao.dart';

// ignore_for_file: type=lint
mixin _$WorkoutsDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkoutsTable get workouts => attachedDatabase.workouts;
  $ExercisesTable get exercises => attachedDatabase.exercises;
  $WorkoutExercisesTable get workoutExercises =>
      attachedDatabase.workoutExercises;
  WorkoutsDaoManager get managers => WorkoutsDaoManager(this);
}

class WorkoutsDaoManager {
  final _$WorkoutsDaoMixin _db;
  WorkoutsDaoManager(this._db);
  $$WorkoutsTableTableManager get workouts =>
      $$WorkoutsTableTableManager(_db.attachedDatabase, _db.workouts);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db.attachedDatabase, _db.exercises);
  $$WorkoutExercisesTableTableManager get workoutExercises =>
      $$WorkoutExercisesTableTableManager(
        _db.attachedDatabase,
        _db.workoutExercises,
      );
}
