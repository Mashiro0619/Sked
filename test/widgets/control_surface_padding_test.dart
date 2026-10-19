import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../support/workspace_harness.dart';

const controlSurfacePaddingCaptureKey = ValueKey(
  'control-surface-padding-capture',
);

typedef ControlSurfacePaddingCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

Finder _text(String value) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == value);

class _Row {
  _Row(Finder scope, String label, this.icon)
    : title = find.descendant(of: scope, matching: _text(label));

  final Finder title;
  final IconData icon;
  Finder get tile =>
      find.ancestor(of: title, matching: find.byType(ListTile)).first;
  Finder get interaction =>
      find.ancestor(of: title, matching: find.byType(InkWell)).first;
  Finder get fill => find.descendant(
    of: interaction,
    matching: find.byWidgetPredicate(
      (widget) => widget is Ink && widget.decoration is ShapeDecoration,
    ),
  );
  Finder get trailing => find.descendant(of: tile, matching: find.byIcon(icon));
}

Future<AppRuntime> _mount(
  WidgetTester tester, {
  AppMode mode = AppMode.student,
  double scale = 1,
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
  Widget? home,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = home == null
      ? const Size(1600, 1100)
      : const Size(900, 720);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(mode: mode, locale: 'zh');
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    provider.dispose();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: controlSurfacePaddingCaptureKey,
      child: WorkspaceHarness(
        provider: provider,
        locale: const Locale('zh'),
        textScale: scale,
        brightness: brightness,
        textDirection: direction,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _click(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget);
  final point = tester.getCenter(target);
  await mouse.moveTo(point);
  await mouse.down(point);
  await mouse.up();
  await tester.pumpAndSettle();
}

Future<List<Color>> _edgePixels(WidgetTester tester, _Row row) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(controlSurfacePaddingCaptureKey),
  );
  final rect = tester.getRect(row.fill);
  final points = [
    boundary.globalToLocal(rect.centerLeft + const Offset(2, 0)),
    boundary.globalToLocal(rect.centerRight + const Offset(-2, 0)),
  ];
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return points.map((point) {
        final offset = (point.dy.floor() * image.width + point.dx.floor()) * 4;
        return Color.fromARGB(
          bytes.getUint8(offset + 3),
          bytes.getUint8(offset),
          bytes.getUint8(offset + 1),
          bytes.getUint8(offset + 2),
        );
      }).toList();
    } finally {
      image.dispose();
    }
  }))!;
}

Future<void> _hoverAndMeasure(
  WidgetTester tester,
  TestGesture mouse,
  _Row row,
  String scene,
  ControlSurfacePaddingCapture? capture, {
  bool multiline = false,
}) async {
  await tester.ensureVisible(row.title);
  await mouse.moveTo(const Offset(1, 1));
  await tester.pumpAndSettle();
  final before = await _edgePixels(tester, row);
  await mouse.moveTo(tester.getCenter(row.interaction));
  await tester.pumpAndSettle();
  // Keep the pointer on the real header throughout the native screenshot.
  await capture?.call(tester, scene);
  final after = await _edgePixels(tester, row);
  expect(
    [
      for (var i = 0; i < before.length; i++)
        before[i].toARGB32() != after[i].toARGB32(),
    ],
    contains(true),
    reason: 'The measured fill must actually receive Windows mouse hover.',
  );
  expect(row.title, findsOneWidget);
  expect(row.fill, findsOneWidget);
  expect(row.trailing, findsOneWidget);
  expect(tester.widget<ListTile>(row.tile).leading, isNull);
  final fill = tester.getRect(row.fill);
  expect(tester.getRect(row.interaction), fill);
  final text = tester.getRect(row.title);
  final trailing = tester.getRect(row.trailing);
  for (final content in [text, trailing]) {
    expect(content.left - fill.left, greaterThanOrEqualTo(11.9));
    expect(fill.right - content.right, greaterThanOrEqualTo(11.9));
    expect(content.top - fill.top, greaterThanOrEqualTo(3.9));
    expect(fill.bottom - content.bottom, greaterThanOrEqualTo(3.9));
  }
  final viewport =
      Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  expect(fill.left, greaterThanOrEqualTo(viewport.left));
  expect(fill.right, lessThanOrEqualTo(viewport.right));
  expect(fill.top, greaterThanOrEqualTo(viewport.top));
  expect(fill.bottom, lessThanOrEqualTo(viewport.bottom));
  final paragraph = tester.renderObject<RenderParagraph>(row.title);
  final natural = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    locale: paragraph.locale,
    strutStyle: paragraph.strutStyle,
    textHeightBehavior: paragraph.textHeightBehavior,
    textWidthBasis: paragraph.textWidthBasis,
  )..layout(maxWidth: text.width);
  try {
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(text.height, closeTo(natural.height, .1));
    if (multiline) {
      expect(natural.computeLineMetrics().length, greaterThan(1));
      expect(fill.height, greaterThan(36));
    }
  } finally {
    natural.dispose();
  }
}

Widget _panel(Widget child) => Scaffold(
  body: Padding(
    padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(width: 320, child: Material(child: child)),
    ),
  ),
);

void main() => runControlSurfacePaddingTests();

void runControlSurfacePaddingTests({ControlSurfacePaddingCapture? capture}) {
  for (final (mode, scale, brightness, direction, scene) in [
    (
      AppMode.student,
      1.0,
      Brightness.light,
      TextDirection.ltr,
      'student-more-light',
    ),
    (
      AppMode.general,
      2.0,
      Brightness.dark,
      TextDirection.rtl,
      'general-more-dark-rtl-2x',
    ),
  ]) {
    testWidgets(
      '$scene leaves room inside the hovered More surface and keeps its draft',
      (tester) async {
        final provider = await _mount(
          tester,
          mode: mode,
          scale: scale,
          brightness: brightness,
          direction: direction,
        );
        final mouse = await _mouse(tester);
        await _click(
          tester,
          mouse,
          find.byKey(
            ValueKey(
              mode == AppMode.student
                  ? 'student-add-course'
                  : 'general-add-event',
            ),
          ),
        );
        final editor = find.byType(
          mode == AppMode.student ? CourseEditorSheet : GeneralEventEditorSheet,
        );
        final disclosure = find.descendant(
          of: editor,
          matching: find.byWidgetPredicate(
            (widget) => widget is WorkspaceEditorDisclosure && widget.compact,
          ),
        );
        expect(disclosure, findsOneWidget);
        final title = tester
            .widget<WorkspaceEditorDisclosure>(disclosure)
            .title;
        final row = _Row(disclosure, title, Icons.expand_more);
        final expansion = tester.widget<ExpansionTile>(
          find.descendant(of: disclosure, matching: find.byType(ExpansionTile)),
        );
        if (expansion.controller?.isExpanded ?? expansion.initiallyExpanded) {
          await _click(tester, mouse, row.interaction);
        }
        final before = provider.workspaceView.data.toJson();
        await _hoverAndMeasure(tester, mouse, row, '$scene-hover', capture);
        await _click(tester, mouse, row.interaction);
        final input = find
            .descendant(of: disclosure, matching: find.byType(TextField))
            .first;
        await tester.ensureVisible(input);
        const draft = '折叠和再次展开后，仍应保留这段较长的编辑器草稿。';
        await tester.enterText(input, draft);
        await tester.pumpAndSettle();
        final element = tester.element(input);
        final controller = tester.widget<TextField>(input).controller!;
        await _hoverAndMeasure(
          tester,
          mouse,
          row,
          '$scene-expanded-hover',
          capture,
        );
        await _click(tester, mouse, row.interaction);
        expect(element.mounted, isTrue);
        await _click(tester, mouse, row.interaction);
        expect(tester.element(input), same(element));
        expect(tester.widget<TextField>(input).controller, same(controller));
        expect(controller.text, draft);
        expect(provider.workspaceView.data.toJson(), before);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'long RTL disclosure at 2x grows its header without indenting its body',
    (tester) async {
      final draft = TextEditingController(text: '保留草稿');
      addTearDown(draft.dispose);
      final expansion = ExpansibleController();
      addTearDown(expansion.dispose);
      final changes = <bool>[];
      const key = ValueKey('long-disclosure');
      const bodyKey = ValueKey('long-disclosure-body');
      const title = '更多课程资料、提醒方式与补充说明';
      await _mount(
        tester,
        scale: 2,
        brightness: Brightness.dark,
        direction: TextDirection.rtl,
        home: _panel(
          WorkspaceEditorDisclosure(
            key: key,
            controller: expansion,
            compact: true,
            icon: Icons.more_horiz,
            title: title,
            initiallyExpanded: false,
            enabled: true,
            onExpansionChanged: changes.add,
            child: SizedBox(
              key: bodyKey,
              width: double.infinity,
              child: TextField(controller: draft),
            ),
          ),
        ),
      );
      final mouse = await _mouse(tester);
      final row = _Row(find.byKey(key), title, Icons.expand_more);
      await _hoverAndMeasure(
        tester,
        mouse,
        row,
        'disclosure-long-dark-rtl-2x-hover',
        capture,
        multiline: true,
      );
      await _click(tester, mouse, row.interaction);
      final body = tester.getRect(find.byKey(bodyKey));
      final fill = tester.getRect(row.fill);
      expect(body.left, closeTo(fill.left, .1));
      expect(body.right, closeTo(fill.right, .1));
      final input = find.descendant(
        of: find.byKey(bodyKey),
        matching: find.byType(TextField),
      );
      final element = tester.element(input);
      await _click(tester, mouse, row.interaction);
      expect(element.mounted, isTrue);
      await _click(tester, mouse, row.interaction);
      expect(tester.element(input), same(element));
      expect(draft.text, '保留草稿');
      expect(changes, [true, false, true]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'selected text-only dialog option keeps its default surface insets',
    (tester) async {
      const key = ValueKey('selected-text-option');
      const title = '使用当前提醒设置';
      var taps = 0;
      await _mount(
        tester,
        home: _panel(
          ExpressiveDialogOption(
            key: key,
            title: const Text(title),
            selected: true,
            onTap: () => taps++,
          ),
        ),
      );
      final mouse = await _mouse(tester);
      final row = _Row(find.byKey(key), title, Icons.check_circle);
      await _hoverAndMeasure(
        tester,
        mouse,
        row,
        'dialog-option-no-leading-selected-hover',
        capture,
      );
      await _click(tester, mouse, row.interaction);
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
