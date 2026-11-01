// Run with flutter test --platform chrome
// test/agent/attachments/attachment_storage_browser_test.dart. This verifies
// real IndexedDB Blob persistence across closed/reopened connections.
@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/attachment_storage_web.dart';

void main() {
  test('closing a pending IndexedDB open settles the operation and closes the connection', () async {
    final name =
        'sked-attachment-close-test-${DateTime.now().microsecondsSinceEpoch}';
    final storage = PlatformAttachmentStorage(databaseName: name);
    addTearDown(() => _deleteDatabase(name));
    addTearDown(storage.close);
    final opening = expectLater(
      storage.ids(),
      throwsA(
        isA<AttachmentException>().having(
          (error) => error.code,
          'code',
          AttachmentError.unavailable,
        ),
      ),
    );
    await storage.close().timeout(const Duration(seconds: 5));
    await opening;
    await expectLater(storage.ids(), throwsA(isA<AttachmentException>()));
  });

  test('IndexedDB preserves native binary Blob bytes after reopen and removes them transactionally', () async {
    final name =
        'sked-attachment-test-${DateTime.now().microsecondsSinceEpoch}';
    addTearDown(() => _deleteDatabase(name));
    final first = AttachmentRepository(
      storage: PlatformAttachmentStorage(databaseName: name),
    );
    addTearDown(first.close);
    final data = Uint8List.fromList(
      List.generate(200000, (i) => (i * 37) % 256),
    );
    final attachment = await first.put(
      id: 'blob-id',
      name: 'binary.pdf',
      mediaType: 'application/pdf',
      byteLength: data.length,
      openRead: () => Stream.value(data),
    );
    await first.close();
    final reopened = AttachmentRepository(
      storage: PlatformAttachmentStorage(databaseName: name),
    );
    addTearDown(reopened.close);
    expect(await reopened.readBytes(attachment), data);
    await reopened.collect({});
    expect(await reopened.storage.ids(), isEmpty);
    await reopened.close();
  });
}

Future<void> _deleteDatabase(String name) async {
  final done = Completer<void>();
  final request = web.window.indexedDB.deleteDatabase(name);
  request.onsuccess = ((web.Event _) {
    done.complete();
  }).toJS;
  request.onerror = ((web.Event _) {
    done.completeError(StateError('delete failed'));
  }).toJS;
  await done.future;
}
