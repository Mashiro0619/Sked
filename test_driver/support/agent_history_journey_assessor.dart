import 'dart:convert';

import 'package:crypto/crypto.dart';

const agentHistoryCheckpoints = [
  'environment',
  'runtime-loaded',
  'product-entry',
  'history-operation-saved',
  'history-later-turn-saved',
  'history-reply-regenerated',
  'history-edit-cancelled-reopened',
  'history-turn-redone',
  'history-versions-browsed',
  'cleanup',
];

const agentHistoryRelevantSources = [
  'integration_test/support/agent_history_journey.dart',
  'test_driver/support/agent_history_journey_assessor.dart',
  'lib/agent/history/conversation_history.dart',
  'lib/agent/history/conversation_history_service.dart',
  'lib/agent/history/conversation_history_preflight.dart',
  'lib/agent/history/conversation_redo_coordinator.dart',
  'lib/agent/history/conversation_main_undo.dart',
  'lib/agent/history/conversation_knowledge_undo.dart',
  'lib/agent/history/conversation_reply_regeneration.dart',
  'lib/agent/runtime/agent_runtime_controller.dart',
  'lib/agent/conversations/conversation_models.dart',
  'lib/agent/conversations/conversation_repository.dart',
  'lib/agent/ui/agent_conversation_view.dart',
  'lib/application/mutation_coordinator.dart',
  'lib/models/application_ledger.dart',
  'lib/models/app_data.dart',
  'lib/screens/adaptive_sked_shell.dart',
  'lib/widgets/workspace_frame.dart',
  'lib/widgets/expressive_motion.dart',
  'lib/widgets/workbench_chrome_metrics.dart',
  'lib/theme/sked_expressive_theme.dart',
];

const _originalRequest = 'Create one hidden synthetic history calendar.';
const _originalReply = 'The synthetic history calendar was created.';
const _calendarName = 'Native history undo calendar';
const _laterRequest =
    'Explain the saved synthetic calendar without changing it.';
const _laterReply = 'The saved synthetic calendar is hidden and has no events.';
const _regeneratedReply =
    'The existing synthetic calendar remains hidden and empty.';
const _editedRequest =
    'Only explain the synthetic history exercise; create nothing.';
const _replayedReply =
    'This edited request only explains the synthetic history exercise.';
const _draft = 'Unsent chat draft kept while editing a previous request';

void _require(bool value, String description) {
  if (!value) throw StateError(description);
}

Map<String, Object?> _map(Object? value, String description) {
  _require(value is Map, '$description is missing or is not an object.');
  return Map<String, Object?>.from(value as Map);
}

List<Object?> _list(Object? value, String description) {
  _require(value is List, '$description is missing or is not a list.');
  return List<Object?>.from(value as List);
}

List<Map<String, Object?>> _maps(Object? value, String description) => [
  for (final item in _list(value, description)) _map(item, description),
];

String _id(Object? value, String description) {
  _require(
    value is String && value.isNotEmpty && value.length <= 256,
    '$description is invalid.',
  );
  return value as String;
}

bool _same(Object? left, Object? right) =>
    jsonEncode(left) == jsonEncode(right);

String _jsonDigest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

void _digest(Object? value, String description) {
  _require(
    value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
    '$description is not a SHA-256 digest.',
  );
}

void _hashOf(Object? digest, Object? raw, String description) {
  _digest(digest, description);
  _require(
    digest == _jsonDigest(raw),
    '$description does not describe its raw value.',
  );
}

void _unchanged(Map<String, Object?> step, String prefix) {
  _digest(step['${prefix}Before'], '$prefix before');
  _require(
    step['${prefix}Before'] == step['${prefix}After'],
    '$prefix changed during a read-only or cancelled action.',
  );
}

void _configuration(Object? value, bool accessible) {
  final observed = _map(value, 'Observed history configuration');
  final scale = observed['textScale'];
  _require(
    observed['brightness'] == (accessible ? 'dark' : 'light') &&
        scale is num &&
        scale.isFinite &&
        (scale - (accessible ? 2 : 1)).abs() < 0.001 &&
        observed['reduceMotion'] == accessible &&
        observed['disableAnimations'] == false &&
        observed['mediaQueryDisableAnimations'] == false,
    'A history surface has the wrong actual theme, text scale or motion configuration.',
  );
}

void _rendered(Object? value, String expected) {
  final observed = _map(value, 'Rendered history text');
  final paragraphs = observed['renderParagraphCount'];
  final editables = observed['renderEditableCount'];
  _require(
    observed['text'] == expected &&
        observed['sha256'] ==
            sha256.convert(utf8.encode(expected)).toString() &&
        observed['textSource'] == 'render-paragraph-and-editable' &&
        paragraphs is int &&
        paragraphs >= 0 &&
        editables is int &&
        editables >= 0 &&
        paragraphs + editables > 0,
    'The history report lacks actual rendered text evidence.',
  );
}

List<Map<String, Object?>> _messages(
  Object? value,
  Object? digest,
  String description,
) {
  final messages = _maps(value, description);
  _require(messages.isNotEmpty, '$description is empty.');
  final ids = <String>{};
  for (final message in messages) {
    _require(
      ids.add(_id(message['id'], '$description message ID')),
      '$description repeats a message identity.',
    );
    _require(
      message['text'] is String &&
          const [
            'user',
            'assistant',
            'tool',
            'notice',
          ].contains(message['role']),
      '$description has an invalid message.',
    );
  }
  _hashOf(digest, value, '$description digest');
  return messages;
}

Map<String, Map<String, Object?>> _steps(Map<String, Object?> report) {
  final values = _maps(report['checkpoints'], 'History checkpoints');
  _require(
    values.length == agentHistoryCheckpoints.length,
    'The history sequence is incomplete.',
  );
  final steps = <String, Map<String, Object?>>{};
  for (var index = 0; index < values.length; index++) {
    final expected = agentHistoryCheckpoints[index];
    _require(
      values[index]['name'] == expected &&
          values[index]['status'] == 'complete',
      'History checkpoint $expected did not complete in order.',
    );
    steps[expected] = _map(
      values[index]['observations'],
      '$expected observations',
    );
  }
  return steps;
}

void _provider(Object? value, {required bool closed}) {
  final provider = _map(value, 'History provider');
  _require(
    provider['type'] == 'history-scripted-offline' &&
        provider['requests'] == 7 &&
        provider['completedResponses'] == 7 &&
        provider['transportAttempts'] == 0 &&
        provider['closed'] == closed &&
        provider['transportClosed'] == closed &&
        provider['closeCount'] == (closed ? 1 : 0),
    'The history provider repeated, omitted, transported or failed to close a request.',
  );
  final trace = _maps(provider['trace'], 'History provider trace');
  const phases = [
    'original-capabilities',
    'original-prepare',
    'original-commit',
    'original-reply',
    'later-reply',
    'reply-regeneration',
    'edited-request-reply',
  ];
  _require(
    trace.length == phases.length,
    'The history provider trace is incomplete.',
  );
  for (var index = 0; index < trace.length; index++) {
    final item = trace[index];
    final users = _list(item['userTexts'], 'Request user texts');
    final tools = _list(item['toolNames'], 'Request tool catalog');
    final expectedInput = index < 4
        ? _originalRequest
        : index < 6
        ? _laterRequest
        : _editedRequest;
    _require(
      item['requestIndex'] == index + 1 &&
          item['phase'] == phases[index] &&
          item['status'] == 'complete' &&
          item['endpointHost'] == 'native-ui.invalid' &&
          item['model'] == 'native-ui-fixture' &&
          item['credentialPresent'] == false &&
          item['cancelledAtStart'] == false &&
          item['messageCount'] is int &&
          (item['messageCount'] as int) > 0 &&
          users.isNotEmpty &&
          users.every((value) => value is String) &&
          users.last == expectedInput &&
          !users.contains(_draft) &&
          tools.every((value) => value is String) &&
          (index == 5 ? tools.isEmpty : tools.isNotEmpty),
      'History request ${index + 1} has an incorrect source, context, tools or credential boundary.',
    );
    if (index == 6) {
      _require(
        !users.contains(_originalRequest) && !users.contains(_laterRequest),
        'The replay context contains a retired user request.',
      );
    }
    final response = _map(item['response'], 'Scripted response');
    final calls = _maps(response['toolCalls'], 'Response tool calls');
    if (index < 3) {
      final expectedTool = const [
        'capabilities.describe',
        'mutation.prepare',
        'mutation.commit',
      ][index];
      _require(
        response['text'] == '' &&
            calls.length == 1 &&
            calls.single['name'] == expectedTool &&
            calls.single['id'] == 'history-call-${index + 1}-$expectedTool' &&
            tools.contains(expectedTool),
        'The original history run did not use the expected real tool chain.',
      );
      final args = _map(calls.single['arguments'], 'Tool arguments');
      if (index == 0) {
        _require(
          _same(args['names'], ['mutation.prepare', 'mutation.commit']),
          'The capability request changed scope.',
        );
      } else if (index == 1) {
        _require(
          _same(args, {
            'commands': [
              {
                'kind': 'calendar',
                'action': 'create',
                'values': {'name': _calendarName, 'isVisible': false},
              },
            ],
          }),
          'The mutation preparation changed the synthetic target.',
        );
      } else {
        final result = _map(
          item['lastToolResult'],
          'Actual mutation prepare result',
        );
        _id(result['planId'], 'Actual prepared plan');
        _require(
          args['planId'] == result['planId'],
          'The commit did not consume its actual prepared plan.',
        );
      }
    } else {
      final expectedText = [
        _originalReply,
        _laterReply,
        _regeneratedReply,
        _replayedReply,
      ][index - 3];
      _require(
        calls.isEmpty && response['text'] == expectedText,
        'A text-only history response attempted a tool or changed content.',
      );
    }
  }
}

/// The central driver first validates native provenance, base fixture, shared
/// ownership and owner cleanup. This assessor verifies the history contract
/// from raw messages, real receipts, provider contexts and rendered evidence.
void validateAgentHistoryJourney(Map<String, Object?> report) {
  _require(
    report['feature'] == 'history' && report['status'] == 'passed',
    'The report is not a passed history journey.',
  );
  final steps = _steps(report);
  final accessible =
      _map(report['configuration'], 'Requested configuration')['name'] ==
      'accessible';
  for (final name in agentHistoryCheckpoints.skip(3).take(6)) {
    _configuration(steps[name]!['configuration'], accessible);
  }
  final fixture = _map(report['fixture'], 'Shared fixture');
  final created = steps['history-operation-saved']!;
  final original = _messages(
    created['suffix'],
    created['suffixSha256'],
    'Original owned suffix',
  );
  final originalTurn = _map(created['turn'], 'Original turn');
  final operations = _maps(
    originalTurn['operations'],
    'Original owned operations',
  );
  _require(
    operations.length == 1,
    'The original turn must own exactly one write.',
  );
  final operation = operations.single;
  final operationId = _id(operation['operationId'], 'Original operation ID');
  final originalRequestId = _id(
    originalTurn['requestMessageId'],
    'Original request ID',
  );
  final originalTurnId = _id(originalTurn['id'], 'Original turn ID');
  final receipt = _map(created['receipt'], 'Original persisted receipt');
  final calendar = _map(created['createdCalendar'], 'Created calendar');
  final calendarId = _id(calendar['id'], 'Created calendar ID');
  _require(
    original.first['role'] == 'user' &&
        original.first['text'] == _originalRequest &&
        original.first['id'] == originalRequestId &&
        original.last['role'] == 'assistant' &&
        original.last['text'] == _originalReply &&
        originalTurn['ownershipComplete'] == true &&
        operation['store'] == 'main' &&
        operation['toolCallId'] == 'history-call-3-mutation.commit' &&
        _list(
          originalTurn['runIds'],
          'Original run IDs',
        ).contains(operation['runId']) &&
        _same(
          originalTurn['messageIds'],
          original.map((message) => message['id']).toList(),
        ) &&
        receipt['operationId'] == operationId &&
        receipt['undo'] is Map &&
        receipt['sequence'] == 1 &&
        calendar['name'] == _calendarName &&
        calendar['isVisible'] == false &&
        _list(calendar['events'], 'Created calendar events').isEmpty &&
        created['calendarCount'] == 2 &&
        created['providerRequests'] == 4 &&
        created['originalPrefixSha256'] == fixture['longHistorySha256'] &&
        created['storageReadback'] ==
            'ConversationArchive.decode / AppData.decodeStorageSnapshot',
    'The original history checkpoint lacks the real reversible write and its ownership.',
  );
  _hashOf(
    created['businessBeforeSha256'],
    created['businessBefore'],
    'Initial business snapshot',
  );
  _digest(created['shortHistorySha256'], 'Independent history digest');

  final later = steps['history-later-turn-saved']!;
  final laterMessages = _messages(
    later['suffix'],
    later['suffixSha256'],
    'Two-turn suffix',
  );
  final turns = _maps(later['turns'], 'Two original turns');
  _require(
    laterMessages.length == original.length + 2 && turns.length == 2,
    'The later request did not add exactly one text-only turn.',
  );
  final laterTurn = turns.last;
  final laterReplyId = _id(later['replyId'], 'Later reply ID');
  _require(
    _same(laterMessages.take(original.length).toList(), original) &&
        _same(turns.first, originalTurn) &&
        laterMessages[laterMessages.length - 2]['role'] == 'user' &&
        laterMessages[laterMessages.length - 2]['text'] == _laterRequest &&
        laterMessages.last['role'] == 'assistant' &&
        laterMessages.last['text'] == _laterReply &&
        laterMessages.last['id'] == laterReplyId &&
        laterTurn['requestMessageId'] ==
            laterMessages[laterMessages.length - 2]['id'] &&
        laterTurn['ownershipComplete'] == true &&
        _list(laterTurn['operations'], 'Later operations').isEmpty &&
        _same(
          laterTurn['messageIds'],
          laterMessages
              .skip(original.length)
              .map((message) => message['id'])
              .toList(),
        ) &&
        later['providerRequests'] == 5,
    'The later explanation changed the original operation or added extra activity.',
  );

  final regenerated = steps['history-reply-regenerated']!;
  final revisions = _maps(regenerated['revisions'], 'Reply revisions');
  _require(
    revisions.length == 2,
    'Reply regeneration did not retain both text versions.',
  );
  for (var index = 0; index < revisions.length; index++) {
    _id(revisions[index]['id'], 'Reply revision ID');
    _id(revisions[index]['runId'], 'Reply revision run');
    _require(
      revisions[index]['messageId'] == laterReplyId &&
          revisions[index]['text'] ==
              (index == 0 ? _laterReply : _regeneratedReply),
      'A reply revision targets another message or text.',
    );
  }
  _require(
    regenerated['replyId'] == laterReplyId &&
        regenerated['beforeText'] == _laterReply &&
        regenerated['afterText'] == _regeneratedReply &&
        _same(
          regenerated['messageIdsBefore'],
          regenerated['messageIdsAfter'],
        ) &&
        _list(
              regenerated['messageIdsBefore'],
              'Regenerated message IDs',
            ).length ==
            512 + laterMessages.length &&
        _same(regenerated['turnsBefore'], turns) &&
        _same(regenerated['turnsBefore'], regenerated['turnsAfter']) &&
        regenerated['mainSha256Before'] == later['mainSha256'] &&
        _list(
          regenerated['regenerationRequestTools'],
          'Regeneration tools',
        ).isEmpty &&
        regenerated['providerRequests'] == 6,
    'Reply regeneration changed transcript identity, owned turns or its text-only request contract.',
  );
  _unchanged(regenerated, 'mainSha256');
  _rendered(regenerated['renderedReply'], _regeneratedReply);

  final cancelled = steps['history-edit-cancelled-reopened']!;
  _configuration(cancelled['reopenedConfiguration'], accessible);
  _require(
    cancelled['originalMessageId'] == originalRequestId &&
        cancelled['originalText'] == _originalRequest &&
        cancelled['typedEdit'] == _editedRequest &&
        cancelled['reopenedInput'] == _editedRequest &&
        cancelled['cancelAction'] == 'visible dialog Cancel button' &&
        cancelled['chatDraft'] == _draft &&
        cancelled['visibleChatDraftBeforeReopen'] == _draft &&
        cancelled['historyVersionCount'] == 0 &&
        cancelled.containsKey('pendingRedo') &&
        cancelled['pendingRedo'] == null &&
        cancelled['providerRequestsBefore'] == 6 &&
        cancelled['providerRequestsAfter'] == 6,
    'Cancelling and reopening the edit lost its draft or executed work.',
  );
  _unchanged(cancelled, 'messagesSha256');
  _unchanged(cancelled, 'mainSha256');
  final expectedRetired = [
    for (final message in laterMessages) Map<String, Object?>.from(message),
  ];
  expectedRetired.last['text'] = _regeneratedReply;
  _hashOf(
    cancelled['suffixSha256BeforeRedo'],
    expectedRetired,
    'Suffix before redo',
  );

  final redone = steps['history-turn-redone']!;
  final active = _messages(
    redone['activeSuffix'],
    redone['activeSuffixSha256'],
    'Edited active suffix',
  );
  final history = _map(redone['historyVersion'], 'Stored history version');
  final retired = _messages(
    history['messages'],
    redone['historyVersionMessagesSha256'],
    'Stored retired suffix',
  );
  final batch = _map(redone['batch'], 'Completed redo batch');
  final batchId = _id(batch['id'], 'Redo batch ID');
  final activeTurn = _map(redone['activeTurn'], 'Replayed turn');
  final tickets = _maps(batch['tickets'], 'Undo tickets');
  final receipts = _maps(redone['mainReceipts'], 'Main operation receipts');
  final inverseReceipts = receipts
      .where(
        (item) =>
            _map(item['result'], 'Receipt result')['undoBatchId'] == batchId,
      )
      .toList();
  _require(
    active.length == 2 &&
        active.first['role'] == 'user' &&
        active.first['text'] == _editedRequest &&
        active.last['role'] == 'assistant' &&
        active.last['text'] == _replayedReply &&
        active.first['id'] == 'redo:$batchId' &&
        _same(retired, expectedRetired) &&
        _same(history['turns'], turns) &&
        history['batchId'] == batchId &&
        history['id'] == batch['historyVersionId'] &&
        batch['phase'] == 'completed' &&
        batch['sourceMessageId'] == originalRequestId &&
        batch['sourceTurnId'] == originalTurnId &&
        batch['text'] == _editedRequest &&
        _same(batch['turnIds'], turns.map((turn) => turn['id']).toList()) &&
        batch['lastError'] == null &&
        tickets.length == 1 &&
        tickets.single['owner'] == 'main' &&
        tickets.single['token'] == batchId &&
        _same(tickets.single['operationIds'], [operationId]) &&
        _same(batch['completedOwners'], ['main']) &&
        activeTurn['requestMessageId'] == active.first['id'] &&
        activeTurn['ownershipComplete'] == true &&
        _same(activeTurn['runIds'], [batch['replayRunId']]) &&
        _same(
          activeTurn['messageIds'],
          active.map((message) => message['id']).toList(),
        ) &&
        _list(activeTurn['operations'], 'Replayed operations').isEmpty &&
        _same(redone['replyRevisions'], revisions) &&
        redone['createdCalendarId'] == calendarId &&
        receipts.length == 2 &&
        inverseReceipts.length == 1 &&
        redone['undoReceiptCount'] == 1 &&
        _map(inverseReceipts.single['result'], 'Inverse result')['status'] ==
            'committed' &&
        _same(
          _map(
            inverseReceipts.single['result'],
            'Inverse result',
          )['undoOperationIds'],
          [operationId],
        ) &&
        receipts.any((item) => _same(item, receipt)) &&
        redone.containsKey('pendingHistoryMarker') &&
        redone['pendingHistoryMarker'] == null &&
        redone['historyOwnsMaintenance'] == false &&
        redone['conversationCanWrite'] == true &&
        redone['mainCanWrite'] == true &&
        redone['savedDraft'] == _draft &&
        redone['visibleDraft'] == _draft &&
        redone['providerRequests'] == 7 &&
        redone['originalPrefixSha256'] == fixture['longHistorySha256'] &&
        redone['storageReadback'] ==
            'ConversationArchive.decode / AppData.decodeStorageSnapshot',
    'The completed redo did not undo the actual owned write once and publish only the selected edited request.',
  );
  _hashOf(
    redone['businessAfterSha256'],
    redone['businessAfter'],
    'Business snapshot after undo',
  );
  _require(
    _same(redone['businessAfter'], created['businessBefore']) &&
        redone['businessAfterSha256'] == created['businessBeforeSha256'],
    'Undo did not restore every business field outside the operation ledger.',
  );
  final finalGeneral = _map(
    _map(redone['businessAfter'], 'Final business snapshot')['generalMode'],
    'Final general workspace',
  );
  _require(
    _maps(finalGeneral['schedules'], 'Final calendars').every(
      (item) => item['id'] != calendarId && item['name'] != _calendarName,
    ),
    'The created calendar still exists after undo.',
  );
  final navigation = _map(
    redone['replyNavigation'],
    'Replayed reply navigation',
  );
  _require(
    navigation['jumpToLatestUsed'] is bool &&
        navigation['latestActionVisibleAfter'] is bool &&
        navigation['replyHitTestable'] == true &&
        (navigation['jumpToLatestUsed'] == false ||
            navigation['latestActionVisibleAfter'] == false),
    'The replayed reply was not reached through the visible product navigation.',
  );
  _rendered(redone['renderedReply'], _replayedReply);

  final browsed = steps['history-versions-browsed']!;
  _configuration(browsed['chatConfiguration'], accessible);
  final rendered = _maps(
    browsed['renderedHistory'],
    'Rendered history versions',
  );
  const expectedRendered = [
    (0, _originalRequest),
    (0, _laterRequest),
    (0, _regeneratedReply),
    (1, _laterReply),
    (2, _regeneratedReply),
  ];
  _require(
    rendered.length == expectedRendered.length &&
        browsed['expandedVersionCount'] == 3,
    'History browsing omitted the retired suffix or reply revisions.',
  );
  for (var index = 0; index < rendered.length; index++) {
    _require(
      rendered[index]['versionIndex'] == expectedRendered[index].$1,
      'A rendered text is attached to the wrong version.',
    );
    _rendered(rendered[index], expectedRendered[index].$2);
  }
  _require(
    browsed['providerRequestsBefore'] == 7 &&
        browsed['providerRequestsAfter'] == 7 &&
        browsed['selectedId'] == 'native-long-history' &&
        browsed['savedDraft'] == _draft &&
        browsed['visibleDraft'] == _draft &&
        browsed['originalPrefixSha256'] == fixture['longHistorySha256'] &&
        browsed['shortHistorySha256'] == created['shortHistorySha256'] &&
        browsed['shortDraft'] == 'Independent short conversation draft' &&
        browsed['knowledgeRecordCount'] == 0 &&
        browsed['knowledgeReceiptCount'] == 0 &&
        browsed['runActive'] == false,
    'Browsing versions changed context, data, another conversation or request count.',
  );
  _unchanged(browsed, 'mainSha256');
  _unchanged(browsed, 'chatSha256');
  _provider(report['providerBeforeCleanup'], closed: false);
  final cleanup = _map(report['cleanup'], 'History cleanup');
  _provider(cleanup['provider'], closed: true);
  _require(
    _same(
      _map(report['providerBeforeCleanup'], 'Provider before cleanup')['trace'],
      _map(cleanup['provider'], 'Closed provider')['trace'],
    ),
    'Cleanup changed the observed history request trace.',
  );
  final boundaries = _map(
    cleanup['featureBoundaries'],
    'History feature boundaries',
  );
  _require(
    boundaries['status'] == 'complete' &&
        boundaries['owner'] == 'history' &&
        _list(
          boundaries['installed'],
          'Installed history boundaries',
        ).isEmpty &&
        _list(boundaries['restored'], 'Restored history boundaries').isEmpty,
    'The history journey introduced or failed to release a platform boundary.',
  );
}
