import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_menu_style.dart';
import '../../theme/sked_surface.dart';
import 'agent_activity_summary.dart';
import 'agent_conversation_timeline.dart';
import 'agent_selectable_text.dart';

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
  AgentToolActivityStatus.corrected => l.agentActivityCorrected,
};

IconData agentActivityStatusIcon(AgentToolActivityStatus status) =>
    switch (status) {
      AgentToolActivityStatus.running => Icons.hourglass_top_rounded,
      AgentToolActivityStatus.completed => Icons.check_rounded,
      AgentToolActivityStatus.failed => Icons.error_outline_rounded,
      AgentToolActivityStatus.uncertain => Icons.pending_outlined,
      AgentToolActivityStatus.notStarted => Icons.remove_rounded,
      AgentToolActivityStatus.corrected => Icons.check_rounded,
    };

Color agentActivityStatusColor(
  AgentToolActivityStatus status,
  ColorScheme colors,
) => switch (status) {
  AgentToolActivityStatus.failed => colors.error,
  AgentToolActivityStatus.uncertain => colors.tertiary,
  AgentToolActivityStatus.running => skedReadableAccent(colors),
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
    this.initiallyExpanded = false,
    this.active = true,
    this.interactive = true,
    this.interactionRevision = 0,
  });
  final String id;
  final String title;
  final String? subtitle;
  final String? statusLabel;
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = widget.active && widget.interactive;
    final extent = SkedMenuStyle.of(context).desktop ? 32.0 : 48.0;
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
        Semantics(
          button: true,
          enabled: enabled,
          expanded: _expanded,
          label: label,
          excludeSemantics: true,
          onTap: enabled ? toggle : null,
          child: KeyedSubtree(
            key: ValueKey(('activity-controls', revision)),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey('agent-activity-toggle-${widget.id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: enabled ? toggle : null,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: extent),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          agentActivityStatusIcon(widget.status),
                          size: 16,
                          color: agentActivityStatusColor(
                            widget.status,
                            colors,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: agentActivityStatusColor(
                                    widget.status,
                                    colors,
                                  ),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.subtitle case final subtitle?)
                                Text(
                                  subtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.chevron_right_rounded,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 24,
              top: 4,
              bottom: 8,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: colors.outlineVariant),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
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
        initiallyExpanded: interaction != null,
        statusLabel: switch (tool.status) {
          AgentToolActivityStatus.failed ||
          AgentToolActivityStatus.uncertain ||
          AgentToolActivityStatus.notStarted ||
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
      statusLabel:
          activity.status == AgentToolActivityStatus.failed ||
              activity.status == AgentToolActivityStatus.uncertain
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
      if (mounted && widget.enabled) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.agentTechnicalDetails,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            IconButton(
              key: ValueKey('agent-activity-copy-${tool.id}'),
              tooltip: _copied ? l.agentCopied : l.agentCopyActivity,
              onPressed: widget.enabled ? () => _copy(tool, revision) : null,
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_outlined,
                size: 18,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(
              key: ValueKey('agent-activity-detail-${tool.id}'),
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AgentSelectableText(tool.name),
                  const SizedBox(height: 8),
                  Text(
                    l.agentToolArguments,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  _ActivityPayload(tool.arguments),
                  const SizedBox(height: 8),
                  Text(
                    l.agentToolResponse,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (tool.result case final result?)
                    _ActivityPayload(result)
                  else
                    Text(agentToolActivityStatusLabel(tool.status, l)),
                ],
              ),
            ),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: AgentSelectableText(
        pretty.isEmpty
            ? AppLocalizations.of(context).agentActivityEmptyOutput
            : pretty,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }
}
