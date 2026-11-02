import 'dart:convert';

import 'package:crypto/crypto.dart';

const agentSelectiveBackupCheckpoints = [
  'environment',
  'runtime-loaded',
  'product-entry',
  'backup-settings-open',
  'backup-file-selected',
  'backup-preview-cancelled',
  'backup-selection-restored',
  'cleanup',
];

const agentSelectiveBackupRelevantSources = [
  'integration_test/support/agent_selective_backup_journey.dart',
  'test_driver/support/agent_selective_backup_journey_assessor.dart',
  'lib/screens/general_schedule_home_screen.dart',
  'lib/widgets/workspace_navigation.dart',
  'lib/screens/settings_page.dart',
  'lib/screens/selective_backup_page.dart',
  'lib/widgets/adaptive_settings_scaffold.dart',
  'lib/widgets/sked_confirmation_dialog.dart',
  'lib/controllers/app_backup_controller.dart',
  'lib/controllers/app_session.dart',
  'lib/backup/selective_backup_service.dart',
  'lib/backup/selective_backup_models.dart',
  'lib/backup/selective_backup_app_data.dart',
  'lib/backup/selective_backup_codec.dart',
  'lib/backup/selective_backup_planner.dart',
  'lib/backup/selective_restore_coordinator.dart',
  'lib/backup/selective_restore_journal.dart',
  'lib/models/app_data.dart',
  'lib/models/app_backup.dart',
  'lib/models/general_schedule.dart',
  'lib/models/general_event.dart',
];

const _calendarId = 'native-calendar';
const _restoredName = 'Selected restored native calendar';
const _restoredEvent = 'Selected restored synthetic event';
const _draft = 'Unsent draft kept while restoring one calendar';

void _require(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

Map<String, Object?> _map(Object? value, String description) {
  _require(value is Map, '$description is missing or invalid.');
  return Map<String, Object?>.from(value as Map);
}

String _jsonDigest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

void _digest(Object? value, String description) {
  _require(
    value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
    '$description is not a SHA-256 digest.',
  );
}

void _single(Object? value, String expected, String description) {
  _require(
    value is List && value.length == 1 && value.single == expected,
    '$description does not contain exactly the expected identity.',
  );
}

void _configuration(Object? value, bool accessible) {
  final config = _map(value, 'Selective backup surface configuration');
  final scale = config['textScale'];
  _require(
    config['brightness'] == (accessible ? 'dark' : 'light') &&
        scale is num &&
        scale.isFinite &&
        (scale - (accessible ? 2 : 1)).abs() < 0.001 &&
        config['reduceMotion'] == accessible &&
        config['disableAnimations'] == false &&
        config['mediaQueryDisableAnimations'] == false,
    'The backup surface did not receive the requested framework configuration.',
  );
}

void _provider(Object? value, {required bool closed}) {
  final provider = _map(value, 'Selective backup provider');
  _require(
    provider['type'] == 'selective-backup-offline' &&
        provider['requests'] == 0 &&
        provider['transportAttempts'] == 0 &&
        provider['closed'] == closed &&
        provider['transportClosed'] == closed &&
        provider['closeCount'] == (closed ? 1 : 0),
    'The backup journey requested a model, used HTTP or failed provider cleanup.',
  );
}

Map<String, Object?> _picker(
  Object? value, {
  required int calls,
  Map<String, Object?>? original,
}) {
  final picker = _map(value, 'Owned backup source picker');
  final length = picker['byteLength'];
  _require(
    picker['calls'] == calls &&
        picker['filename'] == 'native-selective-backup.json' &&
        picker['source'] ==
            'synthetic encodeAppBackup JSON through FileSelectorPlatform' &&
        length is int &&
        length > 0 &&
        length <= 20000000 &&
        jsonEncode(picker['acceptedExtensions']) ==
            jsonEncode(calls == 0 ? <String>[] : ['json', 'zip']),
    'The actual restore-file action did not select its single owned legacy JSON.',
  );
  _digest(picker['sha256'], 'Selected source');
  if (original != null) {
    for (final key in ['filename', 'source', 'byteLength', 'sha256']) {
      _require(picker[key] == original[key], 'The backup source $key changed.');
    }
  }
  return picker;
}

void _selection(Object? value) {
  final selection = _map(value, 'Actual source object selection');
  _require(
    selection['selectedKey'] == 'calendar:native-calendar' &&
        selection['checked'] == true &&
        selection['selectedCountText'] == '1 selected' &&
        selection['filter'] == _restoredName,
    'The actual checkbox, one-object count or retained search filter is incorrect.',
  );
}

void _preview(Object? value, int count, bool accessible) {
  final preview = _map(value, 'Actual restore confirmation');
  _require(
    preview['previewCount'] == count &&
        preview['countsText'] == 'Add 0; replace 1' &&
        preview['replacementText'] == 'Replace: $_restoredName' &&
        preview['dialogProgressIndicatorCount'] == 0 &&
        preview['restoreActiveDuringConfirmation'] == false,
    'The confirmation did not show exactly one waiting calendar replacement.',
  );
  _configuration(preview['configuration'], accessible);
}

Map<String, Object?> _snapshot(Object? value, Map<String, Object?> fixture) {
  final state = _map(value, 'Actual backup owner storage readback');
  for (final key in [
    'mainSha256',
    'selectedCalendarSha256',
    'studentSha256',
    'agentSettingsSha256',
    'chatSha256',
    'chatContentSha256',
    'longHistorySha256',
    'shortHistorySha256',
  ]) {
    _digest(state[key], 'Backup state $key');
  }
  final calendar = _map(state['selectedCalendar'], 'Stored calendar');
  final events = calendar['events'];
  _require(
    calendar['id'] == _calendarId &&
        state['selectedCalendarSha256'] == _jsonDigest(calendar) &&
        events is List &&
        events.length == 1 &&
        _map(events.single, 'Stored event')['id'] == 'native-event',
    'The stored selected calendar identity or complete content digest is invalid.',
  );
  _single(
    state['calendarIds'],
    _calendarId,
    'Actual stored calendar inventory',
  );
  _require(
    state['mainWrites'] is int &&
        (state['mainWrites'] as int) >= 0 &&
        state['chatRevision'] is int &&
        (state['chatRevision'] as int) >= 0 &&
        state['generation'] is String &&
        (state['generation'] as String).isNotEmpty &&
        state['conversationCount'] == 2 &&
        state['selectedConversationId'] == 'native-long-history' &&
        state['longMessageCount'] == 512 &&
        state['shortMessageCount'] == 2 &&
        state['longHistorySha256'] == fixture['longHistorySha256'] &&
        state['longDraft'] == _draft &&
        state['shortDraft'] == 'Independent short conversation draft' &&
        state['journalEmpty'] == true &&
        state['recoveryPending'] == false &&
        state['backupBusy'] == false &&
        state['mainWritable'] == true &&
        state['chatWritable'] == true &&
        state['storageReadback'] == 'AppData.decodeStorageSnapshot / ConversationArchive.decode / selective journal.read',
    'The actual backup owners lost original chat content, writable state or completed journal cleanup.',
  );
  return state;
}

void _preserved(Map<String, Object?> before, Map<String, Object?> after) {
  for (final key in [
    'studentSha256',
    'agentSettingsSha256',
    'chatContentSha256',
    'shortHistorySha256',
  ]) {
    _require(
      before[key] == after[key],
      'Selective restore changed unselected content: $key.',
    );
  }
}

void _cleanup(Object? value, Map<String, Object?> source) {
  final cleanup = _map(value, 'Selective backup cleanup');
  _provider(cleanup['provider'], closed: true);
  final boundary = _map(
    cleanup['featureBoundaries'],
    'Backup boundary cleanup',
  );
  _require(
    boundary['status'] == 'complete' &&
        boundary['owner'] == 'selective-backup' &&
        boundary['pickerRestored'] == true &&
        boundary['sourceBytesReleased'] == true &&
        boundary['previewCount'] == 2 &&
        boundary['sourceFileScope'] ==
            'in-memory XFile; no source file or temporary directory created',
    'The backup picker and owned source bytes did not finish cleanup.',
  );
  _single(
    boundary['installed'],
    'FileSelectorPlatform.instance',
    'Installed picker',
  );
  _single(
    boundary['restored'],
    'FileSelectorPlatform.instance',
    'Restored picker',
  );
  _picker(boundary['picker'], calls: 1, original: source);
}

/// The central driver first validates native/source/configuration/owner gates.
/// This assessor then checks the actual selection, both confirmations and the
/// stored result, including negative controls that were present in the source.
void validateAgentSelectiveBackupJourney(Map<String, Object?> report) {
  _require(
    report['feature'] == 'selective-backup',
    'Wrong backup feature report.',
  );
  final accessible =
      _map(report['configuration'], 'Backup configuration')['name'] ==
      'accessible';
  final fixture = _map(report['fixture'], 'Synthetic backup fixture');
  final steps = report['checkpoints'];
  _require(
    steps is List && steps.length == agentSelectiveBackupCheckpoints.length,
    'The selective backup checkpoints are incomplete.',
  );
  final observations = <String, Map<String, Object?>>{};
  for (var index = 0; index < agentSelectiveBackupCheckpoints.length; index++) {
    final step = _map((steps as List)[index], 'Backup checkpoint');
    final name = agentSelectiveBackupCheckpoints[index];
    _require(
      step['name'] == name && step['status'] == 'complete',
      'Backup checkpoint $name did not complete in order.',
    );
    observations[name] = _map(step['observations'], '$name observations');
  }
  _provider(observations['runtime-loaded']!['provider'], closed: false);
  final entry = observations['product-entry']!;
  _provider(entry['provider'], closed: false);
  final settings = observations['backup-settings-open']!;
  final platform = _map(
    report['environment'],
    'Native backup environment',
  )['platform'];
  final settingsEntry = settings['settingsEntry'];
  final settingsControl = settings['settingsControl'];
  final validSettingsRoute =
      (platform == 'windows' &&
          settingsEntry == 'workspace-resource-settings' &&
          settingsControl == settingsEntry) ||
      (settingsEntry == 'general-settings-button' &&
          const [
            'general-settings-button',
            'general-desktop-toolbar-more / general-settings-button',
            'general-toolbar-more-button / general-settings-button',
          ].contains(settingsControl));
  _require(
    validSettingsRoute &&
        settings['sourceHost'] ==
            (platform == 'windows'
                ? 'AgentAssistantPane'
                : 'AgentPage / BackButton') &&
        settings['sameMainSessionAndBackupOwner'] == true,
    'The backup flow did not enter the real global Settings route from Agent.',
  );
  _configuration(settings['configuration'], accessible);
  final before = _snapshot(settings['before'], fixture);
  _require(
    before['mainSha256'] == entry['mainSha256'],
    'Saving the unsent draft changed the workspace before the backup journey.',
  );
  final expected = _map(
    jsonDecode(jsonEncode(before['selectedCalendar'])),
    'Expected calendar replacement',
  );
  expected['name'] = _restoredName;
  final events = expected['events'] as List;
  events[0] = {
    ..._map(events.single, 'Original event'),
    'title': _restoredEvent,
  };
  _require(
    _jsonDigest(settings['expectedCalendar']) == _jsonDigest(expected) &&
        settings['expectedCalendarSha256'] == _jsonDigest(expected),
    'The fixture replacement changes more than the selected calendar and event titles.',
  );
  _digest(settings['incomingStudentSha256'], 'Unselected archive timetable');
  _require(
    settings['incomingStudentSha256'] != before['studentSha256'] &&
        settings['unselectedIncomingTimetableName'] ==
            'Unselected archive timetable' &&
        settings['unselectedIncomingCalendarId'] ==
            'unselected-archive-calendar',
    'The input is missing its distinct unselected timetable and extra-calendar controls.',
  );
  final source = _picker(settings['source'], calls: 0);

  final selected = observations['backup-file-selected']!;
  _require(
    selected['entry'] == 'settings-app-backup / Restore from file' &&
        selected['sameSelectiveService'] == true &&
        selected['closeAfterRestore'] == true &&
        selected['sourceObjectCount'] is int &&
        (selected['sourceObjectCount'] as int) >= 3,
    'The file action did not open the actual application-owned source selector.',
  );
  _digest(selected['sourceBundleFingerprint'], 'Actual decoded source bundle');
  _picker(selected['source'], calls: 1, original: source);
  _selection(selected['selection']);
  _configuration(selected['configuration'], accessible);
  _provider(selected['provider'], closed: false);

  final cancelled = observations['backup-preview-cancelled']!;
  _preview(cancelled['preview'], 1, accessible);
  _require(
    cancelled['cancelledWithButton'] == true,
    'The real Cancel action is missing.',
  );
  final cancelBefore = _snapshot(cancelled['before'], fixture);
  final cancelAfter = _snapshot(cancelled['after'], fixture);
  _require(
    jsonEncode(cancelBefore) == jsonEncode(before) &&
        jsonEncode(cancelAfter) == jsonEncode(before),
    'Selecting a file or cancelling its preview changed stored data or write counts.',
  );
  _selection(cancelled['selectionAfterCancel']);
  _provider(cancelled['provider'], closed: false);

  final restored = observations['backup-selection-restored']!;
  _preview(restored['preview'], 2, accessible);
  _require(
    restored['confirmedWithButton'] == true &&
        restored['returnedToSettings'] == true &&
        restored['sameMainSessionAndBackupOwner'] == true &&
        restored['scope'] == 'one selected calendar restored; unselected timetable, extra calendar, chat and Agent settings preserved',
    'The actual confirm action and returned application-owned Settings route are missing.',
  );
  _configuration(restored['configuration'], accessible);
  final after = _snapshot(restored['after'], fixture);
  _require(
    after['selectedCalendarSha256'] == settings['expectedCalendarSha256'] &&
        after['selectedCalendarSha256'] != before['selectedCalendarSha256'] &&
        after['mainSha256'] != before['mainSha256'] &&
        (after['mainWrites'] as int) > (before['mainWrites'] as int) &&
        after['generation'] != before['generation'] &&
        after['studentSha256'] != settings['incomingStudentSha256'],
    'The confirmed restore did not persist only the requested calendar replacement in a new generation.',
  );
  _preserved(before, after);
  _picker(restored['source'], calls: 1, original: source);
  _provider(restored['provider'], closed: false);
  _provider(report['providerBeforeCleanup'], closed: false);
  final storage = _map(
    report['storageBeforeCleanup'],
    'Final backup owner storage',
  );
  _require(
    storage['mainSha256'] == after['mainSha256'] &&
        storage['mainWrites'] == after['mainWrites'] &&
        storage['archiveSha256'] == after['chatSha256'] &&
        storage['conversationRevision'] == after['chatRevision'] &&
        storage['conversationLoads'] is int &&
        (storage['conversationLoads'] as int) >= 1 &&
        storage['conversationWrites'] is int &&
        (storage['conversationWrites'] as int) > 0,
    'The final actual owner storage disagrees with the selected restore readback.',
  );
  _cleanup(report['cleanup'], source);
  _cleanup(observations['cleanup'], source);
}
