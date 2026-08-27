import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v6-shaped database on disk, then opens it with the
/// current, v7-aware `AppDatabase` to exercise the real `onUpgrade` path:
/// existing installs should gain the new machine exercises (hip thrust
/// machine, seated calf raise, Graviton, decline-bench sit-up) without
/// losing existing rows or duplicating one that already collides by slug.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v7_test');
    dbFile = File('${tempDir.path}/v6.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade adds the v7 machine exercises without duplicating or '
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
    ''');
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Leg press', 'leg-press', 'legs', 'machine', 0);",
    );
    // A slug that already collides with one of the v7 additions.
    raw.execute(
      "INSERT INTO exercises (name, slug, muscle_group, equipment, is_custom) "
      "VALUES ('Graviton (antigo)', 'graviton-barra-fixa-paralelas-assistidas', 'fullBody', 'machine', 0);",
    );
    raw.execute(
      "INSERT INTO user_settings_table (id, video_provider_id, unit_system, "
      "streak_freeze_enabled, ai_plan_builder_premium_unlocked, theme_mode_preference) "
      "VALUES (0, 'mock', 'metric', 0, 0, 'dark');",
    );
    raw.execute('PRAGMA user_version = 6;');
    raw.close();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    final exercises = await db.exercisesDao.getAllExercises();

    // Pre-existing row untouched.
    expect(exercises.where((e) => e.slug == 'leg-press'), hasLength(1));

    // The colliding slug was skipped, not overwritten or duplicated.
    final graviton = exercisesAddedInSchemaV7.singleWhere(
      (e) => e.name.value == 'Graviton (barra fixa/paralelas assistidas)',
    );
    final collided = exercises.where((e) => e.slug == graviton.slug.value);
    expect(collided, hasLength(1));
    expect(collided.single.name, 'Graviton (antigo)');

    // Every other v7 exercise made it in.
    for (final added in exercisesAddedInSchemaV7) {
      if (added.slug.value == graviton.slug.value) continue;
      expect(
        exercises.where((e) => e.slug == added.slug.value),
        hasLength(1),
        reason: '${added.slug.value} should have been inserted',
      );
    }

    await db.close();
  });
}
