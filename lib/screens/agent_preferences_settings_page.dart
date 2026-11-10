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
import '../widgets/sked_task_actions.dart';

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
  final _retention = TextEditingController();
  late AgentSettings _baseline;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  @override
  Object get settingsDraftFingerprint => (_instructions.text, _retention.text);
  @override
  bool get settingsExitBlocked => _saving;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _baseline = context.read<AgentApplication>().settings;
    _instructions.text = _baseline.systemInstructions;
    _retention.text = '${_baseline.historyRetentionDays}';
    initializeSettingsDraftGuard();
  }

  bool _unchanged(AgentSettings current) =>
      current.systemInstructions == _baseline.systemInstructions &&
      current.historyRetentionDays == _baseline.historyRetentionDays;

  Future<void> _save() async {
    if (_saving ||
        !settingsSourceCurrent ||
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
    for (final controller in [_instructions, _retention]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget labelled(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
        const SizedBox(height: 6),
        Semantics(label: title, child: child),
      ],
    );
    Widget number(String key, String title, TextEditingController controller) =>
        labelled(
          title,
          TextFormField(
            key: ValueKey(key),
            controller: controller,
            enabled: !_saving,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(errorMaxLines: 3),
            onChanged: (_) => setState(() {}),
            validator: (text) {
              final value = int.tryParse(text ?? '');
              return value == null || value < 0
                  ? l.agentInvalidPreference
                  : null;
            },
          ),
        );
    Widget section(String key, String title, String hint, Widget child) =>
        Padding(
          key: ValueKey(key),
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        );
    final editorActions = SkedEditorActions(
      onCancel: requestSettingsExit,
      onSubmit: _saving ? null : () => unawaited(_save()),
      busy: _saving,
    );
    final page = guardSettingsPage(
      SettingsPageScaffold(
        title: l.agentRunPreferences,
        bodyBuilder: (_, header) => Form(
          key: _form,
          child: ResponsiveSettingsSingleColumnBody(
            headerSliver: header,
            scrollViewKey: const PageStorageKey('agent-preferences-scroll'),
            children: [
              section(
                'agent-preferences-guidance',
                l.agentConversationGuidanceTitle,
                l.agentConversationGuidanceHint,
                labelled(
                  l.agentSystemInstructions,
                  TextFormField(
                    key: const ValueKey('agent-system-instructions'),
                    controller: _instructions,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 8,

                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              section(
                'agent-preferences-retention',
                l.agentHistoryRetentionTitle,
                l.agentPreferenceLimitHint,
                number(
                  'agent-history-retention',
                  l.agentHistoryRetentionDays,
                  _retention,
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  key: const ValueKey('agent-settings-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: editorActions.wrapSaveTooltip(
                  context,
                  FilledButton(
                    key: const ValueKey('agent-save-preferences'),
                    onPressed: editorActions.onSubmit,
                    child: Text(_saving ? l.agentSaving : l.save),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return editorActions.wrapShortcuts(context, page);
  }
}
