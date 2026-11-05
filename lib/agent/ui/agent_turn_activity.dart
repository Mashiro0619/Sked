import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/sked_expressive_theme.dart';
import '../../theme/sked_menu_style.dart';
import 'agent_activity_summary.dart';
import 'agent_conversation_timeline.dart';
import 'agent_selectable_text.dart';

/// Human-readable activity names do not imply permission or a saved outcome.
/// The exact technical tool name remains available inside its detail view.
String agentToolActivityLabel(AgentToolActivity tool, AppLocalizations l) {
  return summarizeAgentToolActivity(tool, l).title;
}

String agentToolActivityStatusLabel(
  AgentToolActivityStatus status,
  AppLocalizations l,
) => switch (status) {
  AgentToolActivityStatus.running => l.agentRunning,
  AgentToolActivityStatus.completed => l.agentActivityCompleted,
  AgentToolActivityStatus.failed => l.agentActivityFailed,
  AgentToolActivityStatus.uncertain => l.agentActivityUncertain,
  AgentToolActivityStatus.notStarted => l.agentActivityNotStarted,
};

IconData _statusIcon(AgentToolActivityStatus status) => switch (status) {
  AgentToolActivityStatus.running => Icons.hourglass_top_rounded,
  AgentToolActivityStatus.completed => Icons.check_rounded,
  AgentToolActivityStatus.failed => Icons.error_outline_rounded,
  AgentToolActivityStatus.uncertain => Icons.pending_outlined,
  AgentToolActivityStatus.notStarted => Icons.remove_rounded,
};

Color _statusColor(AgentToolActivityStatus status, ColorScheme colors) =>
    switch (status) {
      AgentToolActivityStatus.failed => colors.error,
      AgentToolActivityStatus.uncertain => colors.tertiary,
      AgentToolActivityStatus.running => colors.primary,
      _ => colors.onSurfaceVariant,
    };

/// A turn occupies one compact row until the reader asks for its activities.
/// The next level shows a bounded detail surface for one selected tool, rather
/// than expanding all raw arguments and responses into the transcript.
class AgentTurnActivity extends StatefulWidget {
  const AgentTurnActivity({
    super.key,
    required this.activity,
    this.active = true,
    this.interactive = true,
    this.interactionRevision = 0,
  });

  final AgentTimelineActivity activity;
  final bool active;
  final bool interactive;
  final int interactionRevision;

  @override
  State<AgentTurnActivity> createState() => _AgentTurnActivityState();
}

class _AgentTurnActivityState extends State<AgentTurnActivity> {
  bool _expanded = false;
  String? _selectedId;
  String? _copiedId;
  bool _copying = false;
  int _generation = 0;
  final _listScroll = ScrollController();
  final _detailScroll = ScrollController();

  bool get _enabled => widget.active && widget.interactive;

  @override
  void didUpdateWidget(AgentTurnActivity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id ||
        oldWidget.interactionRevision != widget.interactionRevision ||
        (oldWidget.active && !widget.active) ||
        (oldWidget.interactive && !widget.interactive)) {
      _generation++;
      _expanded = false;
      _selectedId = null;
      _copiedId = null;
      _copying = false;
    }
    if (_selectedId != null &&
        !widget.activity.tools.any((tool) => tool.id == _selectedId)) {
      _generation++;
      _selectedId = null;
      _copiedId = null;
      _copying = false;
    }
    final previous = oldWidget.activity.tools
        .where((tool) => tool.id == _selectedId)
        .firstOrNull;
    final current = widget.activity.tools
        .where((tool) => tool.id == _selectedId)
        .firstOrNull;
    if (previous?.arguments != current?.arguments ||
        previous?.result != current?.result) {
      _generation++;
      _copiedId = null;
      _copying = false;
    }
  }

  @override
  void dispose() {
    _listScroll.dispose();
    _detailScroll.dispose();
    super.dispose();
  }

  Future<void> _copy(AgentToolActivity tool) async {
    if (!_enabled || _copying || _selectedId != tool.id) return;
    final generation = _generation;
    final text = _copyText(tool);
    if (!widget.activity.tools.any(
      (current) => current.id == tool.id && _copyText(current) == text,
    )) {
      return;
    }
    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted &&
          _enabled &&
          generation == _generation &&
          _selectedId == tool.id &&
          widget.activity.tools.any(
            (current) => current.id == tool.id && _copyText(current) == text,
          )) {
        setState(() => _copiedId = tool.id);
      }
    } catch (_) {
      if (mounted && _enabled && generation == _generation) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).agentCopyFailed)),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _copying = false);
      }
    }
  }

  String _copyText(AgentToolActivity tool) => [
    tool.name,
    tool.arguments,
    if (tool.result != null) tool.result!,
  ].where((value) => value.isNotEmpty).join('\n\n');

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final desktop = SkedMenuStyle.of(context).desktop;
    final extent = desktop ? 32.0 : 48.0;
    final activity = widget.activity;
    final generation = _generation;
    final status = activity.status;
    final statusLabel = agentToolActivityStatusLabel(status, l);
    final summary =
        '${l.agentActivitySummary(activity.tools.length)} · $statusLabel';
    final selected = activity.tools
        .where((tool) => tool.id == _selectedId)
        .firstOrNull;
    return FocusScope(
      canRequestFocus: _enabled,
      descendantsAreFocusable: _enabled,
      descendantsAreTraversable: _enabled,
      // Retire recognizers when the source changes while keeping the outer
      // transcript identity and its reading anchor stable.
      child: KeyedSubtree(
        key: ValueKey(('agent-activity-controls', generation)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Semantics(
                button: true,
                enabled: _enabled,
                expanded: _expanded,
                label: summary,
                child: Tooltip(
                  message: summary,
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      key: ValueKey('agent-activity-toggle-${activity.id}'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: _enabled
                          ? () {
                              if (!_enabled || generation != _generation) {
                                return;
                              }
                              setState(() {
                                _generation++;
                                _expanded = !_expanded;
                                _selectedId = null;
                                _copiedId = null;
                                _copying = false;
                              });
                            }
                          : null,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: extent),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _statusIcon(status),
                                size: 16,
                                color: _statusColor(status, colors),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  summary,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: _statusColor(status, colors),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _expanded
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
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
            ),
            if (_expanded) ...[
              const SizedBox(height: 4),
              Material(
                color: colors.surfaceContainerLow,
                shape: skedShapeSchemeOf(context).control,
                child: selected == null
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: Scrollbar(
                          controller: _listScroll,
                          child: ListView.builder(
                            key: ValueKey('agent-activity-list-${activity.id}'),
                            controller: _listScroll,
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: activity.tools.length,
                            itemBuilder: (context, index) {
                              final tool = activity.tools[index];
                              final description = summarizeAgentToolActivity(
                                tool,
                                l,
                              );
                              final state = agentToolActivityStatusLabel(
                                tool.status,
                                l,
                              );
                              return ListTile(
                                key: ValueKey('agent-activity-tool-${tool.id}'),
                                dense: desktop,
                                minTileHeight: extent,
                                leading: Icon(
                                  _statusIcon(tool.status),
                                  size: 18,
                                  color: _statusColor(tool.status, colors),
                                ),
                                title: Text(
                                  description.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle:
                                    description.detail != null ||
                                        tool.status ==
                                            AgentToolActivityStatus.failed ||
                                        tool.status ==
                                            AgentToolActivityStatus.uncertain
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (description.detail != null)
                                            Text(
                                              description.detail!,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          if (tool.status ==
                                                  AgentToolActivityStatus
                                                      .failed ||
                                              tool.status ==
                                                  AgentToolActivityStatus
                                                      .uncertain)
                                            Text(
                                              state,
                                              style: theme.textTheme.labelMedium
                                                  ?.copyWith(
                                                    color: _statusColor(
                                                      tool.status,
                                                      colors,
                                                    ),
                                                  ),
                                            ),
                                        ],
                                      )
                                    : null,
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                ),
                                onTap: _enabled
                                    ? () {
                                        if (!_enabled ||
                                            generation != _generation) {
                                          return;
                                        }
                                        setState(() {
                                          _generation++;
                                          _selectedId = tool.id;
                                          _copiedId = null;
                                          _copying = false;
                                        });
                                      }
                                    : null,
                              );
                            },
                          ),
                        ),
                      )
                    : _details(selected, l, extent),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _details(AgentToolActivity tool, AppLocalizations l, double extent) {
    final theme = Theme.of(context);
    final generation = _generation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('agent-activity-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: _enabled
                  ? () {
                      if (!_enabled || generation != _generation) return;
                      setState(() {
                        _generation++;
                        _selectedId = null;
                        _copiedId = null;
                        _copying = false;
                      });
                    }
                  : null,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              constraints: BoxConstraints.tightFor(
                width: extent,
                height: extent,
              ),
            ),
            Expanded(
              child: Text(
                agentToolActivityLabel(tool, l),
                style: theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              key: ValueKey('agent-activity-copy-${tool.id}'),
              tooltip: _copiedId == tool.id
                  ? l.agentCopied
                  : l.agentCopyActivity,
              onPressed: _enabled && !_copying
                  ? () {
                      if (_enabled && generation == _generation) {
                        unawaited(_copy(tool));
                      }
                    }
                  : null,
              constraints: BoxConstraints.tightFor(
                width: extent,
                height: extent,
              ),
              icon: Icon(
                _copiedId == tool.id
                    ? Icons.check_rounded
                    : Icons.copy_outlined,
                size: 18,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: Scrollbar(
            controller: _detailScroll,
            child: SingleChildScrollView(
              key: ValueKey('agent-activity-detail-${tool.id}'),
              controller: _detailScroll,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AgentSelectableText(
                    tool.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.agentToolArguments, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  _ActivityPayload(tool.arguments),
                  const SizedBox(height: 12),
                  Text(l.agentToolResponse, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
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
    final theme = Theme.of(context);
    String pretty = source;
    try {
      pretty = const JsonEncoder.withIndent('  ').convert(jsonDecode(source));
    } on FormatException {
      // Historical plain-text output remains intact and copyable.
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: (constraints.maxWidth - 16).clamp(0.0, double.infinity),
            ),
            child: AgentSelectableText(
              pretty.isEmpty
                  ? AppLocalizations.of(context).agentActivityEmptyOutput
                  : pretty,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
