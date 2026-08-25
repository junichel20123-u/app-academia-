import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

class WeighInRepository {
  WeighInRepository(this._db);

  final AppDatabase _db;

  Stream<List<WeighIn>> watchAllWeighIns() =>
      _db.weighInsDao.watchAllWeighIns();

  Future<int> createWeighIn({
    required double weightKg,
    required DateTime occurredAt,
    String? notes,
  }) {
    return _db.weighInsDao.insertWeighIn(
      WeighInsCompanion.insert(
        weightKg: weightKg,
        occurredAt: Value(occurredAt),
        notes: Value(notes),
      ),
    );
  }

  Future<void> updateWeighIn(
    WeighIn entry, {
    required double weightKg,
    required DateTime occurredAt,
    String? notes,
  }) {
    return _db.weighInsDao.updateWeighIn(
      entry.copyWith(
        weightKg: weightKg,
        occurredAt: occurredAt,
        notes: Value(notes),
      ),
    );
  }

  Future<void> deleteWeighIn(int id) => _db.weighInsDao.deleteWeighIn(id);
}
