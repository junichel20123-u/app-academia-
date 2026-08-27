import 'package:drift/drift.dart';

import '../enums.dart';

/// Single-row table: the app always reads/writes the row with id = 0.
class UserSettingsTable extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get videoProviderId => text().nullable()();
  TextColumn get videoProviderBaseUrl => text().nullable()();
  TextColumn get videoProviderApiKeyRef => text().nullable()();
  TextColumn get unitSystem =>
      textEnum<UnitSystem>().withDefault(Constant(UnitSystem.metric.name))();
  BoolColumn get streakFreezeEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get aiPlanBuilderPremiumUnlocked =>
      boolean().withDefault(const Constant(false))();
  TextColumn get themeModePreference =>
      textEnum<AppThemeMode>().withDefault(Constant(AppThemeMode.dark.name))();

  @override
  Set<Column> get primaryKey => {id};
}
