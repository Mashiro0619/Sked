import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import 'agent_setting_labels.dart';
import 'agent_selectable_text.dart';
import 'agent_change_fields.dart';

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
    if (widget.details['kind'] == 'httpTransport') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.agentHttpTransportWarning),
          const SizedBox(height: 8),
          Text(l.agentHttpTransportScope),
          const SizedBox(height: 8),
          Text(l.agentEndpoint, style: Theme.of(context).textTheme.labelLarge),
          AgentSelectableText(widget.details['endpoint'] as String? ?? ''),
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
        ),
        for (final change in changes.take(_shown))
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(_label(change, l)),
            subtitle: Text(
              change['before'] == null
                  ? l.agentKnowledgeAdd
                  : change['after'] == null
                  ? l.delete
                  : l.agentKnowledgeEdit,
            ),
            children: [
              AgentChangeFields(
                change: change,
                references: widget.details['references'] is Map
                    ? widget.details['references'] as Map
                    : const {},
              ),
            ],
          ),
        if (_shown < changes.length)
          TextButton(
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
    return change['label'] as String? ??
        agentSettingLabel(change, l) ??
        change['key'] as String? ??
        '';
  }
}
