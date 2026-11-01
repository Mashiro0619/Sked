import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sked/agent/attachments/attachment_media_types.dart';
import 'package:sked/agent/provider/provider.dart';

void main() {
  for (final protocol in ProviderProtocol.values) {
    test(
      '${protocol.name} sends actual image and PDF bytes in native content blocks',
      () async {
        final image = Uint8List.fromList([137, 80, 78, 71, 0, 255]);
        final pdf = utf8.encode('%PDF fixture');
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final messages =
              body[protocol == ProviderProtocol.responses
                      ? 'input'
                      : 'messages']
                  as List;
          final content = (messages.single as Map)['content'] as List;
          expect(content.first['text'], 'read');
          final imageValue = protocol == ProviderProtocol.responses
              ? content[1]['image_url']
              : content[1]['image_url']['url'];
          expect(imageValue, 'data:image/png;base64,${base64Encode(image)}');
          final fileValue = protocol == ProviderProtocol.responses
              ? content[2]['file_data']
              : content[2]['file']['file_data'];
          expect(fileValue, 'data:application/pdf;base64,${base64Encode(pdf)}');
          return _reply(protocol);
        });
        final provider = ProviderClient(client: client);
        final result = await provider.collect(
          _request(protocol, [
            _attachment('picture.png', 'image/png', image),
            _attachment('document.pdf', 'application/pdf', pdf),
          ]),
          apiKey: '',
        );
        expect(result.text, 'ok');
        provider.close();
        client.close();
      },
    );
  }
  test(
    'Chat Completions encodes WAV audio with its native input_audio block',
    () async {
      final bytes = utf8.encode('RIFF fixture');
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        final audio = body['messages'][0]['content'][1];
        expect(audio, {
          'type': 'input_audio',
          'input_audio': {'data': base64Encode(bytes), 'format': 'wav'},
        });
        return _reply(ProviderProtocol.chatCompletions);
      });
      final provider = ProviderClient(client: client);
      await provider.collect(
        _request(ProviderProtocol.chatCompletions, [
          _attachment('clip.wav', 'audio/wav', bytes),
        ]),
        apiKey: '',
      );
      provider.close();
      client.close();
    },
  );
  test(
    'empty files still report sending and successful service acceptance',
    () async {
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['input'][0]['content'][1], {
          'type': 'input_file',
          'filename': 'empty.txt',
          'file_data': 'data:text/plain;base64,',
        });
        return _reply(ProviderProtocol.responses);
      });
      final provider = ProviderClient(client: client);
      addTearDown(() {
        provider.close();
        client.close();
      });
      final events = await provider
          .stream(
            _request(ProviderProtocol.responses, [
              _attachment('empty.txt', 'text/plain', const []),
            ]),
            apiKey: '',
          )
          .toList();
      expect(
        events.whereType<ProviderUploadProgress>().map((event) => event.phase),
        [ProviderUploadPhase.sending, ProviderUploadPhase.accepted],
      );
      expect(events.whereType<ProviderCompleted>().single.response.text, 'ok');
    },
  );
  for (final (filename, mediaType, content) in [
    ('calendar.ics', 'text/calendar', 'BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n'),
    ('schedule.tsv', 'text/tsv', '课程\t时间\n数学\t08:00\n'),
    ('schedule.dart', 'text/x-dart', "void main() { print('课表'); }\n"),
  ]) {
    test(
      'Responses sends $filename as a native file while Chat rejects it before reading',
      () async {
        final bytes = utf8.encode(content);
        var calls = 0, reads = 0;
        final client = MockClient((request) async {
          calls++;
          final body = jsonDecode(request.body) as Map;
          expect(body['input'][0]['content'][1], {
            'type': 'input_file',
            'filename': filename,
            'file_data': 'data:$mediaType;base64,${base64Encode(bytes)}',
          });
          return _reply(ProviderProtocol.responses);
        });
        final provider = ProviderClient(client: client);
        addTearDown(() {
          provider.close();
          client.close();
        });
        // Existing local references may predate the extension's MIME mapping.
        final attachment = ProviderAttachment(
          id: filename,
          filename: filename,
          mediaType: 'application/octet-stream',
          byteLength: bytes.length,
          digest: sha256.convert(bytes).toString(),
          openRead: () {
            reads++;
            return Stream.value(bytes);
          },
        );
        expect(attachmentMediaType(filename), mediaType);
        await provider.collect(
          _request(ProviderProtocol.responses, [attachment]),
          apiKey: '',
        );
        await expectLater(
          provider.collect(
            _request(ProviderProtocol.chatCompletions, [attachment]),
            apiKey: '',
          ),
          throwsA(
            isA<ProviderException>().having(
              (error) => error.code,
              'code',
              ProviderError.unsupportedAttachment,
            ),
          ),
        );
        expect(calls, 1);
        expect(reads, 1);
        expect(attachment.mediaType, 'application/octet-stream');
      },
    );
  }
  test(
    'Responses accepts a registered MIME for an unfamiliar extension',
    () async {
      final bytes = utf8.encode('{"course":"math"}\n');
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map;
        expect(body['input'][0]['content'][1], {
          'type': 'input_file',
          'filename': 'export.schooldata',
          'file_data':
              'data:application/x-ndjson;base64,${base64Encode(bytes)}',
        });
        return _reply(ProviderProtocol.responses);
      });
      final provider = ProviderClient(client: client);
      addTearDown(() {
        provider.close();
        client.close();
      });
      await provider.collect(
        _request(ProviderProtocol.responses, [
          _attachment('export.schooldata', 'application/x-ndjson', bytes),
        ]),
        apiKey: '',
      );
    },
  );
  test('unsupported files remain unconsumed and never degrade into filenames or a partial request', () async {
    var calls = 0, reads = 0;
    final client = MockClient((request) async {
      calls++;
      return _reply(ProviderProtocol.responses);
    });
    final provider = ProviderClient(client: client);
    for (final (protocol, filename, media) in [
      (
        ProviderProtocol.chatCompletions,
        'notes.docx',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
      (ProviderProtocol.responses, 'movie.mp4', 'video/mp4'),
      (ProviderProtocol.responses, 'audio.wav', 'audio/wav'),
      (ProviderProtocol.responses, 'unknown.bin', 'application/octet-stream'),
    ]) {
      await expectLater(
        provider.collect(
          _request(protocol, [
            ProviderAttachment(
              id: 'unsupported',
              filename: filename,
              mediaType: media,
              byteLength: 1,
              digest: sha256.convert([1]).toString(),
              openRead: () {
                reads++;
                return Stream.value([1]);
              },
            ),
          ]),
          apiKey: '',
        ),
        throwsA(
          isA<ProviderException>().having(
            (e) => e.code,
            'code',
            ProviderError.unsupportedAttachment,
          ),
        ),
      );
    }
    expect(calls, 0);
    expect(reads, 0);
    provider.close();
    client.close();
  });
  test('binary budget is independent of text and declared over-budget input is rejected before reading', () async {
    var calls = 0, reads = 0;
    final client = MockClient((request) async {
      calls++;
      return _reply(ProviderProtocol.responses);
    });
    final provider = ProviderClient(client: client);
    final bytes = Uint8List(3000);
    await provider.collect(
      _request(
        ProviderProtocol.responses,
        [_attachment('p.png', 'image/png', bytes)],
        limits: const ProviderLimits(
          maxRequestBytes: 512,
          maxAttachmentBytes: 4000,
        ),
      ),
      apiKey: '',
    );
    await expectLater(
      provider.collect(
        _request(
          ProviderProtocol.responses,
          [
            ProviderAttachment(
              id: 'large',
              filename: 'p.png',
              mediaType: 'image/png',
              byteLength: 4001,
              digest: '0' * 64,
              openRead: () {
                reads++;
                return const Stream.empty();
              },
            ),
          ],
          limits: const ProviderLimits(
            maxRequestBytes: 512,
            maxAttachmentBytes: 4000,
          ),
        ),
        apiKey: '',
      ),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.code,
          'code',
          ProviderError.requestBudgetExceeded,
        ),
      ),
    );
    expect(calls, 1);
    expect(reads, 0);
    provider.close();
    client.close();
  });
  test('stop during base64 encoding sends no HTTP request and corrupt bytes cannot reach HTTP', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return _reply(ProviderProtocol.responses);
    });
    final provider = ProviderClient(client: client);
    final cancellation = ProviderCancellationToken();
    final events = provider.stream(
      _request(ProviderProtocol.responses, [
        _attachment('p.png', 'image/png', Uint8List(500000)),
      ]),
      apiKey: '',
      cancellation: cancellation,
    );
    await expectLater(
      events.map((event) {
        if (event is ProviderUploadProgress &&
            event.phase == ProviderUploadPhase.encoding) {
          cancellation.cancel();
        }
        return event;
      }).drain<void>(),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.code,
          'code',
          ProviderError.cancelled,
        ),
      ),
    );
    await expectLater(
      provider.collect(
        _request(ProviderProtocol.responses, [
          ProviderAttachment(
            id: 'changed',
            filename: 'p.png',
            mediaType: 'image/png',
            byteLength: 2,
            digest: sha256.convert([1, 2]).toString(),
            openRead: () => Stream.value([1, 3]),
          ),
        ]),
        apiKey: '',
      ),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.code,
          'code',
          ProviderError.attachmentChanged,
        ),
      ),
    );
    expect(calls, 0);
    provider.close();
    client.close();
  });
}

ProviderAttachment _attachment(String name, String media, List<int> bytes) =>
    ProviderAttachment(
      id: name,
      filename: name,
      mediaType: media,
      byteLength: bytes.length,
      digest: sha256.convert(bytes).toString(),
      openRead: () => Stream.value(bytes),
    );
ProviderRequest _request(
  ProviderProtocol protocol,
  List<ProviderAttachment> attachments, {
  ProviderLimits limits = const ProviderLimits(),
}) => ProviderRequest(
  endpoint: Uri.parse('https://files.example/${protocol.name}'),
  model: 'fixture',
  protocol: protocol,
  limits: limits,
  messages: [
    ProviderMessage(
      role: ProviderRole.user,
      text: 'read',
      attachments: attachments,
    ),
  ],
);
http.Response _reply(ProviderProtocol protocol) => http.Response(
  jsonEncode(
    protocol == ProviderProtocol.responses
        ? {
            'status': 'completed',
            'output': [
              {
                'type': 'message',
                'role': 'assistant',
                'content': [
                  {'type': 'output_text', 'text': 'ok'},
                ],
              },
            ],
          }
        : {
            'choices': [
              {
                'index': 0,
                'message': {'role': 'assistant', 'content': 'ok'},
                'finish_reason': 'stop',
              },
            ],
          },
  ),
  200,
  headers: {'content-type': 'application/json'},
);
