import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/agent_native_journey.dart';
import 'support/agent_native_session.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });

  testWidgets(
    'native Agent preserves long-history reading and an active run across product hosts',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Sked',
        packageName: 'com.mashiro.sked.agent_native_journey',
        version: '3.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: '',
      );
      // Framework input owns this test channel. It is not evidence for the OS
      // IME, physical keyboard, native back gesture or accessibility provider.
      binding.testTextInput.register();
      try {
        binding.reportData = {
          'agentNativeJourney': await runAgentNativeJourney(
            tester,
            config: const AgentNativeConfig(
              name: String.fromEnvironment(
                'SKED_AGENT_NATIVE_CONFIG',
                defaultValue: 'baseline',
              ),
              revision: String.fromEnvironment('SKED_AGENT_NATIVE_REVISION'),
              label: String.fromEnvironment(
                'SKED_AGENT_NATIVE_LABEL',
                defaultValue: 'local',
              ),
              sourceNote: String.fromEnvironment(
                'SKED_AGENT_NATIVE_SOURCE_NOTE',
              ),
            ),
          ),
        };
      } on AgentNativeJourneyFailure catch (failure) {
        // integrationDriver(writeResponseOnFailure: true) receives the failed
        // checkpoint and cleanup evidence before the original error is raised.
        binding.reportData = {'agentNativeJourney': failure.report};
        Error.throwWithStackTrace(failure.cause, failure.stackTrace);
      } finally {
        binding.testTextInput.unregister();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    semanticsEnabled: false,
  );
}
