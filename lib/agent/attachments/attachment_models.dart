import 'dart:async';

export 'attachment_media_types.dart' show attachmentMediaType;

/// Portable metadata only. An attachment ID never contains an original path.
class ConversationAttachment {
  const ConversationAttachment({
    required this.id,
    required this.name,
    required this.mediaType,
    required this.byteLength,
    required this.digest,
  });

  static const maxFileBytes = 32 * 1000 * 1000;
  static const maxPerMessage = 20;
  final String id;
  final String name;
  final String mediaType;
  final int byteLength;
  final String digest;

  void validate() {
    if (!validAttachmentId(id) ||
        name.isEmpty ||
        name.length > 256 ||
        name.contains(RegExp(r'[\x00-\x1f/\\]')) ||
        !RegExp(r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$')
            .hasMatch(mediaType) ||
        byteLength < 0 ||
        byteLength > maxFileBytes ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const AttachmentException(AttachmentError.invalidMetadata);
    }
  }

  Map<String, Object?> toJson() {
    validate();
    return {
      'id': id,
      'name': name,
      'mediaType': mediaType,
      'byteLength': byteLength,
      'digest': digest,
    };
  }

  factory ConversationAttachment.fromJson(Object? value) {
    if (value is! Map ||
        value.length != 5 ||
        value['id'] is! String ||
        value['name'] is! String ||
        value['mediaType'] is! String ||
        value['byteLength'] is! int ||
        value['digest'] is! String) {
      throw const FormatException('Invalid attachment metadata.');
    }
    final result = ConversationAttachment(
      id: value['id'] as String,
      name: value['name'] as String,
      mediaType: value['mediaType'] as String,
      byteLength: value['byteLength'] as int,
      digest: value['digest'] as String,
    );
    try {
      result.validate();
    } on AttachmentException {
      throw const FormatException('Invalid attachment metadata.');
    }
    return result;
  }
}

bool validAttachmentId(String value) =>
    RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(value);

enum AttachmentError {
  invalidMetadata,
  tooLarge,
  changed,
  missing,
  corrupt,
  cancelled,
  unavailable,
  unsupported,
  conflict,
}

class AttachmentException implements Exception {
  const AttachmentException(this.code);
  final AttachmentError code;
  @override
  String toString() => 'Attachment ${code.name}.';
}

class AttachmentCancellation {
  final _cancelled = Completer<void>();
  bool get isCancelled => _cancelled.isCompleted;
  Future<void> get whenCancelled => _cancelled.future;
  void cancel() {
    if (!isCancelled) _cancelled.complete();
  }

  void check() {
    if (isCancelled) throw const AttachmentException(AttachmentError.cancelled);
  }

  Future<T> guard<T>(Future<T> value) => Future.any([
    value,
    whenCancelled.then<T>(
      (_) => throw const AttachmentException(AttachmentError.cancelled),
    ),
  ]);
}

enum AttachmentDelivery {
  local,
  saving,
  preparing,
  sending,
  accepted,
  failed,
  cancelled,
  unknown,
}

/// Progress concerns local encoding/transport, never the model's reading.
class AttachmentProgress {
  const AttachmentProgress(
    this.delivery, {
    this.completedBytes = 0,
    this.totalBytes = 0,
  });
  final AttachmentDelivery delivery;
  final int completedBytes;
  final int totalBytes;
}
