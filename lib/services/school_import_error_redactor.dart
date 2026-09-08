import 'dart:convert';

// Error excerpts may be incomplete JSON. Recognize optional slash escaping
// directly instead of requiring the entire diagnostic to decode as JSON.
final _webUrl = RegExp(
  r'''https?:(?:\\?/){2}[^\s<>"']+''',
  caseSensitive: false,
);
final _credentialHeader = RegExp(
  r'''(\b(?:proxy-)?authorization\b|\bx-api-key\b|\bapi[_-]?key\b)(["']?\s*[:=]\s*)'''
  // Consume escaped quotes and fail closed if an excerpt ends inside a value,
  // including a dangling escape. Keep the following truncation marker intact.
  r'''(?:"(?:\\[^\r\n]|[^"\\\r\n])*(?:"|\\?(?=[\r\n]|$))'''
  r'''|'(?:\\[^\r\n]|[^'\\\r\n])*(?:'|\\?(?=[\r\n]|$))'''
  r'''|[^,;\r\n}\]]+)''',
  caseSensitive: false,
);
final _truncationMarker = RegExp(
  r'(?:\n\n\[(?:details|response body) truncated\])+$',
);

/// Sanitizes diagnostic text only. Request URLs, headers, model output and
/// imported timetable content must never be rewritten by this helper.
String redactSchoolImportError(String message, {required String apiKey}) {
  var result = message.replaceAllMapped(_webUrl, (match) {
    try {
      final uri = Uri.tryParse(match[0]!.replaceAll(r'\/', '/'));
      if (uri == null || uri.host.isEmpty) return '[redacted URL]';
      // Even an unfamiliar query parameter or fragment may be a credential.
      // Preserve the destination and path, never user-info/query/fragment.
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: uri.path,
      ).toString();
    } on FormatException {
      return '[redacted URL]';
    }
  });
  result = result.replaceAllMapped(
    _credentialHeader,
    (match) => '${match[1]}${match[2]}[redacted]',
  );

  final secret = apiKey.trim();
  if (secret.isEmpty) return result;
  final jsonSecret = jsonEncode(secret);
  final escapedSecret = jsonSecret.substring(1, jsonSecret.length - 1);
  final variants = {
    secret,
    Uri.encodeComponent(secret),
    Uri.encodeQueryComponent(secret),
    escapedSecret,
    escapedSecret.replaceAll('/', r'\/'),
  }.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final variant in variants) {
    result = result.replaceAll(variant, '[redacted]');
    result = _redactTruncatedSecret(result, variant);
  }
  return result;
}

String _redactTruncatedSecret(String message, String secret) {
  // Error excerpts are bounded before reaching the public API boundary. A
  // long reflected key may therefore be present only as a trailing prefix.
  // Match at least eight known characters to avoid redacting ordinary prose.
  const prefixLength = 8;
  if (secret.length <= prefixLength) return message;
  final prefix = secret.substring(0, prefixLength);
  final contentEnd =
      _truncationMarker.firstMatch(message)?.start ?? message.length;
  var start = message.indexOf(prefix);
  while (start >= 0 && start < contentEnd) {
    final tail = message.substring(start, contentEnd);
    if (secret.startsWith(tail)) {
      return message.replaceRange(start, contentEnd, '[redacted]');
    }
    start = message.indexOf(prefix, start + prefixLength);
  }
  return message;
}
