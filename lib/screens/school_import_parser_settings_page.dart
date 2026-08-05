import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../services/school_import_api.dart';
import '../services/school_import_http_consent.dart';
import '../widgets/school_import_http_consent_dialog.dart';
import '../widgets/settings_list.dart';
import '../widgets/ui_command.dart';

class SchoolImportParserSettingsPage extends StatefulWidget {
  const SchoolImportParserSettingsPage({
    super.key,
    this.api = const SchoolImportApi(),
    this.httpConsentStore,
  });

  final SchoolImportApi api;
  final SchoolImportHttpConsentStore? httpConsentStore;

  @override
  State<SchoolImportParserSettingsPage> createState() =>
      _SchoolImportParserSettingsPageState();
}

class _SchoolImportParserSettingsPageState
    extends State<SchoolImportParserSettingsPage>
    with WidgetsBindingObserver {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late final TextEditingController _customPromptController;
  late final FocusNode _baseUrlFocusNode;
  late final FocusNode _apiKeyFocusNode;
  late final FocusNode _modelFocusNode;
  late final FocusNode _customPromptFocusNode;

  bool _showApiKey = false;
  bool _isFetchingModels = false;
  bool _isSavingApiKey = false;
  bool _isDisposing = false;
  bool _allowPop = false;
  bool _isHandlingPop = false;
  Timer? _apiKeySaveDebounce;
  Future<bool>? _apiKeyFlushOperation;
  TimetableProvider? _pendingApiKeyProvider;
  String? _pendingApiKeyValue;
  int _apiKeySaveToken = 0;
  bool _isSavingTextSettings = false;
  Timer? _textSettingsSaveDebounce;
  Future<bool>? _textSettingsFlushOperation;
  TimetableProvider? _pendingTextSettingsProvider;
  _ParserTextSettingsDraft? _pendingTextSettingsValue;
  int _textSettingsSaveToken = 0;
  String _promptStorageValue = '';
  List<String> _availableModels = const [];
  _ModelFetchSettings? _availableModelsSettings;

  static const _apiKeySaveDelay = Duration(milliseconds: 500);
  static const _textSettingsSaveDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _customPromptController = TextEditingController();
    _baseUrlFocusNode = _createTextSettingsFocusNode();
    _apiKeyFocusNode = FocusNode()
      ..addListener(() {
        if (!_apiKeyFocusNode.hasFocus) {
          unawaited(_flushPendingApiKeySave());
        }
      });
    _modelFocusNode = _createTextSettingsFocusNode();
    _customPromptFocusNode = _createTextSettingsFocusNode();
  }

  @override
  void dispose() {
    _isDisposing = true;
    unawaited(
      _flushAllPendingSettings().catchError((error, stackTrace) {
        debugPrint('Final parser settings flush failed: $error\n$stackTrace');
        return false;
      }),
    );
    WidgetsBinding.instance.removeObserver(this);
    _apiKeySaveDebounce?.cancel();
    _textSettingsSaveDebounce?.cancel();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _customPromptController.dispose();
    _baseUrlFocusNode.dispose();
    _apiKeyFocusNode.dispose();
    _modelFocusNode.dispose();
    _customPromptFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushAllPendingSettings());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        _syncControllers(provider);
        final l10n = AppLocalizations.of(context);
        final baseUrl = _baseUrlController.text.trim();
        final apiKey = _apiKeyController.text.trim();
        final hasValidBaseUrl = isValidCustomOpenAiBaseUrl(baseUrl);
        final currentModelFetchSettings = _ModelFetchSettings(
          baseUrl: baseUrl,
          apiKey: apiKey,
        );
        final availableModels =
            _availableModelsSettings == currentModelFetchSettings
            ? _availableModels
            : const <String>[];
        return PopScope<void>(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              unawaited(_flushAndPop());
            }
          },
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.schoolImportParserSettingsTitle)),
            body: Column(
              children: [
                UiCommandBusyIndicator(
                  busy: _isSavingApiKey || _isSavingTextSettings,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      SettingsSectionHeader(
                        title: l10n.schoolImportParserCustomOpenAi,
                      ),
                      Text(
                        l10n.schoolImportParserSettingsDesc,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _baseUrlController,
                        focusNode: _baseUrlFocusNode,
                        decoration: InputDecoration(
                          labelText: l10n.schoolImportParserBaseUrl,
                          hintText: 'https://api.example.com/v1',
                          prefixIcon: const Icon(Icons.link),
                          errorText: baseUrl.isNotEmpty && !hasValidBaseUrl
                              ? l10n.schoolImportParserBaseUrlInvalid
                              : null,
                        ),
                        keyboardType: TextInputType.url,
                        onChanged: (_) => _scheduleTextSettingsUpdate(provider),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKeyController,
                        focusNode: _apiKeyFocusNode,
                        obscureText: !_showApiKey,
                        decoration: InputDecoration(
                          labelText: l10n.schoolImportParserApiKey,
                          prefixIcon: const Icon(Icons.key_outlined),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _showApiKey = !_showApiKey);
                            },
                            tooltip: _showApiKey
                                ? l10n.hideApiKey
                                : l10n.showApiKey,
                            icon: Icon(
                              _showApiKey
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            _scheduleApiKeyUpdate(provider, value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _modelController,
                        focusNode: _modelFocusNode,
                        decoration: InputDecoration(
                          labelText: l10n.schoolImportParserModel,
                          prefixIcon: const Icon(Icons.model_training_outlined),
                        ),
                        onChanged: (_) => _scheduleTextSettingsUpdate(provider),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed:
                            _isFetchingModels ||
                                _isSavingApiKey ||
                                _isSavingTextSettings ||
                                !hasValidBaseUrl ||
                                apiKey.isEmpty
                            ? null
                            : _fetchModels,
                        icon: _isFetchingModels
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_outlined),
                        label: Text(
                          _isFetchingModels
                              ? l10n.schoolImportParserFetchingModels
                              : l10n.schoolImportParserFetchModels,
                        ),
                      ),
                      if (availableModels.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final model in availableModels)
                              ChoiceChip(
                                label: Text(model),
                                selected: _modelController.text.trim() == model,
                                onSelected: (_) {
                                  _modelController.text = model;
                                  _modelController.selection =
                                      TextSelection.collapsed(
                                        offset: model.length,
                                      );
                                  _scheduleTextSettingsUpdate(provider);
                                  unawaited(_flushPendingTextSettingsSave());
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
                        subtitle: Text(
                          l10n.schoolImportParserCustomPromptDescription,
                        ),
                        children: [
                          TextField(
                            controller: _customPromptController,
                            focusNode: _customPromptFocusNode,
                            minLines: 4,
                            maxLines: 8,
                            decoration: InputDecoration(
                              labelText:
                                  l10n.schoolImportParserCustomPromptTitle,
                              hintText: l10n.schoolImportParserCustomPromptHint,
                              alignLabelWithHint: true,
                            ),
                            onChanged: (value) {
                              _promptStorageValue = value;
                              _scheduleTextSettingsUpdate(provider);
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                _promptStorageValue = '';
                                _syncController(
                                  _customPromptController,
                                  SchoolImportApi
                                      .defaultCustomOpenAiSystemPrompt,
                                );
                                _scheduleTextSettingsUpdate(
                                  provider,
                                  promptOverride: '',
                                );
                                unawaited(_flushPendingTextSettingsSave());
                              },
                              icon: const Icon(Icons.restart_alt_outlined),
                              label: Text(
                                l10n.schoolImportParserResetDefaultPrompt,
                              ),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _syncControllers(TimetableProvider provider) {
    if (_pendingTextSettingsValue == null && !_isSavingTextSettings) {
      _syncController(_baseUrlController, provider.customSchoolImportBaseUrl);
      _syncController(_modelController, provider.customSchoolImportModel);
      _promptStorageValue = provider.customSchoolImportPrompt;
      _syncController(
        _customPromptController,
        provider.customSchoolImportPrompt.isEmpty
            ? SchoolImportApi.defaultCustomOpenAiSystemPrompt
            : provider.customSchoolImportPrompt,
      );
    }
    if (!_apiKeyFocusNode.hasFocus &&
        _pendingApiKeyValue == null &&
        !_isSavingApiKey) {
      _syncController(_apiKeyController, provider.customSchoolImportApiKey);
    }
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

  FocusNode _createTextSettingsFocusNode() {
    final focusNode = FocusNode();
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        unawaited(_flushPendingTextSettingsSave());
      }
    });
    return focusNode;
  }

  void _scheduleTextSettingsUpdate(
    TimetableProvider provider, {
    String? promptOverride,
  }) {
    _allowPop = false;
    if (_availableModelsSettings?.baseUrl != _baseUrlController.text.trim()) {
      _availableModels = const [];
      _availableModelsSettings = null;
    }
    _pendingTextSettingsProvider = provider;
    _pendingTextSettingsValue = _ParserTextSettingsDraft(
      baseUrl: _baseUrlController.text,
      model: _modelController.text,
      prompt: promptOverride ?? _promptStorageValue,
    );
    _textSettingsSaveDebounce?.cancel();
    _textSettingsSaveDebounce = Timer(
      _textSettingsSaveDelay,
      () => unawaited(_flushPendingTextSettingsSave()),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _flushPendingTextSettingsSave() {
    _textSettingsSaveDebounce?.cancel();
    _textSettingsSaveDebounce = null;
    final existing = _textSettingsFlushOperation;
    if (existing != null) {
      return existing;
    }
    final operation = _drainPendingTextSettingsSaves();
    _textSettingsFlushOperation = operation;
    void finishOperation() {
      if (!identical(_textSettingsFlushOperation, operation)) {
        return;
      }
      _textSettingsFlushOperation = null;
      if (mounted && !_isDisposing) {
        setState(() {});
      }
    }

    unawaited(
      operation.then<void>(
        (_) => finishOperation(),
        onError: (Object error, StackTrace stackTrace) {
          finishOperation();
          debugPrint(
            'Parser text settings flush ended unexpectedly: '
            '$error\n$stackTrace',
          );
        },
      ),
    );
    return operation;
  }

  Future<bool> _drainPendingTextSettingsSaves() async {
    while (true) {
      final provider = _pendingTextSettingsProvider;
      final value = _pendingTextSettingsValue;
      if (provider == null || value == null) {
        return true;
      }
      _pendingTextSettingsProvider = null;
      _pendingTextSettingsValue = null;
      final token = ++_textSettingsSaveToken;
      if (mounted && !_isDisposing) {
        setState(() => _isSavingTextSettings = true);
      }
      try {
        await provider.updateCustomSchoolImportTextSettings(
          baseUrl: value.baseUrl,
          model: value.model,
          prompt: value.prompt,
        );
      } catch (error, stackTrace) {
        debugPrint('Parser text settings save failed: $error\n$stackTrace');
        if (!mounted || _isDisposing || token != _textSettingsSaveToken) {
          return false;
        }
        if (_pendingTextSettingsValue == null) {
          _pendingTextSettingsProvider = provider;
          _pendingTextSettingsValue = value;
          _showMessage(AppLocalizations.of(context).saveFailedRetry);
          return false;
        }
      } finally {
        if (mounted && !_isDisposing && token == _textSettingsSaveToken) {
          setState(() => _isSavingTextSettings = false);
        }
      }
    }
  }

  Future<bool> _flushAllPendingSettings() async {
    try {
      final results = await Future.wait<bool>([
        _flushPendingApiKeySave(),
        _flushPendingTextSettingsSave(),
      ]);
      return results.every((saved) => saved);
    } catch (error, stackTrace) {
      debugPrint('Parser settings flush failed: $error\n$stackTrace');
      if (mounted && !_isDisposing) {
        _showMessage(AppLocalizations.of(context).saveFailedRetry);
      }
      return false;
    }
  }

  void _scheduleApiKeyUpdate(TimetableProvider provider, String value) {
    _allowPop = false;
    _availableModels = const [];
    _availableModelsSettings = null;
    _pendingApiKeyProvider = provider;
    _pendingApiKeyValue = value;
    _apiKeySaveDebounce?.cancel();
    _apiKeySaveDebounce = Timer(
      _apiKeySaveDelay,
      () => unawaited(_flushPendingApiKeySave()),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _flushPendingApiKeySave() {
    _apiKeySaveDebounce?.cancel();
    _apiKeySaveDebounce = null;
    final existing = _apiKeyFlushOperation;
    if (existing != null) {
      final hasNewerPendingValue =
          _pendingApiKeyProvider != null && _pendingApiKeyValue != null;
      if (!hasNewerPendingValue) return existing;
      return existing.then((_) {
        if (_pendingApiKeyProvider == null || _pendingApiKeyValue == null) {
          return true;
        }
        return _flushPendingApiKeySave();
      });
    }
    final operation = _drainPendingApiKeySaves();
    _apiKeyFlushOperation = operation;
    void finishOperation() {
      if (!identical(_apiKeyFlushOperation, operation)) {
        return;
      }
      _apiKeyFlushOperation = null;
      if (mounted && !_isDisposing) {
        setState(() {});
      }
    }

    unawaited(
      operation.then<void>(
        (_) => finishOperation(),
        onError: (Object error, StackTrace stackTrace) {
          finishOperation();
          debugPrint(
            'Parser API key flush ended unexpectedly: '
            '$error\n$stackTrace',
          );
        },
      ),
    );
    return operation;
  }

  Future<bool> _drainPendingApiKeySaves() async {
    while (true) {
      final provider = _pendingApiKeyProvider;
      final value = _pendingApiKeyValue;
      if (provider == null || value == null) {
        return true;
      }
      _pendingApiKeyProvider = null;
      _pendingApiKeyValue = null;
      final token = ++_apiKeySaveToken;
      if (mounted && !_isDisposing) {
        setState(() => _isSavingApiKey = true);
      }
      try {
        await provider.updateCustomSchoolImportApiKey(value);
      } catch (error, stackTrace) {
        debugPrint('Parser API key save failed: $error\n$stackTrace');
        if (!mounted || _isDisposing || token != _apiKeySaveToken) {
          return false;
        }
        if (_pendingApiKeyValue == null) {
          _pendingApiKeyProvider = provider;
          _pendingApiKeyValue = value;
          _showMessage(AppLocalizations.of(context).saveFailedRetry);
        }
        return false;
      } finally {
        if (mounted && !_isDisposing && token == _apiKeySaveToken) {
          setState(() => _isSavingApiKey = false);
        }
      }
    }
  }

  Future<void> _flushAndPop() async {
    if (_isHandlingPop) {
      return;
    }
    final route = ModalRoute.of(context);
    _isHandlingPop = true;
    final saved = await _flushAllPendingSettings();
    if (!mounted) {
      return;
    }
    if (!saved) {
      setState(() => _isHandlingPop = false);
      return;
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && _allowPop && route?.isCurrent == true) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() => _isHandlingPop = false);
    }
  }

  Future<void> _fetchModels() async {
    if (_isFetchingModels) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    _ModelFetchSettings? requestSettings;
    setState(() => _isFetchingModels = true);
    try {
      final saved = await _flushAllPendingSettings();
      if (!saved || !mounted) {
        return;
      }
      final settings = _currentModelFetchSettings();
      if (!isValidCustomOpenAiBaseUrl(settings.baseUrl) ||
          settings.apiKey.isEmpty) {
        return;
      }
      requestSettings = settings;
      final confirmed = await confirmSchoolImportHttpEndpoint(
        context: context,
        baseUrl: settings.baseUrl,
        consentStore:
            widget.httpConsentStore ?? SchoolImportHttpConsentStore.session,
      );
      if (!confirmed || !mounted || settings != _currentModelFetchSettings()) {
        return;
      }
      final models = await widget.api.fetchCustomModels(
        baseUrl: settings.baseUrl,
        apiKey: settings.apiKey,
      );
      if (!mounted || settings != _currentModelFetchSettings()) {
        return;
      }
      setState(() {
        _availableModels = models;
        _availableModelsSettings = settings;
      });
      _showMessage(
        models.isEmpty
            ? l10n.schoolImportParserNoModelsFound
            : l10n.schoolImportParserModelsFetched(models.length),
      );
    } on FormatException catch (error) {
      if (!mounted ||
          (requestSettings != null &&
              requestSettings != _currentModelFetchSettings())) {
        return;
      }
      _showMessage(error.message);
    } catch (error, stackTrace) {
      if (!mounted ||
          (requestSettings != null &&
              requestSettings != _currentModelFetchSettings())) {
        return;
      }
      debugPrint('Fetching custom parser models failed: $error\n$stackTrace');
      _showMessage(l10n.schoolImportParserFetchModelsFailed);
    } finally {
      if (mounted) {
        setState(() => _isFetchingModels = false);
      }
    }
  }

  _ModelFetchSettings _currentModelFetchSettings() {
    return _ModelFetchSettings(
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
    );
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

class _ParserTextSettingsDraft {
  const _ParserTextSettingsDraft({
    required this.baseUrl,
    required this.model,
    required this.prompt,
  });

  final String baseUrl;
  final String model;
  final String prompt;
}

class _ModelFetchSettings {
  const _ModelFetchSettings({required this.baseUrl, required this.apiKey});

  final String baseUrl;
  final String apiKey;

  @override
  bool operator ==(Object other) {
    return other is _ModelFetchSettings &&
        other.baseUrl == baseUrl &&
        other.apiKey == apiKey;
  }

  @override
  int get hashCode => Object.hash(baseUrl, apiKey);
}
