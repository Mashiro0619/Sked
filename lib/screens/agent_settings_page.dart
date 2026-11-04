import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/knowledge/knowledge_models.dart';
import '../agent/ui/agent_knowledge_view.dart';
import '../l10n/app_localizations.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_page_header.dart';
import 'agent_connection_settings_page.dart';
import 'agent_preferences_settings_page.dart';

/// Agent settings follow the same page hierarchy as the app's other settings.
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
  AgentApplication? _initializationAttempt;
  bool _opening = false;

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

  Future<void> _open(Widget page) async {
    if (_opening || ModalRoute.of(context)?.isCurrent != true) return;
    final application = context.read<AgentApplication>();
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

  @override
  Widget build(BuildContext context) {
    final application = context.watch<AgentApplication>();
    final l = AppLocalizations.of(context);
    final uri = Uri.tryParse(application.settings.endpoint);
    final endpoint = uri?.host.isNotEmpty == true
        ? uri!.host
        : l.backupParserEndpointUnset;
    Widget destination(
      String key,
      String title,
      IconData icon,
      Widget page, {
      String? value,
    }) => SettingsConnectedTile(
      key: ValueKey(key),
      leading: Icon(icon),
      title: title,
      value: value,
      trailing: const Icon(Icons.chevron_right),
      onTap: _opening ? null : () => unawaited(_open(page)),
    );
    return SettingsPageScaffold(
      title: l.agentSettingsTitle,
      bodyBuilder: (_, header) => ResponsiveSettingsSingleColumnBody(
        headerSliver: header,
        scrollViewKey: const PageStorageKey('agent-settings-overview-scroll'),
        children: [
          SettingsConnectedGroup(
            tonal: true,
            children: [
              destination(
                'agent-settings-connection',
                l.agentConnectionAndModels,
                Icons.hub_outlined,
                const AgentConnectionSettingsPage(),
                value: endpoint,
              ),
              destination(
                'agent-settings-preferences',
                l.agentRunPreferences,
                Icons.tune,
                const AgentPreferencesSettingsPage(),
              ),
              destination(
                'agent-settings-skills',
                l.agentSkills,
                Icons.auto_awesome_outlined,
                const _AgentKnowledgeSettingsPage(kind: KnowledgeKind.skill),
              ),
              destination(
                'agent-settings-memories',
                l.agentMemories,
                Icons.psychology_outlined,
                const _AgentKnowledgeSettingsPage(kind: KnowledgeKind.memory),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentKnowledgeSettingsPage extends StatelessWidget {
  const _AgentKnowledgeSettingsPage({required this.kind});
  final KnowledgeKind kind;

  @override
  Widget build(BuildContext context) {
    final application = context.read<AgentApplication>();
    final l = AppLocalizations.of(context);
    return SettingsPageScaffold(
      title: kind == KnowledgeKind.skill ? l.agentSkills : l.agentMemories,
      bodyBuilder: (_, header) => AgentKnowledgeView(
        service: application.knowledge,
        kind: kind,
        pageEditor: true,
        headerSliver: header,
      ),
    );
  }
}
