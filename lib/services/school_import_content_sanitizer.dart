import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../utils/text_input_limits.dart';

class SchoolImportSanitizationResult {
  const SchoolImportSanitizationResult({
    required this.content,
    required this.wasTruncated,
  });

  final String content;
  final bool wasTruncated;
}

class SchoolImportContentSanitizer {
  const SchoolImportContentSanitizer._();

  static const int maxInputLength = 240000;
  static const int maxContentLength = 120000;
  static const int _maxTreeDepth = 64;

  static const Set<String> _allowedTags = {
    'article',
    'blockquote',
    'br',
    'caption',
    'code',
    'dd',
    'div',
    'dl',
    'dt',
    'em',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'hr',
    'li',
    'main',
    'ol',
    'p',
    'pre',
    'section',
    'span',
    'strong',
    'table',
    'tbody',
    'td',
    'tfoot',
    'th',
    'thead',
    'tr',
    'ul',
  };

  static const Set<String> _discardedTags = {
    'applet',
    'aside',
    'audio',
    'button',
    'canvas',
    'embed',
    'footer',
    'header',
    'iframe',
    'input',
    'link',
    'meta',
    'nav',
    'noscript',
    'object',
    'script',
    'select',
    'style',
    'svg',
    'template',
    'textarea',
    'video',
  };

  static const Set<String> _voidTags = {'br', 'hr'};
  static const HtmlEscape _textEscape = HtmlEscape(HtmlEscapeMode.element);
  static const HtmlEscape _attributeEscape = HtmlEscape(
    HtmlEscapeMode.attribute,
  );

  static String sanitize(String source) {
    return sanitizeWithResult(source).content;
  }

  static SchoolImportSanitizationResult sanitizeWithResult(String source) {
    final inputWasTruncated = source.length > maxInputLength;
    final boundedSource = !inputWasTruncated
        ? source
        : truncateUtf16CodeUnits(source, maxInputLength);
    final fragment = html_parser.parseFragment(boundedSource);
    final writer = _BoundedHtmlWriter(maxContentLength);
    for (final node in fragment.nodes) {
      _serializeNode(node, writer, depth: 0);
      if (writer.truncated) break;
    }
    return SchoolImportSanitizationResult(
      content: writer.toString().trim(),
      wasTruncated: inputWasTruncated || writer.truncated,
    );
  }

  static void _serializeNode(
    Node node,
    _BoundedHtmlWriter writer, {
    required int depth,
  }) {
    if (writer.truncated) return;
    if (node is Text) {
      writer.writeText(_normalizeText(node.data));
      return;
    }
    if (node is! Element) return;

    final tag = node.localName?.toLowerCase() ?? '';
    if (_discardedTags.contains(tag)) return;
    if (depth >= _maxTreeDepth) {
      writer.markTruncated();
      return;
    }

    if (!_allowedTags.contains(tag)) {
      for (final child in node.nodes) {
        _serializeNode(child, writer, depth: depth + 1);
        if (writer.truncated) break;
      }
      return;
    }

    final attributes = _safeAttributes(node, tag);
    final openingTag = attributes.isEmpty
        ? '<$tag>'
        : '<$tag ${attributes.join(' ')}>';
    if (_voidTags.contains(tag)) {
      writer.writeToken(openingTag);
      return;
    }

    final closingTag = '</$tag>';
    if (!writer.openElement(openingTag, closingTag)) return;
    for (final child in node.nodes) {
      _serializeNode(child, writer, depth: depth + 1);
      if (writer.truncated) break;
    }
    writer.closeElement(closingTag);
  }

  static List<String> _safeAttributes(Element element, String tag) {
    if (tag != 'td' && tag != 'th') return const [];
    final result = <String>[];
    for (final name in const ['rowspan', 'colspan']) {
      final rawValue = element.attributes[name]?.trim();
      final value = int.tryParse(rawValue ?? '');
      if (value == null || value < 1 || value > 1000) continue;
      result.add('$name="${_attributeEscape.convert('$value')}"');
    }
    return result;
  }

  static String _normalizeText(String source) {
    return source.replaceAll(RegExp(r'[\s\u00a0]+'), ' ');
  }
}

class _BoundedHtmlWriter {
  _BoundedHtmlWriter(this.maxLength);

  final int maxLength;
  final StringBuffer _buffer = StringBuffer();
  int _reservedClosingLength = 0;
  bool truncated = false;

  void markTruncated() {
    truncated = true;
  }

  bool openElement(String openingTag, String closingTag) {
    if (!_canWrite(openingTag.length + closingTag.length)) {
      truncated = true;
      return false;
    }
    _buffer.write(openingTag);
    _reservedClosingLength += closingTag.length;
    return true;
  }

  void closeElement(String closingTag) {
    _reservedClosingLength -= closingTag.length;
    _buffer.write(closingTag);
  }

  void writeToken(String token) {
    if (!_canWrite(token.length)) {
      truncated = true;
      return;
    }
    _buffer.write(token);
  }

  void writeText(String text) {
    for (final rune in text.runes) {
      final escaped = SchoolImportContentSanitizer._textEscape.convert(
        String.fromCharCode(rune),
      );
      if (!_canWrite(escaped.length)) {
        truncated = true;
        return;
      }
      _buffer.write(escaped);
    }
  }

  bool _canWrite(int length) {
    return _buffer.length + _reservedClosingLength + length <= maxLength;
  }

  @override
  String toString() => _buffer.toString();
}
