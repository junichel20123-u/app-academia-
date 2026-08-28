import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v7-shaped database on disk, then opens it with the
/// current, v8-aware `AppDatabase` to exercise the real `onUpgrade` path:
/// existing installs should gain the new (empty) `gps_run_sessions` table
/// without losing or touching any pre-existing row.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v8_test');
    dbFile = File('${tempDir.path}/v7.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade adds the (empty) gps_run_sessions table without touching '
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
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Leg press', 'leg-press', 'legs', 'machine', 0);",
    );
    raw.execute(
      "INSERT INTO user_settings_table (id, video_provider_id, unit_system, "
      "streak_freeze_enabled, ai_plan_builder_premium_unlocked, theme_mode_preference) "
      "VALUES (0, 'mock', 'metric', 0, 0, 'dark');",
    );
    raw.execute('PRAGMA user_version = 7;');
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    // Pre-existing row untouched.
    final exercises = await db.exercisesDao.getAllExercises();
    expect(exercises.where((e) => e.slug == 'leg-press'), hasLength(1));

    // New table exists, is empty, and is insertable/queryable.
    final runs = await db.gpsRunSessionsDao.watchActiveRun().first;
    expect(runs, isNull);

    final id = await db.gpsRunSessionsDao.startRun(
      GpsRunSessionsCompanion.insert(
        activityType: CardioActivityType.run,
        status: GpsRunSessionStatus.inProgress,
      ),
    );
    final inserted = await db.gpsRunSessionsDao.getRunById(id);
    expect(inserted, isNotNull);
    expect(inserted!.status, GpsRunSessionStatus.inProgress);
    expect(inserted.accumulatedDistanceMeters, 0);

    await db.close();
  });
}
