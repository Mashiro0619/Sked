import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';
import '../../theme/sked_surface.dart';
import '../connection/agent_credential_action.dart';
import '../connection/agent_connection_diagnostics.dart';
import '../provider/provider.dart' show ProviderCancellationToken;

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
  late final _model = TextEditingController(text: widget.settings.model);
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _diagnosing || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      final change = AgentModelSettingsChange(
        settings: widget.settings.copyWith(
          endpoint: _endpoint.text.trim(),
          model: _model.text.trim(),
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
      setState(() => _clearKey = false);
      widget.onSaved?.call();
    } catch (_) {
      // Never echo provider exceptions or a secret-bearing command.
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
                  DropdownButton<String>(
                    key: const ValueKey('agent-model-catalog'),
                    isExpanded: true,
                    hint: Text(l.agentChooseModel),
                    items: [
                      for (final model in catalog.models)
                        DropdownMenuItem(
                          value: model,
                          child: Text(
                            model,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) _model.text = value;
                          },
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
                  labelText: l.agentModel,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l.agentRequiredField
                    : null,
              ),
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
