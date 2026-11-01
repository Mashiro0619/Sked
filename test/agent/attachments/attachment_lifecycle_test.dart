import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/agent_settings.dart';

import '../../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppRuntime app;
  late _BlobStorage blobs;
  late _ChatStorage chats;
  late List<Map<String, dynamic>> sent;
  setUp(() async {
    blobs = _BlobStorage();
    chats = _ChatStorage();
    sent = [];
    app = await workspaceProvider(
      agentAttachmentStorage: blobs,
      agentConversationStorage: chats,
      agentProvider: ProviderClient(
        client: MockClient((request) async {
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'status': 'completed',
              'output': [
                {
                  'type': 'message',
                  'role': 'assistant',
                  'content': [
                    {'type': 'output_text', 'text': 'Done'},
                  ],
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  });
  tearDown(() async {
    if (blobs.writeGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    await app.agent.quiesce();
    app.dispose();
  });

  Future<String> conversation() async {
    await app.agent.initialize();
    await app.agent.quiesce();
    return (await app.agent.conversations.create(title: 'Attachment')).id;
  }

  Future<void> attach(String id) => app.agent.binaryAttachments.attach(
    id,
    XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      path: 'photo.png',
      name: 'photo.png',
    ),
    canModify: () => true,
  );

  test('default-on startup does not open or read binary storage', () async {
    expect(app.agent.settings.enabled, isTrue);
    expect(blobs.listCalls, 0);
    expect(blobs.readCalls, 0);
    expect(blobs.writeCalls, 0);
    await conversation();
    expect(blobs.readCalls, 0);
    expect(blobs.writeCalls, 0);
    expect(sent, isEmpty);
  });

  test('application runtime sends stored binary and publishes real transport progress', () async {
    await app.agent.configure(
      const AgentSettings(
        endpoint: 'https://fixture.example/v1',
        model: 'fixture',
        protocol: AgentModelProtocol.responses,
      ),
    );
    final id = await conversation();
    await attach(id);
    final progress = <AttachmentDelivery>[];
    void changed() {
      final value = app.agent.binaryAttachments.progressFor(id);
      if (value != null) progress.add(value.delivery);
    }

    app.agent.binaryAttachments.addListener(changed);
    await app.agent.runtime.send(id, '');
    app.agent.binaryAttachments.removeListener(changed);
    expect(jsonEncode(sent.single), contains('data:image/png;base64,AQID'));
    expect(
      progress,
      containsAllInOrder([
        AttachmentDelivery.preparing,
        AttachmentDelivery.sending,
        AttachmentDelivery.accepted,
      ]),
    );
    expect(
      app.agent.conversations.find(id)!.messages.first.attachmentDelivery,
      AttachmentDelivery.accepted,
    );
  });

  test(
    'explicit chat recovery preserves a verified pending attachment for retry',
    () async {
      final id = await conversation();
      chats.failNextSave = true;
      await expectLater(attach(id), throwsStateError);
      expect(app.agent.binaryAttachments.hasPending(id), isTrue);
      final blobId = blobs.values.keys.single;
      await app.agent.recoverConversations();
      await app.agent.binaryAttachments.retry(id, canModify: () => true);
      expect(app.agent.conversations.find(id)!.draftAttachmentIds, [blobId]);
      expect(blobs.values, hasLength(1));
    },
  );

  test(
    'deleting chats collects only the last surviving attachment reference',
    () async {
      final first = await conversation();
      await attach(first);
      final attachment = app.agent.conversations
          .find(first)!
          .attachments
          .single;
      final second = (await app.agent.conversations.create(title: 'Shared')).id;
      await app.agent.conversations.update(
        second,
        (current) => current.copyWith(
          attachments: [attachment],
          draftAttachmentIds: [attachment.id],
        ),
      );
      await app.agent.conversations.delete(first);
      await app.agent.quiesce();
      expect(blobs.values.keys, [attachment.id]);
      await app.agent.conversations.delete(second);
      await app.agent.quiesce();
      expect(blobs.values, isEmpty);
    },
  );

  test('clear drains a cancelled import before removal and prevents late publication', () async {
    final id = await conversation();
    blobs.writeGate = Completer<void>();
    final adding = expectLater(attach(id), throwsA(isA<AttachmentException>()));
    await blobs.writeStarted.future;
    var clearEntered = false;
    final clearing = app.dataClear.run(
      clear: () async {
        clearEntered = true;
        blobs.values.clear();
        chats.source = null;
      },
      exit: () async {},
    );
    expect(app.maintenance.isReserved, isTrue);
    expect(clearEntered, isFalse);
    blobs.writeGate!.complete();
    await adding;
    await clearing;
    expect(clearEntered, isTrue);
    await expectLater(attach(id), throwsA(isA<AttachmentException>()));
    expect(chats.source, isNull);
    expect(blobs.values, isEmpty);
  });

  test('failed clear requires actual archive recovery and forgets old pending publication', () async {
    final id = await conversation();
    chats.failNextSave = true;
    await expectLater(attach(id), throwsStateError);
    expect(app.agent.binaryAttachments.hasPending(id), isTrue);
    await expectLater(
      app.dataClear.run(
        clear: () async {
          blobs.values.clear();
          chats.source = null;
          throw StateError('Synthetic partial clear.');
        },
        exit: () async {},
      ),
      throwsStateError,
    );
    expect(app.agent.binaryAttachments.hasPending(id), isFalse);
    await expectLater(attach(id), throwsA(isA<AttachmentException>()));
    await app.agent.recoverConversations();
    final next = (await app.agent.conversations.create(title: 'Recovered')).id;
    await attach(next);
    expect(app.agent.conversations.find(id), isNull);
    expect(blobs.values, hasLength(1));
  });

  test(
    'final shutdown stops local import before draining accepted writes',
    () async {
      final id = await conversation();
      blobs.writeGate = Completer<void>();
      final adding = expectLater(
        attach(id),
        throwsA(isA<AttachmentException>()),
      );
      await blobs.writeStarted.future;
      final closing = app.shutdown.quiesce();
      blobs.writeGate!.complete();
      await adding;
      await closing;
      expect(app.agent.conversations.find(id)!.attachments, isEmpty);
      await expectLater(attach(id), throwsA(isA<AttachmentException>()));
    },
  );
}

class _ChatStorage extends ConversationStorage {
  _ChatStorage() : super.base();
  String? source;
  bool failNextSave = false;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Synthetic reference save failure.');
    }
    source = value;
  }
}

class _BlobStorage extends MemoryAttachmentStorage {
  int listCalls = 0, readCalls = 0, writeCalls = 0;
  Completer<void>? writeGate;
  final writeStarted = Completer<void>();
  @override
  Future<Set<String>> ids() async {
    listCalls++;
    return super.ids();
  }

  @override
  Stream<List<int>> read(String id) {
    readCalls++;
    return super.read(id);
  }

  @override
  Future<void> write(String id, Stream<List<int>> bytes) async {
    writeCalls++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    await super.write(id, bytes);
  }
}
