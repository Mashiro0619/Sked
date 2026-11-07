import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../benchmark/src/agent_persistence_performance.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'profiles real Agent persistence and reopen',
    (tester) async {
      try {
        binding.reportData = {
          'agentPersistencePerformance': await runAgentPersistencePerformance(
            revision: const String.fromEnvironment(
              'SKED_AGENT_PERSISTENCE_REVISION',
            ),
            label: const String.fromEnvironment(
              'SKED_AGENT_PERSISTENCE_LABEL',
              defaultValue: 'local',
            ),
          ),
        };
      } on AgentPersistenceFailure catch (failure) {
        binding.reportData = {'agentPersistencePerformance': failure.report};
        Error.throwWithStackTrace(failure.cause, failure.stack);
      }
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
