import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'attachment_models.dart';
import 'attachment_storage.dart';

/// IndexedDB stores native Blob values. Chat JSON and SharedPreferences contain
/// no base64 payload and a browser refresh does not depend on a picker URL.
class PlatformAttachmentStorage extends AttachmentStorage {
  PlatformAttachmentStorage({this.databaseName = 'sked.agent.attachments.v1'})
    : super.base();
  final String databaseName;
  Future<web.IDBDatabase>? _opening;
  bool _closed = false;

  Future<web.IDBDatabase> _database() {
    final pending = _opening;
    if (pending != null) return pending;
    final opening = _open();
    _opening = opening;
    unawaited(
      opening.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {
          if (identical(_opening, opening)) _opening = null;
        },
      ),
    );
    return opening;
  }

  Future<web.IDBDatabase> _open() async {
    if (_closed) throw const AttachmentException(AttachmentError.unavailable);
    final ready = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains('blobs')) {
        database.createObjectStore('blobs');
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (ready.isCompleted || _closed) {
        database.close();
        if (!ready.isCompleted) {
          ready.completeError(
            const AttachmentException(AttachmentError.unavailable),
          );
        }
        return;
      }
      database.onversionchange = ((web.Event _) {
        database.close();
        _opening = null;
      }).toJS;
      ready.complete(database);
    }).toJS;
    void failed(web.Event _) {
      if (!ready.isCompleted) {
        ready.completeError(
          const AttachmentException(AttachmentError.unavailable),
        );
      }
    }

    request.onerror = failed.toJS;
    request.onblocked = failed.toJS;
    return ready.future;
  }

  Future<JSAny?> _request(
    String mode,
    web.IDBRequest Function(web.IDBObjectStore) action,
  ) async {
    if (_closed) throw const AttachmentException(AttachmentError.unavailable);
    final database = await _database();
    if (_closed) throw const AttachmentException(AttachmentError.unavailable);
    final transaction = database.transaction('blobs'.toJS, mode);
    final complete = Completer<void>();
    transaction.oncomplete = ((web.Event _) {
      if (!complete.isCompleted) complete.complete();
    }).toJS;
    void failed(web.Event _) {
      if (!complete.isCompleted) {
        complete.completeError(
          const AttachmentException(AttachmentError.unavailable),
        );
      }
    }

    transaction.onabort = failed.toJS;
    transaction.onerror = failed.toJS;
    final result = Completer<JSAny?>();
    // Attach an error listener before awaiting either side of the transaction.
    final finished = Future.wait<Object?>([
      result.future,
      complete.future.then<Object?>((_) => null),
    ]);
    try {
      final request = action(transaction.objectStore('blobs'));
      request.onsuccess = ((web.Event _) {
        if (!result.isCompleted) result.complete(request.result);
      }).toJS;
      request.onerror = ((web.Event _) {
        if (!result.isCompleted) {
          result.completeError(
            const AttachmentException(AttachmentError.unavailable),
          );
        }
      }).toJS;
    } catch (_) {
      transaction.abort();
      if (!result.isCompleted) {
        result.completeError(
          const AttachmentException(AttachmentError.unavailable),
        );
      }
    }
    return (await finished).first as JSAny?;
  }

  @override
  Future<void> write(String id, Stream<List<int>> bytes) async {
    if (!validAttachmentId(id)) {
      throw const AttachmentException(AttachmentError.invalidMetadata);
    }
    final parts = <web.BlobPart>[];
    var count = 0;
    await for (final chunk in bytes) {
      count += chunk.length;
      if (count > ConversationAttachment.maxFileBytes) {
        throw const AttachmentException(AttachmentError.tooLarge);
      }
      parts.add(Uint8List.fromList(chunk).toJS);
    }
    final blob = web.Blob(
      parts.toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );
    await _request('readwrite', (store) => store.add(blob, id.toJS));
  }

  @override
  Stream<List<int>> read(String id) async* {
    if (!validAttachmentId(id)) {
      throw const AttachmentException(AttachmentError.invalidMetadata);
    }
    final value = await _request('readonly', (store) => store.get(id.toJS));
    if (value == null || value.isUndefined) {
      throw const AttachmentException(AttachmentError.missing);
    }
    if (!value.isA<web.Blob>()) {
      throw const AttachmentException(AttachmentError.corrupt);
    }
    final blob = value as web.Blob;
    if (blob.size > ConversationAttachment.maxFileBytes) {
      throw const AttachmentException(AttachmentError.tooLarge);
    }
    for (var offset = 0; offset < blob.size; offset += 65536) {
      final end = offset + 65536 < blob.size ? offset + 65536 : blob.size;
      yield (await blob.slice(offset, end).arrayBuffer().toDart).toDart
          .asUint8List();
    }
  }

  @override
  Future<Set<String>> ids() async {
    final keys = await _request('readonly', (store) => store.getAllKeys());
    return (keys as JSArray<JSAny?>).toDart.map((key) {
      final id = (key as JSString).toDart;
      if (!validAttachmentId(id)) {
        throw const AttachmentException(AttachmentError.corrupt);
      }
      return id;
    }).toSet();
  }

  @override
  Future<void> delete(String id) async {
    if (!validAttachmentId(id)) {
      throw const AttachmentException(AttachmentError.invalidMetadata);
    }
    await _request('readwrite', (store) => store.delete(id.toJS));
    final remaining = await _request(
      'readonly',
      (store) => store.getKey(id.toJS),
    );
    if (remaining != null && !remaining.isUndefined) {
      throw const AttachmentException(AttachmentError.unavailable);
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    final opening = _opening;
    if (opening != null) {
      try {
        (await opening).close();
      } catch (_) {
        // An unsuccessful open owns no live connection. A late success after
        // close completes that opening with an error and closes it above.
      }
    }
  }
}
