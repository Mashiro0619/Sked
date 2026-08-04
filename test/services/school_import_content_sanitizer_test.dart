import 'package:flutter_test/flutter_test.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';

void main() {
  group('SchoolImportContentSanitizer', () {
    test('preserves table span attributes used by timetable layouts', () {
      const source = '''
<table>
  <tr>
    <td class="course" rowspan="2" colspan="3" onclick="x()">Math</td>
  </tr>
</table>
''';

      final sanitized = SchoolImportContentSanitizer.sanitize(source);

      expect(sanitized, contains('rowspan="2"'));
      expect(sanitized, contains('colspan="3"'));
      expect(sanitized, isNot(contains('class=')));
      expect(sanitized, isNot(contains('onclick=')));
    });

    test('removes script blocks and caps very large content', () {
      final oversizedText = List.filled(
        SchoolImportContentSanitizer.maxContentLength + 10,
        'A',
      ).join();
      final source = '<script>alert(1)</script>$oversizedText';

      final sanitized = SchoolImportContentSanitizer.sanitize(source);

      expect(sanitized, isNot(contains('alert')));
      expect(sanitized.length, SchoolImportContentSanitizer.maxContentLength);
    });

    test('removes dangling unsafe block tags', () {
      const source = '''
<table><tr><td>Math</td></tr></table>
<script>window.leak = "not timetable";
''';

      final sanitized = SchoolImportContentSanitizer.sanitize(source);

      expect(sanitized, contains('Math'));
      expect(sanitized, isNot(contains('window.leak')));
      expect(sanitized, isNot(contains('not timetable')));
    });

    test('uses a structural allowlist and safely unwraps unknown elements', () {
      const source = '''
<custom-shell data-secret="token">
  <a href="javascript:alert(1)" onmouseover="steal()">Course &amp; Lab</a>
  <table><tr><th rowspan="0002" colspan="bad">Time</th></tr></table>
</custom-shell>
''';

      final sanitized = SchoolImportContentSanitizer.sanitize(source);

      expect(sanitized, contains('Course &amp; Lab'));
      expect(sanitized, contains('<table>'));
      expect(sanitized, contains('rowspan="2"'));
      expect(sanitized, isNot(contains('custom-shell')));
      expect(sanitized, isNot(contains('href')));
      expect(sanitized, isNot(contains('javascript')));
      expect(sanitized, isNot(contains('onmouseover')));
      expect(sanitized, isNot(contains('colspan')));
    });

    test('does not turn encoded markup into executable elements', () {
      const source = '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>';

      final sanitized = SchoolImportContentSanitizer.sanitize(source);

      expect(sanitized, '<p>&lt;script&gt;alert(1)&lt;/script&gt;</p>');
      expect(sanitized, isNot(contains('<script>')));
    });

    test('unwraps form elements without discarding timetable content', () {
      const source =
          '<form action="/login"><table><tr><td>Math</td></tr></table></form>';

      final sanitized = SchoolImportContentSanitizer.sanitize(source);

      expect(sanitized, '<table><tbody><tr><td>Math</td></tr></tbody></table>');
      expect(sanitized, isNot(contains('<form')));
    });

    test('does not expose discarded content beyond the tree depth limit', () {
      final source =
          '${List.filled(64, '<div>').join()}'
          '<section>visible<script>secret-script</script>'
          '<style>secret-style</style><textarea>secret-input</textarea></section>'
          '${List.filled(64, '</div>').join()}';

      final result = SchoolImportContentSanitizer.sanitizeWithResult(source);

      expect(result.content, isNot(contains('secret-script')));
      expect(result.content, isNot(contains('secret-style')));
      expect(result.content, isNot(contains('secret-input')));
      expect(result.wasTruncated, isTrue);
    });

    test(
      'safely truncates extremely deep trees without overflowing the stack',
      () {
        final source =
            '${List.filled(5000, '<div>').join()}'
            'deep content'
            '${List.filled(5000, '</div>').join()}';

        late SchoolImportSanitizationResult result;
        expect(
          () =>
              result = SchoolImportContentSanitizer.sanitizeWithResult(source),
          returnsNormally,
        );
        expect(result.wasTruncated, isTrue);
        expect(
          RegExp('<div>').allMatches(result.content).length,
          RegExp('</div>').allMatches(result.content).length,
        );
      },
    );

    test('bounded serialization keeps opened table elements balanced', () {
      final source =
          '<table><tbody><tr><td>${'A' * (SchoolImportContentSanitizer.maxContentLength * 2)}</td></tr></tbody></table>';

      final result = SchoolImportContentSanitizer.sanitizeWithResult(source);
      final sanitized = result.content;

      expect(
        sanitized.length,
        lessThanOrEqualTo(SchoolImportContentSanitizer.maxContentLength),
      );
      expect(sanitized, startsWith('<table><tbody><tr><td>'));
      expect(sanitized, endsWith('</td></tr></tbody></table>'));
      expect(result.wasTruncated, isTrue);
    });

    test('reports truncation even when the output stops below its limit', () {
      final source =
          '${'A' * (SchoolImportContentSanitizer.maxContentLength - 3)}<hr>rest';

      final result = SchoolImportContentSanitizer.sanitizeWithResult(source);

      expect(
        result.content.length,
        lessThan(SchoolImportContentSanitizer.maxContentLength),
      );
      expect(result.wasTruncated, isTrue);
    });
  });
}
