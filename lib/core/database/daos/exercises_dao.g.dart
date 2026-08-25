// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercises_dao.dart';

// ignore_for_file: type=lint
mixin _$ExercisesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExercisesTable get exercises => attachedDatabase.exercises;
  $ExerciseVideosTable get exerciseVideos => attachedDatabase.exerciseVideos;
  ExercisesDaoManager get managers => ExercisesDaoManager(this);
}

class ExercisesDaoManager {
  final _$ExercisesDaoMixin _db;
  ExercisesDaoManager(this._db);
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db.attachedDatabase, _db.exercises);
  $$ExerciseVideosTableTableManager get exerciseVideos =>
      $$ExerciseVideosTableTableManager(
        _db.attachedDatabase,
        _db.exerciseVideos,
      );
}
