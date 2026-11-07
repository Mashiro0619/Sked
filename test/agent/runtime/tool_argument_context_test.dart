import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/runtime/tool_argument_context.dart';

void main() {
  for (final fixture in <String, Object?>{
    r'{"api\u005fkey":"x",': {'api_key': 'x'},
    '{"credentials":{"value":"x"},': {
      'credentials': {'value': 'x'},
    },
    '{"credentials":[{"value":"x"},': {
      'credentials': [
        {'value': 'x'},
      ],
    },
    r'{"title":"sk\u002druntime-fixture-key': {
      'title': 'sk-runtime-fixture-key',
    },
    r'{"api\u005fkey":"\u0078': {'api_key': 'x'},
    r'{"value":"\u0078",': {'value': 'x'},
    r'{"headers":[{"name":"api\u005fkey","value":"x"}],': {
      'headers': [
        {'name': 'api_key', 'value': 'x'},
      ],
    },
    r'{"credentials":"\uD83D\uDD11': {'credentials': '🔑'},
    r'{"api_key" "x"': {'api_key': 'x'},
    r'{"api_key":x': {'api_key': 'x'},
  }.entries) {
    test('retains decoded JSON prefix ${fixture.key}', () {
      expect(toolArgumentCredentialContext(fixture.key), [fixture.value]);
    });
  }

  test('duplicate field snapshots retain earlier name/value associations', () {
    final result =
        toolArgumentCredentialContext(
              r'{"name":"api_key","value":"x","name":"normal",',
            ).single
            as Map;
    expect(result['name'], 'normal');
    expect(result['value'], 'x');
    expect(result['__partial_json_fragments'], [
      {'name': 'api_key', 'value': 'x'},
    ]);
  });

  test('ordinary string contents are decoded once and never treated as nested JSON', () {
    final result =
        toolArgumentCredentialContext(r'{"notes":"{\"api\\u005fkey\":\"x\"}",')
                .single
            as Map;
    expect(result['notes'], r'{"api\u005fkey":"x"}');
  });

  test('incomplete escapes remain incomplete values', () {
    final slash = String.fromCharCode(92);
    expect(toolArgumentCredentialContext('{"api_key":"x$slash'), [
      {'api_key': 'x$slash'},
    ]);
    expect(toolArgumentCredentialContext(r'{"api_key":"\u007'), [
      {'api_key': r'\u007'},
    ]);
  });

  test(
    'deep open containers preserve the credential ancestor without recursion',
    () {
      final result = toolArgumentCredentialContext(
        '{"credentials":${'[' * 1000}"x"',
      );
      Object? value = (result.single as Map)['credentials'];
      for (var depth = 0; depth < 1000; depth++) {
        value = (value as List).single;
      }
      expect(value, 'x');
    },
  );
}
