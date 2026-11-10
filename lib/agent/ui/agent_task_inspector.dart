import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/sked_task_session.dart';
import 'agent_conversation_timeline.dart';
import 'agent_ui_delegate.dart';
import 'contributions/agent_ui_contribution_contracts.dart';
import 'contributions/agent_ui_contribution_host.dart';
import 'contributions/agent_ui_contribution_registry.dart';
import 'contributions/agent_ui_default_renderers.dart';

/// Optional task facts, rendered by the currently registered section owners.
/// The transcript and this panel share their original execution projection.
class AgentTaskInspector extends StatefulWidget {
  const AgentTaskInspector({
    super.key,
    required this.operations,
    this.plan,
    required this.attachments,
    this.contextUsage,
    this.onCompact,
    required this.onClose,
    this.operationBuilder,
    this.uiContributions,
    this.sourceIdentity,
    this.isSourceCurrent,
  });

  final List<AgentTimelineOperation> operations;
  final AgentTimelinePlan? plan;
  final Widget attachments;
  final AgentContextUsage? contextUsage;
  final VoidCallback? onCompact;
  final VoidCallback onClose;
  final Widget Function(AgentTimelineOperation)? operationBuilder;
  final AgentUiContributionRegistry? uiContributions;

  /// Stable across updates to one conversation; changes retire its section
  /// tasks before another conversation or data owner uses the same panel.
  final Object? sourceIdentity;
  final bool Function()? isSourceCurrent;

  @override
  State<AgentTaskInspector> createState() => _AgentTaskInspectorState();
}

class _AgentTaskInspectorState extends State<AgentTaskInspector>
    with TickerProviderStateMixin {
  late AgentUiContributionRegistry _registry;
  AgentUiContributionRegistry? _ownedRegistry;
  List<AgentUiContributionEntry> _entries = const [];
  final _leases = <AgentUiContributionEntry, AgentUiContributionLease>{};
  final _sessions = <AgentUiContributionEntry, SkedTaskSession>{};
  TabController? _tabs;
  ModalRoute<dynamic>? _ownerRoute;
  SkedTaskSession? _parentSession;

  @override
  void initState() {
    super.initState();
    _attachRegistry();
  }

  void _attachRegistry() {
    final supplied = widget.uiContributions;
    if (supplied != null) {
      _registry = supplied;
    } else {
      final local = _ownedRegistry = AgentUiContributionRegistry();
      local.replaceProfileOwner(
        AgentUiContributionOwner(
          lifetime: AgentUiContributionLifetime.profile,
          sessionToken: Object(),
          instanceId: 'sked.standalone.inspector',
          generation: 0,
        ),
        defaultAgentInspectorContributions,
      );
      _registry = local;
    }
    _refreshEntries();
    _registry.addListener(_contributionsChanged);
  }

  void _contributionsChanged() {
    if (!mounted) return;
    setState(_refreshEntries);
  }

  void _refreshEntries() {
    final next = _registry
        .entries(AgentUiContributionSlot.inspectorSection)
        .where(
          (entry) =>
              agentInspectorRendererSupported(entry.contribution.rendererId),
        )
        .toList();
    if (_entries.length == next.length &&
        Iterable<int>.generate(next.length)
            .every((index) => identical(_entries[index], next[index]))) {
      return;
    }
    final selected = _entries.isEmpty ? null : _entries[_tabs!.index];
    for (final entry in _entries.where((entry) => !next.contains(entry))) {
      _sessions.remove(entry)?.dispose();
      _leases.remove(entry)?.dispose();
    }
    for (final entry in next) {
      _leases.putIfAbsent(entry, entry.lease);
    }
    _entries = next;
    _tabs?.dispose();
    final selectedIndex = selected == null ? -1 : next.indexOf(selected);
    _tabs = TabController(
      length: next.length,
      initialIndex: selectedIndex < 0 ? 0 : selectedIndex,
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final parent = SkedTaskSessionScope.maybeOf(context)?.session;
    if (!identical(route, _ownerRoute) || !identical(parent, _parentSession)) {
      _retireSessions();
      _ownerRoute = route;
      _parentSession = parent;
    }
  }

  @override
  void didUpdateWidget(AgentTaskInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.uiContributions, widget.uiContributions)) {
      _detachRegistry();
      _attachRegistry();
    } else if (oldWidget.sourceIdentity != widget.sourceIdentity) {
      _retireSessions();
    }
    for (final session in _sessions.values) {
      session.check();
    }
  }

  bool Function() _captureSourceCurrent() {
    final identity = widget.sourceIdentity;
    final current = widget.isSourceCurrent;
    final registry = _registry;
    final route = _ownerRoute;
    final parent = _parentSession;
    return () =>
        mounted &&
        widget.sourceIdentity == identity &&
        identical(_registry, registry) &&
        identical(_ownerRoute, route) &&
        identical(_parentSession, parent) &&
        parent?.isCurrent != false &&
        current?.call() != false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sourceCurrent = _captureSourceCurrent();
    final onClose = widget.onClose;
    final data = AgentInspectorSectionData(
      operations: widget.operations,
      attachments: widget.attachments,
      isSourceCurrent: sourceCurrent,
      plan: widget.plan,
      contextUsage: widget.contextUsage,
      onCompact: widget.onCompact,
      operationBuilder: widget.operationBuilder,
    );
    final sections = [
      for (final entry in _entries)
        (
          entry,
          buildAgentInspectorSectionContribution(
            context,
            _leases[entry]!,
            data,
          )!,
        ),
    ];
    final usedTabKeys = <Key>{};
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.agentTaskDetails,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey('agent-inspector-close'),
                  onPressed: () {
                    if (sourceCurrent()) onClose();
                  },
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (sections.isNotEmpty) ...[
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (final (entry, view) in sections)
                  Tab(
                    key: usedTabKeys.add(view.tabKey)
                        ? view.tabKey
                        : ValueKey((view.tabKey, entry)),
                    text: view.title,
                  ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final (entry, view) in sections)
                    AgentUiContributionScope(
                      key: ObjectKey(entry),
                      lease: _leases[entry]!,
                      child: SkedTaskSessionScope(
                        session: _sessions.putIfAbsent(
                          entry,
                          () => agentUiContributionSession(
                            context: context,
                            lease: _leases[entry]!,
                            isOwnerActive: () => mounted,
                            isTargetCurrent: sourceCurrent,
                          ),
                        ),
                        child: view.child,
                      ),
                    ),
                ],
              ),
            ),
          ] else
            const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  void _retireSessions() {
    for (final session in _sessions.values) {
      session.dispose();
    }
    _sessions.clear();
  }

  void _detachRegistry() {
    _registry.removeListener(_contributionsChanged);
    _retireSessions();
    for (final lease in _leases.values) {
      lease.dispose();
    }
    _leases.clear();
    _entries = const [];
    _tabs?.dispose();
    _tabs = null;
    _ownedRegistry?.dispose();
    _ownedRegistry = null;
  }

  @override
  void dispose() {
    _detachRegistry();
    super.dispose();
  }
}
