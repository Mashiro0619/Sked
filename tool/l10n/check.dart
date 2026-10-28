import 'dart:convert';
import 'dart:io';

import 'arb_audit.dart';

const _usage =
    'Usage: dart tool/l10n/check.dart [--arb-dir DIRECTORY] [--json]';

void main(List<String> arguments) {
  var directory = Directory.fromUri(Platform.script.resolve('../../lib/l10n/'));
  var json = false;
  for (var index = 0; index < arguments.length; index++) {
    switch (arguments[index]) {
      case '--help':
        stdout.writeln(_usage);
        return;
      case '--json':
        json = true;
      case '--arb-dir':
        if (++index >= arguments.length || arguments[index].startsWith('--')) {
          stderr.writeln(_usage);
          exitCode = 64;
          return;
        }
        directory = Directory(arguments[index]).absolute;
      default:
        stderr.writeln(_usage);
        exitCode = 64;
        return;
    }
  }
  final report = auditArbDirectory(directory);
  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
  } else {
    stdout.writeln(
      'Localization audit ${report.passed ? 'passed' : 'failed'}: '
      '${report.localeCount} locale files, ${report.templateMessageCount} template messages.',
    );
    for (final issue in report.issues) {
      stdout.writeln(issue);
    }
    stdout.writeln(
      'This checks registered structure and English fallback rules, not native-language review.',
    );
  }
  exitCode = report.passed ? 0 : 1;
}
