import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/bridge/rust_conversation_repository.dart';

import '../../support/agent_native_fixture.dart';

const _id = 'reading-chat';

ViewConversationSnapshot _snapshot(int count, {int sequence = 1}) =>
    copyNativeSnapshot(
      nativeConversationFixture(
        id: _id,
        messages: [
          for (var index = 0; index < count; index++)
            nativeMessageFixture(id: 'message-$index', text: 'Message $index'),
        ],
      ),
      sequence: sequence,
    );

class _ReadingCore extends MemoryAgentCore {
  _ReadingCore()
    : super(
        snapshots: [
          _snapshot(120),
          nativeConversationFixture(id: 'other'),
        ],
      ) {
    selectedId = _id;
  }

  Future<void> Function(AgentQuery)? afterQuery;
  late final StreamController<AgentEvent> _source =
      StreamController<AgentEvent>.broadcast(
        onListen: () => scheduleMicrotask(
          () => _source.add(
            const AgentEvent(kind: EventKind.ready, conversationId: ''),
          ),
        ),
      );

  @override
  Stream<AgentEvent> watchEvents() => _source.stream;

  @override
  void emit(AgentEvent event) => _source.add(event);

  @override
  Future<QueryResult> query({required AgentQuery query}) async {
    final result = await super.query(query: query);
    await afterQuery?.call(query);
    return result;
  }

  @override
  Future<CommandResult> dispatch({required AgentCommand command}) async {
    final result = await super.dispatch(command: command);
    if (command.kind == CommandKind.selectConversation) {
      emit(const AgentEvent(kind: EventKind.resync, conversationId: ''));
    }
    return result;
  }

  @override
  Future<void> shutdown() async {
    unawaited(_source.close());
    await super.shutdown();
  }
}

void main() {
  late _ReadingCore core;
  late RustConversationRepository repository;
  final owner = Object();

  setUp(() async {
    core = _ReadingCore();
    repository = RustConversationRepository(core.client);
    await repository.load();
    await repository.setViewActive(owner, _id);
  });

  tearDown(() async {
    repository.dispose();
    await core.client.shutdown();
  });

  List<String> visibleIds() => [
    for (final message in repository.visibleMessages(_id)) message.id,
  ];

  List<String> expectedIds(int start, int end) => [
    for (var index = start; index < end; index++) 'message-$index',
  ];

  test('selection and resync retain the expanded reading window', () async {
    expect(visibleIds(), expectedIds(70, 120));
    expect(
      core.queries
          .where((query) => query.kind == QueryKind.conversationPage)
          .single
          .limit,
      50,
    );
    await repository.loadEarlierMessages(_id);
    expect(visibleIds(), expectedIds(20, 120));

    await repository.select('other');
    await repository.setViewActive(owner, 'other');
    await repository.waitForPendingWrites();
    await repository.select(_id);
    await repository.setViewActive(owner, _id);
    await repository.waitForPendingWrites();
    expect(visibleIds(), expectedIds(20, 120));

    final refreshStarted = Completer<void>();
    core.beforeQuery = (query) async {
      if (query.kind == QueryKind.conversations &&
          !refreshStarted.isCompleted) {
        refreshStarted.complete();
      }
    };
    core.emit(const AgentEvent(kind: EventKind.resync, conversationId: ''));
    await refreshStarted.future;
    await repository.waitForPendingWrites();
    expect(visibleIds(), expectedIds(20, 120));
    expect(repository.hasEarlierMessages(_id), isTrue);
    expect(repository.blocked, isFalse);
  });

  test(
    'loading earlier includes appended messages and keeps the anchor',
    () async {
      core.snapshots[_id] = _snapshot(140, sequence: 2);
      await repository.loadEarlierMessages(_id);

      expect(visibleIds(), expectedIds(20, 140));
      expect(repository.hasEarlierMessages(_id), isTrue);
      await repository.loadEarlierMessages(_id);
      expect(visibleIds(), expectedIds(0, 140));
      expect(repository.hasEarlierMessages(_id), isFalse);
    },
  );

  test('loading earlier cannot reattach a suffix removed by redo', () async {
    core.snapshots[_id] = _snapshot(80, sequence: 2);
    await repository.loadEarlierMessages(_id);

    expect(visibleIds(), expectedIds(20, 80));
    expect(
      repository.find(_id)!.messages.map((message) => message.id),
      expectedIds(20, 80),
    );
  });

  test('a late page preserves the window from a newer full snapshot', () async {
    await repository.loadEarlierMessages(_id);
    final captured = Completer<void>();
    final release = Completer<void>();
    core.afterQuery = (query) async {
      if (query.kind != QueryKind.conversationPage) return;
      core.afterQuery = null;
      captured.complete();
      await release.future;
    };
    final refresh = repository.setViewActive(owner, _id);
    await captured.future;
    final newer = _snapshot(140, sequence: 2);
    core.snapshots[_id] = newer;
    repository.ingestState(
      (await core.query(
        query: const AgentQuery(
          kind: QueryKind.conversationState,
          conversationId: _id,
        ),
      )).state!,
    );
    release.complete();
    await refresh;

    expect(visibleIds(), expectedIds(20, 140));
  });

  test(
    'a restore boundary discards the old window and its late page failure',
    () async {
      final captured = Completer<void>();
      final release = Completer<void>();
      core.afterQuery = (query) async {
        if (query.kind != QueryKind.conversationPage) return;
        core.afterQuery = null;
        captured.complete();
        await release.future;
        throw StateError('Page failed before data restoration.');
      };
      final earlier = repository.loadEarlierMessages(_id);
      await captured.future;
      repository.invalidateAfterDataBoundary();
      core.snapshots[_id] = _snapshot(60, sequence: 2);
      release.complete();
      await earlier;
      expect(visibleIds(), isEmpty);

      await repository.load();
      await repository.setViewActive(owner, _id);
      await repository.waitForPendingWrites();
      expect(visibleIds(), expectedIds(10, 60));
      expect(repository.blocked, isFalse);
    },
  );

  test('hidden views release bodies and explicit full reads do not populate the window', () async {
    final complete = await repository.read(_id);
    expect(complete.messages, hasLength(120));
    expect(visibleIds(), expectedIds(70, 120));
    await repository.setViewActive(owner, null);
    expect(repository.find(_id)!.messages, isEmpty);
    final pageReads = core.queries
        .where((query) => query.kind == QueryKind.conversationPage)
        .length;
    core.snapshots[_id] = _snapshot(140, sequence: 2);
    await repository.refresh(_id);
    expect(
      core.queries.where((query) => query.kind == QueryKind.conversationPage),
      hasLength(pageReads),
    );
    expect(repository.find(_id)!.messages, isEmpty);
    await repository.setViewActive(owner, _id);
    expect(visibleIds(), expectedIds(70, 140));
  });
}
