import '../attachments/attachment_models.dart';
import '../bridge/generated/api/file_contracts.dart';
import '../files/file_evidence.dart' show fileResourceJson, fileVersionJson;

enum ConversationToolContentKind { text, native }

class ConversationToolContentRange {
  ConversationToolContentRange({required this.offset, required this.length}) {
    if (offset < 0 || length < 0) {
      throw const FormatException('Invalid tool content range.');
    }
  }

  final int offset;
  final int length;

  Map<String, Object?> toJson() => {'offset': offset, 'length': length};

  factory ConversationToolContentRange.fromJson(Object? value) {
    final data = _object(value, {'offset', 'length'});
    return ConversationToolContentRange(
      offset: _integer(data['offset']),
      length: _integer(data['length']),
    );
  }
}

/// Persistent tool content names a verified private attachment. File bytes and
/// text bodies are resolved by the native runtime when constructing a request.
class ConversationToolContentRef {
  ConversationToolContentRef({
    required this.id,
    required this.attachmentId,
    required this.kind,
    this.sourceSnapshotId,
    this.sourceResource,
    this.sourceVersion,
    this.textRange,
  }) {
    if (id.trim().isEmpty ||
        !validAttachmentId(attachmentId) ||
        sourceSnapshotId?.trim().isEmpty == true ||
        sourceResource?.value.trim().isEmpty == true ||
        sourceVersion?.resourceId.trim().isEmpty == true ||
        sourceVersion?.version.trim().isEmpty == true ||
        (sourceResource == null) != (sourceVersion == null) ||
        sourceResource != null && sourceSnapshotId == null ||
        kind == ConversationToolContentKind.native && textRange != null) {
      throw const FormatException('Invalid tool content reference.');
    }
    if (sourceVersion case final version?) {
      final digest = version.sha256;
      final length = version.byteLength;
      if (digest == null || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(digest)) {
        throw const FormatException('Invalid tool content source digest.');
      }
      if (length == null || length < 0) {
        throw const FormatException('Invalid tool content source length.');
      }
    }
  }

  final String id;
  final String attachmentId;
  final ConversationToolContentKind kind;
  final String? sourceSnapshotId;
  final FileResourceRef? sourceResource;
  final FileVersion? sourceVersion;
  final ConversationToolContentRange? textRange;

  void validateAttachment(ConversationAttachment attachment) {
    if (attachment.id != attachmentId ||
        sourceVersion?.sha256 != null &&
            sourceVersion!.sha256!.toLowerCase() != attachment.digest ||
        sourceVersion?.byteLength != null &&
            sourceVersion!.byteLength != attachment.byteLength) {
      throw const FormatException('Tool content differs from its attachment.');
    }
    if (textRange case final range?) {
      if (range.offset > attachment.byteLength ||
          range.length > attachment.byteLength - range.offset) {
        throw const FormatException(
          'Tool content range exceeds its attachment.',
        );
      }
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'attachmentId': attachmentId,
    'kind': kind.name,
    'sourceSnapshotId': ?sourceSnapshotId,
    if (sourceResource case final source?)
      'sourceResource': fileResourceJson(source),
    if (sourceVersion case final version?)
      'sourceVersion': fileVersionJson(version),
    if (textRange case final range?) 'textRange': range.toJson(),
  };

  factory ConversationToolContentRef.fromJson(Object? value) {
    final data = _object(value, {
      'id',
      'attachmentId',
      'kind',
      'sourceSnapshotId',
      'sourceResource',
      'sourceVersion',
      'textRange',
    });
    final kind = ConversationToolContentKind.values
        .where((kind) => kind.name == data['kind'])
        .firstOrNull;
    if (kind == null) {
      throw const FormatException('Invalid tool content kind.');
    }
    return ConversationToolContentRef(
      id: _text(data['id']),
      attachmentId: _text(data['attachmentId']),
      kind: kind,
      sourceSnapshotId: data['sourceSnapshotId'] == null
          ? null
          : _text(data['sourceSnapshotId']),
      sourceResource: data['sourceResource'] == null
          ? null
          : _sourceResource(data['sourceResource']),
      sourceVersion: data['sourceVersion'] == null
          ? null
          : _sourceVersion(data['sourceVersion']),
      textRange: data['textRange'] == null
          ? null
          : ConversationToolContentRange.fromJson(data['textRange']),
    );
  }
}

Map<String, Object?> _object(Object? value, Set<String> fields) {
  if (value is! Map<String, Object?> ||
      value.keys.any((key) => !fields.contains(key))) {
    throw const FormatException('Invalid tool content object.');
  }
  return value;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid tool content field.');
  }
  return value;
}

int _integer(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid tool content range.');
  }
  return value;
}

FileResourceRef _sourceResource(Object? value) {
  final data = _object(value, {'kind', 'value'});
  final kind = FileResourceKind.values
      .where((kind) => kind.name == data['kind'])
      .firstOrNull;
  if (kind == null) {
    throw const FormatException('Invalid tool content source kind.');
  }
  return FileResourceRef(kind: kind, value: _text(data['value']));
}

FileVersion _sourceVersion(Object? value) {
  final data = _object(value, {
    'resourceId',
    'version',
    'sha256',
    'byteLength',
    'modifiedAtMs',
  });
  final modifiedAt = data['modifiedAtMs'];
  if (modifiedAt != null && modifiedAt is! int) {
    throw const FormatException('Invalid tool content source timestamp.');
  }
  return FileVersion(
    resourceId: _text(data['resourceId']),
    version: _text(data['version']),
    sha256: data['sha256'] == null ? null : _text(data['sha256']),
    byteLength: data['byteLength'] == null
        ? null
        : _integer(data['byteLength']),
    modifiedAtMs: modifiedAt as int?,
  );
}
