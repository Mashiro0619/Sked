import 'dart:async';
import 'dart:math' as math;

import 'package:sked/agent/bridge/generated/api.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart';
import 'package:sked/agent/bridge/generated/api/history.dart';
import 'package:sked/agent/bridge/generated/api/management_contracts.dart';
import 'package:sked/agent/bridge/generated/api/models.dart';
import 'package:sked/agent/bridge/knowledge_projection.dart';
import 'package:sked/agent/bridge/rust_agent_client.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';

export 'package:sked/agent/bridge/generated/api/contracts.dart';
export 'package:sked/agent/bridge/generated/api/models.dart';

/// Typed view fixture for application/settings widget tests. Native execution,
/// persistence and recovery are exercised by the formal offline journey.
class MemoryAgentCore implements AgentCore {
  MemoryAgentCore({Iterable<ViewConversationSnapshot> snapshots = const []}) {
    for (final snapshot in snapshots) {
      this.snapshots[snapshot.conversation.id] = snapshot;
    }
  }

  final snapshots = <String, ViewConversationSnapshot>{};
  final knowledge = <String, ViewKnowledgeRecord>{};
  final originals = <String, ViewKnowledgeRecord>{};
  final queries = <AgentQuery>[];
  final commands = <AgentCommand>[];
  final presentations = <String, RunPresentation>{};
  final modelRequests = <AgentCommand>[];
  final _handoffConversations = <String, String>{};
  final _startedHandoffs = <String>{};
  Future<void> Function()? beforeSave;
  bool fail = false;
  String handoffReply = 'Please confirm the period times before importing.';
  final _events = StreamController<AgentEvent>.broadcast();
  Future<void> Function()? beforeInitialize;
  Future<void> Function(AgentQuery)? beforeQuery;
  Future<void> Function(AgentCommand)? beforeDispatch;
  int initializationCount = 0;
  int shutdownCount = 0;
  int revision = 0;
  int _nextId = 0;
  String? selectedId;
  Map<String, ViewConversationSnapshot> get source => Map.unmodifiable({
    for (final entry in snapshots.entries)
      if (!entry.value.conversation.draftOnly) entry.key: entry.value,
  });
  List<ToolDefinition> _tools = const [];

  late final client = AgentRustClient(
    initialize: () async {
      initializationCount++;
      await beforeInitialize?.call();
      return this;
    },
  );

  ConversationSelection get selection => ConversationSelection(
    selectedId: selectedId,
    draftId: snapshots.values
        .where((snapshot) => snapshot.conversation.draftOnly)
        .firstOrNull
        ?.conversation
        .id,
  );

  void publish(ViewConversationSnapshot snapshot) {
    snapshots[snapshot.conversation.id] = snapshot;
    _events.add(
      AgentEvent(
        kind: EventKind.snapshot,
        conversationId: snapshot.conversation.id,
        snapshot: snapshot,
        presentation:
            presentations[snapshot.conversation.id] ??
            _fixturePresentation(snapshot),
      ),
    );
  }

  void emit(AgentEvent event) => _events.add(event);

  @override
  Stream<AgentEvent> watchEvents() async* {
    yield const AgentEvent(kind: EventKind.ready, conversationId: '');
    yield* _events.stream;
  }

  @override
  Future<QueryResult> query({required AgentQuery query}) async {
    queries.add(query);
    await beforeQuery?.call(query);
    final snapshot = snapshots[query.conversationId];
    var records = knowledge.values.toList();
    var summaries = <ViewConversationSummary>[];
    var messages = <ViewMessage>[];
    int? start;
    int? next;
    var total = 0;
    switch (query.kind) {
      case QueryKind.conversations:
        final values = snapshots.values
            .where(
              (value) =>
                  (query.includeDrafts == true ||
                      !value.conversation.draftOnly) &&
                  (query.archived == null ||
                      value.conversation.archived == query.archived),
            )
            .toList();
        total = values.length;
        final offset = query.offset ?? 0;
        summaries = values
            .skip(offset)
            .take(query.limit ?? values.length)
            .map(
              (value) => ViewConversationSummary(
                id: value.conversation.id,
                title: value.conversation.title,
                pinned: value.conversation.pinned,
                archived: value.conversation.archived,
                draftOnly: value.conversation.draftOnly,
                createdAt: value.conversation.createdAt,
                updatedAt: value.conversation.updatedAt,
                status: value.conversation.status,
                hasPendingWork: false,
                sequence: value.sequence,
                messageCount: value.messages.length,
              ),
            )
            .toList();
        if (offset + summaries.length < total) next = offset + summaries.length;
      case QueryKind.readConversation || QueryKind.messages:
        final all = snapshot?.messages ?? const <ViewMessage>[];
        total = all.length;
        final end = math.min(query.before ?? all.length, all.length);
        start = query.limit == null ? 0 : math.max(0, end - query.limit!);
        messages = all.sublist(start, end);
        if (start > 0) next = start;
      case QueryKind.readKnowledgeRecord:
        records = [?knowledge[query.targetId]];
      case QueryKind.conversationSelection ||
          QueryKind.knowledgeCatalog ||
          QueryKind.knowledge ||
          QueryKind.knowledgeRevision ||
          QueryKind.knowledgeState ||
          QueryKind.attachments ||
          QueryKind.canContinue:
        break;
      default:
        throw UnsupportedError('UI fixture query: ${query.kind.name}');
    }
    return QueryResult(
      conversations: summaries,
      snapshot: snapshot == null
          ? null
          : copyNativeSnapshot(
              snapshot,
              messages: start == null ? null : messages,
            ),
      messages: messages,
      total: total,
      nextOffset: next,
      pageStart: start,
      knowledge: records,
      revision: revision,
      knowledgeState: ViewKnowledgeState(
        revision: revision,
        storageRevision: revision,
        records: records,
        tombstones: const {},
        receipts: const [],
        undoBatches: const [],
      ),
      knowledgeCatalog: KnowledgeCatalog(
        revision: revision,
        storageRevision: revision,
        records: records,
        originalDigests: {
          for (final record in originals.values)
            record.id: knowledgeDigest(record.body),
        },
      ),
      attachments: snapshot?.attachments ?? const [],
      selection: selection,
      flag: false,
      presentation:
          presentations[query.conversationId] ?? _fixturePresentation(snapshot),
    );
  }

  @override
  Future<CommandResult> dispatch({required AgentCommand command}) async {
    commands.add(command);
    await beforeDispatch?.call(command);
    switch (command.kind) {
      case CommandKind.createHandoff:
        final request = command.handoff!;
        final prior = _handoffConversations[request.handoffId];
        if (prior != null) {
          selectedId = prior;
          return CommandResult(
            id: prior,
            snapshot: snapshots[prior],
            selection: selection,
            created: false,
          );
        }
        await beforeSave?.call();
        if (fail) throw StateError('Synthetic UI handoff publication failure');
        final id = 'ui-handoff-${++_nextId}';
        final message = nativeMessageFixture(
          id: '$id-request',
          text: request.prompt,
          role: ViewMessageRole.user,
        );
        final snapshot = copyNativeSnapshot(
          nativeConversationFixture(
            id: id,
            title: request.title,
            mode: request.mode,
            modelSelection: request.selection,
            messages: [message],
          ),
          sources: [request.source],
          handoffs: [
            ViewConversationHandoff(
              id: request.handoffId,
              conversationId: id,
              sourceDigest: knowledgeDigest(request.source.text),
              messageId: message.id,
            ),
          ],
        );
        _handoffConversations[request.handoffId] = id;
        selectedId = id;
        publish(snapshot);
        return CommandResult(
          id: id,
          snapshot: snapshot,
          selection: selection,
          created: true,
        );
      case CommandKind.startHandoff:
        final id = command.conversationId!;
        final old = snapshots[id]!;
        if (_startedHandoffs.add(id)) {
          modelRequests.add(command);
          final snapshot = copyNativeSnapshot(
            old,
            sequence: old.sequence + 1,
            messages: [
              ...old.messages,
              nativeMessageFixture(id: '$id-reply', text: handoffReply),
            ],
          );
          publish(snapshot);
          return CommandResult(id: id, snapshot: snapshot);
        }
        return CommandResult(id: id, snapshot: old);
      case CommandKind.setTools:
        _tools = command.tools!;
        return const CommandResult();
      case CommandKind.setPreamble ||
          CommandKind.quiesce ||
          CommandKind.collectAttachments ||
          CommandKind.stop:
        return const CommandResult();
      case CommandKind.createConversation ||
          CommandKind.createManagedConversation:
        final id =
            command.conversationId ??
            command.targetId ??
            'ui-conversation-${++_nextId}';
        final snapshot = nativeConversationFixture(
          id: id,
          title: command.text ?? '',
          draftOnly: command.kind == CommandKind.createConversation,
          mode: command.mode ?? ViewPermissionMode.ask,
          modelSelection: command.selection,
        );
        selectedId = id;
        publish(snapshot);
        return CommandResult(id: id, snapshot: snapshot, selection: selection);
      case CommandKind.selectConversation:
        selectedId = command.conversationId;
        return CommandResult(selection: selection);
      case CommandKind.deleteConversation:
        snapshots.remove(command.conversationId);
        if (selectedId == command.conversationId) selectedId = null;
        return CommandResult(selection: selection);
      case CommandKind.discardDrafts:
        snapshots.removeWhere((_, value) => value.conversation.draftOnly);
        if (!snapshots.containsKey(selectedId)) selectedId = null;
        return CommandResult(selection: selection);
      case CommandKind.rename ||
          CommandKind.pin ||
          CommandKind.archive ||
          CommandKind.updateDraft ||
          CommandKind.setMode ||
          CommandKind.setModel:
        final old = snapshots[command.conversationId]!;
        final value = old.conversation;
        final next = copyNativeSnapshot(
          old,
          sequence: old.sequence + 1,
          conversation: ViewConversation(
            id: value.id,
            title: command.kind == CommandKind.rename
                ? command.text!
                : value.title,
            titleWasEdited:
                command.kind == CommandKind.rename || value.titleWasEdited,
            pinned: command.kind == CommandKind.pin
                ? command.flag!
                : value.pinned,
            archived: command.kind == CommandKind.archive
                ? command.flag!
                : value.archived,
            draftOnly: value.draftOnly,
            createdAt: value.createdAt,
            updatedAt: value.updatedAt,
            mode: command.mode ?? value.mode,
            status: value.status,
            draft: command.kind == CommandKind.updateDraft
                ? command.text ?? value.draft
                : value.draft,
            draftAttachmentIds:
                command.attachmentIds ?? value.draftAttachmentIds,
            draftReferences: command.references ?? value.draftReferences,
            modelSelection: command.selection ?? value.modelSelection,
            connectionFingerprint: value.connectionFingerprint,
            runId: value.runId,
            executionHistoryStart: value.executionHistoryStart,
            titleGeneration: value.titleGeneration,
          ),
        );
        publish(next);
        return CommandResult(
          id: value.id,
          snapshot: next,
          selection: selection,
        );
      default:
        throw UnsupportedError('UI fixture command: ${command.kind.name}');
    }
  }

  @override
  Future<List<ToolDefinition>> toolDefinitions() async => [
    ..._tools,
    for (final name in const [
      'ask_user',
      'update_plan',
      'skills.search',
      'skills.load',
      'skills.get',
      'skills.apply',
      'memories.search',
      'memories.get',
      'memories.apply',
      'knowledge.undo',
      'knowledge.changes.get',
      'conversation.get',
      'conversation.history',
      'conversation.read',
    ])
      ToolDefinition(
        name: name,
        description: name,
        parameters: const JsonPayload(json: '{"type":"object"}'),
      ),
  ];

  @override
  Future<ViewKnowledgeState> registerBuiltinSkills({
    required List<ViewKnowledgeRecord> records,
  }) async {
    for (final record in records) {
      originals[record.id] = record;
      knowledge.putIfAbsent('skill:${record.id}', () => record);
    }
    return ViewKnowledgeState(
      revision: revision,
      storageRevision: revision,
      records: knowledge.values.toList(),
      tombstones: const {},
      receipts: const [],
      undoBatches: const [],
    );
  }

  @override
  Future<ViewKnowledgeReceipt> editKnowledge({
    required KnowledgeEdit request,
  }) async {
    final id = request.id ?? 'ui-${request.kind.name}-${++_nextId}';
    final key = '${request.kind.name}:$id';
    final before = knowledge[key];
    if ((before?.revision ?? 0) != request.expectedRevision) {
      throw StateError('knowledge_conflict');
    }
    revision++;
    ViewKnowledgeRecord? after;
    if (request.action != KnowledgeEditAction.delete) {
      final source = request.action == KnowledgeEditAction.restoreOriginal
          ? originals[id]!
          : request.desired!;
      final record = knowledgeRecordFromRust(source);
      after = knowledgeDraftToRust(
        KnowledgeRecord.fromJson({
          ...record.toJson(),
          'id': id,
          'revision': revision,
          if (request.action == KnowledgeEditAction.restoreOriginal)
            'enabled': before?.enabled ?? true,
        }),
      );
      knowledge[key] = after;
    } else {
      knowledge.remove(key);
    }
    final receipt = ViewKnowledgeReceipt(
      operationId: 'ui-knowledge-$revision',
      digest: knowledgeDigest('$key:$revision'),
      revision: revision,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      changes: [
        ViewKnowledgeChange(
          key: key,
          expectedRevision: request.expectedRevision,
          before: before,
          after: after,
        ),
      ],
      inverseOperationIds: const [],
    );
    _events.add(
      AgentEvent(
        kind: EventKind.knowledgeChanged,
        conversationId: '',
        knowledgeRevision: revision,
      ),
    );
    return receipt;
  }

  @override
  Future<List<HistoryRecoveryTarget>> historyRecoveryTargets() async =>
      const [];

  @override
  Future<List<String>> recoverOperations({String? conversationId}) async =>
      const [];

  @override
  Future<List<String>> pruneHistory({required int cutoffMs}) async => const [];

  @override
  Future<void> shutdown() async {
    shutdownCount++;
    // AgentRustClient cancels its native subscription after shutdown returns.
    unawaited(_events.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'UI fixture does not implement ${invocation.memberName}',
  );
}

RunPresentation _fixturePresentation(ViewConversationSnapshot? snapshot) =>
    RunPresentation(
      active: const {
        ViewConversationStatus.running,
        ViewConversationStatus.waitingApproval,
        ViewConversationStatus.waitingUser,
      }.contains(snapshot?.conversation.status),
      canContinue: false,
      compacting: false,
    );

ViewConversationSnapshot nativeConversationFixture({
  String id = 'ui-conversation',
  String title = 'Conversation',
  String draft = '',
  bool draftOnly = false,
  ViewPermissionMode mode = ViewPermissionMode.ask,
  ViewModelSelection? modelSelection,
  List<ViewMessage> messages = const [],
}) => ViewConversationSnapshot(
  conversation: ViewConversation(
    id: id,
    title: title,
    titleWasEdited: false,
    pinned: false,
    archived: false,
    draftOnly: draftOnly,
    createdAt: 1793664000000,
    updatedAt: 1793664000000,
    mode: mode,
    status: ViewConversationStatus.idle,
    draft: draft,
    draftAttachmentIds: const [],
    draftReferences: const [],
    modelSelection: modelSelection,
    executionHistoryStart: 0,
  ),
  sequence: 1,
  messages: messages,
  runs: const [],
  turns: const [],
  operations: const [],
  queuedInputs: const [],
  queuedControls: const [],
  contextFailures: const [],
  historyVersions: const [],
  replyRevisions: const [],
  redoBatches: const [],
  attachments: const [],
  attachmentReferences: const [],
  sources: const [],
  handoffs: const [],
  providerHistory: const [],
  extensions: const {},
);

ViewConversationSnapshot copyNativeSnapshot(
  ViewConversationSnapshot value, {
  ViewConversation? conversation,
  int? sequence,
  List<ViewMessage>? messages,
  List<ViewQueuedInput>? queuedInputs,
  List<ViewConversationSource>? sources,
  List<ViewConversationHandoff>? handoffs,
}) => ViewConversationSnapshot(
  conversation: conversation ?? value.conversation,
  sequence: sequence ?? value.sequence,
  messages: messages ?? value.messages,
  runs: value.runs,
  turns: value.turns,
  operations: value.operations,
  queuedInputs: queuedInputs ?? value.queuedInputs,
  queuedControls: value.queuedControls,
  currentQuestion: value.currentQuestion,
  plan: value.plan,
  checkpoint: value.checkpoint,
  contextFailures: value.contextFailures,
  historyVersions: value.historyVersions,
  replyRevisions: value.replyRevisions,
  redoBatches: value.redoBatches,
  attachments: value.attachments,
  attachmentReferences: value.attachmentReferences,
  sources: sources ?? value.sources,
  handoffs: handoffs ?? value.handoffs,
  providerHistory: value.providerHistory,
  extensions: value.extensions,
);

ViewMessage nativeMessageFixture({
  required String id,
  required String text,
  ViewMessageRole role = ViewMessageRole.assistant,
  int createdAt = 1793664000000,
}) => ViewMessage(
  id: id,
  role: role,
  text: text,
  createdAt: createdAt,
  toolCalls: const [],
  responseItems: const [],
  attachmentIds: const [],
  contextReferences: const [],
  attachmentDelivery: ViewAttachmentDelivery.local,
);

ViewConversation copyNativeConversation(
  ViewConversation value, {
  String? title,
  String? draft,
  bool? archived,
  bool? draftOnly,
  ViewConversationStatus? status,
  String? runId,
  bool clearRun = false,
}) => ViewConversation(
  id: value.id,
  title: title ?? value.title,
  titleWasEdited: value.titleWasEdited,
  pinned: value.pinned,
  archived: archived ?? value.archived,
  draftOnly: draftOnly ?? value.draftOnly,
  createdAt: value.createdAt,
  updatedAt: value.updatedAt,
  mode: value.mode,
  status: status ?? value.status,
  draft: draft ?? value.draft,
  draftAttachmentIds: value.draftAttachmentIds,
  draftReferences: value.draftReferences,
  modelSelection: value.modelSelection,
  connectionFingerprint: value.connectionFingerprint,
  runId: clearRun ? null : runId ?? value.runId,
  executionHistoryStart: value.executionHistoryStart,
  titleGeneration: value.titleGeneration,
);
