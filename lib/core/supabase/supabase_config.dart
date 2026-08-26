/// Supabase project connection details, baked in at build time via
/// `--dart-define=SUPABASE_URL=...` / `--dart-define=SUPABASE_ANON_KEY=...`.
/// Neither is a secret — the anon/publishable key is meant to be public,
/// protected by the project's RLS policies (see `supabase/migrations/`) —
/// but a build without them (the common case during local development)
/// simply runs with the template catalog offline/empty rather than failing.
class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
