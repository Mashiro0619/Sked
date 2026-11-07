import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/tools/model_configuration.dart';
import 'package:sked/models/agent_settings.dart';

void main() {
  const previous = AgentModelConfig(
    id: 'model',
    reasoningEfforts: [AgentReasoningEffort.medium],
    defaultReasoningEffort: AgentReasoningEffort.medium,
    reportedContextTokens: 128000,
    maxContextTokens: 100000,
    autoCompactAtTokens: 70000,
    autoCompact: false,
  );
  final required = {
    'id': 'model',
    'reasoningEfforts': ['medium', 'high'],
    'defaultReasoningEffort': 'high',
  };

  test(
    'the writable schema excludes reported metadata and decoder preserves it',
    () {
      expect(
        AgentModelToolConfiguration.properties.keys,
        containsAll(['maxContextTokens', 'autoCompactAtTokens', 'autoCompact']),
      );
      expect(
        AgentModelToolConfiguration.properties.containsKey(
          'reportedContextTokens',
        ),
        isFalse,
      );
      final updated = AgentModelToolConfiguration.decode(
        required,
        previous: previous,
      );
      expect(updated.reportedContextTokens, 128000);
      expect(updated.maxContextTokens, 100000);
      expect(updated.autoCompactAtTokens, 70000);
      expect(updated.autoCompact, isFalse);
      expect(updated.defaultReasoningEffort, AgentReasoningEffort.high);
      expect(
        () => AgentModelToolConfiguration.decode({
          ...required,
          'reportedContextTokens': 200000,
        }, previous: previous),
        throwsFormatException,
      );
    },
  );

  test('explicit context edits and resets preserve service metadata', () {
    final updated = AgentModelToolConfiguration.decode({
      ...required,
      'maxContextTokens': null,
      'autoCompactAtTokens': null,
      'autoCompact': true,
    }, previous: previous);
    expect(updated.effectiveContextTokens, 128000);
    expect(updated.effectiveCompactAtTokens, 102400);
    expect(
      AgentModelToolConfiguration.arguments(updated)
          .containsKey('reportedContextTokens'),
      isFalse,
    );
    final fresh = AgentModelToolConfiguration.decode(required);
    expect(fresh.reportedContextTokens, isNull);
    expect(fresh.effectiveCompactAtTokens, isNull);
  });
}
