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
    for (final job in jobs.keys.cast<String>()) {
      final steps = stepsFor(job);
      final flutterSetup = steps.where(
        (step) => (step['uses'] as String? ?? '').startsWith(
          'subosito/flutter-action@',
        ),
      );
      if (flutterSetup.isEmpty) continue;
      final setup = flutterSetup.single['with'] as YamlMap;
      expect(setup['flutter-version'], '3.47.0', reason: job);
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
    'test job resolves the internal plugin before formatting and analysis',
    () {
      final steps = stepsFor('test');
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

  test('named timezone checks include a non-DST Shanghai control', () {
    const zones = {
      'America/New_York': 'america-new-york',
      'Europe/Berlin': 'europe-berlin',
      'Asia/Shanghai': 'asia-shanghai',
    };
    final timezoneSteps = stepsFor('test').where(
      (step) =>
          step['run'] == 'flutter test test/date_dst_regression_test.dart',
    );
    expect(timezoneSteps, hasLength(zones.length));
    for (final zone in zones.entries) {
      final step = timezoneSteps.singleWhere(
        (step) => (step['env'] as YamlMap)['TZ'] == zone.key,
      );
      expect((step['env'] as YamlMap)['SKED_DST_TEST_ZONE'], zone.value);
    }
  });

  test('release smoke builds use an isolated temporary CI signing key', () {
    final steps = stepsFor('android-build');
    final setupJava = stepNamed(steps, 'Set up Java');
    expect((setupJava['with'] as YamlMap)['java-version'], '17');

    final signing = stepNamed(steps, 'Prepare ephemeral CI signing key');
    final signingCommand = signing['run'] as String;
    expect(signingCommand, contains('umask 077'));
    expect(signingCommand, contains('openssl rand -hex'));
    expect(signingCommand, contains('::add-mask::'));
    expect(signingCommand, contains('keytool -genkeypair'));
    expect(signingCommand, contains(r'$RUNNER_TEMP/sked-ci-release.jks'));
    expect(signingCommand, contains('> android/key.properties'));
    expect(signingCommand, isNot(contains('secrets.')));

    for (final command in [
      'flutter build apk --release',
      'flutter build appbundle --release',
    ]) {
      final build = steps.singleWhere((step) => step['run'] == command);
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
    final pluginLock = stepNamed(steps, 'Verify internal plugin lockfile');
    expect(
      pluginLock['working-directory'],
      'packages/android_productivity_plugin',
    );
    expect(pluginLock['run'], 'flutter pub get --enforce-lockfile');
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

  test(
    'test job retains coverage gates and builds the optimized web bundle',
    () {
      final steps = stepsFor('test');
      expect(
        stepNamed(steps, 'Test with coverage')['run'],
        'flutter test --coverage',
      );
      expect(
        stepNamed(steps, 'Enforce coverage gates')['run'],
        contains('--minimum-diff 90'),
      );
      expect(
        stepNamed(steps, 'Build web release')['run'],
        'flutter build web --release',
      );
      expect(stepNamed(steps, 'Upload coverage report')['if'], 'always()');
    },
  );
}
