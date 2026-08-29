import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:app_academia/core/utils/slugify.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v1-shaped database (same shape as
/// `migration_v1_to_v2_test.dart`), then opens it directly with the current,
/// v10-aware `AppDatabase` — exercising a jump straight from v1 to the
/// current schemaVersion in one `onUpgrade` call, skipping every
/// intermediate version. This is a real (if uncommon) upgrade path: an old
/// cached APK build reinstalled after a gap would never have passed
/// through the intermediate schema versions. The v2/v3 branches only touch
/// independent columns/tables and would run in either order; the v4-v7/v9/v10
/// branches depend on v2's branch having already created the
/// `exercises.slug` column and its unique index (see the comment in
/// `app_database.dart`) — this test proves the whole chain works end to
/// end rather than by code inspection.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v1_v7_test');
    dbFile = File('${tempDir.path}/v1.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade from v1 straight to v10 applies every migration', () async {
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE exercises (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        equipment TEXT NULL,
        instructions TEXT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
      );
      CREATE TABLE user_settings_table (
        id INTEGER NOT NULL DEFAULT 0,
        video_provider_id TEXT NULL,
        video_provider_base_url TEXT NULL,
        video_provider_api_key_ref TEXT NULL,
        unit_system TEXT NOT NULL DEFAULT 'metric',
        streak_freeze_enabled INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (id)
      );
      CREATE TABLE workouts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        notes TEXT NULL,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
      );
      CREATE TABLE workout_exercises (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL REFERENCES workouts (id) ON DELETE CASCADE,
        exercise_id INTEGER NOT NULL REFERENCES exercises (id) ON DELETE RESTRICT,
        order_index INTEGER NOT NULL,
        target_sets INTEGER NOT NULL,
        target_reps INTEGER NULL,
        target_weight REAL NULL,
        target_rest_seconds INTEGER NULL,
        notes TEXT NULL
      );
    ''');
    raw.execute(
      "INSERT INTO exercises (name, muscle_group, is_custom, created_at) "
      "VALUES ('Supino reto com barra', 'chest', 0, 1700000000);",
    );
    raw.execute(
      "INSERT INTO user_settings_table (id, video_provider_id, unit_system, streak_freeze_enabled) "
      "VALUES (0, 'mock', 'metric', 0);",
    );
    raw.execute('PRAGMA user_version = 1;');
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    // v2 fields backfilled.
    final exercises = await db.exercisesDao.getAllExercises();
    final original = exercises.singleWhere(
      (e) => e.name == 'Supino reto com barra',
    );
    expect(original.slug, slugify('Supino reto com barra'));
    expect(await db.catalogTemplatesDao.getAllTemplates(), isEmpty);

    // v3 field defaulted.
    final settings = await db.userSettingsDao.getSettings();
    expect(settings.videoProviderId, 'mock');
    expect(settings.aiPlanBuilderPremiumUnlocked, isFalse);
    expect(settings.themeModePreference, AppThemeMode.dark);

    // v4-v10: the new machine/cardio/cable/bodyweight exercises were added
    // on top of the pre-existing row (v8 added no exercises, only the
    // independent gps_run_sessions table).
    expect(
      exercises.length,
      1 +
          exercisesAddedInSchemaV4.length +
          exercisesAddedInSchemaV5.length +
          exercisesAddedInSchemaV6.length +
          exercisesAddedInSchemaV7.length +
          exercisesAddedInSchemaV9.length +
          exercisesAddedInSchemaV10.length,
    );
    for (final added in [
      ...exercisesAddedInSchemaV4,
      ...exercisesAddedInSchemaV5,
      ...exercisesAddedInSchemaV6,
      ...exercisesAddedInSchemaV7,
      ...exercisesAddedInSchemaV9,
      ...exercisesAddedInSchemaV10,
    ]) {
      expect(exercises.where((e) => e.slug == added.slug.value), hasLength(1));
    }

    // v9: the fixed "Treinos iniciante" workouts were seeded too.
    final workouts = await db.workoutsDao.watchAllWorkouts().first;
    expect(workouts.where((w) => w.isSystem), hasLength(3));

    await db.close();
  });
}
