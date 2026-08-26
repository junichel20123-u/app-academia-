import 'package:drift/drift.dart';

import '../enums.dart';

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  // Stable identity for seeded/catalog exercises, addressable by a server or
  // an LLM without relying on the local (per-install) autoincrement id.
  // Custom exercises created by the user are never assigned one.
  TextColumn get slug => text().nullable().unique()();
  TextColumn get muscleGroup => textEnum<MuscleGroup>()();
  TextColumn get equipment => textEnum<Equipment>().nullable()();
  TextColumn get instructions => text().nullable()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
