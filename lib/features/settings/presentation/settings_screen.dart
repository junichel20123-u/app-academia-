import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/database/enums.dart';
import '../../video_generation/application/exercise_video_providers.dart';
import '../../video_generation/data/provider_registry.dart';
import '../application/user_settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  String _providerId = ProviderRegistry.mock.id;
  bool _hasStoredKey = false;
  bool _loaded = false;
  String? _testResultMessage;
  AppThemeMode _themeMode = AppThemeMode.dark;
  bool _aiPlanBuilderUnlocked = false;
  int? _cacheSizeBytes;
  bool _clearingCache = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _loadCacheSize();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final repository = ref.read(userSettingsRepositoryProvider);
    final settings = await repository.getSettings();
    final providerId = settings.videoProviderId ?? ProviderRegistry.mock.id;
    final apiKey = await repository.getApiKeyFor(providerId);
    if (!mounted) return;
    setState(() {
      _providerId = providerId;
      _baseUrlController.text = settings.videoProviderBaseUrl ?? '';
      _hasStoredKey = apiKey != null && apiKey.isNotEmpty;
      _themeMode = settings.themeModePreference;
      _aiPlanBuilderUnlocked = settings.aiPlanBuilderPremiumUnlocked;
      _loaded = true;
    });
  }

  Future<void> _setThemeMode(AppThemeMode mode) async {
    setState(() => _themeMode = mode);
    await ref.read(userSettingsRepositoryProvider).setThemeMode(mode);
  }

  Future<void> _setAiPlanBuilderUnlocked(bool unlocked) async {
    setState(() => _aiPlanBuilderUnlocked = unlocked);
    await ref
        .read(userSettingsRepositoryProvider)
        .setAiPlanBuilderPremiumUnlocked(unlocked);
  }

  Future<void> _loadCacheSize() async {
    final bytes = await ref
        .read(exerciseVideosRepositoryProvider)
        .cacheSizeBytes();
    if (!mounted) return;
    setState(() => _cacheSizeBytes = bytes);
  }

  Future<void> _clearVideoCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar cache de vídeos?'),
        content: const Text(
          'Os vídeos baixados serão apagados. Eles podem ser baixados de '
          'novo (vídeo de estoque) ou gerados de novo (IA) quando você '
          'abrir um exercício.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _clearingCache = true);
    await ref.read(exerciseVideosRepositoryProvider).clearVideoCache();
    if (!mounted) return;
    setState(() {
      _cacheSizeBytes = 0;
      _clearingCache = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Cache de vídeos limpo.')));
  }

  void _testConnection() {
    final descriptor = ProviderRegistry.descriptorFor(_providerId);
    final hasApiKey = _apiKeyController.text.isNotEmpty || _hasStoredKey;
    final hasBaseUrl = _baseUrlController.text.isNotEmpty;
    final valid =
        (!descriptor.requiresApiKey || hasApiKey) &&
        (!descriptor.requiresBaseUrl || hasBaseUrl);
    setState(() {
      _testResultMessage = valid
          ? 'Configuração válida.'
          : 'Preencha os campos obrigatórios para este provedor.';
    });
  }

  Future<void> _save() async {
    final repository = ref.read(userSettingsRepositoryProvider);
    await repository.saveVideoProviderConfig(
      providerId: _providerId,
      baseUrl: _baseUrlController.text.isEmpty ? null : _baseUrlController.text,
      apiKey: _apiKeyController.text.isEmpty ? null : _apiKeyController.text,
    );
    if (_apiKeyController.text.isNotEmpty) {
      setState(() {
        _hasStoredKey = true;
        _apiKeyController.clear();
      });
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Configurações salvas.')));
  }

  @override
  Widget build(BuildContext context) {
    final descriptor = ProviderRegistry.descriptorFor(_providerId);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Aparência',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SegmentedButton<AppThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: AppThemeMode.dark,
                      label: Text('Escuro'),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.light,
                      label: Text('Claro'),
                    ),
                    ButtonSegment(
                      value: AppThemeMode.system,
                      label: Text('Automático'),
                    ),
                  ],
                  selected: {_themeMode},
                  onSelectionChanged: (selection) =>
                      _setThemeMode(selection.first),
                ),
                const SizedBox(height: 12),
                _ThemePreviewSwatch(mode: _themeMode),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _providerId,
                  decoration: const InputDecoration(
                    labelText: 'Provedor de vídeo',
                  ),
                  items: [
                    for (final d in ProviderRegistry.all)
                      DropdownMenuItem(value: d.id, child: Text(d.displayName)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _providerId = value;
                      _hasStoredKey = false;
                      _apiKeyController.clear();
                      _testResultMessage = null;
                    });
                  },
                ),
                if (descriptor.requiresBaseUrl) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL base da API',
                    ),
                  ),
                ],
                if (descriptor.requiresApiKey) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Chave de API',
                      hintText: _hasStoredKey
                          ? 'Chave já configurada (deixe em branco para manter)'
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _testConnection,
                  child: const Text('Testar conexão'),
                ),
                if (_testResultMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_testResultMessage!),
                ],
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('Salvar')),
                const SizedBox(height: 24),
                Text(
                  'Modo de teste',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Recursos de IA (Montador de plano + Coach)',
                  ),
                  subtitle: const Text(
                    'Libera os dois recursos premium de IA sem pagamento — '
                    'não há cobrança real implementada ainda, isto é só '
                    'para teste.',
                  ),
                  value: _aiPlanBuilderUnlocked,
                  onChanged: _setAiPlanBuilderUnlocked,
                ),
                const SizedBox(height: 24),
                Text(
                  'Cache de vídeos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  _cacheSizeBytes == null
                      ? 'Calculando...'
                      : 'Tamanho atual: '
                            '${(_cacheSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _clearingCache ? null : _clearVideoCache,
                  child: _clearingCache
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Limpar cache de vídeos'),
                ),
              ],
            ),
    );
  }
}

/// Small live preview of the selected appearance option — a swatch card
/// showing background/surface plus the primary/secondary accents that
/// option would use, without needing to actually switch `themeModeProvider`
/// (which would restyle the whole Settings screen underneath it).
class _ThemePreviewSwatch extends StatelessWidget {
  const _ThemePreviewSwatch({required this.mode});

  final AppThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final isDark = switch (mode) {
      AppThemeMode.dark => true,
      AppThemeMode.light => false,
      AppThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    final background = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final onSurfaceVariant = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;
    final primary = isDark ? AppColors.volt : AppColors.voltOnLight;
    final secondary = isDark ? AppColors.ember : AppColors.emberOnLight;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onSurfaceVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(primary),
                  const SizedBox(width: 4),
                  _dot(secondary),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Prévia da aparência',
            style: TextStyle(color: onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
