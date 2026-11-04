import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/agent_application.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/knowledge/knowledge_service.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_knowledge_view.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/agent_settings_page.dart';

import 'agent_feature_journey.dart';
import 'agent_native_session.dart';

const _draft = 'Unsent draft before editing shared knowledge';
const _createdTitle = 'Synthetic study preference';
const _createdBody = 'Prefer quiet mornings for the synthetic reading session.';
const _updatedTitle = 'Updated synthetic study preference';
const _updatedBody =
    'Prefer quiet afternoons for the synthetic reading session.';
const _cancelledBody = 'This synthetic memory edit must remain unsaved.';

class _KnowledgeTransport extends http.BaseClient {
  var attempts = 0;
  var closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError(
      'Knowledge settings must not use provider HTTP transport.',
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

/// Settings edits must make zero model requests, including accidental retries.
/// Only counts are retained; no credential or request payload is reported.
class _KnowledgeProvider extends ProviderClient {
  _KnowledgeProvider._(this.transport) : super(client: transport);
  factory _KnowledgeProvider() => _KnowledgeProvider._(_KnowledgeTransport());

  final _KnowledgeTransport transport;
  var requests = 0;
  var closeCount = 0;
  bool get closed => closeCount != 0;

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests++;
    return Stream.error(
      StateError('Knowledge settings unexpectedly requested a model response.'),
    );
  }

  Map<String, Object?> toJson() => {
    'type': 'knowledge-offline',
    'requests': requests,
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

/// The real home, Agent host, settings route and knowledge editor perform all
/// mutations. Repository reloads observe what their synthetic store retained.
class AgentKnowledgeJourney implements AgentNativeFeature {
  final _provider = _KnowledgeProvider();
  AgentFeatureJourney? _active;
  KnowledgeRecord? _created;
  KnowledgeRecord? _updated;
  var _reloads = 0;
  String? _initialShortHistoryDigest;

  @override
  String get name => 'knowledge';

  @override
  ProviderClient get provider => _provider;

  @override
  Map<String, Object?> providerReport() => _provider.toJson();

  @override
  Map<String, Object?> diagnostics() => {
    'createdKey': _created?.key,
    'createdRevision': _created?.revision,
    'updatedKey': _updated?.key,
    'updatedRevision': _updated?.revision,
    'completedStorageReloads': _reloads,
    if (_active case final journey?) 'knowledge': _knowledgeState(journey),
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
      'settings-open',
      () => _openSettingsWithDraft(journey),
    );
    await journey.checkpoint('memory-created', () => _createMemory(journey));
    await journey.checkpoint('memory-updated', () => _updateMemory(journey));
    await journey.checkpoint(
      'settings-reopened',
      () => _reopenSettings(journey),
    );
    await journey.checkpoint(
      'chat-draft-preserved',
      () => _returnToChat(journey),
    );
    _assertOffline();
  }

  void _assertOffline() {
    requireAgentFeature(
      _provider.requests == 0 &&
          _provider.transport.attempts == 0 &&
          !_provider.closed,
      'The knowledge journey made a model/transport request or closed its provider early.',
    );
  }

  Map<String, Object?> _knowledgeState(AgentFeatureJourney journey) {
    final repository = journey.session.app.agent.knowledgeRepository;
    return {
      'archiveRevision': repository.revision,
      'memoryCount': repository.records
          .where((record) => record.kind == KnowledgeKind.memory)
          .length,
      'localSkillCount': repository.records
          .where((record) => record.kind == KnowledgeKind.skill)
          .length,
      'receiptCount': repository.snapshot.receipts.length,
      'ready': journey.session.app.agent.knowledge.ready,
    };
  }

  Finder _page() => find.byType(AgentSettingsPage);
  Finder _editor() => find.byType(AgentKnowledgeEditor);
  Finder _knowledgePage() => find.byWidgetPredicate(
    (widget) => widget is AgentKnowledgeView && widget.pageEditor,
  );

  Future<Map<String, Object?>> _openSettings(
    AgentFeatureJourney journey,
  ) async {
    await journey.tap(
      journey.key('agent-conversation-menu'),
      'the conversation menu',
    );
    await journey.tap(
      journey.key('agent-settings'),
      'the Agent settings overview action',
    );
    await journey.until(
      () => _page().evaluate().length == 1,
      'the Agent settings overview route',
    );
    final context = journey.tester.element(_page());
    requireAgentFeature(
      ModalRoute.of(context)?.isCurrent == true,
      'Agent settings did not become the current overview route.',
    );
    requireAgentFeature(
      identical(context.read<AgentApplication>(), journey.session.app.agent),
      'Settings replaced the AgentApplication owner.',
    );
    return {
      'openedFrom': 'agent-conversation-menu / agent-settings',
      'overviewRoute': true,
      'pageHierarchy': 'overview / knowledge / record',
      'sameApplication': true,
      'configuration': journey.configurationAt(context),
    };
  }

  Future<void> _backToOverview(AgentFeatureJourney journey) async {
    if (_knowledgePage().evaluate().isNotEmpty) {
      await journey.tap(
        find.byType(BackButton).hitTestable(),
        'the knowledge settings Back button',
      );
      await journey.until(
        () =>
            _knowledgePage().evaluate().isEmpty &&
            _page().hitTestable().evaluate().length == 1,
        'the Agent settings overview after child-page Back',
      );
    }
    requireAgentFeature(
      _page().hitTestable().evaluate().length == 1 &&
          ModalRoute.of(journey.tester.element(_page()))?.isCurrent == true,
      'The child settings page did not return to its overview.',
    );
  }

  Future<Map<String, Object?>> _openKnowledgePage(
    AgentFeatureJourney journey,
    KnowledgeKind kind,
  ) async {
    await _backToOverview(journey);
    final destination = journey.key(
      kind == KnowledgeKind.memory
          ? 'agent-settings-memories'
          : 'agent-settings-skills',
    );
    await journey.reveal(destination, 'the ${kind.name} settings destination');
    await journey.tap(destination, 'the ${kind.name} settings destination');
    await journey.until(
      () => _knowledgePage().hitTestable().evaluate().length == 1,
      'the current ${kind.name} child settings page',
    );
    final add = journey.key('knowledge-add-${kind.name}');
    await journey.reveal(add, 'the ${kind.name} add action');
    final view = journey.tester.widget<AgentKnowledgeView>(
      find.ancestor(of: add, matching: find.byType(AgentKnowledgeView)),
    );
    requireAgentFeature(
      view.kind == kind &&
          view.pageEditor &&
          ModalRoute.of(journey.tester.element(add))?.isCurrent == true &&
          identical(view.service, journey.session.app.agent.knowledge),
      'The current knowledge page did not use the expected shared owner.',
    );
    requireAgentFeature(
      journey.tester.widget<FilledButton>(add).onPressed != null,
      'The knowledge add action is disabled.',
    );
    return {
      'kind': view.kind.name,
      'childPage': true,
      'addAction': 'knowledge-add-${kind.name}',
      'addActionReachable': add.hitTestable().evaluate().length == 1,
      'sameKnowledgeService': true,
      'configuration': journey.configurationAt(journey.tester.element(add)),
    };
  }

  Future<Map<String, Object?>> _openSettingsWithDraft(
    AgentFeatureJourney journey,
  ) async {
    _assertOffline();
    final archive = ConversationArchive.decode(journey.session.chatSource);
    final short = archive.conversations.singleWhere(
      (item) => item.id == agentNativeShortId,
    );
    _initialShortHistoryDigest = AgentNativeSession.historyDigest(
      short.messages,
    );
    await journey.enterDraft(_draft);
    final persisted = ConversationArchive.decode(journey.session.chatSource);
    requireAgentFeature(
      persisted.conversations
              .singleWhere((item) => item.id == agentNativeLongId)
              .draft ==
          _draft,
      'The chat draft was not persisted before opening settings.',
    );
    final settings = await _openSettings(journey);
    final memoryPage = await _openKnowledgePage(journey, KnowledgeKind.memory);
    final knowledge = _knowledgeState(journey);
    requireAgentFeature(
      knowledge['archiveRevision'] == 0 &&
          knowledge['memoryCount'] == 0 &&
          knowledge['localSkillCount'] == 0 &&
          knowledge['receiptCount'] == 0 &&
          knowledge['ready'] == true,
      'The knowledge fixture must start with an empty writable local archive.',
    );
    _assertOffline();
    return {
      ...settings,
      'memoryPage': memoryPage,
      'draftBeforeSettings': _draft,
      'storedDraftBeforeSettings': persisted.conversations
          .singleWhere((item) => item.id == agentNativeLongId)
          .draft,
      'initialShortHistorySha256': _initialShortHistoryDigest,
      'knowledgeBefore': knowledge,
    };
  }

  Future<void> _waitForEditor(
    AgentFeatureJourney journey, {
    KnowledgeRecord? record,
  }) async {
    await journey.until(
      () => _editor().hitTestable().evaluate().length == 1,
      'the actual memory editor child page',
    );
    final editor = journey.tester.widget<AgentKnowledgeEditor>(_editor());
    requireAgentFeature(
      editor.kind == KnowledgeKind.memory &&
          editor.pagePresentation &&
          ModalRoute.of(journey.tester.element(_editor()))?.isCurrent == true &&
          find.byType(AlertDialog).evaluate().isEmpty &&
          identical(editor.service, journey.session.app.agent.knowledge) &&
          editor.record?.key == record?.key &&
          editor.record?.revision == record?.revision,
      'The editor did not open the expected memory record and owner.',
    );
    journey.configurationAt(journey.tester.element(_editor()));
  }

  String _input(AgentFeatureJourney journey, String key) =>
      journey.tester.widget<TextFormField>(journey.key(key)).controller!.text;

  Future<void> _writeEditor(
    AgentFeatureJourney journey,
    String title,
    String body,
  ) async {
    final titleField = journey.key('knowledge-title');
    final bodyField = journey.key('knowledge-body');
    await journey.reveal(titleField, 'the memory title field');
    await journey.tester.enterText(titleField, title);
    await journey.reveal(bodyField, 'the memory body field');
    await journey.tester.enterText(bodyField, body);
    requireAgentFeature(
      _input(journey, 'knowledge-title') == title &&
          _input(journey, 'knowledge-body') == body,
      'The editor did not retain the typed memory fields.',
    );
    final save = journey.key('knowledge-save');
    await journey.reveal(save, 'the real memory Save button');
    await journey.tap(save, 'the real memory Save button');
    await journey.until(
      () => _editor().evaluate().isEmpty,
      'the saved editor to close',
    );
    _assertOffline();
  }

  Future<KnowledgeRecord> _reloadSingle(AgentFeatureJourney journey) async {
    final application = journey.session.app.agent;
    await application.knowledgeRepository.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    await application.knowledge
        .initialize(reload: true)
        .timeout(const Duration(seconds: 20));
    _reloads++;
    await journey.until(
      () => application.knowledge.ready,
      'the writable knowledge storage readback',
    );
    final memories = application.knowledgeRepository.records
        .where((record) => record.kind == KnowledgeKind.memory)
        .toList();
    requireAgentFeature(
      memories.length == 1,
      'Storage readback did not contain exactly one memory.',
    );
    requireAgentFeature(
      application.knowledge.list(KnowledgeKind.memory).single.key ==
          memories.single.key,
      'The service and repository disagree after reload.',
    );
    return memories.single;
  }

  Map<String, Object?> _record(
    AgentFeatureJourney journey,
    KnowledgeRecord record,
  ) => {
    'id': record.id,
    'key': record.key,
    'kind': record.kind.name,
    'title': record.title,
    'body': record.body,
    'bodySha256': record.contentSha256,
    'revision': record.revision,
    'enabled': record.enabled,
    'builtIn': record.builtIn,
    'storageReadback': 'knowledge.initialize(reload: true)',
    'completedStorageReloads': _reloads,
    ..._knowledgeState(journey),
  };

  void _assertRecord(
    KnowledgeRecord record,
    String title,
    String body,
    int revision,
  ) {
    requireAgentFeature(
      record.title == title &&
          record.body == body &&
          record.revision == revision &&
          record.enabled &&
          !record.builtIn &&
          record.kind == KnowledgeKind.memory,
      'Persisted memory identity, content or revision is incorrect.',
    );
  }

  Future<void> _openRecord(
    AgentFeatureJourney journey,
    KnowledgeRecord record,
  ) async {
    final add = journey.key('knowledge-add-memory');
    final view = find.ancestor(
      of: add,
      matching: find.byType(AgentKnowledgeView),
    );
    final scroll = find.descendant(
      of: view,
      matching: find.byType(CustomScrollView),
    );
    final row = journey.key('knowledge-item-${record.key}');
    await journey.reveal(row, 'the persisted memory row', scrollable: scroll);
    final tile = journey.tester.widget<ListTile>(row);
    requireAgentFeature(
      tile.title is Text && (tile.title! as Text).data == record.title,
      'The memory list did not show the persisted title.',
    );
    await journey.tap(row, 'the persisted memory row');
    await _waitForEditor(journey, record: record);
  }

  Future<Map<String, Object?>> _createMemory(
    AgentFeatureJourney journey,
  ) async {
    await journey.tap(
      journey.key('knowledge-add-memory'),
      'the real Add memory action',
    );
    await _waitForEditor(journey);
    requireAgentFeature(
      _input(journey, 'knowledge-title').isEmpty &&
          _input(journey, 'knowledge-body').isEmpty,
      'A new memory editor contains stale fields.',
    );
    await _writeEditor(journey, _createdTitle, _createdBody);
    final record = _created = await _reloadSingle(journey);
    _assertRecord(record, _createdTitle, _createdBody, 1);
    requireAgentFeature(
      _knowledgeState(journey)['receiptCount'] == 1,
      'Creating memory did not retain one actual save receipt.',
    );
    return {'savedWith': 'knowledge-save', 'record': _record(journey, record)};
  }

  Future<Map<String, Object?>> _updateMemory(
    AgentFeatureJourney journey,
  ) async {
    final before = _created!;
    await _openRecord(journey, before);
    requireAgentFeature(
      _input(journey, 'knowledge-title') == _createdTitle &&
          _input(journey, 'knowledge-body') == _createdBody,
      'The edit dialog did not reopen the created values.',
    );
    await _writeEditor(journey, _updatedTitle, _updatedBody);
    final record = _updated = await _reloadSingle(journey);
    _assertRecord(record, _updatedTitle, _updatedBody, before.revision + 1);
    requireAgentFeature(
      record.id == before.id && record.key == before.key,
      'Editing memory replaced its stable identity.',
    );
    requireAgentFeature(
      _knowledgeState(journey)['receiptCount'] == 2,
      'Updating memory did not retain exactly two actual save receipts.',
    );
    return {
      'savedWith': 'knowledge-save',
      'previousKey': before.key,
      'previousRevision': before.revision,
      'record': _record(journey, record),
    };
  }

  Future<void> _backToChat(AgentFeatureJourney journey) async {
    await _backToOverview(journey);
    final back = find.descendant(
      of: _page(),
      matching: find.byType(BackButton),
    );
    await journey.tap(back, 'the Agent settings overview Back button');
    await journey.until(
      () =>
          _page().evaluate().isEmpty && journey.composer.evaluate().length == 1,
      'the original Agent host after settings',
    );
    journey.assertOwner();
    requireAgentFeature(
      journey.field.controller!.text == _draft &&
          journey.session.app.agent.conversations
                  .find(agentNativeLongId)
                  ?.draft ==
              _draft,
      'Returning from settings lost the unsent chat draft.',
    );
  }

  Future<Map<String, Object?>> _reopenSettings(
    AgentFeatureJourney journey,
  ) async {
    await _backToChat(journey);
    final settings = await _openSettings(journey);
    final memoryPage = await _openKnowledgePage(journey, KnowledgeKind.memory);
    final updated = _updated!;
    await _openRecord(journey, updated);
    final editor = journey.tester.widget<AgentKnowledgeEditor>(_editor());
    final reopened = <String, Object?>{
      'recordKey': editor.record!.key,
      'recordRevision': editor.record!.revision,
      'title': _input(journey, 'knowledge-title'),
      'body': _input(journey, 'knowledge-body'),
      'configuration': journey.configurationAt(
        journey.tester.element(_editor()),
      ),
    };
    requireAgentFeature(
      reopened['title'] == _updatedTitle && reopened['body'] == _updatedBody,
      'Reopening settings lost the updated memory values.',
    );
    final l = AppLocalizations.of(journey.tester.element(_editor()));
    await journey.reveal(
      journey.key('knowledge-body'),
      'the reopened memory body',
    );
    await journey.tester.enterText(
      journey.key('knowledge-body'),
      _cancelledBody,
    );
    requireAgentFeature(
      _input(journey, 'knowledge-body') == _cancelledBody,
      'The reopened editor did not retain the unsaved cancellation draft.',
    );
    final cancel = find.descendant(
      of: _editor(),
      matching: find.widgetWithText(TextButton, l.cancel),
    );
    await journey.reveal(cancel, 'the dirty editor Cancel button');
    await journey.tap(cancel, 'the dirty editor Cancel button');
    await journey.until(
      () => find.byType(AlertDialog).hitTestable().evaluate().length == 1,
      'the unsaved memory discard confirmation',
    );
    final discard = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, l.discardChangesAndExit),
    );
    await journey.tap(discard, 'the explicit memory draft discard action');
    await journey.until(
      () => _editor().evaluate().isEmpty,
      'the cancelled editor to close',
    );
    final skillsPage = await _openKnowledgePage(journey, KnowledgeKind.skill);
    final skillCount = journey.session.app.agent.knowledge
        .list(KnowledgeKind.skill)
        .length;
    requireAgentFeature(
      skillCount > 0,
      'The reachable Skills page did not load the bundled catalog.',
    );
    final readback = await _reloadSingle(journey);
    _assertRecord(readback, _updatedTitle, _updatedBody, updated.revision);
    requireAgentFeature(
      readback.key == updated.key &&
          _knowledgeState(journey)['receiptCount'] == 2,
      'Cancelling or visiting Skills changed the saved memory.',
    );
    _assertOffline();
    return {
      ...settings,
      'returnedToOriginalChatBeforeReopen': true,
      'memoryPage': memoryPage,
      'editor': reopened,
      'editorCancelledWithButton': true,
      'unsavedDraftDiscardedWithConfirmation': true,
      'skillsPage': skillsPage,
      'skillCount': skillCount,
      'recordAfterCancel': _record(journey, readback),
    };
  }

  Future<Map<String, Object?>> _returnToChat(
    AgentFeatureJourney journey,
  ) async {
    await _backToChat(journey);
    final session = journey.session;
    await session.app.agent.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    await session.app.session.repository
        .waitForPendingWrites(propagateErrors: true)
        .timeout(const Duration(seconds: 20));
    final saved = ConversationArchive.decode(session.chatSource);
    final long = saved.conversations.singleWhere(
      (item) => item.id == agentNativeLongId,
    );
    final short = saved.conversations.singleWhere(
      (item) => item.id == agentNativeShortId,
    );
    final longDigest = AgentNativeSession.historyDigest(long.messages);
    final shortDigest = AgentNativeSession.historyDigest(short.messages);
    requireAgentFeature(
      saved.conversations.length == 2 &&
          saved.selectedId == agentNativeLongId &&
          long.draft == _draft &&
          journey.field.controller!.text == _draft &&
          short.draft == agentNativeShortDraft,
      'The persisted archive did not preserve both independent chat drafts and selection.',
    );
    requireAgentFeature(
      long.messages.length == agentNativeMessageCount &&
          short.messages.length == 2 &&
          longDigest == session.originalHistoryDigest &&
          shortDigest == _initialShortHistoryDigest,
      'Knowledge settings changed or appended conversation messages.',
    );
    requireAgentFeature(
      !session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .isActive &&
          !session.app.agent.runtime.state.value
              .runFor(agentNativeShortId)
              .isActive,
      'A model run became active during knowledge settings work.',
    );
    requireAgentFeature(
      session.mainSource == journey.mainAtEntry,
      'Knowledge settings changed the main workspace snapshot.',
    );
    _assertOffline();
    return {
      'configuration': journey.assertOwner(),
      'sameApplicationAndRepository': true,
      'selectedId': saved.selectedId,
      'conversationCount': saved.conversations.length,
      'visibleDraft': journey.field.controller!.text,
      'savedLongDraft': long.draft,
      'savedShortDraft': short.draft,
      'savedLongMessageCount': long.messages.length,
      'savedShortMessageCount': short.messages.length,
      'savedLongHistorySha256': longDigest,
      'savedShortHistorySha256': shortDigest,
      'runActive': false,
      'mainSnapshotUnchangedSinceEntry': true,
      'mainSha256': agentNativeDigest(session.mainSource),
      'knowledge': _knowledgeState(journey),
      'provider': providerReport(),
      'storage': session.storageReport(),
    };
  }
}
