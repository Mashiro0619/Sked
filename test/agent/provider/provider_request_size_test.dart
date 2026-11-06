import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/provider/provider_request_encoder.dart';

void main() {
  for (final protocol in ProviderProtocol.values) {
    test(
      '${protocol.name} preflight matches wire bytes without opening attachments',
      () async {
        final bytes = utf8.encode('%PDF synthetic 中文');
        var opens = 0;
        final request = ProviderRequest(
          endpoint: Uri.parse('https://fixture.example/v1'),
          model: 'fixture',
          protocol: protocol,
          messages: [
            ProviderMessage(
              role: ProviderRole.user,
              text: '中文\n"quoted"\\literal',
              attachments: [
                ProviderAttachment(
                  id: 'file',
                  filename: 'report.pdf',
                  mediaType: 'application/pdf',
                  byteLength: bytes.length,
                  digest: sha256.convert(bytes).toString(),
                  openRead: () {
                    opens++;
                    return Stream.value(bytes);
                  },
                ),
              ],
            ),
          ],
          tools: [
            ToolDefinition(
              name: 'events.list',
              description: '描述工具字段',
              parameters: {
                'type': 'object',
                'properties': {
                  'name': {
                    'type': 'string',
                    'enum': ['中文', 'a"b'],
                  },
                },
              },
            ),
          ],
        );
        final size = measureProviderRequestSize(request);
        expect(opens, 0);
        expect(size.attachmentBytes, bytes.length);
        final body = await encodeProviderRequestBody(
          request,
          abortSignal: Completer<void>().future,
          checkCancelled: () {},
        );
        expect(opens, 1);
        expect(body.length, size.textBytes + size.encodedBytes);
        expect(
          size.textBytes,
          greaterThan(utf8.encode('中文\n"quoted"\\literal').length),
        );
      },
    );
  }

  test(
    'oversized declared attachment is rejected without opening its stream',
    () async {
      var opens = 0;
      final request = ProviderRequest(
        endpoint: Uri.parse('https://fixture.example/v1'),
        model: 'fixture',
        limits: const ProviderLimits(maxAttachmentBytes: 10),
        messages: [
          ProviderMessage(
            role: ProviderRole.user,
            attachments: [
              ProviderAttachment(
                id: 'file',
                filename: 'report.pdf',
                mediaType: 'application/pdf',
                byteLength: 11,
                digest: '0' * 64,
                openRead: () {
                  opens++;
                  return const Stream.empty();
                },
              ),
            ],
          ),
        ],
      );
      expect(measureProviderRequestSize(request).attachmentBytes, 11);
      expect(opens, 0);
      await expectLater(
        encodeProviderRequestBody(
          request,
          abortSignal: Completer<void>().future,
          checkCancelled: () {},
        ),
        throwsA(
          isA<ProviderException>().having(
            (error) => error.code,
            'code',
            ProviderError.requestBudgetExceeded,
          ),
        ),
      );
      expect(opens, 0);
    },
  );
}
