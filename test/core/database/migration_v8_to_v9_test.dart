import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/seed/seed_beginner_workouts.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v8-shaped database on disk (schema before the M27
/// "Treinos iniciante" category), then opens it with the current, v9-aware
/// `AppDatabase` to exercise the real `onUpgrade` path: existing installs
/// should gain the new bodyweight cardio exercises and the 3 fixed,
/// non-editable "Treinos iniciante" workouts, without touching a
/// pre-existing user-created workout.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v9_test');
    dbFile = File('${tempDir.path}/v8.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade adds the v9 bodyweight exercises and seeds the fixed '
      '"Treinos iniciante" workouts without touching an existing user '
      'workout', () async {
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
    // Pre-existing bodyweight exercises (seeded since v1) that the fixed
    // "Treinos iniciante" workouts also reference alongside the new v9
    // ones — a real v8 database already has these; this fixture only
    // stubs in what the v9 seed actually needs to resolve every slug.
    for (final entry in const [
      ['Flexão de braço', 'flexao-de-braco', 'chest'],
      ['Burpee', 'burpee', 'fullBody'],
      ['Abdominal supra', 'abdominal-supra', 'core'],
      ['Elevação de pernas', 'elevacao-de-pernas', 'core'],
    ]) {
      raw.execute(
        "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
        "VALUES ('${entry[0]}', '${entry[1]}', '${entry[2]}', 'bodyweight', 0);",
      );
    }
    // A pre-existing, user-created workout — must survive untouched, and
    // must never be marked `is_system` by the migration.
    raw.execute(
      "INSERT INTO workouts (id, name) VALUES (1, 'Meu treino de peito');",
    );
    raw.execute(
      "INSERT INTO workout_exercises (workout_id, exercise_id, order_index, target_sets) "
      "VALUES (1, 1, 0, 3);",
    );
    raw.execute('PRAGMA user_version = 8;');
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));

    // v9 exercises added.
    final exercises = await db.exercisesDao.getAllExercises();
    for (final added in exercisesAddedInSchemaV9) {
      expect(
        exercises.where((e) => e.slug == added.slug.value),
        hasLength(1),
        reason: '${added.slug.value} should have been inserted',
      );
    }

    // Pre-existing user workout untouched and still not a system workout.
    final userWorkout = await db.workoutsDao.getWorkoutById(1);
    expect(userWorkout, isNotNull);
    expect(userWorkout!.name, 'Meu treino de peito');
    expect(userWorkout.isSystem, isFalse);

    // The 3 fixed "Treinos iniciante" workouts were seeded, each isSystem
    // and with the exact exercises/targets from seed_beginner_workouts.dart.
    final allWorkouts = await db.workoutsDao.watchAllWorkouts().first;
    final systemWorkouts = allWorkouts.where((w) => w.isSystem).toList();
    expect(systemWorkouts, hasLength(beginnerWorkoutSeeds.length));

    for (final seed in beginnerWorkoutSeeds) {
      final workout = systemWorkouts.singleWhere((w) => w.name == seed.name);
      final entries = await db.workoutsDao.getExercisesForWorkout(workout.id);
      expect(entries, hasLength(seed.exercises.length));
      for (var i = 0; i < seed.exercises.length; i++) {
        final expectedEntry = seed.exercises[i];
        final actualEntry = entries[i];
        final exercise = exercises.singleWhere(
          (e) => e.id == actualEntry.exerciseId,
        );
        expect(exercise.slug, expectedEntry.exerciseSlug);
        expect(actualEntry.targetSets, expectedEntry.targetSets);
        expect(actualEntry.targetReps, expectedEntry.targetReps);
        expect(actualEntry.targetRestSeconds, expectedEntry.targetRestSeconds);
      }
    }

    await db.close();
  });
}
