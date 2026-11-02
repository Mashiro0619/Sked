import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../benchmark/src/agent_ui_performance_scenarios.dart';
import 'support/agent_native_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });

  testWidgets(
    'profiles idle Agent transcript and product host transitions',
    (tester) async {
      try {
        final report = await runAgentUiPerformanceBenchmarks(
          tester,
          config: const AgentNativeConfig(
            name: String.fromEnvironment(
              'SKED_AGENT_UI_PERF_CONFIG',
              defaultValue: 'baseline',
            ),
            revision: String.fromEnvironment('SKED_AGENT_UI_PERF_REVISION'),
            label: String.fromEnvironment(
              'SKED_AGENT_UI_PERF_LABEL',
              defaultValue: 'local',
            ),
            sourceNote: String.fromEnvironment(
              'SKED_AGENT_UI_PERF_SOURCE_NOTE',
            ),
          ),
        );
        binding.reportData = {'agentUiPerformance': report};
      } on AgentUiPerformanceFailure catch (failure) {
        // The driver persists failed windows and cleanup before rejecting them.
        binding.reportData = {'agentUiPerformance': failure.report};
        Error.throwWithStackTrace(failure.cause, failure.stackTrace);
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
    semanticsEnabled: false,
  );
}
