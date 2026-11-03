import 'package:flutter_test/flutter_test.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';

void main() {
  test('default configuration enables the entry without credentials or elevated authority', () {
    const settings = AgentSettings();
    expect(settings.enabled, isTrue);
    expect(settings.permissionMode, AgentPermissionMode.ask);
    expect(settings.protocol, AgentModelProtocol.chatCompletions);
    expect(settings.endpoint, isEmpty);
    expect(settings.model, isEmpty);
    expect(settings.credentialRef, isNull);
    expect(AgentSettings.fromJson(settings.toJson()), settings);
  });

  test('model IDs never imply a reasoning capability or default', () {
    const modelOnly = AgentSettings(model: 'unconfigured-model');
    expect(modelOnly.availableModels, isEmpty);
    expect(modelOnly.defaultModelSelection, isNull);
    expect(modelOnly.validate, throwsFormatException);
    expect(
      () => const AgentSettings().copyWith(model: 'new-model'),
      throwsFormatException,
    );
    final json = const AgentSettings().toJson()
      ..['model'] = 'unconfigured-model';
    expect(() => AgentSettings.fromJson(json), throwsFormatException);
  });

  test('automatic and missing reasoning selections are rejected', () {
    for (final value in [
      {'modelId': 'first', 'reasoningEffort': 'auto'},
      {'modelId': 'first'},
      {'modelId': 'first', 'reasoningEffort': null},
    ]) {
      expect(() => AgentModelSelection.fromJson(value), throwsFormatException);
    }
    expect(
      () => AgentModelConfig.fromJson({
        'id': 'first',
        'reasoningEfforts': ['auto'],
        'defaultReasoningEffort': 'auto',
      }),
      throwsFormatException,
    );
  });

  test('enabled models retain independent supported levels and defaults', () {
    const settings = AgentSettings(
      model: 'first',
      models: [
        AgentModelConfig(
          id: 'first',
          reasoningEfforts: [
            AgentReasoningEffort.medium,
            AgentReasoningEffort.high,
          ],
          defaultReasoningEffort: AgentReasoningEffort.high,
        ),
        AgentModelConfig(
          id: 'second',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ],
    );
    final decoded = AgentSettings.fromJson(settings.toJson());
    expect(decoded, settings);
    expect(decoded.defaultModelSelection!.wireReasoningEffort, 'high');
    expect(
      decoded.allowsSelection(
        const AgentModelSelection(
          modelId: 'first',
          reasoningEffort: AgentReasoningEffort.high,
        ),
      ),
      isTrue,
    );
    expect(
      decoded.allowsSelection(
        const AgentModelSelection(
          modelId: 'second',
          reasoningEffort: AgentReasoningEffort.high,
        ),
      ),
      isFalse,
    );
    expect(
      decoded
          .copyWith(model: 'second')
          .defaultModelSelection!
          .wireReasoningEffort,
      'medium',
    );
    expect(decoded.copyWith(model: '', models: []).availableModels, isEmpty);
  });

  test(
    'model lists reject duplicates and defaults outside their allowed choices',
    () {
      for (final settings in [
        const AgentSettings(
          model: 'missing',
          models: [
            AgentModelConfig(
              id: 'first',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
          ],
        ),
        const AgentSettings(
          model: 'first',
          models: [
            AgentModelConfig(
              id: 'first',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
            AgentModelConfig(
              id: 'first',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.medium,
            ),
          ],
        ),
        const AgentSettings(
          model: 'first',
          models: [
            AgentModelConfig(
              id: 'first',
              reasoningEfforts: [AgentReasoningEffort.medium],
              defaultReasoningEffort: AgentReasoningEffort.high,
            ),
          ],
        ),
        const AgentSettings(
          model: 'first',
          models: [
            AgentModelConfig(
              id: 'first',
              reasoningEfforts: [],
              defaultReasoningEffort: AgentReasoningEffort.high,
            ),
          ],
        ),
      ]) {
        expect(settings.validate, throwsFormatException);
      }
      final invalid = const AgentSettings(
        model: 'first',
        models: [
          AgentModelConfig(
            id: 'first',
            reasoningEfforts: [AgentReasoningEffort.medium],
            defaultReasoningEffort: AgentReasoningEffort.medium,
          ),
        ],
      ).toJson()..['models'] = [];
      expect(() => AgentSettings.fromJson(invalid), throwsFormatException);
    },
  );

  test('configuration round trips and nullable credential can be removed', () {
    final settings = const AgentSettings().copyWith(
      enabled: true,
      permissionMode: AgentPermissionMode.full,
      protocol: AgentModelProtocol.responses,
      endpoint: 'https://example.test/v1',
      model: 'test-model',
      models: const [
        AgentModelConfig(
          id: 'test-model',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ],
      credentialRef: 'agent-key-1',
      systemInstructions: 'Keep responses concise.',
      maxModelRounds: 10,
      maxToolCalls: 25,
      maxTotalTokens: 20000,
      historyRetentionDays: 30,
    );
    final decoded = AgentSettings.fromJson(settings.toJson());
    expect(decoded, settings);
    expect(decoded.hashCode, settings.hashCode);
    expect(settings.copyWith().credentialRef, 'agent-key-1');
    expect(settings.copyWith(credentialRef: null).credentialRef, isNull);
    expect(settings.toJson(), isNot(contains('apiKey')));
  });

  test('unknown fields and malformed persisted types are rejected', () {
    for (final change in <String, Object?>{
      'enabled': 1,
      'permissionMode': 'unrestricted',
      'protocol': 'unknown',
      'endpoint': 10,
      'model': false,
      'credentialRef': '',
      'apiKey': 'untrusted',
    }.entries) {
      final json = const AgentSettings().toJson()..[change.key] = change.value;
      expect(
        () => AgentSettings.fromJson(json),
        throwsFormatException,
        reason: change.key,
      );
    }
    for (final key in [
      'enabled',
      'permissionMode',
      'protocol',
      'endpoint',
      'model',
      'credentialRef',
    ]) {
      final json = const AgentSettings().toJson()..remove(key);
      expect(
        () => AgentSettings.fromJson(json),
        throwsFormatException,
        reason: key,
      );
    }
    expect(() => AgentSettings.fromJson({1: true}), throwsFormatException);
  });

  test(
    'legacy connection configuration receives bounded preference defaults',
    () {
      final legacy = const AgentSettings().toJson()
        ..removeWhere(
          (key, _) => !{
            'enabled',
            'permissionMode',
            'protocol',
            'endpoint',
            'model',
            'credentialRef',
          }.contains(key),
        );
      expect(AgentSettings.fromJson(legacy), const AgentSettings());
    },
  );

  test('preference limits and persisted types reject malformed values', () {
    for (final entry in <String, Object?>{
      'systemInstructions': 1,
      'maxModelRounds': 0,
      'maxToolCalls': 501,
      'maxTotalTokens': 1023,
      'historyRetentionDays': 1,
    }.entries) {
      final json = const AgentSettings().toJson()..[entry.key] = entry.value;
      expect(() => AgentSettings.fromJson(json), throwsFormatException);
    }
    expect(
      () => const AgentSettings(historyRetentionDays: 3651).validate(),
      throwsFormatException,
    );
    expect(
      () => AgentSettings(systemInstructions: 'x' * 16001).validate(),
      throwsFormatException,
    );
    expect(
      () => const AgentSettings(maxModelRounds: 101).validate(),
      throwsFormatException,
    );
    expect(
      () => const AgentSettings(maxTotalTokens: 1000001).validate(),
      throwsFormatException,
    );
  });

  test('invalid endpoints cannot enter a durable configuration', () {
    for (final endpoint in [
      ' https://example.test/v1',
      'file:///tmp/model',
      '/relative',
      'https://',
      'https://user:password@example.test/v1',
      'https://example.test/v1#secret',
    ]) {
      expect(
        () => AgentSettings(endpoint: endpoint).toJson(),
        throwsFormatException,
        reason: endpoint,
      );
    }
    expect(
      AgentSettings(endpoint: 'http://localhost:11434/v1').toJson(),
      containsPair('endpoint', 'http://localhost:11434/v1'),
    );
  });
}
