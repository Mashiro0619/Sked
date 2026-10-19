import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/theme/app_theme.dart';
import 'package:sked/utils/constants.dart';
import 'package:sked/widgets/sked_date_picker.dart';

const dateHeaderPaddingCaptureKey = ValueKey('date-header-padding-capture');

typedef DateHeaderPaddingCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

typedef _Scenario = ({
  String name,
  bool embedded,
  double scale,
  bool rtl,
  Size size,
});

const _draftText = '尚未保存的课表草稿';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _header => _key('sked-date-month-year');
Finder get _ink => find.descendant(of: _header, matching: find.byType(InkWell));
Finder get _material =>
    find.descendant(of: _header, matching: find.byType(Material)).first;
Finder get _label =>
    find.descendant(of: _header, matching: find.byType(Text)).first;

class _Fixture {
  final draft = TextEditingController();
  final results = <DateTime?>[];
}

Future<_Fixture> _mount(WidgetTester tester, _Scenario scenario) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = scenario.size;
  addTearDown(tester.view.reset);
  final fixture = _Fixture();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    fixture.draft.dispose();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: dateHeaderPaddingCaptureKey,
      child: MaterialApp(
        locale: Locale(scenario.rtl ? 'en' : 'zh'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildAppTheme(
          seedColor: const Color(0xFF336699),
          brightness: Brightness.light,
          themeColorMode: themeColorModeSingle,
          colorfulUiColorValues: const {},
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scenario.scale)),
          child: Directionality(
            textDirection: scenario.rtl ? TextDirection.rtl : TextDirection.ltr,
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: TextField(
                  key: const ValueKey('date-header-draft'),
                  controller: fixture.draft,
                ),
              ),
              if (scenario.embedded)
                PositionedDirectional(
                  start: 24,
                  top: 112,
                  bottom: 16,
                  width: 280,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: SizedBox(
                      key: const ValueKey('date-header-embedded-surface'),
                      width: 280,
                      child: SkedDatePicker(
                        embedded: true,
                        initialDate: DateTime(2026, 10, 18),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        commitMode: DatePickerCommitMode.immediate,
                        onSelected: fixture.results.add,
                      ),
                    ),
                  ),
                )
              else
                PositionedDirectional(
                  start: 24,
                  top: 112,
                  width: 200,
                  child: Builder(
                    builder: (anchor) => TextButton(
                      key: const ValueKey('date-header-open'),
                      onPressed: () => unawaited(
                        showSkedDatePicker(
                          context: anchor,
                          anchorContext: anchor,
                          initialDate: DateTime(2026, 10, 18),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        ).then(fixture.results.add),
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
  await tester.enterText(_key('date-header-draft'), _draftText);
  if (!scenario.embedded) await tester.tap(_key('date-header-open'));
  await tester.pumpAndSettle();
  return fixture;
}

Offset _paddingPoint(WidgetTester tester, bool rtl) {
  final rect = tester.getRect(_material);
  // Hover the actual button padding, outside the label's tooltip region.
  return Offset(rtl ? rect.right - 6 : rect.left + 6, rect.center.dy);
}

void _expectInsets(WidgetTester tester, _Scenario scenario) {
  final painted = tester.getRect(_material);
  final text = tester.getRect(
    find.descendant(of: _label, matching: find.byType(RichText)).first,
  );
  final arrow = tester.getRect(
    find.descendant(of: _header, matching: find.byIcon(Icons.arrow_drop_down)),
  );
  // Material is the painted hover/focus surface. TextButton's outer tap target
  // can contain invisible space, so it is not a valid padding measurement.
  final leading = scenario.rtl
      ? painted.right - text.right
      : text.left - painted.left;
  final trailing = scenario.rtl
      ? arrow.left - painted.left
      : painted.right - arrow.right;
  final vertical = scenario.embedded ? 4.0 : 6.0;
  expect(leading, greaterThanOrEqualTo(11.9));
  expect(trailing, greaterThanOrEqualTo(11.9));
  expect(text.top - painted.top, greaterThanOrEqualTo(vertical - .1));
  expect(painted.bottom - text.bottom, greaterThanOrEqualTo(vertical - .1));
  expect(painted.left, greaterThanOrEqualTo(0));
  expect(painted.right, lessThanOrEqualTo(scenario.size.width));
  expect(painted.top, greaterThanOrEqualTo(0));
  expect(painted.bottom, lessThanOrEqualTo(scenario.size.height));
  expect(tester.takeException(), isNull);
}

bool _hasState(WidgetTester tester, WidgetState state) =>
    tester.widget<InkWell>(_ink).statesController!.value.contains(state);

void _expectVisibleFeedback(WidgetTester tester, WidgetState state) {
  final ink = tester.widget<InkWell>(_ink);
  final states = ink.statesController!.value;
  expect(states, contains(state));
  final color = ink.overlayColor?.resolve(states);
  expect(color, isNotNull);
  expect(color!.a, greaterThan(0));
}

Future<void> _focusHeader(WidgetTester tester, TestGesture mouse) async {
  await mouse.moveTo(const Offset(4, 4));
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  for (var step = 0; step < 12; step++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    if (_hasState(tester, WidgetState.focused)) return;
  }
  fail('Keyboard traversal did not reach the month/year button.');
}

void main() => runDateHeaderPaddingTests();

void runDateHeaderPaddingTests({DateHeaderPaddingCapture? capture}) {
  const scenarios = <_Scenario>[
    (
      name: 'floating',
      embedded: false,
      scale: 1,
      rtl: false,
      size: Size(900, 720),
    ),
    (
      name: 'embedded',
      embedded: true,
      scale: 1,
      rtl: false,
      size: Size(620, 720),
    ),
    (
      name: 'floating-narrow-2x-rtl',
      embedded: false,
      scale: 2,
      rtl: true,
      size: Size(480, 820),
    ),
  ];
  for (final scenario in scenarios) {
    testWidgets(
      '${scenario.name} date headers keep text inside painted feedback through browsing',
      (tester) async {
        final fixture = await _mount(tester, scenario);
        final surface = _key(
          scenario.embedded
              ? 'date-header-embedded-surface'
              : 'sked-date-picker-surface',
        );
        final origin = tester.getRect(surface).topLeft;
        final state = tester.state(find.byType(SkedDatePicker));
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: const Offset(4, 4));
        try {
          for (final page in ['days', 'months', 'years']) {
            expect(
              _key(switch (page) {
                'days' => 'sked-date-2026-10-18',
                'months' => 'sked-date-month-2026-10',
                _ => 'sked-date-year-2026',
              }),
              findsOneWidget,
            );
            FocusManager.instance.primaryFocus?.unfocus();
            await mouse.moveTo(_paddingPoint(tester, scenario.rtl));
            await tester.pumpAndSettle();
            _expectVisibleFeedback(tester, WidgetState.hovered);
            _expectInsets(tester, scenario);
            expect(
              RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
              WidgetStateMouseCursor.adaptiveClickable.resolve({
                WidgetState.hovered,
              }),
            );
            // Keep the pointer over the surface when the native runner captures.
            await capture?.call(
              tester,
              'date-header-${scenario.name}-$page-hover',
            );
            if (scenario.name == 'floating' && page == 'days') {
              await _focusHeader(tester, mouse);
              _expectVisibleFeedback(tester, WidgetState.focused);
              _expectInsets(tester, scenario);
              await capture?.call(tester, 'date-header-floating-days-focus');
            }
            expect(tester.getRect(surface).topLeft, origin);
            expect(tester.state(find.byType(SkedDatePicker)), same(state));
            expect(fixture.results, isEmpty);
            expect(fixture.draft.text, _draftText);
            final point = _paddingPoint(tester, scenario.rtl);
            await mouse.moveTo(point);
            await mouse.down(point);
            await mouse.up();
            await tester.pumpAndSettle();
          }
          if (!scenario.embedded) {
            final point = _paddingPoint(tester, scenario.rtl);
            await mouse.moveTo(point);
            await mouse.down(point);
            await mouse.moveBy(const Offset(40, 16));
            await tester.pump();
            await mouse.up();
            await tester.pumpAndSettle();
            expect(tester.getRect(surface).topLeft, origin);
            expect(_key('sked-date-2026-10-18'), findsOneWidget);
            expect(fixture.results, isEmpty);
            await tester.ensureVisible(_key('sked-date-cancel'));
            await tester.tap(_key('sked-date-cancel'));
            await tester.pumpAndSettle();
            expect(fixture.results, [null]);
          }
          expect(fixture.draft.text, _draftText);
          expect(tester.takeException(), isNull);
        } finally {
          await mouse.removePointer();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}
