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
    'profiles the declared workspace60 population without settings routes',
    (tester) async {
      final report = await runUiPerformanceBenchmarks(
        tester,
        config: const UiPerformanceConfig(
          scope: UiPerformanceScope.workspace,
          label: String.fromEnvironment(
            'SKED_UI_WORKSPACE_PERF_LABEL',
            defaultValue: 'local',
          ),
          revision: String.fromEnvironment(
            'SKED_UI_WORKSPACE_PERF_REVISION',
            defaultValue: 'unknown',
          ),
          datasets: ['sparse', '1000', '5000'],
          warmRuns: 1,
          listContentGuards: bool.fromEnvironment(
            'SKED_UI_WORKSPACE_PERF_CONTENT_GUARDS',
            defaultValue: false,
          ),
        ),
      );
      binding.reportData = {'uiWorkspacePerformance': report};
    },
    timeout: Timeout.none,
    semanticsEnabled: false,
  );
}
