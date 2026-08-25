import 'package:app_academia/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = openTestDatabase());
  tearDown(() => db.close());

  test('orders weigh-ins by most recent first', () async {
    final older = DateTime(2026, 1, 1);
    final newer = DateTime(2026, 6, 1);

    await db.weighInsDao.insertWeighIn(
      WeighInsCompanion.insert(weightKg: 80.0, occurredAt: Value(older)),
    );
    await db.weighInsDao.insertWeighIn(
      WeighInsCompanion.insert(weightKg: 78.5, occurredAt: Value(newer)),
    );

    final all = await db.weighInsDao.watchAllWeighIns().first;
    expect(all, hasLength(2));
    expect(all.first.weightKg, 78.5);
    expect(all.last.weightKg, 80.0);
  });
}
