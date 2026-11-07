import 'dart:convert';

// A short local-server credential can also be an ordinary word or identifier.
// Length chooses the matching strategy; it never restricts accepted credentials.
const _distinctiveCredentialLength = 8;

final _authorization = RegExp(
  r'''\b(Bearer|Basic)\s+([^\s,;"'<>]+)''',
  caseSensitive: false,
);
final _credentialAssignment = RegExp(
  r'''(?:^|[\s{,;])["']?(?:api[ _-]?key|api[ _-]?token|access[ _-]?token|refresh[ _-]?token|client[ _-]?secret|secret|password|authorization|proxy[ _-]?authorization|密钥|金鑰|令牌)["']?\s*(?::|=|\bis\b)\s*("(?:\\.|[^"\\])*(?:"|$)|'(?:\\.|[^'\\])*(?:'|$)|[^\s,;}]+)''',
  caseSensitive: false,
);

/// Recognizes the current credential without treating a short placeholder in
/// ordinary prose (for example x in exact) as a credential disclosure.
bool containsAgentCredentialText(String text, String credential) {
  if (credential.isEmpty) return false;
  if (credential.runes.length >= _distinctiveCredentialLength &&
      text.contains(credential)) {
    return true;
  }
  for (final match in _authorization.allMatches(text)) {
    final value = match[2]!;
    if (value == credential) return true;
    if (match[1]!.toLowerCase() == 'basic') {
      try {
        final decoded = utf8.decode(base64.decode(value));
        if (decoded == credential || decoded.endsWith(':$credential')) {
          return true;
        }
      } on FormatException {
        // An invalid header does not establish the current credential's value.
      }
    }
  }
  for (final match in _credentialAssignment.allMatches(text)) {
    if (_credentialScalar(match[1]!) == credential) return true;
  }
  return false;
}

/// Traverses actual structured fields. A credential container propagates its
/// meaning through nested records/lists, without recursively decoding strings.
bool containsAgentCredentialValue(Object? value, String credential) {
  if (credential.isEmpty) return false;
  final pending = <({Object? value, bool credentialField})>[
    (value: value, credentialField: false),
  ];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    final value = current.value;
    if (value is String) {
      if (containsAgentCredentialText(value, credential) ||
          current.credentialField && _credentialValue(value, credential)) {
        return true;
      }
    } else if (value is Map<Object?, Object?>) {
      final namedField = value['name'] ?? value['key'];
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is String && containsAgentCredentialText(key, credential)) {
          return true;
        }
        pending.add((
          value: entry.value,
          credentialField:
              current.credentialField ||
              key is String && _credentialField(key) ||
              key == 'value' &&
                  namedField is String &&
                  _credentialField(namedField),
        ));
      }
    } else if (value is List<Object?>) {
      pending.addAll(
        value.map(
          (item) => (value: item, credentialField: current.credentialField),
        ),
      );
    } else if (current.credentialField &&
        value != null &&
        value.toString() == credential) {
      return true;
    }
  }
  return false;
}

bool _credentialField(String name) => const {
  'apikey',
  'apitoken',
  'accesskey',
  'accesstoken',
  'refreshtoken',
  'clientsecret',
  'secret',
  'password',
  'authorization',
  'proxyauthorization',
  'credential',
  'credentials',
  'token',
  'bearertoken',
  'cookie',
  'setcookie',
  '密钥',
  '金鑰',
  '令牌',
}.contains(name.toLowerCase().replaceAll(RegExp(r'[\s_-]'), ''));

bool _credentialValue(String value, String credential) {
  if (value.trim() == credential) return true;
  // Credential containers can hold cookie/header-style name=value pairs.
  // Only the pair's complete value counts, not a character inside metadata.
  for (final part in value.split(';')) {
    final equals = part.indexOf('=');
    if (equals >= 0 &&
        _credentialScalar(part.substring(equals + 1).trim()) == credential) {
      return true;
    }
  }
  return false;
}

String _credentialScalar(String value) {
  if (value.startsWith('"')) {
    for (final candidate in [value, '$value"']) {
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is String) return decoded;
      } on FormatException {
        // A complete value can arrive before its closing quote. Appending only
        // that quote still rejects incomplete escapes and Unicode sequences.
      }
    }
  }
  if (value.startsWith("'")) {
    final decoded = StringBuffer();
    for (var index = 1; index < value.length; index++) {
      final character = value[index];
      if (character == "'") {
        return index == value.length - 1 ? decoded.toString() : value;
      }
      if (character == '\\') {
        if (++index == value.length) return value;
        final escaped = value[index];
        if (escaped != '\\' && escaped != "'") return value;
        decoded.write(escaped);
      } else {
        decoded.write(character);
      }
    }
    return decoded.toString();
  }
  return value;
}
