import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../ai_plan_builder/presentation/generation_error_message.dart';
import '../data/ai_coach_repository.dart';
import '../domain/chat_message.dart';

final aiCoachRepositoryProvider = Provider<AiCoachRepository>((ref) {
  return AiCoachRepository(
    ref.watch(appDatabaseProvider),
    supabaseUrl: SupabaseConfig.isConfigured ? SupabaseConfig.url : null,
    supabaseAnonKey: SupabaseConfig.isConfigured
        ? SupabaseConfig.anonKey
        : null,
  );
});

/// Chat state for `AiCoachScreen`. `messages` lives only for the app
/// session — nothing here is persisted locally or server-side.
class AiCoachState {
  const AiCoachState({
    this.messages = const [],
    this.isSending = false,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final String? errorMessage;

  AiCoachState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? errorMessage,
  }) {
    return AiCoachState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }
}

/// Owns the in-memory chat conversation with the AI coach. Plain
/// `Notifier` (no code generation — same convention as
/// `GpsTrackingController`) since `build_runner` isn't part of this
/// project's day-to-day edit loop.
class AiCoachController extends Notifier<AiCoachState> {
  @override
  AiCoachState build() => const AiCoachState();

  Future<void> sendMessage(
    String text, {
    required String? goal,
    required String? experienceLevel,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final userMessage = ChatMessage(
      role: ChatRole.user,
      content: trimmed,
      sentAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isSending: true,
      errorMessage: null,
    );

    try {
      final repository = ref.read(aiCoachRepositoryProvider);
      final context = await repository.buildContext(
        goal: goal,
        experienceLevel: experienceLevel,
      );
      final reply = await repository.sendMessage(
        history: state.messages,
        context: context,
      );
      final assistantMessage = ChatMessage(
        role: ChatRole.assistant,
        content: reply,
        sentAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, assistantMessage],
        isSending: false,
      );
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        errorMessage: describeGenerationError(error),
      );
    }
  }
}

final aiCoachControllerProvider =
    NotifierProvider<AiCoachController, AiCoachState>(AiCoachController.new);
