import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sked/agent/bridge/generated/api.dart';
import 'package:sked/agent/bridge/generated/api/contracts.dart';
import 'package:sked/agent/bridge/generated/api/history.dart';
import 'package:sked/agent/bridge/generated/api/management_contracts.dart';
import 'package:sked/agent/bridge/generated/api/models.dart';
import 'package:sked/agent/bridge/generated/api/ui.dart';
import 'package:sked/agent/bridge/generated/api/ui_contracts.dart';
import 'package:sked/agent/bridge/knowledge_projection.dart';
import 'package:sked/agent/bridge/rust_agent_client.dart';
import 'package:sked/agent/knowledge/knowledge_models.dart';
import 'package:sked/application/mutation_coordinator.dart' show mutationDigest;

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
  final _assistantCommits =
      <String, ({String? id, String? text, int revision})>{};
  final _cancelledAttachmentImports = <String>{};
  Future<void> Function()? beforeSave;
  bool fail = false;
  String handoffReply = 'Please confirm the period times before importing.';
  final _events = StreamController<AgentEvent>.broadcast();
  final _uiSubscriptions = <_MemoryUiContributionSubscription>[];
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

  ViewConversationState stateFor(ViewConversationSnapshot snapshot) {
    final assistant = snapshot.messages
        .where((message) => message.role == ViewMessageRole.assistant)
        .lastOrNull;
    final previous = _assistantCommits[snapshot.conversation.id];
    final revision =
        previous != null &&
            previous.id == assistant?.id &&
            previous.text == assistant?.text
        ? previous.revision
        : snapshot.sequence;
    _assistantCommits[snapshot.conversation.id] = (
      id: assistant?.id,
      text: assistant?.text,
      revision: revision,
    );
    return nativeStateFixture(
      snapshot,
      lastCommittedAssistantRevision: revision,
    );
  }

  void publish(
    ViewConversationSnapshot snapshot, {
    RunPresentation? presentation,
  }) {
    snapshots[snapshot.conversation.id] = snapshot;
    _events.add(
      AgentEvent(
        kind: EventKind.snapshot,
        conversationId: snapshot.conversation.id,
        state: stateFor(snapshot),
        presentation:
            presentation ??
            presentations[snapshot.conversation.id] ??
            _fixturePresentation(snapshot),
      ),
    );
  }

  void emit(AgentEvent event) {
    if (event.kind == EventKind.snapshot && event.snapshot != null) {
      publish(event.snapshot!, presentation: event.presentation);
    } else {
      _events.add(event);
    }
  }

  @override
  Stream<AgentEvent> watchEvents() async* {
    yield const AgentEvent(kind: EventKind.ready, conversationId: '');
    yield* _events.stream;
  }

  @override
  UiContributionSubscription openUiContributions() {
    final subscription = _MemoryUiContributionSubscription();
    _uiSubscriptions.add(subscription);
    return subscription;
  }

  @override
  Future<QueryResult> query({required AgentQuery query}) async {
    queries.add(query);
    await beforeQuery?.call(query);
    final snapshot = snapshots[query.conversationId];
    final presentation =
        presentations[query.conversationId] ?? _fixturePresentation(snapshot);
    switch (query.kind) {
      case QueryKind.conversations:
        final values = snapshots.values
            .where(
              (value) =>
                  (query.includeDrafts == true ||
                      !value.conversation.draftOnly) &&
                  (query.archived == null ||
                      value.conversation.archived == query.archived) &&
                  (query.search == null ||
                      value.conversation.title.toLowerCase().contains(
                        query.search!.toLowerCase(),
                      )),
            )
            .toList();
        values.sort((left, right) {
          final pinned = (right.conversation.pinned ? 1 : 0).compareTo(
            left.conversation.pinned ? 1 : 0,
          );
          if (pinned != 0) return pinned;
          final updated = right.conversation.updatedAt.compareTo(
            left.conversation.updatedAt,
          );
          return updated != 0
              ? updated
              : left.conversation.id.compareTo(right.conversation.id);
        });
        final offset = query.offset ?? 0;
        final selected = values
            .skip(offset)
            .take(query.limit ?? 100)
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
                hasPendingWork:
                    value.conversation.status != ViewConversationStatus.idle ||
                    value.queuedInputs.isNotEmpty ||
                    value.operations.any(_pendingOperation) ||
                    value.redoBatches.any(_pendingRedo),
                sequence: value.sequence,
                messageCount: value.messages.length,
              ),
            )
            .toList();
        return nativeQueryResultFixture(
          conversations: selected,
          total: values.length,
          nextOffset: offset + selected.length < values.length
              ? offset + selected.length
              : null,
        );
      case QueryKind.conversationSelection:
        return nativeQueryResultFixture(selection: selection);
      case QueryKind.conversationState:
        return nativeQueryResultFixture(
          state: snapshot == null ? null : stateFor(snapshot),
          presentation: presentation,
        );
      case QueryKind.conversationPage:
        return nativeQueryResultFixture(
          state: snapshot == null ? null : stateFor(snapshot),
          page: snapshot == null
              ? null
              : nativePageFixture(
                  snapshot,
                  before: query.before,
                  beforeMessageId: query.beforeMessageId,
                  fromMessageId: query.fromMessageId,
                  limit: query.limit ?? 50,
                ),
        );
      case QueryKind.readConversation:
        return nativeQueryResultFixture(
          snapshot: snapshot,
          total: snapshot?.messages.length ?? 0,
          pageStart: snapshot == null ? null : 0,
          presentation: presentation,
        );
      case QueryKind.messages:
        if (snapshot == null) return nativeQueryResultFixture();
        if (query.search?.isNotEmpty == true) {
          final matches = snapshot.messages
              .asMap()
              .entries
              .where(
                (entry) => entry.value.text.toLowerCase().contains(
                  query.search!.toLowerCase(),
                ),
              )
              .toList();
          final eligible = matches
              .where(
                (entry) =>
                    entry.key < (query.before ?? snapshot.messages.length),
              )
              .toList();
          final start = math.max(0, eligible.length - (query.limit ?? 50));
          final selected = eligible.skip(start).toList();
          return nativeQueryResultFixture(
            messages: selected
                .map((entry) => nativeDisplayMessageFixture(entry.value))
                .toList(),
            total: matches.length,
            nextOffset: start > 0 ? selected.first.key : null,
          );
        }
        final page = nativePageFixture(
          snapshot,
          before: query.before,
          limit: query.limit ?? 50,
        );
        return nativeQueryResultFixture(
          messages: page.messages,
          total: page.total,
          nextOffset: page.nextOffset,
        );
      case QueryKind.message:
        final message = snapshot?.messages
            .where((message) => message.id == query.targetId)
            .firstOrNull;
        return nativeQueryResultFixture(
          message: message == null
              ? null
              : nativeDisplayMessageFixture(message),
        );
      case QueryKind.historyVersions:
        final versions =
            snapshot?.historyVersions.reversed.toList() ??
            const <ViewHistoryVersion>[];
        final offset = query.offset ?? 0;
        final selected = versions
            .skip(offset)
            .take(query.limit ?? 50)
            .map(nativeHistoryVersionSummaryFixture)
            .toList();
        return nativeQueryResultFixture(
          historyVersions: selected,
          total: versions.length,
          nextOffset: offset + selected.length < versions.length
              ? offset + selected.length
              : null,
        );
      case QueryKind.historyVersionPage:
        final version = snapshot?.historyVersions
            .where((version) => version.id == query.targetId)
            .firstOrNull;
        return nativeQueryResultFixture(
          historyPage: version == null
              ? null
              : ViewHistoryMessagePage(
                  version: nativeHistoryVersionSummaryFixture(version),
                  page: nativePageFixture(
                    snapshot!,
                    historyVersion: version,
                    before: query.before,
                    beforeMessageId: query.beforeMessageId,
                    limit: query.limit ?? 50,
                  ),
                ),
        );
      case QueryKind.replyRevisions:
        final versions =
            snapshot?.replyRevisions.reversed
                .where(
                  (revision) =>
                      query.targetId == null ||
                      query.targetId == '' ||
                      revision.messageId == query.targetId,
                )
                .toList() ??
            const <ViewReplyRevision>[];
        final offset = query.offset ?? 0;
        final selected = versions
            .skip(offset)
            .take(query.limit ?? 50)
            .map(nativeReplyRevisionSummaryFixture)
            .toList();
        return nativeQueryResultFixture(
          replyRevisions: selected,
          total: versions.length,
          nextOffset: offset + selected.length < versions.length
              ? offset + selected.length
              : null,
        );
      case QueryKind.replyRevision:
        final revision = snapshot?.replyRevisions
            .where((revision) => revision.id == query.targetId)
            .firstOrNull;
        return nativeQueryResultFixture(
          replyRevision: revision == null
              ? null
              : nativeDisplayReplyFixture(revision),
        );
      case QueryKind.source:
        return nativeQueryResultFixture(
          source: snapshot?.sources
              .where((source) => source.id == query.targetId)
              .firstOrNull,
        );
      case QueryKind.run:
        return nativeQueryResultFixture(
          run: snapshot?.runs
              .where((run) => run.id == query.targetId)
              .firstOrNull,
        );
      case QueryKind.historyRun:
        final version = snapshot?.historyVersions
            .where((version) => version.id == query.versionId)
            .firstOrNull;
        return nativeQueryResultFixture(
          run: version?.runs
              .where((run) => run.id == query.targetId)
              .firstOrNull,
        );
      case QueryKind.interactionDetails:
        return nativeQueryResultFixture(
          state: snapshot == null ? null : stateFor(snapshot),
          interactionDetails: snapshot == null
              ? null
              : nativeInteractionDetailsFixture(snapshot),
        );
      case QueryKind.businessContext:
        return nativeQueryResultFixture(
          state: snapshot == null ? null : stateFor(snapshot),
          run: snapshot?.runs
              .where((run) => run.id == query.targetId)
              .firstOrNull,
          sources: snapshot?.sources ?? const [],
          attachments: snapshot?.attachments ?? const [],
        );
      case QueryKind.operation:
        return nativeQueryResultFixture(
          operation: snapshot?.operations
              .where(
                (operation) =>
                    operation.toolCallId == query.targetId ||
                    operation.binding?.operationId == query.targetId,
              )
              .firstOrNull,
        );
      case QueryKind.restoreMarker:
        final marker = snapshot?.extensions['restore']?[query.targetId]?.json;
        return nativeQueryResultFixture(
          text: marker == null ? null : jsonDecode(marker) as String?,
        );
      case QueryKind.attachments:
        final records = <String, ViewAttachmentMetadata>{
          for (final value in snapshots.values)
            for (final metadata in value.attachments) metadata.id: metadata,
        };
        return nativeQueryResultFixture(attachments: records.values.toList());
      case QueryKind.canContinue:
        return nativeQueryResultFixture(
          flag: presentation.canContinue,
          presentation: presentation,
        );
      case QueryKind.readKnowledgeRecord:
        return nativeQueryResultFixture(
          knowledge: [?knowledge[query.targetId]],
        );
      case QueryKind.knowledge:
        return nativeQueryResultFixture(knowledge: knowledge.values.toList());
      case QueryKind.knowledgeRevision:
        return nativeQueryResultFixture(revision: revision);
      case QueryKind.knowledgeState:
        return nativeQueryResultFixture(
          knowledgeState: ViewKnowledgeState(
            revision: revision,
            storageRevision: revision,
            records: knowledge.values.toList(),
            tombstones: const {},
            receipts: const [],
            undoBatches: const [],
          ),
        );
      case QueryKind.knowledgeCatalog:
        return nativeQueryResultFixture(
          knowledgeCatalog: KnowledgeCatalog(
            revision: revision,
            storageRevision: revision,
            records: knowledge.values.toList(),
            originalDigests: {
              for (final record in originals.values)
                record.id: knowledgeDigest(record.body),
            },
          ),
        );
      default:
        throw UnsupportedError('UI fixture query: ${query.kind.name}');
    }
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
            state: snapshots[prior] == null
                ? null
                : stateFor(snapshots[prior]!),
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
          turns: [
            ViewTurn(
              id: '$id-turn',
              requestMessageId: message.id,
              ownershipComplete: false,
              messageIds: [message.id],
              runIds: const [],
              operations: const [],
            ),
          ],
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
          state: stateFor(snapshot),
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
          return CommandResult(id: id, state: stateFor(snapshot));
        }
        return CommandResult(id: id, state: stateFor(old));
      case CommandKind.setTools:
        _tools = command.tools!;
        return const CommandResult();
      case CommandKind.setPreamble ||
          CommandKind.quiesce ||
          CommandKind.collectAttachments:
        return const CommandResult();
      case CommandKind.stop:
        final snapshot = snapshots[command.conversationId];
        return CommandResult(
          state: snapshot == null ? null : stateFor(snapshot),
        );
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
        return CommandResult(
          id: id,
          state: stateFor(snapshot),
          selection: selection,
        );
      case CommandKind.selectConversation:
        selectedId = command.conversationId;
        final snapshot = snapshots[selectedId];
        return CommandResult(
          selection: selection,
          state: snapshot == null ? null : stateFor(snapshot),
        );
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
          state: stateFor(next),
          selection: selection,
        );
      case CommandKind.addSource || CommandKind.removeSource:
        final old = snapshots[command.conversationId]!;
        final sources = old.sources
            .where(
              (source) => source.id != (command.source?.id ?? command.targetId),
            )
            .toList();
        if (command.kind == CommandKind.addSource) sources.add(command.source!);
        final next = copyNativeSnapshot(
          old,
          sequence: old.sequence + 1,
          sources: sources,
        );
        publish(next);
        return CommandResult(state: stateFor(next));
      default:
        throw UnsupportedError('UI fixture command: ${command.kind.name}');
    }
  }

  @override
  Future<ViewConversationState> admitDraftAttachment({
    required DraftAttachmentAdmission request,
  }) async {
    final existing = snapshots[request.target.conversationId]!;
    if (existing.attachments.any(
      (attachment) => attachment.id == request.importId,
    )) {
      return stateFor(existing);
    }
    await beforeSave?.call();
    if (fail) throw StateError('Synthetic UI attachment publication failure');
    if (_cancelledAttachmentImports.contains(request.importId)) {
      throw StateError('cancelled: Attachment import was cancelled');
    }
    final old = _attachmentTarget(request.target);
    final metadata = ViewAttachmentMetadata(
      id: request.importId,
      name: request.name,
      mediaType: request.mediaType,
      byteLength: request.byteLength,
      sha256: knowledgeDigest('fixture:${request.importId}'),
      createdAt: old.conversation.updatedAt,
    );
    final next = copyNativeSnapshot(
      old,
      sequence: old.sequence + 1,
      attachments: [...old.attachments, metadata],
      conversation: copyNativeConversation(
        old.conversation,
        draftAttachmentIds: [
          ...old.conversation.draftAttachmentIds,
          metadata.id,
        ],
      ),
    );
    publish(next);
    return stateFor(next);
  }

  @override
  Future<void> cancelAttachmentImport({required String importId}) async {
    _cancelledAttachmentImports.add(importId);
  }

  ViewConversationSnapshot _attachmentTarget(DraftAttachmentTarget target) {
    final value = snapshots[target.conversationId];
    final boundary =
        value?.queuedInputs.lastOrNull?.id ??
        value?.messages
            .where((message) => message.role == ViewMessageRole.user)
            .lastOrNull
            ?.id;
    if (value == null ||
        value.conversation.archived ||
        value.conversation.runId != target.expectedAfterRunId ||
        boundary != target.expectedAfterInputId) {
      throw StateError('draft_changed: Conversation or input boundary changed');
    }
    return value;
  }

  @override
  Future<ViewConversationState> removeDraftAttachment({
    required DraftAttachmentTarget target,
    required String attachmentId,
  }) async => _changeDraftAttachment(target, attachmentId, false);

  @override
  Future<ViewConversationState> useDraftAttachment({
    required DraftAttachmentTarget target,
    required String attachmentId,
  }) async => _changeDraftAttachment(target, attachmentId, true);

  ViewConversationState _changeDraftAttachment(
    DraftAttachmentTarget target,
    String attachmentId,
    bool include,
  ) {
    final old = _attachmentTarget(target);
    if (include &&
        !old.attachments.any((attachment) => attachment.id == attachmentId)) {
      throw StateError('attachment_missing: Attachment does not exist');
    }
    final ids = old.conversation.draftAttachmentIds.toSet();
    if (include) {
      ids.add(attachmentId);
    } else {
      ids.remove(attachmentId);
    }
    final next = copyNativeSnapshot(
      old,
      sequence: old.sequence + 1,
      conversation: copyNativeConversation(
        old.conversation,
        draftAttachmentIds: ids.toList(),
        draftReferences: include
            ? old.conversation.draftReferences
            : old.conversation.draftReferences
                  .where((reference) => reference.attachmentId != attachmentId)
                  .toList(),
      ),
    );
    publish(next);
    return stateFor(next);
  }

  @override
  Future<ViewConversationState> replacePendingRedoReferences({
    required String conversationId,
    required String batchId,
    required int expectedSequence,
    required List<ViewContextReference> references,
  }) async {
    final old = snapshots[conversationId]!;
    final batch = old.redoBatches.where((batch) => batch.id == batchId).first;
    if (old.sequence != expectedSequence ||
        old.conversation.archived ||
        !_pendingRedo(batch) ||
        !old.historyVersions.any(
          (version) => version.id == batch.historyVersionId,
        )) {
      throw StateError('History request changed');
    }
    final message = old.messages
        .where((message) => message.id == batch.sourceMessageId)
        .first;
    final attachments = <String>{
      ...message.attachmentIds,
      ...references.map((reference) => reference.attachmentId).nonNulls,
    }.toList()..sort();
    final changed = ViewRedoBatch(
      id: batch.id,
      sourceTurnId: batch.sourceTurnId,
      sourceMessageId: batch.sourceMessageId,
      historyVersionId: batch.historyVersionId,
      replayRunId: batch.replayRunId,
      createdAt: batch.createdAt,
      text: batch.text,
      attachmentIds: attachments,
      contextReferences: references,
      modelSelection: batch.modelSelection,
      contextDigest: batch.contextDigest,
      turnIds: batch.turnIds,
      tickets: batch.tickets,
      completedOwners: batch.completedOwners,
      phase: batch.phase,
      lastError: batch.lastError,
    );
    final next = copyNativeSnapshot(
      old,
      sequence: old.sequence + 1,
      messages: [
        for (final item in old.messages)
          if (item.id == message.id)
            copyNativeMessage(
              item,
              attachmentIds: attachments,
              contextReferences: references,
            )
          else
            item,
      ],
      redoBatches: [
        for (final item in old.redoBatches)
          if (item.id == batch.id) changed else item,
      ],
    );
    publish(next);
    return stateFor(next);
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
    for (final subscription in _uiSubscriptions) {
      subscription.close();
    }
    _uiSubscriptions.clear();
    // AgentRustClient cancels its native subscription after shutdown returns.
    unawaited(_events.close());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'UI fixture does not implement ${invocation.memberName}',
  );
}

class _MemoryUiContributionSubscription implements UiContributionSubscription {
  final _closed = Completer<void>();

  @override
  Stream<UiContributionSnapshot> watch() async* {
    if (_closed.isCompleted) return;
    yield UiContributionSnapshot(
      contractVersion: 1,
      revision: 1,
      owners: [
        UiContributionOwner(
          instanceId: 'fixture.core',
          generation: 1,
          contributions: [
            for (final (id, slot, order) in const [
              ('sked.tool.operation', UiContributionSlot.toolResult, 0),
              (
                'sked.inspector.changes',
                UiContributionSlot.inspectorSection,
                0,
              ),
              ('sked.inspector.plan', UiContributionSlot.inspectorSection, 10),
              (
                'sked.inspector.attachments',
                UiContributionSlot.inspectorSection,
                20,
              ),
              (
                'sked.inspector.context',
                UiContributionSlot.inspectorSection,
                30,
              ),
            ])
              UiContributionDefinition(
                id: id,
                rendererId: id,
                slot: slot,
                order: order,
              ),
          ],
        ),
      ],
    );
    await _closed.future;
  }

  @override
  void close() {
    if (!_closed.isCompleted) _closed.complete();
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
        ViewConversationStatus.stopping,
      }.contains(snapshot?.conversation.status),
      canContinue: snapshot == null
          ? false
          : nativeStateFixture(snapshot).idleCanContinue,
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
  List<ViewQueuedControl>? queuedControls,
  List<ViewRun>? runs,
  List<ViewTurn>? turns,
  List<ViewOperationRecord>? operations,
  List<ViewHistoryVersion>? historyVersions,
  List<ViewReplyRevision>? replyRevisions,
  List<ViewRedoBatch>? redoBatches,
  List<ViewAttachmentMetadata>? attachments,
  ViewQuestionRequest? currentQuestion,
  bool clearQuestion = false,
  ViewTaskPlan? plan,
  List<ViewConversationSource>? sources,
  List<ViewConversationHandoff>? handoffs,
}) => ViewConversationSnapshot(
  conversation: conversation ?? value.conversation,
  sequence: sequence ?? value.sequence,
  messages: messages ?? value.messages,
  runs: runs ?? value.runs,
  turns: turns ?? value.turns,
  operations: operations ?? value.operations,
  queuedInputs: queuedInputs ?? value.queuedInputs,
  queuedControls: queuedControls ?? value.queuedControls,
  currentQuestion: clearQuestion
      ? null
      : currentQuestion ?? value.currentQuestion,
  plan: plan ?? value.plan,
  checkpoint: value.checkpoint,
  contextFailures: value.contextFailures,
  historyVersions: historyVersions ?? value.historyVersions,
  replyRevisions: replyRevisions ?? value.replyRevisions,
  redoBatches: redoBatches ?? value.redoBatches,
  attachments: attachments ?? value.attachments,
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
  List<String>? draftAttachmentIds,
  List<ViewContextReference>? draftReferences,
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
  draftAttachmentIds: draftAttachmentIds ?? value.draftAttachmentIds,
  draftReferences: draftReferences ?? value.draftReferences,
  modelSelection: value.modelSelection,
  connectionFingerprint: value.connectionFingerprint,
  runId: clearRun ? null : runId ?? value.runId,
  executionHistoryStart: value.executionHistoryStart,
  titleGeneration: value.titleGeneration,
);

ViewMessage copyNativeMessage(
  ViewMessage value, {
  String? text,
  List<String>? attachmentIds,
  List<ViewContextReference>? contextReferences,
  List<JsonPayload>? responseItems,
}) => ViewMessage(
  id: value.id,
  role: value.role,
  text: text ?? value.text,
  createdAt: value.createdAt,
  toolCalls: value.toolCalls,
  toolCallId: value.toolCallId,
  modelSelection: value.modelSelection,
  providerProtocol: value.providerProtocol,
  responseItems: responseItems ?? value.responseItems,
  attachmentIds: attachmentIds ?? value.attachmentIds,
  contextReferences: contextReferences ?? value.contextReferences,
  attachmentDelivery: value.attachmentDelivery,
);

ViewMessage nativeDisplayMessageFixture(ViewMessage value) =>
    copyNativeMessage(value, responseItems: const []);

QueryResult nativeQueryResultFixture({
  List<ViewConversationSummary> conversations = const [],
  ViewConversationSnapshot? snapshot,
  List<ViewMessage> messages = const [],
  int total = 0,
  int? nextOffset,
  int? pageStart,
  List<ViewKnowledgeRecord> knowledge = const [],
  ViewKnowledgeReceipt? knowledgeReceipt,
  int? revision,
  ViewKnowledgeState? knowledgeState,
  List<ViewAttachmentMetadata> attachments = const [],
  ViewAgentArchiveParts? archive,
  Uint8List? bytes,
  String? text,
  bool? flag,
  ViewOperationRecord? operation,
  RunPresentation? presentation,
  ConversationSelection? selection,
  KnowledgeCatalog? knowledgeCatalog,
  ViewConversationState? state,
  ViewConversationPage? page,
  ViewHistoryMessagePage? historyPage,
  List<ViewHistoryVersionSummary> historyVersions = const [],
  List<ViewReplyRevisionSummary> replyRevisions = const [],
  ViewReplyRevision? replyRevision,
  ViewConversationSource? source,
  ViewRun? run,
  List<ViewConversationSource> sources = const [],
  ViewInteractionDetails? interactionDetails,
  ViewMessage? message,
}) => QueryResult(
  conversations: conversations,
  snapshot: snapshot,
  messages: messages,
  total: total,
  nextOffset: nextOffset,
  pageStart: pageStart,
  knowledge: knowledge,
  knowledgeReceipt: knowledgeReceipt,
  revision: revision,
  knowledgeState: knowledgeState,
  attachments: attachments,
  archive: archive,
  bytes: bytes,
  text: text,
  flag: flag,
  operation: operation,
  presentation: presentation,
  selection: selection,
  knowledgeCatalog: knowledgeCatalog,
  state: state,
  page: page,
  historyPage: historyPage,
  historyVersions: historyVersions,
  replyRevisions: replyRevisions,
  replyRevision: replyRevision,
  source: source,
  run: run,
  sources: sources,
  interactionDetails: interactionDetails,
  message: message,
);

ViewReplyRevision nativeDisplayReplyFixture(ViewReplyRevision value) =>
    ViewReplyRevision(
      id: value.id,
      messageId: value.messageId,
      runId: value.runId,
      createdAt: value.createdAt,
      text: value.text,
      model: value.model,
      providerProtocol: value.providerProtocol,
      responseItems: const [],
    );

ViewOperationSummary nativeOperationSummaryFixture(ViewOperationRecord value) =>
    ViewOperationSummary(
      toolCallId: value.toolCallId,
      toolName: value.toolName,
      runId: value.runId,
      binding: value.binding,
      phase: value.phase,
    );

bool _pendingOperation(ViewOperationRecord value) => const {
  ViewOperationPhase.preparing,
  ViewOperationPhase.waitingApproval,
  ViewOperationPhase.executing,
  ViewOperationPhase.unresolved,
}.contains(value.phase);

bool _pendingRedo(ViewRedoBatch value) =>
    value.phase != ViewRedoPhase.completed &&
    value.phase != ViewRedoPhase.cancelled;

ViewUsageSummary nativeUsageSummaryFixture(Iterable<ViewRun> records) {
  final runs = records.toList();
  final requests = runs.expand((run) => run.requests).toList();
  final tools = runs.expand((run) => run.tools).toList();
  final reported = requests
      .where(
        (request) =>
            request.usage?.inputTokens != null &&
            request.usage?.outputTokens != null &&
            request.usage?.totalTokens != null,
      )
      .toList();
  final usages = reported.map((request) => request.usage!).toList();
  ViewOutcomeCounts counts(Iterable<ViewAttemptOutcome> values) {
    final list = values.toList();
    int count(ViewAttemptOutcome outcome) =>
        list.where((value) => value == outcome).length;
    return ViewOutcomeCounts(
      pending: count(ViewAttemptOutcome.pending),
      completed: count(ViewAttemptOutcome.completed),
      failed: count(ViewAttemptOutcome.failed),
      cancelled: count(ViewAttemptOutcome.cancelled),
      unknown: count(ViewAttemptOutcome.unknown),
      notStarted: count(ViewAttemptOutcome.notStarted),
    );
  }

  int sum(Iterable<int> values) =>
      values.fold(0, (total, value) => total + value);
  int? optionalSum(Iterable<int?> values) {
    final present = values.nonNulls.toList();
    return present.isEmpty ? null : sum(present);
  }

  return ViewUsageSummary(
    recordedRuns: runs.length,
    continuedRuns: runs.where((run) => run.continuedFromRunId != null).length,
    modelRequests: requests.length,
    requestOutcomes: counts(requests.map((request) => request.outcome)),
    toolAttempts: tools.length,
    toolOutcomes: counts(tools.map((tool) => tool.outcome)),
    reportedUsageRequests: reported.length,
    completedUsageRequests: reported
        .where((request) => request.outcome == ViewAttemptOutcome.completed)
        .length,
    cachedInputReportedRequests: usages
        .where((usage) => usage.cachedInputTokens != null)
        .length,
    reasoningReportedRequests: usages
        .where((usage) => usage.reasoningTokens != null)
        .length,
    reportedTokens: usages.isEmpty
        ? null
        : ViewTokenUsage(
            inputTokens: sum(usages.map((usage) => usage.inputTokens!)),
            outputTokens: sum(usages.map((usage) => usage.outputTokens!)),
            totalTokens: sum(usages.map((usage) => usage.totalTokens!)),
            cachedInputTokens: optionalSum(
              usages.map((usage) => usage.cachedInputTokens),
            ),
            reasoningTokens: optionalSum(
              usages.map((usage) => usage.reasoningTokens),
            ),
          ),
    settledDurationMs: sum(
      runs
          .where((run) => run.settledAt != null)
          .map((run) => math.max(0, run.settledAt! - run.startedAt)),
    ),
  );
}

ViewRunSummary nativeRunSummaryFixture(ViewRun value) => ViewRunSummary(
  id: value.id,
  startedAt: value.startedAt,
  settledAt: value.settledAt,
  kind: value.kind,
  status: value.status,
  model: value.model,
  continuedFromRunId: value.continuedFromRunId,
  requestCount: value.requests.length,
  toolCount: value.tools.length,
  lastRequest: value.requests.lastOrNull,
  errorCode: value.errorCode,
  usage: nativeUsageSummaryFixture([value]),
);

ViewHistoryVersionSummary nativeHistoryVersionSummaryFixture(
  ViewHistoryVersion value,
) => ViewHistoryVersionSummary(
  id: value.id,
  batchId: value.batchId,
  createdAt: value.createdAt,
  messageCount: value.messages.length,
);

ViewReplyRevisionSummary nativeReplyRevisionSummaryFixture(
  ViewReplyRevision value,
) => ViewReplyRevisionSummary(
  id: value.id,
  messageId: value.messageId,
  runId: value.runId,
  createdAt: value.createdAt,
  model: value.model,
  providerProtocol: value.providerProtocol,
);

ViewSourceSummary nativeSourceSummaryFixture(ViewConversationSource value) =>
    ViewSourceSummary(
      id: value.id,
      kind: value.kind,
      url: value.url,
      targetId: value.targetId,
      truncated: value.truncated,
      provenance: value.provenance,
      attachedAfterRunId: value.attachedAfterRunId,
      attachedAfterMessageId: value.attachedAfterMessageId,
      boundInputId: value.boundInputId,
      boundMessageId: value.boundMessageId,
    );

ViewConversationState nativeStateFixture(
  ViewConversationSnapshot value, {
  int? lastCommittedAssistantRevision,
}) {
  final pendingOperations = value.operations.where(_pendingOperation).toList();
  final pendingRedos = value.redoBatches.where(_pendingRedo).toList();
  final currentRun = value.runs
      .where((run) => run.id == value.conversation.runId)
      .firstOrNull;
  final question = value.currentQuestion;
  return ViewConversationState(
    conversation: value.conversation,
    sequence: value.sequence,
    messageCount: value.messages.length,
    sourceCount: value.sources.length,
    hasExecutionUserInput: value.messages
        .skip(value.conversation.executionHistoryStart)
        .any((message) => message.role == ViewMessageRole.user),
    managementContextDigest: nativeManagementContextDigest(value),
    lastUserMessageId: value.messages
        .where((message) => message.role == ViewMessageRole.user)
        .lastOrNull
        ?.id,
    currentRun: currentRun == null ? null : nativeRunSummaryFixture(currentRun),
    queuedInputs: value.queuedInputs,
    queuedControls: value.queuedControls,
    pendingOperations: pendingOperations
        .map(nativeOperationSummaryFixture)
        .toList(),
    question: question == null
        ? null
        : ViewQuestionSummary(
            id: question.id,
            toolCallId: question.toolCallId,
            runId: question.runId,
            requestMessageId: question.requestMessageId,
            status: question.status,
            consumed: question.consumed,
          ),
    planRevision: value.plan?.revision,
    pendingRedos: pendingRedos
        .map(
          (batch) => ViewRedoSummary(
            id: batch.id,
            sourceTurnId: batch.sourceTurnId,
            sourceMessageId: batch.sourceMessageId,
            historyVersionId: batch.historyVersionId,
            replayRunId: batch.replayRunId,
            phase: batch.phase,
            hasHistoryVersion: value.historyVersions.any(
              (version) => version.id == batch.historyVersionId,
            ),
            lastError: batch.lastError,
          ),
        )
        .toList(),
    historyVersionCount: value.historyVersions.length,
    replyRevisionCount: value.replyRevisions.length,
    lastCommittedAssistantId: value.messages
        .where((message) => message.role == ViewMessageRole.assistant)
        .lastOrNull
        ?.id,
    lastCommittedAssistantRevision:
        lastCommittedAssistantRevision ?? value.sequence,
    idleCanContinue:
        !value.conversation.archived &&
        !value.conversation.draftOnly &&
        !pendingOperations.any(
          (operation) => operation.phase == ViewOperationPhase.unresolved,
        ) &&
        pendingRedos.isEmpty &&
        (value.conversation.status == ViewConversationStatus.interrupted ||
            value.queuedInputs.isNotEmpty),
    usage: nativeUsageSummaryFixture(value.runs),
  );
}

String nativeManagementContextDigest(ViewConversationSnapshot value) {
  Map<String, Object?> reference(ViewContextReference value) =>
      switch (value.kind) {
        ViewContextReferenceKind.resource => {
          'kind': 'resource',
          'label': value.label,
          'ref': value.resource == null
              ? null
              : {
                  'kind': value.resource!.kind,
                  'id': value.resource!.id,
                  'parentId': value.resource!.parentId,
                },
          'datasetGeneration': value.datasetGeneration,
        },
        ViewContextReferenceKind.skill => {
          'kind': 'skill',
          'label': value.label,
          'id': value.skillId,
          'version': value.skillVersion,
          'contentSha256': value.skillSha256,
        },
        ViewContextReferenceKind.attachment => {
          'kind': 'attachment',
          'label': value.label,
          'id': value.attachmentId,
          'conversationId': value.conversationId,
          'digest': value.attachmentDigest,
        },
      };
  return mutationDigest({
    'inputs': value.messages
        .where(
          (message) =>
              message.role == ViewMessageRole.user ||
              message.role == ViewMessageRole.notice,
        )
        .map(
          (message) => {
            'id': message.id,
            'role': message.role.name,
            'text': message.text,
            'createdAt': message.createdAt,
            'toolCalls': message.toolCalls
                .map(
                  (call) => {
                    'id': call.id,
                    'name': call.name,
                    'arguments': call.rawArguments ?? call.arguments.json,
                    'wireName': call.wireName,
                  },
                )
                .toList(),
            'toolCallId': message.toolCallId,
            'modelSelection': message.modelSelection == null
                ? null
                : {
                    'modelId': message.modelSelection!.modelId,
                    'reasoningEffort':
                        message.modelSelection!.reasoningEffort ?? 'none',
                  },
            'providerProtocol': message.providerProtocol,
            'attachmentIds': message.attachmentIds,
            'contextReferences': message.contextReferences
                .map(reference)
                .toList(),
            'attachmentDelivery': message.attachmentIds.isEmpty
                ? null
                : message.attachmentDelivery.name,
          },
        )
        .toList(),
    'sources': value.sources
        .map(
          (source) => {
            'id': source.id,
            'kind': source.kind,
            'text': source.text,
            'url': source.url,
            'targetId': source.targetId,
            'truncated': source.truncated,
            'provenance': source.provenance == null
                ? null
                : {
                    'title': source.provenance!.title,
                    'capturedAt': source.provenance!.capturedAt,
                    'reviewedAt': source.provenance!.reviewedAt,
                    'datasetGeneration': source.provenance!.datasetGeneration,
                    'localeCode': source.provenance!.localeCode,
                    'revision': source.provenance!.revision,
                  },
            'attachedAfterRunId': source.attachedAfterRunId,
            'attachedAfterMessageId': source.attachedAfterMessageId,
          },
        )
        .toList(),
  });
}

ViewInteractionDetails nativeInteractionDetailsFixture(
  ViewConversationSnapshot value,
) => ViewInteractionDetails(
  sequence: value.sequence,
  question: value.currentQuestion,
  plan: value.plan,
  pendingOperations: value.operations.where(_pendingOperation).toList(),
  pendingRedos: value.redoBatches.where(_pendingRedo).toList(),
);

ViewConversationPage nativePageFixture(
  ViewConversationSnapshot value, {
  int? before,
  String? beforeMessageId,
  String? fromMessageId,
  int limit = 50,
  ViewHistoryVersion? historyVersion,
}) {
  final all = historyVersion?.messages ?? value.messages;
  int? position(String? id) {
    if (id == null) return null;
    final index = all.indexWhere((message) => message.id == id);
    return index < 0 ? null : index;
  }

  final beforePosition = position(beforeMessageId);
  if (historyVersion != null &&
      beforeMessageId != null &&
      beforePosition == null) {
    throw StateError(
      'History page cursor does not belong to the selected version.',
    );
  }
  var end = math.min(beforePosition ?? before ?? all.length, all.length);
  final owners = <String, int>{
    for (var index = 0; index < all.length; index++)
      for (final call in all[index].toolCalls) call.id: index,
  };
  int groupStart(int index) => owners[all[index].toolCallId] ?? index;
  final requestedEnd = end;
  for (var index = end; index < all.length; index++) {
    if (groupStart(index) < requestedEnd) end = index + 1;
  }
  var start = math.min(
    position(fromMessageId) ?? math.max(0, end - (limit == 0 ? 50 : limit)),
    end,
  );
  while (true) {
    var expanded = start;
    for (var index = start; index < end; index++) {
      expanded = math.min(expanded, groupStart(index));
    }
    if (expanded == start) break;
    start = expanded;
  }
  final messages = all
      .sublist(start, end)
      .map(nativeDisplayMessageFixture)
      .toList();
  final visible = messages.map((message) => message.id).toSet();
  final sourceTurns = historyVersion?.turns ?? value.turns;
  final turns = sourceTurns
      .where((turn) => turn.messageIds.any(visible.contains))
      .map((turn) {
        final request = all
            .where((message) => message.id == turn.requestMessageId)
            .firstOrNull;
        return ViewTurnContext(
          id: turn.id,
          requestMessageId: turn.requestMessageId,
          request: request == null
              ? null
              : nativeDisplayMessageFixture(request),
          ownershipComplete: turn.ownershipComplete,
          visibleMessageIds: messages
              .where((message) => turn.messageIds.contains(message.id))
              .map((message) => message.id)
              .toList(),
          runIds: turn.runIds,
          operations: turn.operations,
        );
      })
      .toList();
  final runIds = turns.expand((turn) => turn.runIds).toSet();
  final attachmentIds = <String>{};
  final sourceIds = <String>{};
  void collect(
    Iterable<String> attachments,
    Iterable<ViewContextReference> references,
  ) {
    attachmentIds.addAll(attachments);
    attachmentIds.addAll(
      references.map((reference) => reference.attachmentId).nonNulls,
    );
    sourceIds.addAll(
      references.map((reference) => reference.sourceId).nonNulls,
    );
  }

  for (final message in [
    ...messages,
    ...turns.map((turn) => turn.request).nonNulls,
  ]) {
    collect(message.attachmentIds, message.contextReferences);
  }
  if (historyVersion == null) {
    collect(
      value.conversation.draftAttachmentIds,
      value.conversation.draftReferences,
    );
    for (final input in value.queuedInputs) {
      collect(input.attachmentIds, input.contextReferences);
    }
    for (final redo in value.redoBatches.where(_pendingRedo)) {
      collect(redo.attachmentIds, redo.contextReferences);
    }
  }
  return ViewConversationPage(
    sequence: value.sequence,
    total: all.length,
    start: start,
    nextOffset: start > 0 && start < end ? start : null,
    messages: messages,
    turns: turns,
    runs: (historyVersion?.runs ?? value.runs)
        .where((run) => runIds.contains(run.id))
        .map(nativeRunSummaryFixture)
        .toList(),
    operations: historyVersion != null
        ? const []
        : value.operations
              .where((operation) => runIds.contains(operation.runId))
              .map(nativeOperationSummaryFixture)
              .toList(),
    attachments: value.attachments
        .where((attachment) => attachmentIds.contains(attachment.id))
        .toList(),
    sources: value.sources
        .where(
          (source) =>
              sourceIds.contains(source.id) ||
              visible.contains(source.boundMessageId) ||
              historyVersion == null && source.boundMessageId == null,
        )
        .map(nativeSourceSummaryFixture)
        .toList(),
    replyRevisions: historyVersion != null
        ? const []
        : value.replyRevisions
              .where((revision) => visible.contains(revision.messageId))
              .map(nativeReplyRevisionSummaryFixture)
              .toList(),
    handoffs: historyVersion != null
        ? const []
        : value.handoffs
              .where((handoff) => visible.contains(handoff.messageId))
              .toList(),
  );
}
