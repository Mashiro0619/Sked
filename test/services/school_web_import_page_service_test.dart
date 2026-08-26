import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';
import 'package:sked/services/school_web_import_page_service.dart';

void main() {
  group('normalizeJavaScriptResult', () {
    test('treats null-like JavaScript results as empty content', () {
      expect(normalizeJavaScriptResult(null), '');
      expect(normalizeJavaScriptResult('null'), '');
      expect(normalizeJavaScriptResult(' undefined '), '');
    });

    test('decodes quoted JavaScript string results', () {
      expect(
        normalizeJavaScriptResult(r'"<html>\n<body>课表</body></html>"'),
        '<html>\n<body>课表</body></html>',
      );
    });

    test('keeps already-decoded string results unchanged', () {
      const html = '<html><body>Timetable</body></html>';

      expect(normalizeJavaScriptResult(html), html);
    });
  });

  group('webpage extraction boundary', () {
    test(
      'script traverses a bounded live DOM and captures fields atomically',
      () {
        final script = SchoolWebImportPageService.extractImportSourceScript;

        expect(script, contains('MAX_CONTENT'));
        expect(script, contains('MAX_NODES'));
        expect(script, contains('MAX_SCANNED_TEXT'));
        expect(script, contains('scannedTextCharacters'));
        expect(
          script,
          contains(SchoolWebImportPageService.extractionProtocolPrefix.trim()),
        );
        expect(script, contains('return PROTOCOL +'));
        expect(script, contains('safeOrigin.length'));
        expect(script, contains("typeof value !== 'string'"));
        expect(script, isNot(contains('String(')));
        expect(script, isNot(contains('.replace(')));
        expect(script, isNot(contains('new Set(')));
        expect(script, isNot(contains('for (const character of')));
        expect(script, contains(r"character >= '\uD800'"));
        expect(script, contains(r"character = '\uFFFD'"));
        expect(script, isNot(contains('return JSON.stringify(')));
        expect(script, isNot(contains('output.trim()')));
        expect(script, contains('truncated'));
        expect(script, isNot(contains('cloneNode')));
        expect(script, isNot(contains('outerHTML')));
        expect(script, isNot(contains('location.search')));
        expect(script, isNot(contains('location.hash')));
        expect(script, isNot(contains('location.pathname')));
        expect(script, isNot(contains('value.replace')));
      },
    );

    test('decodes the bounded primitive extraction protocol atomically', () {
      const content = '<table><tr><td>Math 😀</td></tr></table>';
      const origin = 'https://school.example.test';
      const title = 'Spring timetable 😀';
      final encoded = _encodeExtractionProtocol(
        content: content,
        origin: origin,
        title: title,
        truncated: true,
      );

      for (final result in <Object>[encoded, jsonEncode(encoded)]) {
        final payload = decodeSchoolWebImportExtraction(
          result,
          fallbackUrl: 'https://fallback.example.test/private?token=1',
          fallbackTitle: 'Fallback',
        );

        expect(payload.content, content);
        expect(payload.url, origin);
        expect(payload.title, title);
        expect(payload.wasTruncated, isTrue);
      }
    });

    test('rejects malformed or over-limit primitive protocol fields', () {
      final valid = _encodeExtractionProtocol(
        content: '<p>Schedule</p>',
        origin: 'https://school.test',
        title: 'Title',
        truncated: false,
      );
      final wrongContentLength = valid.replaceFirst(
        '${'<p>Schedule</p>'.length}\n',
        '${'<p>Schedule</p>'.length + 1}\n',
      );
      final oversizedOriginLength =
          '${SchoolWebImportPageService.extractionProtocolPrefix}'
          '1\n${SchoolWebImportPageService.maxSourceOriginLength + 1}\n'
          '0\n0\nx';

      for (final result in [wrongContentLength, oversizedOriginLength]) {
        expect(
          () => decodeSchoolWebImportExtraction(
            result,
            fallbackUrl: '',
            fallbackTitle: '',
          ),
          throwsA(isA<FormatException>()),
        );
      }
    });

    test('only exposes the content extraction script', () {
      final script = SchoolWebImportPageService.extractImportSourceScript;

      expect(script, contains('document.documentElement'));
      expect(script, isNot(contains('HTMLFormElement.prototype.submit')));
      expect(
        script,
        isNot(contains('HTMLFormElement.prototype.requestSubmit')),
      );
      expect(script, isNot(contains("document.addEventListener('submit'")));
      expect(script, isNot(contains('event.preventDefault()')));
      expect(script, isNot(contains('flutter_inappwebview.callHandler')));
      expect(script, isNot(contains('skedConfirmNavigationOrigin')));
    });

    test('decodes one atomic result and removes URL secrets', () {
      final payload = decodeSchoolWebImportExtraction(
        jsonEncode({
          'content': '<table><tr><td>Math</td></tr></table>',
          'url': 'https://user:secret@school.example.test:443/timetable?token=sso#week',
          'title': 'Spring timetable',
          'truncated': true,
        }),
        fallbackUrl: 'https://fallback.example.test/path?secret=1',
        fallbackTitle: 'Fallback',
      );

      expect(payload.content, contains('Math'));
      expect(payload.url, 'https://school.example.test');
      expect(payload.title, 'Spring timetable');
      expect(payload.wasTruncated, isTrue);
    });

    test('supports map results and sanitizes fallback URL', () {
      final payload = decodeSchoolWebImportExtraction(
        {
          'content': '<p>Schedule</p>',
          'url': 'not a URL',
          'title': '',
          'truncated': false,
        },
        fallbackUrl: 'http://school.test:8080/page?ticket=secret#fragment',
        fallbackTitle: 'Fallback title',
      );

      expect(payload.url, 'http://school.test:8080');
      expect(payload.title, isEmpty);
      expect(payload.wasTruncated, isFalse);
    });

    test('removes path-based session identifiers from source URLs', () {
      expect(
        sanitizeSchoolImportSourceUrl(
          'https://school.test/app;jsessionid=SECRET/timetable',
        ),
        'https://school.test',
      );
      expect(
        sanitizeSchoolImportSourceUrl(
          'https://school.test/timetable/session/SECRET',
        ),
        'https://school.test',
      );
    });

    test(
      'uses the fallback title only when atomic capture omitted the field',
      () {
        final payload = decodeSchoolWebImportExtraction(
          {'content': '<p>Schedule</p>', 'url': 'https://school.test'},
          fallbackUrl: 'https://fallback.test',
          fallbackTitle: 'Fallback title',
        );

        expect(payload.title, 'Fallback title');
      },
    );

    test('rejects empty, malformed, and oversized platform results', () {
      expect(
        () => decodeSchoolWebImportExtraction(
          jsonEncode({'content': '', 'url': '', 'title': ''}),
          fallbackUrl: '',
          fallbackTitle: '',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import content is empty.',
          ),
        ),
      );
      expect(
        () => decodeSchoolWebImportExtraction(
          'not json',
          fallbackUrl: '',
          fallbackTitle: '',
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => decodeSchoolWebImportExtraction(
          jsonEncode({
            'content':
                'x' * (SchoolImportContentSanitizer.maxContentLength + 1),
            'url': '',
            'title': '',
          }),
          fallbackUrl: '',
          fallbackTitle: '',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Import page content is too large.',
          ),
        ),
      );
    });
  });
}

String _encodeExtractionProtocol({
  required String content,
  required String origin,
  required String title,
  required bool truncated,
}) {
  return '${SchoolWebImportPageService.extractionProtocolPrefix}'
      '${content.length}\n'
      '${origin.length}\n'
      '${title.length}\n'
      '${truncated ? 1 : 0}\n'
      '$content$origin$title';
}
