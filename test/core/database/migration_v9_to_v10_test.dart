import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v9-shaped database on disk, then opens it with the
/// current, v10-aware `AppDatabase` to exercise the real `onUpgrade` path:
/// existing installs should gain the v10 exercises (traps, obliques, plain
/// side plank, Romanian deadlift, lying leg curl) without duplicating or
/// overwriting anything already there.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v10_test');
    dbFile = File('${tempDir.path}/v9.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade adds the v10 exercises without duplicating or overwriting '
      'existing rows', () async {
    final raw = sqlite3.sqlite3.open(dbFile.path);
    raw.execute('''
      CREATE TABLE exercises (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        slug TEXT NULL,
        muscle_group TEXT NOT NULL,
        equipment TEXT NULL,
        instructions TEXT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER))
      );
      CREATE UNIQUE INDEX idx_exercises_slug ON exercises (slug);
      CREATE TABLE user_settings_table (
        id INTEGER NOT NULL DEFAULT 0,
        video_provider_id TEXT NULL,
        video_provider_base_url TEXT NULL,
        video_provider_api_key_ref TEXT NULL,
        unit_system TEXT NOT NULL DEFAULT 'metric',
        streak_freeze_enabled INTEGER NOT NULL DEFAULT 0,
        ai_plan_builder_premium_unlocked INTEGER NOT NULL DEFAULT 0,
        theme_mode_preference TEXT NOT NULL DEFAULT 'dark',
        PRIMARY KEY (id)
      );
      CREATE TABLE catalog_templates (
        slug TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT NULL,
        goal TEXT NULL,
        difficulty TEXT NULL,
        payload_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (slug)
      );
      CREATE TABLE workouts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        notes TEXT NULL,
        created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        updated_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        is_system INTEGER NOT NULL DEFAULT 0
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
      CREATE TABLE gps_run_sessions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        activity_type TEXT NOT NULL,
        started_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)),
        completed_at INTEGER NULL,
        accumulated_distance_meters REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL
      );
    ''');
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Leg press', 'leg-press', 'legs', 'machine', 0);",
    );
    // A custom exercise the user created themselves whose slug collides
    // with one of the v10 additions — `insertOrIgnore` must leave it alone
    // rather than overwrite it or fail the whole migration.
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Prancha lateral', 'prancha-lateral', 'core', 'bodyweight', 1);",
    );
    raw.execute('PRAGMA user_version = 9;');
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    final exercises = await db.exercisesDao.getAllExercises();

    // Every v10 exercise resolves to exactly one row — no duplicates.
    for (final added in exercisesAddedInSchemaV10) {
      expect(
        exercises.where((e) => e.slug == added.slug.value),
        hasLength(1),
        reason: '${added.slug.value} should exist exactly once',
      );
    }

    // The colliding custom exercise kept its own identity — the migration
    // skipped it instead of overwriting `isCustom`.
    final sidePlank = exercises.singleWhere((e) => e.slug == 'prancha-lateral');
    expect(sidePlank.isCustom, isTrue);

    // Pre-existing seeded row untouched.
    expect(exercises.where((e) => e.slug == 'leg-press'), hasLength(1));

    await db.close();
  });
}
