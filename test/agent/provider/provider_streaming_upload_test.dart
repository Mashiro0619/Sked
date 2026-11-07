import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sked/agent/provider/provider.dart';

void main() {
  test(
    'HTTP consumes a large attachment in chunks without a whole-request buffer',
    () async {
      final chunk = Uint8List(64 * 1024);
      const count = 513;
      final digest = await sha256
          .bind(Stream.fromIterable(List.filled(count, chunk)))
          .first;
      var sourceChunks = 0;
      var maxWireChunk = 0;
      var wireBytes = 0;
      var wireLength = 0;
      final client = _StreamingClient((request) async {
        expect(sourceChunks, 0);
        expect(request, isA<http.Abortable>());
        wireLength = request.contentLength!;
        final iterator = StreamIterator(request.finalize());
        expect(await iterator.moveNext(), isTrue);
        expect(sourceChunks, 0);
        do {
          final bytes = iterator.current;
          wireBytes += bytes.length;
          if (bytes.length > maxWireChunk) maxWireChunk = bytes.length;
        } while (await iterator.moveNext());
        await iterator.cancel();
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
      });
      final provider = ProviderClient(client: client);
      addTearDown(provider.close);
      final request = ProviderRequest(
        endpoint: Uri.parse('https://fixture.example/v1/chat/completions'),
        model: 'fixture',
        messages: [
          ProviderMessage(
            role: ProviderRole.user,
            attachments: [
              ProviderAttachment(
                id: 'large',
                filename: 'large.pdf',
                mediaType: 'application/pdf',
                byteLength: chunk.length * count,
                digest: digest.toString(),
                openRead: () async* {
                  for (var i = 0; i < count; i++) {
                    sourceChunks++;
                    yield chunk;
                  }
                },
              ),
            ],
          ),
        ],
      );
      final progress = <ProviderUploadProgress>[];
      await for (final event in provider.stream(request, apiKey: '')) {
        if (event is ProviderUploadProgress) progress.add(event);
      }
      expect(sourceChunks, count);
      expect(wireBytes, wireLength);
      expect(maxWireChunk, lessThanOrEqualTo(65536));
      expect(progress.last.phase, ProviderUploadPhase.accepted);
      expect(progress.last.completedBytes, wireLength);
    },
  );
}

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
