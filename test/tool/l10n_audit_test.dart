import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/l10n/arb_audit.dart';
import '../../tool/l10n/translation_policy.dart';

void main() {
  const template = <String, Object?>{'title': 'Title', 'body': 'Current body'};

  List<L10nIssue> audit(
    Map<String, Object?> messages, {
    String locale = 'de',
    Set<String> allowed = const {},
  }) => auditArbLocale(
    locale: locale,
    template: template,
    messages: messages,
    allowedFallbacks: allowed,
    retiredEnglish: const {
      'body': {'Old English body'},
    },
  );

  test('missing messages require an explicit fallback', () {
    expect(audit({'title': 'Titel'}).single.code, 'missing_message');
    expect(audit({'title': 'Titel'}, allowed: {'body'}), isEmpty);
  });

  test('fallbacks cannot conceal blank, null or non-string values', () {
    for (final invalid in <Object?>[' ', null, 4, <Object>[]]) {
      expect(
        audit(
          {'title': 'Titel', 'body': invalid},
          allowed: {'body'},
        ).single.code,
        'invalid_message',
      );
    }
  });

  test('unknown source keys and misspelled fallback keys fail visibly', () {
    expect(
      audit(
        {'title': 'Titel', 'body': 'Inhalt', 'typo': 'Value'},
        allowed: {'typo'},
      ).map((issue) => issue.code),
      ['unknown_fallback', 'unknown_message'],
    );
  });

  test('known retired English is rejected after whitespace and case edits', () {
    final result = audit({'title': 'Titel', 'body': ' OLD  ENGLISH\nbody '});
    expect(result.single.code, 'retired_english');
    expect(result.single.key, 'body');
  });

  test('copied current English cannot become the next stale fallback', () {
    expect(
      audit(
        {'title': 'Titel', 'body': 'Current body'},
        allowed: {'body'},
      ).single.code,
      'copied_english_fallback',
    );
  });

  test('adding an actual translation remains allowed', () {
    expect(
      audit({'title': 'Titel', 'body': 'Aktueller Inhalt'}, allowed: {'body'}),
      isEmpty,
    );
  });

  test(
    'English template, metadata and shared words are not language guesses',
    () {
      expect(
        audit(
          {'title': 'Title', 'body': 'Current body'},
          locale: 'en',
          allowed: {'body'},
        ),
        isEmpty,
      );
      expect(
        audit({
          'title': 'Title',
          'body': 'Version',
          '@body': {'description': 'English metadata'},
        }),
        isEmpty,
      );
    },
  );

  test('Chinese variants cannot acquire the common English fallback list', () {
    expect(allowedFallbacksForLocale('zh'), isEmpty);
    expect(allowedFallbacksForLocale('zh_Hant'), isEmpty);
    expect(allowedFallbacksForLocale('zh-Hant'), isEmpty);
    expect(allowedFallbacksForLocale('en'), isEmpty);
    expect(
      allowedFallbacksForLocale('de'),
      isNot(contains('privacyPolicyEntryDesc')),
    );
    expect(allowedFallbacksForLocale('nl'), contains('privacyPolicyEntryDesc'));
  });

  test(
    'directory validation reports malformed and missing offered locales',
    () {
      final root = Directory.systemTemp.createTempSync('sked-l10n-audit-');
      addTearDown(() => root.deleteSync(recursive: true));
      File.fromUri(root.uri.resolve('app_en.arb')).writeAsStringSync('[]');
      File.fromUri(root.uri.resolve('app_extra.arb')).writeAsStringSync('{}');
      final report = auditArbDirectory(root, expectedLocales: {'en', 'zh'});
      expect(report.passed, isFalse);
      expect(
        report.issues.map((issue) => issue.code),
        containsAll(['invalid_arb', 'missing_locale', 'unregistered_locale']),
      );
      expect(report.toJson()['status'], 'fail');
    },
  );

  test('missing directories are reported instead of throwing', () {
    final root = Directory.systemTemp.createTempSync('sked-l10n-audit-');
    addTearDown(() => root.deleteSync(recursive: true));
    expect(
      auditArbDirectory(Directory.fromUri(root.uri.resolve('missing/')))
          .issues
          .single
          .code,
      'missing_directory',
    );
  });

  test(
    'CLI passes a complete copy and fails an unregistered missing message',
    () async {
      final root = Directory.systemTemp.createTempSync('sked-l10n-cli-');
      addTearDown(() => root.deleteSync(recursive: true));
      for (final locale in offeredLocaleCodes) {
        File('lib/l10n/app_$locale.arb')
            .copySync(root.uri.resolve('app_$locale.arb').toFilePath());
      }
      Future<ProcessResult> run() => Process.run(
        Platform.isWindows ? 'dart.bat' : 'dart',
        ['tool/l10n/check.dart', '--arb-dir', root.path, '--json'],
        runInShell: Platform.isWindows,
      );
      final passing = await run();
      expect(
        passing.exitCode,
        0,
        reason: '${passing.stdout}\n${passing.stderr}',
      );
      final validReport =
          jsonDecode(passing.stdout as String) as Map<String, dynamic>;
      expect(validReport['status'], 'pass');
      expect(validReport['localeCount'], offeredLocaleCodes.length);
      expect(validReport['issues'], isEmpty);
      final germanFile = File.fromUri(root.uri.resolve('app_de.arb'));
      final german = readArbMessages(germanFile)..remove('cancel');
      germanFile.writeAsStringSync(jsonEncode(german));
      final failing = await run();
      expect(
        failing.exitCode,
        1,
        reason: '${failing.stdout}\n${failing.stderr}',
      );
      final report =
          jsonDecode(failing.stdout as String) as Map<String, dynamic>;
      expect(report['status'], 'fail');
      final issues = report['issues'] as List<dynamic>;
      expect(issues.single, containsPair('key', 'cancel'));
      expect(issues.single, containsPair('code', 'missing_message'));
    },
  );
}
