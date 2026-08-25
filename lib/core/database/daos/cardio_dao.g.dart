// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cardio_dao.dart';

// ignore_for_file: type=lint
mixin _$CardioDaoMixin on DatabaseAccessor<AppDatabase> {
  $CardioEntriesTable get cardioEntries => attachedDatabase.cardioEntries;
  CardioDaoManager get managers => CardioDaoManager(this);
}

class CardioDaoManager {
  final _$CardioDaoMixin _db;
  CardioDaoManager(this._db);
  $$CardioEntriesTableTableManager get cardioEntries =>
      $$CardioEntriesTableTableManager(_db.attachedDatabase, _db.cardioEntries);
}
