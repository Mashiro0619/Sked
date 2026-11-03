import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/runtime/agent_runtime_controller.dart';
import 'package:sked/agent/runtime/conversation_context.dart';
import 'package:sked/models/agent_settings.dart';

void main() {
  test('attachment-only messages bind actual bytes and a failed upload retries without another user message', () async {
    var requests = 0;
    final h = await _Harness.create((request) async {
      final body = jsonDecode(request.body) as Map;
      final inputs = body['input'] as List;
      final user = inputs.lastWhere((message) => message['role'] == 'user');
      expect(user['content'], [
        {'type': 'input_image', 'image_url': 'data:image/png;base64,AP+JUg=='},
      ]);
      if (requests++ == 0) return http.Response('refused', 400);
      return _reply();
    });
    addTearDown(h.dispose);
    await h.files.attach(
      h.id,
      XFile.fromData(
        Uint8List.fromList([0, 255, 137, 82]),
        path: 'photo.png',
        name: 'photo.png',
      ),
      canModify: () => true,
    );
    final attachment = h.conversations.find(h.id)!.attachments.single;
    await h.runtime.send(h.id, '');
    expect(
      h.runtime.state.value.runFor(h.id).errorMessage,
      'provider.httpFailure',
    );
    var conversation = h.conversations.find(h.id)!;
    expect(conversation.status, ConversationStatus.interrupted);
    expect(conversation.draftAttachmentIds, isEmpty);
    expect(
      conversation.messages
          .where((m) => m.role == ConversationRole.user)
          .single
          .attachmentIds,
      [attachment.id],
    );
    expect(
      conversation.messages.first.attachmentDelivery,
      AttachmentDelivery.failed,
    );
    await h.runtime.continueConversation(h.id);
    conversation = h.conversations.find(h.id)!;
    expect(
      conversation.messages.where((m) => m.role == ConversationRole.user),
      hasLength(1),
    );
    expect(
      conversation.messages.first.attachmentDelivery,
      AttachmentDelivery.accepted,
    );
    expect(requests, 2);
    expect(await h.attachments.storage.ids(), {attachment.id});
  });

  test('history keeps file references and explicit reuse includes the original bytes in a later request', () async {
    final sent = <Map>[];
    final h = await _Harness.create((request) async {
      sent.add(jsonDecode(request.body) as Map);
      return _reply();
    });
    addTearDown(h.dispose);
    await h.files.attach(
      h.id,
      XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        path: 'photo.png',
        name: 'photo.png',
      ),
      canModify: () => true,
    );
    final attachment = h.conversations.find(h.id)!.attachments.single;
    await h.runtime.send(h.id, 'first');
    await h.runtime.send(h.id, 'a new request');
    expect(jsonEncode(sent.last), isNot(contains('data:image/png;base64,')));
    expect(
      jsonEncode(sent.last),
      contains('Earlier attachments are not included'),
    );
    await h.files.useAgain(h.id, attachment.id, canModify: () => true);
    await h.runtime.send(h.id, 'read again');
    expect(jsonEncode(sent.last), contains('data:image/png;base64,AQID'));
    final archive = ConversationArchive.decode(h.storage.source!);
    expect(
      archive.conversations.single.messages.where(
        (m) => m.attachmentIds.contains(attachment.id),
      ),
      hasLength(2),
    );
    expect(archive.conversations.single.attachments, hasLength(1));
  });

  test('an empty attachment-only message leaves preparing after service acceptance', () async {
    final h = await _Harness.create((request) async {
      final body = jsonDecode(request.body) as Map;
      final inputs = body['input'] as List;
      expect(inputs.last['content'], [
        {
          'type': 'input_file',
          'filename': 'empty.txt',
          'file_data': 'data:text/plain;base64,',
        },
      ]);
      return _reply();
    });
    addTearDown(h.dispose);
    await h.files.attach(
      h.id,
      XFile.fromData(Uint8List(0), path: 'empty.txt', name: 'empty.txt'),
      canModify: () => true,
    );
    await h.runtime.send(h.id, '');
    final message = h.conversations.find(h.id)!.messages.first;
    expect(message.text, isEmpty);
    expect(message.attachmentDelivery, AttachmentDelivery.accepted);
  });

  test('a missing local file fails before HTTP and continues the same saved input after recovery', () async {
    var requests = 0;
    final h = await _Harness.create((_) async {
      requests++;
      return _reply();
    });
    addTearDown(h.dispose);
    final bytes = Uint8List.fromList([1, 2, 3]);
    await h.files.attach(
      h.id,
      XFile.fromData(bytes, path: 'photo.png', name: 'photo.png'),
      canModify: () => true,
    );
    final attachment = h.conversations.find(h.id)!.attachments.single;
    await h.attachments.storage.delete(attachment.id);
    await h.runtime.send(h.id, '');
    expect(
      h.runtime.state.value.runFor(h.id).errorMessage,
      'provider.attachmentMissing',
    );
    expect(requests, 0);
    final failed = h.conversations.find(h.id)!.messages.single;
    expect(failed.attachmentDelivery, AttachmentDelivery.failed);
    expect(failed.attachmentIds, [attachment.id]);
    await h.attachments.storage.write(attachment.id, Stream.value(bytes));
    await h.runtime.continueConversation(h.id);
    final userMessages = h.conversations
        .find(h.id)!
        .messages
        .where((message) => message.role == ConversationRole.user);
    expect(requests, 1);
    expect(userMessages.single.id, failed.id);
    expect(userMessages.single.attachmentDelivery, AttachmentDelivery.accepted);
  });

  test('reopening an interrupted upload reports unknown and keeps the saved attachment', () async {
    final h = await _Harness.create((_) async => _reply());
    addTearDown(h.dispose);
    await h.files.attach(
      h.id,
      XFile.fromData(
        Uint8List.fromList([1]),
        path: 'photo.png',
        name: 'photo.png',
      ),
      canModify: () => true,
    );
    final attachment = h.conversations.find(h.id)!.attachments.single;
    await h.conversations.update(
      h.id,
      (c) => c.copyWith(
        status: ConversationStatus.running,
        draftAttachmentIds: const [],
        messages: [
          ConversationMessage(
            id: 'pending',
            role: ConversationRole.user,
            text: '',
            createdAt: DateTime.utc(2026),
            attachmentIds: [attachment.id],
            attachmentDelivery: AttachmentDelivery.sending,
          ),
        ],
      ),
    );
    final reopened = ConversationRepository(storage: h.storage);
    await reopened.load();
    expect(
      reopened.find(h.id)!.messages.single.attachmentDelivery,
      AttachmentDelivery.unknown,
    );
    expect(reopened.find(h.id)!.status, ConversationStatus.interrupted);
    expect(await h.attachments.readBytes(attachment), [1]);
    reopened.dispose();
  });

  test('context compression never turns a current request file into a filename-only checkpoint', () {
    final attachment = ProviderAttachment(
      id: 'current',
      filename: 'photo.png',
      mediaType: 'image/png',
      byteLength: 1,
      digest: '0' * 64,
      openRead: () => Stream.value([1]),
    );
    final messages = [
      ProviderMessage(role: ProviderRole.user, text: 'old request'),
      ProviderMessage(
        role: ProviderRole.assistant,
        text: 'old explanation' * 500,
      ),
      ProviderMessage(
        role: ProviderRole.user,
        text: 'current request',
        attachments: [attachment],
      ),
      ProviderMessage(role: ProviderRole.assistant, text: 'latest output'),
    ];
    final bounded = boundConversationContext(
      messages,
      maxMessages: 10,
      maxCharacters: 1600,
    )!;
    expect(bounded.expand((m) => m.attachments).single, same(attachment));
    expect(
      boundConversationContext(messages, maxMessages: 1, maxCharacters: 1600),
      isNull,
    );
  });
}

http.Response _reply() => http.Response(
  jsonEncode({
    'status': 'completed',
    'output': [
      {
        'type': 'message',
        'role': 'assistant',
        'content': [
          {'type': 'output_text', 'text': 'done'},
        ],
      },
    ],
  }),
  200,
  headers: {'content-type': 'application/json'},
);

class _Storage extends ConversationStorage {
  _Storage() : super.base();
  String? source;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String source, {required int revision}) async {
    this.source = source;
  }
}

class _Harness {
  _Harness(
    this.storage,
    this.conversations,
    this.attachments,
    this.files,
    this.client,
    this.provider,
    this.id,
  );
  final _Storage storage;
  final ConversationRepository conversations;
  final AttachmentRepository attachments;
  final ConversationAttachments files;
  final http.Client client;
  final ProviderClient provider;
  final String id;
  late final AgentRuntimeController runtime;
  static Future<_Harness> create(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    final storage = _Storage();
    final conversations = ConversationRepository(storage: storage);
    await conversations.load();
    final id = (await conversations.create(title: 'files')).id;
    final attachments = AttachmentRepository(
      storage: MemoryAttachmentStorage(),
    );
    final files = ConversationAttachments(
      conversations: conversations,
      repository: attachments,
    );
    final client = MockClient(handler);
    final provider = ProviderClient(client: client);
    final h = _Harness(
      storage,
      conversations,
      attachments,
      files,
      client,
      provider,
      id,
    );
    h.runtime = AgentRuntimeController(
      repository: conversations,
      provider: provider,
      attachments: attachments,
      onAttachmentProgress: files.transferProgress,
      readSettings: () => const AgentSettings(
        endpoint: 'https://files.example/v1',
        model: 'fixture',
        protocol: AgentModelProtocol.responses,
        models: [
          AgentModelConfig(
            id: 'fixture',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ),
      readApiKey: (_) async => '',
      readTools: (_) => [],
      executeTool: (_, _, _) async => {},
      onOpenSettings: () {},
    );
    return h;
  }

  Future<void> dispose() async {
    runtime.dispose();
    await runtime.waitForIdle();
    files.dispose();
    await attachments.close();
    conversations.dispose();
    provider.close();
    client.close();
  }
}
