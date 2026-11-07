import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/provider/provider_request_encoder.dart';

void main() {
  test('one tool call decodes and freezes its argument object once', () {
    final call = ProviderToolCall(
      id: 'call',
      name: 'events.list',
      arguments: '{"ids":["event"]}',
    );
    final first = call.decodedArguments;
    expect(call.decodedArguments, same(first));
    expect(() => first['ids'] = [], throwsUnsupportedError);
    expect(() => (first['ids'] as List).add('other'), throwsUnsupportedError);
  });

  test('provider values preserve deep JSON as immutable independent data', () {
    Object? nested = {'value': 'complete'};
    for (var index = 0; index < 2048; index++) {
      nested = [nested];
    }
    final source = {'payload': nested};
    final frozen = freezeProviderMap(source);
    source['payload'] = 'changed';
    Object? actual = frozen['payload'];
    for (var index = 0; index < 2048; index++) {
      final level = actual as List;
      expect(() => level.add(null), throwsUnsupportedError);
      actual = level.single;
    }
    expect(actual, {'value': 'complete'});
    expect(() => (actual as Map)['value'] = 'changed', throwsUnsupportedError);
    expect(() => frozen['payload'] = null, throwsUnsupportedError);
  });

  test(
    'request measurement and streaming encode deeply nested tool metadata',
    () async {
      Object? nested = {'type': 'string'};
      for (var index = 0; index < 2048; index++) {
        nested = {'items': nested};
      }
      final request = ProviderRequest(
        endpoint: Uri.parse('https://fixture.example/v1'),
        model: 'fixture',
        protocol: ProviderProtocol.chatCompletions,
        messages: [ProviderMessage(role: ProviderRole.user, text: 'Read')],
        tools: [
          ToolDefinition(
            name: 'synthetic.read',
            description: 'Read',
            parameters: {'type': 'object', 'nested': nested},
          ),
        ],
      );
      final size = measureProviderRequestSize(request);
      final abort = Completer<void>();
      final bytes = <int>[];
      await for (final chunk in encodeProviderRequestBody(
        request,
        abortSignal: abort.future,
        checkCancelled: () {},
      )) {
        bytes.addAll(chunk);
      }
      expect(bytes.length, size.textBytes + size.encodedBytes);
      final body = jsonDecode(utf8.decode(bytes)) as Map;
      Object? current = body['tools'][0]['function']['parameters']['nested'];
      for (var index = 0; index < 2048; index++) {
        current = (current as Map)['items'];
      }
      expect(current, {'type': 'string'});
    },
  );

  test('provider values reject circular, non-JSON and non-finite data', () {
    final cycle = <Object?>[];
    cycle.add(cycle);
    final mapCycle = <String, Object?>{};
    mapCycle['self'] = mapCycle;
    for (final invalid in [
      cycle,
      mapCycle,
      double.infinity,
      double.nan,
      DateTime(2026),
      {1: 'invalid key'},
    ]) {
      expect(
        () => freezeProviderMap({'value': invalid}),
        throwsA(
          isA<ProviderException>().having(
            (error) => error.code,
            'code',
            ProviderError.invalidRequest,
          ),
        ),
      );
    }
    final shared = {'valid': 1};
    expect(freezeProviderMap({'a': shared, 'b': shared}), {
      'a': {'valid': 1},
      'b': {'valid': 1},
    });
  });
}
