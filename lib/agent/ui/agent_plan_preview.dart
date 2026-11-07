import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'agent_setting_labels.dart';
import 'agent_selectable_text.dart';
import 'agent_change_fields.dart';
import 'agent_inline_disclosure_header.dart';
import 'agent_ui_style.dart';

/// Only the host's concrete clear change enables destructive presentation.
bool agentPlanClearsLocalData(Map<String, Object?> details) =>
    (details['changes'] as List? ?? const []).whereType<Map>().any(
      (change) =>
          change['key'] == 'application.localData' &&
          change['before'] is Map &&
          change['after'] == null,
    );

/// Every affected object can be inspected before approval, without eagerly
/// laying out a thousand expanded JSON records on a phone.
class AgentPlanPreview extends StatefulWidget {
  const AgentPlanPreview({super.key, required this.details});
  final Map<String, Object?> details;

  @override
  State<AgentPlanPreview> createState() => _AgentPlanPreviewState();
}

class _AgentPlanPreviewState extends State<AgentPlanPreview> {
  var _shown = 20;

  @override
  void didUpdateWidget(AgentPlanPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.details['planId'] != widget.details['planId']) _shown = 20;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = AgentUiStyle.of(context);
    if (widget.details['kind'] == 'httpTransport') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.agentHttpTransportWarning, style: style.label),
          const SizedBox(height: 8),
          Text(l.agentHttpTransportScope, style: style.label),
          const SizedBox(height: 8),
          Text(l.agentEndpoint, style: style.caption),
          AgentSelectableText(
            widget.details['endpoint'] as String? ?? '',
            style: style.label,
          ),
        ],
      );
    }
    final changes = (widget.details['changes'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (agentPlanClearsLocalData(widget.details)) ...[
          Text(
            l.agentClearDataWarning,
            key: const ValueKey('agent-clear-data-warning'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          l.agentChangeCount(
            widget.details['changeCount'] as int? ?? changes.length,
          ),
          style: style.caption.copyWith(color: style.muted),
        ),
        const SizedBox(height: 4),
        for (final (index, change) in changes.take(_shown).indexed)
          _PlanPreviewChange(
            key: ValueKey('agent-plan-preview-change-$index'),
            identity: (
              widget.details['planId'] ?? widget.details['operationId'],
              change['key'] ?? index,
            ),
            label: _label(change, l),
            action: change['before'] == null
                ? l.agentKnowledgeAdd
                : change['after'] == null
                ? l.delete
                : l.agentKnowledgeEdit,
            change: change,
            references: widget.details['references'] is Map
                ? widget.details['references'] as Map
                : const {},
          ),
        if (_shown < changes.length)
          TextButton(
            style: style.controlStyle,
            onPressed: () => setState(() => _shown += 50),
            child: Text(l.agentShowMoreChanges),
          ),
      ],
    );
  }

  String _label(Map change, AppLocalizations l) {
    for (final value in [change['after'], change['before']]) {
      if (value is! Map) continue;
      final config = value['config'];
      final label =
          value['title'] ??
          value['name'] ??
          (config is Map ? config['name'] : null);
      if (label is String && label.trim().isNotEmpty) return label;
    }
    return agentSettingLabel(change, l) ??
        change['label'] as String? ??
        l.agentPlanDetails;
  }
}

class _PlanPreviewChange extends StatefulWidget {
  const _PlanPreviewChange({
    super.key,
    required this.identity,
    required this.label,
    required this.action,
    required this.change,
    required this.references,
  });

  final Object identity;
  final String label;
  final String action;
  final Map change;
  final Map references;

  @override
  State<_PlanPreviewChange> createState() => _PlanPreviewChangeState();
}

class _PlanPreviewChangeState extends State<_PlanPreviewChange> {
  var _expanded = false;
  var _revision = 0;

  @override
  void didUpdateWidget(_PlanPreviewChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) _expanded = false;
    if (oldWidget.identity != widget.identity ||
        !identical(oldWidget.change, widget.change)) {
      _revision++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = AgentUiStyle.of(context);
    final revision = _revision;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AgentInlineDisclosureHeader(
          title: widget.label,
          subtitle: widget.action,
          titleStyle: style.label,
          maxLines: null,
          expanded: _expanded,
          controlsKey: ValueKey(('preview-controls', revision)),
          leading: Icon(
            widget.change['before'] == null
                ? Icons.add_rounded
                : widget.change['after'] == null
                ? Icons.remove_rounded
                : Icons.edit_note_rounded,
            size: 16,
            color: style.muted,
          ),
          onTap: () {
            if (!mounted || revision != _revision) return;
            setState(() => _expanded = !_expanded);
          },
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(24, 4, 0, 8),
            child: DefaultTextStyle(
              style: style.label,
              child: AgentChangeFields(
                change: widget.change,
                references: widget.references,
              ),
            ),
          ),
      ],
    );
  }
}
