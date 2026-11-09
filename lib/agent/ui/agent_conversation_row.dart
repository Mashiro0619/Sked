import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../widgets/workbench_chrome_metrics.dart';
import '../conversations/conversation_models.dart';
import 'agent_ui_delegate.dart';
import 'agent_ui_style.dart';

class AgentConversationRow extends StatefulWidget {
  const AgentConversationRow({
    super.key,
    required this.conversation,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    required this.actions,
    this.delegate,
    this.busy = false,
  });

  final AgentConversation conversation;
  final AgentUiDelegate? delegate;
  final bool selected;
  final bool enabled;
  final bool busy;
  final VoidCallback? onSelected;
  final List<Widget> actions;

  @override
  State<AgentConversationRow> createState() => _AgentConversationRowState();
}

class _AgentConversationRowState extends State<AgentConversationRow> {
  ValueListenable<AgentUiRunState>? _run;
  bool _hovered = false;
  bool _focused = false;
  late ({AgentUiPhase phase, bool compacting, bool recovery}) _status;

  @override
  void initState() {
    super.initState();
    SemanticsBinding.instance.addSemanticsEnabledListener(_semanticsChanged);
    _watch();
  }

  void _semanticsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AgentConversationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.delegate, widget.delegate) ||
        oldWidget.conversation.id != widget.conversation.id) {
      _unwatch();
      _watch();
    } else {
      _status = _readStatus();
    }
    if (!widget.enabled) {
      _hovered = false;
      _focused = false;
    }
  }

  void _watch() {
    _run = widget.delegate?.watchConversation(widget.conversation.id);
    _status = _readStatus();
    _run?.addListener(_runChanged);
  }

  ({AgentUiPhase phase, bool compacting, bool recovery}) _readStatus() {
    final live = _run?.value;
    return (
      phase:
          live?.phase ??
          switch (widget.conversation.status) {
            ConversationStatus.idle => AgentUiPhase.idle,
            ConversationStatus.running ||
            ConversationStatus.stopping => AgentUiPhase.running,
            ConversationStatus.waitingApproval => AgentUiPhase.waitingApproval,
            ConversationStatus.waitingUser => AgentUiPhase.waitingUser,
            ConversationStatus.interrupted => AgentUiPhase.stopped,
          },
      compacting: live?.contextUsage?.isCompacting == true,
      recovery: live?.recoveryRequired == true,
    );
  }

  void _runChanged() {
    final next = _readStatus();
    // Token deltas do not rebuild the history row.
    if (next != _status) setState(() => _status = next);
  }

  void _unwatch() {
    final run = _run;
    run?.removeListener(_runChanged);
    if (run is AgentConversationRunListenable) run.dispose();
    _run = null;
  }

  @override
  void dispose() {
    SemanticsBinding.instance.removeSemanticsEnabledListener(_semanticsChanged);
    _unwatch();
    super.dispose();
  }

  Widget? _statusRing(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final label = _status.recovery
        ? l.agentRecoveryRequired
        : _status.compacting
        ? l.agentCompactingContext
        : switch (_status.phase) {
            AgentUiPhase.idle => null,
            AgentUiPhase.running => l.agentRunning,
            AgentUiPhase.waitingApproval => l.agentApprovalRequired,
            AgentUiPhase.waitingUser => l.agentWaitingForAnswer,
            AgentUiPhase.stopped => l.agentStopped,
            AgentUiPhase.failed => l.agentRunFailed,
          };
    if (label == null) return null;
    final running =
        !_status.recovery &&
        (_status.compacting || _status.phase == AgentUiPhase.running);
    final failed = _status.phase == AgentUiPhase.failed;
    final waiting =
        _status.recovery ||
        _status.phase == AgentUiPhase.waitingApproval ||
        _status.phase == AgentUiPhase.waitingUser;
    final color = failed
        ? colors.error
        : waiting
        ? colors.tertiary
        : colors.onSurfaceVariant;
    final motion = SkedMotionPolicy.of(context);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        label: label,
        child: ExcludeSemantics(
          child: SizedBox.square(
            key: ValueKey('agent-history-status-${widget.conversation.id}'),
            dimension: 20,
            child: Center(
              child: SizedBox.square(
                dimension: 14,
                child: running
                    ? CircularProgressIndicator(
                        value: motion.spatialAnimationsEnabled ? null : 0.75,
                        strokeWidth: 1.6,
                        padding: EdgeInsets.zero,
                        trackGap: 0,
                        color: color,
                      )
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: color, width: 1.4),
                        ),
                        child: Icon(
                          failed || _status.recovery
                              ? Icons.priority_high
                              : waiting
                              ? Icons.pause
                              : Icons.stop,
                          size: 8,
                          color: color,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = AgentUiStyle.of(context);
    final metrics = WorkbenchChromeMetrics.of(context);
    final visible =
        widget.enabled &&
        (!metrics.desktop ||
            _hovered ||
            _focused ||
            widget.busy ||
            MediaQuery.accessibleNavigationOf(context) ||
            SemanticsBinding.instance.semanticsEnabled);
    final status = _statusRing(context);
    final actions = widget.actions;
    return MouseRegion(
      onEnter: (_) {
        if (widget.enabled) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (_hovered) setState(() => _hovered = false);
      },
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: widget.enabled,
        descendantsAreTraversable: widget.enabled,
        onFocusChange: (value) {
          if (_focused != value) {
            setState(() => _focused = value && widget.enabled);
          }
        },
        child: ListTile(
          key: ValueKey('agent-history-${widget.conversation.id}'),
          selected: widget.selected,
          shape: metrics.desktop
              ? skedShapeSchemeOf(context).compact
              : skedShapeSchemeOf(context).control,
          selectedTileColor: style.selected,
          selectedColor: style.foreground,
          hoverColor: style.hover,
          focusColor: style.hover,
          minTileHeight: metrics.resourceRowHeight,
          minVerticalPadding: metrics.desktop ? 4 : null,
          contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
          title: Row(
            children: [
              if (widget.conversation.pinned) ...[
                Icon(Icons.push_pin, size: 12, color: style.muted),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Tooltip(
                  message: widget.conversation.title,
                  excludeFromSemantics: true,
                  child: Text(
                    widget.conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.label.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
          onTap: widget.enabled ? widget.onSelected : null,
          trailing: actions.isEmpty && status == null
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actions.isNotEmpty)
                      ExcludeFocus(
                        excluding: !visible,
                        child: ExcludeSemantics(
                          excluding: !visible,
                          child: IgnorePointer(
                            ignoring: !visible,
                            child: Visibility(
                              visible: visible,
                              maintainState: true,
                              maintainAnimation: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ?status,
                  ],
                ),
        ),
      ),
    );
  }
}
