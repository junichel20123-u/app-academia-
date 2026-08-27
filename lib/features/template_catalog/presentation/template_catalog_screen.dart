import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase/supabase_config.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/template_catalog_providers.dart';

class TemplateCatalogScreen extends ConsumerStatefulWidget {
  const TemplateCatalogScreen({super.key});

  @override
  ConsumerState<TemplateCatalogScreen> createState() =>
      _TemplateCatalogScreenState();
}

class _TemplateCatalogScreenState extends ConsumerState<TemplateCatalogScreen> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: the list already renders from the local cache; a
    // successful sync just refreshes it live via catalogTemplatesProvider.
    unawaited(_sync());
  }

  Future<void> _sync() async {
    try {
      await ref.read(templateCatalogRepositoryProvider).sync();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar o catálogo agora.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(catalogTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de treinos')),
      body: RefreshIndicator(
        onRefresh: _sync,
        child: templatesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _scrollableMessage('Erro: $err'),
          data: (templates) {
            if (templates.isEmpty) {
              return EmptyState(
                icon: Icons.auto_stories,
                title: SupabaseConfig.isConfigured
                    ? 'Nenhum modelo de treino disponível ainda.'
                    : 'Catálogo online não configurado nesta build.',
              );
            }
            return ListView.builder(
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final subtitleParts = <String>[
                  if (template.goal != null) template.goal!,
                  if (template.difficulty != null) template.difficulty!,
                ];
                return TweenAnimationBuilder<double>(
                  key: ValueKey(template.slug),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: ListTile(
                    title: Text(template.name),
                    subtitle: subtitleParts.isEmpty
                        ? null
                        : Text(subtitleParts.join(' · ')),
                    onTap: () => context.push('/templates/${template.slug}'),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// A message centered in a scrollable — `RefreshIndicator` needs a
  /// scrollable child to detect the pull gesture even in empty/error states.
  Widget _scrollableMessage(String message) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text(message)),
        ),
      ],
    );
  }
}
