import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v3-shaped database on disk (the schema before the M22
/// exercise-library expansion), then opens it with the current, v10-aware
/// `AppDatabase` — since `AppDatabase` always migrates to its current
/// schemaVersion, this exercises the v4-v7/v9/v10 `onUpgrade` branches in one
/// call. Existing installs should gain the new machine/cardio/cable/
/// bodyweight exercises without losing their existing rows (seeded,
/// custom, or one that happens to already have a colliding slug).
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v4_test');
    dbFile = File('${tempDir.path}/v3.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade adds the v4-v7/v9/v10 exercises without duplicating or '
      'overwriting existing rows', () async {
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
      "INSERT INTO exercises (name, slug, muscle_group, is_custom, created_at) "
      "VALUES ('Supino reto com barra', 'supino-reto-com-barra', 'chest', 0, 1700000000);",
    );
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, is_custom, created_at) "
      "VALUES ('Meu exercício', NULL, 'core', 1, 1700000000);",
    );
    // Simulates a slug that already collides with one of the v4 additions
    // (e.g. a prior manual insert) — the migration must skip it rather
    // than crash on the unique index or overwrite the existing name.
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom, created_at) "
      "VALUES ('Supino máquina (antigo)', 'supino-maquina', 'chest', 'machine', 0, 1700000000);",
    );
    raw.execute(
      "INSERT INTO user_settings_table (id, video_provider_id, unit_system, "
      "streak_freeze_enabled, ai_plan_builder_premium_unlocked, theme_mode_preference) "
      "VALUES (0, 'mock', 'metric', 0, 0, 'dark');",
    );
    raw.execute('PRAGMA user_version = 3;');
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final exercises = await db.exercisesDao.getAllExercises();

    // 3 pre-existing rows + all v4-v7/v9/v10 additions except the one that
    // collided.
    expect(
      exercises.length,
      3 +
          exercisesAddedInSchemaV4.length +
          exercisesAddedInSchemaV5.length +
          exercisesAddedInSchemaV6.length +
          exercisesAddedInSchemaV7.length +
          exercisesAddedInSchemaV9.length +
          exercisesAddedInSchemaV10.length -
          1,
    );

    // Pre-existing rows preserved as-is.
    expect(
      exercises.where((e) => e.name == 'Supino reto com barra'),
      hasLength(1),
    );
    expect(exercises.where((e) => e.name == 'Meu exercício'), hasLength(1));

    // The colliding slug was skipped, not overwritten or duplicated.
    final collided = exercises.where((e) => e.slug == 'supino-maquina');
    expect(collided, hasLength(1));
    expect(collided.single.name, 'Supino máquina (antigo)');

    // Every other v4-v7/v9/v10 exercise made it in.
    for (final added in [
      ...exercisesAddedInSchemaV4,
      ...exercisesAddedInSchemaV5,
      ...exercisesAddedInSchemaV6,
      ...exercisesAddedInSchemaV7,
      ...exercisesAddedInSchemaV9,
      ...exercisesAddedInSchemaV10,
    ]) {
      if (added.slug.value == 'supino-maquina') continue;
      expect(
        exercises.where((e) => e.slug == added.slug.value),
        hasLength(1),
        reason: '${added.slug.value} should have been inserted',
      );
    }

    // The fixed "Treinos iniciante" workouts were seeded too.
    final workouts = await db.workoutsDao.watchAllWorkouts().first;
    expect(workouts.where((w) => w.isSystem), hasLength(3));

    await db.close();
  });
}
