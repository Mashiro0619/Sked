import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/timetable_provider.dart';
import '../services/school_import_api.dart';
import '../services/school_import_http_consent.dart';
import '../widgets/school_import_http_consent_dialog.dart';
import '../widgets/settings_list.dart';

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
  late final FocusNode _apiKeyFocusNode;

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
  List<String> _availableModels = const [];

  static const _apiKeySaveDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _modelController = TextEditingController();
    _customPromptController = TextEditingController();
    _apiKeyFocusNode = FocusNode()
      ..addListener(() {
        if (!_apiKeyFocusNode.hasFocus) {
          unawaited(_flushPendingApiKeySave());
        }
      });
  }

  @override
  void dispose() {
    _isDisposing = true;
    unawaited(
      _flushPendingApiKeySave().catchError((error, stackTrace) {
        debugPrint('Final API key flush failed: $error\n$stackTrace');
        return false;
      }),
    );
    WidgetsBinding.instance.removeObserver(this);
    _apiKeySaveDebounce?.cancel();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _customPromptController.dispose();
    _apiKeyFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_flushPendingApiKeySave());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        _syncControllers(provider);
        final l10n = AppLocalizations.of(context);
        final baseUrl = provider.customSchoolImportBaseUrl.trim();
        final hasValidBaseUrl = isValidCustomOpenAiBaseUrl(baseUrl);
        return PopScope<void>(
          canPop: _allowPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              unawaited(_flushAndPop());
            }
          },
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.schoolImportParserSettingsTitle)),
            body: ListView(
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
                  decoration: InputDecoration(
                    labelText: l10n.schoolImportParserBaseUrl,
                    hintText: 'https://api.example.com/v1',
                    prefixIcon: const Icon(Icons.link),
                    errorText: baseUrl.isNotEmpty && !hasValidBaseUrl
                        ? l10n.schoolImportParserBaseUrlInvalid
                        : null,
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
                          !hasValidBaseUrl ||
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
                            _modelController.selection =
                                TextSelection.collapsed(offset: model.length);
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
                  subtitle: Text(
                    l10n.schoolImportParserCustomPromptDescription,
                  ),
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
    _allowPop = false;
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
    unawaited(
      operation.whenComplete(() {
        if (!identical(_apiKeyFlushOperation, operation)) {
          return;
        }
        _apiKeyFlushOperation = null;
        if (mounted && !_isDisposing) {
          setState(() {});
        }
      }),
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
      } catch (error) {
        if (!mounted || _isDisposing || token != _apiKeySaveToken) {
          return false;
        }
        if (_pendingApiKeyValue == null) {
          _pendingApiKeyProvider = provider;
          _pendingApiKeyValue = value;
          _showMessage(_settingsSaveErrorMessage(error));
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
    _isHandlingPop = true;
    final saved = await _flushPendingApiKeySave();
    if (!mounted) {
      return;
    }
    if (!saved) {
      setState(() => _isHandlingPop = false);
      return;
    }
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      Navigator.of(context).pop();
    }
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
    final baseUrl = provider.customSchoolImportBaseUrl;
    final apiKey = provider.customSchoolImportApiKey;
    setState(() => _isFetchingModels = true);
    try {
      final confirmed = await confirmSchoolImportHttpEndpoint(
        context: context,
        baseUrl: baseUrl,
        consentStore:
            widget.httpConsentStore ?? SchoolImportHttpConsentStore.session,
      );
      if (!confirmed || !mounted) {
        return;
      }
      final models = await widget.api.fetchCustomModels(
        baseUrl: baseUrl,
        apiKey: apiKey,
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
