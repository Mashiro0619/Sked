import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../application/resource_contracts.dart';
import '../../l10n/app_localizations.dart';

/// Host receipts provide the outcome. Assistant prose never sets this card's
/// saved, failed or uncertain state.
class AgentOperationCard extends StatelessWidget {
  const AgentOperationCard({
    super.key,
    required this.receipt,
    this.onUndo,
    this.onOpenResource,
  });

  final Map<String, Object?> receipt;
  final VoidCallback? onUndo;
  final void Function(Map<String, Object?> ref)? onOpenResource;

  static Map<String, Object?>? parse(String text) {
    try {
      final value = jsonDecode(text);
      if (value is Map<String, dynamic> &&
          (value.containsKey('operationId') ||
              value.containsKey('planId') ||
              value.containsKey('error'))) {
        return Map<String, Object?>.from(value);
      }
    } on FormatException {
      // Other tool replies remain readable in their original result view.
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final applied =
        receipt['status'] == 'committed' ||
        receipt['effectStatus'] == 'applied';
    final prepared = receipt.containsKey('planId') && receipt['status'] == null;
    final uncertain =
        receipt['effectStatus'] == 'unknown' ||
        receipt['effectStatus'] == 'pending' ||
        receipt['status'] == 'partial';
    final title = uncertain
        ? l.agentActionUncertain
        : prepared
        ? l.agentPlanReady
        : applied
        ? (receipt['kind'] == 'external'
              ? l.agentActionApplied
              : l.agentChangesSaved)
        : l.agentActionFailed;
    final storedChanges = (receipt['changes'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final namedObjects = storedChanges.any(_isNamedObjectChange);
    final changes = [
      for (final change in storedChanges)
        _presentChange(change, applied: applied, l: l),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card.outlined(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    uncertain
                        ? Icons.pending_outlined
                        : applied
                        ? Icons.check_circle_outline
                        : prepared
                        ? Icons.preview_outlined
                        : Icons.error_outline,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              if (receipt['changeCount'] case final int count) ...[
                const SizedBox(height: 6),
                Text(l.agentChangeCount(count)),
              ],
              if (receipt['notificationEffect'] case final Map effect)
                if (effect['state'] != 'notRequired') ...[
                  const SizedBox(height: 6),
                  Text(l.agentNotificationEffect('${effect['state']}')),
                ],
              for (final change in changes) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(_changeText(change, l))),
                    if (change['ref'] is Map &&
                        change['action'] != 'deleted' &&
                        onOpenResource != null)
                      IconButton(
                        tooltip: l.agentViewObject,
                        icon: const Icon(Icons.open_in_new, size: 20),
                        onPressed: () => onOpenResource!(
                          Map<String, Object?>.from(change['ref'] as Map),
                        ),
                      ),
                  ],
                ),
              ],
              if (receipt['hasMoreChanges'] == true) Text(l.agentMoreChanges),
              if (receipt['stoppedAfterCommit'] == true) Text(l.agentStopped),
              if (applied &&
                  receipt['kind'] != 'external' &&
                  receipt['undoOf'] == null &&
                  onUndo != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: onUndo,
                    icon: const Icon(Icons.undo),
                    label: Text(l.agentUndo),
                  ),
                ),
              if (!namedObjects)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(l.agentPlanDetails),
                  children: [
                    SelectableText(
                      const JsonEncoder.withIndent('  ').convert(receipt),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _changeText(Map change, AppLocalizations l) {
  final label = change['label'] ?? change['key'] ?? '';
  if (change['action'] == 'unconfirmed') return '$label';
  final action = switch (change['action']) {
    'created' => l.agentChangeCreated,
    'deleted' => l.agentChangeDeleted,
    _ => l.agentChangeUpdated,
  };
  return '$action · $label';
}

bool _isNamedObjectChange(Map change) {
  final key = change['key'];
  if (key is! String) return false;
  if (key.startsWith('knowledge.skill:') ||
      key.startsWith('knowledge.memory:')) {
    return true;
  }
  final after = change['after'];
  return key.startsWith('backup.') &&
      after is Map &&
      after['kind'] is String &&
      _objectLabel(after) != null;
}

Map _presentChange(
  Map change, {
  required bool applied,
  required AppLocalizations l,
}) {
  if (!_isNamedObjectChange(change)) {
    if (applied) return change;
    // Standard prepare receipts already contain actions and object references.
    // Those describe the proposal, not a confirmed write or an existing target.
    return {...change, 'action': 'unconfirmed'}..remove('ref');
  }
  final before = change['before'], after = change['after'];
  final key = change['key'] as String;
  final label =
      _objectLabel(after) ??
      _objectLabel(before) ??
      (key.startsWith('knowledge.skill:') ? l.agentSkills : l.agentMemories);
  // A prepared or uncertain target does not prove that the change took effect.
  // Keep these rows neutral and do not link to a restored object yet.
  if (!applied) return {'action': 'unconfirmed', 'label': label};
  // Adding or removing a local override does not create/delete the installed
  // Skill. Its logical identity already exists independently of that record.
  final builtInSkill =
      key.startsWith('knowledge.skill:') &&
      ((after is Map && after['builtIn'] == true) ||
          (before is Map && before['builtIn'] == true));
  final action = builtInSkill
      ? 'updated'
      : before == null
      ? 'created'
      : after == null
      ? 'deleted'
      : 'updated';
  ResourceRef? ref;
  if (key.startsWith('backup.') && after is Map) {
    final kind = switch (after['kind']) {
      'timetable' => ResourceKind.timetable,
      'periodTimeSet' => ResourceKind.periodTimeSet,
      'calendar' => ResourceKind.calendar,
      _ => null,
    };
    final id = after['id'];
    if (kind != null && id is String && id.isNotEmpty) {
      ref = ResourceRef(kind: kind, id: id);
    }
  }
  // Display projections never change the stored receipt or infer write status.
  // Knowledge has no ResourceRef route; its saved name is the visible result.
  return {
    'action': action,
    'label': label,
    if (ref != null) 'ref': ref.toJson(),
  };
}

String? _objectLabel(Object? value) {
  if (value is! Map) return null;
  for (final field in ['label', 'title', 'name']) {
    final label = value[field];
    if (label is String && label.trim().isNotEmpty) return label;
  }
  return null;
}
