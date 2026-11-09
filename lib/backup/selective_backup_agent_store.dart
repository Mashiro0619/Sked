import 'dart:convert';
import 'dart:typed_data';

import '../agent/attachments/attachment_models.dart';
import '../agent/bridge/generated/api/contracts.dart' as bridge;
import '../agent/bridge/generated/api/models.dart' as native;
import '../agent/bridge/rust_agent_client.dart';
import 'selective_backup_agent_data.dart';
import 'selective_backup_codec.dart';
import 'selective_backup_models.dart';

/// The backup coordinator uses native portable records and durable native
/// restore markers. It never writes the conversation view projection.
class NativeAgentBackupStore {
  NativeAgentBackupStore(this.client);

  final AgentRustClient client;

  Future<Map<String, Object?>> exportParts({
    List<String>? conversationIds,
    List<String>? knowledgeKeys,
  }) => _translate(() async {
    final json = await (await client.core).exportArchiveJson(
      conversationIds: conversationIds,
      knowledgeKeys: knowledgeKeys,
    );
    final value = jsonDecode(json);
    if (value is! Map<String, Object?> ||
        value['schema'] != SelectiveBackupCodec.agentSchema ||
        value['version'] != SelectiveBackupCodec.agentVersion) {
      backupInvalid('Invalid native Agent archive envelope.');
    }
    return {
      'conversations': backupList(value['conversations']),
      'knowledge': backupList(value['knowledge']),
      'attachments': backupList(value['attachments']),
    };
  });

  Future<bool> restored(Map<String, Object?> parts, String restoreId) =>
      _translate(
        () async => (await client.core).archiveRestoreState(
          json: _encode(parts),
          restoreId: restoreId,
        ),
      );

  Future<void> restore(Map<String, Object?> parts, String restoreId) =>
      _translate(
        () async => (await client.core).importArchiveJson(
          json: _encode(parts),
          restoreId: restoreId,
        ),
      );

  Future<Uint8List> readAttachment(ConversationAttachment attachment) =>
      _translate(() async {
        final result = await client.query(
          bridge.AgentQuery(
            kind: bridge.QueryKind.attachmentBytes,
            attachment: native.ViewAttachmentMetadata(
              id: attachment.id,
              name: attachment.name,
              mediaType: attachment.mediaType,
              byteLength: attachment.byteLength,
              sha256: attachment.digest,
              createdAt: 0,
            ),
          ),
        );
        return result.bytes ??
            (throw const SelectiveBackupException(
              SelectiveBackupError.unavailable,
              'The native attachment could not be read.',
            ));
      });

  Future<bool> attachmentExists(Map<String, Object?> metadata) => _translate(
    () async => (await client.core).attachmentRestoreState(
      metadata: _metadata(metadata),
    ),
  );

  Future<void> writeAttachment(
    Map<String, Object?> metadata,
    Uint8List bytes,
  ) => _translate(() async {
    await (await client.core).writeAttachment(
      metadata: _metadata(metadata),
      bytes: bytes,
    );
  });

  native.ViewAttachmentMetadata _metadata(Map<String, Object?> data) {
    final value = nativeBackupAttachment(data);
    return native.ViewAttachmentMetadata(
      id: value.id,
      name: value.name,
      mediaType: value.mediaType,
      byteLength: value.byteLength,
      sha256: value.digest,
      createdAt: data['createdAt'] as int,
    );
  }

  String _encode(Map<String, Object?> parts) => jsonEncode({
    'schema': SelectiveBackupCodec.agentSchema,
    'version': SelectiveBackupCodec.agentVersion,
    ...parts,
  });

  Future<T> _translate<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on SelectiveBackupException {
      rethrow;
    } catch (error) {
      final message = error.toString();
      final code = message.contains('archive_conflict:')
          ? SelectiveBackupError.conflict
          : message.contains('archive_invalid:')
          ? SelectiveBackupError.invalid
          : SelectiveBackupError.unavailable;
      throw SelectiveBackupException(code, message);
    }
  }
}
