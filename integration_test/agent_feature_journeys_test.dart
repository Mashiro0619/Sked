import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/agent_attachment_journey.dart';
import 'support/agent_feature_journey.dart';
import 'support/agent_knowledge_journey.dart';
import 'support/agent_native_session.dart';

AgentNativeFeature _feature(String name) => switch (name) {
  'knowledge' => AgentKnowledgeJourney(),
  'attachments' => AgentAttachmentJourney(),
  _ => throw ArgumentError.value(
    name,
    'SKED_AGENT_FEATURE_JOURNEY',
    'Use knowledge or attachments.',
  ),
};

void main() {
  const featureName = String.fromEnvironment(
    'SKED_AGENT_FEATURE_JOURNEY',
    defaultValue: 'knowledge',
  );
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    runApp(const SizedBox.shrink());
    await binding.endOfFrame;
  });

  testWidgets(
    'native Agent $featureName journey preserves its product state',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Sked',
        packageName: 'com.mashiro.sked.agent_feature_journeys',
        version: '3.0.0',
        buildNumber: '0',
        buildSignature: '',
        installerStore: '',
      );
      // The registered framework keyboard is not native IME acceptance.
      binding.testTextInput.register();
      try {
        binding.reportData = {
          'agentFeatureJourney': await runAgentFeatureJourney(
            tester,
            featureName: featureName,
            createFeature: _feature,
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
      } on AgentFeatureJourneyFailure catch (failure) {
        binding.reportData = {'agentFeatureJourney': failure.report};
        Error.throwWithStackTrace(failure.cause, failure.stackTrace);
      } finally {
        binding.testTextInput.unregister();
      }
    },
    timeout: const Timeout(Duration(minutes: 6)),
    semanticsEnabled: false,
  );
}
