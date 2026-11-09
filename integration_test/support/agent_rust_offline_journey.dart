import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
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
import 'package:sked/agent/bridge/rust_agent_ui_delegate.dart';
import 'package:sked/agent/bridge/rust_conversation_repository.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/references/agent_composer_reference.dart';
import 'package:sked/agent/tools/application_tool_host.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/application/mutation_coordinator.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/backup/selective_backup_agent_store.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/timetable_models.dart';

import 'agent_rust_offline_workspace.dart';
import 'agent_rust_backup_journey.dart';
import 'agent_rust_history_journey.dart';
import 'agent_rust_clear_journey.dart';

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
    expect(journey.conversations.isDraft(journey.id), isTrue);
    expect(journey.conversations.conversations, isEmpty);
    expect(journey.conversations.selected!.draft, '准备创建复习日程');
    expect(journey.conversations.selected!.draftReferences, hasLength(1));
    checkpoints.add('独立Rust仓储创建应用内草稿并按字段保存输入');

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
    expect(journey.conversations.isDraft(journey.id), isFalse);
    expect(journey.conversations.conversations, hasLength(1));
    final paged = RustConversationRepository(journey.client, pageSize: 2);
    await paged.load();
    await paged.select(journey.id);
    final recent = paged.visibleMessages(journey.id);
    expect(recent.length, lessThan(first.messages.length));
    expect(recent.first.role, isNot(ConversationRole.tool));
    expect(paged.hasEarlierMessages(journey.id), isTrue);
    await paged.read(journey.id);
    expect(
      paged.visibleMessages(journey.id).map((message) => message.id),
      recent.map((message) => message.id),
    );
    while (paged.hasEarlierMessages(journey.id)) {
      await paged.loadEarlierMessages(journey.id);
    }
    expect(
      paged.visibleMessages(journey.id).map((message) => message.id),
      first.messages.map((message) => message.id),
    );
    paged.dispose();
    final unsent = await journey.conversations.createDraft(title: '稍后继续的草稿');
    await journey.conversations.updateDraftText(unsent.id, '保留应用内输入');
    await journey.conversations.select(journey.id);
    expect(
      (await journey.conversations.createDraft(title: '复用草稿')).id,
      unsent.id,
    );
    expect(journey.conversations.selected!.draft, '保留应用内输入');
    await journey.conversations.select(journey.id);
    checkpoints.add('首次接纳转入历史、完整工具分页、后台全读保持窗口与草稿切换');

    final queuedBytes = Uint8List.fromList([1, 4, 9]);
    final queuedSource = await File(path.join(root.path, 'queued.bin'))
        .writeAsBytes(queuedBytes);
    await journey.workspace.app.agent.binaryAttachments.attach(
      journey.id,
      XFile(queuedSource.path, mimeType: 'application/octet-stream'),
      canModify: () => journey.conversations.canWrite,
    );
    final queuedFile = journey.conversations
        .find(journey.id)!
        .attachments
        .single;
    await journey.conversations.updateDraftReferences(journey.id, [
      AgentComposerReference.attachment(
        attachment: queuedFile,
        conversationId: journey.id,
      ),
    ]);
    await journey.delegate.queueFollowUp(journey.id, '仅排队并恢复输入');
    final queued = journey.conversations.find(journey.id)!.queuedInputs.single;
    expect(queued.attachmentIds, [queuedFile.id]);
    expect(queued.contextReferences, hasLength(1));
    await journey.delegate.restoreQueuedInput(
      journey.id,
      queued.asUserMessage(),
    );
    final restoredInput = journey.conversations.find(journey.id)!;
    expect(restoredInput.queuedInputs, isEmpty);
    expect(restoredInput.draft, '仅排队并恢复输入');
    expect(restoredInput.draftAttachmentIds, [queuedFile.id]);
    expect(restoredInput.draftReferences.single.attachmentId, queuedFile.id);
    expect(
      await journey.workspace.app.agent.attachmentStore.readBytes(queuedFile),
      queuedBytes,
    );
    await journey.delegate.queueFollowUp(journey.id, restoredInput.draft);
    await journey.delegate.cancelQueuedInput(
      journey.id,
      journey.conversations
          .find(journey.id)!
          .queuedInputs
          .single
          .asUserMessage(),
    );
    expect(journey.conversations.find(journey.id)!.queuedInputs, isEmpty);
    expect(journey.conversations.find(journey.id)!.draft, isEmpty);
    expect(journey.conversations.find(journey.id)!.runId, firstRun);
    checkpoints.add('队列恢复原子转回正文、引用与二进制；取消队列不发起模型');

    await journey.delegate.setMode(journey.id, AgentPermissionMode.ask);
    final allowedRun = await journey.send('再创建一个需要确认的日程');
    await journey.approval('create-allowed');
    final approvalDetails = journey.delegate.state.value
        .runFor(journey.id)
        .pendingApproval!
        .details;
    final approvalChange = (approvalDetails['changes'] as List).single as Map;
    expect(approvalChange, containsPair('before', null));
    final approvalAfter = Map<String, Object?>.from(
      approvalChange['after'] as Map,
    );
    expect(approvalAfter['title'], '已批准的安排');
    expect(
      approvalDetails,
      containsPair('references', const <String, Object?>{}),
    );
    expect(journey.eventTitles, ['课后复习']);
    await tester.pump();
    expect(find.byType(AgentPlanPreview), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rust-journey-allow')));
    await journey.finishUiAction();
    await journey.settled(allowedRun);
    expect(journey.eventTitles, unorderedEquals(['课后复习', '已批准的安排']));
    expect(
      journey.session.committedData.generalMode.schedules.single.events
          .singleWhere((event) => event.id == approvalAfter['id'])
          .toJson(),
      approvalAfter,
    );
    checkpoints.add('真实审批传递完整候选，允许后保存相同对象');

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

    await journey.delegate.setMode(journey.id, AgentPermissionMode.ask);
    final replacedRun = await journey.send('先提议一个待审批安排');
    await journey.approval('create-steer-approval');
    const steeringText = '改为只解释安排，不保存这项提议';
    await journey.delegate.steer(journey.id, steeringText);
    final steered = await journey.events.wait(
      (event) =>
          event.snapshot?.conversation.id == journey.id &&
          event.snapshot?.conversation.runId != replacedRun &&
          event.snapshot!.messages.any(
            (message) => message.text == steeringText,
          ),
    );
    await journey.settled(steered.snapshot!.conversation.runId!);
    await expectLater(
      journey.delegate.approve(journey.id, 'create-steer-approval'),
      throwsA(isA<Object>()),
    );
    final afterSteer = await journey.snapshot();
    expect(
      afterSteer.operations
          .singleWhere(
            (operation) => operation.toolCallId == 'create-steer-approval',
          )
          .phase,
      view.ViewOperationPhase.cancelled,
    );
    expect(afterSteer.conversation.runId, isNot(replacedRun));
    expect(journey.eventTitles, unorderedEquals(['课后复习', '已批准的安排']));
    checkpoints.add('审批中补充要求取消原票据，新轮次不能批准旧操作');

    await journey.delegate.setMode(journey.id, AgentPermissionMode.full);
    journey.writeGate.arm();
    final heldRun = await journey.send('保存期间关闭界面，然后继续管理任务');
    await journey.writeGate.entered.future.timeout(const Duration(seconds: 20));
    await tester.pumpWidget(const SizedBox.shrink());
    journey.detachView();
    final stillRunning = await journey.client.query(
      native.AgentQuery(
        kind: native.QueryKind.readConversation,
        conversationId: journey.id,
      ),
    );
    expect(stillRunning.presentation!.active, isTrue);
    expect(journey.eventTitles, unorderedEquals(['课后复习', '已批准的安排']));
    journey.attachView();
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

    final backupHistory = await NativeAgentBackupStore(journey.client)
        .exportParts(conversationIds: [journey.id], knowledgeKeys: const []);
    final backupSeed = journey.session.committedData;

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
      expect(
        (await reopened.query(
          query: native.AgentQuery(
            kind: native.QueryKind.readConversation,
            conversationId: unsent.id,
          ),
        )).snapshot,
        isNull,
      );
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
    await runRustAgentBackupJourney(
      root: root,
      seed: backupSeed,
      historyParts: backupHistory,
      checkpoints: checkpoints,
    );
    await runRustHistoryJourney(root, checkpoints);
    await runRustAgentClearJourney(root, backupSeed, checkpoints);
  } finally {
    journey.writeGate.release();
    await tester.pumpWidget(const SizedBox.shrink());
    await journey.close();
    await root.delete(recursive: true);
    report['temporaryDataRemoved'] = !await root.exists();
  }
}

class _Journey {
  _Journey(this.root) : workspace = OfflineAgentWorkspace(root);
  final Directory root;
  final OfflineAgentWorkspace workspace;
  Directory get businessDirectory => workspace.businessDirectory;
  Directory get agentDirectory => workspace.agentDirectory;
  OfflineWriteGate get writeGate => workspace.writeGate;
  final conversation = ValueNotifier<AgentConversation?>(null);
  AppSession get session => workspace.app.session;
  MutationCoordinator get mutations => workspace.app.agent.mutations;
  ApplicationToolHost get tools => workspace.app.agent.tools;
  AgentRustClient get client => workspace.client;
  RustAgentBusinessHost get business => workspace.app.agent.businessHost;
  RustAgentUiDelegate get delegate => workspace.app.agent.runtime;
  RustConversationRepository get conversations =>
      workspace.app.agent.conversations;
  late _EventLog events;
  late String id;
  bool _opened = false;
  bool _coreClosed = false;
  bool _viewAttached = false;
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
    await workspace.open(seed: seed, replies: _replies());
    events = _EventLog(client.events);
    _opened = true;
    await conversations.load();
    final created = await conversations.createDraft(
      title: 'Rust 原生离线旅程',
      mode: AgentPermissionMode.full,
    );
    id = created.id;
    attachView();
    await conversations.updateDraftReferences(id, [
      AgentComposerReference.resource(
        ref: const ResourceRef(kind: ResourceKind.calendar, id: _calendarId),
        datasetGeneration: mutations.generation,
        label: '离线旅程日历',
      ),
    ]);
    await conversations.updateDraftText(id, '准备创建复习日程');
    await delegate.loadConversation(id);
  }

  void attachView() {
    if (_viewAttached) return;
    conversations.addListener(_updateView);
    _viewAttached = true;
    _updateView();
  }

  void _updateView() => conversation.value = conversations.find(id);

  void detachView() {
    if (!_viewAttached) return;
    conversations.removeListener(_updateView);
    _viewAttached = false;
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
    detachView();
    await workspace.closeCore();
    await events.close();
    _coreClosed = true;
  }

  Future<void> close() async {
    if (!_opened) return;
    await closeCore();
    await workspace.close();
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
    callId: 'create-steer-approval',
    tool: 'mutation.apply',
    arguments: _create('已被补充要求取消的安排'),
  ),
  _reply(text: '已按补充要求解释安排，没有保存原提议。'),
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
