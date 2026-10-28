import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final workflow = loadYaml(
    File('.github/workflows/flutter.yml').readAsStringSync(),
  ) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;

  List<YamlMap> stepsFor(String job) =>
      ((jobs[job] as YamlMap)['steps'] as YamlList).cast<YamlMap>().toList();

  YamlMap stepNamed(List<YamlMap> steps, String name) =>
      steps.singleWhere((step) => step['name'] == name);

  test('all Flutter jobs pin the same SDK and enforce dependency locks', () {
    String? sdkVersion;
    for (final job in jobs.keys.cast<String>()) {
      final steps = stepsFor(job);
      final flutterSetup = steps.where(
        (step) => (step['uses'] as String? ?? '').startsWith(
          'subosito/flutter-action@',
        ),
      );
      if (flutterSetup.isEmpty) continue;
      final setup = flutterSetup.single['with'] as YamlMap;
      final version = setup['flutter-version'] as String;
      expect(version, matches(r'^\d+\.\d+\.\d+$'), reason: job);
      sdkVersion ??= version;
      expect(version, sdkVersion, reason: job);
      expect(setup['channel'], 'stable', reason: job);
      expect(
        steps.any(
          (step) => step['run'] == 'flutter pub get --enforce-lockfile',
        ),
        isTrue,
        reason: job,
      );
    }
  });

  test(
    'quality checks resolve the internal plugin before formatting and analysis',
    () {
      final steps = stepsFor('checks');
      final pluginLock = stepNamed(steps, 'Verify internal plugin lockfile');
      expect(
        pluginLock['working-directory'],
        'packages/android_productivity_plugin',
      );
      expect(pluginLock['run'], 'flutter pub get --enforce-lockfile');
      expect(
        steps.indexOf(pluginLock),
        lessThan(steps.indexOf(stepNamed(steps, 'Check formatting'))),
      );
      expect(
        steps.indexOf(pluginLock),
        lessThan(steps.indexOf(stepNamed(steps, 'Analyze'))),
      );
    },
  );

  test(
    'named timezone checks cover indexed reminders and skipped civil dates',
    () {
      const zones = {
        'America/New_York': 'america-new-york',
        'Europe/Berlin': 'europe-berlin',
        'Asia/Shanghai': 'asia-shanghai',
        'America/Sao_Paulo': 'america-sao-paulo',
        'Pacific/Apia': 'pacific-apia',
      };
      final timezoneSteps = stepsFor('checks').where(
        (step) => (step['env'] as YamlMap?)?['SKED_DST_TEST_ZONE'] != null,
      );
      for (final zone in zones.entries) {
        final step = timezoneSteps.singleWhere(
          (step) => (step['env'] as YamlMap)['TZ'] == zone.key,
        );
        expect((step['env'] as YamlMap)['SKED_DST_TEST_ZONE'], zone.value);
        final command = (step['run'] as String).split(RegExp(r'\s+'));
        expect(command.take(2), ['flutter', 'test']);
        for (final path in [
          'test/named_timezone_indexed_reminder_test.dart',
          'test/models/general_event_occurrence_range_test.dart',
          'test/services/general_reminder_indexed_items_test.dart',
          'test/services/general_occurrence_cache_test.dart',
          'test/services/windows_agenda_notification_coverage_test.dart',
        ]) {
          expect(command, contains(path), reason: zone.key);
        }
        expect(
          command.contains('test/date_dst_regression_test.dart'),
          zone.key != 'Pacific/Apia',
          reason: 'The original suite supports the four original zones only.',
        );
      }
    },
  );

  test(
    'all VM tests run in four independent shards with retained coverage',
    () {
      final job = jobs['test-shards'] as YamlMap;
      expect(job['strategy']['fail-fast'], false);
      expect(job['strategy']['matrix']['shard'], [0, 1, 2, 3]);
      final steps = stepsFor('test-shards');
      final tests = stepNamed(steps, 'Test shard with coverage');
      expect(
        tests['run'],
        r'flutter test --no-pub --coverage --concurrency=2 --total-shards=4 --shard-index=${{ matrix.shard }}',
      );
      expect(tests['continue-on-error'], isNull);
      final upload = stepNamed(steps, 'Upload shard coverage');
      expect(upload['if'], r'${{ always() }}');
      expect(upload['with']['name'], r'coverage-shard-${{ matrix.shard }}');
      expect(upload['with']['path'], 'coverage/lcov.info');
      expect(upload['with']['if-no-files-found'], 'error');
      expect(steps.indexOf(upload), greaterThan(steps.indexOf(tests)));
    },
  );

  test(
    'a partial rerun retains successful shards and replaces its own report',
    () {
      final upload = stepNamed(
        stepsFor('test-shards'),
        'Upload shard coverage',
      );
      final download = stepNamed(
        stepsFor('coverage'),
        'Download shard coverage',
      );
      String render(String value, int shard, int attempt) => value
          .replaceAll(r'${{ matrix.shard }}', '$shard')
          .replaceAll(r'${{ github.run_attempt }}', '$attempt');
      final artifacts = <String, int>{};
      for (var shard = 0; shard < 4; shard++) {
        artifacts[render(upload['with']['name'] as String, shard, 1)] = shard;
      }
      artifacts[render(upload['with']['name'] as String, 2, 2)] = 20;
      final pattern = render(download['with']['pattern'] as String, 0, 2);
      final matches = RegExp(
        '^${RegExp.escape(pattern).replaceAll(r'\*', '.*')}\$',
      );
      final downloaded = artifacts.entries.where(
        (entry) => matches.hasMatch(entry.key),
      );
      expect(downloaded.map((entry) => entry.value).toList()..sort(), [
        0,
        1,
        3,
        20,
      ]);
      expect(upload['with']['overwrite'], isTrue);
      expect(download['with']['run-id'], isNull);
      expect(download['with']['repository'], isNull);
    },
  );

  test('coverage is combined only after downloading every distinct shard', () {
    final job = jobs['coverage'] as YamlMap;
    expect(job['needs'], 'test-shards');
    expect(job['if'], r'${{ always() && !cancelled() }}');
    final steps = stepsFor('coverage');
    final download = stepNamed(steps, 'Download shard coverage');
    expect(download['with']['pattern'], 'coverage-shard-*');
    expect(download['with']['merge-multiple'], false);
    expect(
      download['with']['path'],
      r'${{ runner.temp }}/sked-coverage-shards',
    );
    final merge = stepNamed(steps, 'Merge complete shard coverage');
    expect(
      merge['run'],
      r'dart tool/merge_lcov.dart "$RUNNER_TEMP/sked-coverage-shards" coverage/lcov.info 4',
    );
    final upload = stepNamed(steps, 'Upload coverage report');
    expect(
      upload['with']['name'],
      r'coverage-report-${{ github.run_attempt }}',
    );
    expect(upload['with']['if-no-files-found'], 'error');
    expect(steps.indexOf(download), lessThan(steps.indexOf(merge)));
    expect(steps.indexOf(merge), lessThan(steps.indexOf(upload)));
    expect(merge['continue-on-error'], isNull);
    expect(upload['if'], isNull);
  });

  test(
    'the existing test gate fails for incomplete or failed dependencies',
    () {
      final job = jobs['test'] as YamlMap;
      expect(job['needs'], ['checks', 'test-shards', 'coverage']);
      expect(job['if'], r'${{ always() }}');
      final gate = stepNamed(stepsFor('test'), 'Require all test results');
      expect(gate['shell'], 'bash');
      expect(gate['env']['CHECKS_RESULT'], r'${{ needs.checks.result }}');
      expect(gate['env']['SHARDS_RESULT'], r'${{ needs.test-shards.result }}');
      expect(gate['env']['COVERAGE_RESULT'], r'${{ needs.coverage.result }}');
      expect((gate['run'] as String).trim().split('\n'), [
        'set -eu',
        r'test "$CHECKS_RESULT" = success',
        r'test "$SHARDS_RESULT" = success',
        r'test "$COVERAGE_RESULT" = success',
      ]);
      expect(gate['continue-on-error'], isNull);
      final checks = stepsFor('checks');
      expect(
        stepNamed(checks, 'Test browser instance lease')['run'],
        'flutter test --platform chrome test/services/app_instance_lease_web_test.dart',
      );
      expect(
        stepNamed(checks, 'Build web release')['run'],
        'flutter build web --release',
      );
    },
  );

  test('release smoke builds use an isolated temporary CI signing key', () {
    final steps = stepsFor('android-build');
    final signing = stepNamed(steps, 'Prepare ephemeral CI signing key');
    final signingCommand = signing['run'] as String;
    expect(signingCommand, contains('umask 077'));
    expect(signingCommand, contains('openssl rand -hex'));
    expect(signingCommand, contains('::add-mask::'));
    expect(signingCommand, contains('keytool -genkeypair'));
    expect(signingCommand, contains(r'$RUNNER_TEMP/sked-ci-release.jks'));
    expect(signingCommand, contains('> android/key.properties'));
    expect(signingCommand, isNot(contains('secrets.')));

    for (final (name, command) in [
      ('Build Android APK release', 'flutter build apk --release'),
      (
        'Build Android App Bundle release',
        'flutter build appbundle --release --dart-define=SKED_DISTRIBUTION_CHANNEL=google-play',
      ),
    ]) {
      final build = stepNamed(steps, name);
      expect(build['run'], command);
      expect(steps.indexOf(signing), lessThan(steps.indexOf(build)));
    }
    final cleanup = stepNamed(steps, 'Remove ephemeral CI signing key');
    expect(cleanup['if'], 'always()');
    expect(cleanup['run'], contains('android/key.properties'));
    expect(cleanup['run'], contains(r'$RUNNER_TEMP/sked-ci-release.jks'));
    expect(steps.indexOf(cleanup), greaterThan(steps.indexOf(signing)));
  });

  test('the first Android build bootstraps all direct Gradle commands', () {
    final steps = stepsFor('android-build');
    final bootstrap = stepNamed(steps, 'Build Android APK release');
    expect(bootstrap['run'], 'flutter build apk --release');
    final gradleSteps = steps.where(
      (step) => (step['run'] as String? ?? '').contains('./gradlew'),
    );
    expect(gradleSteps, isNotEmpty);
    for (final step in gradleSteps) {
      expect(
        steps.indexOf(bootstrap),
        lessThan(steps.indexOf(step)),
        reason: 'A fresh checkout has no wrapper until Flutter builds Android.',
      );
    }
  });

  test('Android release runs native tests and verifies merged artifacts', () {
    final steps = stepsFor('android-build');
    final nativeTests = stepNamed(steps, 'Test Android native unit tests');
    expect(nativeTests['working-directory'], 'android');
    expect(nativeTests['run'], contains(':app:testDebugUnitTest'));
    expect(
      (stepNamed(steps, 'Upload Android native test report')['with']
          as YamlMap)['path'],
      'build/app/test-results/testDebugUnitTest/*.xml',
    );
    final artifactCheck = stepNamed(
      steps,
      'Verify release merged Android manifest',
    );
    expect(
      artifactCheck['run'],
      contains('platform_artifact_check.dart android-manifest'),
    );
    expect(artifactCheck['run'], contains('--application-id com.mashiro.sked'));
    expect(
      stepNamed(steps, 'Upload release Android security artifacts')['if'],
      contains('!cancelled()'),
    );
  });

  test('Windows CI builds both channels without submitting to the Store', () {
    final windowsJob = jobs.values.cast<YamlMap>().singleWhere(
      (job) =>
          (job['strategy']?['matrix']?['include'] as YamlList?)?.any(
            (entry) => entry['target'] == 'windows',
          ) ??
          false,
    );
    final steps = (windowsJob['steps'] as YamlList).cast<YamlMap>().toList();
    final sideload = stepNamed(
      steps,
      'Build Windows MSIX notification package',
    );
    final store = stepNamed(steps, 'Build Microsoft Store submission package');
    final upload = stepNamed(
      steps,
      'Upload Microsoft Store submission package',
    );
    expect(sideload['run'], 'pwsh -File tool/build_msix.ps1 -Unsigned');
    expect(store['run'], 'pwsh -File tool/build_msix.ps1 -Store');
    expect(store['if'], "matrix.target == 'windows'");
    expect(steps.indexOf(store), greaterThan(steps.indexOf(sideload)));
    expect(upload['with']['path'], 'build/microsoft-store/*.msix');
    expect(upload['with']['if-no-files-found'], 'error');
    expect(
      stepNamed(steps, 'Build release application')['if'],
      "matrix.target != 'windows'",
    );
    expect(workflow['permissions']['contents'], 'read');
    expect(
      steps.any(
        (step) => (step['run'] as String? ?? '').contains('msstore publish'),
      ),
      isFalse,
    );
  });
}
