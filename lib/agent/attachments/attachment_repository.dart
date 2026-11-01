import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'attachment_models.dart';
import 'attachment_storage.dart';

export 'attachment_models.dart';
export 'attachment_storage.dart';

/// The conversation archive owns references; this repository owns bytes. A
/// caller must finish put + reference publication before collecting orphans.
class AttachmentRepository {
  AttachmentRepository({AttachmentStorage? storage})
    : storage = storage ?? AttachmentStorage();
  final AttachmentStorage storage;
  Future<void> _tail = Future.value();
  bool _frozen = false;
  bool _closed = false;
  final _active = <AttachmentCancellation>{};
  final _reads = <Completer<void>>{};

  Future<ConversationAttachment> put({
    required String id,
    required String name,
    required String mediaType,
    required int byteLength,
    required Stream<List<int>> Function() openRead,
    AttachmentCancellation? cancellation,
    void Function(int bytes)? onProgress,
  }) => _enqueue(() async {
    _checkWritable();
    if (!validAttachmentId(id) ||
        byteLength < 0 ||
        byteLength > ConversationAttachment.maxFileBytes) {
      throw const AttachmentException(AttachmentError.tooLarge);
    }
    ConversationAttachment(
      id: id,
      name: name,
      mediaType: mediaType,
      byteLength: byteLength,
      digest: '0' * 64,
    ).validate();
    final token = cancellation ?? AttachmentCancellation();
    _active.add(token);
    final digest = _DigestSink();
    final hash = sha256.startChunkedConversion(digest);
    var count = 0;
    Stream<List<int>> bounded() async* {
      final iterator = StreamIterator(openRead());
      try {
        while (await token.guard(iterator.moveNext())) {
          token.check();
          final chunk = iterator.current;
          count += chunk.length;
          if (count > byteLength ||
              count > ConversationAttachment.maxFileBytes) {
            throw const AttachmentException(AttachmentError.changed);
          }
          hash.add(chunk);
          onProgress?.call(count);
          yield chunk;
        }
        token.check();
        if (count != byteLength) {
          throw const AttachmentException(AttachmentError.changed);
        }
        hash.close();
      } finally {
        await iterator.cancel();
      }
    }

    try {
      token.check();
      await storage.write(id, bounded());
      final result = ConversationAttachment(
        id: id,
        name: name,
        mediaType: mediaType,
        byteLength: byteLength,
        digest: digest.value!.toString(),
      );
      result.validate();
      await verify(result, cancellation: token);
      token.check();
      return result;
    } finally {
      _active.remove(token);
    }
  });

  Stream<List<int>> read(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  }) async* {
    attachment.validate();
    if (_closed || _frozen) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
    final token = cancellation ?? AttachmentCancellation();
    token.check();
    final digest = _DigestSink();
    final hash = sha256.startChunkedConversion(digest);
    final iterator = StreamIterator(storage.read(attachment.id));
    final settled = Completer<void>();
    var count = 0;
    _active.add(token);
    _reads.add(settled);
    try {
      while (await token.guard(iterator.moveNext())) {
        token.check();
        final chunk = iterator.current;
        count += chunk.length;
        if (count > attachment.byteLength) {
          throw const AttachmentException(AttachmentError.corrupt);
        }
        hash.add(chunk);
        yield chunk;
      }
      token.check();
      hash.close();
      if (count != attachment.byteLength ||
          digest.value.toString() != attachment.digest) {
        throw const AttachmentException(AttachmentError.corrupt);
      }
    } finally {
      try {
        await iterator.cancel();
      } finally {
        _active.remove(token);
        _reads.remove(settled);
        settled.complete();
      }
    }
  }

  Future<void> verify(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  }) async {
    await for (final _ in read(attachment, cancellation: cancellation)) {}
  }

  Future<Uint8List> readBytes(
    ConversationAttachment attachment, {
    AttachmentCancellation? cancellation,
  }) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in read(attachment, cancellation: cancellation)) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<void> collect(Set<String> references) => _enqueue(() async {
    _checkWritable();
    for (final id in await storage.ids()) {
      if (!references.contains(id)) await storage.delete(id);
    }
  });
  Future<void> freezeAndDrain() async {
    _frozen = true;
    for (final token in _active.toList()) {
      token.cancel();
    }
    await waitForPendingOperations();
  }

  Future<void> waitForPendingOperations() async {
    while (true) {
      final pending = _tail;
      await pending;
      await Future.wait(_reads.map((read) => read.future).toList());
      if (identical(pending, _tail) && _reads.isEmpty) return;
    }
  }

  void resume() {
    if (!_closed) _frozen = false;
  }

  Future<void> clearFrozen() => _enqueue(() async {
    if (!_frozen || _closed) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
    for (final id in await storage.ids()) {
      await storage.delete(id);
    }
    if ((await storage.ids()).isNotEmpty) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
  });
  Future<void> close() async {
    await freezeAndDrain();
    _closed = true;
    await storage.close();
  }

  void _checkWritable() {
    if (_frozen || _closed) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
