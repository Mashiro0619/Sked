import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_menu_style.dart';
import 'agent_activity_summary.dart';
import 'agent_conversation_timeline.dart';
import 'agent_inline_disclosure_header.dart';
import 'agent_selectable_text.dart';
import 'agent_ui_style.dart';

String agentToolActivityLabel(AgentToolActivity tool, AppLocalizations l) =>
    summarizeAgentToolActivity(tool, l).title;

String agentToolActivityStatusLabel(
  AgentToolActivityStatus status,
  AppLocalizations l,
) => switch (status) {
  AgentToolActivityStatus.running => l.agentRunning,
  AgentToolActivityStatus.completed => l.agentActivityCompleted,
  AgentToolActivityStatus.failed => l.agentActivityFailed,
  AgentToolActivityStatus.uncertain => l.agentActivityUncertain,
  AgentToolActivityStatus.notStarted => l.agentActivityNotStarted,
  AgentToolActivityStatus.cancelled => l.agentActivityCancelled,
  AgentToolActivityStatus.corrected => l.agentActivityCorrected,
};

IconData agentActivityStatusIcon(AgentToolActivityStatus status) =>
    switch (status) {
      AgentToolActivityStatus.failed => Icons.error_outline_rounded,
      AgentToolActivityStatus.uncertain => Icons.pending_outlined,
      AgentToolActivityStatus.notStarted => Icons.pause_circle_outline_rounded,
      AgentToolActivityStatus.cancelled => Icons.stop_circle_outlined,
      _ => Icons.terminal_rounded,
    };

IconData agentToolActivityIcon(String name) {
  if (name == 'ask_user') return Icons.chat_bubble_outline_rounded;
  if (name == 'update_plan') return Icons.checklist_rounded;
  if (name.startsWith('notifications.')) {
    return Icons.notifications_none_rounded;
  }
  if (name.startsWith('skills.') || name.startsWith('memories.')) {
    return Icons.description_outlined;
  }
  if (name.endsWith('.apply') ||
      name.endsWith('.update') ||
      name.endsWith('.undo') ||
      name.endsWith('.restore') ||
      name == 'maintenance.clear') {
    return Icons.edit_note_rounded;
  }
  if (name.endsWith('.list') ||
      name.endsWith('.get') ||
      name.endsWith('.read') ||
      name.endsWith('.search') ||
      name.endsWith('.describe') ||
      name.endsWith('.query') ||
      name.endsWith('.free_slots') ||
      name.endsWith('.conflicts')) {
    return Icons.search_rounded;
  }
  return Icons.terminal_rounded;
}

Color agentActivityStatusColor(
  AgentToolActivityStatus status,
  ColorScheme colors,
) => switch (status) {
  AgentToolActivityStatus.failed => colors.error,
  AgentToolActivityStatus.running => colors.onSurface,
  _ => colors.onSurfaceVariant,
};

/// One inline disclosure for tool traffic, operations and their decisions.
/// Completion collapses automatic expansion while retaining reader choices.
/// Reading choices follow a conversation, independently of execution updates.
class AgentActivityReading {
  final expanded = <String, bool>{};
  final processes = <String, bool>{};
}

class AgentActivityReadingScope extends InheritedWidget {
  const AgentActivityReadingScope({
    super.key,
    required this.reading,
    required this.onChanged,
    required super.child,
  });

  final AgentActivityReading reading;
  final VoidCallback onChanged;

  static AgentActivityReadingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AgentActivityReadingScope>();

  @override
  bool updateShouldNotify(AgentActivityReadingScope oldWidget) =>
      !identical(reading, oldWidget.reading);
}

class AgentActivityDisclosure extends StatefulWidget {
  const AgentActivityDisclosure({
    super.key,
    required this.id,
    required this.title,
    required this.status,
    required this.child,
    this.subtitle,
    this.statusLabel,
    this.statusIcon,
    this.semanticsLabel,
    this.initiallyExpanded = false,
    this.active = true,
    this.interactive = true,
    this.interactionRevision = 0,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String? statusLabel;
  final IconData? statusIcon;
  final String? semanticsLabel;
  final AgentToolActivityStatus status;
  final Widget child;
  final bool initiallyExpanded;
  final bool active;
  final bool interactive;
  final int interactionRevision;

  @override
  State<AgentActivityDisclosure> createState() =>
      _AgentActivityDisclosureState();
}

class _AgentActivityDisclosureState extends State<AgentActivityDisclosure> {
  bool? _readerExpanded;
  int _revision = 0;
  bool get _expanded =>
      AgentActivityReadingScope.maybeOf(context)?.reading.expanded[widget.id] ??
      _readerExpanded ??
      widget.initiallyExpanded;

  @override
  void didUpdateWidget(AgentActivityDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _readerExpanded = null;
    if (oldWidget.id != widget.id ||
        oldWidget.interactionRevision != widget.interactionRevision ||
        (oldWidget.active && !widget.active) ||
        (oldWidget.interactive && !widget.interactive)) {
      _revision++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AgentUiStyle.of(context);
    final colors = style.colors;
    final enabled = widget.active && widget.interactive;
    final status = widget.statusLabel;
    final label = [widget.title, ?status].join(' · ');
    final revision = _revision;
    void toggle() {
      if (mounted &&
          revision == _revision &&
          widget.active &&
          widget.interactive) {
        final expanded = !_expanded;
        setState(() => _readerExpanded = expanded);
        final scope = AgentActivityReadingScope.maybeOf(context);
        if (scope != null) {
          scope.reading.expanded[widget.id] = expanded;
          scope.onChanged();
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AgentInlineDisclosureHeader(
          title: label,
          subtitle: widget.subtitle,
          semanticsLabel:
              widget.semanticsLabel ??
              [
                label,
                ?widget.subtitle,
                if (status == null)
                  agentToolActivityStatusLabel(
                    widget.status,
                    AppLocalizations.of(context),
                  ),
              ].join(' · '),
          expanded: _expanded,
          onTap: enabled ? toggle : null,
          toggleKey: ValueKey('agent-activity-toggle-${widget.id}'),
          controlsKey: ValueKey(('activity-controls', revision)),
          titleStyle: style.label.copyWith(
            color: agentActivityStatusColor(widget.status, colors),
          ),
          leading: Icon(
            widget.statusIcon ?? agentActivityStatusIcon(widget.status),
            size: 16,
            color: agentActivityStatusColor(widget.status, colors),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, bottom: 4),
            child: DecoratedBox(
              key: ValueKey('agent-activity-branch-${widget.id}'),
              decoration: const BoxDecoration(),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ExcludeFocus(
                  excluding: !enabled,
                  child: ExcludeSemantics(
                    excluding: !enabled,
                    child: IgnorePointer(
                      ignoring: !enabled,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AgentTurnActivity extends StatelessWidget {
  const AgentTurnActivity({
    super.key,
    required this.activity,
    this.active = true,
    this.interactive = true,
    this.interactionRevision = 0,
    this.interactionForTool,
  });
  final AgentTimelineActivity activity;
  final bool active;
  final bool interactive;
  final int interactionRevision;
  final Widget? Function(AgentToolActivity tool)? interactionForTool;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tools = activity.tools;
    Widget row(AgentToolActivity tool) {
      final summary = summarizeAgentToolActivity(tool, l);
      final interaction = interactionForTool?.call(tool);
      return AgentActivityDisclosure(
        key: ValueKey('agent-activity-tool-${tool.id}'),
        id: tool.id,
        title: summary.title,
        subtitle: summary.detail,
        status: tool.status,
        statusIcon: agentToolActivityIcon(tool.name),
        initiallyExpanded: interaction != null,
        statusLabel: switch (tool.status) {
          AgentToolActivityStatus.failed ||
          AgentToolActivityStatus.uncertain ||
          AgentToolActivityStatus.notStarted ||
          AgentToolActivityStatus.cancelled ||
          AgentToolActivityStatus.corrected => agentToolActivityStatusLabel(
            tool.status,
            l,
          ),
          _ => null,
        },
        active: active,
        interactive: interactive,
        interactionRevision: interactionRevision,
        child:
            interaction ??
            AgentToolActivityDetails(
              tool: tool,
              enabled: active && interactive,
            ),
      );
    }

    if (tools.length == 1) return row(tools.single);
    return AgentActivityDisclosure(
      id: activity.id,
      title: l.agentActivitySummary(tools.length),
      status: activity.status,
      statusIcon: Icons.list_alt_rounded,
      statusLabel:
          activity.status == AgentToolActivityStatus.failed ||
              activity.status == AgentToolActivityStatus.uncertain ||
              activity.status == AgentToolActivityStatus.cancelled
          ? agentToolActivityStatusLabel(activity.status, l)
          : null,
      initiallyExpanded: activity.status == AgentToolActivityStatus.running,
      active: active,
      interactive: interactive,
      interactionRevision: interactionRevision,
      child: Column(
        key: ValueKey('agent-activity-list-${activity.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final tool in tools) row(tool)],
      ),
    );
  }
}

class AgentToolActivityDetails extends StatefulWidget {
  const AgentToolActivityDetails({
    super.key,
    required this.tool,
    this.enabled = true,
  });
  final AgentToolActivity tool;
  final bool enabled;
  @override
  State<AgentToolActivityDetails> createState() =>
      _AgentToolActivityDetailsState();
}

class _AgentToolActivityDetailsState extends State<AgentToolActivityDetails> {
  bool _copied = false;
  int _revision = 0;
  final _scroll = ScrollController();
  @override
  void didUpdateWidget(AgentToolActivityDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tool.result != widget.tool.result ||
        oldWidget.tool.arguments != widget.tool.arguments ||
        oldWidget.enabled != widget.enabled) {
      _copied = false;
      _revision++;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _copy(AgentToolActivity tool, int revision) async {
    if (!mounted ||
        !widget.enabled ||
        revision != _revision ||
        !identical(tool, widget.tool)) {
      return;
    }
    try {
      await Clipboard.setData(
        ClipboardData(
          text: [tool.name, tool.arguments, ?tool.result].join('\n\n'),
        ),
      );
      if (mounted &&
          widget.enabled &&
          revision == _revision &&
          identical(tool, widget.tool)) {
        setState(() => _copied = true);
      }
    } catch (_) {
      if (mounted &&
          widget.enabled &&
          revision == _revision &&
          identical(tool, widget.tool)) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).agentCopyFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tool = widget.tool;
    final revision = _revision;
    final style = AgentUiStyle.of(context);
    final desktop = SkedMenuStyle.of(context).desktop;
    final target = desktop ? 32.0 : 48.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.subtleSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: AgentSelectableText(
                    tool.name,
                    style: style.caption.copyWith(
                      fontFamily: 'monospace',
                      color: style.muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: ValueKey('agent-activity-copy-${tool.id}'),
                  tooltip: _copied ? l.agentCopied : l.agentCopyActivity,
                  style: style.controlStyle,
                  constraints: BoxConstraints.tightFor(
                    width: target,
                    height: target,
                  ),
                  visualDensity: VisualDensity.standard,
                  padding: EdgeInsets.zero,
                  onPressed: widget.enabled
                      ? () => _copy(tool, revision)
                      : null,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_outlined,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: desktop ? 280 : 320),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                thickness: 4,
                child: SingleChildScrollView(
                  key: ValueKey('agent-activity-detail-${tool.id}'),
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l.agentToolArguments,
                        style: style.caption.copyWith(color: style.muted),
                      ),
                      _ActivityPayload(tool.arguments),
                      const SizedBox(height: 8),
                      Text(
                        l.agentToolResponse,
                        style: style.caption.copyWith(color: style.muted),
                      ),
                      if (tool.result case final result?)
                        _ActivityPayload(result)
                      else
                        Text(
                          agentToolActivityStatusLabel(tool.status, l),
                          style: style.caption,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPayload extends StatelessWidget {
  const _ActivityPayload(this.source);
  final String source;
  @override
  Widget build(BuildContext context) {
    String pretty = source;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(source));
    } on FormatException {
      // Plain text remains readable and copyable.
    }
    final style = AgentUiStyle.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AgentSelectableText(
        pretty.isEmpty
            ? AppLocalizations.of(context).agentActivityEmptyOutput
            : pretty,
        style: style.caption.copyWith(
          fontFamily: 'monospace',
          color: style.foreground,
          height: 1.5,
        ),
      ),
    );
  }
}
