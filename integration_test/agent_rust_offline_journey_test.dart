import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/agent_rust_offline_journey.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'Rust Agent completes the native offline business and conversation journey',
    (tester) async {
      final report = <String, Object?>{
        'sourceRevision': const String.fromEnvironment(
          'SKED_AGENT_NATIVE_REVISION',
        ),
        'checkpoints': <String>[],
      };
      binding.reportData = {'agentRustOfflineJourney': report};
      try {
        await runRustAgentOfflineJourney(tester, report);
        report['passed'] = true;
      } catch (error) {
        report['passed'] = false;
        report['error'] = error.toString();
        rethrow;
      } finally {
        binding.reportData = {'agentRustOfflineJourney': report};
      }
    },
    timeout: const Timeout(Duration(minutes: 4)),
    semanticsEnabled: false,
  );
}
