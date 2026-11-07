import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/school_import_models.dart';
import '../utils/unique_id.dart';

class SchoolWebImportPageService {
  const SchoolWebImportPageService();

  static const String extractionProtocolPrefix = 'SKED_WEB_IMPORT_V1\n';
  static const String extractionChunkPrefix = 'SKED_WEB_IMPORT_CHUNK_V1\n';

  static final String extractImportSourceScript =
      '''
(() => {
  const PROTOCOL = ${jsonEncode(extractionProtocolPrefix)};
  let output = '';

  const elementKind = (tag) => {
    switch (tag) {
      case 'br': case 'hr':
        return 2;
      case 'article': case 'blockquote': case 'caption': case 'code':
      case 'dd': case 'div': case 'dl': case 'dt': case 'em': case 'h1':
      case 'h2': case 'h3': case 'h4': case 'h5': case 'h6': case 'li':
      case 'main': case 'ol': case 'p': case 'pre': case 'section':
      case 'span': case 'strong': case 'table': case 'tbody': case 'td':
      case 'tfoot': case 'th': case 'thead': case 'tr': case 'ul':
        return 1;
      case 'applet': case 'aside': case 'audio': case 'button': case 'canvas':
      case 'embed': case 'footer': case 'header': case 'iframe': case 'input':
      case 'link': case 'meta': case 'nav': case 'noscript': case 'object':
      case 'script': case 'select': case 'style': case 'svg': case 'template':
      case 'textarea': case 'video':
        return -1;
      default:
        return 0;
    }
  };

  const writeText = (value) => {
    if (typeof value !== 'string') return;
    let previousWasWhitespace = false;
    for (let index = 0; index < value.length; index += 1) {
      let character = value[index];
      let characterLength = 1;
      if (character >= '\\uD800' && character <= '\\uDBFF' &&
          index + 1 < value.length) {
        const trailing = value[index + 1];
        if (trailing >= '\\uDC00' && trailing <= '\\uDFFF') {
          character += trailing;
          characterLength = 2;
        }
      }
      if (characterLength === 1 &&
          character >= '\\uD800' && character <= '\\uDFFF') {
        character = '\\uFFFD';
      }
      index += characterLength - 1;
      const isWhitespace =
        character === ' ' || character === '\\t' || character === '\\n' ||
        character === '\\f' || character === '\\r' || character === '\\u00a0';
      if (isWhitespace && previousWasWhitespace) continue;
      previousWasWhitespace = isWhitespace;
      if (!isWhitespace && character < ' ') continue;
      const escaped = isWhitespace
        ? ' '
        : character === '&'
        ? '&amp;'
        : character === '<'
        ? '&lt;'
        : character === '>'
        ? '&gt;'
        : character;
      output += escaped;
    }
  };

  const boundedSpanValue = (raw) => {
    if (typeof raw !== 'string' || raw.length === 0 || raw.length > 4) {
      return 0;
    }
    let value = 0;
    for (let index = 0; index < raw.length; index += 1) {
      const character = raw[index];
      let digit = -1;
      switch (character) {
        case '0': digit = 0; break;
        case '1': digit = 1; break;
        case '2': digit = 2; break;
        case '3': digit = 3; break;
        case '4': digit = 4; break;
        case '5': digit = 5; break;
        case '6': digit = 6; break;
        case '7': digit = 7; break;
        case '8': digit = 8; break;
        case '9': digit = 9; break;
        default: return 0;
      }
      value = value * 10 + digit;
      if (value > 1000) return 0;
    }
    return value;
  };

  const safeAttributes = (element, tag) => {
    if (tag !== 'td' && tag !== 'th') return '';
    if (typeof element.getAttribute !== 'function') return '';
    let attributes = '';
    for (let index = 0; index < 2; index += 1) {
      const name = index === 0 ? 'rowspan' : 'colspan';
      let raw = '';
      try {
        raw = element.getAttribute(name);
      } catch (_) {
        continue;
      }
      const value = boundedSpanValue(raw);
      if (value >= 1) attributes += ' ' + name + '="' + value + '"';
    }
    return attributes;
  };

  const root = document.documentElement;
  const pending = root ? [{node: root}] : [];
  while (pending.length) {
    const entry = pending.pop();
    if (entry.closing) {
      output += entry.closing;
      continue;
    }
    const node = entry.node;
    if (node.nodeType === 3) {
      writeText(node.nodeValue);
      continue;
    }
    if (node.nodeType !== 1) continue;
    const tag = node.localName;
    if (typeof tag !== 'string') continue;
    const kind = elementKind(tag);
    if (kind < 0) continue;
    if (kind > 0) {
      output += '<' + tag + safeAttributes(node, tag) + '>';
      if (kind === 2) continue;
      pending.push({closing: '</' + tag + '>'});
    }
    const children = node.childNodes;
    for (let index = children.length - 1; index >= 0; index -= 1) {
      pending.push({node: children[index]});
    }
  }

  const copyPrimitive = (value) => {
    if (typeof value !== 'string') return '';
    let result = '';
    for (let index = 0; index < value.length; index += 1) {
      let character = value[index];
      let characterLength = 1;
      if (character >= '\\uD800' && character <= '\\uDBFF' &&
          index + 1 < value.length) {
        const trailing = value[index + 1];
        if (trailing >= '\\uDC00' && trailing <= '\\uDFFF') {
          character += trailing;
          characterLength = 2;
        }
      }
      if (characterLength === 1 &&
          character >= '\\uD800' && character <= '\\uDFFF') {
        character = '\\uFFFD';
      }
      result += character;
      index += characterLength - 1;
    }
    return result;
  };
  let rawOrigin = '';
  let rawTitle = '';
  try {
    rawOrigin = location.origin;
  } catch (_) {}
  try {
    rawTitle = document.title;
  } catch (_) {}
  const safeOrigin = rawOrigin === 'null'
    ? ''
    : copyPrimitive(rawOrigin);
  const safeTitle = copyPrimitive(rawTitle);

  // A primitive, length-prefixed result prevents page-world serializers and
  // coercion hooks from expanding data before it crosses the platform bridge.
  return PROTOCOL +
    output.length + '\\n' +
    safeOrigin.length + '\\n' +
    safeTitle.length + '\\n' +
    '0\\n' +
    output + safeOrigin + safeTitle;
})()
''';

  Future<SchoolImportSourcePayload> extractSource(
    InAppWebViewController controller, {
    required String fallbackUrl,
    required String fallbackTitle,
  }) async {
    return extractWithEvaluator(
      (source) => controller.evaluateJavascript(source: source),
      fallbackUrl: fallbackUrl,
      fallbackTitle: fallbackTitle,
    );
  }

  @visibleForTesting
  Future<SchoolImportSourcePayload> extractWithEvaluator(
    Future<Object?> Function(String source) evaluate, {
    required String fallbackUrl,
    required String fallbackTitle,
  }) async {
    final key = jsonEncode('__skedImport_${generateUuidV4()}');
    try {
      final rawLength = await evaluate('''// sked-source-start
(() => {
  const captured = $extractImportSourceScript;
  globalThis[$key] = captured;
  return captured.length;
})()
''');
      final length =
          rawLength is num &&
              rawLength.isFinite &&
              rawLength == rawLength.truncateToDouble()
          ? rawLength.toInt()
          : int.tryParse(normalizeJavaScriptResult(rawLength));
      if (length == null || length < 0) {
        throw const FormatException('The captured source length is invalid.');
      }
      final output = StringBuffer();
      var offset = 0;
      while (offset < length) {
        final end = (offset + 65536).clamp(0, length);
        final raw = await evaluate('''// sked-source-chunk
(() => {
  const captured = globalThis[$key];
  if (typeof captured !== 'string' || captured.length !== $length) throw new Error('Source changed');
  let end = $end;
  const last = captured.charCodeAt(end - 1);
  if (end < captured.length && last >= 0xD800 && last <= 0xDBFF) end -= 1;
  return ${jsonEncode(extractionChunkPrefix)} + captured.slice($offset, end);
})()
''');
        final response = normalizeJavaScriptResult(raw);
        if (!response.startsWith(extractionChunkPrefix)) {
          throw const FormatException('The captured source chunk is invalid.');
        }
        final chunk = response.substring(extractionChunkPrefix.length);
        if (chunk.isEmpty || offset + chunk.length > end) {
          throw const FormatException(
            'The captured source chunk length is invalid.',
          );
        }
        output.write(chunk);
        offset += chunk.length;
      }
      return decodeSchoolWebImportExtraction(
        output.toString(),
        fallbackUrl: fallbackUrl,
        fallbackTitle: fallbackTitle,
      );
    } finally {
      await evaluate('// sked-source-finish\ndelete globalThis[$key]');
    }
  }
}

@visibleForTesting
SchoolImportSourcePayload decodeSchoolWebImportExtraction(
  Object? value, {
  required String fallbackUrl,
  required String fallbackTitle,
}) {
  final normalized = normalizeJavaScriptResult(value);
  final Object? decoded;
  if (normalized.startsWith(
    SchoolWebImportPageService.extractionProtocolPrefix,
  )) {
    decoded = _decodeSchoolWebImportProtocol(normalized);
  } else {
    try {
      decoded = jsonDecode(normalized.trim());
    } catch (_) {
      throw const FormatException('Import page result is invalid.');
    }
  }
  if (decoded is! Map) {
    throw const FormatException('Import page result is invalid.');
  }
  final contentValue = decoded['content'];
  final content = contentValue is String ? contentValue.trim() : '';
  if (content.isEmpty) {
    throw const FormatException('Import content is empty.');
  }
  final rawUrl = decoded['url'] is String ? decoded['url'] as String : '';
  final hasAtomicTitle = decoded['title'] is String;
  final rawTitle = hasAtomicTitle ? decoded['title'] as String : fallbackTitle;
  final sanitizedUrl = sanitizeSchoolImportSourceUrl(rawUrl);
  return SchoolImportSourcePayload(
    url: sanitizedUrl.isEmpty
        ? sanitizeSchoolImportSourceUrl(fallbackUrl)
        : sanitizedUrl,
    title: rawTitle.trim(),
    content: content,
    wasTruncated: decoded['truncated'] == true,
  );
}

Map<String, Object?> _decodeSchoolWebImportProtocol(String value) {
  var cursor = SchoolWebImportPageService.extractionProtocolPrefix.length;

  String readLine() {
    final end = value.indexOf('\n', cursor);
    if (end < cursor) {
      throw const FormatException('Import page result is invalid.');
    }
    final line = value.substring(cursor, end);
    cursor = end + 1;
    return line;
  }

  int readLength() {
    final raw = readLine();
    if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(raw)) {
      throw const FormatException('Import page result is invalid.');
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw const FormatException('Import page result is invalid.');
    }
    return parsed;
  }

  final contentLength = readLength();
  final originLength = readLength();
  final titleLength = readLength();
  final truncatedValue = readLine();
  if (truncatedValue != '0' && truncatedValue != '1') {
    throw const FormatException('Import page result is invalid.');
  }
  if (value.length - cursor != contentLength + originLength + titleLength) {
    throw const FormatException('Import page result is invalid.');
  }

  final contentEnd = cursor + contentLength;
  final originEnd = contentEnd + originLength;
  return <String, Object?>{
    'content': value.substring(cursor, contentEnd),
    'url': value.substring(contentEnd, originEnd),
    'title': value.substring(originEnd),
    'truncated': truncatedValue == '1',
  };
}

@visibleForTesting
String sanitizeSchoolImportSourceUrl(String source) {
  final uri = Uri.tryParse(source.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.trim().isEmpty) {
    return '';
  }
  final isDefaultPort =
      (uri.scheme == 'http' && uri.port == 80) ||
      (uri.scheme == 'https' && uri.port == 443);
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort && !isDefaultPort ? uri.port : null,
  ).toString();
}

@visibleForTesting
String normalizeJavaScriptResult(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'undefined') {
      return '';
    }
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is String) {
          return decoded;
        }
      } catch (_) {
        return trimmed.substring(1, trimmed.length - 1);
      }
    }
    return value;
  }
  if (value is Map || value is List) {
    return jsonEncode(value);
  }
  final text = value.toString().trim();
  return text == 'null' || text == 'undefined' ? '' : text;
}
