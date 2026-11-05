import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_message_actions.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  Finder key(String value) => find.byKey(ValueKey(value));
  Widget body(String id) => SizedBox(
    key: ValueKey('body-$id'),
    height: 80,
    child: Text('Message $id'),
  );

  testWidgets(
    'desktop operations reveal on hover and align beside their owning message',
    (tester) async {
      addTearDown(tester.view.reset);
      final calls = <String>[];
      await mountAgentUi(
        tester,
        Column(
          children: [
            AgentMessageActions(
              messageId: 'user',
              copyText: 'Question',
              isUser: true,
              onEditAndRedo: () => calls.add('edit'),
              child: body('user'),
            ),
            AgentMessageActions(
              messageId: 'reply',
              copyText: 'Answer',
              alwaysVisible: true,
              onRegenerate: () => calls.add('regenerate'),
              child: body('reply'),
            ),
          ],
        ),
      );
      final edit = key('agent-edit-redo-user');
      expect(edit.hitTestable(), findsNothing);
      expect(key('agent-regenerate-reply').hitTestable(), findsOneWidget);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(10, 10));
      await mouse.moveTo(tester.getCenter(key('body-user')));
      await tester.pumpAndSettle();
      expect(edit.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(edit).right,
        closeTo(tester.getRect(key('body-user')).right, 1),
      );
      expect(
        tester.getRect(key('agent-copy-reply')).left,
        closeTo(tester.getRect(key('body-reply')).left, 1),
      );
      await tester.tap(edit);
      await tester.pumpAndSettle();
      await tester.tap(key('agent-regenerate-reply'));
      await tester.pumpAndSettle();
      expect(calls, ['edit', 'regenerate']);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
    semanticsEnabled: false,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'keyboard traversal reveals otherwise hidden desktop actions',
    (tester) async {
      addTearDown(tester.view.reset);
      final before = FocusNode();
      addTearDown(before.dispose);
      await mountAgentUi(
        tester,
        Column(
          children: [
            TextButton(
              focusNode: before,
              autofocus: true,
              onPressed: () {},
              child: const Text('Before'),
            ),
            AgentMessageActions(
              messageId: 'reply',
              copyText: 'Answer',
              onRegenerate: () {},
              child: body('reply'),
            ),
          ],
        ),
      );
      expect(key('agent-copy-reply').hitTestable(), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(key('agent-copy-reply').hitTestable(), findsOneWidget);
      expect(
        Focus.of(tester.element(key('agent-copy-reply'))).hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
    semanticsEnabled: false,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'screen reader activation reveals and operates historical message buttons',
    (tester) async {
      addTearDown(tester.view.reset);
      final calls = <String>[];
      final copied = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await mountAgentUi(
        tester,
        Column(
          children: [
            AgentMessageActions(
              messageId: 'user',
              copyText: 'Saved question',
              isUser: true,
              onEditAndRedo: () => calls.add('edit'),
              child: body('user'),
            ),
            AgentMessageActions(
              messageId: 'reply',
              copyText: 'Saved answer',
              onRegenerate: () => calls.add('regenerate'),
              child: body('reply'),
            ),
          ],
        ),
      );
      expect(key('agent-copy-user').hitTestable(), findsNothing);
      expect(key('agent-regenerate-reply').hitTestable(), findsNothing);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpAndSettle();
        for (final control in [
          'agent-copy-user',
          'agent-edit-redo-user',
          'agent-regenerate-reply',
        ]) {
          final target = key(control);
          expect(target.hitTestable(), findsOneWidget);
          final node = tester.getSemantics(target);
          final data = node.getSemanticsData();
          expect(data.tooltip, isNotEmpty);
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          node.owner!.performAction(node.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
        }
        expect(copied, ['Saved question']);
        expect(calls, ['edit', 'regenerate']);
      } finally {
        semantics.dispose();
      }
      await tester.pumpAndSettle();
      expect(key('agent-copy-user').hitTestable(), findsNothing);
      expect(key('agent-regenerate-reply').hitTestable(), findsNothing);
      expect(tester.takeException(), isNull);
    },
    semanticsEnabled: false,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final hideActivity in [true, false]) {
    testWidgets(
      'screen reader actions retire when host ${hideActivity ? 'activity' : 'interaction'} ends',
      (tester) async {
        addTearDown(tester.view.reset);
        final calls = <String>[];
        var available = true;
        late StateSetter change;
        await mountAgentUi(
          tester,
          StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return AgentMessageActions(
                messageId: 'reply',
                copyText: 'Saved answer',
                active: !hideActivity || available,
                interactive: hideActivity || available,
                onRegenerate: () => calls.add('regenerate'),
                child: body('reply'),
              );
            },
          ),
        );
        final target = key('agent-regenerate-reply');
        expect(target.hitTestable(), findsOneWidget);
        final oldCallback = tester.widget<IconButton>(target).onPressed!;
        final node = tester.getSemantics(target);
        final owner = node.owner!;
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        change(() => available = false);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsNothing);
        final tree = owner.rootSemanticsNode!.toStringDeep();
        expect(tree, isNot(contains('Regenerate reply')));
        expect(Focus.of(tester.element(target)).canRequestFocus, isFalse);
        oldCallback();
        owner.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(calls, isEmpty);
        change(() => available = true);
        await tester.pumpAndSettle();
        oldCallback();
        await tester.pump();
        expect(calls, isEmpty);
        final current = tester.getSemantics(target);
        current.owner!.performAction(current.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(calls, ['regenerate']);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'accessible navigation keeps historical controls visibly discoverable',
    (tester) async {
      addTearDown(tester.view.reset);
      var accessible = false;
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(accessibleNavigation: accessible),
              child: AgentMessageActions(
                messageId: 'reply',
                copyText: 'Saved answer',
                onRegenerate: () {},
                child: body('reply'),
              ),
            );
          },
        ),
      );
      expect(key('agent-regenerate-reply').hitTestable(), findsNothing);
      change(() => accessible = true);
      await tester.pumpAndSettle();
      expect(key('agent-regenerate-reply').hitTestable(), findsOneWidget);
      change(() => accessible = false);
      await tester.pumpAndSettle();
      expect(key('agent-regenerate-reply').hitTestable(), findsNothing);
    },
    semanticsEnabled: false,
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'reused message host rejects callbacks captured before its identity changes',
    (tester) async {
      addTearDown(tester.view.reset);
      var id = 'old';
      late StateSetter change;
      final calls = <String>[];
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            change = setState;
            return AgentMessageActions(
              messageId: id,
              copyText: 'Reply $id',
              onRegenerate: () => calls.add(id),
              child: body(id),
            );
          },
        ),
      );
      final stale = tester
          .widget<IconButton>(key('agent-regenerate-old'))
          .onPressed!;
      change(() => id = 'new');
      await tester.pumpAndSettle();
      stale();
      await tester.pump();
      expect(calls, isEmpty);
      await tester.tap(key('agent-regenerate-new'));
      await tester.pumpAndSettle();
      expect(calls, ['new']);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('late clipboard completion is not published to a restored host', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final gate = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') await gate.future;
      return null;
    });
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    var active = true;
    late StateSetter change;
    await mountAgentUi(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          change = setState;
          return AgentMessageActions(
            messageId: 'reply',
            copyText: 'Answer',
            active: active,
            child: body('reply'),
          );
        },
      ),
    );
    await tester.tap(key('agent-copy-reply'));
    await tester.pump();
    change(() => active = false);
    await tester.pump();
    change(() => active = true);
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentMessageActions)),
    );
    expect(find.byTooltip(l.agentCopied), findsNothing);
    expect(find.byTooltip(l.agentCopyMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final direction in TextDirection.values) {
    testWidgets(
      'touch actions and read-only version navigation fit 320dp at 2x in $direction',
      (tester) async {
        addTearDown(tester.view.reset);
        final selected = <int>[];
        await mountAgentUi(
          tester,
          Directionality(
            textDirection: direction,
            child: AgentMessageActions(
              messageId: 'reply',
              copyText: 'Saved version',
              versionIndex: 1,
              versionCount: 3,
              onVersionSelected: selected.add,
              onRegenerate: () {},
              child: body('reply'),
            ),
          ),
          size: const Size(320, 740),
          scale: 2,
        );
        for (final control in [
          'agent-copy-reply',
          'agent-regenerate-reply',
          'agent-reply-previous-reply',
          'agent-reply-next-reply',
        ]) {
          final target = key(control);
          expect(target.hitTestable(), findsOneWidget);
          final rect = tester.getRect(target);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          final render = tester.renderObject(target);
          for (final x in [rect.left + 2, rect.center.dx, rect.right - 2]) {
            for (final y in [rect.top + 2, rect.center.dy, rect.bottom - 2]) {
              expect(
                tester
                    .hitTestOnBinding(Offset(x, y))
                    .path
                    .any((entry) => identical(entry.target, render)),
                isTrue,
                reason:
                    '$control must receive input throughout its 48dp target.',
              );
            }
          }
        }
        await tester.tap(key('agent-reply-previous-reply'));
        await tester.pumpAndSettle();
        await tester.tap(key('agent-reply-next-reply'));
        await tester.pumpAndSettle();
        expect(selected, [0, 2]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}
