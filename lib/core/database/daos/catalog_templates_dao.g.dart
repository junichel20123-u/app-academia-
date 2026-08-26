// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_templates_dao.dart';

// ignore_for_file: type=lint
mixin _$CatalogTemplatesDaoMixin on DatabaseAccessor<AppDatabase> {
  $CatalogTemplatesTable get catalogTemplates =>
      attachedDatabase.catalogTemplates;
  CatalogTemplatesDaoManager get managers => CatalogTemplatesDaoManager(this);
}

class CatalogTemplatesDaoManager {
  final _$CatalogTemplatesDaoMixin _db;
  CatalogTemplatesDaoManager(this._db);
  $$CatalogTemplatesTableTableManager get catalogTemplates =>
      $$CatalogTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.catalogTemplates,
      );
}
