import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:material_ui/material_ui.dart';

import '../../application/resource_contracts.dart';
import '../../l10n/app_localizations.dart';
import '../../models/school_site_models.dart' show validSchoolSiteId;
import '../runtime/operation_outcome.dart';
import 'agent_conversation_receipt.dart';
import 'agent_setting_labels.dart';
import 'agent_selectable_text.dart';

/// Host receipts provide the outcome. Assistant prose never sets this card's
/// saved, failed or uncertain state.
class AgentOperationCard extends StatefulWidget {
  const AgentOperationCard({
    super.key,
    required this.receipt,
    this.onUndo,
    this.onOpenResource,
    this.canOpenConversation,
    this.onOpenConversation,
  });

  final Map<String, Object?> receipt;
  final VoidCallback? onUndo;
  final void Function(Map<String, Object?> ref)? onOpenResource;
  final bool Function(String id)? canOpenConversation;
  final ValueChanged<String>? onOpenConversation;

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
  State<AgentOperationCard> createState() => _AgentOperationCardState();
}

class _AgentOperationCardState extends State<AgentOperationCard> {
  bool _showDetails = false;
  Map<String, Object?> get receipt => widget.receipt;

  @override
  void didUpdateWidget(AgentOperationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.receipt['operationId'] ?? oldWidget.receipt['planId']) !=
        (receipt['operationId'] ?? receipt['planId'])) {
      _showDetails = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onUndo = widget.onUndo;
    final onOpenResource = widget.onOpenResource;
    final onOpenConversation = widget.onOpenConversation;
    final canOpenConversation = widget.canOpenConversation;
    final l = AppLocalizations.of(context);
    final applied =
        receipt['status'] == 'committed' ||
        receipt['effectStatus'] == 'applied';
    final prepared = receipt.containsKey('planId') && receipt['status'] == null;
    final uncertain =
        requiresAgentOutcomeReview(receipt) ||
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
    var presentsSchoolSites = false;
    var presentsConversations = false;
    final changes = <Map>[];
    for (final change in storedChanges) {
      final conversation = presentConversationReceiptChange(
        change,
        applied: applied,
        l: l,
      );
      if (conversation != null) {
        presentsConversations = true;
        changes.add(conversation);
        continue;
      }
      final schoolSites = _presentSchoolSites(change, applied: applied, l: l);
      if (schoolSites != null) {
        presentsSchoolSites = true;
        changes.addAll(schoolSites);
      } else {
        changes.add(_presentChange(change, applied: applied, l: l));
      }
    }
    final namedObjects =
        presentsSchoolSites ||
        presentsConversations ||
        storedChanges.any(_isNamedObjectChange);
    final storedChangeCount = receipt['changeCount'];
    final changeCount = presentsSchoolSites
        ? changes.length
        : storedChangeCount is int
        ? storedChangeCount
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card.filled(
        margin: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surfaceContainerLow,
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
                    color: uncertain
                        ? Theme.of(context).colorScheme.tertiary
                        : !applied && !prepared
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (changeCount case final int count)
                          Text(
                            l.agentChangeCount(count),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (receipt['notificationEffect'] case final Map effect)
                if (effect['state'] != 'notRequired') ...[
                  const SizedBox(height: 6),
                  Text(l.agentNotificationEffect('${effect['state']}')),
                ],
              for (final change in changes) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: Text(_changeText(change, l))),
                    if (change['conversationId'] case final String id)
                      if (onOpenConversation != null &&
                          canOpenConversation?.call(id) == true)
                        IconButton(
                          tooltip: l.agentViewObject,
                          icon: const Icon(Icons.open_in_new, size: 20),
                          onPressed: () => onOpenConversation(id),
                        ),
                    if (change['ref'] is Map &&
                        change['action'] != 'deleted' &&
                        onOpenResource != null)
                      IconButton(
                        tooltip: l.agentViewObject,
                        icon: const Icon(Icons.open_in_new, size: 20),
                        onPressed: () => onOpenResource(
                          Map<String, Object?>.from(change['ref'] as Map),
                        ),
                      ),
                  ],
                ),
              ],
              if (receipt['hasMoreChanges'] == true) Text(l.agentMoreChanges),
              if (receipt['stoppedAfterCommit'] == true) Text(l.agentStopped),
              Wrap(
                key: const ValueKey('agent-receipt-actions'),
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (applied &&
                      receipt['kind'] != 'external' &&
                      receipt['undoOf'] == null &&
                      onUndo != null)
                    TextButton.icon(
                      onPressed: onUndo,
                      icon: const Icon(Icons.undo),
                      label: Text(l.agentUndo),
                    ),
                  if (!namedObjects)
                    Semantics(
                      expanded: _showDetails,
                      child: TextButton.icon(
                        key: const ValueKey('agent-receipt-details'),
                        onPressed: () =>
                            setState(() => _showDetails = !_showDetails),
                        icon: Icon(
                          _showDetails ? Icons.expand_less : Icons.expand_more,
                        ),
                        label: Text(l.agentPlanDetails),
                      ),
                    ),
                ],
              ),
              if (!namedObjects && _showDetails)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AgentSelectableText(
                    const JsonEncoder.withIndent('  ').convert(receipt),
                  ),
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
    'archived' => l.agentChangeArchived,
    'restored' => l.agentChangeRestored,
    _ => l.agentChangeUpdated,
  };
  return '$action · $label';
}

List<Map>? _presentSchoolSites(
  Map change, {
  required bool applied,
  required AppLocalizations l,
}) {
  if (change['key'] != 'schoolSites') return null;
  final before = _schoolSitesById(change['before']);
  final after = _schoolSitesById(change['after']);
  // Historical records without unique stable IDs cannot be matched by name
  // or URL. Keep their existing detail view instead of inventing a difference.
  if (before == null || after == null) return null;
  final rows = <Map>[];
  for (final entry in after.entries) {
    final previous = before[entry.key];
    // The owning SchoolSite snapshot contains scalar ID, name and URL fields.
    if (previous != null && mapEquals(previous, entry.value)) continue;
    rows.add({
      'label': entry.value['name'],
      'action': !applied
          ? 'unconfirmed'
          : previous == null
          ? 'created'
          : 'updated',
    });
  }
  for (final entry in before.entries) {
    if (after.containsKey(entry.key)) continue;
    rows.add({
      'label': entry.value['name'],
      'action': applied ? 'deleted' : 'unconfirmed',
    });
  }
  if (rows.isEmpty && !listEquals(before.keys.toList(), after.keys.toList())) {
    rows.add({
      'label': l.schoolSitesPageTitle,
      'action': applied ? 'updated' : 'unconfirmed',
    });
  }
  return rows;
}

Map<String, Map>? _schoolSitesById(Object? value) {
  if (value is! List) return null;
  final sites = <String, Map>{};
  for (final site in value) {
    if (site is! Map) return null;
    final id = site['id'], name = site['name'];
    if (id is! String ||
        !validSchoolSiteId(id) ||
        sites.containsKey(id) ||
        name is! String ||
        name.trim().isEmpty ||
        site['loginUrl'] is! String) {
      return null;
    }
    sites[id] = site;
  }
  return sites;
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
    final label =
        change['label'] ??
        agentSettingLabel(change, l) ??
        _objectLabel(change['after']) ??
        _objectLabel(change['before']);
    final presented = label == null ? change : {...change, 'label': label};
    if (applied) return presented;
    // Standard prepare receipts already contain actions and object references.
    // Those describe the proposal, not a confirmed write or an existing target.
    return {...presented, 'action': 'unconfirmed'}..remove('ref');
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
