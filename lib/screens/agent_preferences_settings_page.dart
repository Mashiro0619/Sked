import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/connection/agent_connection_manager.dart';
import '../agent/ui/agent_settings_exit_guard.dart';
import '../l10n/app_localizations.dart';
import '../models/agent_settings.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/settings_list.dart';

class AgentPreferencesSettingsPage extends StatefulWidget {
  const AgentPreferencesSettingsPage({super.key});
  @override
  State<AgentPreferencesSettingsPage> createState() =>
      _AgentPreferencesSettingsPageState();
}

class _AgentPreferencesSettingsPageState
    extends State<AgentPreferencesSettingsPage>
    with AgentSettingsExitGuard<AgentPreferencesSettingsPage> {
  final _form = GlobalKey<FormState>();
  final _instructions = TextEditingController();
  final _rounds = TextEditingController();
  final _calls = TextEditingController();
  final _tokens = TextEditingController();
  final _retention = TextEditingController();
  late AgentSettings _baseline;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  Object get settingsDraftFingerprint => (
    _instructions.text,
    _rounds.text,
    _calls.text,
    _tokens.text,
    _retention.text,
  );
  @override
  bool get settingsExitBlocked => _saving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _baseline = context.read<AgentApplication>().settings;
    _instructions.text = _baseline.systemInstructions;
    _rounds.text = '${_baseline.maxModelRounds}';
    _calls.text = '${_baseline.maxToolCalls}';
    _tokens.text = '${_baseline.maxTotalTokens}';
    _retention.text = '${_baseline.historyRetentionDays}';
    initializeSettingsDraftGuard();
  }

  bool _unchanged(AgentSettings current) =>
      current.systemInstructions == _baseline.systemInstructions &&
      current.maxModelRounds == _baseline.maxModelRounds &&
      current.maxToolCalls == _baseline.maxToolCalls &&
      current.maxTotalTokens == _baseline.maxTotalTokens &&
      current.historyRetentionDays == _baseline.historyRetentionDays;

  Future<void> _save() async {
    if (_saving ||
        ModalRoute.of(context)?.isCurrent != true ||
        !_form.currentState!.validate()) {
      return;
    }
    final application = context.read<AgentApplication>();
    final current = application.settings;
    final l = AppLocalizations.of(context);
    if (!_unchanged(current)) {
      setState(() => _error = l.agentSettingsChanged);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await application.configurePreferences(
        current.copyWith(
          systemInstructions: _instructions.text,
          maxModelRounds: int.parse(_rounds.text),
          maxToolCalls: int.parse(_calls.text),
          maxTotalTokens: int.parse(_tokens.text),
          historyRetentionDays: int.parse(_retention.text),
        ),
        expectedSettings: current,
      );
      if (!mounted) return;
      setState(() => _saving = false);
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

  @override
  void dispose() {
    for (final controller in [
      _instructions,
      _rounds,
      _calls,
      _tokens,
      _retention,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget number(
      String key,
      String title,
      TextEditingController controller,
      int min,
      int max, {
      bool retention = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: TextFormField(
        key: ValueKey(key),
        controller: controller,
        enabled: !_saving,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: title,
          helperText: retention ? l.agentPreferenceLimitHint : '$min–$max',
          helperMaxLines: 5,
        ),
        onChanged: (_) => setState(() {}),
        validator: (text) {
          final value = int.tryParse(text ?? '');
          return value == null ||
                  value < min ||
                  value > max ||
                  (retention && value != 0 && value < 7)
              ? l.agentInvalidPreference
              : null;
        },
      ),
    );
    return guardSettingsPage(
      SettingsPageScaffold(
        title: l.agentRunPreferences,
        bodyBuilder: (_, header) => Form(
          key: _form,
          child: ResponsiveSettingsSingleColumnBody(
            headerSliver: header,
            scrollViewKey: const PageStorageKey('agent-preferences-scroll'),
            children: [
              TextFormField(
                key: const ValueKey('agent-system-instructions'),
                controller: _instructions,
                enabled: !_saving,
                minLines: 3,
                maxLines: 8,
                maxLength: 16000,
                decoration: InputDecoration(
                  labelText: l.agentSystemInstructions,
                  alignLabelWithHint: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              number(
                'agent-max-rounds',
                l.agentMaxModelRounds,
                _rounds,
                1,
                100,
              ),
              number('agent-max-calls', l.agentMaxToolCalls, _calls, 1, 500),
              number(
                'agent-max-tokens',
                l.agentMaxTotalTokens,
                _tokens,
                1024,
                1000000,
              ),
              number(
                'agent-history-retention',
                l.agentHistoryRetentionDays,
                _retention,
                0,
                3650,
                retention: true,
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  key: const ValueKey('agent-settings-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  key: const ValueKey('agent-save-preferences'),
                  onPressed: _saving ? null : () => unawaited(_save()),
                  child: Text(_saving ? l.agentSaving : l.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
