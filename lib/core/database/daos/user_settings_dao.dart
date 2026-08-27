import 'package:drift/drift.dart';

import '../app_database.dart';
import '../enums.dart';
import '../tables/user_settings_table.dart';

part 'user_settings_dao.g.dart';

@DriftAccessor(tables: [UserSettingsTable])
class UserSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$UserSettingsDaoMixin {
  UserSettingsDao(super.db);

  Stream<UserSettingsTableData> watchSettings() {
    return select(userSettingsTable)
        .watchSingleOrNull()
        .map((row) => row ?? _defaultRow);
  }

  Future<UserSettingsTableData> getSettings() async {
    final row = await (select(
      userSettingsTable,
    )..where((t) => t.id.equals(0))).getSingleOrNull();
    return row ?? _defaultRow;
  }

  Future<void> saveSettings(UserSettingsTableCompanion entry) {
    return into(userSettingsTable)
        .insertOnConflictUpdate(entry.copyWith(id: const Value(0)));
  }

  static final UserSettingsTableData _defaultRow = UserSettingsTableData(
    id: 0,
    videoProviderId: null,
    videoProviderBaseUrl: null,
    videoProviderApiKeyRef: null,
    unitSystem: UnitSystem.metric,
    streakFreezeEnabled: false,
    aiPlanBuilderPremiumUnlocked: false,
    themeModePreference: AppThemeMode.dark,
  );
}
