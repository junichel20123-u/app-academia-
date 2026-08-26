import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/utils/slugify.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v1-shaped database on disk (the schema before `slug`,
/// `aiPlanBuilderPremiumUnlocked` and `catalog_templates` existed), then
/// opens it with the current, v2-aware `AppDatabase` to exercise the real
/// `onUpgrade` backfill path — something `NativeDatabase.memory()` can't
/// cover, since a fresh in-memory database always takes the `onCreate`
/// path. Column encodings below (booleans/enums as INTEGER 0/1 and TEXT,
/// dates as epoch seconds, snake_case names) were confirmed empirically
/// against what Drift actually writes for this schema.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_test');
    dbFile = File('${tempDir.path}/v1.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test(
    'onUpgrade backfills exercise slugs and adds the new columns/table',
    () async {
      final raw = sqlite3.sqlite3.open(dbFile.path);
      raw.execute('''
        CREATE TABLE exercises (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          muscle_group TEXT NOT NULL,
          equipment TEXT NULL,
          instructions TEXT NULL,
          is_custom INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
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
      ''');
      raw.execute(
        "INSERT INTO exercises (name, muscle_group, is_custom, created_at) "
        "VALUES ('Supino reto com barra', 'chest', 0, 1700000000);",
      );
      raw.execute(
        "INSERT INTO exercises (name, muscle_group, is_custom, created_at) "
        "VALUES ('Meu exercício', 'core', 1, 1700000000);",
      );
      raw.execute(
        "INSERT INTO user_settings_table (id, video_provider_id, unit_system, streak_freeze_enabled) "
        "VALUES (0, 'mock', 'metric', 0);",
      );
      raw.execute('PRAGMA user_version = 1;');
      raw.close();

      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      final exercises = await db.exercisesDao.getAllExercises();

      final seeded = exercises.firstWhere((e) => !e.isCustom);
      expect(seeded.slug, slugify('Supino reto com barra'));

      final custom = exercises.firstWhere((e) => e.isCustom);
      expect(custom.slug, isNull);

      expect(await db.catalogTemplatesDao.getAllTemplates(), isEmpty);

      final settings = await db.userSettingsDao.getSettings();
      // Confirms this is the real pre-existing row (preserved through the
      // upgrade), not the DAO's empty-database fallback.
      expect(settings.videoProviderId, 'mock');
      expect(settings.aiPlanBuilderPremiumUnlocked, isFalse);

      await db.close();
    },
  );
}
