import 'package:flutter_test/flutter_test.dart';

import '../benchmark/src/agent_ui_performance_scenarios.dart';
import '../test_driver/agent_ui_performance_driver.dart';

const _protocol = <String, Object?>{
  'id': 'agent-ui-frames-v3',
  'version': 3,
  'storage': {
    'id': 'isolated-production-store-v1',
    'backend': 'drift-sqlite',
    'fixturePersistence': 'before-home-mount',
    'inspection': 'outside-action-windows',
    'fullArchiveReadBeforeFirstEntry': false,
  },
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
    test('$platform v3 measures the complete cold and warm full-page path', () {
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

    test('$platform rejects old evidence even with a new action list', () {
      for (final version in [1, 2]) {
        expect(
          () => validateAgentUiPerformancePopulation(
            protocol: {
              ..._protocol,
              'id': 'agent-ui-frames-v$version',
              'version': version,
            },
            expectedActions: actions,
            platform: platform,
          ),
          throwsStateError,
        );
      }
    });

    test('$platform rejects a legacy pane action in the v3 population', () {
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

  test('v3 preserves independent process and iteration requirements', () {
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

  test('v3 refuses an unrelated scroll target', () {
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

  test('v3 accepts a real legacy backend for a matched baseline', () {
    expect(
      validateAgentUiPerformancePopulation(
        protocol: {
          ..._protocol,
          'storage': {
            ...(_protocol['storage']! as Map),
            'backend': 'legacy-json',
          },
        },
        expectedActions: agentUiPerformanceWindowsActions,
        platform: 'windows',
      ),
      agentUiPerformanceWindowsActions,
    );
  });

  test('v3 rejects memory storage and archive prewarming', () {
    for (final change in [
      {'backend': 'memory'},
      {'fullArchiveReadBeforeFirstEntry': true},
      {'inspection': 'inside-action-windows'},
    ]) {
      expect(
        () => validateAgentUiPerformancePopulation(
          protocol: {
            ..._protocol,
            'storage': {...(_protocol['storage']! as Map), ...change},
          },
          expectedActions: agentUiPerformanceWindowsActions,
          platform: 'windows',
        ),
        throwsStateError,
      );
    }
  });
}
