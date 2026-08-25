// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weigh_ins_dao.dart';

// ignore_for_file: type=lint
mixin _$WeighInsDaoMixin on DatabaseAccessor<AppDatabase> {
  $WeighInsTable get weighIns => attachedDatabase.weighIns;
  WeighInsDaoManager get managers => WeighInsDaoManager(this);
}

class WeighInsDaoManager {
  final _$WeighInsDaoMixin _db;
  WeighInsDaoManager(this._db);
  $$WeighInsTableTableManager get weighIns =>
      $$WeighInsTableTableManager(_db.attachedDatabase, _db.weighIns);
}
