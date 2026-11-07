import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/runtime/secret_content.dart';

void main() {
  for (final key in ['x', 'test', r't\est']) {
    test(
      'short credential $key is not inferred from ordinary text or keys',
      () {
        expect(
          containsAgentCredentialText(
            'Use exact function names. This is a test.',
            key,
          ),
          isFalse,
        );
        expect(containsAgentCredentialText(key, key), isFalse);
        expect(
          containsAgentCredentialValue({
            'text': 'Example test',
            key: 'normal',
            'nested': [key],
          }, key),
          isFalse,
        );
      },
    );

    for (final field in [
      'apiKey',
      'api_key',
      'access-token',
      'Authorization',
      'clientSecret',
      'credentials',
    ]) {
      test('short credential $key in $field remains protected', () {
        expect(
          containsAgentCredentialValue({
            'wrapper': [
              {field: key},
            ],
          }, key),
          isTrue,
        );
        expect(
          containsAgentCredentialValue({
            field: {
              'nested': [key],
            },
          }, key),
          isTrue,
        );
      });
    }

    test(
      'short credential $key in explicit text assignments remains protected',
      () {
        expect(
          containsAgentCredentialText('API key: ${jsonEncode(key)}', key),
          isTrue,
        );
        expect(
          containsAgentCredentialText('api_key = ${jsonEncode(key)}', key),
          isTrue,
        );
        expect(
          containsAgentCredentialText('API Key is ${jsonEncode(key)}', key),
          isTrue,
        );
        expect(
          containsAgentCredentialText('Authorization: Bearer $key', key),
          isTrue,
        );
        final basic = base64.encode(utf8.encode('user:$key'));
        expect(
          containsAgentCredentialText('Authorization: Basic $basic', key),
          isTrue,
        );
        expect(
          containsAgentCredentialValue({'name': 'apiKey', 'value': key}, key),
          isTrue,
        );
        expect(
          containsAgentCredentialValue({
            'Cookie': 'session=$key; language=en',
          }, key),
          isTrue,
        );
      },
    );
  }

  test('credential field metadata does not mistake x in example for a key', () {
    expect(
      containsAgentCredentialValue({
        'apiKey': {'description': 'Example value', 'type': 'string'},
      }, 'x'),
      isFalse,
    );
    expect(
      containsAgentCredentialText('Authorization: Bearer existing-value', 'x'),
      isFalse,
    );
  });

  test(
    'long credentials retain exact full-value protection in all positions',
    () {
      const key = 'sk-long-random-fixture-key';
      for (final value in [
        key,
        'prefix$key suffix',
        {'field-$key': 'normal'},
        {
          'nested': ['prefix$key'],
        },
      ]) {
        expect(containsAgentCredentialValue(value, key), isTrue);
      }
      expect(containsAgentCredentialText('prefix$key suffix', key), isTrue);
    },
  );

  test('empty credentials and unrelated explicit values are allowed', () {
    expect(containsAgentCredentialText('Authorization: Bearer x', ''), isFalse);
    expect(
      containsAgentCredentialValue({'api_key': 'another-value'}, 'test'),
      isFalse,
    );
    expect(
      containsAgentCredentialText('API key: another-value', 'test'),
      isFalse,
    );
  });

  test(
    'complete quoted credentials are blocked before the closing quote arrives',
    () {
      for (final key in ['x', 'test', 'x"', 'x\\']) {
        final encoded = jsonEncode(key);
        expect(
          containsAgentCredentialText(
            'API key: ${encoded.substring(0, encoded.length - 1)}',
            key,
          ),
          isTrue,
        );
      }
      expect(containsAgentCredentialText("API key: 'x", 'x'), isTrue);
      expect(containsAgentCredentialText(r"API key: 'x\'", "x'"), isTrue);
      expect(containsAgentCredentialText(r'API key: "\u0078', 'x'), isTrue);
    },
  );

  test('partial credentials and unfinished escapes are not decoded as complete values', () {
    expect(containsAgentCredentialText('API key: "tes', 'test'), isFalse);
    expect(containsAgentCredentialText('API key: "x\\', 'x'), isFalse);
    expect(containsAgentCredentialText(r'API key: "\u007', 'x'), isFalse);
    expect(containsAgentCredentialText("API key: 'x\\", 'x'), isFalse);
  });
}
