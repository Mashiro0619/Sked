import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';
import '../../theme/sked_surface.dart';
import '../connection/agent_credential_action.dart';
import '../connection/agent_connection_diagnostics.dart';
import '../provider/provider.dart' show ProviderCancellationToken;
import 'agent_model_labels.dart';

export '../connection/agent_credential_action.dart';

/// A transient host command, deliberately without JSON serialization. The
/// host writes the secret to its credential store and returns only a reference.
class AgentModelSettingsChange {
  const AgentModelSettingsChange({
    required this.settings,
    required this.credentialAction,
    this.apiKey,
  });
  final AgentSettings settings;
  final AgentCredentialAction credentialAction;
  final String? apiKey;
}

class AgentModelSettingsForm extends StatefulWidget {
  const AgentModelSettingsForm({
    super.key,
    required this.settings,
    required this.onSave,
    this.onSaved,
    this.showTitle = true,
    this.onProbe,
    this.onListModels,
  });
  final AgentSettings settings;
  final Future<void> Function(AgentModelSettingsChange change) onSave;
  final VoidCallback? onSaved;
  final bool showTitle;
  final Future<AgentConnectionProbeResult> Function(
    ProviderCancellationToken cancellation,
  )?
  onProbe;
  final Future<AgentModelCatalog> Function(
    ProviderCancellationToken cancellation,
  )?
  onListModels;

  @override
  State<AgentModelSettingsForm> createState() => _AgentModelSettingsFormState();
}

class _AgentModelSettingsFormState extends State<AgentModelSettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _endpoint = TextEditingController(text: widget.settings.endpoint);
  final _model = TextEditingController();
  final _modelSearch = TextEditingController();
  late String _defaultModel = widget.settings.model;
  late final _models = <String, AgentModelConfig>{
    for (final model in widget.settings.availableModels) model.id: model,
  };
  final _removedModels = <String, AgentModelConfig>{};
  final _key = TextEditingController();
  late AgentModelProtocol _protocol = widget.settings.protocol;
  bool _showKey = false;
  bool _clearKey = false;
  bool _saving = false;
  bool _failed = false;
  bool _diagnosing = false;
  bool _diagnosticFailed = false;
  AgentConnectionProbeResult? _probe;
  AgentModelCatalog? _catalog;
  ProviderCancellationToken? _diagnosticCancellation;

  Future<void> _diagnose({required bool listModels}) async {
    if (_diagnosing || _saving) return;
    final snapshot = widget.settings;
    final cancellation = ProviderCancellationToken();
    _diagnosticCancellation = cancellation;
    setState(() {
      _diagnosing = true;
      _diagnosticFailed = false;
    });
    try {
      if (listModels) {
        final result = await widget.onListModels!(cancellation);
        if (mounted && widget.settings == snapshot) {
          setState(() => _catalog = result);
        }
      } else {
        final result = await widget.onProbe!(cancellation);
        if (mounted && widget.settings == snapshot) {
          setState(() => _probe = result);
        }
      }
    } catch (_) {
      if (mounted && widget.settings == snapshot && !cancellation.isCancelled) {
        setState(() => _diagnosticFailed = true);
      }
    } finally {
      if (identical(_diagnosticCancellation, cancellation)) {
        _diagnosticCancellation = null;
      }
      if (mounted) setState(() => _diagnosing = false);
    }
  }

  @override
  void didUpdateWidget(AgentModelSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _diagnosticCancellation?.cancel();
      _probe = null;
      _catalog = null;
      _diagnosticFailed = false;
    }
  }

  @override
  void dispose() {
    _diagnosticCancellation?.cancel();
    _key.clear();
    _key.dispose();
    _endpoint.dispose();
    _model.dispose();
    _modelSearch.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _diagnosing || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final manualModel = _model.text.trim();
      if (manualModel.isNotEmpty) _setModelEnabled(manualModel, true);
      final change = AgentModelSettingsChange(
        settings: widget.settings.copyWith(
          endpoint: _endpoint.text.trim(),
          model: _defaultModel,
          models: _models.values.toList(),
          protocol: _protocol,
        ),
        credentialAction: _clearKey
            ? AgentCredentialAction.clear
            : _key.text.isNotEmpty
            ? AgentCredentialAction.replace
            : AgentCredentialAction.keep,
        apiKey: _clearKey || _key.text.isEmpty ? null : _key.text,
      );
      await widget.onSave(change);
      if (!mounted) return;
      _key.clear();
      _model.clear();
      setState(() => _clearKey = false);
      widget.onSaved?.call();
    } catch (_) {
      // Never echo provider exceptions or a secret-bearing command.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _setModelEnabled(String id, bool enabled) {
    if (enabled) {
      _models.putIfAbsent(
        id,
        () => _removedModels.remove(id) ?? AgentModelConfig(id: id),
      );
      if (_defaultModel.isEmpty) _defaultModel = id;
    } else {
      final removed = _models.remove(id);
      if (removed != null) _removedModels[id] = removed;
      if (_defaultModel == id) _defaultModel = _models.keys.firstOrNull ?? '';
    }
  }

  void _addManualModel() {
    if (!_formKey.currentState!.validate()) return;
    final id = _model.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _setModelEnabled(id, true);
      _model.clear();
    });
  }

  Widget _modelOptions(
    AgentModelConfig model,
    AppLocalizations l,
  ) => ExpansionTile(
    key: ValueKey('agent-model-options-${model.id}'),
    title: Text(model.id),
    subtitle: model.id == _defaultModel ? Text(l.agentDefaultModel) : null,
    trailing: IconButton(
      key: ValueKey('agent-remove-model-${model.id}'),
      tooltip: l.agentRemoveModel,
      onPressed: _saving
          ? null
          : () => setState(() => _setModelEnabled(model.id, false)),
      icon: const Icon(Icons.close),
    ),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(l.agentAllowedEfforts),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final effort in AgentReasoningEffort.values)
            FilterChip(
              key: ValueKey('agent-model-effort-${model.id}-${effort.name}'),
              label: Text(agentReasoningEffortLabel(l, effort)),
              selected: model.reasoningEfforts.contains(effort),
              onSelected: _saving || effort == AgentReasoningEffort.auto
                  ? null
                  : (selected) {
                      setState(() {
                        final efforts = AgentReasoningEffort.values
                            .where(
                              (value) =>
                                  value == AgentReasoningEffort.auto ||
                                  (value == effort
                                      ? selected
                                      : model.reasoningEfforts.contains(value)),
                            )
                            .toList();
                        _models[model.id] = AgentModelConfig(
                          id: model.id,
                          reasoningEfforts: List.unmodifiable(efforts),
                          defaultReasoningEffort:
                              efforts.contains(model.defaultReasoningEffort)
                              ? model.defaultReasoningEffort
                              : AgentReasoningEffort.auto,
                        );
                      });
                    },
            ),
        ],
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<AgentReasoningEffort>(
        key: ValueKey(
          'agent-default-effort-${model.id}-${model.defaultReasoningEffort.name}',
        ),
        initialValue: model.defaultReasoningEffort,
        isExpanded: true,
        decoration: InputDecoration(
          filled: true,
          labelText: l.agentDefaultEffort,
        ),
        items: [
          for (final effort in model.reasoningEfforts)
            DropdownMenuItem(
              value: effort,
              child: Text(agentReasoningEffortLabel(l, effort)),
            ),
        ],
        onChanged: _saving
            ? null
            : (effort) => setState(() {
                if (effort != null) {
                  _models[model.id] = AgentModelConfig(
                    id: model.id,
                    reasoningEfforts: model.reasoningEfforts,
                    defaultReasoningEffort: effort,
                  );
                }
              }),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final savedEndpoint = Uri.tryParse(widget.settings.endpoint);
    final canDiagnose = savedEndpoint != null && savedEndpoint.host.isNotEmpty;
    final safeEndpoint = canDiagnose
        ? Uri(
            scheme: savedEndpoint.scheme,
            host: savedEndpoint.host,
            port: savedEndpoint.hasPort ? savedEndpoint.port : null,
            path: savedEndpoint.path,
          ).toString()
        : '';
    return SkedSurface(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showTitle) ...[
                Text(
                  l.agentModelSettings,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
              ],
              Text(l.agentApiDataNotice),
              const SizedBox(height: 16),
              if (widget.onProbe != null || widget.onListModels != null) ...[
                Text(
                  l.agentSavedConnectionHint(
                    safeEndpoint.isEmpty
                        ? l.backupParserEndpointUnset
                        : safeEndpoint,
                  ),
                ),
                if (savedEndpoint?.scheme == 'http')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(l.agentHttpTransportWarning),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.onProbe != null)
                      OutlinedButton(
                        key: const ValueKey('agent-probe-connection'),
                        onPressed:
                            canDiagnose &&
                                widget.settings.model.isNotEmpty &&
                                !_diagnosing &&
                                !_saving
                            ? () => _diagnose(listModels: false)
                            : null,
                        child: Text(l.agentTestConnection),
                      ),
                    if (widget.onListModels != null)
                      OutlinedButton(
                        key: const ValueKey('agent-load-models'),
                        onPressed: canDiagnose && !_diagnosing && !_saving
                            ? () => _diagnose(listModels: true)
                            : null,
                        child: Text(l.agentLoadModels),
                      ),
                  ],
                ),
                if (_diagnosing) const LinearProgressIndicator(),
                if (_diagnosticFailed)
                  Text(
                    l.agentRequestFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_probe case final result?) ...[
                  Text(l.agentConnectionOk),
                  Text(
                    result.toolCallingObserved
                        ? l.agentToolsObserved
                        : l.agentToolsUnverified,
                  ),
                ],
                if (_catalog case final catalog?) ...[
                  if (!catalog.complete) Text(l.agentModelsPartial),
                  TextField(
                    key: const ValueKey('agent-model-search'),
                    controller: _modelSearch,
                    decoration: InputDecoration(
                      filled: true,
                      labelText: l.agentModelSearch,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(
                    key: const ValueKey('agent-model-catalog'),
                    height: 240,
                    child: Builder(
                      builder: (context) {
                        final filtered = catalog.models
                            .where(
                              (id) => id.toLowerCase().contains(
                                _modelSearch.text.trim().toLowerCase(),
                              ),
                            )
                            .toList();
                        return ListView.builder(
                          primary: false,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final id = filtered[index];
                            return CheckboxListTile(
                              key: ValueKey('agent-catalog-model-$id'),
                              value: _models.containsKey(id),
                              title: Text(id),
                              onChanged: _saving
                                  ? null
                                  : (enabled) => setState(
                                      () => _setModelEnabled(id, enabled!),
                                    ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
              TextFormField(
                key: const ValueKey('agent-endpoint'),
                controller: _endpoint,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  filled: true,
                  labelText: l.agentEndpoint,
                  errorMaxLines: 5,
                ),
                validator: (value) {
                  try {
                    if (value == null || value.trim().isEmpty) {
                      return l.agentInvalidEndpoint;
                    }
                    AgentSettings(endpoint: value.trim()).validate();
                    return null;
                  } on FormatException {
                    return l.agentInvalidEndpoint;
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('agent-model'),
                controller: _model,
                enabled: !_saving,
                autocorrect: false,
                decoration: InputDecoration(
                  filled: true,
                  labelText: l.agentManualModelId,
                ),
                validator: (value) => (value?.trim().length ?? 0) > 256
                    ? l.agentRequiredField
                    : null,
                onFieldSubmitted: (_) {
                  if (!_saving) _addManualModel();
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('agent-add-model'),
                  onPressed: _saving ? null : _addManualModel,
                  icon: const Icon(Icons.add),
                  label: Text(l.agentAddModel),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.agentEnabledModels,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_models.isEmpty) Text(l.agentNoModelsSelected),
              if (_models.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('agent-default-model-$_defaultModel'),
                  initialValue: _defaultModel,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    labelText: l.agentDefaultModel,
                  ),
                  items: [
                    for (final id in _models.keys)
                      DropdownMenuItem(
                        value: id,
                        child: Text(id, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (id) => setState(() => _defaultModel = id!),
                ),
                const SizedBox(height: 8),
                Text(l.agentModelCapabilityHint),
                for (final model in _models.values) _modelOptions(model, l),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<AgentModelProtocol>(
                key: const ValueKey('agent-protocol'),
                initialValue: _protocol,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  labelText: l.agentProtocol,
                ),
                items: const [
                  DropdownMenuItem(
                    value: AgentModelProtocol.chatCompletions,
                    child: Text('Chat Completions'),
                  ),
                  DropdownMenuItem(
                    value: AgentModelProtocol.responses,
                    child: Text('Responses'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _protocol = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('agent-api-key'),
                controller: _key,
                enabled: !_saving && !_clearKey,
                obscureText: !_showKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  filled: true,
                  labelText: l.agentApiKey,
                  helperText: l.agentKeyHint,
                  helperMaxLines: 3,
                  suffixIcon: IconButton(
                    tooltip: _showKey ? l.agentHideKey : l.agentShowKey,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _showKey = !_showKey),
                    icon: Icon(
                      _showKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              if (widget.settings.credentialRef != null)
                CheckboxListTile(
                  key: const ValueKey('agent-clear-key'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.agentClearKey),
                  value: _clearKey,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _clearKey = value!;
                          if (_clearKey) _key.clear();
                        }),
                ),
              if (_failed)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    l.agentSaveFailed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('agent-save-model'),
                onPressed: _saving || _diagnosing ? null : _save,
                child: Text(_saving ? l.agentSaving : l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
