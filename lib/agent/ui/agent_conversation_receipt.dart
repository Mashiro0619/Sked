import '../../l10n/app_localizations.dart';

/// Display-only projection of the conversation adapter's stored snapshots.
/// It never resolves a title to an identity or changes the stored receipt.
Map<String, Object?>? presentConversationReceiptChange(
  Map change, {
  required bool applied,
  required AppLocalizations l,
}) {
  final key = change['key'];
  if (!const {
    'conversation.create',
    'conversations.rename',
    'conversations.delete',
    'conversations.archive',
  }.contains(key)) {
    return null;
  }
  final before = _conversation(change['before']);
  final after = _conversation(change['after']);
  final Map record;
  final String action;
  switch (key) {
    case 'conversation.create':
      if (change['before'] != null || after == null) return null;
      record = after;
      action = 'created';
    case 'conversations.delete':
      if (before == null || change['after'] != null) return null;
      record = before;
      action = 'deleted';
    case 'conversations.rename':
    case 'conversations.archive':
      if (before == null || after == null || before['id'] != after['id']) {
        return null;
      }
      record = after;
      if (key == 'conversations.archive') {
        if (after['archived'] is! bool) return null;
        action = after['archived'] == true ? 'archived' : 'restored';
      } else {
        action = 'updated';
      }
    default:
      return null;
  }
  final title = record['title'] as String;
  return {
    'label': title.trim().isEmpty ? l.agentNewConversation : title,
    'action': applied ? action : 'unconfirmed',
    if (applied && action != 'deleted') 'conversationId': record['id'],
  };
}

Map? _conversation(Object? value) =>
    value is Map &&
        value['id'] is String &&
        (value['id'] as String).isNotEmpty &&
        value['title'] is String
    ? value
    : null;
