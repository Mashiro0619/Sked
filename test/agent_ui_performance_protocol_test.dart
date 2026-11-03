import 'package:flutter_test/flutter_test.dart';

import '../benchmark/src/agent_ui_performance_scenarios.dart';
import '../test_driver/agent_ui_performance_driver.dart';

const _protocol = <String, Object?>{
  'id': 'agent-ui-frames-v2',
  'version': 2,
  'nativeSemanticsHarnessVersion': 2,
  'iterations': 2,
  'requiredIndependentProcesses': 3,
  'deliveryWaitMs': 1200,
  'scrollTargeting': {
    'id': 'agent-transcript-scroll-v1',
    'version': 1,
    'scope': 'agent-transcript',
    'key': 'agent-transcript-native-long-history',
  },
};

void main() {
  for (final platform in ['windows', 'android']) {
    final actions = platform == 'windows'
        ? agentUiPerformanceWindowsActions
        : agentUiPerformanceAndroidActions;
    test('$platform v2 measures the complete cold and warm full-page path', () {
      expect(agentUiPerformanceProtocolId, _protocol['id']);
      final accepted = validateAgentUiPerformancePopulation(
        protocol: _protocol,
        expectedActions: actions,
        platform: platform,
      );
      expect(accepted, [
        'agent.entry.open',
        'agent.page.scroll_older',
        'agent.page.close_reading',
        'agent.page.reopen_reading',
        'agent.page.jump_latest',
        'agent.page.close_latest',
      ]);
      expect(accepted.length * agentUiPerformanceIterations, 12);
    });

    test('$platform rejects old v1 evidence even with a new action list', () {
      expect(
        () => validateAgentUiPerformancePopulation(
          protocol: {..._protocol, 'id': 'agent-ui-frames-v1', 'version': 1},
          expectedActions: actions,
          platform: platform,
        ),
        throwsStateError,
      );
    });

    test('$platform rejects a legacy pane action in the v2 population', () {
      expect(
        () => validateAgentUiPerformancePopulation(
          protocol: _protocol,
          expectedActions: [...actions.take(5), 'agent.pane.close'],
          platform: platform,
        ),
        throwsStateError,
      );
    });
  }

  test('v2 preserves independent process and iteration requirements', () {
    for (final change in [
      {'iterations': 1},
      {'requiredIndependentProcesses': 1},
      {'deliveryWaitMs': 0},
    ]) {
      expect(
        () => validateAgentUiPerformancePopulation(
          protocol: {..._protocol, ...change},
          expectedActions: agentUiPerformanceWindowsActions,
          platform: 'windows',
        ),
        throwsStateError,
      );
    }
  });

  test('v2 refuses an unrelated scroll target', () {
    expect(
      () => validateAgentUiPerformancePopulation(
        protocol: {
          ..._protocol,
          'scrollTargeting': {
            ...(_protocol['scrollTargeting']! as Map),
            'key': 'general-calendar',
          },
        },
        expectedActions: agentUiPerformanceWindowsActions,
        platform: 'windows',
      ),
      throwsStateError,
    );
  });
}
