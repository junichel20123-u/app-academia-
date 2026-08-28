import 'package:dio/dio.dart';

/// Turns a [DioException] into a sanitized, user-facing message: prefers
/// whatever the API's own JSON error payload says (`error`/`message` keys —
/// the shape both Runway and generic job-based APIs tend to use) over a
/// generic status-code message. Never includes the request URL, headers, or
/// any credential — only the response body's own text (if any) and the
/// HTTP status code/error type, so an API key can never leak through this
/// path even when the message is shown directly in the UI.
///
/// Shared by every [VideoGenerationProvider] that talks real HTTP
/// (`RunwayVideoGenerationProvider`, `HttpJobBasedProvider`) so this
/// sanitization logic exists in exactly one place.
String describeDioError(DioException error, {required String genericMessage}) {
  final data = error.response?.data;
  final message = data is Map ? (data['error'] ?? data['message']) : null;
  if (message is String && message.isNotEmpty) return message;
  return '$genericMessage (${error.response?.statusCode ?? error.type}).';
}
