import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

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
    final fragment = html_parser.parseFragment(source);
    final output = StringBuffer();
    final pending = <({Node? node, String? closing})>[
      for (final node in fragment.nodes.reversed) (node: node, closing: null),
    ];
    while (pending.isNotEmpty) {
      final entry = pending.removeLast();
      if (entry.closing case final closing?) {
        output.write(closing);
        continue;
      }
      final node = entry.node;
      if (node is Text) {
        output.write(_textEscape.convert(_normalizeText(node.data)));
        continue;
      }
      if (node is! Element) continue;
      final tag = node.localName?.toLowerCase() ?? '';
      if (_discardedTags.contains(tag)) continue;
      if (_allowedTags.contains(tag)) {
        final attributes = _safeAttributes(node, tag);
        output.write(
          attributes.isEmpty ? '<$tag>' : '<$tag ${attributes.join(' ')}>',
        );
        if (_voidTags.contains(tag)) continue;
        pending.add((node: null, closing: '</$tag>'));
      }
      for (final child in node.nodes.reversed) {
        pending.add((node: child, closing: null));
      }
    }
    return SchoolImportSanitizationResult(
      content: output.toString().trim(),
      wasTruncated: false,
    );
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
