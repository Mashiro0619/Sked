import 'dart:convert';

import 'package:material_ui/material_ui.dart';

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
    final changes = (receipt['changes'] as List? ?? const [])
        .whereType<Map>()
        .toList();
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
                    Expanded(
                      child: Text(
                        '${switch (change['action']) {
                          'created' => l.agentChangeCreated,
                          'deleted' => l.agentChangeDeleted,
                          _ => l.agentChangeUpdated,
                        }} · ${change['label'] ?? change['key'] ?? ''}',
                      ),
                    ),
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
