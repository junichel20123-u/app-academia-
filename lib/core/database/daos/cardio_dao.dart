import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/cardio_entries_table.dart';

part 'cardio_dao.g.dart';

@DriftAccessor(tables: [CardioEntries])
class CardioDao extends DatabaseAccessor<AppDatabase> with _$CardioDaoMixin {
  CardioDao(super.db);

  Stream<List<CardioEntry>> watchAllEntries() => (select(
    cardioEntries,
  )..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])).watch();

  Future<int> insertEntry(CardioEntriesCompanion entry) =>
      into(cardioEntries).insert(entry);

  Future<bool> updateEntry(CardioEntry entry) =>
      update(cardioEntries).replace(entry);

  Future<int> deleteEntry(int id) =>
      (delete(cardioEntries)..where((t) => t.id.equals(id))).go();
}
