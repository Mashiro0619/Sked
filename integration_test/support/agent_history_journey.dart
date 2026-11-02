import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/app_data.dart';

import 'agent_feature_journey.dart';
import 'agent_native_session.dart';

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
const _unsentDraft = 'Unsent chat draft kept while editing a previous request';

const _providerPhases = [
  'original-capabilities',
  'original-prepare',
  'original-commit',
  'original-reply',
  'later-reply',
  'reply-regeneration',
  'edited-request-reply',
];

class _HistoryTransport extends http.BaseClient {
  var attempts = 0;
  var closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError('The native history script cannot use HTTP transport.');
  }

  @override
  void close() {
    if (closed) return;
    closed = true;
    super.close();
  }
}

/// Deterministic model boundary only. Production tools, ownership recording,
/// approvals, history transactions and persistence remain application-owned.
class _HistoryProvider extends ProviderClient {
  _HistoryProvider._(this.transport) : super(client: transport);
  factory _HistoryProvider() => _HistoryProvider._(_HistoryTransport());

  final _HistoryTransport transport;
  final trace = <Map<String, Object?>>[];
  var completedResponses = 0;
  var closeCount = 0;
  bool get closed => closeCount != 0;
  int get requests => trace.length;

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) async* {
    final index = trace.length;
    final users = request.messages
        .where((message) => message.role == ProviderRole.user)
        .map((message) => message.text)
        .toList();
    final tools = request.tools.map((tool) => tool.name).toList();
    final lastTool = request.messages
        .where((message) => message.role == ProviderRole.tool)
        .lastOrNull;
    final observed = <String, Object?>{
      'requestIndex': index + 1,
      'phase': index < _providerPhases.length
          ? _providerPhases[index]
          : 'unexpected',
      'endpointHost': request.endpoint.host,
      'model': request.model,
      'messageCount': request.messages.length,
      'userTexts': users,
      'toolNames': tools,
      'credentialPresent': apiKey.isNotEmpty,
      'cancelledAtStart': cancellation?.isCancelled,
      'status': 'running',
    };
    trace.add(observed);
    try {
      requireAgentFeature(
        !closed &&
            index < _providerPhases.length &&
            cancellation != null &&
            !cancellation.isCancelled,
        'An extra, closed or cancelled history request reached the provider.',
      );
      requireAgentFeature(
        apiKey.isEmpty &&
            request.endpoint.host == 'native-ui.invalid' &&
            request.model == 'native-ui-fixture' &&
            users.isNotEmpty,
        'The history request did not use the explicit synthetic model.',
      );
      final expectedInput = index < 4
          ? _originalRequest
          : index < 6
          ? _laterRequest
          : _editedRequest;
      requireAgentFeature(
        users.last == expectedInput,
        'A history action sent a different or repeated user request.',
      );
      requireAgentFeature(
        index == 5 ? tools.isEmpty : tools.isNotEmpty,
        'Only reply regeneration may use the empty-tool request path.',
      );
      if (index == 6) {
        requireAgentFeature(
          !users.contains(_originalRequest) && !users.contains(_laterRequest),
          'The edited request replayed the retired user suffix.',
        );
      }

      Map<String, Object?> lastResult() {
        requireAgentFeature(lastTool != null, 'A real tool result is missing.');
        final decoded = jsonDecode(lastTool!.text);
        requireAgentFeature(
          decoded is Map,
          'A real tool result is not an object.',
        );
        final result = Map<String, Object?>.from(decoded as Map);
        observed['lastToolResult'] = result;
        return result;
      }

      String preparedPlanId() {
        final value = lastResult()['planId'];
        requireAgentFeature(
          value is String && value.isNotEmpty,
          'The actual prepare result has no plan identity.',
        );
        return value as String;
      }

      ProviderResponse call(String name, Map<String, Object?> arguments) {
        requireAgentFeature(
          tools.contains(name),
          'The requested tool is not exposed.',
        );
        return ProviderResponse(
          text: '',
          toolCalls: [
            ProviderToolCall(
              id: 'history-call-${index + 1}-$name',
              name: name,
              arguments: jsonEncode(arguments),
            ),
          ],
          finishReason: 'tool_calls',
        );
      }

      ProviderResponse done(String text) => ProviderResponse(
        text: text,
        toolCalls: const [],
        finishReason: 'stop',
      );

      final response = switch (index) {
        0 => call('capabilities.describe', {
          'names': ['mutation.prepare', 'mutation.commit'],
        }),
        1 => call('mutation.prepare', {
          'commands': [
            {
              'kind': 'calendar',
              'action': 'create',
              'values': {'name': _calendarName, 'isVisible': false},
            },
          ],
        }),
        2 => call('mutation.commit', {'planId': preparedPlanId()}),
        3 => done(_originalReply),
        4 => done(_laterReply),
        5 => done(_regeneratedReply),
        6 => done(_replayedReply),
        _ => throw StateError('Unexpected history script index.'),
      };
      observed['response'] = {
        'text': response.text,
        'toolCalls': [
          for (final tool in response.toolCalls)
            {
              'id': tool.id,
              'name': tool.name,
              'arguments': tool.decodedArguments,
            },
        ],
      };
      observed['status'] = 'complete';
      completedResponses++;
      yield ProviderCompleted(response);
    } catch (error) {
      observed.addAll({'status': 'failed', 'error': '$error'});
      rethrow;
    }
  }

  Map<String, Object?> toJson() => {
    'type': 'history-scripted-offline',
    'requests': requests,
    'completedResponses': completedResponses,
    'trace': [for (final item in trace) Map<String, Object?>.from(item)],
    'transportAttempts': transport.attempts,
    'transportClosed': transport.closed,
    'closed': closed,
    'closeCount': closeCount,
  };

  @override
  void close() {
    if (closed) return;
    super.close();
    transport.close();
    closeCount++;
  }
}

/// Every chat send, regeneration, edit, cancellation and history selection
/// enters through the visible product UI. Reads below verify real owner saves.
class AgentHistoryJourney implements AgentNativeFeature {
  final _provider = _HistoryProvider();
  AgentFeatureJourney? _active;
  String? _originalMessageId;
  String? _replyMessageId;
  String? _createdCalendarId;
  String? _originalOperationId;
  String? _shortDigest;
  String? _businessDigest;
  String? _beforeRedoDigest;
  AgentConversation? _beforeRedo;

  @override
  String get name => 'history';

  @override
  ProviderClient get provider => _provider;

  @override
  Map<String, Object?> providerReport() => _provider.toJson();

  @override
  Map<String, Object?> diagnostics() => {
    'originalMessageId': _originalMessageId,
    'replyMessageId': _replyMessageId,
    'createdCalendarId': _createdCalendarId,
    'originalOperationId': _originalOperationId,
    'beforeRedoMessageSha256': _beforeRedoDigest,
    if (_active case final journey?)
      'history': {
        'turnCount': _current(journey).turns.length,
        'versionCount': _current(journey).historyVersions.length,
        'replyRevisionCount': _current(journey).replyRevisions.length,
        'pendingRedo': _current(journey).pendingRedo?.toJson(),
        'ownsMaintenance': journey.session.app.agent.history.ownsMaintenance,
      },
  };

  @override
  Future<Map<String, Object?>> releaseBoundaries() async => {
    'status': 'complete',
    'owner': name,
    'installed': <String>[],
    'restored': <String>[],
    'scope': 'no picker or platform-channel replacement installed',
  };

  @override
  Future<void> exercise(AgentFeatureJourney journey) async {
    _active = journey;
    await journey.checkpoint(
      'history-operation-saved',
      () => _createOriginal(journey),
    );
    await journey.checkpoint(
      'history-later-turn-saved',
      () => _createLater(journey),
    );
    await journey.checkpoint(
      'history-reply-regenerated',
      () => _regenerate(journey),
    );
    await journey.checkpoint(
      'history-edit-cancelled-reopened',
      () => _cancelAndReopen(journey),
    );
    await journey.checkpoint(
      'history-turn-redone',
      () => _confirmRedo(journey),
    );
    await journey.checkpoint(
      'history-versions-browsed',
      () => _browseVersions(journey),
    );
  }

  AgentConversation _current(AgentFeatureJourney journey) =>
      journey.session.app.agent.conversations.find(agentNativeLongId)!;

  List<Map<String, Object?>> _messages(
    Iterable<ConversationMessage> messages,
  ) => [for (final message in messages) message.toJson()];

  Map<String, dynamic> _business(AppData data) =>
      data.toJson()..remove('applicationLedger');

  Future<AgentConversation> _readSaved(AgentFeatureJourney journey) async {
    final app = journey.session.app;
    await app.agent.runtime.waitForIdle().timeout(const Duration(seconds: 20));
    await app.agent.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    await app.session.repository
        .waitForPendingWrites(propagateErrors: true)
        .timeout(const Duration(seconds: 20));
    await app.agent.knowledgeRepository.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    final archive = ConversationArchive.decode(journey.session.chatSource);
    final saved = archive.conversations.singleWhere(
      (item) => item.id == agentNativeLongId,
    );
    final short = archive.conversations.singleWhere(
      (item) => item.id == agentNativeShortId,
    );
    requireAgentFeature(
      archive.conversations.length == 2 &&
          archive.selectedId == agentNativeLongId &&
          saved.messages.length >= agentNativeMessageCount &&
          AgentNativeSession.historyDigest(
                saved.messages.take(agentNativeMessageCount),
              ) ==
              journey.session.originalHistoryDigest &&
          short.messages.length == 2 &&
          short.draft == agentNativeShortDraft &&
          (_shortDigest == null ||
              AgentNativeSession.historyDigest(short.messages) == _shortDigest),
      'The history journey changed the fixed prefix, independent conversation or selection.',
    );
    requireAgentFeature(
      jsonEncode(saved.toJson()) == jsonEncode(_current(journey).toJson()),
      'The live history state differs from the production-codec storage readback.',
    );
    final main = AppData.decodeStorageSnapshot(journey.session.mainSource);
    requireAgentFeature(
      main.encode() == app.session.committedData.encode(),
      'The committed main owner differs from its saved storage snapshot.',
    );
    requireAgentFeature(
      app.agent.knowledgeRepository.records.isEmpty &&
          app.agent.knowledgeRepository.snapshot.receipts.isEmpty,
      'History of a main-store operation changed shared knowledge.',
    );
    requireAgentFeature(
      _provider.transport.attempts == 0,
      'The synthetic provider attempted HTTP.',
    );
    return saved;
  }

  Future<void> _send(
    AgentFeatureJourney journey,
    String text,
    String reply,
    int requests,
  ) async {
    await journey.enterDraft(text);
    final send = journey.key('agent-send').hitTestable();
    await journey.until(
      () =>
          send.evaluate().length == 1 &&
          journey.tester.widget<IconButton>(send).onPressed != null,
      'the enabled history Send button',
    );
    await journey.tap(send, 'the product history Send button');
    await journey.until(
      () =>
          _provider.requests == requests &&
          _current(journey).status == ConversationStatus.idle &&
          !journey.session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .isActive &&
          _current(journey).messages.last.text == reply,
      'the completed scripted history reply',
    );
  }

  Future<Map<String, Object?>> _createOriginal(
    AgentFeatureJourney journey,
  ) async {
    final initial = await _readSaved(journey);
    _shortDigest = AgentNativeSession.historyDigest(
      ConversationArchive.decode(journey.session.chatSource).conversations
          .singleWhere((item) => item.id == agentNativeShortId)
          .messages,
    );
    final businessBefore = _business(
      AppData.decodeStorageSnapshot(journey.session.mainSource),
    );
    _businessDigest = agentNativeDigest(jsonEncode(businessBefore));
    requireAgentFeature(
      initial.turns.isEmpty &&
          initial.historyVersions.isEmpty &&
          initial.replyRevisions.isEmpty &&
          initial.pendingRedo == null &&
          _provider.requests == 0,
      'The seeded history contains execution or version ownership.',
    );
    await _send(journey, _originalRequest, _originalReply, 4);
    final saved = await _readSaved(journey);
    final suffix = saved.messages.skip(agentNativeMessageCount).toList();
    final turn = saved.turns.single;
    final binding = turn.operations.single;
    _originalMessageId = turn.requestMessageId;
    _originalOperationId = binding.operationId;
    final main = AppData.decodeStorageSnapshot(journey.session.mainSource);
    final calendar = main.generalMode.schedules.singleWhere(
      (item) => item.name == _calendarName,
    );
    _createdCalendarId = calendar.id;
    final receipt = main.applicationLedger!.receipts.singleWhere(
      (item) => item.operationId == binding.operationId,
    );
    requireAgentFeature(
      suffix.first.id == turn.requestMessageId &&
          suffix.first.text == _originalRequest &&
          suffix.last.text == _originalReply &&
          turn.ownershipComplete &&
          binding.store == ConversationOperationStore.main &&
          binding.toolCallId == 'history-call-3-mutation.commit' &&
          turn.runIds.contains(binding.runId) &&
          receipt.undo != null &&
          main.generalMode.schedules.length == 2 &&
          calendar.events.isEmpty &&
          main.applicationLedger!.receipts.length == 1,
      'The original tool run did not persist one reversible owned calendar creation.',
    );
    return {
      'configuration': journey.assertOwner(),
      'businessBefore': businessBefore,
      'businessBeforeSha256': _businessDigest,
      'shortHistorySha256': _shortDigest,
      'originalPrefixSha256': journey.session.originalHistoryDigest,
      'suffix': _messages(suffix),
      'suffixSha256': AgentNativeSession.historyDigest(suffix),
      'turn': turn.toJson(),
      'createdCalendar': calendar.toJson(),
      'receipt': receipt.toJson(),
      'calendarCount': main.generalMode.schedules.length,
      'providerRequests': _provider.requests,
      'storageReadback':
          'ConversationArchive.decode / AppData.decodeStorageSnapshot',
    };
  }

  Future<Map<String, Object?>> _createLater(AgentFeatureJourney journey) async {
    await _send(journey, _laterRequest, _laterReply, 5);
    final saved = await _readSaved(journey);
    final last = saved.turns.last;
    final reply = saved.messages.last;
    _replyMessageId = reply.id;
    requireAgentFeature(
      saved.turns.length == 2 &&
          last.ownershipComplete &&
          last.operations.isEmpty &&
          saved.messages
                  .singleWhere((item) => item.id == last.requestMessageId)
                  .text ==
              _laterRequest &&
          reply.role == ConversationRole.assistant &&
          reply.toolCalls.isEmpty &&
          last.messageIds.length == 2 &&
          last.messageIds.last == reply.id &&
          saved.turns.first.operations.single.operationId ==
              _originalOperationId,
      'The later explanation did not produce one separate text-only turn.',
    );
    return {
      'configuration': journey.assertOwner(),
      'turns': [for (final turn in saved.turns) turn.toJson()],
      'suffix': _messages(saved.messages.skip(agentNativeMessageCount)),
      'suffixSha256': AgentNativeSession.historyDigest(
        saved.messages.skip(agentNativeMessageCount),
      ),
      'replyId': reply.id,
      'providerRequests': _provider.requests,
      'mainSha256': agentNativeDigest(journey.session.mainSource),
    };
  }

  Future<void> _revealTranscript(
    AgentFeatureJourney journey,
    Finder target, {
    bool older = true,
  }) async {
    final transcript = journey
        .key('agent-transcript-$agentNativeLongId')
        .hitTestable();
    await journey.until(
      () => transcript.evaluate().length == 1,
      'the actual history transcript',
    );
    for (
      var attempt = 0;
      attempt < 30 && target.evaluate().isEmpty;
      attempt++
    ) {
      final height = journey.tester.getSize(transcript).height;
      final distance = (height * 0.72).clamp(180.0, 520.0).toDouble();
      await journey.tester.drag(
        transcript,
        Offset(0, older ? distance : -distance),
      );
      await journey.tester.pump(const Duration(milliseconds: 16));
    }
    await journey.reveal(target, 'the targeted history message action');
  }

  Map<String, Object?> _renderedText(
    AgentFeatureJourney journey,
    Finder target,
    String expected,
  ) {
    requireAgentFeature(
      target.hitTestable().evaluate().length == 1,
      'The observed history text is not visible.',
    );
    final root = journey.tester
        .element(target.hitTestable())
        .findRenderObject();
    final fragments = <String>[];
    var paragraphs = 0;
    var editables = 0;
    void visit(RenderObject object) {
      if (!object.attached ||
          object is RenderOffstage && object.offstage ||
          object is RenderBox && !object.hasSize) {
        return;
      }
      if (object is RenderParagraph) {
        paragraphs++;
        fragments.add(object.text.toPlainText(includeSemanticsLabels: false));
      } else if (object is RenderEditable) {
        editables++;
        final text = object.text;
        if (text != null) {
          fragments.add(text.toPlainText(includeSemanticsLabels: false));
        }
      }
      object.visitChildren(visit);
    }

    if (root != null) visit(root);
    requireAgentFeature(
      fragments.where((text) => text == expected).length == 1,
      'The actual rendered history body does not match the saved text.',
    );
    final observedText = fragments.singleWhere((text) => text == expected);
    return {
      'text': observedText,
      'sha256': agentNativeDigest(observedText),
      'textSource': 'render-paragraph-and-editable',
      'renderParagraphCount': paragraphs,
      'renderEditableCount': editables,
    };
  }

  Future<Map<String, Object?>> _regenerate(AgentFeatureJourney journey) async {
    final before = await _readSaved(journey);
    final mainBefore = journey.session.mainSource;
    final action = journey.key('agent-regenerate-$_replyMessageId');
    await _revealTranscript(journey, action);
    await journey.tap(action, 'the real Regenerate reply button');
    await journey.until(
      () =>
          _provider.requests == 6 &&
          !journey.session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .isActive &&
          _current(journey).messages.last.text == _regeneratedReply,
      'the saved regenerated reply',
    );
    final saved = await _readSaved(journey);
    requireAgentFeature(
      saved.messages.length == before.messages.length &&
          saved.messages.last.id == _replyMessageId &&
          saved.replyRevisions.length == 2 &&
          saved.replyRevisions.first.text == _laterReply &&
          saved.replyRevisions.last.text == _regeneratedReply &&
          saved.replyRevisions.every(
            (revision) => revision.messageId == _replyMessageId,
          ) &&
          jsonEncode(saved.turns.map((turn) => turn.toJson()).toList()) ==
              jsonEncode(before.turns.map((turn) => turn.toJson()).toList()) &&
          journey.session.mainSource == mainBefore &&
          saved.pendingRedo == null,
      'Reply regeneration changed ownership, business data or transcript identity.',
    );
    final body = journey.key('agent-message-$_replyMessageId');
    await _revealTranscript(journey, body);
    return {
      'configuration': journey.assertOwner(),
      'replyId': _replyMessageId,
      'beforeText': _laterReply,
      'afterText': _regeneratedReply,
      'messageIdsBefore': before.messages.map((message) => message.id).toList(),
      'messageIdsAfter': saved.messages.map((message) => message.id).toList(),
      'turnsBefore': [for (final turn in before.turns) turn.toJson()],
      'turnsAfter': [for (final turn in saved.turns) turn.toJson()],
      'revisions': [
        for (final revision in saved.replyRevisions) revision.toJson(),
      ],
      'renderedReply': _renderedText(journey, body, _regeneratedReply),
      'mainSha256Before': agentNativeDigest(mainBefore),
      'mainSha256After': agentNativeDigest(journey.session.mainSource),
      'providerRequests': _provider.requests,
      'regenerationRequestTools': _provider.trace[5]['toolNames'],
    };
  }

  Finder _editDialog(AgentFeatureJourney journey) => find.ancestor(
    of: journey.key('agent-redo-input'),
    matching: find.byType(AlertDialog),
  );

  Future<void> _openEdit(AgentFeatureJourney journey) async {
    final action = journey.key('agent-edit-redo-$_originalMessageId');
    await _revealTranscript(journey, action);
    await journey.tap(action, 'the original request Edit and redo button');
    await journey.until(
      () => _editDialog(journey).evaluate().length == 1,
      'the actual history editor',
    );
    await journey.reveal(
      journey.key('agent-redo-input'),
      'the history edit input',
    );
  }

  Future<Map<String, Object?>> _cancelAndReopen(
    AgentFeatureJourney journey,
  ) async {
    await journey.enterDraft(_unsentDraft);
    final before = await _readSaved(journey);
    final mainBefore = journey.session.mainSource;
    final requestsBefore = _provider.requests;
    final historyBefore = AgentNativeSession.historyDigest(before.messages);
    await _openEdit(journey);
    final input = journey.key('agent-redo-input');
    requireAgentFeature(
      journey.tester.widget<TextField>(input).controller!.text ==
          _originalRequest,
      'The editor opened a different original request.',
    );
    await journey.tester.enterText(input, _editedRequest);
    requireAgentFeature(
      journey.tester.widget<TextField>(input).controller!.text ==
          _editedRequest,
      'The history editor lost the typed replacement.',
    );
    final editConfiguration = journey.configurationAt(
      journey.tester.element(_editDialog(journey)),
    );
    final cancelLabel = AppLocalizations.of(
      journey.tester.element(_editDialog(journey)),
    ).cancel;
    final cancel = find.descendant(
      of: _editDialog(journey),
      matching: find.widgetWithText(TextButton, cancelLabel),
    );
    await journey.reveal(cancel, 'the history editor Cancel button');
    await journey.tap(cancel, 'the history editor Cancel button');
    await journey.until(
      () => _editDialog(journey).evaluate().isEmpty,
      'the cancelled history editor to close',
    );
    final after = await _readSaved(journey);
    final visibleDraftAfterCancel = journey.field.controller!.text;
    requireAgentFeature(
      _provider.requests == 6 &&
          AgentNativeSession.historyDigest(after.messages) == historyBefore &&
          journey.session.mainSource == mainBefore &&
          after.historyVersions.isEmpty &&
          after.pendingRedo == null &&
          after.draft == _unsentDraft &&
          journey.field.controller!.text == _unsentDraft,
      'Cancelling a history edit executed work or changed the chat draft.',
    );
    _beforeRedo = after;
    _beforeRedoDigest = AgentNativeSession.historyDigest(
      after.messages.skip(agentNativeMessageCount),
    );
    await _openEdit(journey);
    final reopened = journey.tester.widget<TextField>(input).controller!.text;
    requireAgentFeature(
      reopened == _editedRequest,
      'Reopening the history editor lost the cancelled edit draft.',
    );
    return {
      'configuration': editConfiguration,
      'reopenedConfiguration': journey.configurationAt(
        journey.tester.element(_editDialog(journey)),
      ),
      'originalMessageId': _originalMessageId,
      'originalText': _originalRequest,
      'typedEdit': _editedRequest,
      'reopenedInput': reopened,
      'cancelAction': 'visible dialog Cancel button',
      'messagesSha256Before': historyBefore,
      'messagesSha256After': AgentNativeSession.historyDigest(after.messages),
      'mainSha256Before': agentNativeDigest(mainBefore),
      'mainSha256After': agentNativeDigest(journey.session.mainSource),
      'chatDraft': after.draft,
      'visibleChatDraftBeforeReopen': visibleDraftAfterCancel,
      'historyVersionCount': after.historyVersions.length,
      'pendingRedo': after.pendingRedo?.toJson(),
      'providerRequestsBefore': requestsBefore,
      'providerRequestsAfter': _provider.requests,
      'suffixSha256BeforeRedo': _beforeRedoDigest,
    };
  }

  Future<Map<String, Object?>> _confirmRedo(AgentFeatureJourney journey) async {
    final confirmation = journey.key('agent-confirm-redo');
    await journey.reveal(
      confirmation,
      'the enabled Confirm edit and redo button',
    );
    requireAgentFeature(
      journey.tester.widget<FilledButton>(confirmation).onPressed != null,
      'The edited request cannot be confirmed.',
    );
    await journey.tap(confirmation, 'the product Confirm edit and redo button');
    await journey.until(
      () =>
          _provider.requests == 7 &&
          _current(journey).pendingRedo == null &&
          _current(journey).historyVersions.length == 1 &&
          _current(journey).messages.last.text == _replayedReply &&
          !journey.session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .isActive,
      'the completed real undo and one edited replay',
    );
    final saved = await _readSaved(journey);
    final main = AppData.decodeStorageSnapshot(journey.session.mainSource);
    final businessAfter = _business(main);
    final suffix = saved.messages.skip(agentNativeMessageCount).toList();
    final version = saved.historyVersions.single;
    final batch = saved.redoBatches.single;
    final turn = saved.turns.single;
    final receipts = main.applicationLedger!.receipts;
    final inverses = receipts
        .where((receipt) => receipt.result['undoBatchId'] == batch.id)
        .toList();
    final marker = await journey.session.app.agent.conversations
        .pendingHistoryBatch();
    requireAgentFeature(
      suffix.length == 2 &&
          suffix.first.role == ConversationRole.user &&
          suffix.first.text == _editedRequest &&
          suffix.last.role == ConversationRole.assistant &&
          suffix.last.text == _replayedReply &&
          AgentNativeSession.historyDigest(version.messages) ==
              _beforeRedoDigest &&
          jsonEncode(version.turns.map((item) => item.toJson()).toList()) ==
              jsonEncode(
                _beforeRedo!.turns.map((item) => item.toJson()).toList(),
              ) &&
          batch.phase == ConversationRedoPhase.completed &&
          batch.sourceMessageId == _originalMessageId &&
          batch.historyVersionId == version.id &&
          version.batchId == batch.id &&
          batch.turnIds.length == 2 &&
          turn.runIds.contains(batch.replayRunId) &&
          turn.requestMessageId == suffix.first.id &&
          turn.operations.isEmpty &&
          turn.ownershipComplete &&
          saved.replyRevisions.length == 2 &&
          main.generalMode.schedules.every(
            (calendar) => calendar.id != _createdCalendarId,
          ) &&
          agentNativeDigest(jsonEncode(businessAfter)) == _businessDigest &&
          receipts.length == 2 &&
          inverses.length == 1 &&
          inverses.single.result['status'] == 'committed' &&
          jsonEncode(inverses.single.result['undoOperationIds']) ==
              jsonEncode([_originalOperationId]) &&
          receipts.any(
            (receipt) => receipt.operationId == _originalOperationId,
          ) &&
          marker == null &&
          !journey.session.app.agent.history.ownsMaintenance &&
          journey.session.app.agent.conversations.canWrite &&
          journey.session.app.lifecycle.canWrite &&
          saved.draft == _unsentDraft &&
          journey.field.controller!.text == _unsentDraft,
      'The real history redo did not preserve ownership, undo once and replay only the edited request.',
    );
    final body = journey.key('agent-message-${suffix.last.id}');
    final latest = journey.key('agent-jump-latest');
    final jumpedToLatest = latest.evaluate().isNotEmpty;
    if (jumpedToLatest) {
      // The old reading anchor can belong to the retired suffix. Use the
      // product action to view the new reply across the full lazy history.
      requireAgentFeature(
        journey.tester.widget<IconButton>(latest).onPressed != null,
        'The history Return to latest action is disabled.',
      );
      await journey.tap(latest, 'Return to latest after the edited replay');
      await journey.until(
        () =>
            body.evaluate().length == 1 &&
            latest.hitTestable().evaluate().isEmpty,
        'the replayed reply after Return to latest',
      );
    }
    await _revealTranscript(journey, body, older: false);
    return {
      'configuration': journey.assertOwner(),
      'activeSuffix': _messages(suffix),
      'activeSuffixSha256': AgentNativeSession.historyDigest(suffix),
      'originalPrefixSha256': AgentNativeSession.historyDigest(
        saved.messages.take(agentNativeMessageCount),
      ),
      'historyVersion': version.toJson(),
      'historyVersionMessagesSha256': AgentNativeSession.historyDigest(
        version.messages,
      ),
      'batch': batch.toJson(),
      'activeTurn': turn.toJson(),
      'replyRevisions': [
        for (final revision in saved.replyRevisions) revision.toJson(),
      ],
      'createdCalendarId': _createdCalendarId,
      'businessAfter': businessAfter,
      'businessAfterSha256': agentNativeDigest(jsonEncode(businessAfter)),
      'mainReceipts': [for (final receipt in receipts) receipt.toJson()],
      'undoReceiptCount': inverses.length,
      'pendingHistoryMarker': marker,
      'historyOwnsMaintenance':
          journey.session.app.agent.history.ownsMaintenance,
      'conversationCanWrite': journey.session.app.agent.conversations.canWrite,
      'mainCanWrite': journey.session.app.lifecycle.canWrite,
      'savedDraft': saved.draft,
      'visibleDraft': journey.field.controller!.text,
      'providerRequests': _provider.requests,
      'replyNavigation': {
        'jumpToLatestUsed': jumpedToLatest,
        'latestActionVisibleAfter': latest.hitTestable().evaluate().isNotEmpty,
        'replyHitTestable': body.hitTestable().evaluate().length == 1,
      },
      'renderedReply': _renderedText(journey, body, _replayedReply),
      'storageReadback':
          'ConversationArchive.decode / AppData.decodeStorageSnapshot',
    };
  }

  Future<Map<String, Object?>> _browseVersions(
    AgentFeatureJourney journey,
  ) async {
    final saved = await _readSaved(journey);
    final mainBefore = journey.session.mainSource;
    final chatBefore = journey.session.chatSource;
    final requestsBefore = _provider.requests;
    final menu = journey.key('agent-conversation-menu');
    await journey.tap(menu, 'the conversation menu');
    final versionsItem = find.byWidgetPredicate(
      (widget) =>
          widget is PopupMenuItem<String> && widget.value == 'message-history',
    );
    await journey.tap(versionsItem, 'the actual Message history menu item');
    final dialog = find.byType(AlertDialog).hitTestable();
    await journey.until(
      () => dialog.evaluate().length == 1,
      'the message history dialog',
    );
    final tiles = find.descendant(
      of: dialog,
      matching: find.byType(ExpansionTile),
    );
    requireAgentFeature(
      tiles.evaluate().length == 3,
      'The history dialog omitted the suffix or reply versions.',
    );
    final rendered = <Map<String, Object?>>[];
    final expectedTexts = [
      [_originalRequest, _laterRequest, _regeneratedReply],
      [_laterReply],
      [_regeneratedReply],
    ];
    for (var index = 0; index < expectedTexts.length; index++) {
      final tile = tiles.at(index);
      final header = find
          .descendant(of: tile, matching: find.byType(ListTile))
          .first;
      await journey.reveal(header, 'history version ${index + 1} header');
      await journey.tap(header, 'history version ${index + 1} expand action');
      // The run is idle. Let expansion finish changing the scroll extent
      // before revealing text against the dialog's final layout.
      await journey.tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      for (final text in expectedTexts[index]) {
        final body = find.descendant(
          of: tile,
          matching: find.byWidgetPredicate(
            (widget) => widget is SelectableText && widget.data == text,
          ),
        );
        await journey.reveal(
          body,
          'the stored text in history version ${index + 1}',
        );
        rendered.add({
          'versionIndex': index,
          ..._renderedText(journey, body, text),
        });
      }
      await journey.reveal(
        header,
        'history version ${index + 1} collapse action',
      );
      await journey.tap(header, 'history version ${index + 1} collapse action');
      await journey.tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    }
    final configuration = journey.configurationAt(
      journey.tester.element(dialog),
    );
    final confirmLabel = AppLocalizations.of(journey.tester.element(dialog))
        .confirm;
    final close = find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextButton, confirmLabel),
    );
    await journey.reveal(close, 'the message history Close button');
    await journey.tap(close, 'the message history Close button');
    await journey.until(
      () => dialog.evaluate().isEmpty,
      'the message history dialog to close',
    );
    final after = await _readSaved(journey);
    final short = ConversationArchive.decode(journey.session.chatSource)
        .conversations
        .singleWhere((item) => item.id == agentNativeShortId);
    requireAgentFeature(
      _provider.requests == 7 &&
          _provider.completedResponses == 7 &&
          journey.session.mainSource == mainBefore &&
          journey.session.chatSource == chatBefore &&
          jsonEncode(after.toJson()) == jsonEncode(saved.toJson()) &&
          journey.field.controller!.text == _unsentDraft,
      'Viewing historical versions replayed a request, changed context or lost the draft.',
    );
    return {
      'configuration': configuration,
      'chatConfiguration': journey.assertOwner(),
      'expandedVersionCount': 3,
      'renderedHistory': rendered,
      'providerRequestsBefore': requestsBefore,
      'providerRequestsAfter': _provider.requests,
      'mainSha256Before': agentNativeDigest(mainBefore),
      'mainSha256After': agentNativeDigest(journey.session.mainSource),
      'chatSha256Before': agentNativeDigest(chatBefore),
      'chatSha256After': agentNativeDigest(journey.session.chatSource),
      'selectedId': journey.session.app.agent.conversations.selectedId,
      'savedDraft': after.draft,
      'visibleDraft': journey.field.controller!.text,
      'originalPrefixSha256': AgentNativeSession.historyDigest(
        after.messages.take(agentNativeMessageCount),
      ),
      'shortHistorySha256': AgentNativeSession.historyDigest(short.messages),
      'shortDraft': short.draft,
      'knowledgeRecordCount':
          journey.session.app.agent.knowledgeRepository.records.length,
      'knowledgeReceiptCount': journey
          .session
          .app
          .agent
          .knowledgeRepository
          .snapshot
          .receipts
          .length,
      'runActive': journey.session.app.agent.runtime.state.value
          .runFor(agentNativeLongId)
          .isActive,
    };
  }
}
