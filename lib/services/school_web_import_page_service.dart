import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/school_import_models.dart';
import 'school_import_content_sanitizer.dart';

class SchoolWebImportPageService {
  const SchoolWebImportPageService();

  static const String navigationApprovalHandlerName =
      'skedConfirmNavigationOrigin';
  static const int maxPlatformResultLength = 512 * 1024;
  static const int maxDomNodeCount = 50000;
  static const int maxDomDepth = 64;
  static const int maxSourceOriginLength = 2048;
  static const int maxSourceTitleLength = 512;
  static const String extractionProtocolPrefix = 'SKED_WEB_IMPORT_V1\n';

  static final String formNavigationGuardScript =
      '''
(() => {
  if (window.__skedFormNavigationGuardInstalled) return;
  window.__skedFormNavigationGuardInstalled = true;
  const approvedOrigins = new Set();
  const nativeSubmit = HTMLFormElement.prototype.submit;
  const nativeRequestSubmit = HTMLFormElement.prototype.requestSubmit;

  const targetOrigin = (form, submitter) => {
    try {
      const action = (submitter && submitter.formAction) || form.action || location.href;
      return new URL(action, location.href).origin;
    } catch (_) {
      return '';
    }
  };

  const continueSubmission = (form, submitter, useRequestSubmit) => {
    if (useRequestSubmit && nativeRequestSubmit) {
      nativeRequestSubmit.call(form, submitter || undefined);
    } else {
      nativeSubmit.call(form);
    }
  };

  const guardSubmission = async (form, submitter, useRequestSubmit) => {
    const origin = targetOrigin(form, submitter);
    if (!origin) return;
    if (origin === location.origin || approvedOrigins.has(origin)) {
      continueSubmission(form, submitter, useRequestSubmit);
      return;
    }
    try {
      const approved = await window.flutter_inappwebview.callHandler(
        '$navigationApprovalHandlerName',
        origin
      );
      if (approved === true) {
        const approvedOrigin = targetOrigin(form, submitter);
        if (approvedOrigin !== origin) {
          void guardSubmission(form, submitter, useRequestSubmit);
          return;
        }
        approvedOrigins.add(origin);
        continueSubmission(form, submitter, useRequestSubmit);
      }
    } catch (_) {}
  };

  HTMLFormElement.prototype.submit = function() {
    void guardSubmission(this, null, false);
  };
  HTMLFormElement.prototype.requestSubmit = function(submitter) {
    void guardSubmission(this, submitter || null, true);
  };
  document.addEventListener('submit', (event) => {
    const form = event.target;
    if (!(form instanceof HTMLFormElement)) return;
    const submitter = event.submitter || null;
    const origin = targetOrigin(form, submitter);
    if (!origin || origin === location.origin || approvedOrigins.has(origin)) {
      return;
    }
    event.preventDefault();
    event.stopImmediatePropagation();
    void guardSubmission(form, submitter, true);
  }, true);
})()
''';

  static final String extractImportSourceScript =
      '''
(() => {
  const MAX_CONTENT = ${SchoolImportContentSanitizer.maxContentLength};
  const MAX_NODES = $maxDomNodeCount;
  const MAX_DEPTH = $maxDomDepth;
  const MAX_SCANNED_TEXT = ${SchoolImportContentSanitizer.maxInputLength};
  const MAX_ORIGIN = $maxSourceOriginLength;
  const MAX_TITLE = $maxSourceTitleLength;
  const PROTOCOL = ${jsonEncode(extractionProtocolPrefix)};
  let output = '';
  let reservedClosings = 0;
  let visitedNodes = 0;
  let scannedTextCharacters = 0;
  let truncated = false;

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

  const canWrite = (length) =>
    output.length + reservedClosings + length <= MAX_CONTENT;

  const writeToken = (token) => {
    if (!canWrite(token.length)) {
      truncated = true;
      return false;
    }
    output += token;
    return true;
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
      if (scannedTextCharacters + characterLength > MAX_SCANNED_TEXT) {
        truncated = true;
        return;
      }
      scannedTextCharacters += characterLength;
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
      if (!canWrite(escaped.length)) {
        truncated = true;
        return;
      }
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

  let visit;
  const visitChildren = (node, depth) => {
    let children;
    let length;
    try {
      children = node.childNodes;
      length = children && children.length;
    } catch (_) {
      return;
    }
    if (typeof length !== 'number' || !(length >= 0)) return;
    if (length > MAX_NODES) length = MAX_NODES;
    for (let index = 0; index < length; index += 1) {
      let child;
      try {
        child = children[index];
      } catch (_) {
        continue;
      }
      if (child) visit(child, depth + 1);
      if (truncated) break;
    }
  };

  visit = (node, depth) => {
    if (truncated) return;
    visitedNodes += 1;
    if (visitedNodes > MAX_NODES || depth > MAX_DEPTH) {
      truncated = true;
      return;
    }
    let nodeType;
    try {
      nodeType = node.nodeType;
    } catch (_) {
      return;
    }
    if (nodeType === 3) {
      let value;
      try {
        value = node.nodeValue;
      } catch (_) {
        return;
      }
      writeText(value);
      return;
    }
    if (nodeType !== 1) return;
    let tag;
    try {
      tag = node.localName;
    } catch (_) {
      return;
    }
    if (typeof tag !== 'string') return;
    const kind = elementKind(tag);
    if (kind < 0) return;
    if (kind === 0) {
      visitChildren(node, depth);
      return;
    }

    const opening = '<' + tag + safeAttributes(node, tag) + '>';
    if (kind === 2) {
      writeToken(opening);
      return;
    }
    const closing = '</' + tag + '>';
    if (!canWrite(opening.length + closing.length)) {
      truncated = true;
      return;
    }
    output += opening;
    reservedClosings += closing.length;
    visitChildren(node, depth);
    reservedClosings -= closing.length;
    output += closing;
  };

  let root;
  try {
    root = document.documentElement;
  } catch (_) {}
  if (root) visit(root, 0);

  const copyBoundedPrimitive = (value, limit) => {
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
      if (result.length + character.length > limit) break;
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
    : copyBoundedPrimitive(rawOrigin, MAX_ORIGIN);
  const safeTitle = copyBoundedPrimitive(rawTitle, MAX_TITLE);

  // A primitive, length-prefixed result prevents page-world serializers and
  // coercion hooks from expanding data before it crosses the platform bridge.
  return PROTOCOL +
    output.length + '\\n' +
    safeOrigin.length + '\\n' +
    safeTitle.length + '\\n' +
    (truncated ? '1' : '0') + '\\n' +
    output + safeOrigin + safeTitle;
})()
''';

  Future<SchoolImportSourcePayload> extractSource(
    InAppWebViewController controller, {
    required String fallbackUrl,
    required String fallbackTitle,
  }) async {
    final result = await controller.evaluateJavascript(
      source: extractImportSourceScript,
    );
    return decodeSchoolWebImportExtraction(
      result,
      fallbackUrl: fallbackUrl,
      fallbackTitle: fallbackTitle,
    );
  }
}

@visibleForTesting
SchoolImportSourcePayload decodeSchoolWebImportExtraction(
  Object? value, {
  required String fallbackUrl,
  required String fallbackTitle,
}) {
  final normalized = normalizeJavaScriptResult(value);
  if (normalized.length > SchoolWebImportPageService.maxPlatformResultLength) {
    throw const FormatException('Import page result is too large.');
  }
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
  if (content.length > SchoolImportContentSanitizer.maxContentLength) {
    throw const FormatException('Import page content is too large.');
  }
  final rawUrl = decoded['url'] is String ? decoded['url'] as String : '';
  final hasAtomicTitle = decoded['title'] is String;
  final rawTitle = hasAtomicTitle ? decoded['title'] as String : fallbackTitle;
  final sanitizedUrl = sanitizeSchoolImportSourceUrl(rawUrl);
  return SchoolImportSourcePayload(
    url: sanitizedUrl.isEmpty
        ? sanitizeSchoolImportSourceUrl(fallbackUrl)
        : sanitizedUrl,
    title: _boundedText(
      rawTitle,
      SchoolWebImportPageService.maxSourceTitleLength,
    ),
    content: content,
    wasTruncated: decoded['truncated'] == true,
  );
}

Map<String, Object?> _decodeSchoolWebImportProtocol(String value) {
  var cursor = SchoolWebImportPageService.extractionProtocolPrefix.length;

  String readLine({required int maxLength}) {
    final end = value.indexOf('\n', cursor);
    if (end < cursor || end - cursor > maxLength) {
      throw const FormatException('Import page result is invalid.');
    }
    final line = value.substring(cursor, end);
    cursor = end + 1;
    return line;
  }

  int readLength(int maximum) {
    final raw = readLine(maxLength: 10);
    if (!RegExp(r'^(0|[1-9]\d*)$').hasMatch(raw)) {
      throw const FormatException('Import page result is invalid.');
    }
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed > maximum) {
      throw const FormatException('Import page result is invalid.');
    }
    return parsed;
  }

  final contentLength = readLength(
    SchoolImportContentSanitizer.maxContentLength,
  );
  final originLength = readLength(
    SchoolWebImportPageService.maxSourceOriginLength,
  );
  final titleLength = readLength(
    SchoolWebImportPageService.maxSourceTitleLength,
  );
  final truncatedValue = readLine(maxLength: 1);
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

String _boundedText(String source, int maxLength) {
  final normalized = source.trim();
  if (normalized.length <= maxLength) return normalized;
  final buffer = StringBuffer();
  var length = 0;
  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    if (length + character.length > maxLength) break;
    buffer.write(character);
    length += character.length;
  }
  return buffer.toString();
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
