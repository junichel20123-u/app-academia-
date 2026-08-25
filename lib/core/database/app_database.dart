import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/cardio_dao.dart';
import 'daos/exercises_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/user_settings_dao.dart';
import 'daos/weigh_ins_dao.dart';
import 'daos/workouts_dao.dart';
import 'enums.dart';
import 'seed/seed_exercises.dart';
import 'tables/cardio_entries_table.dart';
import 'tables/exercise_videos_table.dart';
import 'tables/exercises_table.dart';
import 'tables/logged_sets_table.dart';
import 'tables/user_settings_table.dart';
import 'tables/weigh_ins_table.dart';
import 'tables/workout_exercises_table.dart';
import 'tables/workout_sessions_table.dart';
import 'tables/workouts_table.dart';

part 'app_database.g.dart';

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_academia.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(
  tables: [
    Exercises,
    ExerciseVideos,
    Workouts,
    WorkoutExercises,
    WorkoutSessions,
    LoggedSets,
    CardioEntries,
    WeighIns,
    UserSettingsTable,
  ],
  daos: [
    ExercisesDao,
    WorkoutsDao,
    SessionsDao,
    CardioDao,
    WeighInsDao,
    UserSettingsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await batch((b) => b.insertAll(exercises, seedExercises));
    },
    beforeOpen: (details) async {
      // SQLite ignores ON DELETE CASCADE/RESTRICT/SET NULL unless this is on.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
