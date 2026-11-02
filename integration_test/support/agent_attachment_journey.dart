import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/rendering.dart' show RenderImage;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_attachment_view.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_feature_journey.dart';
import 'agent_native_session.dart';

const _filename = 'native-fixture.png';
const _sourcePath = 'memory://agent-attachment-source/native-fixture.png';
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAFklEQVR42mO4Y5PyX6Pp0n8YzUC6AAA4VyexAxAkqQAAAABJRU5ErkJggg==';
const _pngSha256 =
    '3fcb9447dea312fee271ab4f0bf36413614bb9b9a08d866b3130792e504aca8d';
const _reply = 'The offline attachment fixture was received once.';
const _nextDraft = 'Unsent draft after the attachment-only request';

String _bytesDigest(List<int> bytes) => sha256.convert(bytes).toString();

class _AttachmentPicker extends FileSelectorPlatform {
  var calls = 0;
  var unfiltered = false;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    calls++;
    unfiltered = acceptedTypeGroups == null || acceptedTypeGroups.isEmpty;
    requireAgentFeature(
      calls == 1 && unfiltered && initialDirectory == null,
      'The attachment journey expected exactly one unfiltered picker call.',
    );
    return XFile.fromData(
      base64Decode(_pngBase64),
      path: _sourcePath,
      name: _filename,
      mimeType: 'image/png',
    );
  }

  Map<String, Object?> toJson() => {
    'calls': calls,
    'unfiltered': unfiltered,
    'source': 'synthetic XFile.fromData at the FileSelectorPlatform boundary',
    'filename': _filename,
    'byteLength': 79,
    'sha256': _pngSha256,
  };
}

/// The production provider still performs budgeting, attachment reads, native
/// content-block encoding, progress and response decoding. Only HTTP delivery
/// is replaced here; no socket or real model request is created.
class _AttachmentTransport extends http.BaseClient {
  var requests = 0;
  var closed = false;
  var responseSettled = false;
  Map<String, Object?>? wire;
  String? rejection;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests++;
    try {
      requireAgentFeature(
        requests == 1 &&
            request.method == 'POST' &&
            request.url.host == 'native-ui.invalid' &&
            !request.followRedirects,
        'Unexpected attachment transport request.',
      );
      final hasAuthorization = request.headers.keys.any(
        (key) => key.toLowerCase() == 'authorization',
      );
      requireAgentFeature(
        !hasAuthorization,
        'Synthetic attachment transport received a credential header.',
      );
      final bytes = await request.finalize().toBytes();
      final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final messages = body['messages'] as List;
      final latest = messages.last as Map;
      final content = latest['content'] as List;
      final images = content
          .whereType<Map>()
          .where((block) => block['type'] == 'image_url')
          .toList();
      requireAgentFeature(
        body['model'] == 'native-ui-fixture' &&
            body['stream'] == true &&
            latest['role'] == 'user' &&
            content.length == 1 &&
            images.length == 1,
        'The actual wire request is not the expected attachment-only message.',
      );
      final url = (images.single['image_url'] as Map)['url'] as String;
      const prefix = 'data:image/png;base64,';
      requireAgentFeature(
        url.startsWith(prefix),
        'The wire image has the wrong native content block.',
      );
      final png = base64Decode(url.substring(prefix.length));
      requireAgentFeature(
        png.length == 79 && _bytesDigest(png) == _pngSha256,
        'The production encoder did not deliver the original attachment bytes.',
      );
      wire = {
        'method': request.method,
        'host': request.url.host,
        'followRedirects': request.followRedirects,
        'authorizationHeaderPresent': hasAuthorization,
        'bodyByteLength': bytes.length,
        'bodySha256': _bytesDigest(bytes),
        'messageCount': messages.length,
        'latestRole': latest['role'],
        'contentBlocks': content.length,
        'imageBlocks': images.length,
        'textBlocks': 0,
        'imageByteLength': png.length,
        'imageSha256': _bytesDigest(png),
        'responseScope':
            'one synthetic HTTP 200 JSON reply; no remote acceptance claim',
      };
      final response = utf8.encode(
        jsonEncode({
          'choices': [
            {
              'index': 0,
              'message': {'role': 'assistant', 'content': _reply},
              'finish_reason': 'stop',
            },
          ],
        }),
      );
      return http.StreamedResponse(
        _response(response),
        200,
        headers: const {'content-type': 'application/json'},
        request: request,
      );
    } catch (error) {
      rejection = '$error';
      rethrow;
    }
  }

  Stream<List<int>> _response(List<int> bytes) async* {
    try {
      yield bytes;
    } finally {
      responseSettled = true;
    }
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _AttachmentProvider extends ProviderClient {
  _AttachmentProvider._(this.transport) : super(client: transport);
  factory _AttachmentProvider() =>
      _AttachmentProvider._(_AttachmentTransport());

  final _AttachmentTransport transport;
  final progress = <Map<String, Object?>>[];
  ProviderCancellationToken? cancellation;
  Map<String, Object?>? declared;
  var requests = 0;
  var completedReplies = 0;
  var errors = 0;
  var streamSettled = false;
  var closeCount = 0;

  @override
  Stream<ProviderEvent> stream(
    ProviderRequest request, {
    required String apiKey,
    ProviderCancellationToken? cancellation,
  }) {
    requests++;
    this.cancellation = cancellation;
    final attachments = request.messages
        .expand((message) => message.attachments)
        .toList();
    if (requests != 1 ||
        request.endpoint.host != 'native-ui.invalid' ||
        request.model != 'native-ui-fixture' ||
        request.protocol != ProviderProtocol.chatCompletions ||
        apiKey.isNotEmpty ||
        cancellation == null ||
        attachments.length != 1 ||
        request.messages.last.role != ProviderRole.user ||
        request.messages.last.text.isNotEmpty ||
        request.messages.last.attachments.length != 1) {
      errors++;
      return Stream.error(
        StateError('Unexpected attachment-only provider request.'),
      );
    }
    final file = attachments.single;
    declared = {
      'id': file.id,
      'filename': file.filename,
      'mediaType': file.mediaType,
      'byteLength': file.byteLength,
      'sha256': file.digest,
      'protocol': request.protocol.name,
      'latestText': request.messages.last.text,
    };
    return _observe(
      super.stream(request, apiKey: apiKey, cancellation: cancellation),
    );
  }

  Stream<ProviderEvent> _observe(Stream<ProviderEvent> events) async* {
    try {
      await for (final event in events) {
        if (event is ProviderUploadProgress) {
          progress.add({
            'phase': event.phase.name,
            'completedBytes': event.completedBytes,
            'totalBytes': event.totalBytes,
          });
        }
        if (event is ProviderCompleted) {
          completedReplies++;
          requireAgentFeature(
            event.response.text == _reply && event.response.toolCalls.isEmpty,
            'The synthetic attachment response did not decode as expected.',
          );
        }
        yield event;
      }
    } catch (_) {
      errors++;
      rethrow;
    } finally {
      streamSettled = true;
    }
  }

  Map<String, Object?> toJson() => {
    'type': 'attachment-encoded-offline',
    'requests': requests,
    'completedReplies': completedReplies,
    'errors': errors,
    'cancelled': cancellation?.isCancelled ?? false,
    'streamSettled': streamSettled,
    'closed': closeCount != 0,
    'closeCount': closeCount,
    'transportRequests': transport.requests,
    'transportClosed': transport.closed,
    'responseSettled': transport.responseSettled,
    'declaredAttachment': declared,
    'wire': transport.wire,
    'progress': List<Map<String, Object?>>.of(progress),
    'transportRejection': transport.rejection,
    'transportScope': 'owned in-memory HTTP response; no network transport',
  };

  @override
  void close() {
    if (closeCount != 0) return;
    super.close();
    transport.close();
    closeCount++;
  }
}

class AgentAttachmentJourney implements AgentNativeFeature {
  AgentAttachmentJourney._(this._previousPicker, this._picker, this._provider) {
    FileSelectorPlatform.instance = _picker;
  }

  factory AgentAttachmentJourney() => AgentAttachmentJourney._(
    FileSelectorPlatform.instance,
    _AttachmentPicker(),
    _AttachmentProvider(),
  );

  final FileSelectorPlatform _previousPicker;
  final _AttachmentPicker _picker;
  final _AttachmentProvider _provider;
  final _previewProviders = <ImageProvider>[];
  ConversationAttachment? _attachment;
  String? _userMessageId;
  String? _shortHistoryDigest;
  var _previewCount = 0;

  @override
  String get name => 'attachments';

  @override
  ProviderClient get provider => _provider;

  @override
  Map<String, Object?> providerReport() => _provider.toJson();

  @override
  Map<String, Object?> diagnostics() => {
    'attachmentId': _attachment?.id,
    'userMessageId': _userMessageId,
    'previewCount': _previewCount,
    'picker': _picker.toJson(),
    'pickerOwnerRetained': identical(FileSelectorPlatform.instance, _picker),
  };

  @override
  Future<Map<String, Object?>> releaseBoundaries() async {
    final steps = <Map<String, Object?>>[];
    for (var index = 0; index < _previewProviders.length; index++) {
      try {
        final removed = await _previewProviders[index].evict();
        steps.add({
          'name': 'preview-cache-$index',
          'status': 'complete',
          'removed': removed,
        });
      } catch (error, stack) {
        steps.add({
          'name': 'preview-cache-$index',
          'status': 'failed',
          'error': '$error',
          'stack': '$stack',
        });
      }
    }
    var pickerRestored = false;
    try {
      requireAgentFeature(
        identical(FileSelectorPlatform.instance, _picker),
        'The attachment journey lost ownership of its picker replacement.',
      );
      FileSelectorPlatform.instance = _previousPicker;
      pickerRestored = identical(
        FileSelectorPlatform.instance,
        _previousPicker,
      );
      steps.add({
        'name': 'restore-file-selector',
        'status': pickerRestored ? 'complete' : 'failed',
      });
    } catch (error, stack) {
      steps.add({
        'name': 'restore-file-selector',
        'status': 'failed',
        'error': '$error',
        'stack': '$stack',
      });
    }
    return {
      'status':
          pickerRestored && steps.every((step) => step['status'] == 'complete')
          ? 'complete'
          : 'failed',
      'owner': name,
      'installed': ['FileSelectorPlatform.instance'],
      'restored': [if (pickerRestored) 'FileSelectorPlatform.instance'],
      'pickerRestored': pickerRestored,
      'picker': _picker.toJson(),
      'previewCount': _previewCount,
      'steps': steps,
      'sourceFileScope': 'in-memory XFile fixture; no source file or temporary directory created',
    };
  }

  @override
  Future<void> exercise(AgentFeatureJourney journey) async {
    await journey.checkpoint('attachment-selected', () => _select(journey));
    await journey.checkpoint(
      'attachment-preview',
      () => _previewDraft(journey),
    );
    await journey.checkpoint('attachment-only-send', () => _send(journey));
    await journey.checkpoint('attachment-reopened', () => _reopen(journey));
  }

  void _assertRequests(int expected) {
    requireAgentFeature(
      _provider.requests == expected &&
          _provider.transport.requests == expected &&
          _provider.errors == 0 &&
          _provider.transport.rejection == null &&
          _provider.closeCount == 0,
      'Selecting, previewing or reopening an attachment made an unexpected provider request.',
    );
  }

  Map<String, Object?> _completedRunEvidence(AgentConversation conversation) {
    requireAgentFeature(
      conversation.runs.length == 1,
      'The saved attachment conversation has an unexpected run count.',
    );
    final run = conversation.runs.single;
    requireAgentFeature(
      run.status == ConversationRunStatus.completed &&
          run.requests.length == 1 &&
          run.requests.single.outcome == ConversationAttemptOutcome.completed,
      'The saved attachment run or request did not complete successfully.',
    );
    return {
      'savedRunCount': conversation.runs.length,
      'savedRunStatus': run.status.name,
      'savedRequestCount': run.requests.length,
      'savedRequestOutcome': run.requests.single.outcome.name,
    };
  }

  Future<Map<String, Object?>> _storedAttachment(
    AgentFeatureJourney journey,
  ) async {
    final application = journey.session.app.agent;
    await application.attachmentStore.waitForPendingOperations().timeout(
      const Duration(seconds: 20),
    );
    await application.conversations.waitForPendingWrites().timeout(
      const Duration(seconds: 20),
    );
    final saved = ConversationArchive.decode(journey.session.chatSource);
    final conversation = saved.conversations.singleWhere(
      (item) => item.id == agentNativeLongId,
    );
    requireAgentFeature(
      conversation.attachments.length == 1,
      'The saved conversation does not own exactly one attachment.',
    );
    final file = conversation.attachments.single;
    final ids = await application.attachmentStore.storage.ids().timeout(
      const Duration(seconds: 20),
    );
    final bytes = await application.attachmentStore
        .readBytes(file)
        .timeout(const Duration(seconds: 20));
    requireAgentFeature(
      ids.length == 1 &&
          ids.contains(file.id) &&
          file.id == _attachment!.id &&
          file.name == _filename &&
          file.mediaType == 'image/png' &&
          file.byteLength == 79 &&
          file.digest == _pngSha256 &&
          bytes.length == file.byteLength &&
          _bytesDigest(bytes) == file.digest,
      'The saved attachment reference and verified private bytes disagree.',
    );
    requireAgentFeature(
      !journey.session.chatSource.contains(_sourcePath) &&
          !journey.session.chatSource.contains(_pngBase64) &&
          !journey.session.chatSource.contains('data:image/png;base64,'),
      'The conversation JSON contains the source path or binary payload.',
    );
    return {
      'id': file.id,
      'filename': file.name,
      'mediaType': file.mediaType,
      'byteLength': file.byteLength,
      'sha256': file.digest,
      'verifiedByteLength': bytes.length,
      'verifiedSha256': _bytesDigest(bytes),
      'storeIds': ids.toList()..sort(),
      'referenceCount': conversation.attachments.length,
      'draftAttachmentIds': conversation.draftAttachmentIds,
      'sourcePathAbsent': true,
      'binaryPayloadAbsentFromChat': true,
      'readback': 'ConversationArchive.decode(chatSource) and attachmentStore.readBytes',
    };
  }

  Future<Map<String, Object?>> _select(AgentFeatureJourney journey) async {
    _assertRequests(0);
    final archive = ConversationArchive.decode(journey.session.chatSource);
    _shortHistoryDigest = AgentNativeSession.historyDigest(
      archive.conversations
          .singleWhere((item) => item.id == agentNativeShortId)
          .messages,
    );
    await journey.enterDraft('');
    final attach = journey.key('agent-attach-file');
    await journey.reveal(attach, 'the actual attachment picker button');
    await journey.tap(attach, 'the actual attachment picker button');
    final application = journey.session.app.agent;
    await journey.until(
      () =>
          _picker.calls == 1 &&
          !application.binaryAttachments.isImporting(agentNativeLongId) &&
          !application.binaryAttachments.hasPending(agentNativeLongId) &&
          application.binaryAttachments
                  .progressFor(agentNativeLongId)
                  ?.delivery ==
              AttachmentDelivery.local &&
          application.conversations
                  .find(agentNativeLongId)
                  ?.draftAttachmentIds
                  .length ==
              1,
      'the locally saved and verified draft attachment',
    );
    final selected = application.conversations.find(agentNativeLongId)!;
    _attachment = selected.attachments.single;
    requireAgentFeature(
      selected.draft.isEmpty && journey.field.controller!.text.isEmpty,
      'The attachment-only draft still contains text.',
    );
    final card = journey.key('agent-draft-attachments');
    await journey.reveal(card, 'the locally saved attachment card');
    requireAgentFeature(
      find
              .descendant(of: card, matching: find.byType(Image))
              .evaluate()
              .isEmpty &&
          journey.key('agent-attachment-preview').evaluate().isEmpty,
      'An attachment was previewed before an explicit preview action.',
    );
    _assertRequests(0);
    return {
      'picker': _picker.toJson(),
      'attachment': await _storedAttachment(journey),
      'draftText': journey.field.controller!.text,
      'delivery': application.binaryAttachments
          .progressFor(agentNativeLongId)!
          .delivery
          .name,
      'previewOpenedAutomatically': false,
      'provider': providerReport(),
      'initialShortHistorySha256': _shortHistoryDigest,
      'configuration': journey.assertOwner(),
    };
  }

  Future<Map<String, Object?>> _previewImage(
    AgentFeatureJourney journey,
    Finder menu, {
    required int expectedRequests,
  }) async {
    final context = journey.tester.element(menu);
    final previewText = AppLocalizations.of(context).agentFilePreview;
    await journey.tap(menu, 'the explicit attachment action menu');
    await journey.tap(
      find.text(previewText),
      'the explicit Preview file action',
    );
    final dialog = journey.key('agent-attachment-preview');
    await journey.until(
      () => dialog.evaluate().length == 1,
      'the actual attachment preview dialog',
    );
    final raw = find.descendant(of: dialog, matching: find.byType(RawImage));
    await journey.until(
      () =>
          raw.evaluate().length == 1 &&
          journey.tester.widget<RawImage>(raw).image != null,
      'an actually decoded local preview image',
    );
    await journey.reveal(raw, 'the decoded preview image');
    final rendered = journey.tester.renderObject<RenderImage>(raw);
    final decoded = rendered.image!;
    final image = journey.tester.widget<Image>(
      find.descendant(of: dialog, matching: find.byType(Image)),
    );
    final actualProvider = image.image;
    final memory = actualProvider is ResizeImage
        ? actualProvider.imageProvider
        : actualProvider;
    requireAgentFeature(
      memory is MemoryImage &&
          _bytesDigest(memory.bytes) == _pngSha256 &&
          decoded.width > 0 &&
          decoded.height > 0 &&
          decoded.width == decoded.height &&
          rendered.hasSize &&
          rendered.size.width > 0 &&
          rendered.size.height > 0,
      'The rendered preview did not decode the verified synthetic PNG bytes.',
    );
    _previewProviders.add(actualProvider);
    _previewCount++;
    final observations = <String, Object?>{
      'openedWith': 'attachment menu / Preview file',
      'dialogKey': 'agent-attachment-preview',
      'imageSha256': _bytesDigest((memory as MemoryImage).bytes),
      'decodedWidth': decoded.width,
      'decodedHeight': decoded.height,
      'renderedWidth': rendered.size.width,
      'renderedHeight': rendered.size.height,
      'previewCount': _previewCount,
      'configuration': journey.configurationAt(journey.tester.element(dialog)),
    };
    final closeText = MaterialLocalizations.of(journey.tester.element(dialog))
        .closeButtonLabel;
    final close = find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextButton, closeText),
    );
    await journey.reveal(close, 'the preview Close button');
    await journey.tap(close, 'the preview Close button');
    await journey.until(
      () => dialog.evaluate().isEmpty,
      'the explicitly closed preview',
    );
    _assertRequests(expectedRequests);
    return {
      ...observations,
      'closedWithButton': true,
      'providerRequests': _provider.requests,
    };
  }

  Future<Map<String, Object?>> _previewDraft(
    AgentFeatureJourney journey,
  ) async {
    final card = journey.key('agent-draft-attachments');
    final menu = find.descendant(
      of: card,
      matching: journey.key('agent-attachment-menu-${_attachment!.id}'),
    );
    await journey.reveal(menu, 'the draft attachment menu');
    final preview = await _previewImage(journey, menu, expectedRequests: 0);
    return {
      'preview': preview,
      'attachment': await _storedAttachment(journey),
      'provider': providerReport(),
    };
  }

  Future<Map<String, Object?>> _send(AgentFeatureJourney journey) async {
    requireAgentFeature(
      journey.field.controller!.text.isEmpty,
      'The attachment-only request contains text.',
    );
    await journey.tap(
      journey.key('agent-send'),
      'the explicit attachment-only Send button',
    );
    await journey.until(
      () =>
          _provider.requests == 1 &&
          !journey.session.app.agent.runtime.state.value
              .runFor(agentNativeLongId)
              .isActive &&
          journey.session.app.agent.conversations
                  .find(agentNativeLongId)
                  ?.status ==
              ConversationStatus.idle &&
          _provider.streamSettled &&
          _provider.transport.responseSettled,
      'the single decoded attachment reply and settled production run',
    );
    await journey.session.app.agent.runtime.waitForIdle().timeout(
      const Duration(seconds: 20),
    );
    await journey.session.app.agent.conversations
        .waitForPendingWrites()
        .timeout(const Duration(seconds: 20));
    final saved = ConversationArchive.decode(journey.session.chatSource);
    final long = saved.conversations.singleWhere(
      (item) => item.id == agentNativeLongId,
    );
    requireAgentFeature(
      long.messages.length == agentNativeMessageCount + 2,
      'The attachment-only send did not append exactly one user input and one reply.',
    );
    final input = long.messages[agentNativeMessageCount];
    _userMessageId = input.id;
    requireAgentFeature(
      input.role == ConversationRole.user &&
          input.text.isEmpty &&
          input.attachmentIds.length == 1 &&
          input.attachmentIds.single == _attachment!.id &&
          input.attachmentDelivery == AttachmentDelivery.accepted &&
          long.messages.last.role == ConversationRole.assistant &&
          long.messages.last.text == _reply &&
          long.draftAttachmentIds.isEmpty &&
          long.draft.isEmpty &&
          AgentNativeSession.historyDigest(
                long.messages.take(agentNativeMessageCount),
              ) ==
              journey.session.originalHistoryDigest,
      'The saved attachment input, reply, delivery state or original history is incorrect.',
    );
    requireAgentFeature(
      _provider.completedReplies == 1,
      'The explicit attachment request did not finish exactly once.',
    );
    final completion = _completedRunEvidence(long);
    _assertRequests(1);
    await journey.enterDraft(_nextDraft);
    return {
      'userMessageId': input.id,
      'userText': input.text,
      'userAttachmentIds': input.attachmentIds,
      'attachmentDelivery': input.attachmentDelivery.name,
      'deliveryScope':
          'synthetic transport acceptance through the production provider',
      'reply': long.messages.last.text,
      ...completion,
      'savedLongMessageCount': long.messages.length,
      'savedOriginalHistorySha256': AgentNativeSession.historyDigest(
        long.messages.take(agentNativeMessageCount),
      ),
      'nextDraft': journey.field.controller!.text,
      'attachment': await _storedAttachment(journey),
      'provider': providerReport(),
      'configuration': journey.assertOwner(),
    };
  }

  Future<void> _selectConversation(
    AgentFeatureJourney journey,
    String id,
  ) async {
    await journey.tap(
      journey.key('agent-history'),
      'the real conversation list action',
    );
    final list = find
        .byKey(const PageStorageKey('agent-conversation-list'))
        .hitTestable();
    await journey.until(
      () => list.evaluate().length == 1,
      'the actual conversation list',
    );
    final row = journey.key('agent-history-$id');
    await journey.reveal(row, 'the chosen conversation row', scrollable: list);
    await journey.tap(row, 'the chosen conversation row');
    await journey.until(
      () =>
          journey.session.app.agent.conversations.selectedId == id &&
          journey.key('agent-history-drawer').evaluate().isEmpty &&
          journey.composer.evaluate().length == 1,
      'the selected conversation after its list closes',
    );
  }

  Future<Map<String, Object?>> _revealSavedAttachmentMenu(
    AgentFeatureJourney journey,
    Finder menu,
    Finder transcript,
  ) async {
    final initiallyVisible = menu.hitTestable().evaluate().length == 1;
    final drags = <double>[];
    // User scrolling leaves follow-latest mode. Programmatic ensureVisible
    // does not, so a later transcript layout can return it to the last reply.
    for (
      var attempt = 0;
      attempt < 12 && menu.hitTestable().evaluate().length != 1;
      attempt++
    ) {
      await journey.until(
        () => transcript.hitTestable().evaluate().length == 1,
        'the reopened attachment transcript',
      );
      final candidates = menu.evaluate();
      requireAgentFeature(
        candidates.length <= 1,
        'The reopened attachment menu is duplicated.',
      );
      final viewport = journey.tester.getRect(transcript.hitTestable());
      final target = candidates.isEmpty ? null : journey.tester.getRect(menu);
      final distance = (viewport.height * 0.55).clamp(80.0, 180.0).toDouble();
      final delta = target != null && target.center.dy < viewport.center.dy
          ? distance
          : -distance;
      drags.add(delta);
      await journey.tester.drag(transcript.hitTestable(), Offset(0, delta));
      await journey.tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
    }
    await journey.until(
      () => menu.hitTestable().evaluate().length == 1,
      'the saved attachment menu after real transcript scrolling',
    );
    return {
      'method': 'framework transcript drag',
      'initiallyVisible': initiallyVisible,
      'dragCount': drags.length,
      'verticalDeltas': drags,
      'menuHitTestable': true,
    };
  }

  Future<Map<String, Object?>> _reopen(AgentFeatureJourney journey) async {
    await _selectConversation(journey, agentNativeShortId);
    requireAgentFeature(
      journey.field.controller!.text == agentNativeShortDraft &&
          journey.session.app.agent.conversations
              .find(agentNativeShortId)!
              .attachments
              .isEmpty,
      'Opening the independent short conversation inherited the long draft or attachment.',
    );
    _assertRequests(1);
    await _selectConversation(journey, agentNativeLongId);
    journey.assertOwner();
    requireAgentFeature(
      journey.field.controller!.text == _nextDraft,
      'Reopening the attachment conversation lost its next draft.',
    );
    final transcript = journey
        .key('agent-transcript-$agentNativeLongId')
        .hitTestable();
    final menu = journey.key('agent-attachment-menu-${_attachment!.id}');
    final menuReveal = await _revealSavedAttachmentMenu(
      journey,
      menu,
      transcript,
    );
    final list = journey.tester.widget<AgentAttachmentList>(
      find.ancestor(of: menu, matching: find.byType(AgentAttachmentList)),
    );
    requireAgentFeature(
      list.delivery == AttachmentDelivery.accepted &&
          list.ids.length == 1 &&
          list.ids.single == _attachment!.id &&
          identical(list.repository, journey.session.app.agent.attachmentStore),
      'The reopened message card does not use the saved attachment and actual byte store.',
    );
    final preview = await _previewImage(journey, menu, expectedRequests: 1);
    final attachment = await _storedAttachment(journey);
    await journey.session.app.session.repository
        .waitForPendingWrites(propagateErrors: true)
        .timeout(const Duration(seconds: 20));
    final saved = ConversationArchive.decode(journey.session.chatSource);
    final long = saved.conversations.singleWhere(
      (item) => item.id == agentNativeLongId,
    );
    final short = saved.conversations.singleWhere(
      (item) => item.id == agentNativeShortId,
    );
    final input = long.messages[agentNativeMessageCount];
    requireAgentFeature(
      saved.selectedId == agentNativeLongId &&
          saved.conversations.length == 2 &&
          long.messages.length == agentNativeMessageCount + 2 &&
          long.draft == _nextDraft &&
          input.id == _userMessageId &&
          input.text.isEmpty &&
          input.attachmentIds.length == 1 &&
          input.attachmentIds.single == _attachment!.id &&
          input.attachmentDelivery == AttachmentDelivery.accepted &&
          long.messages.last.text == _reply &&
          short.attachments.isEmpty &&
          short.messages.length == 2 &&
          short.draft == agentNativeShortDraft &&
          AgentNativeSession.historyDigest(short.messages) ==
              _shortHistoryDigest &&
          AgentNativeSession.historyDigest(
                long.messages.take(agentNativeMessageCount),
              ) ==
              journey.session.originalHistoryDigest &&
          journey.session.mainSource == journey.mainAtEntry,
      'Reopening attachments changed the stored drafts, original histories or main workspace.',
    );
    _assertRequests(1);
    return {
      'route': 'long conversation / short conversation / long conversation',
      'menuReveal': menuReveal,
      'sameApplicationAndRepository': true,
      'selectedId': saved.selectedId,
      'conversationCount': saved.conversations.length,
      'savedLongMessageCount': long.messages.length,
      'savedShortMessageCount': short.messages.length,
      'savedOriginalHistorySha256': AgentNativeSession.historyDigest(
        long.messages.take(agentNativeMessageCount),
      ),
      'savedShortHistorySha256': AgentNativeSession.historyDigest(
        short.messages,
      ),
      'visibleDraft': journey.field.controller!.text,
      'savedLongDraft': long.draft,
      'savedShortDraft': short.draft,
      'savedShortAttachmentCount': short.attachments.length,
      'userMessageId': input.id,
      'userAttachmentIds': input.attachmentIds,
      'attachmentDelivery': input.attachmentDelivery.name,
      'reply': long.messages.last.text,
      ..._completedRunEvidence(long),
      'attachment': attachment,
      'preview': preview,
      'provider': providerReport(),
      'picker': _picker.toJson(),
      'mainSnapshotUnchangedSinceEntry': true,
      'mainSha256': agentNativeDigest(journey.session.mainSource),
      'storage': journey.session.storageReport(),
      'configuration': journey.assertOwner(),
    };
  }
}
