import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../agent/agent_application.dart';
import '../agent/knowledge/knowledge_models.dart';
import '../agent/ui/agent_knowledge_view.dart';
import '../agent/ui/contributions/agent_ui_contribution_contracts.dart';
import '../agent/ui/contributions/agent_ui_contribution_host.dart';
import '../agent/ui/contributions/agent_ui_contribution_registry.dart';
import '../agent/ui/contributions/agent_ui_default_renderers.dart';
import '../l10n/app_localizations.dart';
import '../widgets/settings_list.dart';
import '../widgets/settings_page_header.dart';
import '../widgets/sked_task_session.dart';
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

  static Future<void> openConnection(BuildContext context) async {
    final application = context.read<AgentApplication>();
    final entry = application.uiContributions
        .entries(AgentUiContributionSlot.settings)
        .where(
          (entry) =>
              entry.contribution.rendererId == AgentUiRendererIds.connection,
        )
        .firstOrNull;
    if (entry == null || !entry.isCurrent) return;
    final lease = entry.lease();
    final session = agentUiContributionSession(
      context: context,
      lease: lease,
      isOwnerActive: () => context.mounted,
      isTargetCurrent: () =>
          context.mounted &&
          identical(context.read<AgentApplication>(), application),
    );
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<AgentApplication>.value(
            value: application,
            child: SkedTaskRouteGuard(
              parent: session,
              child: const AgentConnectionSettingsPage(),
            ),
          ),
        ),
      );
    } finally {
      session.dispose();
      lease.dispose();
    }
  }

  @override
  State<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends State<AgentSettingsPage> {
  AgentApplication? _initializationAttempt;
  AgentApplication? _application;
  final _destinations = <SkedTaskSession>{};
  bool _opening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final application = context.read<AgentApplication>();
    if (!identical(_application, application)) {
      for (final session in _destinations) {
        session.invalidate();
      }
      _application = application;
    }
    if (!application.platformSupported) return;
    if (identical(_initializationAttempt, application)) return;
    _initializationAttempt = application;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(context.read<AgentApplication>(), application)) {
        application.initialize().ignore();
      }
    });
  }

  Future<void> _open(AgentUiContributionEntry entry, Widget page) async {
    if (_opening ||
        !entry.isCurrent ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final application = context.read<AgentApplication>();
    final lease = entry.lease();
    final session = agentUiContributionSession(
      context: context,
      lease: lease,
      isOwnerActive: () => mounted,
      isTargetCurrent: () => identical(_application, application),
    );
    _destinations.add(session);
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChangeNotifierProvider<AgentApplication>.value(
            value: application,
            child: SkedTaskRouteGuard(
              parent: session,
              child: AgentUiContributionScope(lease: lease, child: page),
            ),
          ),
        ),
      );
    } finally {
      _destinations.remove(session);
      session.dispose();
      lease.dispose();
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    for (final session in _destinations) {
      session.invalidate();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final application = context.watch<AgentApplication>();
    final l = AppLocalizations.of(context);
    final uri = Uri.tryParse(application.settings.endpoint);
    final endpoint = uri?.host.isNotEmpty == true
        ? uri!.host
        : l.backupParserEndpointUnset;
    final data = AgentSettingsDestinationData(
      platformSupported: application.platformSupported,
      endpoint: endpoint,
      connection: const AgentConnectionSettingsPage(),
      preferences: const AgentPreferencesSettingsPage(),
      skills: const _AgentKnowledgeSettingsPage(kind: KnowledgeKind.skill),
      memories: const _AgentKnowledgeSettingsPage(kind: KnowledgeKind.memory),
    );
    return ListenableBuilder(
      listenable: application.uiContributions,
      builder: (context, _) {
        final destinations = [
          for (final entry in application.uiContributions.entries(
            AgentUiContributionSlot.settings,
          ))
            if (buildAgentSettingsContribution(
                  context,
                  entry.contribution,
                  data,
                )
                case final view?)
              (entry, view),
        ];
        final usedKeys = <Key>{};
        final keyedDestinations = [
          for (final (entry, view) in destinations)
            (
              entry,
              view,
              usedKeys.add(view.key) ? view.key : ValueKey((view.key, entry)),
            ),
        ];
        return SettingsPageScaffold(
          title: l.agentSettingsTitle,
          bodyBuilder: (_, header) => ResponsiveSettingsSingleColumnBody(
            headerSliver: header,
            scrollViewKey: const PageStorageKey(
              'agent-settings-overview-scroll',
            ),
            children: [
              SettingsConnectedGroup(
                tonal: true,
                children: [
                  if (!application.platformSupported)
                    SettingsConnectedTile(
                      key: const ValueKey(
                        'agent-settings-unsupported-platform',
                      ),
                      leading: const Icon(Icons.info_outline),
                      title: l.agentUnsupportedPlatform,
                      informational: true,
                    ),
                  for (final (entry, view, key) in keyedDestinations)
                    SettingsConnectedTile(
                      key: key,
                      leading: Icon(view.icon),
                      title: view.title,
                      value: view.value,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _opening || !entry.isCurrent
                          ? null
                          : () => unawaited(_open(entry, view.page)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
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
