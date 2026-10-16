import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../benchmark/src/ui_performance_scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });

  testWidgets(
    'profiles production workspace interactions with isolated data',
    (tester) async {
      const datasetNames = String.fromEnvironment(
        'SKED_UI_PERF_DATASETS',
        defaultValue: 'sparse,1000,5000',
      );
      final report = await runUiPerformanceBenchmarks(
        tester,
        config: UiPerformanceConfig(
          label: const String.fromEnvironment(
            'SKED_UI_PERF_LABEL',
            defaultValue: 'local',
          ),
          revision: const String.fromEnvironment(
            'SKED_UI_PERF_REVISION',
            defaultValue: 'unknown',
          ),
          datasets: datasetNames.split(',').map((name) => name.trim()).toList(),
          warmRuns: const int.fromEnvironment(
            'SKED_UI_PERF_WARM_RUNS',
            defaultValue: 1,
          ),
        ),
      );
      binding.reportData = {'uiPerformance': report};
    },
    timeout: Timeout.none,
    semanticsEnabled: false,
  );
}
