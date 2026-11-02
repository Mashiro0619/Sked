import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:integration_test/integration_test_driver.dart';

import 'support/agent_attachment_journey_assessor.dart';
import 'support/agent_history_journey_assessor.dart';
import 'support/agent_selective_backup_journey_assessor.dart';
import 'support/report_output_directory.dart';

const _protocol = 'agent-native-feature-journey-v1';
const _knowledgeCheckpoints = [
  'environment',
  'runtime-loaded',
  'product-entry',
  'settings-open',
  'memory-created',
  'memory-updated',
  'settings-reopened',
  'chat-draft-preserved',
  'cleanup',
];
const _ownerCleanup = [
  'cancel-active-run',
  'quiesce',
  'dispose-runtime',
  'close-agent',
  'close-backup-staging',
  'close-session',
  'drain-main-writes',
  'flush-layout',
  'release-owned-preferences',
];
const _relevantSources = [
  'integration_test/agent_feature_journeys_test.dart',
  'integration_test/support/agent_feature_journey.dart',
  'integration_test/support/agent_knowledge_journey.dart',
  'integration_test/support/agent_native_session.dart',
  'integration_test/support/capture_output_directory.dart',
  'test_driver/agent_feature_journeys_driver.dart',
  'test_driver/support/report_output_directory.dart',
  'test/support/agenda_notification_memory.dart',
  'lib/app_runtime.dart',
  'lib/providers/app_scope.dart',
  'lib/screens/app_home_screen.dart',
  'lib/screens/agent_page.dart',
  'lib/screens/agent_settings_page.dart',
  'lib/widgets/assistant_pane.dart',
  'lib/widgets/settings_page_header.dart',
  'lib/agent/agent_application.dart',
  'lib/agent/conversations/conversation_repository.dart',
  'lib/agent/conversations/conversation_models.dart',
  'lib/agent/ui/agent_conversation_view.dart',
  'lib/agent/ui/agent_knowledge_view.dart',
  'lib/agent/knowledge/knowledge_service.dart',
  'lib/agent/knowledge/knowledge_repository.dart',
  'lib/agent/knowledge/knowledge_models.dart',
  'lib/agent/knowledge/knowledge_storage.dart',
];

Future<void> main() => integrationDriver(
  timeout: const Duration(minutes: 7),
  writeResponseOnFailure: true,
  responseDataCallback: (data) async {
    final output = createDriverReportOutputDirectory(
      label: 'agent-feature-journey',
    );
    final manifest = <String, Object?>{};
    for (final path in {
      ..._relevantSources,
      ...agentAttachmentRelevantSources,
      ...agentHistoryRelevantSources,
      ...agentSelectiveBackupRelevantSources,
    }) {
      try {
        final file = File(path);
        manifest[path] = await file.exists()
            ? sha256.convert(await file.readAsBytes()).toString()
            : 'missing';
      } catch (error) {
        manifest[path] = {'error': '$error'};
      }
    }
    final rawFile = File(
      '${output.path}${Platform.pathSeparator}agent-feature-journey-raw.json',
    );
    // Persist failed or malformed responses and available source hashes first.
    await _writeNew(rawFile, {
      'response': data,
      'driverSourceManifest': {
        'scope': 'relevant files read from the driver checkout; not all tracked files or binary attestation',
        'sha256': manifest,
      },
    });
    final assessmentFile = File(
      '${output.path}${Platform.pathSeparator}agent-feature-journey-assessment.json',
    );
    try {
      final feature = _validate(data?['agentFeatureJourney']);
      _require(
        manifest.values.every(
          (value) =>
              value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
        ),
        'A relevant driver source file is missing or unreadable.',
      );
      await _writeNew(assessmentFile, {
        'status': 'passed',
        'protocol': _protocol,
        'feature': feature,
        'rawReport': rawFile.absolute.path,
        'scope': 'native functional feature checkpoints; native process logs require separate review',
      });
    } catch (error, stack) {
      await _writeNew(assessmentFile, {
        'status': 'failed',
        'error': '$error',
        'stack': '$stack',
        'rawReport': rawFile.absolute.path,
      });
      rethrow;
    }
    stdout.writeln('Agent native feature report: ${rawFile.absolute.path}');
  },
);

Future<void> _writeNew(File file, Object? value) async {
  if (await file.exists()) {
    throw StateError(
      'Use a new output directory; refusing to replace ${file.absolute.path}.',
    );
  }
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(value)}\n',
    flush: true,
  );
}

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Map<String, Object?> _map(Object? value, String description) {
  _require(value is Map, '$description is missing or invalid.');
  return Map<String, Object?>.from(value as Map);
}

void _digest(Object? value, String description) {
  _require(
    value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value),
    '$description is not a SHA-256 digest.',
  );
}

Map<String, Map<String, Object?>> _checkpoints(
  Object? value, {
  List<String> expected = _knowledgeCheckpoints,
}) {
  _require(
    value is List && value.length == expected.length,
    'The required native feature checkpoint sequence is incomplete.',
  );
  final result = <String, Map<String, Object?>>{};
  final steps = value as List;
  for (var index = 0; index < expected.length; index++) {
    final step = _map(steps[index], 'Checkpoint $index');
    final name = expected[index];
    _require(
      step['name'] == name && step['status'] == 'complete',
      'Checkpoint $name did not complete in order.',
    );
    result[name] = _map(step['observations'], '$name observations');
  }
  return result;
}

void _configuration(
  Map<String, Object?> value,
  bool accessible, {
  bool observed = false,
}) {
  final scale = value['textScale'];
  _require(
    value['brightness'] == (accessible ? 'dark' : 'light') &&
        scale is num &&
        scale.isFinite &&
        (scale - (accessible ? 2 : 1)).abs() < 0.001 &&
        value['reduceMotion'] == accessible &&
        value['disableAnimations'] == false &&
        (!observed || value['mediaQueryDisableAnimations'] == false),
    'The actual framework theme, text scale or motion configuration is incorrect.',
  );
}

String _environment(Object? value) {
  final environment = _map(value, 'Native environment');
  final platform = environment['platform'];
  _require(
    const ['windows', 'android'].contains(platform),
    'This is not a supported native platform.',
  );
  _require(
    environment['surfaceOverrides'] == false &&
        environment['executable'] is String &&
        !(environment['executable'] as String).toLowerCase().contains(
          'flutter_tester',
        ) &&
        environment['pid'] is int &&
        (environment['pid'] as int) > 0,
    'Actual native process and surface evidence is missing.',
  );
  for (final key in ['operatingSystemVersion', 'dartVersion', 'abi']) {
    _require(
      environment[key] is String && (environment[key] as String).isNotEmpty,
      'Native $key is missing.',
    );
  }
  _require(
    const ['debug', 'profile', 'release'].contains(environment['buildMode']),
    'Native build mode is missing.',
  );
  for (final key in [
    'physicalWidth',
    'physicalHeight',
    'logicalWidth',
    'logicalHeight',
    'devicePixelRatio',
  ]) {
    final dimension = environment[key];
    _require(
      dimension is num && dimension.isFinite && dimension > 0,
      'Native $key is invalid.',
    );
  }
  for (final dimension in ['Width', 'Height']) {
    final actual =
        (environment['physical$dimension'] as num) /
        (environment['devicePixelRatio'] as num);
    _require(
      (actual - (environment['logical$dimension'] as num)).abs() < 0.01,
      'Native $dimension and DPR are inconsistent.',
    );
  }
  _require(
    environment['nativeSemanticsEnabled'] is bool &&
        environment['nativeAccessibilityFeatures'] is String,
    'Observed accessibility flags are missing.',
  );
  if (platform == 'windows') {
    _require(
      (environment['logicalWidth'] as num) >= 1100 &&
          (environment['logicalHeight'] as num) >= 600 &&
          environment['deviceKind'] == 'Windows native window',
      'Windows did not use the required actual desktop window.',
    );
  } else {
    _require(
      environment['androidApi'] is String &&
          int.tryParse(environment['androidApi'] as String) != null &&
          environment['androidAbi'] is String &&
          (environment['androidAbi'] as String).isNotEmpty &&
          environment['androidQemu'] is String,
      'Android API, ABI or emulator provenance is incomplete.',
    );
    _require(
      environment['deviceKind'] ==
          (environment['androidQemu'] == '1'
              ? 'emulator'
              : 'unclassified Android native surface'),
      'The Android surface label is not supported by its recorded property.',
    );
  }
  return platform as String;
}

void _provider(Object? value, {required bool closed}) {
  final provider = _map(value, 'Knowledge provider');
  _require(
    provider['type'] == 'knowledge-offline' &&
        provider['requests'] == 0 &&
        provider['transportAttempts'] == 0 &&
        provider['closed'] == closed &&
        provider['transportClosed'] == closed &&
        provider['closeCount'] == (closed ? 1 : 0),
    'Knowledge settings made a model request, used transport or failed provider lifetime checks.',
  );
}

void _knowledgeState(Object? value, {required int revision}) {
  final state = _map(value, 'Knowledge archive');
  _require(
    state['archiveRevision'] == revision &&
        state['memoryCount'] == (revision == 0 ? 0 : 1) &&
        state['localSkillCount'] == 0 &&
        state['receiptCount'] == revision &&
        state['ready'] == true,
    'The local knowledge archive count, revision or actual receipt count is incorrect.',
  );
}

void _tab(Object? value, {required String kind, required bool accessible}) {
  final tab = _map(value, '$kind tab');
  _require(
    tab['kind'] == kind &&
        tab['tabIndex'] == (kind == 'memory' ? 3 : 2) &&
        tab['addAction'] == 'knowledge-add-$kind' &&
        tab['addActionReachable'] == true &&
        tab['sameKnowledgeService'] == true,
    'The actual $kind settings tab and enabled Add action were not reached.',
  );
  _configuration(
    _map(tab['configuration'], '$kind tab configuration'),
    accessible,
    observed: true,
  );
}

Map<String, Object?> _record(
  Object? value, {
  required String title,
  required String body,
  required int revision,
  required int reloads,
}) {
  final record = _map(value, 'Memory storage readback');
  _require(
    record['id'] is String &&
        RegExp(
          r'^memory-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(record['id'] as String) &&
        record['key'] == 'memory:${record['id']}',
    'The memory readback lacks the stable UI-created identity.',
  );
  _require(
    record['kind'] == 'memory' &&
        record['title'] == title &&
        record['body'] == body &&
        record['bodySha256'] == sha256.convert(utf8.encode(body)).toString() &&
        record['revision'] == revision &&
        record['enabled'] == true &&
        record['builtIn'] == false &&
        record['storageReadback'] == 'knowledge.initialize(reload: true)' &&
        record['completedStorageReloads'] == reloads,
    'Memory content, version or completed storage readback is incorrect.',
  );
  _knowledgeState(record, revision: revision);
  return record;
}

void _settings(Object? value, bool accessible) {
  final settings = _map(value, 'Standalone settings');
  _require(
    settings['openedFrom'] == 'agent-conversation-menu / agent-settings' &&
        settings['standaloneRoute'] == true &&
        settings['sameApplication'] == true,
    'Settings were not opened through the actual Agent menu and standalone route.',
  );
  _configuration(
    _map(settings['configuration'], 'Settings configuration'),
    accessible,
    observed: true,
  );
  _tab(settings['memoryTab'], kind: 'memory', accessible: accessible);
}

Map<String, Object?> _runtimeCleanup(Object? value) {
  final cleanup = _map(value, 'Cleanup');
  _require(
    cleanup['status'] == 'complete' &&
        cleanup['unmount'] == 'complete' &&
        cleanup['httpGuardInstalled'] == true &&
        cleanup['httpGuardRestored'] == true &&
        cleanup['httpOperationAttempts'] == 0,
    'Unmount or the owned HTTP guard did not finish cleanly.',
  );
  final owners = _map(cleanup['owners'], 'Runtime owners');
  _require(owners['status'] == 'complete', 'Runtime owner cleanup failed.');
  final steps = owners['steps'];
  _require(
    steps is List && steps.length == _ownerCleanup.length,
    'Runtime owner drains are incomplete.',
  );
  for (var index = 0; index < _ownerCleanup.length; index++) {
    final step = _map((steps as List)[index], 'Runtime cleanup step');
    _require(
      step['name'] == _ownerCleanup[index] && step['status'] == 'complete',
      'Runtime cleanup ${_ownerCleanup[index]} failed.',
    );
  }
  _require(
    _map(cleanup['provider'], 'Feature provider')['closed'] == true &&
        _map(cleanup['ownedProvider'], 'Session provider owner')['closed'] ==
            true &&
        _map(
              cleanup['featureBoundaries'],
              'Feature boundary cleanup',
            )['status'] ==
            'complete',
    'The runtime provider or feature boundaries were not completely closed.',
  );
  return cleanup;
}

void _cleanup(Object? value) {
  final cleanup = _runtimeCleanup(value);
  final boundaries = _map(
    cleanup['featureBoundaries'],
    'Feature boundary restoration',
  );
  _require(
    boundaries['status'] == 'complete' &&
        boundaries['owner'] == 'knowledge' &&
        boundaries['installed'] is List &&
        (boundaries['installed'] as List).isEmpty &&
        boundaries['restored'] is List &&
        (boundaries['restored'] as List).isEmpty,
    'Knowledge unexpectedly installed a picker or platform replacement.',
  );
  _provider(cleanup['provider'], closed: true);
}

void _validateKnowledge(Object? value) {
  final report = _map(value, 'Agent feature journey report');
  _require(
    report['protocol'] == _protocol &&
        report['measurement'] == 'native-functional-feature',
    'This is not the native feature protocol.',
  );
  _require(
    report['status'] == 'passed',
    'The native journey failed; inspect its retained checkpoints and cleanup.',
  );
  _require(
    report['feature'] == 'knowledge',
    'This driver implements only the knowledge feature contract.',
  );
  final source = _map(report['source'], 'Source provenance');
  _require(
    source['revision'] is String &&
        RegExp(r'^[0-9a-f]{40}$').hasMatch(source['revision'] as String),
    'The native build must declare a full source SHA.',
  );
  _require(
    report['label'] is String &&
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')
            .hasMatch(report['label'] as String),
    'The report label is invalid.',
  );
  final platform = _environment(report['environment']);
  final config = _map(report['configuration'], 'Framework configuration');
  _require(
    const ['baseline', 'accessible'].contains(config['name']),
    'The framework configuration name is invalid.',
  );
  _require(
    config['configurationScope'] ==
        'framework theme, TextScaler and motion scope',
    'The configuration scope is not declared.',
  );
  final accessible = config['name'] == 'accessible';
  _configuration(config, accessible);
  final fixture = _map(report['fixture'], 'Synthetic fixture');
  _require(
    fixture['longMessageCount'] == 512 &&
        fixture['shortMessageCount'] == 2 &&
        fixture['conversationCount'] == 2,
    'The synthetic conversation fixture is incomplete.',
  );
  for (final key in ['mainSha256', 'archiveSha256', 'longHistorySha256']) {
    _digest(fixture[key], 'Fixture $key');
  }
  final checkpoints = _checkpoints(report['checkpoints']);
  final loaded = checkpoints['runtime-loaded']!;
  _require(
    loaded['agentInitialized'] == false &&
        _map(loaded['storage'], 'Initial storage')['conversationLoads'] == 0,
    'Agent history was not dormant before product entry.',
  );
  _provider(loaded['provider'], closed: false);
  final entry = checkpoints['product-entry']!;
  _require(
    entry['historyMessageCount'] == 512 &&
        entry['initialDraft'] == 'Long conversation initial draft' &&
        entry['sameApplicationAndRepository'] == true &&
        entry['selectedId'] == 'native-long-history' &&
        entry['host'] ==
            (platform == 'windows' ? 'AgentAssistantPane' : 'AgentPage') &&
        entry['entry'] ==
            (platform == 'windows'
                ? 'home assistant toggle'
                : 'home More menu / Agent'),
    'The actual product entry did not retain the expected host, owner, archive and draft.',
  );
  _digest(entry['mainSha256'], 'Workspace at product entry');
  _configuration(
    _map(entry['configuration'], 'Agent host configuration'),
    accessible,
    observed: true,
  );
  _provider(entry['provider'], closed: false);

  const draft = 'Unsent draft before editing shared knowledge';
  const createdTitle = 'Synthetic study preference';
  const createdBody =
      'Prefer quiet mornings for the synthetic reading session.';
  const updatedTitle = 'Updated synthetic study preference';
  const updatedBody =
      'Prefer quiet afternoons for the synthetic reading session.';
  final settings = checkpoints['settings-open']!;
  _settings(settings, accessible);
  _require(
    settings['draftBeforeSettings'] == draft &&
        settings['storedDraftBeforeSettings'] == draft,
    'The original chat draft was not saved before settings.',
  );
  _digest(settings['initialShortHistorySha256'], 'Independent short history');
  _knowledgeState(settings['knowledgeBefore'], revision: 0);

  final create = checkpoints['memory-created']!;
  _require(
    create['savedWith'] == 'knowledge-save',
    'Memory creation did not use the Save button.',
  );
  final created = _record(
    create['record'],
    title: createdTitle,
    body: createdBody,
    revision: 1,
    reloads: 1,
  );
  final update = checkpoints['memory-updated']!;
  _require(
    update['savedWith'] == 'knowledge-save' &&
        update['previousKey'] == created['key'] &&
        update['previousRevision'] == 1,
    'The edit did not continue the created record.',
  );
  final updated = _record(
    update['record'],
    title: updatedTitle,
    body: updatedBody,
    revision: 2,
    reloads: 2,
  );
  _require(
    updated['id'] == created['id'] && updated['key'] == created['key'],
    'Editing replaced the memory identity.',
  );

  final reopened = checkpoints['settings-reopened']!;
  _settings(reopened, accessible);
  _require(
    reopened['returnedToOriginalChatBeforeReopen'] == true &&
        reopened['editorCancelledWithButton'] == true,
    'The settings round trip or actual Cancel action is missing.',
  );
  final editor = _map(reopened['editor'], 'Reopened editor fields');
  _require(
    editor['recordKey'] == updated['key'] &&
        editor['recordRevision'] == 2 &&
        editor['title'] == updatedTitle &&
        editor['body'] == updatedBody,
    'The reopened editor did not show the persisted updated record.',
  );
  _configuration(
    _map(editor['configuration'], 'Editor configuration'),
    accessible,
    observed: true,
  );
  _tab(reopened['skillsTab'], kind: 'skill', accessible: accessible);
  _require(
    reopened['skillCount'] is int && (reopened['skillCount'] as int) > 0,
    'The Skills catalog was not available.',
  );
  final afterCancel = _record(
    reopened['recordAfterCancel'],
    title: updatedTitle,
    body: updatedBody,
    revision: 2,
    reloads: 3,
  );
  _require(
    afterCancel['key'] == updated['key'],
    'Cancelling the editor changed memory identity.',
  );

  final chat = checkpoints['chat-draft-preserved']!;
  _require(
    chat['sameApplicationAndRepository'] == true &&
        chat['selectedId'] == 'native-long-history' &&
        chat['conversationCount'] == 2 &&
        chat['visibleDraft'] == draft &&
        chat['savedLongDraft'] == draft &&
        chat['savedShortDraft'] == 'Independent short conversation draft' &&
        chat['savedLongMessageCount'] == 512 &&
        chat['savedShortMessageCount'] == 2 &&
        chat['savedLongHistorySha256'] == fixture['longHistorySha256'] &&
        chat['savedShortHistorySha256'] ==
            settings['initialShortHistorySha256'] &&
        chat['runActive'] == false,
    'Returning from settings did not preserve the real chat owner, drafts, history and idle run.',
  );
  _require(
    chat['mainSnapshotUnchangedSinceEntry'] == true &&
        chat['mainSha256'] == entry['mainSha256'],
    'Knowledge work changed the main workspace.',
  );
  _configuration(
    _map(chat['configuration'], 'Returned Agent configuration'),
    accessible,
    observed: true,
  );
  _knowledgeState(chat['knowledge'], revision: 2);
  _provider(chat['provider'], closed: false);
  _provider(report['providerBeforeCleanup'], closed: false);
  final storage = _map(
    report['storageBeforeCleanup'],
    'Persisted conversation storage',
  );
  _require(
    storage['conversationLoads'] == 1 &&
        storage['conversationWrites'] is int &&
        (storage['conversationWrites'] as int) > 0 &&
        storage['mainSha256'] == entry['mainSha256'],
    'The synthetic archive was not loaded and saved by its actual owner.',
  );
  _cleanup(report['cleanup']);
  _cleanup(checkpoints['cleanup']);
}

/// Shared gates for separately implemented feature assessors. Knowledge keeps
/// its existing explicit validator; new features must also supply their own
/// concrete UI, persistence, provider and boundary assertions after this gate.
void _validateFeatureBase(
  Map<String, Object?> report, {
  required String feature,
  required List<String> expectedCheckpoints,
}) {
  _require(
    report['protocol'] == _protocol &&
        report['measurement'] == 'native-functional-feature',
    'This is not the native feature protocol.',
  );
  _require(
    report['status'] == 'passed' && report['feature'] == feature,
    'The selected native feature did not pass; inspect retained failure and cleanup evidence.',
  );
  final source = _map(report['source'], 'Source provenance');
  _require(
    source['revision'] is String &&
        RegExp(r'^[0-9a-f]{40}$').hasMatch(source['revision'] as String),
    'The native feature must declare its full source SHA.',
  );
  _require(
    report['label'] is String &&
        RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$')
            .hasMatch(report['label'] as String),
    'The native feature label is invalid.',
  );
  final platform = _environment(report['environment']);
  final config = _map(report['configuration'], 'Framework configuration');
  _require(
    const ['baseline', 'accessible'].contains(config['name']) &&
        config['configurationScope'] ==
            'framework theme, TextScaler and motion scope',
    'The native feature configuration or its scope is invalid.',
  );
  final accessible = config['name'] == 'accessible';
  _configuration(config, accessible);
  final fixture = _map(report['fixture'], 'Synthetic fixture');
  _require(
    fixture['longMessageCount'] == 512 &&
        fixture['shortMessageCount'] == 2 &&
        fixture['conversationCount'] == 2,
    'The native feature did not use the required synthetic conversation fixture.',
  );
  for (final key in ['mainSha256', 'archiveSha256', 'longHistorySha256']) {
    _digest(fixture[key], 'Fixture $key');
  }
  final checkpoints = _checkpoints(
    report['checkpoints'],
    expected: expectedCheckpoints,
  );
  final loaded = checkpoints['runtime-loaded']!;
  _require(
    loaded['agentInitialized'] == false &&
        _map(loaded['storage'], 'Initial storage')['conversationLoads'] == 0,
    'Agent history was not dormant before the real product entry.',
  );
  final entry = checkpoints['product-entry']!;
  _require(
    entry['historyMessageCount'] == 512 &&
        entry['initialDraft'] == 'Long conversation initial draft' &&
        entry['sameApplicationAndRepository'] == true &&
        entry['selectedId'] == 'native-long-history' &&
        entry['host'] ==
            (platform == 'windows' ? 'AgentAssistantPane' : 'AgentPage') &&
        entry['entry'] ==
            (platform == 'windows'
                ? 'home assistant toggle'
                : 'home More menu / Agent'),
    'The formal native entry did not retain its expected host, owners, archive and draft.',
  );
  _digest(entry['mainSha256'], 'Workspace at product entry');
  _configuration(
    _map(entry['configuration'], 'Native Agent host configuration'),
    accessible,
    observed: true,
  );
  _runtimeCleanup(report['cleanup']);
  _runtimeCleanup(checkpoints['cleanup']);
}

String _validate(Object? value) {
  final report = _map(value, 'Agent feature journey report');
  switch (report['feature']) {
    case 'knowledge':
      _validateKnowledge(report);
      return 'knowledge';
    case 'attachments':
      _validateFeatureBase(
        report,
        feature: 'attachments',
        expectedCheckpoints: agentAttachmentCheckpoints,
      );
      validateAgentAttachmentJourney(report);
      return 'attachments';
    case 'history':
      _validateFeatureBase(
        report,
        feature: 'history',
        expectedCheckpoints: agentHistoryCheckpoints,
      );
      validateAgentHistoryJourney(report);
      return 'history';
    case 'selective-backup':
      _validateFeatureBase(
        report,
        feature: 'selective-backup',
        expectedCheckpoints: agentSelectiveBackupCheckpoints,
      );
      validateAgentSelectiveBackupJourney(report);
      return 'selective-backup';
    default:
      throw StateError(
        'No native feature assessor is implemented for ${report['feature']}.',
      );
  }
}
