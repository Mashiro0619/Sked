import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:sked/agent/bridge/conversation_projection.dart';
import 'package:sked/agent/bridge/generated/api.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart' as native;
import 'package:sked/agent/bridge/generated/api/models.dart' as view;
import 'package:sked/agent/bridge/generated/frb_generated.dart';
import 'package:sked/agent/bridge/rust_agent_business_host.dart';
import 'package:sked/agent/bridge/rust_agent_client.dart';
import 'package:sked/agent/bridge/rust_agent_main_undo.dart';
import 'package:sked/agent/bridge/rust_agent_ui_delegate.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';

const _calendarId = 'rust-offline-calendar';
const _model = 'offline-model';
const _settings = AgentSettings(
  endpoint: 'https://offline.invalid/custom/model?journey=native',
  model: _model,
  permissionMode: AgentPermissionMode.full,
  models: [
    AgentModelConfig(
      id: _model,
      reasoningEfforts: [AgentReasoningEffort.high],
      defaultReasoningEffort: AgentReasoningEffort.high,
      maxContextTokens: 100000,
      autoCompact: false,
    ),
  ],
);

/// Uses the native FRB library, Rust runtime/stores, Dart business tools and
/// durable AppSession path. Scripted provider replies are the model fixture.
Future<void> runRustAgentOfflineJourney(
  WidgetTester tester,
  Map<String, Object?> report,
) async {
  final temporary = Directory.systemTemp;
  if (Platform.isWindows && !temporary.path.toLowerCase().startsWith('f:')) {
    throw StateError('Run this journey with TEMP and TMP on F:.');
  }
  final root = await temporary.createTemp('sked-rust-offline-');
  final journey = _Journey(root);
  final checkpoints = report['checkpoints']! as List<String>;
  report['platform'] = Platform.operatingSystem;
  report['temporaryDirectory'] = root.path;
  try {
    await RustLib.init();
    await journey.open();
    await journey.show(tester);

    final firstRun = await journey.send('创建课后复习日程');
    await journey.settled(firstRun);
    final first = await journey.snapshot();
    expect(journey.eventTitles, ['课后复习']);
    expect(
      first.messages.any((message) => message.text == '已创建课后复习日程。'),
      isTrue,
    );
    expect(
      first.operations.any(
        (operation) =>
            operation.toolCallId == 'create-first' &&
            operation.phase == view.ViewOperationPhase.committed &&
            operation.binding != null,
      ),
      isTrue,
    );
    final savedToolMessage = conversationFromRust(first).messages
        .singleWhere((message) => message.toolCallId == 'create-first');
    expect(
      savedToolMessage.toolOutcome?.operationId,
      first.operations
          .singleWhere((operation) => operation.toolCallId == 'create-first')
          .binding!
          .operationId,
    );
    expect(
      journey.events.values.any(
        (event) =>
            event.kind == native.EventKind.textDelta && event.runId == firstRun,
      ),
      isTrue,
    );
    expect(
      first.extensions['runtime']?['exposedTools']?.json,
      contains('mutation.apply'),
    );
    checkpoints.add('发现工具、流式回复、正式新增日程与回执');

    await journey.delegate.setMode(journey.id, AgentPermissionMode.ask);
    final allowedRun = await journey.send('再创建一个需要确认的日程');
    await journey.approval('create-allowed');
    expect(journey.eventTitles, ['课后复习']);
    await tester.pump();
    expect(find.byType(AgentPlanPreview), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rust-journey-allow')));
    await journey.finishUiAction();
    await journey.settled(allowedRun);
    expect(journey.eventTitles, unorderedEquals(['课后复习', '已批准的安排']));
    checkpoints.add('真实审批按钮允许后保存');

    final rejectedRun = await journey.send('提出一个随后拒绝的日程');
    await journey.approval('create-rejected');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rust-journey-reject')));
    await journey.finishUiAction();
    await journey.settled(rejectedRun);
    expect(journey.eventTitles, unorderedEquals(['课后复习', '已批准的安排']));
    final rejected = await journey.snapshot();
    expect(
      rejected.operations
          .singleWhere((operation) => operation.toolCallId == 'create-rejected')
          .phase,
      view.ViewOperationPhase.cancelled,
    );
    checkpoints.add('拒绝审批后保存真实取消结果');

    await journey.delegate.setMode(journey.id, AgentPermissionMode.plan);
    final planRun = await journey.send('只预览下一项安排');
    await journey.settled(planRun);
    expect(journey.eventTitles, unorderedEquals(['课后复习', '已批准的安排']));
    final preview = await journey.snapshot();
    expect(
      preview.operations
          .singleWhere((operation) => operation.toolCallId == 'create-preview')
          .phase,
      view.ViewOperationPhase.previewed,
    );
    expect(
      journey.delegate.state.value.runFor(journey.id).pendingApproval,
      isNull,
    );
    checkpoints.add('只读计划返回预览并保持主库');

    await journey.delegate.setMode(journey.id, AgentPermissionMode.full);
    journey.writeGate.arm();
    final heldRun = await journey.send('保存期间关闭界面，然后继续管理任务');
    await journey.writeGate.entered.future.timeout(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    await journey.delegate.dispose();
    final stillRunning = await journey.client.query(
      native.AgentQuery(
        kind: native.QueryKind.readConversation,
        conversationId: journey.id,
      ),
    );
    expect(stillRunning.presentation!.active, isTrue);
    expect(journey.eventTitles, unorderedEquals(['课后复习', '已批准的安排']));
    journey.replaceDelegate();
    await journey.delegate.loadConversation(journey.id);
    await journey.show(tester);
    checkpoints.add('关闭界面订阅后原生核心与已接纳保存继续运行');

    await journey.delegate.queueFollowUp(journey.id, '保存完成后总结');
    expect(journey.delegate.pendingInputCount(journey.id), 1);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rust-journey-stop')));
    await journey.finishUiAction();
    final stopping = await journey.client.query(
      native.AgentQuery(
        kind: native.QueryKind.readConversation,
        conversationId: journey.id,
      ),
    );
    expect(
      stopping.snapshot!.conversation.status,
      view.ViewConversationStatus.stopping,
    );
    expect(stopping.presentation!.active, isTrue);
    expect(stopping.presentation!.canContinue, isFalse);
    expect(journey.delegate.state.value.runFor(journey.id).isActive, isTrue);
    journey.writeGate.release();
    await journey.settled(heldRun);
    expect(
      journey.eventTitles,
      unorderedEquals(['课后复习', '已批准的安排', '停止时完成的保存']),
    );
    final stopped = await journey.snapshot();
    expect(stopped.queuedInputs.single.text, '保存完成后总结');
    expect(
      stopped.operations
          .singleWhere((operation) => operation.toolCallId == 'create-held')
          .phase,
      view.ViewOperationPhase.committed,
    );
    expect(journey.delegate.state.value.runFor(journey.id).isActive, isFalse);
    checkpoints.add('排队、停止请求、真实保存收尾与按钮状态一致');

    await journey.delegate.continueConversation(journey.id);
    final continued = await journey.snapshot();
    await journey.settled(continued.conversation.runId!);
    final finished = await journey.snapshot();
    expect(finished.queuedInputs, isEmpty);
    expect(finished.messages.last.text, '已根据真实保存结果完成总结。');
    expect(
      journey.session.committedData.applicationLedger!.receipts,
      hasLength(3),
    );
    checkpoints.add('显式继续消费队列且不重复业务保存');

    final savedMessages = [
      for (final message in finished.messages)
        [message.id, message.role.name, message.text],
    ];
    final savedOperationIds = finished.operations
        .where(
          (operation) =>
              operation.phase == view.ViewOperationPhase.committed &&
              operation.binding?.store == view.ViewOperationStore.main,
        )
        .map((operation) => operation.binding?.operationId)
        .nonNulls
        .toSet();

    journey.writeGate.arm();
    final shutdownRun = await journey.send('保存已接纳后关闭应用');
    await journey.writeGate.entered.future.timeout(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    final shutdown = journey.closeCore();
    await journey.events.wait(
      (event) =>
          event.hostRequest?.kind == native.HostRequestKind.cancel &&
          event.hostRequest?.runId == shutdownRun,
    );
    journey.writeGate.release();
    await shutdown.timeout(const Duration(seconds: 20));
    expect(
      journey.eventTitles,
      unorderedEquals(['课后复习', '已批准的安排', '停止时完成的保存', '退出时完成的保存']),
    );
    expect(
      journey.session.committedData.applicationLedger!.receipts,
      hasLength(4),
    );
    checkpoints.add('核心关闭等待已接纳保存及宿主回执完成');

    final journalFiles =
        await Directory(path.join(journey.agentDirectory.path, 'conversations'))
            .list()
            .where((entry) => entry is File && entry.path.endsWith('.jsonl'))
            .cast<File>()
            .toList();
    expect(journalFiles, hasLength(1));
    final lines = await journalFiles.single.readAsLines();
    expect(lines, isNotEmpty);
    for (final line in lines) {
      expect(jsonDecode(line), isA<Map<String, dynamic>>());
    }
    report['journalRecords'] = lines.length;
    report['nativeEvents'] = journey.events.values.length;

    final reopened = await AgentCore.initialize(
      config: native.CoreConfig(
        dataDirectory: journey.agentDirectory.path,
        preamble:
            'Continue the offline Sked journey using actual tool receipts.',
        tools: journey.tools.registeredDefinitions
            .map(
              (definition) => native.ToolDefinition(
                name: definition.name,
                description: definition.description,
                parameters: view.JsonPayload(
                  json: jsonEncode(definition.parameters),
                ),
              ),
            )
            .toList(growable: false),
        generateTitles: false,
        offlineReplies: const [],
      ),
    );
    try {
      final restored = (await reopened.query(
        query: native.AgentQuery(
          kind: native.QueryKind.readConversation,
          conversationId: journey.id,
        ),
      )).snapshot!;
      expect([
        for (final message in restored.messages.take(savedMessages.length))
          [message.id, message.role.name, message.text],
      ], savedMessages);
      expect(restored.messages.length, greaterThan(savedMessages.length));
      final shutdownOperation = restored.operations.singleWhere(
        (operation) => operation.toolCallId == 'create-shutdown',
      );
      expect(shutdownOperation.phase, view.ViewOperationPhase.committed);
      expect(shutdownOperation.binding?.operationId, isNotNull);
      final restoredOperationIds = restored.operations
          .where(
            (operation) =>
                operation.phase == view.ViewOperationPhase.committed &&
                operation.binding?.store == view.ViewOperationStore.main,
          )
          .map((operation) => operation.binding!.operationId)
          .toSet();
      expect(restoredOperationIds, {
        ...savedOperationIds,
        shutdownOperation.binding!.operationId,
      });
      expect(restored.queuedInputs, isEmpty);
      final page = await reopened.query(
        query: native.AgentQuery(
          kind: native.QueryKind.messages,
          conversationId: journey.id,
          limit: 2,
        ),
      );
      expect(page.total, restored.messages.length);
      expect(page.messages.last.id, restored.messages.last.id);
      final diskRepository = AppRepository(
        storage: IoTimetableStorage(
          directoryProvider: () async => journey.businessDirectory,
        ),
      );
      final disk = (await diskRepository.load())!;
      expect(
        disk.generalMode.schedules.single.events.map((event) => event.title),
        unorderedEquals(['课后复习', '已批准的安排', '停止时完成的保存', '退出时完成的保存']),
      );
      expect(
        disk.applicationLedger!.receipts
            .map((receipt) => receipt.operationId)
            .toSet(),
        restoredOperationIds,
      );
      report['messages'] = restored.messages.length;
      report['businessReceipts'] = disk.applicationLedger!.receipts.length;
      checkpoints.add('JSONL、分页索引、业务文件与真实回执重新打开一致');
    } finally {
      await reopened.shutdown();
    }
  } finally {
    journey.writeGate.release();
    await tester.pumpWidget(const SizedBox.shrink());
    await journey.close();
    await root.delete(recursive: true);
    report['temporaryDataRemoved'] = !await root.exists();
  }
}

class _Journey {
  _Journey(this.root);
  final Directory root;
  late final businessDirectory = Directory(path.join(root.path, 'business'));
  late final agentDirectory = Directory(path.join(root.path, 'agent'));
  final writeGate = _WriteGate();
  final conversation = ValueNotifier<AgentConversation?>(null);
  late AppSession session;
  late MutationCoordinator mutations;
  late ApplicationToolHost tools;
  late AgentRustClient client;
  late RustAgentBusinessHost business;
  late RustAgentUiDelegate delegate;
  late _EventLog events;
  late String id;
  bool _opened = false;
  bool _coreClosed = false;
  Future<void>? _uiAction;
  (Object, StackTrace)? _uiError;

  List<String> get eventTitles => session
      .committedData
      .generalMode
      .schedules
      .single
      .events
      .map((event) => event.title)
      .toList(growable: false);

  Future<void> open() async {
    await businessDirectory.create();
    final storage = IoTimetableStorage(
      directoryProvider: () async => businessDirectory,
      beforeMainReplace: writeGate.beforeReplace,
    );
    final seed =
        buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: 'zh_CN',
        ).copyWith(
          activeMode: AppMode.general,
          generalMode: const GeneralScheduleData(
            activeScheduleId: _calendarId,
            selectedDateIso: '2026-11-09',
            schedules: [
              GeneralSchedule(id: _calendarId, name: '离线旅程', events: []),
            ],
          ),
          agentSettings: _settings,
        );
    await storage.save(seed);
    final repository = AppRepository(storage: storage);
    session = AppSession(
      repository: repository,
      initialData: (await repository.load())!,
      requireMutationAllowed: () {},
    );
    mutations = MutationCoordinator(
      session: session,
      settlePendingChanges: () async {},
      dataSessionRevision: () => 0,
    );
    tools = ApplicationToolHost(
      session: session,
      mutations: mutations,
      conversationForScope: (scope) => business.conversationForScope(scope),
      environmentForScope: (scope) => business.environmentForScope(scope),
    );
    client = AgentRustClient(
      initialize: () => AgentCore.initialize(
        config: native.CoreConfig(
          dataDirectory: agentDirectory.path,
          preamble: 'Use Sked tools and report actual business receipts.',
          tools: business.definitions,
          generateTitles: false,
          offlineReplies: _replies(),
        ),
      ),
    );
    final undo = RustAgentMainUndo(session: session, mutations: mutations);
    business = RustAgentBusinessHost(
      client: client,
      tools: tools,
      readEnvironment: (_) => {
        'datasetGeneration': mutations.generation,
        'localeCode': 'zh_CN',
        'localDateTime': '2026-11-09T08:00:00+08:00',
      },
      prepareUndo: undo.prepare,
      commitUndo: undo.commit,
    );
    events = _EventLog(client.events);
    replaceDelegate();
    _opened = true;
    final created = await client.dispatch(
      const native.AgentCommand(
        kind: native.CommandKind.createConversation,
        text: 'Rust 原生离线旅程',
        mode: view.ViewPermissionMode.full,
      ),
    );
    id = created.id!;
    delegate.ingestSnapshot(created.snapshot!);
    await delegate.loadConversation(id);
  }

  void replaceDelegate() {
    delegate = RustAgentUiDelegate(
      client: client,
      readSettings: () => _settings,
      readApiKey: (_) async => 'offline-placeholder',
      onOpenSettings: () {},
      onSnapshot: (snapshot) =>
          conversation.value = conversationFromRust(snapshot),
    );
  }

  Future<view.ViewConversationSnapshot> snapshot() async =>
      (await delegate.loadConversation(id))!;

  Future<String> send(String text) async {
    await delegate.send(id, text);
    return (await snapshot()).conversation.runId!;
  }

  Future<void> settled(String runId) async {
    await events.wait(
      (event) =>
          event.kind == native.EventKind.runSettled && event.runId == runId,
    );
    await delegate.loadConversation(id);
  }

  Future<void> approval(String toolCallId) async {
    await events.wait(
      (event) =>
          event.snapshot?.operations.any(
            (operation) =>
                operation.toolCallId == toolCallId &&
                operation.phase == view.ViewOperationPhase.waitingApproval,
          ) ==
          true,
    );
    await delegate.loadConversation(id);
    expect(delegate.state.value.runFor(id).pendingApproval!.id, toolCallId);
  }

  Future<void> show(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _JourneyPane(journey: this)),
    ),
  );

  void invoke(Future<void> Function() action) {
    _uiError = null;
    _uiAction = Future<void>.sync(action)
        .catchError((Object error, StackTrace stack) {
          _uiError = (error, stack);
        });
  }

  Future<void> finishUiAction() async {
    await _uiAction!;
    final failure = _uiError;
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
  }

  Future<void> closeCore() async {
    if (!_opened || _coreClosed) return;
    await client.shutdown();
    await business.dispose();
    await delegate.dispose();
    await events.close();
    _coreClosed = true;
  }

  Future<void> close() async {
    if (!_opened) return;
    await closeCore();
    await mutations.waitForPendingWrites();
    await session.repository.waitForPendingWrites(propagateErrors: true);
    tools.dispose();
    await session.close();
    conversation.dispose();
  }
}

class _JourneyPane extends StatelessWidget {
  const _JourneyPane({required this.journey});
  final _Journey journey;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ValueListenableBuilder<AgentUiRunState>(
      valueListenable: journey.delegate.watchConversation(journey.id),
      builder: (context, state, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Rust Agent 离线旅程',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ValueListenableBuilder<AgentConversation?>(
            valueListenable: journey.conversation,
            builder: (context, conversation, _) {
              final reply = conversation?.messages
                  .where(
                    (message) =>
                        message.role == ConversationRole.assistant &&
                        message.text.isNotEmpty,
                  )
                  .lastOrNull;
              return AgentMessageContent(
                text: state.streamingText.isNotEmpty
                    ? state.streamingText
                    : reply?.text ?? '',
                roleLabel: 'Assistant',
                streaming: state.streamingText.isNotEmpty,
              );
            },
          ),
          if (state.pendingApproval case final approval?) ...[
            AgentPlanPreview(details: approval.details),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  key: const ValueKey('rust-journey-allow'),
                  onPressed: () => journey.invoke(
                    () => journey.delegate.approve(journey.id, approval.id),
                  ),
                  child: Text(l.agentApprove),
                ),
                OutlinedButton(
                  key: const ValueKey('rust-journey-reject'),
                  onPressed: () => journey.invoke(
                    () => journey.delegate.reject(journey.id, approval.id),
                  ),
                  child: Text(l.agentReject),
                ),
              ],
            ),
          ],
          if (state.isActive)
            FilledButton(
              key: const ValueKey('rust-journey-stop'),
              onPressed: () =>
                  journey.invoke(() => journey.delegate.stop(journey.id)),
              child: Text(l.agentStop),
            ),
        ],
      ),
    );
  }
}

class _WriteGate {
  Completer<void> entered = Completer<void>();
  Completer<void>? _release;

  void arm() {
    entered = Completer<void>();
    _release = Completer<void>();
  }

  Future<void> beforeReplace() async {
    final gate = _release;
    if (gate == null) return;
    if (!entered.isCompleted) entered.complete();
    await gate.future;
  }

  void release() {
    final gate = _release;
    _release = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

class _EventLog {
  _EventLog(Stream<native.AgentEvent> source) {
    _subscription = source.listen((event) {
      values.add(event);
      _changes.add(event);
    }, onError: _changes.addError);
  }
  final values = <native.AgentEvent>[];
  final _changes = StreamController<native.AgentEvent>.broadcast();
  late final StreamSubscription<native.AgentEvent> _subscription;

  Future<native.AgentEvent> wait(
    bool Function(native.AgentEvent) predicate,
  ) async {
    final existing = values.where(predicate).lastOrNull;
    if (existing != null) return existing;
    return _changes.stream
        .firstWhere(predicate)
        .timeout(const Duration(seconds: 20));
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _changes.close();
  }
}

List<native.OfflineModelReply> _replies() => [
  _reply(
    callId: 'discover',
    tool: 'capabilities.describe',
    arguments: {
      'names': ['mutation.apply'],
    },
  ),
  _reply(
    callId: 'create-first',
    tool: 'mutation.apply',
    arguments: _create('课后复习'),
  ),
  _reply(text: '已创建课后复习日程。'),
  _reply(
    callId: 'create-allowed',
    tool: 'mutation.apply',
    arguments: _create('已批准的安排'),
  ),
  _reply(text: '已按批准保存日程。'),
  _reply(
    callId: 'create-rejected',
    tool: 'mutation.apply',
    arguments: _create('不会保存的安排'),
  ),
  _reply(text: '该安排已取消，没有保存。'),
  _reply(
    callId: 'create-preview',
    tool: 'mutation.apply',
    arguments: _create('仅预览的安排'),
  ),
  _reply(text: '已经提供安排预览。'),
  _reply(
    callId: 'create-held',
    tool: 'mutation.apply',
    arguments: _create('停止时完成的保存'),
  ),
  _reply(text: '已根据真实保存结果完成总结。'),
  _reply(
    callId: 'create-shutdown',
    tool: 'mutation.apply',
    arguments: _create('退出时完成的保存'),
  ),
];

Map<String, Object?> _create(String title) => {
  'commands': [
    {
      'kind': 'event',
      'action': 'create',
      'destinationParentId': _calendarId,
      'values': {
        'title': title,
        'start': '2026-11-09T16:00:00',
        'end': '2026-11-09T17:00:00',
      },
    },
  ],
};

native.OfflineModelReply _reply({
  String text = '',
  String? callId,
  String? tool,
  Map<String, Object?>? arguments,
}) {
  final delta = tool == null
      ? <String, Object?>{'role': 'assistant', 'content': text}
      : <String, Object?>{
          'role': 'assistant',
          'tool_calls': [
            {
              'index': 0,
              'id': callId,
              'type': 'function',
              'function': {
                'name': tool.replaceAll('_', '_u').replaceAll('.', '__'),
                'arguments': jsonEncode(arguments),
              },
            },
          ],
        };
  Map<String, Object?> chunk(
    Map<String, Object?> part,
    String? finish, {
    bool usage = false,
  }) => {
    'id': 'offline-${callId ?? 'answer'}',
    'object': 'chat.completion.chunk',
    'created': 0,
    'model': _model,
    'choices': [
      {'index': 0, 'delta': part, 'finish_reason': finish},
    ],
    if (usage)
      'usage': {
        'prompt_tokens': 100,
        'completion_tokens': 12,
        'total_tokens': 112,
      },
  };
  return native.OfflineModelReply(
    status: 200,
    contentType: 'text/event-stream',
    body:
        'data: ${jsonEncode(chunk(delta, null))}\n\n'
        'data: ${jsonEncode(chunk({}, tool == null ? 'stop' : 'tool_calls', usage: true))}\n\n'
        'data: [DONE]\n\n',
  );
}
