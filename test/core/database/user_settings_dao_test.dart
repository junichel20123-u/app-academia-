import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('returns default settings when nothing was saved yet', () async {
    final settings = await db.userSettingsDao.getSettings();
    expect(settings.videoProviderId, isNull);
    expect(settings.unitSystem, UnitSystem.metric);
  });

  test('saves and reloads settings as a single row', () async {
    await db.userSettingsDao.saveSettings(
      const UserSettingsTableCompanion(
        videoProviderId: Value('mock'),
        videoProviderBaseUrl: Value('https://example.com'),
        unitSystem: Value(UnitSystem.imperial),
      ),
    );

    final settings = await db.userSettingsDao.getSettings();
    expect(settings.videoProviderId, 'mock');
    expect(settings.unitSystem, UnitSystem.imperial);

    // Saving again must update the same row, not insert a second one.
    await db.userSettingsDao.saveSettings(
      const UserSettingsTableCompanion(
        videoProviderId: Value('other-provider'),
      ),
    );
    final updated = await db.userSettingsDao.getSettings();
    expect(updated.videoProviderId, 'other-provider');
  });
}
