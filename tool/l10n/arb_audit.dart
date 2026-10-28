import 'dart:convert';
import 'dart:io';

import 'translation_policy.dart';

class L10nIssue {
  const L10nIssue(this.locale, this.key, this.code, this.detail);

  final String locale;
  final String key;
  final String code;
  final String detail;

  Map<String, String> toJson() => {
    'locale': locale,
    'key': key,
    'code': code,
    'detail': detail,
  };

  @override
  String toString() => '$locale:$key [$code] $detail';
}

String _normalizedCopy(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

Set<String> _messageKeys(Map<String, Object?> messages) =>
    messages.keys.where((key) => !key.startsWith('@')).toSet();

/// Checks structure and explicitly registered English copies. This does not
/// infer translation quality from Latin letters, word counts or plural syntax.
List<L10nIssue> auditArbLocale({
  required String locale,
  required Map<String, Object?> template,
  required Map<String, Object?> messages,
  Set<String> allowedFallbacks = const {},
  Map<String, Set<String>> retiredEnglish = retiredEnglishMessages,
}) {
  final issues = <L10nIssue>[];
  final expected = _messageKeys(template);
  for (final key in allowedFallbacks.difference(expected).toList()..sort()) {
    issues.add(
      L10nIssue(
        locale,
        key,
        'unknown_fallback',
        'Fallback key is not in the English template.',
      ),
    );
  }
  for (final key in _messageKeys(
    messages,
  ).difference(expected).toList()..sort()) {
    issues.add(
      L10nIssue(
        locale,
        key,
        'unknown_message',
        'Message key is not in the English template.',
      ),
    );
  }
  for (final key in expected.toList()..sort()) {
    if (!messages.containsKey(key)) {
      if (!allowedFallbacks.contains(key)) {
        issues.add(
          L10nIssue(
            locale,
            key,
            'missing_message',
            'Message is missing and has no explicit English fallback.',
          ),
        );
      }
      continue;
    }
    final value = messages[key];
    if (value is! String || value.trim().isEmpty) {
      issues.add(
        L10nIssue(
          locale,
          key,
          'invalid_message',
          'Message must be a nonempty string.',
        ),
      );
      continue;
    }
    if (locale == 'en') continue;
    final normalized = _normalizedCopy(value);
    if (retiredEnglish[key]?.any((old) => _normalizedCopy(old) == normalized) ==
        true) {
      issues.add(
        L10nIssue(
          locale,
          key,
          'retired_english',
          'This is a confirmed retired English copy; translate it or use an explicit current fallback.',
        ),
      );
    }
    final currentEnglish = template[key];
    if (allowedFallbacks.contains(key) &&
        currentEnglish is String &&
        normalized == _normalizedCopy(currentEnglish)) {
      issues.add(
        L10nIssue(
          locale,
          key,
          'copied_english_fallback',
          'Remove the copied value so generation follows the current English template.',
        ),
      );
    }
  }
  return issues;
}

Map<String, Object?> readArbMessages(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('An ARB must contain a JSON object.');
  }
  return decoded;
}

class L10nAuditReport {
  const L10nAuditReport({
    required this.templateMessageCount,
    required this.localeCount,
    required this.allowedMissingMessages,
    required this.issues,
  });

  final int templateMessageCount;
  final int localeCount;
  final Map<String, int> allowedMissingMessages;
  final List<L10nIssue> issues;
  bool get passed => issues.isEmpty;

  Map<String, Object?> toJson() => {
    'status': passed ? 'pass' : 'fail',
    'templateMessageCount': templateMessageCount,
    'localeCount': localeCount,
    'allowedMissingMessages': allowedMissingMessages,
    'issues': issues.map((issue) => issue.toJson()).toList(),
  };
}

L10nAuditReport auditArbDirectory(
  Directory directory, {
  Set<String> expectedLocales = offeredLocaleCodes,
}) {
  final sources = <String, Map<String, Object?>>{};
  final issues = <L10nIssue>[];
  final fallbacks = <String, int>{};
  if (!directory.existsSync()) {
    return L10nAuditReport(
      templateMessageCount: 0,
      localeCount: 0,
      allowedMissingMessages: const {},
      issues: [
        L10nIssue(
          '*',
          '',
          'missing_directory',
          'ARB directory does not exist: ${directory.path}',
        ),
      ],
    );
  }
  final localePattern = RegExp(r'^app_(.+)\.arb$');
  for (final file in directory.listSync(followLinks: false).whereType<File>()) {
    final name = file.uri.pathSegments.last;
    final locale = localePattern.firstMatch(name)?.group(1);
    if (locale != null && !expectedLocales.contains(locale)) {
      issues.add(
        L10nIssue(
          locale,
          '',
          'unregistered_locale',
          'Register an offered locale before adding its ARB.',
        ),
      );
    }
  }
  for (final locale in expectedLocales.toList()..sort()) {
    final file = File.fromUri(directory.uri.resolve('app_$locale.arb'));
    if (!file.existsSync()) {
      issues.add(
        L10nIssue(
          locale,
          '',
          'missing_locale',
          'The offered locale has no ARB file.',
        ),
      );
      continue;
    }
    try {
      sources[locale] = readArbMessages(file);
    } on FormatException {
      issues.add(
        L10nIssue(
          locale,
          '',
          'invalid_arb',
          'ARB must be a valid JSON object.',
        ),
      );
    } on FileSystemException {
      issues.add(
        L10nIssue(locale, '', 'unreadable_arb', 'ARB file could not be read.'),
      );
    }
  }
  final template = sources['en'];
  if (template != null) {
    for (final entry in sources.entries) {
      final allowed = allowedFallbacksForLocale(entry.key);
      issues.addAll(
        auditArbLocale(
          locale: entry.key,
          template: template,
          messages: entry.value,
          allowedFallbacks: allowed,
        ),
      );
      fallbacks[entry.key] = _messageKeys(template)
          .difference(entry.value.keys.toSet())
          .intersection(allowed)
          .length;
    }
  } else if (!expectedLocales.contains('en')) {
    issues.add(
      const L10nIssue(
        'en',
        '',
        'missing_template',
        'English must be included as the template locale.',
      ),
    );
  }
  return L10nAuditReport(
    templateMessageCount: template == null ? 0 : _messageKeys(template).length,
    localeCount: sources.length,
    allowedMissingMessages: Map.unmodifiable(fallbacks),
    issues: List.unmodifiable(issues),
  );
}
