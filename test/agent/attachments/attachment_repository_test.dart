import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/attachment_storage_io.dart' as native;
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/services/app_storage_layout_io.dart';

void main() {
  test('native bytes are private, verified after reopen, and do not use the display filename', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-binary-attachment-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final layout = AppStorageLayout(directoryProvider: () async => directory);
    final repository = AttachmentRepository(
      storage: native.PlatformAttachmentStorage(layout: layout),
    );
    final bytes = Uint8List.fromList(List.generate(150000, (i) => i % 256));
    final attachment = await repository.put(
      id: 'fixed-id',
      name: '私有图片.png',
      mediaType: 'image/png',
      byteLength: bytes.length,
      openRead: () => Stream.value(bytes),
    );
    await repository.close();
    final reopened = AttachmentRepository(
      storage: native.PlatformAttachmentStorage(layout: layout),
    );
    expect(await reopened.readBytes(attachment), bytes);
    expect(
      await File('${directory.path}/Sked_agent_attachments/fixed-id.bin')
          .exists(),
      isTrue,
    );
    expect(await File('${directory.path}/私有图片.png').exists(), isFalse);
    await reopened.collect({});
    expect(await reopened.storage.ids(), isEmpty);
    await reopened.close();
  });

  test('native collection and clear remove interrupted pending files without deleting referenced bytes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sked-pending-attachment-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = AttachmentRepository(
      storage: native.PlatformAttachmentStorage(
        layout: AppStorageLayout(directoryProvider: () async => directory),
      ),
    );
    addTearDown(repository.close);
    final attachment = await repository.put(
      id: 'kept',
      name: 'kept.pdf',
      mediaType: 'application/pdf',
      byteLength: 3,
      openRead: () => Stream.value([1, 2, 3]),
    );
    final pending = File(
      '${directory.path}/Sked_agent_attachments/interrupted.bin.pending',
    );
    await pending.writeAsBytes([4, 5], flush: true);
    expect(await repository.storage.ids(), {'kept', 'interrupted'});
    await repository.collect({attachment.id});
    expect(await pending.exists(), isFalse);
    expect(await repository.readBytes(attachment), [1, 2, 3]);

    await pending.writeAsBytes([6], flush: true);
    await repository.freezeAndDrain();
    await repository.clearFrozen();
    expect(await repository.storage.ids(), isEmpty);
    expect(await pending.exists(), isFalse);
  });

  test('imported binaries survive archive reload without embedding bytes or source paths', () async {
    final storage = _ConversationMemory();
    final conversations = ConversationRepository(storage: storage);
    await conversations.load();
    final id = (await conversations.create(title: 'binary')).id;
    final blobs = MemoryAttachmentStorage();
    final repository = AttachmentRepository(storage: blobs);
    final files = ConversationAttachments(
      conversations: conversations,
      repository: repository,
    );
    final bytes = Uint8List.fromList([0, 255, 137, 50, 0, 12]);
    await files.attach(
      id,
      XFile.fromData(
        bytes,
        path: 'arbitrary.unknown',
        name: 'arbitrary.unknown',
      ),
      canModify: () => true,
    );
    final before = conversations.find(id)!;
    expect(before.attachments.single.mediaType, 'application/octet-stream');
    expect(before.draftAttachmentIds, [before.attachments.single.id]);
    expect(storage.source, isNot(contains('file_data')));
    expect(storage.source, isNot(contains('base64')));
    expect(storage.source, isNot(contains('file://')));
    final reloaded = ConversationRepository(storage: storage);
    await reloaded.load();
    expect(
      await repository.readBytes(reloaded.find(id)!.attachments.single),
      bytes,
    );
    files.dispose();
    conversations.dispose();
    reloaded.dispose();
    await repository.close();
  });

  test('failed reference publication retries the same verified binary without duplicates', () async {
    final storage = _ConversationMemory();
    final conversations = ConversationRepository(storage: storage);
    await conversations.load();
    final id = (await conversations.create(title: 'retry')).id;
    final blobs = MemoryAttachmentStorage();
    final repository = AttachmentRepository(storage: blobs);
    final files = ConversationAttachments(
      conversations: conversations,
      repository: repository,
    );
    storage.fail = true;
    await expectLater(
      files.attach(
        id,
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          path: 'photo.png',
          name: 'photo.png',
        ),
        canModify: () => true,
      ),
      throwsStateError,
    );
    expect(files.hasPending(id), isTrue);
    expect(blobs.values, hasLength(1));
    expect(files.progressFor(id)?.delivery, AttachmentDelivery.failed);
    await conversations.load();
    await files.retry(id, canModify: () => true);
    expect(files.hasPending(id), isFalse);
    expect(conversations.find(id)!.attachments, hasLength(1));
    expect(blobs.values, hasLength(1));
    expect(files.progressFor(id)?.delivery, AttachmentDelivery.local);
    expect(files.isImporting(id), isFalse);
    files.dispose();
    conversations.dispose();
    await repository.close();
  });

  test('removing a draft reference preserves a file used by history until its last reference is gone', () async {
    final conversations = ConversationRepository(
      storage: _ConversationMemory(),
    );
    await conversations.load();
    final id = (await conversations.create(title: 'references')).id;
    final repository = AttachmentRepository(storage: MemoryAttachmentStorage());
    final files = ConversationAttachments(
      conversations: conversations,
      repository: repository,
    );
    await files.attach(
      id,
      XFile.fromData(
        Uint8List.fromList([1]),
        path: 'photo.png',
        name: 'photo.png',
      ),
      canModify: () => true,
    );
    final attachment = conversations.find(id)!.attachments.single;
    await conversations.update(
      id,
      (c) => c.copyWith(
        messages: [
          ConversationMessage(
            id: 'message',
            role: ConversationRole.user,
            text: '',
            createdAt: DateTime.utc(2026),
            attachmentIds: [attachment.id],
          ),
        ],
        draftAttachmentIds: const [],
      ),
    );
    await files.useAgain(id, attachment.id, canModify: () => true);
    await files.remove(id, attachment.id, canModify: () => true);
    expect(await repository.storage.ids(), {attachment.id});
    await conversations.delete(id);
    await files.collectGarbage();
    expect(await repository.storage.ids(), isEmpty);
    files.dispose();
    conversations.dispose();
    await repository.close();
  });

  test('cancellation interrupts a stalled local read and cannot publish partial bytes', () async {
    final repository = AttachmentRepository(storage: MemoryAttachmentStorage());
    final token = AttachmentCancellation();
    final entered = Completer<void>();
    final controller = StreamController<List<int>>(onListen: entered.complete);
    final put = repository.put(
      id: 'cancelled',
      name: 'file.pdf',
      mediaType: 'application/pdf',
      byteLength: 3,
      openRead: () => controller.stream,
      cancellation: token,
    );
    final rejected = expectLater(
      put,
      throwsA(
        isA<AttachmentException>().having(
          (e) => e.code,
          'code',
          AttachmentError.cancelled,
        ),
      ),
    );
    await entered.future;
    token.cancel();
    await rejected;
    expect(await repository.storage.ids(), isEmpty);
    await controller.close();
    await repository.close();
  });

  test('cancel during final verification keeps bytes pending without publishing the reference', () async {
    final conversations = ConversationRepository(
      storage: _ConversationMemory(),
    );
    await conversations.load();
    final id = (await conversations.create(title: 'Cancel verification')).id;
    final storage = _PausingReadStorage(pauseAt: 2);
    final repository = AttachmentRepository(storage: storage);
    final files = ConversationAttachments(
      conversations: conversations,
      repository: repository,
    );
    addTearDown(() async {
      files.dispose();
      await repository.close();
      await storage.paused.close();
      conversations.dispose();
    });
    final adding = expectLater(
      files.attach(
        id,
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          path: 'photo.png',
          name: 'photo.png',
        ),
        canModify: () => true,
      ),
      throwsA(
        isA<AttachmentException>().having(
          (error) => error.code,
          'code',
          AttachmentError.cancelled,
        ),
      ),
    );
    await storage.readStarted.future;
    files.cancelImport(id);
    await adding.timeout(const Duration(seconds: 5));
    expect(conversations.find(id)!.attachments, isEmpty);
    expect(conversations.find(id)!.draftAttachmentIds, isEmpty);
    expect(files.hasPending(id), isTrue);
    final blobId = storage.values.keys.single;

    await files.retry(id, canModify: () => true);
    expect(conversations.find(id)!.draftAttachmentIds, [blobId]);
    expect(storage.values, hasLength(1));
  });

  test('retry verification is cancellable and a later retry publishes the same stored file', () async {
    final chats = _ConversationMemory();
    final conversations = ConversationRepository(storage: chats);
    await conversations.load();
    final id = (await conversations.create(title: 'Cancel retry')).id;
    final storage = _PausingReadStorage(pauseAt: 3);
    final repository = AttachmentRepository(storage: storage);
    final files = ConversationAttachments(
      conversations: conversations,
      repository: repository,
    );
    addTearDown(() async {
      files.dispose();
      await repository.close();
      await storage.paused.close();
      conversations.dispose();
    });
    chats.fail = true;
    await expectLater(
      files.attach(
        id,
        XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          path: 'photo.png',
          name: 'photo.png',
        ),
        canModify: () => true,
      ),
      throwsStateError,
    );
    await conversations.load();
    final blobId = storage.values.keys.single;
    final retry = expectLater(
      files.retry(id, canModify: () => true),
      throwsA(
        isA<AttachmentException>().having(
          (error) => error.code,
          'code',
          AttachmentError.cancelled,
        ),
      ),
    );
    await storage.readStarted.future;
    expect(files.isImporting(id), isTrue);
    expect(files.progressFor(id)?.delivery, AttachmentDelivery.saving);
    files.cancelImport(id);
    await retry.timeout(const Duration(seconds: 5));
    expect(conversations.find(id)!.attachments, isEmpty);
    expect(files.hasPending(id), isTrue);
    expect(files.isImporting(id), isFalse);
    expect(files.progressFor(id)?.delivery, AttachmentDelivery.cancelled);

    await files.retry(id, canModify: () => true);
    expect(conversations.find(id)!.draftAttachmentIds, [blobId]);
    expect(storage.values, hasLength(1));
    expect(files.hasPending(id), isFalse);
    expect(files.isImporting(id), isFalse);
    expect(files.progressFor(id)?.delivery, AttachmentDelivery.local);
  });

  test(
    'a cancelled verification does not open even an empty stored file',
    () async {
      final storage = _PausingReadStorage(pauseAt: 3);
      final repository = AttachmentRepository(storage: storage);
      addTearDown(repository.close);
      final attachment = await repository.put(
        id: 'empty',
        name: 'empty.txt',
        mediaType: 'text/plain',
        byteLength: 0,
        openRead: () => const Stream.empty(),
      );
      final reads = storage.reads;
      final cancellation = AttachmentCancellation()..cancel();
      await expectLater(
        repository.verify(attachment, cancellation: cancellation),
        throwsA(
          isA<AttachmentException>().having(
            (error) => error.code,
            'code',
            AttachmentError.cancelled,
          ),
        ),
      );
      expect(storage.reads, reads);
    },
  );

  test('freeze cancels a pending history verification before draining its service action', () async {
    final conversations = ConversationRepository(
      storage: _ConversationMemory(),
    );
    await conversations.load();
    final id = (await conversations.create(title: 'Freeze verification')).id;
    final storage = _PausingReadStorage(pauseAt: 3);
    final repository = AttachmentRepository(storage: storage);
    final files = ConversationAttachments(
      conversations: conversations,
      repository: repository,
    );
    addTearDown(() async {
      files.dispose();
      await repository.close();
      await storage.paused.close();
      conversations.dispose();
    });
    await files.attach(
      id,
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        path: 'photo.png',
        name: 'photo.png',
      ),
      canModify: () => true,
    );
    final attachmentId = conversations.find(id)!.attachments.single.id;
    final reusing = expectLater(
      files.useAgain(id, attachmentId, canModify: () => true),
      throwsA(
        isA<AttachmentException>().having(
          (error) => error.code,
          'code',
          AttachmentError.cancelled,
        ),
      ),
    );
    await storage.readStarted.future;
    await files.freezeAndDrain().timeout(const Duration(seconds: 5));
    await reusing;
    expect(conversations.find(id)!.draftAttachmentIds, [attachmentId]);
    expect(storage.values.keys, [attachmentId]);
    files.resume();
    await files.useAgain(id, attachmentId, canModify: () => true);
    expect(conversations.find(id)!.draftAttachmentIds, [attachmentId]);
  });

  test('oversized declarations fail before reading and corrupt content never verifies', () async {
    final storage = MemoryAttachmentStorage();
    final repository = AttachmentRepository(storage: storage);
    var opened = false;
    await expectLater(
      repository.put(
        id: 'large',
        name: 'large.bin',
        mediaType: 'application/octet-stream',
        byteLength: ConversationAttachment.maxFileBytes + 1,
        openRead: () {
          opened = true;
          return const Stream.empty();
        },
      ),
      throwsA(isA<AttachmentException>()),
    );
    expect(opened, isFalse);
    final attachment = await repository.put(
      id: 'changed',
      name: 'file.png',
      mediaType: 'image/png',
      byteLength: 2,
      openRead: () => Stream.value([1, 2]),
    );
    storage.values[attachment.id] = Uint8List.fromList([1, 3]);
    await expectLater(
      repository.verify(attachment),
      throwsA(isA<AttachmentException>()),
    );
    await repository.close();
  });
}

class _ConversationMemory extends ConversationStorage {
  _ConversationMemory() : super.base();
  String? source;
  bool fail = false;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String source, {required int revision}) async {
    if (fail) {
      fail = false;
      throw StateError('injected write failure');
    }
    this.source = source;
  }
}

class _PausingReadStorage extends MemoryAttachmentStorage {
  _PausingReadStorage({required this.pauseAt});
  final int pauseAt;
  int reads = 0;
  final readStarted = Completer<void>();
  late final paused = StreamController<List<int>>(
    onListen: () => readStarted.complete(),
  );

  @override
  Stream<List<int>> read(String id) {
    reads++;
    return reads == pauseAt ? paused.stream : super.read(id);
  }
}
