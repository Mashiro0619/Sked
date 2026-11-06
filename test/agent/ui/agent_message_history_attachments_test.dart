import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/attachments/conversation_attachments.dart';
import 'package:sked/agent/conversations/conversation_repository.dart';
import 'package:sked/agent/history/conversation_history.dart';
import 'package:sked/agent/ui/agent_attachment_view.dart';
import 'package:sked/agent/ui/agent_conversation_view.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import 'agent_ui_test_support.dart';

void main() {
  for (final text in ['', 'Previous attachment explanation']) {
    _testWithFixture('history displays and previews files with text "$text"', (
      tester,
      fixture,
    ) async {
      await tester.runAsync(() => fixture.setHistory(text: text));
      await mountAgentUi(tester, fixture.view());
      expect(find.text(fixture.file.name), findsNothing);
      await _openHistory(tester);
      final list = tester.widget<AgentAttachmentList>(
        find.byType(AgentAttachmentList),
      );
      expect(list.ids, [fixture.file.id]);
      expect(list.onRemove, isNull);
      expect(list.onUseAgain, isNull);
      expect(find.text(fixture.file.name), findsOneWidget);
      if (text.isNotEmpty) expect(find.text(text), findsOneWidget);
      await _openPreview(tester, fixture.file.id);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      await _pumpUntil(
        tester,
        () => find.text(l.agentFileNoPreview).evaluate().isNotEmpty,
      );
      expect(
        find.byKey(const ValueKey('agent-attachment-preview')),
        findsOneWidget,
      );
      expect(fixture.conversations.selected!.draftAttachmentIds, isEmpty);
      expect(fixture.delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  _testWithFixture('missing historical bytes report the file error', (
    tester,
    fixture,
  ) async {
    fixture.blobs.values.clear();
    await mountAgentUi(tester, fixture.view());
    await _openHistory(tester);
    await _openPreview(tester, fixture.file.id);
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentConversationView)),
    );
    await _pumpUntil(
      tester,
      () => find.text(l.agentFileMissing).evaluate().isNotEmpty,
    );
    expect(find.text(fixture.file.name), findsNWidgets(2));
    expect(
      fixture
          .conversations
          .selected!
          .historyVersions
          .single
          .messages
          .single
          .attachmentIds,
      [fixture.file.id],
    );
    expect(tester.takeException(), isNull);
  });

  _testWithFixture(
    'history keeps metadata readable without an attachment service',
    (tester, fixture) async {
      await mountAgentUi(tester, fixture.view(withAttachments: false));
      await _openHistory(tester);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      expect(find.text(fixture.file.name), findsOneWidget);
      expect(find.text(l.agentFileUnavailable), findsOneWidget);
      expect(find.byType(AgentAttachmentList), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final boundary in [
    'activity',
    'interaction',
    'history',
    'dataset',
    'repository',
  ]) {
    _testWithFixture('historical preview expires across $boundary changes', (
      tester,
      fixture,
    ) async {
      await mountAgentUi(tester, fixture.view());
      await _openHistory(tester);
      await _openPreview(tester, fixture.file.id);
      final l = AppLocalizations.of(
        tester.element(find.byType(AgentConversationView)),
      );
      await _pumpUntil(
        tester,
        () => find.text(l.agentFileNoPreview).evaluate().isNotEmpty,
      );
      switch (boundary) {
        case 'activity':
          await mountAgentUi(tester, fixture.view(active: false));
          await mountAgentUi(tester, fixture.view());
        case 'interaction':
          await mountAgentUi(tester, fixture.view(interactive: false));
          await mountAgentUi(tester, fixture.view());
        case 'history':
          await tester.runAsync(
            () => fixture.conversations.update(
              fixture.id,
              (value) => value.copyWith(historyVersions: []),
            ),
          );
        case 'dataset':
          fixture.generation = 'restored';
          await mountAgentUi(tester, fixture.view());
        case 'repository':
          await mountAgentUi(
            tester,
            AgentConversationView(
              repository: fixture.replacement,
              delegate: fixture.replacementDelegate,
            ),
          );
      }
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.delegate.calls, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _openHistory(WidgetTester tester) async {
  final menu = tester.widget<SkedPopupMenuButton<String>>(
    find.byKey(const ValueKey('agent-conversation-menu')),
  );
  menu.onSelected!.call('message-history');
  await tester.pumpAndSettle();
  final dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget);
  await tester.tap(
    find.descendant(of: dialog, matching: find.byType(ExpansionTile)),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPreview(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(ValueKey('agent-attachment-menu-$id')));
  await tester.pumpAndSettle();
  final l = AppLocalizations.of(
    tester.element(find.byType(AgentConversationView)),
  );
  await tester.tap(find.text(l.agentFilePreview).last);
  await tester.pump();
}

void _testWithFixture(
  String description,
  Future<void> Function(WidgetTester, _Fixture) body,
) {
  testWidgets(description, (tester) async {
    addTearDown(tester.view.reset);
    final fixture = (await tester.runAsync(_Fixture.create))!;
    try {
      await body(tester, fixture);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      var closed = false;
      final closing = fixture.attachments.close().whenComplete(
        () => closed = true,
      );
      await _pumpUntil(tester, () => closed);
      await closing;
      fixture.attachments.dispose();
      fixture.conversations.dispose();
      fixture.replacement.dispose();
      fixture.delegate.state.dispose();
      fixture.replacementDelegate.state.dispose();
    }
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() settled) async {
  final elapsed = Stopwatch()..start();
  while (!settled() && elapsed.elapsed < const Duration(seconds: 10)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
  expect(settled(), isTrue);
}

class _Fixture {
  final conversations = ConversationRepository(storage: UiMemoryStorage());
  final replacement = ConversationRepository(storage: UiMemoryStorage());
  final blobs = MemoryAttachmentStorage();
  late final delegate = UiDelegate(conversations);
  late final replacementDelegate = UiDelegate(replacement);
  late final files = AttachmentRepository(storage: blobs);
  late final ConversationAttachments attachments;
  late final String id;
  late final ConversationAttachment file;
  String generation = 'original';
  final time = DateTime.utc(2026, 11, 7);

  static Future<_Fixture> create() async {
    final fixture = _Fixture();
    await fixture.conversations.load();
    await fixture.replacement.load();
    fixture.id = (await fixture.conversations.create(
      title: 'History attachments',
    )).id;
    await fixture.replacement.create(title: 'Replacement');
    final bytes = Uint8List.fromList([1, 2, 3]);
    fixture.file = ConversationAttachment(
      id: 'historical-file',
      name: 'historical-only.pdf',
      mediaType: 'application/pdf',
      byteLength: bytes.length,
      digest: sha256.convert(bytes).toString(),
    );
    fixture.blobs.values[fixture.file.id] = bytes;
    // Construct the service and its futures in the same real zone as storage.
    fixture.attachments = ConversationAttachments(
      conversations: fixture.conversations,
      repository: fixture.files,
    );
    await fixture.setHistory();
    return fixture;
  }

  Future<void> setHistory({String text = ''}) => conversations.update(
    id,
    (value) => value.copyWith(
      attachments: [file],
      messages: [
        ConversationMessage(
          id: 'current',
          role: ConversationRole.user,
          text: 'Current request',
          createdAt: time,
        ),
      ],
      historyVersions: [
        ConversationHistoryVersion(
          id: 'history',
          batchId: 'batch',
          createdAt: time,
          messages: [
            ConversationMessage(
              id: 'old',
              role: ConversationRole.user,
              text: text,
              attachmentIds: [file.id],
              createdAt: time,
            ),
          ],
          runs: [],
          turns: [],
        ),
      ],
    ),
  );

  Widget view({
    bool active = true,
    bool interactive = true,
    bool withAttachments = true,
  }) => AgentConversationView(
    repository: conversations,
    delegate: delegate,
    binaryAttachments: withAttachments ? attachments : null,
    active: active,
    interactive: interactive,
    readDatasetGeneration: () => generation,
  );
}
