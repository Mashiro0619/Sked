import 'dart:convert';

import '../../application/operation_contracts.dart';
import '../../models/agent_settings.dart';
import '../conversations/conversation_models.dart';
import '../history/conversation_history.dart';
import '../interactions/agent_question.dart';
import '../references/agent_composer_reference.dart';
import 'generated/api/models.dart' as native;
import 'generated/api/management_contracts.dart' as management;

DateTime _date(int value) =>
    DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

AgentModelSelection? modelSelectionFromRust(native.ViewModelSelection? value) =>
    value == null
    ? null
    : AgentModelSelection(
        modelId: value.modelId,
        reasoningEffort: AgentReasoningEffort.values.byName(
          value.reasoningEffort ?? 'none',
        ),
      );

native.ViewModelSelection? modelSelectionToRust(AgentModelSelection? value) =>
    value == null
    ? null
    : native.ViewModelSelection(
        modelId: value.modelId,
        reasoningEffort: value.reasoningEffort.name,
      );

AgentComposerReference referenceFromRust(native.ViewContextReference value) =>
    AgentComposerReference.fromJson({
      'kind': value.kind.name,
      'label': value.label,
      ...switch (value.kind) {
        native.ViewContextReferenceKind.resource => {
          'ref': {
            'kind': value.resource!.kind,
            'id': value.resource!.id,
            if (value.resource!.parentId != null)
              'parentId': value.resource!.parentId,
          },
          'datasetGeneration': value.datasetGeneration,
        },
        native.ViewContextReferenceKind.skill => {
          'id': value.skillId,
          'version': value.skillVersion,
          'contentSha256': value.skillSha256,
        },
        native.ViewContextReferenceKind.attachment => {
          'id': value.attachmentId,
          'conversationId': value.conversationId,
          'digest': value.attachmentDigest,
        },
      },
    });

native.ViewContextReference referenceToRust(AgentComposerReference value) =>
    native.ViewContextReference(
      id: value.stableKey,
      kind: native.ViewContextReferenceKind.values.byName(value.kind.name),
      label: value.label,
      resource: value.resourceRef == null
          ? null
          : native.ViewResourceReference(
              kind: value.resourceRef!.kind.name,
              id: value.resourceRef!.id,
              parentId: value.resourceRef!.parentId,
              generation: value.datasetGeneration,
            ),
      datasetGeneration: value.datasetGeneration,
      skillId: value.skillId,
      skillVersion: value.skillVersion,
      skillSha256: value.skillSha256,
      attachmentId: value.attachmentId,
      conversationId: value.conversationId,
      attachmentDigest: value.attachmentDigest,
    );

ConversationTokenUsage? tokenUsageFromRust(native.ViewTokenUsage? value) {
  if (value == null ||
      value.inputTokens == null ||
      value.outputTokens == null ||
      value.totalTokens == null) {
    return null;
  }
  return ConversationTokenUsage(
    inputTokens: value.inputTokens!.toInt(),
    outputTokens: value.outputTokens!.toInt(),
    totalTokens: value.totalTokens!.toInt(),
    cachedInputTokens: value.cachedInputTokens?.toInt(),
    reasoningTokens: value.reasoningTokens?.toInt(),
  );
}

ConversationRequestUsage requestFromRust(native.ViewRequestUsage value) =>
    ConversationRequestUsage(
      id: value.id,
      startedAt: _date(value.startedAt.toInt()),
      kind: ConversationRequestKind.values.byName(value.kind.name),
      outcome: ConversationAttemptOutcome.values.byName(value.outcome.name),
      usage: tokenUsageFromRust(value.usage),
      errorCode: value.errorCode,
    );

ConversationRunUsage runFromRust(native.ViewRun value) => ConversationRunUsage(
  id: value.id,
  startedAt: _date(value.startedAt.toInt()),
  settledAt: value.settledAt == null ? null : _date(value.settledAt!.toInt()),
  kind: ConversationRunKind.values.byName(value.kind.name),
  status: ConversationRunStatus.values.byName(value.status.name),
  model: value.model?.modelId,
  protocol: value.model?.protocol,
  reasoningEffort: value.model?.reasoningEffort == null
      ? null
      : AgentReasoningEffort.values.byName(value.model!.reasoningEffort!),
  continuedFromRunId: value.continuedFromRunId,
  requests: value.requests.map(requestFromRust),
  tools: value.tools.map(
    (tool) => ConversationToolUsage(
      id: tool.id,
      name: tool.name,
      outcome: ConversationAttemptOutcome.values.byName(tool.outcome.name),
    ),
  ),
);

ConversationMessage conversationMessageFromRust(native.ViewMessage value) =>
    ConversationMessage(
      id: value.id,
      role: ConversationRole.values.byName(value.role.name),
      text: value.text,
      createdAt: _date(value.createdAt.toInt()),
      toolCalls: value.toolCalls.map(
        (call) => ConversationToolCall(
          id: call.id,
          name: call.name,
          arguments: call.rawArguments ?? call.arguments.json,
          wireName: call.wireName,
        ),
      ),
      toolCallId: value.toolCallId,
      modelSelection: modelSelectionFromRust(value.modelSelection),
      providerProtocol: value.providerProtocol == null
          ? null
          : AgentModelProtocol.values.byName(value.providerProtocol!),
      attachmentIds: value.attachmentIds,
      contextReferences: value.contextReferences.map(referenceFromRust),
      attachmentDelivery: AttachmentDelivery.values.byName(
        value.attachmentDelivery.name,
      ),
      // Tool continuation records belong to the native history. The shared
      // Flutter message keeps assistant provider details for its inspector.
      responseItems: value.role == native.ViewMessageRole.assistant
          ? value.responseItems.map(
              (item) => Map<String, Object?>.from(jsonDecode(item.json) as Map),
            )
          : const [],
    );

ConversationTurn turnFromRust(native.ViewTurn value) => ConversationTurn(
  id: value.id,
  requestMessageId: value.requestMessageId,
  ownershipComplete: value.ownershipComplete,
  messageIds: value.messageIds,
  runIds: value.runIds,
  operations: value.operations.map(
    (operation) => ConversationOperationBinding(
      operationId: operation.operationId,
      store: switch (operation.store) {
        native.ViewOperationStore.main => ConversationOperationStore.main,
        native.ViewOperationStore.knowledge =>
          ConversationOperationStore.knowledge,
        native.ViewOperationStore.external_ =>
          ConversationOperationStore.external,
      },
      runId: operation.runId,
      toolCallId: operation.toolCallId,
    ),
  ),
);

ConversationAttachment attachmentFromRust(
  native.ViewAttachmentMetadata value,
) => ConversationAttachment(
  id: value.id,
  name: value.name,
  mediaType: value.mediaType,
  byteLength: value.byteLength.toInt(),
  digest: value.sha256,
);

ConversationSource sourceFromRust(native.ViewConversationSource value) =>
    ConversationSource(
      id: value.id,
      text: value.text,
      kind: value.kind,
      url: value.url,
      targetId: value.targetId,
      truncated: value.truncated,
      attachedAfterRunId: value.attachedAfterRunId,
      attachedAfterMessageId: value.attachedAfterMessageId,
      boundInputId: value.boundInputId,
      boundMessageId: value.boundMessageId,
      provenance: value.provenance == null
          ? null
          : ConversationSourceProvenance(
              title: value.provenance!.title,
              capturedAt: _date(value.provenance!.capturedAt.toInt()),
              reviewedAt: _date(value.provenance!.reviewedAt.toInt()),
              datasetGeneration: value.provenance!.datasetGeneration,
              localeCode: value.provenance!.localeCode,
              revision: value.provenance!.revision,
            ),
    );

native.ViewConversationSource sourceToRust(ConversationSource value) =>
    native.ViewConversationSource(
      id: value.id,
      text: value.text,
      kind: value.kind,
      url: value.url,
      targetId: value.targetId,
      truncated: value.truncated,
      attachedAfterRunId: value.attachedAfterRunId,
      attachedAfterMessageId: value.attachedAfterMessageId,
      boundInputId: value.boundInputId,
      boundMessageId: value.boundMessageId,
      provenance: value.provenance == null
          ? null
          : native.ViewSourceProvenance(
              title: value.provenance!.title,
              capturedAt: value.provenance!.capturedAt.millisecondsSinceEpoch,
              reviewedAt: value.provenance!.reviewedAt.millisecondsSinceEpoch,
              datasetGeneration: value.provenance!.datasetGeneration,
              localeCode: value.provenance!.localeCode,
              revision: value.provenance!.revision,
              resourceReferences: const [],
            ),
    );

AgentQuestionRequest? questionFromRust(native.ViewQuestionRequest? value) {
  if (value == null ||
      value.consumed ||
      value.status == native.ViewQuestionStatus.retired) {
    return null;
  }
  return AgentQuestionRequest(
    id: value.id,
    toolCallId: value.toolCallId,
    runId: value.runId,
    requestMessageId: value.requestMessageId,
    connectionFingerprint: value.connectionFingerprint,
    createdAt: _date(value.createdAt.toInt()),
    datasetGeneration: value.datasetGeneration,
    contextReferenceDigest: value.contextDigest.isEmpty
        ? null
        : value.contextDigest,
    questions: value.questions.map(
      (prompt) => AgentQuestionPrompt(
        id: prompt.id,
        question: prompt.question,
        multiple: prompt.multiple,
        options: prompt.options.map(
          (option) => AgentQuestionOption(
            id: option.id,
            label: option.label,
            description: option.description.isEmpty ? null : option.description,
          ),
        ),
      ),
    ),
    dismissed: value.status == native.ViewQuestionStatus.skipped,
    answers: value.status != native.ViewQuestionStatus.answered
        ? null
        : value.answers.map(
            (answer) => AgentQuestionAnswer(
              questionId: answer.questionId,
              optionIds: answer.optionIds,
              text: answer.text ?? '',
            ),
          ),
  );
}

ConversationTitleGeneration? titleFromRust(native.ViewTitleGeneration? value) =>
    value == null
    ? null
    : ConversationTitleGeneration(
        sourceMessageId: value.sourceMessageId,
        sourceDigest: value.sourceDigest,
        model: value.model!.modelId,
        protocol: value.model!.protocol!,
        reasoningEffort: value.model!.reasoningEffort,
        request: ConversationRequestUsage(
          id: value.requestId,
          startedAt: _date(value.startedAt.toInt()),
          kind: ConversationRequestKind.title,
          outcome: ConversationAttemptOutcome.values.byName(value.outcome.name),
          usage: tokenUsageFromRust(value.usage),
          errorCode: value.error,
        ),
      );

ConversationUndoOwner _undoOwner(native.ViewOperationStore value) =>
    switch (value) {
      native.ViewOperationStore.main => ConversationUndoOwner.main,
      native.ViewOperationStore.knowledge => ConversationUndoOwner.knowledge,
      native.ViewOperationStore.external_ => throw const FormatException(
        'External operations do not have a history undo ticket.',
      ),
    };

ConversationRedoBatch redoFromRust(
  native.ViewRedoBatch value,
  String conversationId,
) => ConversationRedoBatch(
  id: value.id,
  conversationId: conversationId,
  sourceTurnId: value.sourceTurnId,
  sourceMessageId: value.sourceMessageId,
  historyVersionId: value.historyVersionId,
  replayRunId: value.replayRunId,
  createdAt: _date(value.createdAt.toInt()),
  text: value.text,
  attachmentIds: value.attachmentIds,
  modelSelection: modelSelectionFromRust(value.modelSelection),
  contextDigest: value.contextDigest,
  turnIds: value.turnIds,
  phase: ConversationRedoPhase.values.byName(value.phase.name),
  lastError: value.lastError,
  tickets: value.tickets.map(
    (ticket) => ConversationUndoTicket(
      owner: _undoOwner(ticket.owner),
      token: ticket.token,
      digest: ticket.digest,
      operationIds: ticket.operationIds,
    ),
  ),
  completedOwners: value.completedOwners.map(_undoOwner),
);

AgentConversation conversationFromRust(
  native.ViewConversationSnapshot value, {
  List<ConversationMessage>? projectedMessages,
  int messageStart = 0,
}) {
  final metadata = value.conversation;
  final messages =
      projectedMessages ??
      value.messages.map(conversationMessageFromRust).toList();
  final visibleIds = messages.map((message) => message.id).toSet();
  final turns = projectedMessages == null
      ? value.turns
      : value.turns.where(
          (turn) =>
              visibleIds.contains(turn.requestMessageId) &&
              turn.messageIds.every(visibleIds.contains),
        );
  return AgentConversation(
    id: metadata.id,
    title: metadata.title,
    titleWasEdited: metadata.titleWasEdited,
    pinned: metadata.pinned,
    archived: metadata.archived,
    createdAt: _date(metadata.createdAt.toInt()),
    updatedAt: _date(metadata.updatedAt.toInt()),
    mode: AgentPermissionMode.values.byName(metadata.mode.name),
    status: ConversationStatus.values.byName(metadata.status.name),
    draft: metadata.draft,
    connectionFingerprint: metadata.connectionFingerprint,
    runId: metadata.runId,
    modelSelection: modelSelectionFromRust(metadata.modelSelection),
    titleGeneration: titleFromRust(metadata.titleGeneration),
    executionHistoryStart: projectedMessages == null
        ? metadata.executionHistoryStart.toInt()
        : (metadata.executionHistoryStart - messageStart).clamp(
            0,
            messages.length,
          ),
    messages: messages,
    sources: value.sources.map(sourceFromRust),
    runs: value.runs.map(runFromRust),
    attachments: value.attachments.map(attachmentFromRust),
    draftAttachmentIds: metadata.draftAttachmentIds,
    draftReferences: metadata.draftReferences.map(referenceFromRust),
    turns: turns.map(turnFromRust),
    historyVersions: value.historyVersions.map(
      (version) => ConversationHistoryVersion(
        id: version.id,
        batchId: version.batchId,
        createdAt: _date(version.createdAt.toInt()),
        messages: version.messages.map(conversationMessageFromRust),
        runs: version.runs.map(runFromRust),
        turns: version.turns.map(turnFromRust),
      ),
    ),
    replyRevisions: value.replyRevisions.map(
      (revision) => ConversationReplyRevision(
        id: revision.id,
        messageId: revision.messageId,
        runId: revision.runId,
        createdAt: _date(revision.createdAt.toInt()),
        text: revision.text,
        modelSelection: modelSelectionFromRust(revision.model),
        providerProtocol: revision.providerProtocol == null
            ? null
            : AgentModelProtocol.values.byName(revision.providerProtocol!),
      ),
    ),
    redoBatches: value.redoBatches.map(
      (batch) => redoFromRust(batch, metadata.id),
    ),
    queuedInputs: value.queuedInputs.map(
      (input) => ConversationQueuedInput(
        id: input.id,
        text: input.text,
        createdAt: _date(input.createdAt.toInt()),
        mode: ConversationQueuedInputMode.values.byName(input.mode.name),
        modelSelection: modelSelectionFromRust(input.modelSelection),
        attachmentIds: input.attachmentIds,
        contextReferences: input.contextReferences.map(referenceFromRust),
      ),
    ),
    queuedControls: value.queuedControls.map(
      (control) => ConversationControlCommand(
        id: control.id,
        kind: ConversationControlKind.values.byName(control.kind.name),
        createdAt: _date(control.createdAt.toInt()),
        status: ConversationControlStatus.values.byName(control.status.name),
        errorMessage: control.errorMessage,
      ),
    ),
    pendingQuestion:
        projectedMessages == null ||
            visibleIds.contains(value.currentQuestion?.requestMessageId)
        ? questionFromRust(value.currentQuestion)
        : null,
  );
}

ConversationHandoff handoffFromRust(management.ViewConversationHandoff value) =>
    ConversationHandoff(
      id: value.id,
      conversationId: value.conversationId,
      sourceDigest: value.sourceDigest,
      messageId: value.messageId,
    );

AgentConversation conversationSummaryFromRust(
  native.ViewConversationSummary value,
) => AgentConversation(
  id: value.id,
  title: value.title,
  pinned: value.pinned,
  archived: value.archived,
  createdAt: _date(value.createdAt.toInt()),
  updatedAt: _date(value.updatedAt.toInt()),
  status: ConversationStatus.values.byName(value.status.name),
);
