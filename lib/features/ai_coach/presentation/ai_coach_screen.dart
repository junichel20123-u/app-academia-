import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ai_plan_builder/application/ai_plan_builder_providers.dart';
import '../application/ai_coach_providers.dart';
import '../domain/chat_message.dart';

// Same three levels/labels as AiPlanBuilderScreen, redeclared locally —
// that screen doesn't share them either (each screen in this app is
// self-contained rather than pulling a tiny shared constant from
// elsewhere).
const _experienceLevels = ['beginner', 'intermediate', 'advanced'];

String _experienceLevelLabel(String level) => switch (level) {
  'beginner' => 'Iniciante',
  'intermediate' => 'Intermediário',
  'advanced' => 'Avançado',
  _ => level,
};

class AiCoachScreen extends ConsumerStatefulWidget {
  const AiCoachScreen({super.key});

  @override
  ConsumerState<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends ConsumerState<AiCoachScreen> {
  final _goalController = TextEditingController();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String _experienceLevel = _experienceLevels.first;

  @override
  void dispose() {
    _goalController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    ref
        .read(aiCoachControllerProvider.notifier)
        .sendMessage(
          text,
          goal: _goalController.text.trim().isEmpty
              ? null
              : _goalController.text.trim(),
          experienceLevel: _experienceLevel,
        );
    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final premiumUnlocked = ref.watch(aiPlanBuilderPremiumUnlockedProvider);
    final chatState = ref.watch(aiCoachControllerProvider);

    ref.listen(aiCoachControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach de IA'),
        actions: [
          if (premiumUnlocked)
            IconButton(
              icon: const Icon(Icons.fitness_center),
              tooltip: 'Ajustar um treino',
              onPressed: () => context.push('/coach/adjust'),
            ),
        ],
      ),
      body: !premiumUnlocked ? _lockedState(context) : _chatBody(chatState),
    );
  }

  Widget _chatBody(AiCoachState chatState) {
    return Column(
      children: [
        ExpansionTile(
          title: const Text('Seu contexto'),
          subtitle: const Text('Objetivo e nível usados para personalizar'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            TextField(
              controller: _goalController,
              decoration: const InputDecoration(
                labelText: 'Objetivo (ex: hipertrofia, emagrecimento)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _experienceLevel,
              decoration: const InputDecoration(
                labelText: 'Nível de experiência',
              ),
              items: [
                for (final level in _experienceLevels)
                  DropdownMenuItem(
                    value: level,
                    child: Text(_experienceLevelLabel(level)),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _experienceLevel = value);
              },
            ),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: chatState.messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Pergunte sobre treino, nutrição ou hábitos '
                      'saudáveis — o coach considera seu objetivo e seu '
                      'histórico no app.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      chatState.messages.length + (chatState.isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= chatState.messages.length) {
                      return const _TypingBubble();
                    }
                    return _MessageBubble(message: chatState.messages[index]);
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Digite sua pergunta...',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: chatState.isSending ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lockedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'O coach de IA é um recurso premium.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pagamentos em breve.')),
                );
              },
              child: const Text('Desbloquear'),
            ),
            const SizedBox(height: 8),
            Text(
              'Testando o app? Ative em Configurações → Modo de teste.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? colorScheme.onPrimary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(
          width: 20,
          height: 12,
          child: Center(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    );
  }
}
