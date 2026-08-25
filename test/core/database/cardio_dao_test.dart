import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('inserts, updates and deletes a cardio entry', () async {
    final id = await db.cardioDao.insertEntry(
      CardioEntriesCompanion.insert(
        activityType: CardioActivityType.run,
        durationSeconds: 1800,
        distanceMeters: const Value(5000),
      ),
    );

    var all = await db.cardioDao.watchAllEntries().first;
    expect(all, hasLength(1));
    expect(all.first.activityType, CardioActivityType.run);

    await db.cardioDao.updateEntry(all.first.copyWith(durationSeconds: 1900));
    all = await db.cardioDao.watchAllEntries().first;
    expect(all.first.durationSeconds, 1900);

    await db.cardioDao.deleteEntry(id);
    all = await db.cardioDao.watchAllEntries().first;
    expect(all, isEmpty);
  });
}
