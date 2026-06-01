import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../services/school_import_api.dart';
import '../widgets/settings_list.dart';

class SchoolImportParserSettingsPage extends StatefulWidget {
  const SchoolImportParserSettingsPage({
    super.key,
    this.api = const SchoolImportApi(),
  });

  final SchoolImportApi api;

  @override
  State<SchoolImportParserSettingsPage> createState() =>
      _SchoolImportParserSettingsPageState();
}

class _SchoolImportParserSettingsPageState
    extends State<SchoolImportParserSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _customPromptController;
  late final FocusNode _apiKeyFocusNode;

  bool _showApiKey = false;
  bool _isFetchingModels = false;
  bool _isSavingApiKey = false;
  Timer? _apiKeySaveDebounce;
  TimetableProvider? _pendingApiKeyProvider;
  String? _pendingApiKeyValue;
  int _apiKeySaveToken = 0;
  List<String> _availableModels = const [];

  static const _apiKeySaveDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _customPromptController = TextEditingController();
    _apiKeyFocusNode = FocusNode()
      ..addListener(() {
        if (!_apiKeyFocusNode.hasFocus) {
          _flushPendingApiKeySave();
        }
      });
  }

  @override
  void dispose() {
    final pendingProvider = _pendingApiKeyProvider;
    final pendingValue = _pendingApiKeyValue;
    _apiKeySaveDebounce?.cancel();
    if (pendingProvider != null && pendingValue != null) {
      unawaited(
        pendingProvider
            .updateCustomSchoolImportApiKey(pendingValue)
            .catchError((_) {}),
      );
    }
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _customPromptController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        _syncControllers(provider);
        final l10n = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(l10n.schoolImportParserSettingsTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SettingsSectionHeader(title: l10n.schoolImportParserCustomOpenAi),
              Text(
                l10n.schoolImportParserSettingsDesc,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlController,
                decoration: InputDecoration(
                  labelText: l10n.schoolImportParserBaseUrl,
                  hintText: 'https://api.example.com/v1',
                  prefixIcon: const Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
                onChanged: provider.updateCustomSchoolImportBaseUrl,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                focusNode: _apiKeyFocusNode,
                obscureText: !_showApiKey,
                decoration: InputDecoration(
                  labelText: l10n.schoolImportParserApiKey,
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isSavingApiKey)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      IconButton(
                        onPressed: () {
                          setState(() => _showApiKey = !_showApiKey);
                        },
                        icon: Icon(
                          _showApiKey
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ],
                  ),
                ),
                onChanged: (value) => _scheduleApiKeyUpdate(provider, value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: l10n.schoolImportParserModel,
                  prefixIcon: const Icon(Icons.model_training_outlined),
                ),
                onChanged: provider.updateCustomSchoolImportModel,
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed:
                    _isFetchingModels ||
                        _pendingApiKeyValue != null ||
                        _isSavingApiKey ||
                        provider.customSchoolImportBaseUrl.isEmpty ||
                        provider.customSchoolImportApiKey.isEmpty
                    ? null
                    : () => _fetchModels(provider),
                icon: _isFetchingModels
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
                label: Text(
                  _isFetchingModels
                      ? l10n.schoolImportParserFetchingModels
                      : l10n.schoolImportParserFetchModels,
                ),
              ),
              if (_availableModels.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final model in _availableModels)
                      ChoiceChip(
                        label: Text(model),
                        selected: provider.customSchoolImportModel == model,
                        onSelected: (_) async {
                          _modelController.text = model;
                          _modelController.selection = TextSelection.collapsed(
                            offset: model.length,
                          );
                          await provider.updateCustomSchoolImportModel(model);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 8),
                initiallyExpanded: false,
                title: Text(l10n.schoolImportParserCustomPromptTitle),
                subtitle: Text(l10n.schoolImportParserCustomPromptDescription),
                children: [
                  TextField(
                    controller: _customPromptController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.schoolImportParserCustomPromptTitle,
                      hintText: l10n.schoolImportParserCustomPromptHint,
                      alignLabelWithHint: true,
                    ),
                    onChanged: provider.updateCustomSchoolImportPrompt,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        _syncController(
                          _customPromptController,
                          SchoolImportApi.defaultCustomOpenAiSystemPrompt,
                        );
                        await provider.updateCustomSchoolImportPrompt('');
                      },
                      icon: const Icon(Icons.restart_alt_outlined),
                      label: Text(l10n.schoolImportParserResetDefaultPrompt),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                l10n.schoolImportParserPlaintextWarning,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _syncControllers(TimetableProvider provider) {
    _syncController(_baseUrlController, provider.customSchoolImportBaseUrl);
    if (!_apiKeyFocusNode.hasFocus &&
        _pendingApiKeyValue == null &&
        !_isSavingApiKey) {
      _syncController(_apiKeyController, provider.customSchoolImportApiKey);
    }
    _syncController(_modelController, provider.customSchoolImportModel);
    _syncController(
      _customPromptController,
      provider.customSchoolImportPrompt.isEmpty
          ? SchoolImportApi.defaultCustomOpenAiSystemPrompt
          : provider.customSchoolImportPrompt,
    );
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _scheduleApiKeyUpdate(TimetableProvider provider, String value) {
    _pendingApiKeyProvider = provider;
    _pendingApiKeyValue = value;
    _apiKeySaveDebounce?.cancel();
    _apiKeySaveDebounce = Timer(_apiKeySaveDelay, _flushPendingApiKeySave);
    if (mounted) {
      setState(() {});
    }
  }

  void _flushPendingApiKeySave() {
    final provider = _pendingApiKeyProvider;
    final value = _pendingApiKeyValue;
    if (provider == null || value == null) {
      return;
    }
    if (_isSavingApiKey) {
      return;
    }
    _pendingApiKeyValue = null;
    _apiKeySaveDebounce?.cancel();
    _apiKeySaveDebounce = null;
    final token = ++_apiKeySaveToken;
    if (mounted) {
      setState(() => _isSavingApiKey = true);
    }
    unawaited(
      provider
          .updateCustomSchoolImportApiKey(value)
          .catchError((Object error) {
            if (!mounted || token != _apiKeySaveToken) {
              return;
            }
            if (_pendingApiKeyValue == null) {
              _syncController(
                _apiKeyController,
                provider.customSchoolImportApiKey,
              );
            }
            _showMessage(_settingsSaveErrorMessage(error));
          })
          .whenComplete(() {
            if (mounted && token == _apiKeySaveToken) {
              setState(() => _isSavingApiKey = false);
              if (_pendingApiKeyValue != null) {
                _flushPendingApiKeySave();
              }
            }
          }),
    );
  }

  String _settingsSaveErrorMessage(Object error) {
    if (error is StateError && error.message.isNotEmpty) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _fetchModels(TimetableProvider provider) async {
    if (_isFetchingModels) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _isFetchingModels = true);
    try {
      final models = await widget.api.fetchCustomModels(
        baseUrl: provider.customSchoolImportBaseUrl,
        apiKey: provider.customSchoolImportApiKey,
      );
      if (!mounted) {
        return;
      }
      setState(() => _availableModels = models);
      _showMessage(
        models.isEmpty
            ? l10n.schoolImportParserNoModelsFound
            : l10n.schoolImportParserModelsFetched(models.length),
      );
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isFetchingModels = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
