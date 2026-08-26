import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/supabase_rest_client.dart';
import '../data/template_catalog_repository.dart';

final templateCatalogRepositoryProvider = Provider<TemplateCatalogRepository>((
  ref,
) {
  final restClient = SupabaseConfig.isConfigured
      ? SupabaseRestClient(
          baseUrl: SupabaseConfig.url,
          apiKey: SupabaseConfig.anonKey,
        )
      : null;
  return TemplateCatalogRepository(
    ref.watch(appDatabaseProvider),
    restClient: restClient,
  );
});

final catalogTemplatesProvider = StreamProvider<List<CatalogTemplate>>((ref) {
  return ref.watch(templateCatalogRepositoryProvider).watchAllTemplates();
});

/// The one cached template matching [slug], derived from
/// [catalogTemplatesProvider] — no separate DAO query needed.
final catalogTemplateBySlugProvider = Provider.autoDispose
    .family<CatalogTemplate?, String>((ref, slug) {
      final templates = ref.watch(catalogTemplatesProvider).value ?? const [];
      for (final template in templates) {
        if (template.slug == slug) return template;
      }
      return null;
    });
