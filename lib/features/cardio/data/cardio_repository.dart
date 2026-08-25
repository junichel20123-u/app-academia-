import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';

class CardioRepository {
  CardioRepository(this._db);

  final AppDatabase _db;

  Stream<List<CardioEntry>> watchAllEntries() =>
      _db.cardioDao.watchAllEntries();

  Future<int> createEntry({
    required CardioActivityType activityType,
    required int durationSeconds,
    double? distanceMeters,
    int? calories,
    required DateTime occurredAt,
    String? notes,
  }) {
    return _db.cardioDao.insertEntry(
      CardioEntriesCompanion.insert(
        activityType: activityType,
        durationSeconds: durationSeconds,
        distanceMeters: Value(distanceMeters),
        calories: Value(calories),
        occurredAt: Value(occurredAt),
        notes: Value(notes),
      ),
    );
  }

  Future<void> updateEntry(
    CardioEntry entry, {
    required CardioActivityType activityType,
    required int durationSeconds,
    double? distanceMeters,
    int? calories,
    required DateTime occurredAt,
    String? notes,
  }) {
    return _db.cardioDao.updateEntry(
      entry.copyWith(
        activityType: activityType,
        durationSeconds: durationSeconds,
        distanceMeters: Value(distanceMeters),
        calories: Value(calories),
        occurredAt: occurredAt,
        notes: Value(notes),
      ),
    );
  }

  Future<void> deleteEntry(int id) => _db.cardioDao.deleteEntry(id);
}
