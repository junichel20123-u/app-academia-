enum ChatRole { user, assistant }

/// One turn of the coach conversation. Kept in memory only for the current
/// app session (see `AiCoachController`) — never persisted locally or
/// server-side.
class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.sentAt,
  });

  final ChatRole role;
  final String content;
  final DateTime sentAt;
}

/// Parses the `ai-coach` Edge Function's response body (`{"reply": "..."}`).
/// Throws a [FormatException] if `reply` is missing or empty — a malformed
/// response should surface as an error, not silently render a blank bubble.
String parseChatReply(Map<String, dynamic> json) {
  final reply = json['reply'];
  if (reply is! String || reply.trim().isEmpty) {
    throw const FormatException('Resposta do coach de IA veio vazia.');
  }
  return reply;
}
