import 'dart:convert';

/// Reads semantic values from a malformed JSON argument prefix for credential
/// checks. This never repairs executable arguments or recursively parses string
/// values. Open containers and complete prefixes of open strings remain visible.
List<Object?> toolArgumentCredentialContext(String source) {
  final roots = <Object?>[];
  final stack = <_ArgumentContainer>[];
  final containers = <_ArgumentContainer>[];
  void add(Object? value) {
    if (stack.isEmpty) {
      roots.add(value);
    } else {
      stack.last.add(value);
    }
  }

  var offset = 0;
  while (offset < source.length) {
    final character = source[offset];
    if (character == '"') {
      final parsed = _argumentString(source, offset + 1);
      offset = parsed.end;
      final current = stack.lastOrNull;
      if (current != null && current.isObject && current.expectsKey) {
        current.key(parsed.value);
      } else {
        add(parsed.value);
      }
      continue;
    }
    if (character == '{' || character == '[') {
      final container = _ArgumentContainer(character == '{');
      add(container.value);
      stack.add(container);
      containers.add(container);
      offset++;
      continue;
    }
    if (character == '}' || character == ']') {
      if (stack.isNotEmpty && stack.last.isObject == (character == '}')) {
        stack.removeLast();
      }
      offset++;
      continue;
    }
    if (character == ',') {
      if (stack.lastOrNull case final current? when current.isObject) {
        current.expectsKey = true;
        current.pendingKey = null;
      }
      offset++;
      continue;
    }
    if (character == ':' || character.trim().isEmpty) {
      offset++;
      continue;
    }
    final start = offset;
    while (offset < source.length &&
        !'{}[],:"'.contains(source[offset]) &&
        source[offset].trim().isNotEmpty) {
      offset++;
    }
    final token = source.substring(start, offset);
    try {
      add(jsonDecode(token));
    } on FormatException {
      // Preserve a non-JSON scalar's credential field/ancestor association.
      add(token);
    }
  }
  for (final container in containers.reversed) {
    container.finish();
  }
  return roots;
}

class _ArgumentContainer {
  _ArgumentContainer(this.isObject)
    : value = isObject ? <String, Object?>{} : <Object?>[],
      expectsKey = isObject;
  final bool isObject;
  final Object value;
  final previous = <Map<String, Object?>>[];
  final fragments = <Object?>[];
  bool expectsKey;
  String? pendingKey;

  void key(String key) {
    final object = value as Map<String, Object?>;
    if (object.containsKey(key)) {
      // Preserve overwritten values and header-style name/key/value meaning
      // without copying the whole object for every duplicate field.
      previous.add({
        key: object[key],
        for (final metadata in ['name', 'key', 'value'])
          if (object.containsKey(metadata)) metadata: object[metadata],
      });
    }
    // Keep a decoded key visible even if its colon/value never arrives.
    object[key] = null;
    pendingKey = key;
    expectsKey = false;
  }

  void add(Object? child) {
    if (!isObject) {
      (value as List<Object?>).add(child);
    } else if (pendingKey case final key?) {
      (value as Map<String, Object?>)[key] = child;
      pendingKey = null;
      expectsKey = false;
    } else {
      // Invalid separators must not detach fragments from a credential parent.
      fragments.add(child);
    }
  }

  void finish() {
    if (!isObject || previous.isEmpty && fragments.isEmpty) return;
    final object = value as Map<String, Object?>;
    var key = '__partial_json_fragments';
    while (object.containsKey(key)) {
      key += '_';
    }
    // Added only after parsing: previous snapshots cannot reference this list.
    object[key] = [...previous, ...fragments];
  }
}

({String value, int end}) _argumentString(String source, int offset) {
  final decoded = StringBuffer();
  while (offset < source.length) {
    final character = source[offset++];
    if (character == '"') return (value: decoded.toString(), end: offset);
    if (character != r'\') {
      decoded.write(character);
      continue;
    }
    if (offset == source.length) {
      decoded.write(r'\');
      break;
    }
    final escaped = source[offset++];
    if (escaped == 'u') {
      if (offset + 4 <= source.length) {
        final digits = source.substring(offset, offset + 4);
        if (RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(digits)) {
          decoded.writeCharCode(int.parse(digits, radix: 16));
          offset += 4;
          continue;
        }
      }
      decoded.write(r'\u');
      continue;
    }
    const escapes = <String, String>{
      '"': '"',
      r'\': r'\',
      '/': '/',
      'b': '\b',
      'f': '\f',
      'n': '\n',
      'r': '\r',
      't': '\t',
    };
    decoded.write(escapes[escaped] ?? '\\$escaped');
  }
  return (value: decoded.toString(), end: offset);
}
