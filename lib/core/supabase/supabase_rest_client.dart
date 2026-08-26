import 'package:dio/dio.dart';

/// Thin `dio`-based client for Supabase's PostgREST REST API. Deliberately
/// not `supabase_flutter` — this app only ever does one unauthenticated GET
/// (the template catalog), and pulling in auth/realtime/storage for that
/// would be a lot of surface for very little use. `supabase_flutter` is the
/// natural upgrade once the app has real user accounts.
class SupabaseRestClient {
  SupabaseRestClient({required this.baseUrl, required this.apiKey, Dio? dio})
    : _dio = dio ?? Dio();

  final String baseUrl;
  final String apiKey;
  final Dio _dio;

  /// Fetches every active template program with its workouts and their
  /// exercises embedded in one round trip (PostgREST resource embedding).
  Future<List<dynamic>> fetchTemplatePrograms() async {
    final response = await _dio.get<List<dynamic>>(
      '$baseUrl/rest/v1/template_programs',
      queryParameters: {
        'select': '*,template_program_workouts(*,template_program_workout_exercises(*))',
        'is_active': 'eq.true',
        'order': 'name.asc',
        'template_program_workouts.order': 'day_index.asc',
        'template_program_workout_exercises.order': 'order_index.asc',
      },
      options: Options(
        headers: {'apikey': apiKey, 'Authorization': 'Bearer $apiKey'},
      ),
    );
    return response.data ?? const [];
  }
}
