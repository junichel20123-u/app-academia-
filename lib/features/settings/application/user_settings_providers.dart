import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../data/user_settings_repository.dart';

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return UserSettingsRepository(ref.watch(appDatabaseProvider));
});

final userSettingsProvider = StreamProvider<UserSettingsTableData>((ref) {
  return ref.watch(userSettingsRepositoryProvider).watchSettings();
});

/// Defaults to [ThemeMode.dark] while settings are loading/erroring, so the
/// app never flashes a light theme before the first frame that has real
/// settings data — dark is the app's decided default anyway.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final preference = ref.watch(userSettingsProvider).value?.themeModePreference;
  return switch (preference) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.dark || null => ThemeMode.dark,
  };
});
