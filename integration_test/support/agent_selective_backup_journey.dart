import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/backup/selective_backup_models.dart';
import 'package:sked/controllers/app_backup_controller.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/agent_page.dart';
import 'package:sked/screens/selective_backup_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/sked_confirmation_dialog.dart';

import 'agent_feature_journey.dart';
import 'agent_native_session.dart';

const _calendarId = 'native-calendar';
const _calendarKey = BackupObjectKey(BackupObjectKind.calendar, _calendarId);
const _restoredName = 'Selected restored native calendar';
const _restoredEvent = 'Selected restored synthetic event';
const _unselectedName = 'Unselected archive timetable';
const _extraCalendarId = 'unselected-archive-calendar';
const _extraCalendarName = 'Unselected archive-only calendar';
const _filename = 'native-selective-backup.json';
const _draft = 'Unsent draft kept while restoring one calendar';

String _jsonDigest(Object? value) => agentNativeDigest(jsonEncode(value));

class _BackupTransport extends http.BaseClient {
  var attempts = 0;
  var closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    attempts++;
    throw StateError(
      'The selective backup journey must not use provider HTTP.',
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _BackupProvider extends ProviderClient {
  _BackupProvider._(this.transport) : super(client: transport);
  factory _BackupProvider() => _BackupProvider._(_BackupTransport());
  final _BackupTransport transport;
  var requests = 0;
  var closeCount = 0;
  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests++;
    return Stream.error(
      StateError('Selecting or restoring a backup requested a model response.'),
    );
  }

  Map<String, Object?> toJson() => {
    'type': 'selective-backup-offline',
    'requests': requests,
    'transportAttempts': transport.attempts,
    'transportClosed': transport.closed,
    'closed': closeCount != 0,
    'closeCount': closeCount,
  };
  @override
  void close() {
    if (closeCount != 0) return;
    super.close();
    transport.close();
    closeCount++;
  }
}

class _BackupPicker extends FileSelectorPlatform {
  Uint8List? bytes;
  String? sha256;
  var byteLength = 0;
  var calls = 0;
  List<String> extensions = const [];

  void configure(String source) {
    requireAgentFeature(
      bytes == null && calls == 0,
      'The backup fixture was configured twice.',
    );
    bytes = Uint8List.fromList(utf8.encode(source));
    byteLength = bytes!.length;
    sha256 = agentNativeDigest(source);
  }

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls++;
    final selected = bytes;
    extensions = {
      for (final group in acceptedTypeGroups ?? const <XTypeGroup>[])
        ...?group.extensions,
    }.toList()..sort();
    requireAgentFeature(
      calls == 1 &&
          selected != null &&
          extensions.length == 2 &&
          extensions[0] == 'json' &&
          extensions[1] == 'zip',
      'The real backup-file action did not make its single expected picker request.',
    );
    return XFile.fromData(
      selected!,
      path: 'memory://selective-backup/$_filename',
      name: _filename,
      mimeType: 'application/json',
    );
  }

  Map<String, Object?> toJson() => {
    'calls': calls,
    'filename': _filename,
    'byteLength': byteLength,
    'sha256': sha256,
    'acceptedExtensions': extensions,
    'source': 'synthetic encodeAppBackup JSON through FileSelectorPlatform',
  };
}

/// One real settings selection, cancelled preview and confirmed selective
/// restore. Model/file-dialog boundaries are owned; restore services are real.
class AgentSelectiveBackupJourney implements AgentNativeFeature {
  AgentSelectiveBackupJourney._(
    this._previousPicker,
    this._picker,
    this._provider,
  ) {
    FileSelectorPlatform.instance = _picker;
  }
  factory AgentSelectiveBackupJourney() => AgentSelectiveBackupJourney._(
    FileSelectorPlatform.instance,
    _BackupPicker(),
    _BackupProvider(),
  );

  final FileSelectorPlatform _previousPicker;
  final _BackupPicker _picker;
  final _BackupProvider _provider;
  AgentFeatureJourney? _active;
  GeneralSchedule? _expected;
  Map<String, Object?>? _initial;
  String? _incomingStudentDigest;
  var _previews = 0;

  @override
  String get name => 'selective-backup';
  @override
  ProviderClient get provider => _provider;
  @override
  Map<String, Object?> providerReport() => _provider.toJson();
  @override
  Map<String, Object?> diagnostics() => {
    'picker': _picker.toJson(),
    'previewCount': _previews,
    'pickerOwnerRetained': identical(FileSelectorPlatform.instance, _picker),
    if (_active case final journey?) ...{
      'backupBusy': journey.session.app.backups.selective.isBusy,
      'recoveryPending': journey.session.app.backups.selective.recoveryPending,
      'mainWritable': journey.session.app.lifecycle.canWrite,
      'mainSha256': agentNativeDigest(journey.session.mainSource),
    },
  };
  @override
  Future<Map<String, Object?>> releaseBoundaries() async {
    final owned = identical(FileSelectorPlatform.instance, _picker);
    if (owned) {
      FileSelectorPlatform.instance = _previousPicker;
    }
    final restored =
        owned && identical(FileSelectorPlatform.instance, _previousPicker);
    _picker.bytes = null;
    return {
      'status': restored ? 'complete' : 'failed',
      'owner': name,
      'installed': ['FileSelectorPlatform.instance'],
      'restored': [if (restored) 'FileSelectorPlatform.instance'],
      'pickerRestored': restored,
      'sourceBytesReleased': _picker.bytes == null,
      'picker': _picker.toJson(),
      'previewCount': _previews,
      'sourceFileScope':
          'in-memory XFile; no source file or temporary directory created',
      if (!owned)
        'error': 'The backup journey lost ownership of its picker replacement.',
    };
  }

  @override
  Future<void> exercise(AgentFeatureJourney journey) async {
    _active = journey;
    await journey.checkpoint(
      'backup-settings-open',
      () => _openSettings(journey),
    );
    await journey.checkpoint(
      'backup-file-selected',
      () => _selectFile(journey),
    );
    await journey.checkpoint(
      'backup-preview-cancelled',
      () => _cancelPreview(journey),
    );
    await journey.checkpoint(
      'backup-selection-restored',
      () => _restoreSelection(journey),
    );
  }

  void _assertOffline() => requireAgentFeature(
    _provider.requests == 0 &&
        _provider.transport.attempts == 0 &&
        _provider.closeCount == 0,
    'The selective backup flow contacted a model or closed its provider early.',
  );

  Finder get _settings => find.byWidgetPredicate(
    (widget) => widget is SettingsPage && widget.initialDestination == null,
  );
  Finder get _page => find.byType(SelectiveBackupPage);
  Finder get _dialog => find.byType(SkedConfirmationDialog);

  Future<Map<String, Object?>> _snapshot(AgentFeatureJourney journey) async {
    final session = journey.session;
    final app = session.app;
    await app.session.repository
        .waitForPendingWrites(propagateErrors: true)
        .timeout(const Duration(seconds: 20));
    await app.agent.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    final data = AppData.decodeStorageSnapshot(session.mainSource);
    requireAgentFeature(
      data.encode() == app.session.committedData.encode(),
      'The live main owner disagrees with its saved snapshot.',
    );
    final archive = ConversationArchive.decode(session.chatSource);
    final chatContent = Map<String, Object?>.from(
      jsonDecode(archive.encode()) as Map,
    )..remove('revision');
    final long = archive.conversations.singleWhere(
      (item) => item.id == agentNativeLongId,
    );
    final short = archive.conversations.singleWhere(
      (item) => item.id == agentNativeShortId,
    );
    final selected = data.generalMode.schedules.singleWhere(
      (item) => item.id == _calendarId,
    );
    return {
      'mainSha256': agentNativeDigest(session.mainSource),
      'mainWrites': session.storageReport()['mainWrites'],
      'generation': data.applicationLedger!.generation,
      'selectedCalendar': selected.toJson(),
      'selectedCalendarSha256': _jsonDigest(selected.toJson()),
      'calendarIds': data.generalMode.schedules.map((item) => item.id).toList(),
      'studentSha256': _jsonDigest(data.studentMode.toJson()),
      'agentSettingsSha256': _jsonDigest(data.agentSettings.toJson()),
      'chatSha256': agentNativeDigest(session.chatSource),
      'chatRevision': archive.revision,
      'chatContentSha256': _jsonDigest(chatContent),
      'conversationCount': archive.conversations.length,
      'selectedConversationId': archive.selectedId,
      'longHistorySha256': AgentNativeSession.historyDigest(long.messages),
      'shortHistorySha256': AgentNativeSession.historyDigest(short.messages),
      'longMessageCount': long.messages.length,
      'shortMessageCount': short.messages.length,
      'longDraft': long.draft,
      'shortDraft': short.draft,
      'journalEmpty':
          await app.backups.selective.journal.read().timeout(
            const Duration(seconds: 20),
          ) ==
          null,
      'recoveryPending': app.backups.selective.recoveryPending,
      'backupBusy': app.backups.selective.isBusy,
      'mainWritable': app.lifecycle.canWrite,
      'chatWritable': app.agent.conversations.canWrite,
      'storageReadback': 'AppData.decodeStorageSnapshot / ConversationArchive.decode / selective journal.read',
    };
  }

  Map<String, Object?> _settingsOwner(AgentFeatureJourney journey) {
    final context = journey.tester.element(_settings);
    requireAgentFeature(
      identical(context.read<AppSession>(), journey.session.app.session) &&
          identical(
            context.read<AppBackupController>(),
            journey.session.app.backups,
          ),
      'The actual settings route replaced the main session or backup owner.',
    );
    return journey.configurationAt(context);
  }

  Future<Map<String, Object?>> _openSettings(
    AgentFeatureJourney journey,
  ) async {
    await journey.enterDraft(_draft);
    _initial = await _snapshot(journey);
    final original = AppData.decodeStorageSnapshot(journey.session.mainSource);
    requireAgentFeature(
      original.generalMode.schedules.length == 1 &&
          original.studentMode.timetables.length == 1,
      'The selective backup fixture does not have its expected independent objects.',
    );
    final calendar = original.generalMode.schedules.single;
    _expected = calendar.copyWith(
      name: _restoredName,
      events: [calendar.events.single.copyWith(title: _restoredEvent)],
    );
    final table = original.studentMode.timetables.single;
    final incoming = original.copyWith(
      generalMode: original.generalMode.copyWith(
        schedules: [
          _expected!,
          const GeneralSchedule(
            id: _extraCalendarId,
            name: _extraCalendarName,
            events: [],
          ),
        ],
      ),
      studentMode: original.studentMode.copyWith(
        timetables: [
          table.copyWith(config: table.config.copyWith(name: _unselectedName)),
        ],
      ),
    );
    _incomingStudentDigest = _jsonDigest(incoming.studentMode.toJson());
    requireAgentFeature(
      _incomingStudentDigest != _initial!['studentSha256'],
      'The unselected archive fixture must differ from the local timetable.',
    );
    _picker.configure(encodeAppBackup(incoming, const []));
    final back = find.descendant(
      of: find.byType(AgentPage),
      matching: find.byType(BackButton),
    );
    await journey.tap(back, 'the actual Agent page Back button');
    await journey.until(
      () => find.byType(AgentPage).evaluate().isEmpty,
      'the general home after leaving Agent',
    );
    const settingsControls = [
      'workspace-resource-settings',
      'general-settings-button',
      'general-desktop-toolbar-more',
      'general-toolbar-more-button',
    ];
    await journey.until(
      () => settingsControls.any(
        (id) => journey.key(id).hitTestable().evaluate().length == 1,
      ),
      'the visible home Settings control',
    );
    final settingsControl = settingsControls.firstWhere(
      (id) => journey.key(id).hitTestable().evaluate().length == 1,
    );
    final settingsEntry = settingsControl == 'workspace-resource-settings'
        ? settingsControl
        : 'general-settings-button';
    final settings = journey.key(settingsEntry);
    if (settingsControl != settingsEntry) {
      await journey.tap(
        journey.key(settingsControl),
        'the visible home More menu for settings',
      );
      await journey.reveal(settings, 'the actual home Settings menu item');
    }
    await journey.tap(settings, 'the actual general workspace Settings entry');
    await journey.until(
      () => _settings.evaluate().length == 1,
      'the actual application Settings route',
    );
    _assertOffline();
    return {
      'settingsEntry': settingsEntry,
      'settingsControl': settingsControl == settingsEntry
          ? settingsControl
          : '$settingsControl / $settingsEntry',
      'sourceHost': 'AgentPage / BackButton',
      'sameMainSessionAndBackupOwner': true,
      'configuration': _settingsOwner(journey),
      'before': _initial,
      'expectedCalendar': _expected!.toJson(),
      'expectedCalendarSha256': _jsonDigest(_expected!.toJson()),
      'incomingStudentSha256': _incomingStudentDigest,
      'unselectedIncomingTimetableName': _unselectedName,
      'unselectedIncomingCalendarId': _extraCalendarId,
      'source': _picker.toJson(),
    };
  }

  Future<void> _reveal(
    AgentFeatureJourney journey,
    Finder target,
    String description, {
    bool towardStart = false,
  }) async {
    if (target.evaluate().isEmpty) {
      final scrollable = find
          .descendant(
            of: find.descendant(
              of: _page,
              matching: find.byType(CustomScrollView),
            ),
            matching: find.byType(Scrollable),
          )
          .first;
      await journey.tester
          .scrollUntilVisible(
            target,
            towardStart ? -200 : 200,
            scrollable: scrollable,
            maxScrolls: 20,
          )
          .timeout(const Duration(seconds: 20));
    }
    await journey.reveal(target, description);
  }

  Finder _search() =>
      find.descendant(of: _page, matching: find.byType(TextField));

  Future<Map<String, Object?>> _selection(
    AgentFeatureJourney journey, {
    bool towardStart = false,
  }) async {
    final row = journey.key('backup-object-$_calendarKey');
    await _reveal(
      journey,
      row,
      'the selected calendar row',
      towardStart: towardStart,
    );
    final checkbox = journey.tester.widget<CheckboxListTile>(row);
    requireAgentFeature(
      checkbox.value == true && checkbox.onChanged != null,
      'The actual calendar selection is absent or blocked.',
    );
    final l = AppLocalizations.of(journey.tester.element(_page));
    final count = find.descendant(
      of: _page,
      matching: find.text(l.selectiveBackupSelectedCount(1)),
    );
    await _reveal(
      journey,
      count,
      'the one-object selection count',
      towardStart: true,
    );
    final countText = journey.tester.widget<Text>(count).data;
    await _reveal(
      journey,
      _search(),
      'the retained object filter',
      towardStart: true,
    );
    final input = journey.tester.widget<EditableText>(
      find.descendant(of: _search(), matching: find.byType(EditableText)),
    );
    requireAgentFeature(
      input.controller.text == _restoredName,
      'The object filter was lost during review.',
    );
    return {
      'selectedKey': _calendarKey.toString(),
      'checked': checkbox.value,
      'selectedCountText': countText,
      'filter': input.controller.text,
    };
  }

  Future<Map<String, Object?>> _selectFile(AgentFeatureJourney journey) async {
    final backup = journey.key('settings-app-backup');
    if (backup.evaluate().isEmpty) {
      final scroll = find.descendant(
        of: find.byKey(
          const PageStorageKey<String>('settings-overview-scroll'),
        ),
        matching: find.byType(Scrollable),
      );
      await journey.tester
          .scrollUntilVisible(backup, 250, scrollable: scroll, maxScrolls: 20)
          .timeout(const Duration(seconds: 20));
    }
    await journey.reveal(backup, 'the Settings Backup and restore entry');
    await journey.tap(backup, 'the Settings Backup and restore entry');
    final label = AppLocalizations.of(journey.tester.element(_settings))
        .restoreBackupFileTitle;
    await journey.reveal(find.text(label), 'the real Restore from file action');
    await journey.tap(find.text(label), 'the real Restore from file action');
    await journey.until(
      () => _page.evaluate().length == 1 && _picker.calls == 1,
      'the file-backed object selector',
    );
    final page = journey.tester.widget<SelectiveBackupPage>(_page);
    final source = page.initialSource;
    requireAgentFeature(
      identical(page.service, journey.session.app.backups.selective) &&
          source != null &&
          page.closeAfterRestore &&
          source.byKey.containsKey(_calendarKey) &&
          source.byKey.containsKey(
            const BackupObjectKey(BackupObjectKind.timetable, 'native-table'),
          ) &&
          source.byKey.containsKey(
            const BackupObjectKey(BackupObjectKind.calendar, _extraCalendarId),
          ),
      'Settings did not pass the decoded selected file to its actual selective restore owner.',
    );
    final l = AppLocalizations.of(journey.tester.element(_page));
    final clear = find.descendant(
      of: _page,
      matching: find.text(l.selectiveBackupClearSelection),
    );
    await _reveal(journey, clear, 'the actual Clear selection button');
    await journey.tap(clear, 'the actual Clear selection button');
    await _reveal(
      journey,
      _search(),
      'the source object filter',
      towardStart: true,
    );
    await journey.tester.enterText(_search(), _restoredName);
    final row = journey.key('backup-object-$_calendarKey');
    await _reveal(journey, row, 'the single filtered calendar row');
    requireAgentFeature(
      journey.tester.widget<CheckboxListTile>(row).value == false,
      'Clear selection did not remove the imported default selection.',
    );
    await journey.tap(row, 'the single calendar checkbox');
    final selected = await _selection(journey);
    _assertOffline();
    return {
      'entry': 'settings-app-backup / Restore from file',
      'sameSelectiveService': true,
      'closeAfterRestore': page.closeAfterRestore,
      'sourceBundleFingerprint': source!.fingerprint,
      'sourceObjectCount': source.records.length,
      'source': _picker.toJson(),
      'selection': selected,
      'configuration': journey.configurationAt(journey.tester.element(_page)),
      'provider': providerReport(),
    };
  }

  Future<Map<String, Object?>> _openPreview(AgentFeatureJourney journey) async {
    final primary = journey.key('selective-backup-primary');
    await _reveal(
      journey,
      primary,
      'the selected-object Review restore button',
    );
    requireAgentFeature(
      journey.tester.widget<FilledButton>(primary).onPressed != null,
      'The selected-object review button is disabled.',
    );
    await journey.tap(primary, 'the selected-object Review restore button');
    await journey.until(
      () => _dialog.evaluate().length == 1,
      'the real selective restore confirmation',
    );
    final l = AppLocalizations.of(journey.tester.element(_dialog));
    final counts = find.descendant(
      of: _dialog,
      matching: find.text(l.selectiveBackupRestoreCounts(0, 1)),
    );
    final replacement = find.descendant(
      of: _dialog,
      matching: find.text('${l.selectiveBackupReplace}: $_restoredName'),
    );
    await journey.reveal(
      counts,
      'the actual zero-add, one-replacement preview count',
    );
    final countsText = journey.tester.widget<Text>(counts).data;
    await journey.reveal(
      replacement,
      'the actual selected calendar replacement preview',
    );
    final progressCount = find
        .descendant(of: _dialog, matching: find.byType(LinearProgressIndicator))
        .evaluate()
        .length;
    final restoreBusy = journey.session.app.backups.selective.isBusy;
    requireAgentFeature(
      progressCount == 0 && !restoreBusy,
      'The waiting confirmation incorrectly presents an active restore.',
    );
    _previews++;
    return {
      'previewCount': _previews,
      'countsText': countsText,
      'replacementText': journey.tester.widget<Text>(replacement).data,
      'dialogProgressIndicatorCount': progressCount,
      'restoreActiveDuringConfirmation': restoreBusy,
      'configuration': journey.configurationAt(journey.tester.element(_dialog)),
    };
  }

  Future<Map<String, Object?>> _cancelPreview(
    AgentFeatureJourney journey,
  ) async {
    final before = await _snapshot(journey);
    final preview = await _openPreview(journey);
    final cancelText = AppLocalizations.of(journey.tester.element(_dialog))
        .cancel;
    final cancel = find.descendant(
      of: _dialog,
      matching: find.widgetWithText(TextButton, cancelText),
    );
    await journey.reveal(cancel, 'the real restore preview Cancel button');
    await journey.tap(cancel, 'the real restore preview Cancel button');
    await journey.until(
      () => _dialog.evaluate().isEmpty,
      'the cancelled restore confirmation',
    );
    final selected = await _selection(journey, towardStart: true);
    final after = await _snapshot(journey);
    requireAgentFeature(
      before['mainSha256'] == after['mainSha256'] &&
          before['mainWrites'] == after['mainWrites'] &&
          before['chatSha256'] == after['chatSha256'] &&
          before['generation'] == after['generation'] &&
          after['journalEmpty'] == true &&
          after['recoveryPending'] == false &&
          after['mainWritable'] == true,
      'Cancelling the actual preview wrote data, changed chat or left restore recovery pending.',
    );
    _assertOffline();
    return {
      'preview': preview,
      'cancelledWithButton': true,
      'before': before,
      'after': after,
      'selectionAfterCancel': selected,
      'provider': providerReport(),
    };
  }

  Future<Map<String, Object?>> _restoreSelection(
    AgentFeatureJourney journey,
  ) async {
    final preview = await _openPreview(journey);
    final restoreText = AppLocalizations.of(journey.tester.element(_dialog))
        .selectiveBackupRestore;
    final restore = find.descendant(
      of: _dialog,
      matching: find.widgetWithText(FilledButton, restoreText),
    );
    await journey.reveal(
      restore,
      'the real selected-data Restore confirmation',
    );
    await journey.tap(restore, 'the real selected-data Restore confirmation');
    final service = journey.session.app.backups.selective;
    await journey.until(
      () =>
          _page.evaluate().isEmpty &&
          _dialog.evaluate().isEmpty &&
          _settings.evaluate().length == 1 &&
          !service.isBusy &&
          !service.recoveryPending,
      'the completed application-owned restore and returned Settings route',
    );
    final after = await _snapshot(journey);
    final before = _initial!;
    requireAgentFeature(
      after['selectedCalendarSha256'] == _jsonDigest(_expected!.toJson()) &&
          after['selectedCalendarSha256'] != before['selectedCalendarSha256'] &&
          after['mainSha256'] != before['mainSha256'] &&
          (after['mainWrites'] as int) > (before['mainWrites'] as int) &&
          after['generation'] != before['generation'],
      'The selected calendar did not persist the actual confirmed replacement.',
    );
    requireAgentFeature(
      after['studentSha256'] == before['studentSha256'] &&
          after['studentSha256'] != _incomingStudentDigest &&
          (after['calendarIds'] as List).length == 1 &&
          (after['calendarIds'] as List).single == _calendarId &&
          after['agentSettingsSha256'] == before['agentSettingsSha256'] &&
          after['chatContentSha256'] == before['chatContentSha256'] &&
          after['conversationCount'] == 2 &&
          after['selectedConversationId'] == agentNativeLongId &&
          after['longMessageCount'] == agentNativeMessageCount &&
          after['shortMessageCount'] == 2 &&
          after['longHistorySha256'] == before['longHistorySha256'] &&
          after['shortHistorySha256'] == before['shortHistorySha256'] &&
          after['longDraft'] == _draft &&
          after['shortDraft'] == agentNativeShortDraft,
      'Selective restore changed an unselected object, conversation or Agent configuration.',
    );
    requireAgentFeature(
      after['journalEmpty'] == true &&
          after['recoveryPending'] == false &&
          after['backupBusy'] == false &&
          after['mainWritable'] == true &&
          after['chatWritable'] == true,
      'The confirmed restore did not finish its actual journal and owner lifecycle.',
    );
    _assertOffline();
    return {
      'preview': preview,
      'confirmedWithButton': true,
      'returnedToSettings': true,
      'sameMainSessionAndBackupOwner': true,
      'configuration': _settingsOwner(journey),
      'after': after,
      'source': _picker.toJson(),
      'provider': providerReport(),
      'scope': 'one selected calendar restored; unselected timetable, extra calendar, chat and Agent settings preserved',
    };
  }
}
