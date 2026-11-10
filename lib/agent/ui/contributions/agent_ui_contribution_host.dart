import 'package:material_ui/material_ui.dart';

import '../../../widgets/sked_task_session.dart';
import 'agent_ui_contribution_registry.dart';

class AgentUiContributionScope
    extends InheritedNotifier<AgentUiContributionLease> {
  const AgentUiContributionScope({
    super.key,
    required AgentUiContributionLease lease,
    required super.child,
  }) : super(notifier: lease);

  AgentUiContributionLease get lease => notifier!;

  static AgentUiContributionLease? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AgentUiContributionScope>()
      ?.lease;
}

/// A mounted renderer owns its lease. A replacement entry builds a new lease,
/// so an old action closure cannot acquire a replacement provider implicitly.
class AgentUiContributionHost extends StatefulWidget {
  const AgentUiContributionHost({
    super.key,
    required this.entry,
    required this.builder,
    this.retired = const SizedBox.shrink(),
  });

  final AgentUiContributionEntry entry;
  final Widget Function(BuildContext context, AgentUiContributionLease lease)
  builder;
  final Widget retired;

  @override
  State<AgentUiContributionHost> createState() =>
      _AgentUiContributionHostState();
}

class _AgentUiContributionHostState extends State<AgentUiContributionHost> {
  late AgentUiContributionLease _lease;

  @override
  void initState() {
    super.initState();
    _lease = widget.entry.lease();
  }

  @override
  void didUpdateWidget(AgentUiContributionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.entry, widget.entry)) {
      _lease.dispose();
      _lease = widget.entry.lease();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _lease,
    builder: (context, _) => _lease.isCurrent
        ? AgentUiContributionScope(
            lease: _lease,
            child: Builder(
              builder: (context) => widget.builder(context, _lease),
            ),
          )
        : widget.retired,
  );

  @override
  void dispose() {
    _lease.dispose();
    super.dispose();
  }
}

/// Owned dialogs and sheets keep the existing source checks and close through
/// SkedTaskSession when their contribution is withdrawn.
SkedTaskSession agentUiContributionSession({
  required BuildContext context,
  required AgentUiContributionLease lease,
  Listenable? targetChanges,
  bool Function()? isOwnerActive,
  bool Function()? isTargetCurrent,
}) => SkedTaskSession(
  ownerRoute: ModalRoute.of(context),
  parent: SkedTaskSessionScope.maybeOf(context)?.session,
  targetChanges: Listenable.merge([lease, targetChanges]),
  isOwnerActive: isOwnerActive,
  isTargetCurrent: () => lease.isCurrent && isTargetCurrent?.call() != false,
);
