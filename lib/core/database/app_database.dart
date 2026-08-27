import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/slugify.dart';
import 'daos/cardio_dao.dart';
import 'daos/catalog_templates_dao.dart';
import 'daos/exercises_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/user_settings_dao.dart';
import 'daos/weigh_ins_dao.dart';
import 'daos/workouts_dao.dart';
import 'enums.dart';
import 'seed/seed_exercises.dart';
import 'tables/cardio_entries_table.dart';
import 'tables/catalog_templates_table.dart';
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
    CatalogTemplates,
  ],
  daos: [
    ExercisesDao,
    WorkoutsDao,
    SessionsDao,
    CardioDao,
    WeighInsDao,
    UserSettingsDao,
    CatalogTemplatesDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await batch((b) => b.insertAll(exercises, seedExercises));
    },
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        await m.addColumn(
          userSettingsTable,
          userSettingsTable.themeModePreference,
        );
      }
      if (from < 2) {
        // SQLite rejects `ALTER TABLE ... ADD COLUMN ... UNIQUE` directly,
        // so the column is added plain here and uniqueness is enforced by a
        // separate index instead (multiple NULLs don't conflict under it,
        // which is fine since the backfill below runs right after).
        await customStatement('ALTER TABLE exercises ADD COLUMN slug TEXT;');
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_exercises_slug ON exercises (slug);',
        );
        await m.addColumn(
          userSettingsTable,
          userSettingsTable.aiPlanBuilderPremiumUnlocked,
        );
        await m.createTable(catalogTemplates);

        final seeded = await (select(
          exercises,
        )..where((t) => t.isCustom.equals(false))).get();
        for (final exercise in seeded) {
          await (update(exercises)..where((t) => t.id.equals(exercise.id)))
              .write(ExercisesCompanion(slug: Value(slugify(exercise.name))));
        }
      }
    },
    beforeOpen: (details) async {
      // SQLite ignores ON DELETE CASCADE/RESTRICT/SET NULL unless this is on.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
