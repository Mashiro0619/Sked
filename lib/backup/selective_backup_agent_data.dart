import '../agent/attachments/attachment_models.dart';
import 'selective_backup_models.dart';

/// The native core owns portable Agent records. Dart adds the identities and
/// dependency edges used by the shared backup selector and ZIP transport.
List<BackupRecord> nativeAgentBackupRecords(Map<String, Object?> parts) {
  final records = <BackupRecord>[];
  for (final raw in backupList(parts['knowledge'])) {
    final data = _record(raw);
    final kind = switch (data['kind']) {
      'skill' => BackupObjectKind.skill,
      'memory' => BackupObjectKind.memory,
      _ => backupInvalid('Invalid native knowledge kind.'),
    };
    records.add(
      BackupRecord(
        key: BackupObjectKey(kind, backupText(data['id'], max: 256)),
        label: backupLabel(data['title']),
        data: data,
      ),
    );
  }
  for (final raw in backupList(parts['conversations'])) {
    final data = _record(raw);
    final conversation = _record(data['conversation']);
    records.add(
      BackupRecord(
        key: BackupObjectKey(
          BackupObjectKind.conversation,
          backupText(conversation['id'], max: 256),
        ),
        label: backupLabel(conversation['title']),
        data: data,
        dependencies: [
          for (final attachment in backupList(data['attachments']))
            BackupObjectKey(
              BackupObjectKind.attachment,
              backupText(_record(attachment)['id'], max: 256),
            ),
        ],
      ),
    );
  }
  for (final raw in backupList(parts['attachments'])) {
    final data = _record(raw);
    final attachment = nativeBackupAttachment(data);
    records.add(
      BackupRecord(
        key: BackupObjectKey(BackupObjectKind.attachment, attachment.id),
        label: attachment.name,
        data: data,
      ),
    );
  }
  return records;
}

/// Selective transport retains native payloads without projecting through the
/// conversation UI model or rebuilding the native storage schema in Dart.
Map<String, Object?> nativeArchiveParts(Iterable<BackupRecord> records) {
  final conversations = <Map<String, Object?>>[];
  final knowledge = <Map<String, Object?>>[];
  final attachments = <String, Map<String, Object?>>{};
  void addAttachment(Map<String, Object?> metadata) {
    final id = nativeBackupAttachment(metadata).id;
    final previous = attachments[id];
    if (previous != null &&
        canonicalBackupJson(previous) != canonicalBackupJson(metadata)) {
      backupInvalid('Shared native attachment metadata conflicts.');
    }
    attachments[id] = metadata;
  }

  for (final record in records) {
    switch (record.key.kind) {
      case BackupObjectKind.conversation:
        conversations.add(record.data);
        for (final metadata in backupList(record.data['attachments'])) {
          addAttachment(_record(metadata));
        }
      case BackupObjectKind.skill:
      case BackupObjectKind.memory:
        knowledge.add(record.data);
      case BackupObjectKind.attachment:
        addAttachment(record.data);
      default:
        backupInvalid('A business object cannot enter the Agent archive.');
    }
  }
  return {
    'conversations': conversations,
    'knowledge': knowledge,
    'attachments': attachments.values.toList(),
  };
}

/// Binary staging shares the application's attachment transport interface;
/// its local metadata object is independent of the portable archive encoding.
ConversationAttachment nativeBackupAttachment(Map<String, Object?> data) {
  final digest = backupText(data['sha256'], max: 64);
  if (!backupDigestIsValid(digest)) {
    backupInvalid('Invalid native attachment digest.');
  }
  final createdAt = data['createdAt'];
  if (createdAt is! int) {
    backupInvalid('Invalid native attachment timestamp.');
  }
  final attachment = ConversationAttachment(
    id: backupText(data['id'], max: 256),
    name: backupText(data['name']),
    mediaType: backupText(data['mediaType']),
    byteLength: backupInteger(data['byteLength']),
    digest: digest,
  );
  attachment.validate();
  return attachment;
}

Map<String, Object?> _record(Object? value) {
  if (value is! Map<String, Object?>) {
    backupInvalid('Invalid native Agent record.');
  }
  return value;
}
