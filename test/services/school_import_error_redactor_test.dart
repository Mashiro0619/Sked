import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/school_import_error_redactor.dart';

void main() {
  test(
    'keeps the failure context but strips every URL credential component',
    () {
      final message = redactSchoolImportError(
        'HTTP 401 at https://user:password@api.example.test:8443/v1/models?unknown_secret=hidden#private',
        apiKey: '',
      );
      expect(message, 'HTTP 401 at https://api.example.test:8443/v1/models');
    },
  );

  test('redacts URL credentials in slash-escaped JSON diagnostics', () {
    final message = jsonEncode({
      'url': 'https://user:password@api.example.test:8443/v1/models?token=hidden#private',
      'status': 401,
    }).replaceAll('/', r'\/');

    final result = redactSchoolImportError(message, apiKey: '');

    expect(jsonDecode(result), {
      'url': 'https://api.example.test:8443/v1/models',
      'status': 401,
    });
  });

  test('redacts slash-escaped URLs even when the JSON was truncated', () {
    const message =
        r'HTTP 401: {"url":"https:\/\/user:password@api.example.test\/v1?token=hidden'
        '\n\n[details truncated]';

    expect(
      redactSchoolImportError(message, apiKey: ''),
      'HTTP 401: {"url":"https://api.example.test/v1\n\n[details truncated]',
    );
  });

  test(
    'preserves IPv6 loopback and explicit ports without query or fragment',
    () {
      expect(
        redactSchoolImportError(
          'Failed at http://[::1]:6190/v1?token=hidden#private',
          apiKey: '',
        ),
        'Failed at http://[::1]:6190/v1',
      );
    },
  );

  test('redacts malformed and hostless URLs instead of echoing them', () {
    for (final url in [
      'https://[broken?token=hidden',
      'http://?token=hidden',
    ]) {
      expect(
        redactSchoolImportError('Failed at $url', apiKey: ''),
        'Failed at [redacted URL]',
      );
    }
  });

  test(
    'redacts authorization headers even when the token is not the API key',
    () {
      final result = redactSchoolImportError(
        'Authorization: Bearer UNKNOWN_BEARER\n'
        'Proxy-Authorization=Basic BASE64_CREDENTIAL\n'
        'x-api-key: OTHER_KEY\n'
        'Status: 401',
        apiKey: '',
      );
      for (final credential in [
        'UNKNOWN_BEARER',
        'BASE64_CREDENTIAL',
        'OTHER_KEY',
      ]) {
        expect(result, isNot(contains(credential)));
      }
      expect(result, contains('Status: 401'));
      expect(result, contains('Authorization: [redacted]'));
    },
  );

  test(
    'redacts quoted JSON header values without removing unrelated fields',
    () {
      final result = redactSchoolImportError(
        '{"Authorization":"Bearer UNKNOWN_TOKEN","message":"denied", "apiKey":"OTHER_KEY"}',
        apiKey: '',
      );
      expect(result, isNot(contains('UNKNOWN_TOKEN')));
      expect(result, isNot(contains('OTHER_KEY')));
      expect(result, contains('"message":"denied"'));
    },
  );

  test('redacts escaped quotes and backslashes in JSON header values', () {
    const secret = r'prefix"suffix-sensitive\more,secret';
    final message = jsonEncode({
      'Authorization': 'Bearer $secret',
      'message': 'denied',
    });

    for (final apiKey in ['', secret]) {
      final result = redactSchoolImportError(message, apiKey: apiKey);
      expect(result, '{"Authorization":[redacted],"message":"denied"}');
    }
  });

  test('redacts escaped quotes inside single-quoted header values', () {
    const message =
        r"'Authorization': 'Bearer prefix\'suffix-sensitive;extra-secret'; denied";

    expect(
      redactSchoolImportError(message, apiKey: ''),
      "'Authorization': [redacted]; denied",
    );
  });

  test('redacts truncated quoted headers without leaving secret suffixes', () {
    const headers = [
      r'Authorization: "Bearer prefix\"suffix-sensitive,other-sensitive',
      r"Authorization: 'Bearer prefix\'suffix-sensitive;other-sensitive",
      'Authorization: "Bearer trailing'
          r'\',
    ];
    for (final header in headers) {
      for (final marker in [
        '',
        '\n\n[details truncated]',
        '\n\n[response body truncated]',
      ]) {
        expect(
          redactSchoolImportError('$header$marker', apiKey: ''),
          'Authorization: [redacted]$marker',
        );
      }
    }
  });

  test('redacts single-quoted header values case-insensitively', () {
    final result = redactSchoolImportError(
      "'aUtHoRiZaTiOn': 'Bearer UNKNOWN_TOKEN'; denied",
      apiKey: '',
    );
    expect(result, isNot(contains('UNKNOWN_TOKEN')));
    expect(result, contains('denied'));
  });

  test('redacts the configured key wherever an error echoes it', () {
    const secret = 'sk-SECRET_TOKEN';
    expect(
      redactSchoolImportError(
        'Rejected $secret; retry $secret',
        apiKey: '  $secret  ',
      ),
      'Rejected [redacted]; retry [redacted]',
    );
  });

  test('redacts URI-encoded and JSON-escaped keys', () {
    const secret = 'secret+/with space\n"quote';
    final json = jsonEncode(secret);
    for (final variant in [
      Uri.encodeComponent(secret),
      Uri.encodeQueryComponent(secret),
      json.substring(1, json.length - 1),
      json.substring(1, json.length - 1).replaceAll('/', r'\/'),
    ]) {
      expect(
        redactSchoolImportError('Rejected $variant', apiKey: secret),
        'Rejected [redacted]',
      );
    }
  });

  test(
    'redacts a key embedded in a URL path after stripping URL credentials',
    () {
      expect(
        redactSchoolImportError(
          'Failed at https://api.example.test/sk-SECRET_TOKEN?secret=x',
          apiKey: 'sk-SECRET_TOKEN',
        ),
        'Failed at https://api.example.test/[redacted]',
      );
    },
  );

  test('redacts a long key cut by either bounded error excerpt marker', () {
    final secret = 'sk-1234567890${'Z' * 6000}';
    for (final marker in ['[details truncated]', '[response body truncated]']) {
      final result = redactSchoolImportError(
        'Rejected ${secret.substring(0, 4000)}\n\n$marker',
        apiKey: secret,
      );
      expect(result, 'Rejected [redacted]\n\n$marker');
      expect(result, isNot(contains('sk-1234567890')));
    }
  });

  test('redacts a trailing known key prefix without a truncation marker', () {
    expect(
      redactSchoolImportError(
        'Rejected sk-1234567890',
        apiKey: 'sk-1234567890-long-secret',
      ),
      'Rejected [redacted]',
    );
  });

  test('does not mistake ordinary prose for a truncated key', () {
    const message =
        '12345678 was rejected; 12345678 is an unrelated identifier.';
    expect(
      redactSchoolImportError(message, apiKey: '12345678-secret'),
      message,
    );
  });

  test(
    'handles short keys and leaves credential-free diagnostics unchanged',
    () {
      expect(
        redactSchoolImportError('Rejected key', apiKey: 'key'),
        'Rejected [redacted]',
      );
      expect(
        redactSchoolImportError('HTTP 503: service unavailable', apiKey: ''),
        'HTTP 503: service unavailable',
      );
    },
  );
}
