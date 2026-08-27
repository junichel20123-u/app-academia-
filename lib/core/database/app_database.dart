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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await batch((b) => b.insertAll(exercises, seedExercises));
    },
    onUpgrade: (m, from, to) async {
      // The v2 and v3 branches only touch independent columns/tables (neither
      // reads anything the other writes), so a database that jumps straight
      // from v1 to v3 in one open — skipping v2 entirely, e.g. an old
      // cached APK reinstalled after a gap — would run either order safely.
      // The v4 branch is the one exception: it relies on the unique index
      // the v2 branch creates on `exercises.slug` for `insertOrIgnore` to
      // skip rows this install already has, so all branches are kept in
      // chronological (version) order — a from=1 jump straight to v4 runs
      // v2's branch first within this same call, so the index always exists
      // by the time v4's insert runs.
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
      if (from < 3) {
        await m.addColumn(
          userSettingsTable,
          userSettingsTable.themeModePreference,
        );
      }
      if (from < 4) {
        // insertOrIgnore: safe no-op for a slug this install already has
        // (e.g. a user who manually created a custom exercise that happens
        // to collide, or a v1->v4 jump where onCreate never ran).
        for (final entry in exercisesAddedInSchemaV4) {
          await into(exercises).insert(entry, mode: InsertMode.insertOrIgnore);
        }
      }
    },
    beforeOpen: (details) async {
      // SQLite ignores ON DELETE CASCADE/RESTRICT/SET NULL unless this is on.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
