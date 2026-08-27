import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v4-shaped database on disk, then opens it with the
/// current, v5-aware `AppDatabase` to exercise the real `onUpgrade` path:
/// existing installs should (1) get "Puxada frontal" corrected from
/// `Equipment.machine` to `Equipment.cable` — it was mislabeled, real
/// lat-pulldown machines are cable/weight-stack based — without touching a
/// user's own custom exercise of the same name, and (2) gain the new
/// cable/pulley exercises without losing existing rows.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v5_test');
    dbFile = File('${tempDir.path}/v4.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade fixes the Puxada frontal equipment mislabel and adds the v5 '
      'cable exercises', () async {
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
    ''');
    // The pre-fix seeded row, mislabeled as a generic machine.
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Puxada frontal', 'puxada-frontal', 'back', 'machine', 0);",
    );
    // A user's own custom exercise with the same name — slug NULL, must
    // never be touched by the slug-matched UPDATE.
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Puxada frontal', NULL, 'back', 'machine', 1);",
    );
    // A slug that already collides with one of the v5 additions.
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Remada baixa (antiga)', 'remada-baixa-na-polia', 'back', 'cable', 0);",
    );
    raw.execute(
      "INSERT INTO user_settings_table (id, video_provider_id, unit_system, "
      "streak_freeze_enabled, ai_plan_builder_premium_unlocked, theme_mode_preference) "
      "VALUES (0, 'mock', 'metric', 0, 0, 'dark');",
    );
    raw.execute('PRAGMA user_version = 4;');
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final exercises = await db.exercisesDao.getAllExercises();

    // The seeded row was corrected to cable.
    final seededPulldown = exercises.singleWhere(
      (e) => e.slug == 'puxada-frontal',
    );
    expect(seededPulldown.equipment, Equipment.cable);
    expect(seededPulldown.isCustom, isFalse);

    // The custom exercise of the same name was left completely alone.
    final customPulldown = exercises.singleWhere(
      (e) => e.isCustom && e.name == 'Puxada frontal',
    );
    expect(customPulldown.equipment, Equipment.machine);

    // The colliding slug was skipped, not overwritten or duplicated.
    final collided = exercises.where((e) => e.slug == 'remada-baixa-na-polia');
    expect(collided, hasLength(1));
    expect(collided.single.name, 'Remada baixa (antiga)');

    // Every other v5 exercise made it in.
    for (final added in exercisesAddedInSchemaV5) {
      if (added.slug.value == 'remada-baixa-na-polia') continue;
      expect(
        exercises.where((e) => e.slug == added.slug.value),
        hasLength(1),
        reason: '${added.slug.value} should have been inserted',
      );
    }

    await db.close();
  });
}
