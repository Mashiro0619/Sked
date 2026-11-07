import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sked/agent/provider/provider.dart';

import '../../../test_driver/support/agent_attachment_journey_assessor.dart';

void main() {
  late List<Map<String, Object?>> progress;
  late int bodyByteLength;

  setUpAll(() async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAFklEQVR42mO4Y5PyX6Pp0n8YzUC6AAA4VyexAxAkqQAAAABJRU5ErkJggg==',
    );
    final transport = _AttachmentTransport();
    final provider = ProviderClient(client: transport);
    progress = [];
    try {
      await for (final event in provider.stream(
        ProviderRequest(
          endpoint: Uri.parse('https://fixture.example/v1/chat/completions'),
          model: 'fixture',
          messages: [
            ProviderMessage(
              role: ProviderRole.user,
              attachments: [
                ProviderAttachment(
                  id: 'fixture',
                  filename: 'native-fixture.png',
                  mediaType: 'image/png',
                  byteLength: bytes.length,
                  digest: sha256.convert(bytes).toString(),
                  openRead: () => Stream.fromIterable([
                    bytes.sublist(0, 17),
                    bytes.sublist(17),
                  ]),
                ),
              ],
            ),
          ],
        ),
        apiKey: '',
      )) {
        if (event is ProviderUploadProgress) {
          progress.add({
            'phase': event.phase.name,
            'completedBytes': event.completedBytes,
            'totalBytes': event.totalBytes,
          });
        }
      }
      bodyByteLength = transport.bodyByteLength;
      expect(transport.declaredByteLength, bodyByteLength);
      expect(progress.length, greaterThan(3));
    } finally {
      provider.close();
      transport.close();
    }
  });

  test('accepts actual streamed ProviderClient upload progress', () {
    validateAgentAttachmentUploadProgress(
      progress,
      bodyByteLength: bodyByteLength,
    );
  });

  final mutations = <String, void Function(List<Map<String, Object?>>)>{
    'missing progress': (value) => value.clear(),
    'acceptance without sending': (value) =>
        value.removeRange(0, value.length - 1),
    'missing acceptance': (value) => value.removeLast(),
    'incomplete sending before acceptance': (value) =>
        value.removeAt(value.length - 2),
    'acceptance before sending': (value) => value.insert(0, value.removeLast()),
    'duplicate acceptance': (value) => value.add(Map.of(value.last)),
    'zero initial sending bytes': (value) => value.first['completedBytes'] = 0,
    'backward sending bytes': (value) => value[1]['completedBytes'] = 0,
    'duplicate sending bytes': (value) =>
        value[1]['completedBytes'] = value.first['completedBytes'],
    'sending beyond request length': (value) =>
        value[1]['completedBytes'] = bodyByteLength + 1,
    'different total length': (value) =>
        value.first['totalBytes'] = bodyByteLength + 1,
    'non-integer completed bytes': (value) =>
        value.first['completedBytes'] = '1',
    'obsolete encoding phase': (value) => value.first['phase'] = 'encoding',
    'partial accepted length': (value) =>
        value.last['completedBytes'] = bodyByteLength - 1,
  };
  for (final entry in mutations.entries) {
    test('rejects ${entry.key}', () {
      final changed = progress.map(Map<String, Object?>.of).toList();
      entry.value(changed);
      expect(
        () => validateAgentAttachmentUploadProgress(
          changed,
          bodyByteLength: bodyByteLength,
        ),
        throwsStateError,
      );
    });
  }
}

class _AttachmentTransport extends http.BaseClient {
  var bodyByteLength = 0;
  int? declaredByteLength;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    declaredByteLength = request.contentLength;
    await for (final chunk in request.finalize()) {
      bodyByteLength += chunk.length;
    }
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {'content': 'Done'},
                'finish_reason': 'stop',
              },
            ],
          }),
        ),
      ),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
