import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/core/database/enums.dart';
import 'package:app_academia/features/cardio/data/cardio_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CardioRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CardioRepository(db);
  });
  tearDown(() => db.close());

  test('creates entries of different activity types', () async {
    await repo.createEntry(
      activityType: CardioActivityType.run,
      durationSeconds: 1800,
      distanceMeters: 5000,
      occurredAt: DateTime(2026, 1, 1),
    );
    await repo.createEntry(
      activityType: CardioActivityType.swim,
      durationSeconds: 900,
      calories: 300,
      occurredAt: DateTime(2026, 1, 2),
    );

    final all = await repo.watchAllEntries().first;
    expect(all, hasLength(2));
    expect(
      all.map((e) => e.activityType),
      containsAll([CardioActivityType.run, CardioActivityType.swim]),
    );
  });

  test('updates an entry', () async {
    await repo.createEntry(
      activityType: CardioActivityType.walk,
      durationSeconds: 1200,
      occurredAt: DateTime(2026, 1, 1),
    );
    final entry = (await repo.watchAllEntries().first).first;

    await repo.updateEntry(
      entry,
      activityType: CardioActivityType.bike,
      durationSeconds: 2400,
      distanceMeters: 15000,
      occurredAt: entry.occurredAt,
    );

    final updated = (await repo.watchAllEntries().first).first;
    expect(updated.activityType, CardioActivityType.bike);
    expect(updated.durationSeconds, 2400);
    expect(updated.distanceMeters, 15000);
  });

  test('deletes an entry', () async {
    await repo.createEntry(
      activityType: CardioActivityType.other,
      durationSeconds: 600,
      occurredAt: DateTime(2026, 1, 1),
    );
    final entry = (await repo.watchAllEntries().first).first;

    await repo.deleteEntry(entry.id);

    expect(await repo.watchAllEntries().first, isEmpty);
  });

  test('orders entries by most recent first', () async {
    await repo.createEntry(
      activityType: CardioActivityType.run,
      durationSeconds: 1800,
      occurredAt: DateTime(2026, 1, 1),
    );
    await repo.createEntry(
      activityType: CardioActivityType.run,
      durationSeconds: 1800,
      occurredAt: DateTime(2026, 6, 1),
    );

    final all = await repo.watchAllEntries().first;
    expect(all.first.occurredAt, DateTime(2026, 6, 1));
  });
}
