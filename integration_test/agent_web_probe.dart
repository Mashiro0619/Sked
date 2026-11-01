// A browser acceptance entry point, intentionally not a *_test.dart file.
//
// Build with normal Flutter web plugin registration, then serve the output on
// a dedicated local HTTP/HTTPS origin in a fresh browser profile:
//   flutter build web --release --no-web-resources-cdn \
//     --target integration_test/agent_web_probe.dart
//
// Invoke from a browser test driver:
//   JSON.parse(await window.skedAgentWebProbe(JSON.stringify({
//     operation: 'request', endpoint: 'https://localhost:PORT/cors-allow'
//   })))
//
// The driver supplies local same/cross-origin JSON or SSE endpoints, checks
// server-observed OPTIONS/POST/abort events, and reloads this page between
// seedStorage and readStorage. It must not disable browser web security.
// CORS, mixed-content enforcement and native cancellation are observations of
// the actual browser, not exceptions fabricated by a MockClient.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:http/browser_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/utils/app_storage_keys.dart';
import 'package:web/web.dart' as web;

@JS('skedAgentWebProbe')
external set _probe(JSFunction callback);

const _credentialMarker = 'sked-synthetic-browser-credential';
final _credentials = AgentCredentialStore();
final _conversations = ConversationStorage();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _requireFixtureOrigin(Uri.parse(web.window.location.href));
  _probe = _invoke.toJS;
}

JSPromise<JSString> _invoke(JSString request) =>
    _dispatch(request.toDart).then((value) => jsonEncode(value).toJS).toJS;

Future<Map<String, Object?>> _dispatch(String source) async {
  try {
    final input = jsonDecode(source) as Map<String, dynamic>;
    final FutureOr<Map<String, Object?>> result = switch (input['operation']) {
      'context' => {
        'origin': web.window.location.origin,
        'secureContext': web.window.isSecureContext,
        'credentialStorage': _credentials.kind.name,
        'transport': 'BrowserClient/fetch',
      },
      'request' => _collect(_endpoint(input)),
      'cancelToken' => _cancelToken(_endpoint(input)),
      'cancelSubscription' => _cancelSubscription(_endpoint(input)),
      'seedStorage' => _seedStorage(),
      'readStorage' => _readStorage(),
      'deleteConversation' => _deleteConversation(),
      'corruptSlot' => _corruptSlot(input['slot'] as int),
      'futureSlot' => _futureSlot(),
      'clearStorage' => _clearStorage(),
      'seedAttachments' => _seedAttachments(),
      'readAttachments' => _withAttachments(_attachmentReport),
      'deleteAttachments' => _deleteAttachments(),
      'requestAttachment' => _requestAttachment(_endpoint(input)),
      _ => throw const FormatException('Unknown browser probe operation.'),
    };
    return await result;
  } catch (error) {
    return {'status': 'probeError', 'type': error.runtimeType.toString()};
  }
}

Uri _endpoint(Map<String, dynamic> input) {
  final endpoint = Uri.parse(input['endpoint'] as String);
  _requireFixtureOrigin(endpoint);
  return endpoint;
}

void _requireFixtureOrigin(Uri uri) {
  if (!{
        'localhost',
        '127.0.0.1',
        '::1',
        'sked-insecure.test',
      }.contains(uri.host) ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.userInfo.isNotEmpty) {
    throw const FormatException(
      'Use a dedicated local browser fixture origin.',
    );
  }
}

ProviderRequest _request(Uri endpoint) => ProviderRequest(
  endpoint: endpoint,
  model: 'browser-fixture',
  messages: [
    ProviderMessage(role: ProviderRole.user, text: 'Return browser-ok.'),
  ],
  allowInsecureHttp: true,
  limits: const ProviderLimits(
    totalTimeout: Duration(seconds: 10),
    idleTimeout: Duration(seconds: 5),
    maxOutputTokens: 32,
  ),
);

Future<Map<String, Object?>> _collect(Uri endpoint) async {
  final browser = BrowserClient();
  final provider = ProviderClient(client: browser);
  try {
    final result = await provider.collect(
      _request(endpoint),
      apiKey: _credentialMarker,
    );
    return {'status': 'completed', 'text': result.text};
  } on ProviderException catch (error) {
    return {'status': 'rejected', 'code': error.code.name};
  } finally {
    browser.close();
  }
}

Future<Map<String, Object?>> _cancelToken(Uri endpoint) async {
  final browser = BrowserClient();
  final provider = ProviderClient(client: browser);
  final cancellation = ProviderCancellationToken();
  var sawDelta = false;
  try {
    await for (final event in provider.stream(
      _request(endpoint),
      apiKey: _credentialMarker,
      cancellation: cancellation,
    )) {
      if (event is ProviderTextDelta) {
        sawDelta = true;
        cancellation.cancel();
      }
    }
    return {'status': 'unexpectedCompletion', 'sawDelta': sawDelta};
  } on ProviderException catch (error) {
    return {
      'status': 'rejected',
      'code': error.code.name,
      'sawDelta': sawDelta,
    };
  } finally {
    browser.close();
  }
}

Future<Map<String, Object?>> _cancelSubscription(Uri endpoint) async {
  final browser = BrowserClient();
  final provider = ProviderClient(client: browser);
  final firstDelta = Completer<void>();
  final subscription = provider
      .stream(_request(endpoint), apiKey: _credentialMarker)
      .listen(
        (event) {
          if (event is ProviderTextDelta && !firstDelta.isCompleted) {
            firstDelta.complete();
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!firstDelta.isCompleted) {
            firstDelta.completeError(error, stack);
          }
        },
        onDone: () {
          if (!firstDelta.isCompleted) {
            firstDelta.completeError(
              StateError('Stream ended before the first delta.'),
            );
          }
        },
      );
  try {
    await firstDelta.future.timeout(const Duration(seconds: 5));
    await subscription.cancel();
    return {'status': 'subscriptionCancelled', 'sawDelta': true};
  } finally {
    await subscription.cancel();
    browser.close();
  }
}

String _archive(int revision, {bool deleted = false}) => ConversationArchive(
  revision: revision,
  selectedId: deleted ? null : 'browser-fixture',
  conversations: [
    if (!deleted)
      AgentConversation(
        id: 'browser-fixture',
        title: 'Persistent browser conversation',
        createdAt: DateTime.utc(2026, 10, 30),
        updatedAt: DateTime.utc(2026, 10, 30),
      ),
  ],
  terminatedIds: deleted ? ['browser-fixture'] : const [],
).encode();

Future<Map<String, Object?>> _seedStorage() async {
  for (final slot in AgentCredentialSlot.values) {
    await _credentials.write(slot, _credentialMarker);
  }
  await _conversations.save(_archive(1), revision: 1);
  return _readStorage();
}

Future<Map<String, Object?>> _deleteConversation() async {
  await _conversations.save(_archive(2, deleted: true), revision: 2);
  return _readStorage();
}

Future<Map<String, Object?>> _readStorage() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final slotValues = [
    for (var i = 0; i < 2; i++)
      prefs.getString('$agentConversationsWebStorageKeyPrefix$i'),
  ];
  final result = <String, Object?>{
    'credentialStorage': _credentials.kind.name,
    'activeCredentialPresent':
        await _credentials.read(AgentCredentialSlot.active) != null,
    'pendingCredentialPresent':
        await _credentials.read(AgentCredentialSlot.pending) != null,
    'credentialInLocalStorage': _containsMarker(web.window.localStorage),
    'credentialInSessionStorage': _containsMarker(web.window.sessionStorage),
    'slotsPresent': slotValues.map((value) => value != null).toList(),
    'slotsMatch': slotValues.first == slotValues.last,
    'nativeSlotsMatchPreferences': [
      for (var i = 0; i < 2; i++)
        _decodeLocalPreference(
              'flutter.$agentConversationsWebStorageKeyPrefix$i',
            ) ==
            slotValues[i],
    ],
  };
  try {
    final loaded = await _conversations.load();
    final archive = loaded.source == null
        ? null
        : ConversationArchive.decode(loaded.source!);
    result.addAll({
      'storageStatus': 'loaded',
      'revision': archive?.revision,
      'conversationTitles':
          archive?.conversations.map((c) => c.title).toList() ?? [],
      'terminatedIds': archive?.terminatedIds.toList() ?? [],
      'recovered': loaded.recovered,
    });
  } on ConversationStorageException {
    result['storageStatus'] = 'rejected';
  }
  return result;
}

Object? _decodeLocalPreference(String key) {
  final raw = web.window.localStorage.getItem(key);
  return raw == null ? null : jsonDecode(raw);
}

bool _containsMarker(web.Storage storage) {
  for (var i = 0; i < storage.length; i++) {
    final key = storage.key(i);
    if (key != null &&
        (storage.getItem(key)?.contains(_credentialMarker) ?? false)) {
      return true;
    }
  }
  return false;
}

Future<Map<String, Object?>> _corruptSlot(int slot) async {
  if (slot != 0 && slot != 1) {
    throw const FormatException('Unknown slot.');
  }
  web.window.localStorage.setItem(
    'flutter.$agentConversationsWebStorageKeyPrefix$slot',
    jsonEncode('{damaged fixture slot'),
  );
  return _readStorage();
}

Future<Map<String, Object?>> _futureSlot() async {
  web.window.localStorage.setItem(
    'flutter.${agentConversationsWebStorageKeyPrefix}0',
    jsonEncode(jsonEncode({'version': 2})),
  );
  return _readStorage();
}

Future<Map<String, Object?>> _clearStorage() async {
  final prefs = await SharedPreferences.getInstance();
  for (var i = 0; i < 2; i++) {
    await prefs.remove('$agentConversationsWebStorageKeyPrefix$i');
  }
  for (final slot in AgentCredentialSlot.values) {
    await _credentials.write(slot, null);
  }
  return _readStorage();
}

const _attachmentConversationId = 'browser-attachment-fixture';
const _binaryFixtureName = 'browser-fixture.bin';
const _calendarFixtureName = 'browser-fixture.ics';
const _calendarFixture =
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nBEGIN:VEVENT\r\n'
    'UID:sked-browser-fixture\r\nDTSTART:20261102T080000Z\r\n'
    'DTEND:20261102T090000Z\r\nSUMMARY:Synthetic course\r\n'
    'END:VEVENT\r\nEND:VCALENDAR\r\n';

Uint8List _attachmentFixtureBytes(String name) => switch (name) {
  _binaryFixtureName => Uint8List.fromList(
    List.generate(200000, (index) => (index * 37) % 256),
  ),
  _calendarFixtureName => Uint8List.fromList(utf8.encode(_calendarFixture)),
  _ => throw const FormatException('Unknown attachment fixture.'),
};

Future<Map<String, Object?>> _withAttachments(
  Future<Map<String, Object?>> Function(
    ConversationRepository,
    AttachmentRepository,
    ConversationAttachments,
  )
  action,
) async {
  final conversations = ConversationRepository(storage: _conversations);
  final repository = AttachmentRepository();
  final attachments = ConversationAttachments(
    conversations: conversations,
    repository: repository,
  );
  try {
    await conversations.load();
    return await action(conversations, repository, attachments);
  } finally {
    await attachments.close();
    attachments.dispose();
    conversations.dispose();
  }
}

Future<Map<String, Object?>> _seedAttachments() =>
    _withAttachments((conversations, repository, attachments) async {
      await conversations.create(
        id: _attachmentConversationId,
        title: 'Persistent binary attachment fixture',
      );
      for (final name in [_binaryFixtureName, _calendarFixtureName]) {
        await attachments.attach(
          _attachmentConversationId,
          XFile.fromData(_attachmentFixtureBytes(name), path: name, name: name),
          canModify: () => true,
        );
      }
      await conversations.update(_attachmentConversationId, (current) {
        final binary = current.attachments.singleWhere(
          (attachment) => attachment.name == _binaryFixtureName,
        );
        final calendar = current.attachments.singleWhere(
          (attachment) => attachment.name == _calendarFixtureName,
        );
        return current.copyWith(
          messages: [
            ConversationMessage(
              id: 'browser-attachment-message',
              role: ConversationRole.user,
              text: '',
              createdAt: DateTime.utc(2026, 11, 1),
              attachmentIds: [binary.id],
              attachmentDelivery: AttachmentDelivery.sending,
            ),
          ],
          draftAttachmentIds: [calendar.id],
        );
      });
      return _attachmentReport(conversations, repository, attachments);
    });

Future<Map<String, Object?>> _attachmentReport(
  ConversationRepository conversations,
  AttachmentRepository repository,
  ConversationAttachments _,
) async {
  final conversation = conversations.find(_attachmentConversationId);
  final storedIds = (await repository.storage.ids()).toList()..sort();
  final files = <Map<String, Object?>>[];
  for (final attachment
      in conversation?.attachments ?? const <ConversationAttachment>[]) {
    final bytes = await repository.readBytes(attachment);
    files.add({
      ...attachment.toJson(),
      'actualDigest': sha256.convert(bytes).toString(),
      'fixtureDigest': sha256
          .convert(_attachmentFixtureBytes(attachment.name))
          .toString(),
    });
  }
  final encodedBinary = base64Encode(
    _attachmentFixtureBytes(_binaryFixtureName),
  );
  var binaryInLocalStorage = false;
  for (var index = 0; index < web.window.localStorage.length; index++) {
    final key = web.window.localStorage.key(index);
    if (key != null &&
        (web.window.localStorage.getItem(key)?.contains(encodedBinary) ??
            false)) {
      binaryInLocalStorage = true;
    }
  }
  return {
    'status': conversation == null ? 'missing' : 'loaded',
    'conversationId': conversation?.id,
    'conversationStatus': conversation?.status.name,
    'draftAttachmentIds': conversation?.draftAttachmentIds ?? const [],
    'messageAttachmentIds': [
      for (final message
          in conversation?.messages ?? const <ConversationMessage>[])
        ...message.attachmentIds,
    ],
    'messageDeliveries': [
      for (final message
          in conversation?.messages ?? const <ConversationMessage>[])
        message.attachmentDelivery.name,
    ],
    'files': files,
    'storedIds': storedIds,
    'binaryInLocalStorage': binaryInLocalStorage,
  };
}

Future<Map<String, Object?>> _deleteAttachments() =>
    _withAttachments((conversations, repository, attachments) async {
      if (conversations.find(_attachmentConversationId) != null) {
        await conversations.delete(_attachmentConversationId);
      }
      await attachments.collectGarbage();
      return _attachmentReport(conversations, repository, attachments);
    });

Future<Map<String, Object?>> _requestAttachment(Uri endpoint) =>
    _withAttachments((conversations, repository, _) async {
      final attachment = conversations
          .find(_attachmentConversationId)!
          .attachments
          .singleWhere((attachment) => attachment.name == _calendarFixtureName);
      final browser = BrowserClient();
      final provider = ProviderClient(client: browser);
      try {
        final response = await provider.collect(
          ProviderRequest(
            endpoint: endpoint,
            protocol: ProviderProtocol.responses,
            model: 'browser-file-fixture',
            allowInsecureHttp: true,
            messages: [
              ProviderMessage(
                role: ProviderRole.user,
                text: 'Read the synthetic calendar.',
                attachments: [
                  ProviderAttachment(
                    id: attachment.id,
                    filename: attachment.name,
                    mediaType: attachment.mediaType,
                    byteLength: attachment.byteLength,
                    digest: attachment.digest,
                    openRead: () => repository.read(attachment),
                  ),
                ],
              ),
            ],
            limits: const ProviderLimits(
              totalTimeout: Duration(seconds: 10),
              idleTimeout: Duration(seconds: 5),
              maxOutputTokens: 32,
            ),
          ),
          apiKey: _credentialMarker,
        );
        return {
          'status': 'completed',
          'text': response.text,
          'attachmentId': attachment.id,
          'digest': attachment.digest,
        };
      } finally {
        provider.close();
        browser.close();
      }
    });
