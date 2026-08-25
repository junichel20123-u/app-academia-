import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/weigh_ins_table.dart';

part 'weigh_ins_dao.g.dart';

@DriftAccessor(tables: [WeighIns])
class WeighInsDao extends DatabaseAccessor<AppDatabase>
    with _$WeighInsDaoMixin {
  WeighInsDao(super.db);

  Stream<List<WeighIn>> watchAllWeighIns() => (select(
    weighIns,
  )..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])).watch();

  Future<int> insertWeighIn(WeighInsCompanion entry) =>
      into(weighIns).insert(entry);

  Future<bool> updateWeighIn(WeighIn entry) => update(weighIns).replace(entry);

  Future<int> deleteWeighIn(int id) =>
      (delete(weighIns)..where((t) => t.id.equals(id))).go();
}
