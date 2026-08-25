import 'package:app_academia/core/database/app_database.dart';
import 'package:app_academia/features/weigh_in/data/weigh_in_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late WeighInRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = WeighInRepository(db);
  });
  tearDown(() => db.close());

  test('orders entries by most recent first', () async {
    await repo.createWeighIn(weightKg: 80, occurredAt: DateTime(2026, 1, 1));
    await repo.createWeighIn(weightKg: 78.5, occurredAt: DateTime(2026, 6, 1));

    final all = await repo.watchAllWeighIns().first;
    expect(all, hasLength(2));
    expect(all.first.weightKg, 78.5);
  });

  test('updates an entry', () async {
    await repo.createWeighIn(weightKg: 80, occurredAt: DateTime(2026, 1, 1));
    final entry = (await repo.watchAllWeighIns().first).first;

    await repo.updateWeighIn(
      entry,
      weightKg: 79,
      occurredAt: entry.occurredAt,
      notes: 'após o café',
    );

    final updated = (await repo.watchAllWeighIns().first).first;
    expect(updated.weightKg, 79);
    expect(updated.notes, 'após o café');
  });

  test('deletes an entry', () async {
    await repo.createWeighIn(weightKg: 80, occurredAt: DateTime(2026, 1, 1));
    final entry = (await repo.watchAllWeighIns().first).first;

    await repo.deleteWeighIn(entry.id);

    expect(await repo.watchAllWeighIns().first, isEmpty);
  });
}
