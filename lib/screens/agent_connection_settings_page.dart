import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/connection/agent_connection_diagnostics.dart';
import '../agent/connection/agent_connection_manager.dart';
import '../agent/provider/provider.dart' show ProviderCancellationToken;
import '../agent/ui/agent_model_labels.dart';
import '../agent/ui/agent_settings_exit_guard.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_settings.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/sked_dropdown_menu.dart';
import '../widgets/sked_task_session.dart';
import 'agent_model_settings_page.dart';

class AgentConnectionSettingsPage extends StatefulWidget {
  const AgentConnectionSettingsPage({super.key});
  @override
  State<AgentConnectionSettingsPage> createState() =>
      _AgentConnectionSettingsPageState();
}

class _AgentConnectionSettingsPageState
    extends State<AgentConnectionSettingsPage>
    with AgentSettingsExitGuard<AgentConnectionSettingsPage> {
  final _form = GlobalKey<FormState>();
  final _endpoint = TextEditingController();
  final _key = TextEditingController();
  late AgentSettings _baseline;
  AgentModelProtocol _protocol = AgentModelProtocol.chatCompletions;
  bool _initialized = false;
  bool _saving = false;
  bool _clearKey = false;
  bool _showKey = false;
  bool _opening = false;
  bool _routeCurrent = false;
  int _interactionGeneration = 0;
  String? _error;
  _AgentConnectionProbeState? _probe;
  AgentApplication? _scopeApplication;
  _AgentDiagnosticRequest? _diagnosticRequest;

  bool get _diagnosing => _diagnosticRequest != null;

  @override
  Object get settingsDraftFingerprint =>
      (_endpoint.text, _protocol, _key.text, _clearKey);
  @override
  bool get settingsExitBlocked => _saving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeApplication = context.read<AgentApplication>();
    if (_probe case final probe? when !probe.session.isCurrent) _clearProbe();
    final current = ModalRoute.of(context)?.isCurrent == true;
    if (_routeCurrent && !current) _interactionGeneration++;
    _routeCurrent = current;
    final request = _diagnosticRequest;
    if (request != null) {
      request.session.check();
      if (!request.session.isCurrent) _retireDiagnostic(request, cancel: true);
    }
    if (_initialized) return;
    _initialized = true;
    _baseline = context.read<AgentApplication>().settings;
    _endpoint.text = _baseline.endpoint;
    _protocol = _baseline.protocol;
    initializeSettingsDraftGuard();
  }

  bool _sameTransport(AgentSettings value) =>
      value.endpoint == _baseline.endpoint &&
      value.protocol == _baseline.protocol &&
      value.credentialRef == _baseline.credentialRef;

  Future<void> _save() async {
    if (_saving ||
        _diagnosing ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_form.currentState!.validate())
      return;
    final application = context.read<AgentApplication>();
    final snapshot = application.settings;
    final l = AppLocalizations.of(context);
    if (!_sameTransport(snapshot)) {
      setState(() => _error = l.agentSettingsChanged);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await application.configure(
        snapshot.copyWith(endpoint: _endpoint.text.trim(), protocol: _protocol),
        expectedSettings: snapshot,
        credentialAction: _clearKey
            ? AgentCredentialAction.clear
            : _key.text.isNotEmpty
            ? AgentCredentialAction.replace
            : AgentCredentialAction.keep,
        rawKey: _clearKey || _key.text.isEmpty ? null : _key.text,
      );
      if (!mounted) return;
      _key.clear();
      setState(() {
        _clearKey = false;
        _saving = false;
      });
      completeSettingsSave<void>();
    } on AgentConnectionException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error.code == AgentConnectionErrorCode.configurationChanged
              ? l.agentSettingsChanged
              : l.agentSettingsSaveFailed,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = l.agentSettingsSaveFailed);
    } finally {
      if (mounted && _saving) setState(() => _saving = false);
    }
  }

  Future<void> _open(
    Widget page, {
    required int generation,
    required AgentApplication application,
    required AgentSettings expectedSettings,
  }) async {
    if (!mounted ||
        _saving ||
        _opening ||
        generation != _interactionGeneration ||
        ModalRoute.of(context)?.isCurrent != true ||
        !identical(_scopeApplication, application) ||
        application.settings != expectedSettings)
      return;
    if (_diagnosticRequest case final request?) {
      _retireDiagnostic(request, cancel: true);
    }
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<AgentApplication>.value(
            value: application,
            child: page,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _retireDiagnostic(
    _AgentDiagnosticRequest request, {
    bool cancel = false,
    bool rebuild = false,
  }) {
    if (cancel) request.cancellation.cancel();
    final ownsUi = identical(_diagnosticRequest, request);
    if (ownsUi) _diagnosticRequest = null;
    request.dispose();
    if (mounted && ownsUi && rebuild) setState(() {});
  }

  void _clearProbe() {
    _probe?.session.dispose();
    _probe = null;
  }

  Future<void> _diagnose({
    required bool listModels,
    required int generation,
  }) async {
    if (!mounted ||
        _saving ||
        _diagnosing ||
        generation != _interactionGeneration ||
        ModalRoute.of(context)?.isCurrent != true)
      return;
    final application = context.read<AgentApplication>();
    final snapshot = application.settings;
    final route = ModalRoute.of(context);
    final l = AppLocalizations.of(context);
    final cancellation = ProviderCancellationToken();
    final request = _AgentDiagnosticRequest(
      cancellation: cancellation,
      session: SkedTaskSession(
        ownerRoute: route,
        targetChanges: application,
        isOwnerActive: () => mounted && route?.isCurrent == true,
        isTargetCurrent: () =>
            mounted &&
            generation == _interactionGeneration &&
            identical(_scopeApplication, application) &&
            application.settings == snapshot,
      ),
    );
    request.onInvalidated = () {
      if (request.session.isCurrent) return;
      cancellation.cancel();
      // A session can notify while checking its owner. Dispose after that
      // notification has drained, and only release this request's UI state.
      scheduleMicrotask(() => _retireDiagnostic(request, rebuild: true));
    };
    request.session.addListener(request.onInvalidated!);
    setState(() {
      _clearProbe();
      _diagnosticRequest = request;
      _error = null;
    });
    bool current() =>
        mounted &&
        identical(_diagnosticRequest, request) &&
        request.session.isCurrent &&
        !cancellation.isCancelled;
    try {
      if (listModels) {
        final catalog = await application.listConnectionModels(
          cancellation: cancellation,
          allowInsecureHttp: Uri.tryParse(snapshot.endpoint)?.scheme == 'http',
        );
        if (current()) {
          _retireDiagnostic(request, rebuild: true);
          await _open(
            _AgentModelCatalogPage(catalog: catalog),
            generation: generation,
            application: application,
            expectedSettings: snapshot,
          );
        }
      } else {
        final probe = await application.probeConnection(
          cancellation: cancellation,
          allowInsecureHttp: Uri.tryParse(snapshot.endpoint)?.scheme == 'http',
        );
        if (current()) {
          // A completed probe may survive an unrelated route visit. A change
          // to its saved configuration permanently expires that result.
          final state = _AgentConnectionProbeState(
            result: probe,
            session: SkedTaskSession(
              ownerRoute: route,
              targetChanges: application,
              isOwnerActive: () => mounted,
              isTargetCurrent: () =>
                  mounted &&
                  identical(_scopeApplication, application) &&
                  application.settings == snapshot,
            ),
          );
          setState(() => _probe = state);
        }
      }
    } catch (_) {
      if (current()) setState(() => _error = l.agentRequestFailed);
    } finally {
      _retireDiagnostic(request, rebuild: true);
    }
  }

  @override
  void dispose() {
    _clearProbe();
    if (_diagnosticRequest case final request?) {
      _retireDiagnostic(request, cancel: true);
    }
    _key.clear();
    _key.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = _interactionGeneration;
    final application = context.watch<AgentApplication>();
    final settings = application.settings;
    final l = AppLocalizations.of(context);
    final uri = Uri.tryParse(settings.endpoint);
    final canDiagnose = uri?.host.isNotEmpty == true;
    final safeEndpoint = canDiagnose
        ? Uri(
            scheme: uri!.scheme,
            host: uri.host,
            port: uri.hasPort ? uri.port : null,
            path: uri.path,
          ).toString()
        : l.backupParserEndpointUnset;
    return guardSettingsPage(
      SettingsPageScaffold(
        title: l.agentConnectionAndModels,
        bodyBuilder: (_, header) => Form(
          key: _form,
          child: ResponsiveSettingsSingleColumnBody(
            headerSliver: header,
            scrollViewKey: const PageStorageKey('agent-connection-scroll'),
            children: [
              Text(
                l.agentConnectionSettings,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('agent-endpoint'),
                controller: _endpoint,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                autocorrect: false,
                maxLength: 4096,
                decoration: InputDecoration(
                  labelText: l.agentEndpoint,
                  counterText: '',
                  errorMaxLines: 4,
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  try {
                    AgentSettings(endpoint: value?.trim() ?? '').validate();
                    return null;
                  } on FormatException {
                    return l.agentInvalidEndpoint;
                  }
                },
              ),
              const SizedBox(height: 16),
              SkedDropdownMenu<AgentModelProtocol>(
                key: const ValueKey('agent-protocol'),
                initialSelection: _protocol,
                enabled: !_saving,
                label: Text(l.agentProtocol),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(
                    value: AgentModelProtocol.chatCompletions,
                    label: 'Chat Completions',
                  ),
                  DropdownMenuEntry(
                    value: AgentModelProtocol.responses,
                    label: 'Responses',
                  ),
                ],
                onSelected: _saving
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
                onChanged: (_) => setState(() {}),
              ),
              if (settings.credentialRef != null)
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
              const SizedBox(height: 16),
              Text(
                l.agentApiDataNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: const ValueKey('agent-save-connection'),
                  onPressed: _saving || _diagnosing ? null : _save,
                  child: Text(_saving ? l.agentSaving : l.save),
                ),
              ),
              const SizedBox(height: 28),
              SettingsConnectedGroup(
                title: l.agentEnabledModels,
                tonal: true,
                children: [
                  for (final model in settings.availableModels)
                    SettingsConnectedTile(
                      key: ValueKey('agent-configured-model-${model.id}'),
                      leading: const Icon(Icons.smart_toy_outlined),
                      title: model.id,
                      subtitle: agentReasoningEffortLabel(
                        l,
                        model.defaultReasoningEffort,
                      ),
                      value: settings.model == model.id
                          ? l.agentDefaultModel
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving || _opening
                          ? null
                          : () => unawaited(
                              _open(
                                AgentModelSettingsPage(model: model),
                                generation: generation,
                                application: application,
                                expectedSettings: settings,
                              ),
                            ),
                    ),
                  SettingsConnectedTile(
                    key: const ValueKey('agent-add-model'),
                    leading: const Icon(Icons.add),
                    title: l.agentAddModel,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _saving || _opening
                        ? null
                        : () => unawaited(
                            _open(
                              AgentModelSettingsPage(
                                suggestedId: settings.models.isEmpty
                                    ? application.suggestedModelId
                                    : null,
                              ),
                              generation: generation,
                              application: application,
                              expectedSettings: settings,
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l.agentSavedConnectionHint(safeEndpoint),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (uri?.scheme == 'http') ...[
                const SizedBox(height: 8),
                Text(
                  l.agentHttpTransportWarning,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('agent-probe-connection'),
                    onPressed:
                        canDiagnose &&
                            settings.defaultModelSelection != null &&
                            !_diagnosing &&
                            !_saving
                        ? () => unawaited(
                            _diagnose(
                              listModels: false,
                              generation: generation,
                            ),
                          )
                        : null,
                    child: Text(l.agentTestConnection),
                  ),
                  OutlinedButton(
                    key: const ValueKey('agent-load-models'),
                    onPressed: canDiagnose && !_diagnosing && !_saving
                        ? () => unawaited(
                            _diagnose(listModels: true, generation: generation),
                          )
                        : null,
                    child: Text(l.agentLoadModels),
                  ),
                ],
              ),
              if (_diagnosing) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (_probe case final probe? when probe.session.isCurrent) ...[
                const SizedBox(height: 12),
                Text(l.agentConnectionOk),
                Text(
                  probe.result.toolCallingObserved
                      ? l.agentToolsObserved
                      : l.agentToolsUnverified,
                ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  key: const ValueKey('agent-settings-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentConnectionProbeState {
  _AgentConnectionProbeState({required this.result, required this.session});
  final AgentConnectionProbeResult result;
  final SkedTaskSession session;
}

class _AgentDiagnosticRequest {
  _AgentDiagnosticRequest({required this.cancellation, required this.session});
  final ProviderCancellationToken cancellation;
  final SkedTaskSession session;
  VoidCallback? onInvalidated;

  void dispose() {
    if (onInvalidated case final callback?) session.removeListener(callback);
    session.dispose();
  }
}

class _AgentModelCatalogPage extends StatefulWidget {
  const _AgentModelCatalogPage({required this.catalog});
  final AgentModelCatalog catalog;
  @override
  State<_AgentModelCatalogPage> createState() => _AgentModelCatalogPageState();
}

class _AgentModelCatalogPageState extends State<_AgentModelCatalogPage> {
  final _search = TextEditingController();
  bool _opening = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    if (_opening || ModalRoute.of(context)?.isCurrent != true) return;
    final application = context.read<AgentApplication>();
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<AgentApplication>.value(
            value: application,
            child: AgentModelSettingsPage(
              model: application.settings.modelConfig(id),
              suggestedId: id,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final settings = context.watch<AgentApplication>().settings;
    final query = _search.text.trim().toLowerCase();
    final models = widget.catalog.models
        .where((id) => id.toLowerCase().contains(query))
        .toList();
    return SettingsPageScaffold(
      title: l.agentLoadModels,
      bodyBuilder: (_, header) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: CustomScrollView(
            key: const PageStorageKey('agent-model-catalog-scroll'),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              ?header,
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('agent-model-search'),
                        controller: _search,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          labelText: l.agentModelSearch,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (!widget.catalog.complete) ...[
                        const SizedBox(height: 12),
                        Text(l.agentModelsPartial),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: models.length,
                  itemBuilder: (_, index) {
                    final id = models[index];
                    return ListTile(
                      key: ValueKey('agent-catalog-model-$id'),
                      leading: const Icon(Icons.smart_toy_outlined),
                      title: Text(id),
                      trailing: Icon(
                        settings.modelConfig(id) == null
                            ? Icons.add
                            : Icons.chevron_right,
                      ),
                      onTap: _opening ? null : () => unawaited(_open(id)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
