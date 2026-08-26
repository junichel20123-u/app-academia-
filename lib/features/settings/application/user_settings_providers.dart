import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../data/user_settings_repository.dart';

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(ref.watch(appDatabaseProvider));
});

final userSettingsProvider = StreamProvider<UserSettingsTableData>((ref) {
  return ref.watch(userSettingsRepositoryProvider).watchSettings();
});
