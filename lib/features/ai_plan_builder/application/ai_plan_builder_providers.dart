import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../settings/application/user_settings_providers.dart';
import '../data/ai_plan_builder_repository.dart';

final aiPlanBuilderRepositoryProvider = Provider<AiPlanBuilderRepository>((
  ref,
) {
  return AiPlanBuilderRepository(
    ref.watch(appDatabaseProvider),
    supabaseUrl: SupabaseConfig.isConfigured ? SupabaseConfig.url : null,
    supabaseAnonKey: SupabaseConfig.isConfigured
        ? SupabaseConfig.anonKey
        : null,
  );
});

/// Derived from the same settings stream the rest of the app already
/// watches — no separate DB query needed for a single boolean.
final aiPlanBuilderPremiumUnlockedProvider = Provider<bool>((ref) {
  return ref.watch(userSettingsProvider).value?.aiPlanBuilderPremiumUnlocked ??
      false;
});
