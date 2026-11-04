import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/attachments/attachment_repository.dart';
import 'package:sked/agent/ui/agent_attachment_view.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/widgets/sked_popup_menu.dart';

import 'agent_ui_test_support.dart';

void main() {
  Finder menu() => find.byKey(const ValueKey('agent-attachment-menu-file'));
  Finder preview() => find.byKey(const ValueKey('agent-attachment-preview'));

  for (final boundary in ['activity', 'interaction', 'conversation']) {
    testWidgets(
      'an open attachment menu expires across the $boundary boundary',
      (tester) async {
        addTearDown(tester.view.reset);
        final fixture = (await tester.runAsync(() async => _Fixture()))!;
        addTearDown(fixture.close);
        var active = true;
        var interactive = true;
        var conversationId = 'first';
        late StateSetter change;
        final calls = <String>[];
        await mountAgentUi(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return AgentAttachmentList(
                conversationId: conversationId,
                attachments: [fixture.attachment],
                ids: const ['file'],
                repository: fixture.repository,
                active: active,
                interactive: interactive,
                onRemove: (id) => calls.add('remove:$id'),
                onUseAgain: (id) => calls.add('reuse:$id'),
              );
            },
          ),
        );
        final retained = tester.state(find.byType(AgentAttachmentList));
        await tester.tap(menu());
        await tester.pumpAndSettle();
        final stale = tester
            .widget<SkedPopupMenuButton<String>>(menu())
            .onSelected!;
        change(() {
          active = boundary != 'activity';
          interactive = boundary != 'interaction';
          conversationId = boundary == 'conversation' ? 'second' : 'first';
        });
        await tester.pump();
        change(() {
          active = true;
          interactive = true;
          conversationId = 'first';
        });
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(AgentAttachmentList)), same(retained));
        // A real route result reaches the rebuilt trigger callback, while other
        // queued callbacks may still hold its older function identity.
        await tester.tap(find.text('Preview file'));
        await tester.pumpAndSettle();
        stale('preview');
        stale('reuse');
        stale('remove');
        await tester.pumpAndSettle();
        expect(preview(), findsNothing);
        expect(fixture.storage.reads, 0);
        expect(calls, isEmpty);
        await tester.tap(menu());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Use in the next message'));
        await tester.pumpAndSettle();
        expect(calls, ['reuse:file']);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'changed attachment metadata expires a menu even if the ID returns',
    (tester) async {
      addTearDown(tester.view.reset);
      final fixture = (await tester.runAsync(() async => _Fixture()))!;
      addTearDown(fixture.close);
      var attachment = fixture.attachment;
      late StateSetter change;
      final removed = <String>[];
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return AgentAttachmentList(
              conversationId: 'first',
              attachments: [attachment],
              ids: const ['file'],
              repository: fixture.repository,
              onRemove: removed.add,
            );
          },
        ),
      );
      await tester.tap(menu());
      await tester.pumpAndSettle();
      change(
        () => attachment = ConversationAttachment(
          id: 'file',
          name: 'Replacement.txt',
          mediaType: fixture.attachment.mediaType,
          byteLength: fixture.attachment.byteLength,
          digest: fixture.attachment.digest,
        ),
      );
      await tester.pump();
      change(() => attachment = fixture.attachment);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove attachment'));
      await tester.pumpAndSettle();
      expect(removed, isEmpty);
      expect(fixture.storage.reads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a hidden preview retires its own route and cannot close a newer page',
    (tester) async {
      addTearDown(tester.view.reset);
      final fixture = (await tester.runAsync(() async => _Fixture()))!;
      addTearDown(fixture.close);
      var active = true;
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return AgentAttachmentList(
              conversationId: 'first',
              attachments: [fixture.attachment],
              ids: const ['file'],
              repository: fixture.repository,
              active: active,
            );
          },
        ),
      );
      final navigator = Navigator.of(
        tester.element(menu()),
        rootNavigator: true,
      );
      final l = AppLocalizations.of(tester.element(menu()));
      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview file'));
      await _pumpUntil(
        tester,
        () => find.text(l.agentFileNoPreview).evaluate().isNotEmpty,
        'the first local preview finishes verifying its bytes',
      );
      await tester.pumpAndSettle();
      expect(preview(), findsOneWidget);
      expect(fixture.storage.reads, 1);
      final oldClose = tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
          .onPressed!;
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Independent page')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      change(() => active = false);
      await tester.pumpAndSettle();
      change(() => active = true);
      await tester.pumpAndSettle();
      oldClose();
      await tester.pumpAndSettle();
      expect(find.text('Independent page'), findsOneWidget);
      expect(preview().evaluate(), isEmpty);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(preview(), findsNothing);
      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview file'));
      await _pumpUntil(
        tester,
        () => find.text(l.agentFileNoPreview).evaluate().isNotEmpty,
        'the reopened local preview finishes verifying its bytes',
      );
      await tester.pumpAndSettle();
      expect(preview(), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(preview(), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a delayed preview read cannot publish after the host is hidden',
    (tester) async {
      addTearDown(tester.view.reset);
      final fixture = (await tester.runAsync(
        () async => _Fixture(storage: _DelayedStorage()),
      ))!;
      final storage = fixture.storage as _DelayedStorage;
      addTearDown(() async {
        if (!storage.release.isCompleted) storage.release.complete();
        await fixture.close();
      });
      var interactive = true;
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return AgentAttachmentList(
              conversationId: 'first',
              attachments: [fixture.attachment],
              ids: const ['file'],
              repository: fixture.repository,
              interactive: interactive,
            );
          },
        ),
      );
      final l = AppLocalizations.of(tester.element(menu()));
      await tester.tap(menu());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preview file'));
      await tester.pump();
      expect(storage.entered.isCompleted, isTrue);
      change(() => interactive = false);
      await tester.pumpAndSettle();
      change(() => interactive = true);
      await tester.pump();
      storage.release.complete();
      await tester.pumpAndSettle();
      expect(preview(), findsNothing);
      expect(find.text(l.agentFileNoPreview), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final direction in TextDirection.values) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'attachment menu keeps its 48dp target at 320dp, 2x, $direction, $brightness',
        (tester) async {
          addTearDown(tester.view.reset);
          final fixture = (await tester.runAsync(() async => _Fixture()))!;
          addTearDown(fixture.close);
          await mountAgentUi(
            tester,
            Directionality(
              textDirection: direction,
              child: AgentAttachmentList(
                conversationId: 'first',
                attachments: [fixture.attachment],
                ids: const ['file'],
                repository: fixture.repository,
              ),
            ),
            size: const Size(320, 640),
            scale: 2,
            brightness: brightness,
          );
          final rect = tester.getRect(menu());
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          final navigator = Navigator.of(
            tester.element(menu()),
            rootNavigator: true,
          );
          for (final x in [.08, .5, .92]) {
            for (final y in [.08, .5, .92]) {
              await tester.tapAt(
                Offset(rect.left + rect.width * x, rect.top + rect.height * y),
              );
              await tester.pumpAndSettle();
              expect(find.byType(SkedPopupMenuItem<String>), findsOneWidget);
              navigator.pop();
              await tester.pumpAndSettle();
            }
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }
}

/// Pumps widget frames and the storage's real zone until its visible result.
/// An indeterminate loader cannot settle while its read still needs a real-zone
/// continuation; waiting for a specific preview result also verifies the read.
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
  _Fixture({_CountingStorage? storage})
    : storage = storage ?? _CountingStorage() {
    final bytes = Uint8List.fromList([1, 2, 3]);
    this.storage.values['file'] = bytes;
    attachment = ConversationAttachment(
      id: 'file',
      name: 'A long attachment name with a readable description.txt',
      mediaType: 'text/plain',
      byteLength: bytes.length,
      digest: sha256.convert(bytes).toString(),
    );
    repository = AttachmentRepository(storage: this.storage);
  }
  final _CountingStorage storage;
  late final ConversationAttachment attachment;
  late final AttachmentRepository repository;

  // The repository is created in runAsync's real zone. Dart `await` on a
  // completed fake-zone Future can still enqueue its continuation there after
  // the widget test has stopped pumping; keep storage teardown in one zone.
  Future<void> close() =>
      repository.close().timeout(const Duration(seconds: 10));
}

class _CountingStorage extends MemoryAttachmentStorage {
  int reads = 0;
  @override
  Stream<List<int>> read(String id) {
    reads++;
    return super.read(id);
  }
}

class _DelayedStorage extends _CountingStorage {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Stream<List<int>> read(String id) async* {
    entered.complete();
    await release.future;
    yield* super.read(id);
  }
}
