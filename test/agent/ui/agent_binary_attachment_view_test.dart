import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/agent/ui/agent_ui_delegate.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import 'agent_ui_test_support.dart';

void main() {
  _testWithFixture(
    'an arbitrary file is saved locally and can be sent without text',
    (tester, fixture) async {
      fixture.selected = XFile.fromData(
        Uint8List.fromList([0, 255, 2]),
        path: 'payload.custom',
        name: 'payload.custom',
      );
      await mountAgentUi(tester, fixture.view());
      expect(find.byTooltip('Attach a file'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
      await _pumpUntil(
        tester,
        () =>
            fixture.conversations.selected!.draftAttachmentIds.length == 1 &&
            !fixture.files.isImporting(fixture.id),
        'the selected file is verified and its draft reference is saved',
      );
      await tester.pumpAndSettle();
      final attachment = fixture.conversations.selected!.attachments.single;
      expect(attachment.mediaType, 'application/octet-stream');
      expect(find.text('payload.custom'), findsOneWidget);
      expect(find.text('Saved on this device'), findsOneWidget);
      expect(fixture.delegate.calls, isEmpty);
      await tester.ensureVisible(find.byKey(const ValueKey('agent-send')));
      await tester.tap(find.byKey(const ValueKey('agent-send')));
      await tester.pumpAndSettle();
      expect(fixture.delegate.calls, ['send:${fixture.id}:']);
      expect(await tester.runAsync(() => fixture.store.readBytes(attachment)), [
        0,
        255,
        2,
      ]);
    },
  );

  _testWithFixture(
    'failed reference publication can retry after the panel reopens',
    (tester, fixture) async {
      fixture.selected = XFile.fromData(
        Uint8List.fromList([1]),
        path: 'notes.pdf',
        name: 'notes.pdf',
      );
      await mountAgentUi(tester, fixture.view());
      fixture.chatStorage.fail = true;
      await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
      await _pumpUntil(
        tester,
        () =>
            fixture.files.hasPending(fixture.id) &&
            !fixture.files.isImporting(fixture.id),
        'the failed reference save retains a verified retry',
      );
      await tester.pumpAndSettle();
      expect(fixture.files.hasPending(fixture.id), isTrue);
      expect(fixture.conversations.canWrite, isFalse);
      expect(fixture.blobs.values, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      fixture.chatStorage.fail = false;
      await mountAgentUi(tester, fixture.view());
      final retry = find.byKey(const ValueKey('agent-retry-binary-attachment'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await _pumpUntil(
        tester,
        () =>
            !fixture.files.hasPending(fixture.id) &&
            fixture.conversations.selected!.draftAttachmentIds.length == 1,
        'the same reference is saved after reopening',
      );
      await tester.pumpAndSettle();
      expect(fixture.files.hasPending(fixture.id), isFalse);
      expect(fixture.conversations.selected!.attachments, hasLength(1));
      expect(fixture.blobs.values, hasLength(1));
      expect(fixture.delegate.calls, isEmpty);
    },
  );

  _testWithFixture(
    'cancelling a stalled import publishes no attachment or model request',
    (tester, fixture) async {
      final stalled = (await tester.runAsync(() async => _StalledFile()))!;
      fixture.selected = stalled;
      await mountAgentUi(tester, fixture.view());
      await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
      await _pumpUntil(
        tester,
        () => stalled.entered.isCompleted,
        'the file stream is open before cancellation',
      );
      await tester.pump();
      final cancel = find.byKey(const ValueKey('agent-cancel-attachment'));
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await _pumpUntil(
        tester,
        () =>
            !fixture.files.isImporting(fixture.id) &&
            fixture.files.progressFor(fixture.id)?.delivery ==
                AttachmentDelivery.cancelled,
        'cancellation settles the local copy',
      );
      await tester.pumpAndSettle();
      expect(fixture.conversations.selected!.attachments, isEmpty);
      expect(fixture.delegate.calls, isEmpty);
      expect(fixture.blobs.values, isEmpty);
      expect(find.text('File transfer stopped'), findsOneWidget);
      await tester.runAsync(stalled.chunks.close);
    },
  );

  _testWithFixture(
    'a picker result from a previous data generation cannot attach',
    (tester, fixture) async {
      final picker = Completer<XFile?>();
      fixture.pick = () => picker.future;
      await mountAgentUi(tester, fixture.view());
      await tester.tap(find.byKey(const ValueKey('agent-attach-file')));
      await tester.pump();
      fixture.generation = 'new-data';
      picker.complete(
        XFile.fromData(
          Uint8List.fromList([1]),
          path: 'old.pdf',
          name: 'old.pdf',
        ),
      );
      await tester.pumpAndSettle();
      expect(fixture.conversations.selected!.attachments, isEmpty);
      expect(fixture.blobs.values, isEmpty);
      expect(find.textContaining('conversation changed while'), findsOneWidget);
    },
  );

  _testWithFixture(
    'local image preview is explicit and history can reuse its bytes',
    (tester, fixture) async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD5sAAAAASUVORK5CYII=',
      );
      await tester.runAsync(
        () => fixture.files.attach(
          fixture.id,
          XFile.fromData(png, path: 'sample.png', name: 'sample.png'),
          canModify: () => true,
        ),
      );
      final attachment = fixture.conversations.selected!.attachments.single;
      await tester.runAsync(
        () => fixture.conversations.update(
          fixture.id,
          (current) => current.copyWith(
            draftAttachmentIds: [],
            messages: [
              ConversationMessage(
                id: 'file-message',
                role: ConversationRole.user,
                text: '',
                createdAt: DateTime.utc(2026),
                attachmentIds: [attachment.id],
                attachmentDelivery: AttachmentDelivery.accepted,
              ),
            ],
          ),
        ),
      );
      await mountAgentUi(tester, fixture.view());
      expect(find.byType(Image), findsNothing);
      expect(find.text('Accepted by the service'), findsOneWidget);
      await tester.runAsync(
        () => tester.tap(
          find.byKey(ValueKey('agent-attachment-menu-${attachment.id}')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SkedPopupMenuItem<String>), findsNWidgets(2));
      await tester.tap(find.text('Preview file'));
      await _pumpUntil(
        tester,
        () => find.byType(Image).evaluate().isNotEmpty,
        'the local preview finishes reading the verified bytes',
      );
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-attachment-preview')),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.tap(
          find.byKey(ValueKey('agent-attachment-menu-${attachment.id}')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use in the next message'));
      await _pumpUntil(
        tester,
        () => fixture.conversations.selected!.draftAttachmentIds.contains(
          attachment.id,
        ),
        'the historical file is referenced by the current draft',
      );
      await tester.pumpAndSettle();
      expect(fixture.conversations.selected!.draftAttachmentIds, [
        attachment.id,
      ]);
      expect(fixture.blobs.values, hasLength(1));
      final draft = find.byKey(const ValueKey('agent-draft-attachments'));
      final menu = find.descendant(
        of: draft,
        matching: find.byKey(
          ValueKey('agent-attachment-menu-${attachment.id}'),
        ),
      );
      await tester.ensureVisible(menu);
      await tester.runAsync(() => tester.tap(menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove attachment'));
      await _pumpUntil(
        tester,
        () => fixture.conversations.selected!.draftAttachmentIds.isEmpty,
        'only the draft reference is removed',
      );
      await tester.pumpAndSettle();
      expect(fixture.conversations.selected!.draftAttachmentIds, isEmpty);
      expect(fixture.blobs.values, hasLength(1));
    },
  );

  _testWithFixture(
    'missing history bytes report a real error and do not queue a filename',
    (tester, fixture) async {
      await tester.runAsync(
        () => fixture.files.attach(
          fixture.id,
          XFile.fromData(
            Uint8List.fromList([1]),
            path: 'lost.pdf',
            name: 'lost.pdf',
          ),
          canModify: () => true,
        ),
      );
      final attachment = fixture.conversations.selected!.attachments.single;
      await tester.runAsync(
        () => fixture.conversations.update(
          fixture.id,
          (current) => current.copyWith(
            draftAttachmentIds: [],
            messages: [
              ConversationMessage(
                id: 'file-message',
                role: ConversationRole.user,
                text: '',
                createdAt: DateTime.utc(2026),
                attachmentIds: [attachment.id],
                attachmentDelivery: AttachmentDelivery.unknown,
              ),
            ],
          ),
        ),
      );
      fixture.blobs.values.clear();
      await mountAgentUi(tester, fixture.view());
      expect(find.text('Service acceptance is unknown'), findsOneWidget);
      await tester.runAsync(
        () => tester.tap(
          find.byKey(ValueKey('agent-attachment-menu-${attachment.id}')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use in the next message'));
      await _pumpUntil(
        tester,
        () => find
            .textContaining('no longer available on this device')
            .evaluate()
            .isNotEmpty,
        'the unavailable historical bytes are reported',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('no longer available on this device'),
        findsOneWidget,
      );
      expect(fixture.conversations.selected!.draftAttachmentIds, isEmpty);
      expect(fixture.delegate.calls, isEmpty);
    },
  );

  _testWithFixture('attachment-only follow-up remains reachable with 2x text', (
    tester,
    fixture,
  ) async {
    await tester.runAsync(
      () => fixture.files.attach(
        fixture.id,
        XFile.fromData(
          Uint8List.fromList([1]),
          path: 'a very long file name.pdf',
          name: 'a very long file name.pdf',
        ),
        canModify: () => true,
      ),
    );
    fixture.delegate.state.value = AgentUiState(
      enabled: true,
      configured: true,
      runs: {fixture.id: const AgentUiRunState(phase: AgentUiPhase.running)},
    );
    await mountAgentUi(
      tester,
      fixture.view(),
      size: const Size(320, 740),
      scale: 2,
      keyboard: 260,
    );
    final queue = find.byKey(const ValueKey('agent-queue'));
    await tester.ensureVisible(queue);
    await tester.tap(queue);
    await _pumpUntil(
      tester,
      () => fixture.delegate.calls.isNotEmpty,
      'the attachment-only follow-up reaches the delegate',
    );
    await tester.pumpAndSettle();
    expect(fixture.delegate.calls, ['queue:${fixture.id}:']);
    expect(tester.takeException(), isNull);
  });
}

void _testWithFixture(
  String description,
  Future<void> Function(WidgetTester tester, _Fixture fixture) body,
) {
  testWidgets(description, (tester) async {
    addTearDown(tester.view.reset);
    final fixture = (await tester.runAsync(_Fixture.create))!;
    try {
      await body(tester, fixture);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      var closed = false;
      final closing = fixture.close().whenComplete(() => closed = true);
      await _pumpUntil(
        tester,
        () => closed,
        'the fixture stores finish closing',
      );
      await closing;
    }
  });
}

/// Pump frames and both async zones until the operation's observable result.
/// A snapshot of a queue can settle before the picker has admitted its work.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() settled,
  String reason,
) async {
  final elapsed = Stopwatch()..start();
  while (!settled() && elapsed.elapsed < const Duration(seconds: 10)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(settled(), isTrue, reason: reason);
}

class _Fixture {
  _Fixture(this.conversations, this.id, this.chatStorage) {
    files = ConversationAttachments(
      conversations: conversations,
      repository: store,
    );
    delegate = UiDelegate(conversations);
  }
  final ConversationRepository conversations;
  final String id;
  final UiMemoryStorage chatStorage;
  final blobs = MemoryAttachmentStorage();
  late final store = AttachmentRepository(storage: blobs);
  late final ConversationAttachments files;
  late final UiDelegate delegate;
  XFile? selected;
  Future<XFile?> Function()? pick;
  String generation = 'data';

  static Future<_Fixture> create() async {
    final storage = UiMemoryStorage();
    final conversations = ConversationRepository(storage: storage);
    await conversations.load();
    final id = (await conversations.create(title: 'Files')).id;
    // This fixture and its byte-stream operations share runAsync's real zone.
    // Widget frames settle separately after storage reports actual completion.
    return _Fixture(conversations, id, storage);
  }

  Future<void> close() async {
    await files.close();
    await conversations.waitForPendingWrites();
    files.dispose();
    conversations.dispose();
    delegate.state.dispose();
  }

  Widget view() => AgentConversationView(
    repository: conversations,
    delegate: delegate,
    binaryAttachments: files,
    readDatasetGeneration: () => generation,
    pickBinaryAttachment: () => pick?.call() ?? Future.value(selected),
  );
}

class _StalledFile extends XFile {
  _StalledFile() : super('unused', name: 'waiting.bin');
  final entered = Completer<void>();
  final chunks = StreamController<Uint8List>();
  @override
  Future<int> length() async => 3;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) {
    if (!entered.isCompleted) entered.complete();
    return chunks.stream;
  }
}
