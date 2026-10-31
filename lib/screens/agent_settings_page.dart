import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/ui/agent_model_settings_form.dart';
import '../agent/ui/agent_preferences_form.dart';
import '../models/agent_settings.dart';
import '../l10n/app_localizations.dart';
import '../widgets/settings_page_header.dart';

/// The model connection is edited separately from conversation drafts.
class AgentSettingsPage extends StatefulWidget {
  const AgentSettingsPage({super.key});

  static Future<void> open(BuildContext context) {
    final application = context.read<AgentApplication>();
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<AgentApplication>.value(
          value: application,
          child: const AgentSettingsPage(),
        ),
      ),
    );
  }

  @override
  State<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends State<AgentSettingsPage> {
  bool _saving = false;
  AgentApplication? _initializationAttempt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final application = context.read<AgentApplication>();
    if (identical(_initializationAttempt, application)) return;
    _initializationAttempt = application;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(context.read<AgentApplication>(), application)) {
        application.initialize().ignore();
      }
    });
  }

  Future<void> _save(AgentModelSettingsChange change) async {
    if (_saving) throw StateError('Agent settings are already being saved.');
    setState(() => _saving = true);
    try {
      await context.read<AgentApplication>().configure(
        change.settings,
        credentialAction: change.credentialAction,
        rawKey: change.apiKey,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _savePreferences(AgentSettings settings) async {
    if (_saving) throw StateError('Agent settings are already being saved.');
    setState(() => _saving = true);
    try {
      await context.read<AgentApplication>().configurePreferences(settings);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _saved() {
    final route = ModalRoute.of(context);
    // The host must publish its cleared saving guard before asking the route
    // to pop. A late completion must never close a newer route above it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route?.isCurrent == true) {
        Navigator.of(context).maybePop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final application = context.watch<AgentApplication>();
    final displayedSettings = application.settings;
    void checkDisplayedConnection() {
      if (application.settings != displayedSettings) {
        throw StateError('The saved connection changed before this request.');
      }
    }

    final l = AppLocalizations.of(context);
    final tabs = TabBar(
      isScrollable: true,
      tabs: [
        Tab(text: l.agentModelSettings),
        Tab(text: l.agentRunPreferences),
      ],
    );
    return DefaultTabController(
      length: 2,
      child: PopScope<void>(
        canPop: !_saving,
        child: SettingsPageScaffold(
          title: l.agentSettingsTitle,
          headerBottom: PreferredSize(
            preferredSize: tabs.preferredSize,
            child: AbsorbPointer(
              absorbing: _saving,
              child: ExcludeFocus(excluding: _saving, child: tabs),
            ),
          ),
          bodyBuilder: (context, header) => NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [?header],
            body: TabBarView(
              physics: _saving ? const NeverScrollableScrollPhysics() : null,
              children: [
                _KeptSettingsForm(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: AgentModelSettingsForm(
                        settings: displayedSettings,
                        showTitle: false,
                        onSave: _save,
                        onSaved: _saved,
                        onProbe: (cancellation) {
                          checkDisplayedConnection();
                          return application.probeConnection(
                            allowInsecureHttp:
                                Uri.tryParse(displayedSettings.endpoint)
                                    ?.scheme ==
                                'http',
                            cancellation: cancellation,
                          );
                        },
                        onListModels: (cancellation) {
                          checkDisplayedConnection();
                          return application.listConnectionModels(
                            allowInsecureHttp:
                                Uri.tryParse(displayedSettings.endpoint)
                                    ?.scheme ==
                                'http',
                            cancellation: cancellation,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                _KeptSettingsForm(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: AgentPreferencesForm(
                        settings: application.settings,
                        onSave: _savePreferences,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KeptSettingsForm extends StatefulWidget {
  const _KeptSettingsForm({required this.child});
  final Widget child;

  @override
  State<_KeptSettingsForm> createState() => _KeptSettingsFormState();
}

class _KeptSettingsFormState extends State<_KeptSettingsForm>
    with AutomaticKeepAliveClientMixin<_KeptSettingsForm> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
