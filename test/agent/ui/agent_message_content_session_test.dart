import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_message_content.dart';
import 'package:sked/agent/ui/agent_selectable_text.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'agent_ui_test_support.dart';

const _code = 'print("原始代码");\n\treturn 42;\n';
const _reference = 'https://reference.example.invalid/help';
const _markdown =
    'A reply with a reference.\n\n```dart\n$_code```\n\n'
    '[Open reference]($_reference)\n\n'
    '![Reference description](https://image.example.invalid/reference.png)';

enum _Boundary {
  text,
  active,
  interactive,
  revision,
  label,
  streaming,
  showCopy,
}

void main() {
  for (final boundary in _Boundary.values) {
    testWidgets(
      'old code and link callbacks stay invalid after $boundary returns to its original value',
      (tester) async {
        addTearDown(tester.view.reset);
        final copied = _captureClipboard(tester);
        final launcher = _installLauncher();
        final host = await _mount(tester);
        final copy = _copyButton(tester).onPressed!;
        final link = tester
            .widget<MarkdownBody>(find.byType(MarkdownBody))
            .onTapLink!;

        await _crossBoundary(tester, host, boundary);
        copy();
        link('Open reference', _reference, '');
        await tester.pumpAndSettle();
        expect(copied, isEmpty);
        expect(launcher.urls, isEmpty);
        expect(find.byType(SnackBar), findsNothing);

        await tester.tap(_copyButtonFinder());
        await tester.pumpAndSettle();
        expect(copied, [_code]);
        expect(find.byTooltip(_strings(tester).agentCopied), findsOneWidget);
        await tester.tapAt(_referencePoint(tester));
        await tester.pumpAndSettle();
        expect(launcher.urls, [_reference]);
        expect(launcher.modes, [PreferredLaunchMode.externalApplication]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final boundary in [
    _Boundary.text,
    _Boundary.active,
    _Boundary.interactive,
    _Boundary.revision,
    _Boundary.label,
  ]) {
    testWidgets('standalone copy rejects the old $boundary callback', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      final copied = _captureClipboard(tester);
      final host = await _mount(tester, standaloneCopy: true);
      final copy = _copyButton(tester).onPressed!;
      await _crossBoundary(tester, host, boundary);
      copy();
      await tester.pumpAndSettle();
      expect(copied, isEmpty);
      await tester.tap(_copyButtonFinder());
      await tester.pumpAndSettle();
      expect(copied, [_code]);
      expect(find.byTooltip(_strings(tester).agentCopied), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final input in [
    (kind: PointerDeviceKind.touch, platform: TargetPlatform.android),
    (kind: PointerDeviceKind.mouse, platform: TargetPlatform.windows),
  ]) {
    for (final boundary in [
      _Boundary.active,
      _Boundary.interactive,
      _Boundary.revision,
    ]) {
      for (final codeCopy in [false, true]) {
        testWidgets(
          'a pressed ${codeCopy ? 'code copy' : 'Markdown link'} from ${input.kind} cannot revive after $boundary',
          (tester) async {
            addTearDown(tester.view.reset);
            final copied = _captureClipboard(tester);
            final launcher = _installLauncher();
            final host = await _mount(tester);
            final pressed = await tester.startGesture(
              codeCopy
                  ? tester.getCenter(_copyButtonFinder())
                  : _referencePoint(tester),
              kind: input.kind,
            );
            await tester.pump();
            await _crossBoundary(tester, host, boundary);
            await pressed.up();
            if (input.kind == PointerDeviceKind.mouse) {
              await pressed.removePointer();
            }
            await tester.pumpAndSettle();
            expect(copied, isEmpty);
            expect(launcher.urls, isEmpty);
            expect(find.byType(SnackBar), findsNothing);

            // A separate press must keep working after the stale gesture has
            // ended; exclude the text selector's consecutive-tap interval.
            await tester.pump(
              kDoubleTapTimeout + const Duration(milliseconds: 1),
            );
            final current = await tester.startGesture(
              codeCopy
                  ? tester.getCenter(_copyButtonFinder())
                  : _referencePoint(tester),
              kind: input.kind,
            );
            await current.up();
            if (input.kind == PointerDeviceKind.mouse) {
              await current.removePointer();
            }
            await tester.pumpAndSettle();
            expect(copied, codeCopy ? [_code] : isEmpty);
            expect(launcher.urls, codeCopy ? isEmpty : [_reference]);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(input.platform),
        );
      }
    }
  }

  for (final boundary in [
    _Boundary.text,
    _Boundary.active,
    _Boundary.interactive,
    _Boundary.revision,
  ]) {
    for (final fail in [false, true]) {
      testWidgets(
        'accepted old copy ${fail ? 'failure' : 'success'} after $boundary cannot affect a newer copy',
        (tester) async {
          addTearDown(tester.view.reset);
          final oldWrite = Completer<void>();
          final newWrite = Completer<void>();
          final copied = _captureClipboard(
            tester,
            gates: [oldWrite, newWrite],
            failingWrites: fail ? {0} : {},
          );
          final host = await _mount(tester);
          await tester.tap(_copyButtonFinder());
          await tester.pump();
          expect(copied, [_code]);
          expect(_copyButton(tester).onPressed, isNull);

          await _crossBoundary(tester, host, boundary);
          await tester.tap(_copyButtonFinder());
          await tester.pump();
          expect(copied, [_code, _code]);
          expect(_copyButton(tester).onPressed, isNull);
          oldWrite.complete();
          await tester.pumpAndSettle();
          expect(_copyButton(tester).onPressed, isNull);
          expect(find.byTooltip(_strings(tester).agentCopied), findsNothing);
          expect(find.byType(SnackBar), findsNothing);

          newWrite.complete();
          await tester.pumpAndSettle();
          expect(_copyButton(tester).onPressed, isNotNull);
          expect(find.byTooltip(_strings(tester).agentCopied), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'accepted old launch ${fail ? 'throw' : 'false'} after $boundary has no restored-host feedback',
        (tester) async {
          addTearDown(tester.view.reset);
          final completion = Completer<bool>();
          addTearDown(() {
            if (!completion.isCompleted) completion.complete(false);
          });
          final launcher = _installLauncher()..result = () => completion.future;
          final host = await _mount(tester);
          await tester.tapAt(_referencePoint(tester));
          await tester.pump();
          expect(launcher.urls, [_reference]);
          await _crossBoundary(tester, host, boundary);
          if (fail) {
            completion.completeError(
              PlatformException(
                code: 'synthetic-launch',
                message: 'private-launch-detail',
              ),
            );
          } else {
            completion.complete(false);
          }
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(find.text('private-launch-detail'), findsNothing);

          launcher.result = null;
          _openReference(tester);
          await tester.pumpAndSettle();
          expect(launcher.urls, [_reference, _reference]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'a current clipboard failure still gives safe feedback and permits retry',
    (tester) async {
      addTearDown(tester.view.reset);
      final copied = _captureClipboard(tester, failingWrites: {0});
      await _mount(tester);
      await tester.tap(_copyButtonFinder());
      await tester.pumpAndSettle();
      expect(find.text(_strings(tester).agentCopyFailed), findsOneWidget);
      expect(find.text('private-clipboard-detail'), findsNothing);
      expect(_copyButton(tester).onPressed, isNotNull);
      await tester.tap(_copyButtonFinder());
      await tester.pumpAndSettle();
      expect(copied, [_code, _code]);
      expect(find.byTooltip(_strings(tester).agentCopied), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'a current launch ${fail ? 'throw' : 'false'} still gives safe feedback',
      (tester) async {
        addTearDown(tester.view.reset);
        final launcher = _installLauncher()
          ..result = () => fail
              ? Future<bool>.error(
                  PlatformException(
                    code: 'synthetic-launch',
                    message: 'private-launch-detail',
                  ),
                )
              : Future<bool>.value(false);
        await _mount(tester);
        await tester.tapAt(_referencePoint(tester));
        await tester.pumpAndSettle();
        expect(launcher.urls, [_reference]);
        expect(
          find.text(_strings(tester).agentOperationFailed),
          findsOneWidget,
        );
        expect(find.text('private-launch-detail'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'only explicit allowed links launch and remote images remain selectable text',
    (tester) async {
      addTearDown(tester.view.reset);
      final launcher = _installLauncher();
      await _mount(tester);
      expect(find.byType(Image), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AgentSelectableText &&
              widget.data == 'Reference description',
        ),
        findsOneWidget,
      );
      expect(launcher.urls, isEmpty);
      final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
      expect(markdown.selectable, isTrue);
      expect(markdown.fitContent, isFalse);
      for (final href in [
        null,
        '',
        'http://[',
        'javascript:alert(1)',
        'file:///private.txt',
        'data:text/plain,example',
        'ftp://files.example.invalid/file',
        'sked:run',
        '/relative',
      ]) {
        markdown.onTapLink!('Rejected', href, '');
      }
      await tester.pumpAndSettle();
      expect(launcher.urls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
      final allowed = [
        'https://reference.example.invalid/secure',
        'http://reference.example.invalid/plain',
        'mailto:synthetic@example.invalid?subject=Reference',
      ];
      for (final href in allowed) {
        markdown.onTapLink!('Allowed', href, '');
      }
      await tester.pumpAndSettle();
      expect(launcher.urls, allowed);
      expect(
        launcher.modes,
        everyElement(PreferredLaunchMode.externalApplication),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'showCopy keeps message and code copies separate with compatible defaults',
    (tester) async {
      addTearDown(tester.view.reset);
      final copied = _captureClipboard(tester);
      final host = await _mount(tester);
      expect(find.byType(AgentCopyButton), findsOneWidget);
      expect(
        tester
            .widget<AgentMessageContent>(find.byType(AgentMessageContent))
            .showCopy,
        isFalse,
      );
      host.update(() => host.showCopy = true);
      await tester.pumpAndSettle();
      expect(find.byType(AgentCopyButton), findsNWidgets(2));
      await tester.tap(find.byTooltip(_strings(tester).agentCopyMessage));
      await tester.pumpAndSettle();
      expect(copied, [_markdown]);
      const defaults = AgentMessageContent(
        text: 'Message',
        roleLabel: 'Assistant',
      );
      const copyDefaults = AgentCopyButton(text: 'Message', label: 'Copy');
      expect(
        (defaults.active, defaults.interactive, defaults.interactionRevision),
        (true, true, 0),
      );
      expect(
        (
          copyDefaults.active,
          copyDefaults.interactive,
          copyDefaults.interactionRevision,
        ),
        (true, true, 0),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final boundary in [_Boundary.active, _Boundary.interactive]) {
    testWidgets(
      'unavailable $boundary disables cached code controls and preserves selection',
      (tester) async {
        addTearDown(tester.view.reset);
        final copied = _captureClipboard(tester);
        final launcher = _installLauncher();
        final host = await _mount(tester);
        final codeText = find.byWidgetPredicate(
          (widget) => widget is AgentSelectableText && widget.data == _code,
        );
        final editable = find.descendant(
          of: codeText,
          matching: find.byType(EditableText),
        );
        final controller = tester.widget<EditableText>(editable).controller;
        const selection = TextSelection(baseOffset: 0, extentOffset: 5);
        controller.selection = selection;
        final copy = _copyButton(tester).onPressed!;
        final link = tester
            .widget<MarkdownBody>(find.byType(MarkdownBody))
            .onTapLink!;
        final bounds = tester.getRect(codeText);
        host.update(() {
          if (boundary == _Boundary.active) {
            host.active = false;
          } else {
            host.interactive = false;
          }
        });
        await tester.pumpAndSettle();
        expect(_copyButton(tester).onPressed, isNull);
        expect(
          tester.widget<MarkdownBody>(find.byType(MarkdownBody)).onTapLink,
          isNull,
        );
        copy();
        link('Open reference', _reference, '');
        await tester.pumpAndSettle();
        expect(copied, isEmpty);
        expect(launcher.urls, isEmpty);
        host.update(() {
          host.active = true;
          host.interactive = true;
        });
        await tester.pumpAndSettle();
        expect(
          tester.widget<EditableText>(editable).controller,
          same(controller),
        );
        expect(controller.selection, selection);
        expect(tester.getRect(codeText), bounds);
        expect(_copyButton(tester).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('disposing a body rejects captured copy and link callbacks', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final copied = _captureClipboard(tester);
    final launcher = _installLauncher();
    await _mount(tester);
    final copy = _copyButton(tester).onPressed!;
    final link = tester
        .widget<MarkdownBody>(find.byType(MarkdownBody))
        .onTapLink!;
    await tester.pumpWidget(const SizedBox.shrink());
    copy();
    link('Open reference', _reference, '');
    await tester.pumpAndSettle();
    expect(copied, isEmpty);
    expect(launcher.urls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'legal reparenting preserves an accepted copy and its current link callback',
    (tester) async {
      addTearDown(tester.view.reset);
      final write = Completer<void>();
      final copied = _captureClipboard(tester, gates: [write]);
      final launcher = _installLauncher();
      final contentKey = GlobalKey();
      final content = AgentMessageContent(
        key: contentKey,
        text: _markdown,
        roleLabel: 'Assistant',
        showCopy: false,
      );
      var right = false;
      late StateSetter change;
      await mountAgentUi(
        tester,
        StatefulBuilder(
          builder: (_, setState) {
            change = setState;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: right ? const SizedBox.shrink() : content),
                Expanded(child: right ? content : const SizedBox.shrink()),
              ],
            );
          },
        ),
        size: const Size(1000, 800),
      );
      final originalState = contentKey.currentState;
      expect(originalState, isNotNull);
      final copy = _copyButton(tester).onPressed!;
      final link = tester
          .widget<MarkdownBody>(find.byType(MarkdownBody))
          .onTapLink!;
      copy();
      await tester.pump();
      expect(copied, [_code]);
      change(() => right = true);
      await tester.pumpAndSettle();
      expect(contentKey.currentState, same(originalState));
      link('Open reference', _reference, '');
      write.complete();
      await tester.pumpAndSettle();
      expect(launcher.urls, [_reference]);
      expect(find.byTooltip('Copied'), findsOneWidget);
      copy();
      await tester.pumpAndSettle();
      expect(copied, [_code, _code]);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<_SessionHostState> _mount(
  WidgetTester tester, {
  bool standaloneCopy = false,
}) async {
  final key = GlobalKey<_SessionHostState>();
  await mountAgentUi(
    tester,
    _SessionHost(key: key, standaloneCopy: standaloneCopy),
    size: const Size(600, 800),
  );
  return key.currentState!;
}

Finder _copyButtonFinder() => find.descendant(
  of: find.byType(AgentCopyButton).first,
  matching: find.byType(IconButton),
);

IconButton _copyButton(WidgetTester tester) =>
    tester.widget(_copyButtonFinder());

Offset _referencePoint(WidgetTester tester) {
  final text = find.byWidgetPredicate(
    (widget) =>
        widget is EditableText && widget.controller.text == 'Open reference',
  );
  expect(text, findsOneWidget);
  final render = tester.state<EditableTextState>(text).renderEditable;
  final boxes = render.getBoxesForSelection(
    const TextSelection(baseOffset: 0, extentOffset: 1),
  );
  expect(boxes, isNotEmpty);
  return render.localToGlobal(boxes.first.toRect().center);
}

AppLocalizations _strings(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(_SessionHost)));

void _openReference(WidgetTester tester) => tester
    .widget<MarkdownBody>(find.byType(MarkdownBody))
    .onTapLink!('Open reference', _reference, '');

Future<void> _crossBoundary(
  WidgetTester tester,
  _SessionHostState host,
  _Boundary boundary,
) async {
  final originalText = host.text;
  final originalRevision = host.revision;
  final originalLabel = host.label;
  void change(bool restore) => host.update(() {
    switch (boundary) {
      case _Boundary.text:
        host.text = restore
            ? originalText
            : '# Another source\n\n$originalText';
      case _Boundary.active:
        host.active = restore;
      case _Boundary.interactive:
        host.interactive = restore;
      case _Boundary.revision:
        host.revision = restore ? originalRevision : originalRevision + 1;
      case _Boundary.label:
        host.label = restore ? originalLabel : 'Another source';
      case _Boundary.streaming:
        host.streaming = !restore;
      case _Boundary.showCopy:
        host.showCopy = !restore;
    }
  });
  change(false);
  await tester.pump();
  change(true);
  await tester.pumpAndSettle();
}

List<String> _captureClipboard(
  WidgetTester tester, {
  List<Completer<void>> gates = const [],
  Set<int> failingWrites = const {},
}) {
  final copied = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method != 'Clipboard.setData') return null;
    final write = copied.length;
    copied.add((call.arguments as Map<Object?, Object?>)['text'] as String);
    if (write < gates.length) await gates[write].future;
    if (failingWrites.contains(write)) {
      throw PlatformException(
        code: 'synthetic-clipboard',
        message: 'private-clipboard-detail',
      );
    }
    return null;
  });
  addTearDown(() {
    for (final gate in gates) {
      if (!gate.isCompleted) gate.complete();
    }
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return copied;
}

_LauncherProbe _installLauncher() {
  final previous = UrlLauncherPlatform.instance;
  final launcher = _LauncherProbe();
  UrlLauncherPlatform.instance = launcher;
  addTearDown(() => UrlLauncherPlatform.instance = previous);
  return launcher;
}

class _LauncherProbe extends UrlLauncherPlatform {
  final urls = <String>[];
  final modes = <PreferredLaunchMode>[];
  Future<bool> Function()? result;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) {
    urls.add(url);
    modes.add(options.mode);
    return result?.call() ?? Future<bool>.value(true);
  }
}

class _SessionHost extends StatefulWidget {
  const _SessionHost({super.key, required this.standaloneCopy});
  final bool standaloneCopy;

  @override
  State<_SessionHost> createState() => _SessionHostState();
}

class _SessionHostState extends State<_SessionHost> {
  late String text = widget.standaloneCopy ? _code : _markdown;
  String label = 'Assistant';
  bool active = true;
  bool interactive = true;
  int revision = 0;
  bool streaming = false;
  bool showCopy = false;

  void update(VoidCallback change) => setState(change);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: widget.standaloneCopy
        ? AgentCopyButton(
            text: text,
            label: label,
            active: active,
            interactive: interactive,
            interactionRevision: revision,
          )
        : AgentMessageContent(
            text: text,
            roleLabel: label,
            active: active,
            interactive: interactive,
            interactionRevision: revision,
            streaming: streaming,
            showCopy: showCopy,
          ),
  );
}
