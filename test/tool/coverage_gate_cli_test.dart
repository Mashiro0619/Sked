import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CLI reads git changes, writes artifacts, and returns gate status',
    () async {
      final repository = await Directory.systemTemp.createTemp(
        'sked-coverage-gate-',
      );
      final script = File('tool/coverage_gate.dart').absolute.path;
      try {
        await _runChecked('git', <String>['init'], repository.path);
        await _runChecked('git', <String>[
          'config',
          'user.email',
          'coverage-gate@example.invalid',
        ], repository.path);
        await _runChecked('git', <String>[
          'config',
          'user.name',
          'Coverage Gate Test',
        ], repository.path);

        final source = File(
          '${repository.path}${Platform.pathSeparator}lib'
          '${Platform.pathSeparator}feature.dart',
        );
        await source.parent.create(recursive: true);
        await source.writeAsString('void oldImplementation() {}\n');
        for (final path in _coverageUnavailableSourcePaths) {
          final file = File(
            '${repository.path}${Platform.pathSeparator}'
            '${path.replaceAll('/', Platform.pathSeparator)}',
          );
          await file.parent.create(recursive: true);
          await file.writeAsString('// No executable VM coverage.\n');
        }
        await _runChecked('git', <String>['add', 'lib'], repository.path);
        await _runChecked('git', <String>[
          'commit',
          '-m',
          'base',
        ], repository.path);
        final base = (await _runChecked('git', <String>[
          'rev-parse',
          'HEAD',
        ], repository.path)).stdout.toString().trim();

        await source.writeAsString('void newImplementation() {}\n');
        await _runChecked('git', <String>[
          'add',
          'lib/feature.dart',
        ], repository.path);
        await _runChecked('git', <String>[
          'commit',
          '-m',
          'head',
        ], repository.path);

        final lcov = File(
          '${repository.path}${Platform.pathSeparator}lcov.info',
        );
        final filtered =
            '${repository.path}${Platform.pathSeparator}filtered.info';
        final report = '${repository.path}${Platform.pathSeparator}report.txt';
        await lcov.writeAsString(_lcov(hitCount: 1));

        final passing = await Process.run(_dartExecutable, <String>[
          script,
          '--base-ref',
          base,
          '--head-ref',
          'HEAD',
          '--lcov',
          lcov.path,
          '--output',
          filtered,
          '--report',
          report,
          '--minimum-total',
          '0',
          '--minimum-diff',
          '100',
        ], workingDirectory: repository.path);

        expect(passing.exitCode, 0, reason: passing.stderr.toString());
        expect(passing.stdout, contains('Result: PASS'));
        expect(
          await File(filtered).readAsString(),
          contains('SF:lib/feature.dart'),
        );
        expect(await File(report).readAsString(), contains('Diff: 1/1'));

        await lcov.writeAsString(_lcov(hitCount: 0));
        final failing = await Process.run(_dartExecutable, <String>[
          script,
          '--base-ref',
          base,
          '--head-ref',
          'HEAD',
          '--lcov',
          lcov.path,
          '--output',
          filtered,
          '--report',
          report,
          '--minimum-total',
          '0',
          '--minimum-diff',
          '100',
          '--github-annotations',
        ], workingDirectory: repository.path);

        expect(failing.exitCode, 1, reason: failing.stderr.toString());
        expect(failing.stdout, contains('Result: FAIL'));
        expect(
          failing.stdout,
          contains(
            '::error file=lib/feature.dart,line=1::Changed executable line is '
            'not covered.',
          ),
        );
        expect(await File(report).readAsString(), contains('Result: FAIL'));

        final baseline = File(
          '${repository.path}${Platform.pathSeparator}baseline.info',
        );
        await baseline.writeAsString(
          _lcov(hitCount: 1, sourcePath: source.absolute.path),
        );
        final regressedTotal = await Process.run(_dartExecutable, <String>[
          script,
          '--base-ref',
          base,
          '--head-ref',
          'HEAD',
          '--lcov',
          lcov.path,
          '--baseline-lcov',
          baseline.path,
          '--baseline-root',
          repository.path,
          '--output',
          filtered,
          '--report',
          report,
          '--minimum-total',
          '0',
          '--minimum-diff',
          '0',
        ], workingDirectory: repository.path);

        expect(
          regressedTotal.exitCode,
          1,
          reason: regressedTotal.stderr.toString(),
        );
        expect(regressedTotal.stdout, contains('Base snapshot: 1/1'));
        expect(regressedTotal.stdout, contains('Total: 0/1'));

        final unmeasured = File(
          '${repository.path}${Platform.pathSeparator}lib'
          '${Platform.pathSeparator}unmeasured.dart',
        );
        await unmeasured.writeAsString('void neverMeasured() {}\n');
        await _runChecked('git', <String>[
          'add',
          'lib/unmeasured.dart',
        ], repository.path);
        await _runChecked('git', <String>[
          'commit',
          '-m',
          'add unmeasured source',
        ], repository.path);

        final missingUnchangedSource = await Process.run(
          _dartExecutable,
          <String>[
            script,
            '--base-ref',
            'HEAD',
            '--head-ref',
            'HEAD',
            '--lcov',
            lcov.path,
            '--output',
            filtered,
            '--report',
            report,
            '--minimum-total',
            '0',
            '--minimum-diff',
            '0',
            '--github-annotations',
          ],
          workingDirectory: repository.path,
        );

        expect(missingUnchangedSource.exitCode, 1);
        expect(
          missingUnchangedSource.stdout,
          contains('Handwritten sources missing from LCOV'),
        );
        expect(
          missingUnchangedSource.stdout,
          contains('::error file=lib/unmeasured.dart,line=1::'),
        );
      } finally {
        await repository.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}

Future<ProcessResult> _runChecked(
  String executable,
  List<String> arguments,
  String workingDirectory,
) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    fail(
      '$executable ${arguments.join(' ')} failed (${result.exitCode}):\n'
      '${result.stderr}',
    );
  }
  return result;
}

String _lcov({required int hitCount, String sourcePath = 'lib/feature.dart'}) =>
    '''
SF:$sourcePath
DA:1,$hitCount
LF:1
LH:${hitCount > 0 ? 1 : 0}
end_of_record
''';

String get _dartExecutable => Platform.isWindows ? 'dart.bat' : 'dart';

const _coverageUnavailableSourcePaths = <String>[
  'lib/l10n/app_localization_delegates.dart',
  'lib/models/timetable_models.dart',
  'lib/services/app_backup_restore_journal_factory_stub.dart',
  'lib/services/app_instance_lease.dart',
  'lib/services/app_instance_lease_stub.dart',
  'lib/services/app_instance_web_lock.dart',
  'lib/services/app_instance_web_lock_browser.dart',
  'lib/services/app_storage_layout.dart',
  'lib/services/app_storage_layout_stub.dart',
  'lib/theme/app_motion.dart',
  'lib/utils/constants.dart',
  'lib/widgets/app_layout_tokens.dart',
  'lib/services/app_data_clear_service.dart',
  'lib/services/app_data_clear_service_stub.dart',
  'lib/services/app_exit_controller.dart',
  'lib/services/app_exit_controller_stub.dart',
  'lib/services/app_exit_controller_io.dart',
];
