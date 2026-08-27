import 'dart:io';

import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/core/database/seed/seed_exercises.dart';
import 'package:app_academia/core/utils/slugify.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Hand-writes a v1-shaped database (same shape as
/// `migration_v1_to_v2_test.dart`), then opens it directly with the current
/// v6-aware `AppDatabase` — exercising a jump straight from v1 to v6 in one
/// `onUpgrade` call, skipping v2/v3/v4/v5 entirely. This is a real (if
/// uncommon) upgrade path: an old cached APK build reinstalled after a gap
/// would never have passed through the intermediate schema versions. The
/// v2/v3 branches only touch independent columns/tables and would run in
/// either order; the v4/v5/v6 branches depend on v2's branch having already
/// created the `exercises.slug` column and its unique index (see the
/// comment in `app_database.dart`) — this test proves the whole chain works
/// end to end rather than by code inspection.
void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('migration_v1_v6_test');
    dbFile = File('${tempDir.path}/v1.sqlite');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('onUpgrade from v1 straight to v6 applies every migration', () async {
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

    // v4/v5/v6: the new machine/cardio/cable exercises were added on top of
    // the pre-existing row.
    expect(
      exercises.length,
      1 +
          exercisesAddedInSchemaV4.length +
          exercisesAddedInSchemaV5.length +
          exercisesAddedInSchemaV6.length,
    );
    for (final added in [
      ...exercisesAddedInSchemaV4,
      ...exercisesAddedInSchemaV5,
      ...exercisesAddedInSchemaV6,
    ]) {
      expect(exercises.where((e) => e.slug == added.slug.value), hasLength(1));
    }

    await db.close();
  });
}
