import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
void _size(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  addTearDown(t.view.resetViewPadding);
  addTearDown(t.view.resetViewInsets);
}

Future<void> _open(
  WidgetTester t,
  TimetableProvider p,
  String kind,
  List<Object?> results, {
  double scale = 1,
  Brightness brightness = Brightness.light,
  FocusNode? triggerFocus,
  int weeks = 18,
}) async {
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: const Locale('zh'),
      textScale: scale,
      brightness: brightness,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 90, left: 20),
            child: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open-picker'),
                focusNode: triggerFocus,
                onPressed: () async {
                  final Object? result;
                  if (kind == 'date') {
                    result = await showSkedDatePicker(
                      context: context,
                      anchorContext: context,
                      workspace: AppMode.general,
                      initialDate: DateTime(2026, 9, 23),
                      firstDate: DateTime(1970),
                      lastDate: DateTime(2100),
                    );
                  } else if (kind == 'time') {
                    result = await showSkedTimePicker(
                      context: context,
                      anchorContext: context,
                      workspace: AppMode.general,
                      initialTime: const TimeOfDay(hour: 23, minute: 59),
                      alwaysUse24HourFormat: true,
                    );
                  } else {
                    result = await showSkedWeekPicker(
                      context: context,
                      anchorContext: context,
                      selectedWeek: weeks,
                      config: TimetableConfig(
                        name: '2026 秋季学期',
                        startDate: DateTime(2026, 9, 7),
                        totalWeeks: weeks,
                        periodTimeSetId: defaultPeriodTimeSetId,
                      ),
                    );
                  }
                  results.add(result);
                },
                child: const Text('打开选择器'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(_key('open-picker'));
  await t.pumpAndSettle();
}

String _close(String kind) =>
    kind == 'time' ? 'sked-time-cancel' : 'sked-$kind-picker-close';

void main() {
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      for (final kind in ['date', 'time', 'week']) {
        testWidgets(
          '$kind phone $width scale $scale is content-height and paints its bottom inset',
          (t) async {
            _size(t, Size(width, 900));
            final p = await workspaceProvider();
            addTearDown(p.dispose);
            final results = <Object?>[];
            final brightness = scale == 1.3
                ? Brightness.dark
                : Brightness.light;
            await _open(
              t,
              p,
              kind,
              results,
              scale: scale,
              brightness: brightness,
            );
            final surface = _key('sked-$kind-picker-surface');
            final rect = t.getRect(surface);
            expect(rect.left, 0);
            expect(rect.right, width);
            expect(rect.bottom, 900);
            expect(
              rect.top,
              greaterThan(100),
              reason: 'Small pickers must not become fullscreen',
            );
            final systemStyle = t
                .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
                  find
                      .ancestor(
                        of: surface,
                        matching: find.byType(
                          AnnotatedRegion<SystemUiOverlayStyle>,
                        ),
                      )
                      .first,
                )
                .value;
            final theme = Theme.of(t.element(surface));
            expect(
              systemStyle.systemNavigationBarColor,
              theme.colorScheme.surface,
            );
            expect(
              systemStyle.systemNavigationBarIconBrightness,
              brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            );
            final close = _key(_close(kind));
            expect(close.hitTestable(), findsOneWidget);
            expect(t.getRect(close).bottom, lessThanOrEqualTo(900 - 24));
            if (kind == 'time') {
              expect(t.testTextInput.isVisible, isFalse);
              final wheel = t.widget<ListWheelScrollView>(
                _key('sked-time-minute-wheel'),
              );
              expect(
                t.getSize(_key('sked-time-minute-wheel')).height,
                closeTo(wheel.itemExtent * 5, .01),
              );
            }
            await t.tap(close);
            await t.pumpAndSettle();
            expect(results, [null]);
            expect(t.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.android),
        );
      }
    }
  }

  testWidgets(
    'single-week sheet occupies only one grid row, external cancel restores focus',
    (t) async {
      _size(t, const Size(393, 852));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final results = <Object?>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await _open(t, p, 'week', results, weeks: 1, triggerFocus: focus);
      expect(t.getSize(_key('sked-week-picker-surface')).height, lessThan(200));
      await t.tapAt(const Offset(200, 220));
      await t.pumpAndSettle();
      expect(results, [null]);
      expect(focus.hasFocus, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'time draft survives IME and rotation with footer immediately reachable',
    (t) async {
      _size(t, const Size(393, 852));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final results = <Object?>[];
      await _open(t, p, 'time', results, scale: 1.3);
      final state = t.state(find.byType(SkedTimePicker));
      await t.enterText(_key('sked-time-hour-input'), '19');
      await t.enterText(_key('sked-time-minute-input'), '');
      t.view.viewInsets = const FakeViewPadding(bottom: 320);
      t.view.padding = const FakeViewPadding(top: 24);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedTimePicker)), same(state));
      expect(t.getRect(_key('sked-time-picker-surface')).bottom, 532);
      expect(_key('sked-time-cancel').hitTestable(), findsOneWidget);
      expect(_key('sked-time-confirm').hitTestable(), findsOneWidget);
      expect(
        t.widget<FilledButton>(_key('sked-time-confirm')).onPressed,
        isNull,
      );
      await t.enterText(_key('sked-time-minute-input'), '17');
      await t.pumpAndSettle();
      t.view.physicalSize = const Size(852, 393);
      t.view.viewInsets = const FakeViewPadding(bottom: 170);
      await t.pumpAndSettle();
      expect(t.state(find.byType(SkedTimePicker)), same(state));
      expect(
        t.widget<TextField>(_key('sked-time-hour-input')).controller!.text,
        '19',
      );
      expect(
        t.widget<TextField>(_key('sked-time-minute-input')).controller!.text,
        '17',
      );
      expect(_key('sked-time-cancel').hitTestable(), findsOneWidget);
      expect(_key('sked-time-confirm').hitTestable(), findsOneWidget);
      final confirm = t
          .widget<FilledButton>(_key('sked-time-confirm'))
          .onPressed!;
      await t.tap(_key('sked-time-confirm'));
      confirm();
      await t.pumpAndSettle();
      expect(results, [const TimeOfDay(hour: 19, minute: 17)]);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('wheel drag selects without dismissing its bottom task', (
    t,
  ) async {
    _size(t, const Size(360, 800));
    final p = await workspaceProvider();
    addTearDown(p.dispose);
    final results = <Object?>[];
    await _open(t, p, 'time', results);
    final wheel = _key('sked-time-minute-wheel');
    await t.drag(wheel, const Offset(0, 120));
    await t.pumpAndSettle();
    expect(find.byType(SkedTimePicker), findsOneWidget);
    expect(results, isEmpty);
    expect(
      t.widget<TextField>(_key('sked-time-hour-input')).controller!.text,
      '23',
    );
    expect(
      t.widget<TextField>(_key('sked-time-minute-input')).controller!.text,
      isNot('59'),
    );
    await t.sendEventToBinding(
      PointerScrollEvent(
        kind: PointerDeviceKind.mouse,
        position: t.getCenter(wheel),
        scrollDelta: const Offset(0, 52),
      ),
    );
    await t.pumpAndSettle();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(results, [null]);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final kind in ['date', 'time', 'week']) {
    for (final replaceData in [false, true]) {
      testWidgets('$kind bottom task invalidates on replace=$replaceData', (
        t,
      ) async {
        _size(t, const Size(360, 800));
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        final backup = await p.exportAppDataJson();
        final results = <Object?>[];
        await _open(t, p, kind, results);
        if (replaceData) {
          await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
        } else {
          await p.setWorkspaceEnabled(
            kind == 'week' ? AppMode.student : AppMode.general,
            false,
          );
        }
        await t.pumpAndSettle();
        expect(_key('sked-$kind-picker-surface'), findsNothing);
        expect(results, [null]);
        expect(t.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }
  }

  testWidgets(
    'tablet week picker remains centered, not a full-width bottom task',
    (t) async {
      _size(t, const Size(800, 1280));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final results = <Object?>[];
      await _open(t, p, 'week', results);
      final rect = t.getRect(_key('sked-week-picker-surface'));
      expect(rect.width, 360);
      expect(rect.center, const Offset(400, 640));
      expect(rect.bottom, lessThan(1000));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
