import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'attachment_models.dart';
import 'attachment_storage_stub.dart'
    if (dart.library.io) 'attachment_storage_io.dart'
    if (dart.library.js_interop) 'attachment_storage_web.dart';

typedef AttachmentStorageFactory = AttachmentStorage Function();
AttachmentStorageFactory? _factory;
@visibleForTesting
void debugSetAttachmentStorageFactory(AttachmentStorageFactory? factory) =>
    _factory = factory;

/// All reads are bounded chunks. Implementations publish a new immutable blob
/// only after the complete stream has been written and flushed/committed.
abstract class AttachmentStorage {
  factory AttachmentStorage() =>
      _factory?.call() ?? PlatformAttachmentStorage();
  AttachmentStorage.base();
  Future<void> write(String id, Stream<List<int>> bytes);
  Stream<List<int>> read(String id);
  Future<Set<String>> ids();
  Future<void> delete(String id);
  Future<void> close() async {}
}

class MemoryAttachmentStorage extends AttachmentStorage {
  MemoryAttachmentStorage() : super.base();
  final values = <String, Uint8List>{};
  @override
  Future<void> write(String id, Stream<List<int>> bytes) async {
    if (!validAttachmentId(id)) {
      throw const AttachmentException(AttachmentError.invalidMetadata);
    }
    if (values.containsKey(id)) {
      throw const AttachmentException(AttachmentError.conflict);
    }
    final buffer = BytesBuilder(copy: false);
    await for (final chunk in bytes) {
      if (buffer.length + chunk.length > ConversationAttachment.maxFileBytes) {
        throw const AttachmentException(AttachmentError.tooLarge);
      }
      buffer.add(chunk);
    }
    values[id] = buffer.takeBytes();
  }

  @override
  Stream<List<int>> read(String id) async* {
    final data = values[id];
    if (data == null) throw const AttachmentException(AttachmentError.missing);
    for (var offset = 0; offset < data.length; offset += 65536) {
      final end = offset + 65536 < data.length ? offset + 65536 : data.length;
      yield Uint8List.sublistView(data, offset, end);
    }
  }

  @override
  Future<Set<String>> ids() async => values.keys.toSet();
  @override
  Future<void> delete(String id) async {
    values.remove(id);
  }
}
