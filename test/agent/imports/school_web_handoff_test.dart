import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/imports/school_web_handoff.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/services/school_import_content_sanitizer.dart';

class _MemoryStorage extends ConversationStorage {
  _MemoryStorage() : super.base();
  String? source;
  Future<void> Function()? beforeSave;
  bool fail = false;
  @override
  Future<ConversationStorageLoad> load() async =>
      ConversationStorageLoad(source: source);
  @override
  Future<void> save(String value, {required int revision}) async {
    await beforeSave?.call();
    if (fail) throw StateError('synthetic storage failure');
    source = value;
  }
}

Matcher _problem(OperationErrorCode code) =>
    isA<OperationProblem>().having((problem) => problem.code, 'code', code);

void main() {
  late _MemoryStorage storage;
  late ConversationRepository repository;
  late SchoolWebHandoffController handoff;
  late AgentSettings settings;
  late SchoolWebReviewedDraft draft;
  var generation = 'dataset-one';
  var current = true;
  late List<String> starts;
  Future<void> Function() initialize = () async {};

  setUp(() async {
    storage = _MemoryStorage();
    repository = ConversationRepository(storage: storage);
    await repository.load();
    addTearDown(repository.dispose);
    generation = 'dataset-one';
    current = true;
    starts = [];
    initialize = () async {};
    settings = const AgentSettings(
      enabled: true,
      endpoint: 'https://model.example/v1',
      model: 'test-model',
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

  test(
    'a source, first message and handoff persist before starting inference',
    () async {
      final saving = Completer<void>();
      final release = Completer<void>();
      storage.beforeSave = () async {
        saving.complete();
        await release.future;
      };
      final pending = handoff.handoff(draft, isCurrent: () => current);
      await saving.future;
      expect(starts, isEmpty);
      expect(repository.conversations, isEmpty);
      release.complete();
      final result = await pending;
      final archive = ConversationArchive.decode(storage.source!);
      expect(archive.handoffs.single.id, result.handoffId);
      expect(
        archive.handoffs.single.messageId,
        archive.conversations.single.messages.single.id,
      );
      final source = archive.conversations.single.sources.single;
      expect(source.url, 'https://school.test/courses');
      expect(source.truncated, isTrue);
      expect(source.provenance!.datasetGeneration, generation);
      expect(starts, [result.conversationId]);
    },
  );

  test(
    'rapid duplicate clicks and navigation retry keep the same request',
    () async {
      final gate = Completer<void>();
      initialize = () => gate.future;
      final first = handoff.handoff(draft, isCurrent: () => current);
      final second = handoff.handoff(draft, isCurrent: () => current);
      expect(identical(first, second), isTrue);
      gate.complete();
      final result = await first;
      final retry = await handoff.handoff(draft, isCurrent: () => current);
      expect(retry.created, isFalse);
      expect(retry.handoffId, result.handoffId);
      expect(retry.conversationId, result.conversationId);
      expect(repository.conversations.single.messages.length, 1);
      expect(repository.conversations.single.sources.length, 1);
    },
  );

  test(
    'cancelled source before acceptance never creates a conversation',
    () async {
      final gate = Completer<void>();
      initialize = () => gate.future;
      final pending = handoff.handoff(draft, isCurrent: () => current);
      current = false;
      gate.complete();
      await expectLater(
        pending,
        throwsA(_problem(OperationErrorCode.cancelled)),
      );
      expect(repository.conversations, isEmpty);
      expect(starts, isEmpty);
    },
  );

  test(
    'disabled and missing configuration preserve a retriable source',
    () async {
      settings = const AgentSettings();
      await expectLater(
        handoff.handoff(draft, isCurrent: () => true),
        throwsA(_problem(OperationErrorCode.disabled)),
      );
      settings = settings.copyWith(enabled: true);
      await expectLater(
        handoff.handoff(draft, isCurrent: () => true),
        throwsA(_problem(OperationErrorCode.invalidArgument)),
      );
      expect(repository.conversations, isEmpty);
      settings = settings.copyWith(
        endpoint: 'https://model.test/v1',
        model: 'test',
      );
      await handoff.handoff(draft, isCurrent: () => true);
      expect(
        repository.conversations.single.sources.single.text,
        draft.content,
      );
    },
  );

  test(
    'storage failure leaves no inference and can recover the same handoff',
    () async {
      storage.fail = true;
      await expectLater(
        handoff.handoff(draft, isCurrent: () => true),
        throwsStateError,
      );
      expect(starts, isEmpty);
      storage.fail = false;
      await repository.load();
      final result = await handoff.handoff(draft, isCurrent: () => true);
      expect(result.created, isTrue);
      expect(repository.conversations.length, 1);
    },
  );

  test(
    'restoration invalidates old sources and a new review is distinct',
    () async {
      generation = 'dataset-two';
      await expectLater(
        handoff.handoff(draft, isCurrent: () => true),
        throwsA(_problem(OperationErrorCode.expired)),
      );
      expect(repository.conversations, isEmpty);
      final refreshed = SchoolWebReviewedDraft(
        content: 'Re-reviewed content',
        datasetGeneration: generation,
        capturedAt: draft.capturedAt,
        localeCode: 'en',
      );
      await handoff.handoff(refreshed, isCurrent: () => true);
      expect(
        repository.conversations.single.sources.single.text,
        refreshed.content,
      );
    },
  );

  test('source quotas and unsafe URLs stay outside model requests', () async {
    expect(redactSchoolWebSourceUrl('javascript:alert(1)'), isNull);
    expect(redactSchoolWebSourceUrl('file:///private'), isNull);
    final oversized = SchoolWebReviewedDraft(
      content: 'x' * (SchoolImportContentSanitizer.maxContentLength + 1),
      datasetGeneration: generation,
      capturedAt: draft.capturedAt,
      localeCode: 'en',
    );
    await expectLater(
      handoff.handoff(oversized, isCurrent: () => true),
      throwsA(_problem(OperationErrorCode.invalidArgument)),
    );
    expect(starts, isEmpty);
  });
}
