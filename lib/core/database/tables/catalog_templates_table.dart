import 'package:drift/drift.dart';

/// Flattened local cache of the remote workout-template catalog (synced in
/// a later milestone). `payloadJson` carries the full denormalized
/// program->workouts->exercises tree so the catalog screen works offline
/// once synced once; `slug` is the stable identity assigned by the server.
class CatalogTemplates extends Table {
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get goal => text().nullable()();
  TextColumn get difficulty => text().nullable()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {slug};
}
