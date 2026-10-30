import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/agent_settings.dart';

class AgentPreferencesForm extends StatefulWidget {
  const AgentPreferencesForm({
    super.key,
    required this.settings,
    required this.onSave,
  });
  final AgentSettings settings;
  final Future<void> Function(AgentSettings) onSave;

  @override
  State<AgentPreferencesForm> createState() => _AgentPreferencesFormState();
}

class _AgentPreferencesFormState extends State<AgentPreferencesForm> {
  final _form = GlobalKey<FormState>();
  late final _instructions = TextEditingController(
    text: widget.settings.systemInstructions,
  );
  late final _rounds = TextEditingController(
    text: '${widget.settings.maxModelRounds}',
  );
  late final _calls = TextEditingController(
    text: '${widget.settings.maxToolCalls}',
  );
  late final _tokens = TextEditingController(
    text: '${widget.settings.maxTotalTokens}',
  );
  late final _retention = TextEditingController(
    text: '${widget.settings.historyRetentionDays}',
  );
  bool _saving = false;
  bool _failed = false;
  bool _saved = false;

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

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
      _saved = false;
    });
    try {
      await widget.onSave(
        widget.settings.copyWith(
          systemInstructions: _instructions.text,
          maxModelRounds: int.parse(_rounds.text),
          maxToolCalls: int.parse(_calls.text),
          maxTotalTokens: int.parse(_tokens.text),
          historyRetentionDays: int.parse(_retention.text),
        ),
      );
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget number(
      String key,
      String label,
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
          labelText: label,
          helperText: retention ? l.agentPreferenceLimitHint : '$min–$max',
          helperMaxLines: 5,
        ),
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
    return Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('agent-system-instructions'),
              controller: _instructions,
              enabled: !_saving,
              minLines: 3,
              maxLines: 8,
              maxLength: 16000,
              decoration: InputDecoration(labelText: l.agentSystemInstructions),
            ),
            number('agent-max-rounds', l.agentMaxModelRounds, _rounds, 1, 100),
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
            const SizedBox(height: 16),
            if (_failed)
              Text(
                l.agentSaveFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_saved) Text(l.agentPreferencesSaved),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? l.agentSaving : l.save),
            ),
          ],
        ),
      ),
    );
  }
}
