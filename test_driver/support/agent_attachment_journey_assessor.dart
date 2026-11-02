const agentAttachmentCheckpoints = [
  'environment',
  'runtime-loaded',
  'product-entry',
  'attachment-selected',
  'attachment-preview',
  'attachment-only-send',
  'attachment-reopened',
  'cleanup',
];

const agentAttachmentRelevantSources = [
  'integration_test/support/agent_attachment_journey.dart',
  'test_driver/support/agent_attachment_journey_assessor.dart',
  'lib/agent/ui/agent_attachment_view.dart',
  'lib/agent/attachments/attachment_models.dart',
  'lib/agent/attachments/attachment_repository.dart',
  'lib/agent/attachments/attachment_storage.dart',
  'lib/agent/attachments/conversation_attachments.dart',
  'lib/agent/provider/provider_client.dart',
  'lib/agent/provider/provider_models.dart',
  'lib/agent/provider/provider_protocol.dart',
  'lib/agent/provider/provider_request_encoder.dart',
];

const _pngSha256 =
    '3fcb9447dea312fee271ab4f0bf36413614bb9b9a08d866b3130792e504aca8d';
const _filename = 'native-fixture.png';
const _reply = 'The offline attachment fixture was received once.';
const _draft = 'Unsent draft after the attachment-only request';

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

void _oneId(Object? value, String id, String description) {
  _require(
    value is List && value.length == 1 && value.single == id,
    '$description did not retain the single original attachment ID.',
  );
}

void _configuration(Object? value, bool accessible) {
  final config = _map(value, 'Attachment surface configuration');
  final scale = config['textScale'];
  _require(
    config['brightness'] == (accessible ? 'dark' : 'light') &&
        scale is num &&
        scale.isFinite &&
        (scale - (accessible ? 2 : 1)).abs() < 0.001 &&
        config['reduceMotion'] == accessible &&
        config['disableAnimations'] == false &&
        config['mediaQueryDisableAnimations'] == false,
    'The attachment surface did not receive its requested framework configuration.',
  );
}

void _picker(Object? value) {
  final picker = _map(value, 'Attachment picker');
  _require(
    picker['calls'] == 1 &&
        picker['unfiltered'] == true &&
        picker['source'] ==
            'synthetic XFile.fromData at the FileSelectorPlatform boundary' &&
        picker['filename'] == _filename &&
        picker['byteLength'] == 79 &&
        picker['sha256'] == _pngSha256,
    'The actual file button did not make one owned synthetic picker selection.',
  );
}

String _attachment(Object? value, {required bool draft}) {
  final file = _map(value, 'Attachment storage readback');
  final id = file['id'];
  _require(
    id is String &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        ).hasMatch(id),
    'The attachment is missing its real stable identity.',
  );
  _require(
    file['filename'] == _filename &&
        file['mediaType'] == 'image/png' &&
        file['byteLength'] == 79 &&
        file['sha256'] == _pngSha256 &&
        file['verifiedByteLength'] == 79 &&
        file['verifiedSha256'] == _pngSha256 &&
        file['referenceCount'] == 1 &&
        file['sourcePathAbsent'] == true &&
        file['binaryPayloadAbsentFromChat'] == true &&
        file['readback'] == 'ConversationArchive.decode(chatSource) and attachmentStore.readBytes',
    'Persisted attachment metadata and actual verified byte readback disagree.',
  );
  final identity = id as String;
  _oneId(file['storeIds'], identity, 'The private attachment store');
  if (draft) {
    _oneId(file['draftAttachmentIds'], identity, 'The attachment draft');
  } else {
    _require(
      file['draftAttachmentIds'] is List &&
          (file['draftAttachmentIds'] as List).isEmpty,
      'Sending did not transfer the attachment reference out of the draft.',
    );
  }
  return identity;
}

void _preview(
  Object? value, {
  required int count,
  required int requests,
  required bool accessible,
}) {
  final preview = _map(value, 'Explicit local preview');
  _require(
    preview['openedWith'] == 'attachment menu / Preview file' &&
        preview['dialogKey'] == 'agent-attachment-preview' &&
        preview['imageSha256'] == _pngSha256 &&
        preview['previewCount'] == count &&
        preview['closedWithButton'] == true &&
        preview['providerRequests'] == requests,
    'The explicit preview action, original image bytes or Close action is missing.',
  );
  for (final key in [
    'decodedWidth',
    'decodedHeight',
    'renderedWidth',
    'renderedHeight',
  ]) {
    final dimension = preview[key];
    _require(
      dimension is num && dimension.isFinite && dimension > 0,
      'The actual preview $key is invalid.',
    );
  }
  _require(
    preview['decodedWidth'] == preview['decodedHeight'] &&
        (preview['decodedWidth'] as num) <= 1200,
    'The actual image decode is inconsistent with the square PNG and production decode limit.',
  );
  _configuration(preview['configuration'], accessible);
}

void _provider(
  Object? value, {
  required int requests,
  required bool closed,
  String? attachmentId,
}) {
  final provider = _map(value, 'Attachment provider');
  // A completed run also cancels its token during runtime cleanup.
  _require(
    provider['type'] == 'attachment-encoded-offline' &&
        provider['requests'] == requests &&
        provider['transportRequests'] == requests &&
        provider['completedReplies'] == requests &&
        provider['errors'] == 0 &&
        provider['cancelled'] is bool &&
        (requests != 0 || provider['cancelled'] == false) &&
        provider['transportRejection'] == null &&
        provider['closed'] == closed &&
        provider['closeCount'] == (closed ? 1 : 0) &&
        provider['transportClosed'] == closed &&
        provider['transportScope'] ==
            'owned in-memory HTTP response; no network transport',
    'The attachment provider request, completion or lifetime counters are incorrect.',
  );
  final progress = provider['progress'];
  _require(progress is List, 'Production provider upload progress is missing.');
  final stages = progress as List;
  if (requests == 0) {
    _require(
      stages.isEmpty &&
          provider['declaredAttachment'] == null &&
          provider['wire'] == null,
      'Selecting or previewing a local attachment started a request.',
    );
    return;
  }
  _require(
    provider['streamSettled'] == true && provider['responseSettled'] == true,
    'The production provider or synthetic response stream did not finish.',
  );
  final declared = _map(
    provider['declaredAttachment'],
    'Provider attachment reference',
  );
  _require(
    declared['id'] == attachmentId &&
        declared['filename'] == _filename &&
        declared['mediaType'] == 'image/png' &&
        declared['byteLength'] == 79 &&
        declared['sha256'] == _pngSha256 &&
        declared['protocol'] == 'chatCompletions' &&
        declared['latestText'] == '',
    'The runtime did not give the production provider its original attachment-only input.',
  );
  final wire = _map(provider['wire'], 'Production encoded wire request');
  _require(
    wire['method'] == 'POST' &&
        wire['host'] == 'native-ui.invalid' &&
        wire['followRedirects'] == false &&
        wire['authorizationHeaderPresent'] == false &&
        wire['latestRole'] == 'user' &&
        wire['contentBlocks'] == 1 &&
        wire['imageBlocks'] == 1 &&
        wire['textBlocks'] == 0 &&
        wire['imageByteLength'] == 79 &&
        wire['imageSha256'] == _pngSha256 &&
        wire['bodyByteLength'] is int &&
        (wire['bodyByteLength'] as int) > 79 &&
        wire['messageCount'] is int &&
        (wire['messageCount'] as int) > 0,
    'The actual native image_url content block did not encode the original PNG bytes.',
  );
  _digest(wire['bodySha256'], 'Encoded request body');
  _require(
    stages.length == 3,
    'The actual encoding, sending and synthetic acceptance phases are incomplete.',
  );
  final encoding = _map(stages[0], 'Attachment encoding progress');
  final sending = _map(stages[1], 'Attachment sending progress');
  final accepted = _map(stages[2], 'Attachment acceptance progress');
  _require(
    encoding['phase'] == 'encoding' &&
        encoding['completedBytes'] == 79 &&
        encoding['totalBytes'] == 79 &&
        sending['phase'] == 'sending' &&
        sending['completedBytes'] == 0 &&
        sending['totalBytes'] == wire['bodyByteLength'] &&
        accepted['phase'] == 'accepted' &&
        accepted['completedBytes'] == wire['bodyByteLength'] &&
        accepted['totalBytes'] == wire['bodyByteLength'],
    'Production provider progress does not match actual encoded bytes and the synthetic response.',
  );
}

void _cleanup(Object? value, String id) {
  final cleanup = _map(value, 'Attachment cleanup');
  _provider(cleanup['provider'], requests: 1, closed: true, attachmentId: id);
  final boundaries = _map(
    cleanup['featureBoundaries'],
    'Attachment boundary cleanup',
  );
  _require(
    boundaries['status'] == 'complete' &&
        boundaries['owner'] == 'attachments' &&
        boundaries['pickerRestored'] == true &&
        boundaries['previewCount'] == 2,
    'The owned picker or preview resources did not finish cleanup.',
  );
  _oneId(
    boundaries['installed'],
    'FileSelectorPlatform.instance',
    'Installed feature boundary',
  );
  _oneId(
    boundaries['restored'],
    'FileSelectorPlatform.instance',
    'Restored feature boundary',
  );
  _picker(boundaries['picker']);
  final steps = boundaries['steps'];
  _require(
    steps is List && steps.length == 3,
    'Owned image-cache and picker cleanup steps are missing.',
  );
  for (var index = 0; index < 3; index++) {
    final step = _map((steps as List)[index], 'Attachment cleanup step');
    _require(
      step['name'] ==
              (index < 2 ? 'preview-cache-$index' : 'restore-file-selector') &&
          step['status'] == 'complete',
      'An owned attachment cleanup step did not complete in order.',
    );
    if (index < 2) {
      _require(
        step['removed'] is bool,
        'Image-cache eviction completion was not recorded.',
      );
    }
  }
}

void _completedRun(Map<String, Object?> observation) {
  _require(
    observation['savedRunCount'] == 1 &&
        observation['savedRunStatus'] == 'completed' &&
        observation['savedRequestCount'] == 1 &&
        observation['savedRequestOutcome'] == 'completed',
    'The saved attachment run or request did not complete exactly once.',
  );
}

/// Called after the central driver validates source/native/configuration and
/// common runtime-owner cleanup. No reported feature checkpoint is accepted
/// without its concrete attachment identity, byte, UI and request observations.
void validateAgentAttachmentJourney(Map<String, Object?> report) {
  _require(
    report['feature'] == 'attachments',
    'Wrong attachment feature report.',
  );
  final config = _map(report['configuration'], 'Attachment configuration');
  final accessible = config['name'] == 'accessible';
  final fixture = _map(report['fixture'], 'Attachment conversation fixture');
  final steps = report['checkpoints'];
  _require(
    steps is List && steps.length == agentAttachmentCheckpoints.length,
    'Attachment checkpoints are incomplete.',
  );
  final observations = <String, Map<String, Object?>>{};
  for (var index = 0; index < agentAttachmentCheckpoints.length; index++) {
    final step = _map((steps as List)[index], 'Attachment checkpoint');
    final name = agentAttachmentCheckpoints[index];
    _require(
      step['name'] == name && step['status'] == 'complete',
      'Attachment checkpoint $name did not complete in order.',
    );
    observations[name] = _map(step['observations'], '$name observations');
  }
  _provider(
    observations['runtime-loaded']!['provider'],
    requests: 0,
    closed: false,
  );
  final entry = observations['product-entry']!;
  _provider(entry['provider'], requests: 0, closed: false);
  final selected = observations['attachment-selected']!;
  _picker(selected['picker']);
  final id = _attachment(selected['attachment'], draft: true);
  _require(
    selected['draftText'] == '' &&
        selected['delivery'] == 'local' &&
        selected['previewOpenedAutomatically'] == false,
    'The picker did not finish as a locally saved attachment-only draft.',
  );
  _digest(
    selected['initialShortHistorySha256'],
    'Original independent short history',
  );
  _provider(selected['provider'], requests: 0, closed: false);
  _configuration(selected['configuration'], accessible);

  final preview = observations['attachment-preview']!;
  _preview(preview['preview'], count: 1, requests: 0, accessible: accessible);
  _require(
    _attachment(preview['attachment'], draft: true) == id,
    'Preview replaced the draft attachment identity.',
  );
  _provider(preview['provider'], requests: 0, closed: false);

  final sent = observations['attachment-only-send']!;
  _completedRun(sent);
  _require(
    sent['userMessageId'] is String &&
        (sent['userMessageId'] as String).isNotEmpty &&
        sent['userText'] == '' &&
        sent['attachmentDelivery'] == 'accepted' &&
        sent['reply'] == _reply &&
        sent['deliveryScope'] ==
            'synthetic transport acceptance through the production provider' &&
        sent['savedLongMessageCount'] == 514 &&
        sent['savedOriginalHistorySha256'] == fixture['longHistorySha256'] &&
        sent['nextDraft'] == _draft,
    'The attachment-only input and single scripted reply were not persisted correctly.',
  );
  _oneId(sent['userAttachmentIds'], id, 'Saved user input');
  _require(
    _attachment(sent['attachment'], draft: false) == id,
    'Sending replaced or copied the attachment.',
  );
  _provider(sent['provider'], requests: 1, closed: false, attachmentId: id);
  _configuration(sent['configuration'], accessible);

  final reopened = observations['attachment-reopened']!;
  _completedRun(reopened);
  final menuReveal = _map(reopened['menuReveal'], 'Reopened attachment menu');
  final deltas = menuReveal['verticalDeltas'];
  _require(
    menuReveal['method'] == 'framework transcript drag' &&
        menuReveal['initiallyVisible'] is bool &&
        menuReveal['menuHitTestable'] == true &&
        deltas is List &&
        deltas.length <= 12 &&
        menuReveal['dragCount'] == deltas.length &&
        (menuReveal['initiallyVisible'] == true || deltas.isNotEmpty) &&
        deltas.every(
          (delta) =>
              delta is num &&
              delta.isFinite &&
              delta.abs() >= 80 &&
              delta.abs() <= 180,
        ),
    'Reopened attachment visibility lacks bounded real transcript scrolling.',
  );
  _require(
    reopened['route'] ==
            'long conversation / short conversation / long conversation' &&
        reopened['sameApplicationAndRepository'] == true &&
        reopened['selectedId'] == 'native-long-history' &&
        reopened['conversationCount'] == 2 &&
        reopened['savedLongMessageCount'] == 514 &&
        reopened['savedShortMessageCount'] == 2 &&
        reopened['savedShortAttachmentCount'] == 0 &&
        reopened['savedOriginalHistorySha256'] ==
            fixture['longHistorySha256'] &&
        reopened['savedShortHistorySha256'] ==
            selected['initialShortHistorySha256'] &&
        reopened['visibleDraft'] == _draft &&
        reopened['savedLongDraft'] == _draft &&
        reopened['savedShortDraft'] == 'Independent short conversation draft' &&
        reopened['userMessageId'] == sent['userMessageId'] &&
        reopened['attachmentDelivery'] == 'accepted' &&
        reopened['reply'] == _reply,
    'Reopening did not preserve the actual conversation, attachment message, independent drafts and original histories.',
  );
  _oneId(reopened['userAttachmentIds'], id, 'Reopened user message');
  _require(
    reopened['mainSnapshotUnchangedSinceEntry'] == true &&
        reopened['mainSha256'] == entry['mainSha256'],
    'The attachment flow changed the main workspace snapshot.',
  );
  _require(
    _attachment(reopened['attachment'], draft: false) == id,
    'Reopening did not retain the original private bytes.',
  );
  _preview(reopened['preview'], count: 2, requests: 1, accessible: accessible);
  _picker(reopened['picker']);
  _provider(reopened['provider'], requests: 1, closed: false, attachmentId: id);
  _configuration(reopened['configuration'], accessible);
  _provider(
    report['providerBeforeCleanup'],
    requests: 1,
    closed: false,
    attachmentId: id,
  );
  final storage = _map(
    report['storageBeforeCleanup'],
    'Attachment conversation storage',
  );
  _require(
    storage['conversationLoads'] == 1 &&
        storage['conversationWrites'] is int &&
        (storage['conversationWrites'] as int) > 0 &&
        storage['mainSha256'] == entry['mainSha256'],
    'Actual attachment conversation storage did not confirm the preserved workspace.',
  );
  _cleanup(report['cleanup'], id);
  _cleanup(observations['cleanup'], id);
}
