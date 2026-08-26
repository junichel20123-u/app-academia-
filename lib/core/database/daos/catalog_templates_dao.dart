import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/catalog_templates_table.dart';

part 'catalog_templates_dao.g.dart';

@DriftAccessor(tables: [CatalogTemplates])
class CatalogTemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$CatalogTemplatesDaoMixin {
  CatalogTemplatesDao(super.db);

  Future<List<CatalogTemplate>> getAllTemplates() =>
      select(catalogTemplates).get();

  Stream<List<CatalogTemplate>> watchAllTemplates() =>
      select(catalogTemplates).watch();

  Future<CatalogTemplate?> getBySlug(String slug) => (select(
    catalogTemplates,
  )..where((t) => t.slug.equals(slug))).getSingleOrNull();

  /// Full-replace sync: clears the local cache and reinserts the latest
  /// snapshot from the server. Simple and correct for now; an incremental
  /// strategy can replace this once the sync feature actually needs it.
  Future<void> replaceAll(List<CatalogTemplatesCompanion> entries) {
    return transaction(() async {
      await delete(catalogTemplates).go();
      await batch((b) => b.insertAll(catalogTemplates, entries));
    });
  }
}
