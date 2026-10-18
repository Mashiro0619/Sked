import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/utils/constants.dart';
import 'package:sked/widgets/sked_date_picker.dart';

const datePickerFloatingCaptureKey = ValueKey('date-picker-floating-capture');

typedef DatePickerFloatingInteractionCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

const _viewport = Size(900, 720);
const _triggerRect = Rect.fromLTWH(220, 300, 200, 40);
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _surface => _key('sked-date-picker-surface');
Finder get _monthYear => _key('sked-date-month-year');
Finder get _monthLabel =>
    find.descendant(of: _monthYear, matching: find.byType(Text));
Finder get _monthArrow => find.descendant(
  of: _monthYear,
  matching: find.byIcon(Icons.arrow_drop_down),
);
Finder get _titleDrag => find.descendant(
  of: _key('sked-date-picker-heading'),
  matching: _key('sked-picker-drag-handle'),
);

Future<void> _mountAndOpen(WidgetTester tester, List<DateTime?> results) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _viewport;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: datePickerFloatingCaptureKey,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(
          seedColor: const Color(0xFF336699),
          brightness: Brightness.light,
          themeColorMode: themeColorModeSingle,
          colorfulUiColorValues: const {},
        ),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fromRect(
                rect: _triggerRect,
                child: Builder(
                  builder: (anchor) => TextButton(
                    key: const ValueKey('open-start-date'),
                    onPressed: () => unawaited(
                      showSkedDatePicker(
                        context: anchor,
                        anchorContext: anchor,
                        initialDate: DateTime(2026, 10, 18),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      ).then(results.add),
                    ),
                    child: const Text('选择开学日期'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open-start-date'));
  await tester.pumpAndSettle();
  expect(_surface, findsOneWidget);
  expect(find.byType(SkedDatePicker), findsOneWidget);
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(16, 16));
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _click(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
) async {
  final hitTarget = target.hitTestable();
  expect(hitTarget, findsOneWidget);
  final point = tester.getCenter(hitTarget);
  await mouse.moveTo(point);
  await mouse.down(point);
  await mouse.up();
  await tester.pumpAndSettle();
}

Future<void> _drag(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
  Offset delta,
) async {
  final hitTarget = target.hitTestable();
  expect(hitTarget, findsOneWidget);
  final point = tester.getCenter(hitTarget);
  await mouse.moveTo(point);
  await mouse.down(point);
  for (var step = 0; step < 8; step++) {
    await mouse.moveBy(delta / 8);
    await tester.pump();
  }
  await mouse.up();
  await tester.pumpAndSettle();
}

Future<void> _expectCursor(
  WidgetTester tester,
  TestGesture mouse,
  Finder target,
  MouseCursor cursor,
) async {
  final hitTarget = target.hitTestable();
  expect(hitTarget, findsOneWidget);
  await mouse.moveTo(tester.getCenter(hitTarget));
  await tester.pump();
  expect(
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
    cursor,
    reason: 'The actual mouse hit over $target must advertise its action.',
  );
}

void _expectUnmoved(WidgetTester tester, Offset origin, String interaction) {
  expect(
    tester.getRect(_surface).topLeft,
    origin,
    reason: '$interaction must not reposition the open date picker.',
  );
}

Future<void> _capture(
  WidgetTester tester,
  TestGesture mouse,
  DatePickerFloatingInteractionCapture? capture,
  String scene,
) async {
  if (capture == null) return;
  await mouse.moveTo(const Offset(16, 16));
  await tester.pumpAndSettle();
  await capture(tester, scene);
}

void main() => runDatePickerFloatingInteractionTests();

void runDatePickerFloatingInteractionTests({
  DatePickerFloatingInteractionCapture? capture,
}) {
  testWidgets(
    'desktop date picker keeps its position through month and year browsing',
    (tester) async {
      final results = <DateTime?>[];
      await _mountAndOpen(tester, results);
      final mouse = await _mouse(tester);
      final initial = tester.getRect(_surface);
      final state = tester.state(find.byType(SkedDatePicker));
      // The day grid fits beside this field. The shorter month grid also fits
      // below it; changing the calendar page must not choose a new attachment.
      expect(initial.left, greaterThan(_triggerRect.right));
      await _capture(tester, mouse, capture, 'date-picker-days-initial');

      Future<void> browse(Finder target, String description) async {
        await _click(tester, mouse, target);
        _expectUnmoved(tester, initial.topLeft, description);
        expect(tester.state(find.byType(SkedDatePicker)), same(state));
        expect(results, isEmpty);
        expect(tester.takeException(), isNull);
      }

      await browse(_monthLabel, 'Opening month selection');
      expect(_key('sked-date-month-2026-10'), findsOneWidget);
      await _capture(tester, mouse, capture, 'date-picker-months');
      await browse(_monthLabel, 'Opening year selection');
      expect(_key('sked-date-year-2027'), findsOneWidget);
      await _capture(tester, mouse, capture, 'date-picker-years');
      await browse(_key('sked-date-next'), 'Browsing the next year page');
      await browse(_key('sked-date-previous'), 'Returning to the year page');
      await browse(_key('sked-date-year-2027'), 'Choosing a year');
      await browse(_key('sked-date-month-2027-2'), 'Choosing a month');
      expect(_key('sked-date-2027-02-23'), findsOneWidget);
      await browse(_key('sked-date-next'), 'Browsing the next month');
      await browse(_key('sked-date-previous'), 'Returning to the month');
      await browse(
        _key('sked-date-2027-02-23'),
        'Selecting a provisional date',
      );
      await _capture(tester, mouse, capture, 'date-picker-days-selected');

      await _click(tester, mouse, _key('sked-date-confirm'));
      expect(results, [DateTime(2027, 2, 23)]);
      expect(_surface, findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop date navigation controls use button cursors and never drag the panel',
    (tester) async {
      final results = <DateTime?>[];
      await _mountAndOpen(tester, results);
      final mouse = await _mouse(tester);
      final origin = tester.getRect(_surface).topLeft;
      final buttonCursor = WidgetStateMouseCursor.adaptiveClickable.resolve({
        WidgetState.hovered,
      });
      for (final target in [
        _monthLabel,
        _monthArrow,
        _key('sked-date-previous'),
        _key('sked-date-next'),
      ]) {
        await _expectCursor(tester, mouse, target, buttonCursor);
        await _drag(tester, mouse, target, const Offset(-48, -24));
        _expectUnmoved(tester, origin, 'Dragging a navigation control');
        expect(_key('sked-date-2026-10-18'), findsOneWidget);
        expect(results, isEmpty);
      }
      await _capture(tester, mouse, capture, 'date-picker-controls-stationary');
      await _click(tester, mouse, _key('sked-date-cancel'));
      expect(results, [null]);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop date picker static title keeps its move cursor and mouse dragging',
    (tester) async {
      final results = <DateTime?>[];
      await _mountAndOpen(tester, results);
      final mouse = await _mouse(tester);
      final initial = tester.getRect(_surface);
      await _expectCursor(tester, mouse, _titleDrag, SystemMouseCursors.move);
      const delta = Offset(-48, -24);
      await _drag(tester, mouse, _titleDrag, delta);
      final moved = tester.getRect(_surface);
      expect(moved.left, closeTo(initial.left + delta.dx, .1));
      expect(moved.top, closeTo(initial.top + delta.dy, .1));
      expect(results, isEmpty);

      await _click(tester, mouse, _monthArrow);
      _expectUnmoved(tester, moved.topLeft, 'Browsing after a title drag');
      expect(_key('sked-date-month-2026-10'), findsOneWidget);
      expect(results, isEmpty);
      await _capture(tester, mouse, capture, 'date-picker-title-dragged');
      await _click(tester, mouse, _key('sked-date-cancel'));
      expect(results, [null]);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop date picker still clamps a dragged panel when the window shrinks',
    (tester) async {
      final results = <DateTime?>[];
      await _mountAndOpen(tester, results);
      final mouse = await _mouse(tester);
      await _drag(tester, mouse, _titleDrag, const Offset(100, 20));
      final beforeResize = tester.getRect(_surface);
      const smallerViewport = Size(820, 560);
      expect(beforeResize.right, greaterThan(smallerViewport.width - 8));
      expect(beforeResize.bottom, greaterThan(smallerViewport.height - 8));

      tester.view.physicalSize = smallerViewport;
      await tester.pumpAndSettle();
      final clamped = tester.getRect(_surface);
      expect(clamped.left, greaterThanOrEqualTo(8));
      expect(clamped.top, greaterThanOrEqualTo(56));
      expect(clamped.right, closeTo(smallerViewport.width - 8, .1));
      expect(clamped.bottom, closeTo(smallerViewport.height - 8, .1));
      expect(_key('sked-date-confirm').hitTestable(), findsOneWidget);
      expect(results, isEmpty);
      await _capture(tester, mouse, capture, 'date-picker-window-clamped');
      await _click(tester, mouse, _key('sked-date-cancel'));
      expect(results, [null]);
      expect(tester.takeException(), isNull);
    },
    variant: _desktop,
  );
}
