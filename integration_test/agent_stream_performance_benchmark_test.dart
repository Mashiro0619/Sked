import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../benchmark/src/agent_stream_performance.dart';
import 'support/agent_native_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });
  testWidgets(
    'profiles controlled Agent streaming on the native surface',
    (tester) async {
      try {
        SharedPreferences.setMockInitialValues({});
        PackageInfo.setMockInitialValues(
          appName: 'Sked stream acceptance',
          packageName: 'com.mashiro.sked.agent_stream',
          version: '0',
          buildNumber: '0',
          buildSignature: '',
        );
        binding.reportData = {
          'agentStreamPerformance': await runAgentStreamPerformance(
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
          ),
        };
      } on AgentStreamPerformanceFailure catch (failure) {
        binding.reportData = {'agentStreamPerformance': failure.report};
        Error.throwWithStackTrace(failure.cause, failure.stack);
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
    semanticsEnabled: false,
  );
}
