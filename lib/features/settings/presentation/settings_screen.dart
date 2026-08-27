import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/enums.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInitial();
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
      _loaded = true;
    });
  }

  Future<void> _setThemeMode(AppThemeMode mode) async {
    setState(() => _themeMode = mode);
    await ref.read(userSettingsRepositoryProvider).setThemeMode(mode);
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
              ],
            ),
    );
  }
}
