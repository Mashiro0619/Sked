import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/imports/school_web_handoff.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/l10n/app_locale.dart';
import 'package:sked/l10n/app_localizations.dart';

import '../../support/agent_memory_conversations.dart';

void main() {
  late MemoryConversationRepository repository;
  late SchoolWebHandoffController handoff;
  late AgentSettings settings;
  late SchoolWebReviewedDraft draft;
  var generation = 'dataset-one';
  final starts = <String>[];
  Future<void> Function() initialize = () async {};
  setUp(() async {
    repository = MemoryConversationRepository();
    await repository.load();
    starts.clear();
    generation = 'dataset-one';
    initialize = () async {};
    settings = const AgentSettings(
      endpoint: 'https://model.example/v1',
      model: 'test-model',
      models: [
        AgentModelConfig(
          id: 'test-model',
          reasoningEfforts: [AgentReasoningEffort.medium],
          defaultReasoningEffort: AgentReasoningEffort.medium,
        ),
      ],
    );
    draft = SchoolWebReviewedDraft(
      content: 'A reviewed school page',
      datasetGeneration: generation,
      capturedAt: DateTime.utc(2026, 10, 30),
      localeCode: 'en',
      title: 'Semester',
      url: 'https://user:secret@school.test/courses?token=secret#session',
      truncated: true,
    );
    handoff = SchoolWebHandoffController(
      repository: repository,
      readSettings: () => settings,
      initialize: () => initialize(),
      startHandoff: (id) async => starts.add(id),
      readGeneration: () => generation,
      clock: () => DateTime.utc(2026, 10, 30, 1),
    );
  });
  tearDown(() => repository.dispose());

  test('handoff passes reviewed source and localized task to the conversation owner', () async {
    final result = await handoff.handoff(draft, isCurrent: () => true);
    final conversation = repository.find(result.conversationId)!;
    final source = conversation.sources.single;
    expect(source.url, 'https://school.test/courses');
    expect(source.text, draft.content);
    expect(source.truncated, isTrue);
    expect(source.provenance!.datasetGeneration, generation);
    expect(
      conversation.messages.single.text,
      lookupAppLocalizations(appLocaleFromCode('en')).schoolWebAgentImportTask,
    );
    expect(starts, [result.conversationId]);
  });

  test(
    'duplicate UI requests share admission and cancelled review starts nothing',
    () async {
      final gate = Completer<void>();
      initialize = () => gate.future;
      var current = true;
      final first = handoff.handoff(draft, isCurrent: () => current);
      final second = handoff.handoff(draft, isCurrent: () => current);
      expect(identical(first, second), isTrue);
      current = false;
      gate.complete();
      await expectLater(
        first,
        throwsA(
          isA<OperationProblem>().having(
            (error) => error.code,
            'code',
            OperationErrorCode.cancelled,
          ),
        ),
      );
      expect(repository.conversations, isEmpty);
      expect(starts, isEmpty);
    },
  );

  test('a restored dataset requires a new review and unsafe source URLs are excluded', () async {
    generation = 'dataset-two';
    await expectLater(
      handoff.handoff(draft, isCurrent: () => true),
      throwsA(
        isA<OperationProblem>().having(
          (error) => error.code,
          'code',
          OperationErrorCode.expired,
        ),
      ),
    );
    expect(repository.conversations, isEmpty);
    expect(redactSchoolWebSourceUrl('javascript:alert(1)'), isNull);
    expect(redactSchoolWebSourceUrl('file:///private'), isNull);
  });
}
