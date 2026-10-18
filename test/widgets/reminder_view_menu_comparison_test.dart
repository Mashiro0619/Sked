import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/course_system_reminder_field.dart';
import 'package:sked/widgets/sked_dropdown_menu.dart';

import '../support/workspace_harness.dart';

const reminderViewMenuCaptureKey = ValueKey('reminder-view-menu-capture');

typedef ReminderViewMenuCapture = Future<void> Function(
  WidgetTester tester,
  String scene,
);

enum _MenuKind { reminder, studentView }

const _away = Offset(680, 650);

Finder _text(String label) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == label);

// Scope the text to actual menu entries. The workspace also contains a day
// header named "日", and native checked entries ignore pointer hits on text.
Finder _entry(String label) => find
    .ancestor(
      of: _text(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem || widget is MenuItemButton,
      ),
    )
    .hitTestable();

Finder _label(String label) =>
    find.descendant(of: _entry(label), matching: _text(label));

Finder _row(String label) =>
    find.ancestor(of: _label(label), matching: find.byType(InkWell)).first;

Finder _surface(String label) => find
    .ancestor(
      of: _entry(label),
      matching: find.byWidgetPredicate(
        (widget) => widget is Material && widget.elevation > 0,
      ),
    )
    .first;

FocusNode _focus(WidgetTester tester, Finder label) {
  final ink = tester.widget<InkWell>(
    find.ancestor(of: label, matching: find.byType(InkWell)).first,
  );
  // The label is below InkWell's internal Focus, unlike InkWell's own context.
  return ink.focusNode ??
      Focus.of(tester.element(label), createDependency: false);
}

Set<WidgetState> _states(WidgetTester tester, String label) {
  final controller = tester.widget<InkWell>(_row(label)).statesController;
  expect(controller, isNotNull, reason: '$label must expose its actual states');
  return controller!.value;
}

void _expectStates(
  WidgetTester tester,
  String label,
  Set<WidgetState> expected,
) {
  final actual = _states(tester, label);
  for (final state in [
    WidgetState.hovered,
    WidgetState.focused,
    WidgetState.pressed,
  ]) {
    expect(
      actual.contains(state),
      expected.contains(state),
      reason: '$label: expected $expected, actual $actual',
    );
  }
}

class _Fixture {
  const _Fixture({
    required this.kind,
    required this.selectedLabel,
    required this.otherLabel,
    required this.width,
    required this.behavior,
    required this.minutes,
    required this.changes,
    required this.gateway,
  });

  final _MenuKind kind;
  final String selectedLabel, otherLabel;
  final ValueNotifier<double> width;
  final ValueNotifier<CourseReminderBehavior> behavior;
  final TextEditingController minutes;
  final List<CourseReminderBehavior> changes;
  final MemoryAgendaNotificationGateway gateway;

  Finder get trigger => find.byKey(
    ValueKey(
      kind == _MenuKind.reminder
          ? 'course-reminder-behavior'
          : 'student-view-toggle',
    ),
  );

  void expectDraft({bool changed = false}) {
    expect(minutes.text, '17');
    expect(gateway.scheduled, isEmpty);
    expect(
      changes,
      changed && kind == _MenuKind.reminder
          ? [CourseReminderBehavior.disabled]
          : isEmpty,
    );
    expect(
      behavior.value,
      changed && kind == _MenuKind.reminder
          ? CourseReminderBehavior.disabled
          : CourseReminderBehavior.inherit,
    );
    expect(
      find.descendant(
        of: kind == _MenuKind.reminder
            ? find.descendant(
                of: trigger,
                matching: find.byType(InputDecorator),
              )
            : trigger,
        matching: _text(changed ? otherLabel : selectedLabel),
      ),
      findsOneWidget,
    );
  }
}

Future<_Fixture> _mount(
  WidgetTester tester,
  _MenuKind kind, {
  Brightness brightness = Brightness.light,
  TextDirection direction = TextDirection.ltr,
}) async {
  final provider = await workspaceProvider(mode: AppMode.student, locale: 'zh');
  final width = ValueNotifier(240.0);
  final behavior = ValueNotifier(CourseReminderBehavior.inherit);
  final minutes = TextEditingController(text: '17');
  final changes = <CourseReminderBehavior>[];
  final gateway = MemoryAgendaNotificationGateway();
  final service = AgendaNotificationService(
    enabled: true,
    gateway: gateway,
    runtimeStore: MemoryAgendaNotificationRuntimeStore(),
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    service.dispose();
    minutes.dispose();
    behavior.dispose();
    width.dispose();
    provider.dispose();
  });
  await provider.studentCommands.setSelectedWeek(1);
  await tester.pumpWidget(
    RepaintBoundary(
      key: reminderViewMenuCaptureKey,
      child: WorkspaceHarness(
        key: ValueKey((kind, brightness, direction)),
        provider: provider,
        locale: const Locale('zh'),
        seedColor: const Color(0xff336699),
        brightness: brightness,
        textDirection: direction,
        home: kind == _MenuKind.studentView
            ? null
            : Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: ValueListenableBuilder<double>(
                      valueListenable: width,
                      builder: (context, fieldWidth, _) => SizedBox(
                        width: fieldWidth,
                        child: SingleChildScrollView(
                          child: ValueListenableBuilder<CourseReminderBehavior>(
                            valueListenable: behavior,
                            builder: (context, value, _) =>
                                CourseSystemReminderField(
                                  behavior: value,
                                  minutesController: minutes,
                                  notificationService: service,
                                  onChanged: (value) {
                                    changes.add(value);
                                    behavior.value = value;
                                  },
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final trigger = find.byKey(
    ValueKey(
      kind == _MenuKind.reminder
          ? 'course-reminder-behavior'
          : 'student-view-toggle',
    ),
  );
  expect(trigger.hitTestable(), findsOneWidget);
  final l10n = AppLocalizations.of(tester.element(trigger));
  final entries = kind == _MenuKind.reminder
      ? tester
            .widget<SkedDropdownMenu<CourseReminderBehavior>>(trigger)
            .dropdownMenuEntries
      : null;
  return _Fixture(
    kind: kind,
    selectedLabel: entries?.first.label ?? l10n.viewWeek,
    otherLabel: entries?[1].label ?? l10n.viewDay,
    width: width,
    behavior: behavior,
    minutes: minutes,
    changes: changes,
    gateway: gateway,
  );
}

Future<void> _prepareWindow(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1366, 768);
  addTearDown(tester.view.reset);
  final bridge = DesktopWindowBridge.instance;
  if (tester.binding is AutomatedTestWidgetsFlutterBinding) {
    const channel = MethodChannel('com.mashiro.sked/window');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final previous = (
      available: bridge.available,
      maximized: bridge.maximized,
      focused: bridge.focused,
      hovered: bridge.maximizeHovered,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      return call.method == 'initialize'
          ? {'maximized': false, 'focused': true}
          : null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      channel.setMethodCallHandler(null);
      bridge.available = previous.available;
      bridge.maximized = previous.maximized;
      bridge.focused = previous.focused;
      bridge.maximizeHovered = previous.hovered;
    });
  }
  // Native captures keep the real channel and real desktop chrome.
  await bridge.initialize();
}

Future<void> _mouseOpen(
  WidgetTester tester,
  TestGesture mouse,
  _Fixture fixture,
) async {
  final point = tester.getCenter(fixture.trigger);
  await mouse.moveTo(point);
  await mouse.down(point);
  await tester.pump();
  await mouse.up();
  await tester.pumpAndSettle();
  await mouse.moveTo(_away);
  await tester.pumpAndSettle();
}

typedef _Geometry = ({double start, double end, double height});

_Geometry _geometry(
  WidgetTester tester,
  String selected,
  String other,
  TextDirection direction,
) {
  final row = tester.getRect(_row(selected));
  final text = tester.getRect(_label(selected));
  final otherRow = tester.getRect(_row(other));
  final otherText = tester.getRect(_label(other));
  final check = find.descendant(
    of: _row(selected),
    matching: find.byIcon(Icons.check),
  );
  expect(check, findsOneWidget);
  final icon = tester.getRect(check);
  final ltr = direction == TextDirection.ltr;
  final start = ltr ? text.left - row.left : row.right - text.right;
  final otherStart = ltr
      ? otherText.left - otherRow.left
      : otherRow.right - otherText.right;
  final end = ltr ? row.right - icon.right : icon.left - row.left;
  final gap = ltr ? icon.left - text.right : text.left - icon.right;
  expect(start, closeTo(10, .1));
  expect(otherStart, closeTo(start, .1));
  expect(end, closeTo(10, .1));
  expect(gap, closeTo(8, .1), reason: 'Check belongs at the logical row end');
  expect(icon.width, closeTo(16, .1));
  expect(icon.height, closeTo(16, .1));
  // 32 is a minimum, with 6 px above and below text when the label needs more.
  expect(
    row.height,
    closeTo((text.height + 12).clamp(32, double.infinity), .1),
  );
  expect(
    otherRow.height,
    closeTo((otherText.height + 12).clamp(32, double.infinity), .1),
  );
  for (final (rowRect, labelRect) in [(row, text), (otherRow, otherText)]) {
    expect(labelRect.top - rowRect.top, greaterThanOrEqualTo(5.9));
    expect(rowRect.bottom - labelRect.bottom, greaterThanOrEqualTo(5.9));
  }
  for (final label in [selected, other]) {
    final style = tester
        .renderObject<RenderParagraph>(_label(label))
        .text
        .style!;
    expect(style.fontWeight, FontWeight.w400);
    expect(style.fontSize, 13);
  }
  expect(
    tester.renderObject<RenderParagraph>(_label(other)).constraints.maxWidth,
    closeTo(
      tester
          .renderObject<RenderParagraph>(_label(selected))
          .constraints
          .maxWidth,
      .1,
    ),
    reason: 'Unselected choices must reserve the same trailing check slot',
  );
  expect(
    find.descendant(of: _row(other), matching: find.byIcon(Icons.check)),
    findsNothing,
  );
  final surface = _surface(selected);
  final menu = tester.getRect(surface);
  expect(menu.width, inInclusiveRange(143.9, 360.1));
  final rows = [
    for (final element
        in find
            .descendant(of: surface, matching: find.byType(InkWell))
            .evaluate())
      tester.getRect(find.byWidget(element.widget)),
  ]..sort((a, b) => a.top.compareTo(b.top));
  expect(rows.first.top - menu.top, closeTo(4, .1));
  expect(menu.bottom - rows.last.bottom, closeTo(4, .1));
  expect(rows.first.left - menu.left, closeTo(4, .1));
  expect(menu.right - rows.first.right, closeTo(4, .1));
  for (var index = 1; index < rows.length; index++) {
    expect(rows[index].top - rows[index - 1].bottom, closeTo(0, .1));
  }
  expect(
    menu.height,
    closeTo(rows.fold<double>(8, (sum, rect) => sum + rect.height), .1),
  );
  return (start: start, end: end, height: row.height);
}

void _expectColor(Color actual, Color expected, String reason) {
  expect(actual.r, closeTo(expected.r, 2 / 255), reason: reason);
  expect(actual.g, closeTo(expected.g, 2 / 255), reason: reason);
  expect(actual.b, closeTo(expected.b, 2 / 255), reason: reason);
  expect(actual.a, closeTo(1, 1 / 255), reason: reason);
}

Future<List<Color>> _backgrounds(
  WidgetTester tester,
  List<String> labels,
  List<Color> expected,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(reminderViewMenuCaptureKey),
  );
  final points = [
    for (final label in labels)
      [
        // Sample a patch inside the row padding, clear of glyphs, checkmarks,
        // rounded corners and the separate 1 px keyboard focus outline.
        for (final dx in [4.0, 6.0])
          for (final dy in [-3.0, 0.0, 3.0])
            boundary.globalToLocal(
              tester.getRect(_row(label)).centerLeft + Offset(dx, dy),
            ),
      ],
  ];
  final patches = (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      return [
        for (final patch in points)
          [
            for (final point in patch)
              Color.fromARGB(
                bytes.getUint8(
                  (point.dy.floor() * image.width + point.dx.floor()) * 4 + 3,
                ),
                bytes.getUint8(
                  (point.dy.floor() * image.width + point.dx.floor()) * 4,
                ),
                bytes.getUint8(
                  (point.dy.floor() * image.width + point.dx.floor()) * 4 + 1,
                ),
                bytes.getUint8(
                  (point.dy.floor() * image.width + point.dx.floor()) * 4 + 2,
                ),
              ),
          ],
      ];
    } finally {
      image.dispose();
    }
  }))!;
  for (var index = 0; index < labels.length; index++) {
    for (final color in patches[index]) {
      _expectColor(
        color,
        expected[index],
        '${labels[index]} painted background',
      );
    }
  }
  return [for (final patch in patches) patch.first];
}

Future<List<Color>> _checkpoint(
  WidgetTester tester,
  _Fixture fixture,
  String scene,
  ReminderViewMenuCapture? capture, {
  Set<WidgetState> selectedStates = const {},
  Set<WidgetState> otherStates = const {},
  double selectedOpacity = .06,
  double otherOpacity = 0,
}) async {
  await capture?.call(tester, scene);
  _expectStates(tester, fixture.selectedLabel, selectedStates);
  _expectStates(tester, fixture.otherLabel, otherStates);
  expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
  final colors = Theme.of(tester.element(_surface(fixture.selectedLabel)))
      .colorScheme;
  Color blend(double opacity) => Color.alphaBlend(
    colors.primary.withValues(alpha: opacity),
    colors.surface,
  );
  return _backgrounds(
    tester,
    [fixture.selectedLabel, fixture.otherLabel],
    [blend(selectedOpacity), blend(otherOpacity)],
  );
}

void _expectFocusOutline(WidgetTester tester, String label) {
  final inks = find.descendant(of: _row(label), matching: find.byType(Ink));
  final decorations = tester
      .widgetList<Ink>(inks)
      .map((ink) => ink.decoration)
      .whereType<ShapeDecoration>();
  final ShapeBorder? shape;
  if (decorations.isNotEmpty) {
    shape = decorations.first.shape;
  } else {
    shape = tester
        .widget<Material>(
          find
              .ancestor(
                of: _row(label),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Material &&
                      widget.elevation == 0 &&
                      widget.shape is OutlinedBorder,
                ),
              )
              .first,
        )
        .shape;
  }
  expect(shape, isA<OutlinedBorder>());
  final side = (shape! as OutlinedBorder).side;
  expect(side.style, BorderStyle.solid);
  expect(side.width, closeTo(1, .01));
  expect(side.color.a, greaterThan(0));
}

Future<void> _keyboardFocus(WidgetTester tester, String label) async {
  // PopupRoute starts with a route focus scope; MenuAnchor starts at its
  // trigger. Use real traversal from either entry point, never mutate states.
  for (
    var step = 0;
    step < 3 && !_focus(tester, _label(label)).hasFocus;
    step++
  ) {
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
  }
  expect(_focus(tester, _label(label)).hasPrimaryFocus, isTrue);
}

void main() => runReminderViewMenuComparisonTests();

void runReminderViewMenuComparisonTests({ReminderViewMenuCapture? capture}) {
  for (final brightness in Brightness.values) {
    testWidgets('real reminder and student view menus share mouse and keyboard appearance '
        'in ${brightness.name}', (tester) async {
      await _prepareWindow(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: _away);
      addTearDown(mouse.removePointer);
      _Geometry? referenceGeometry;
      final referencePixels = <String, List<Color>>{};
      for (final kind in _MenuKind.values) {
        final fixture = await _mount(tester, kind, brightness: brightness);
        final prefix = 'reminder-view-${brightness.name}-${kind.name}';
        // A real keyboard event establishes Windows highlight mode. Every
        // subsequent pointer action is mouse down/up, never a touch tap.
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        final triggerFocus = _focus(
          tester,
          find.descendant(
            of: fixture.trigger,
            matching: _text(fixture.selectedLabel),
          ),
        );
        await _mouseOpen(tester, mouse, fixture);
        await capture?.call(tester, '$prefix-layout');
        final geometry = _geometry(
          tester,
          fixture.selectedLabel,
          fixture.otherLabel,
          TextDirection.ltr,
        );
        if (referenceGeometry == null) {
          referenceGeometry = geometry;
        } else {
          expect(geometry, referenceGeometry);
        }
        Future<void> check(
          String state, {
          Set<WidgetState> selected = const {},
          Set<WidgetState> other = const {},
          double selectedOpacity = .06,
          double opacity = 0,
        }) async {
          final pixels = await _checkpoint(
            tester,
            fixture,
            '$prefix-$state',
            capture,
            selectedStates: selected,
            otherStates: other,
            selectedOpacity: selectedOpacity,
            otherOpacity: opacity,
          );
          final previous = referencePixels[state];
          if (previous == null) {
            referencePixels[state] = pixels;
          } else {
            for (var index = 0; index < pixels.length; index++) {
              _expectColor(
                pixels[index],
                previous[index],
                '$state must match across entries',
              );
            }
          }
        }

        await check('mouse-idle');
        await mouse.moveTo(tester.getCenter(_row(fixture.selectedLabel)));
        await tester.pump();
        await check(
          'selected-hover-first-frame',
          selected: {WidgetState.hovered},
        );
        await tester.pump(const Duration(milliseconds: 50));
        await check('selected-hover-50ms', selected: {WidgetState.hovered});
        await tester.pumpAndSettle();
        await check('selected-hover', selected: {WidgetState.hovered});
        await mouse.moveTo(tester.getCenter(_row(fixture.otherLabel)));
        await tester.pump();
        await check(
          'other-hover-first-frame',
          other: {WidgetState.hovered},
          opacity: .04,
        );
        await tester.pump(const Duration(milliseconds: 50));
        await check(
          'other-hover-50ms',
          other: {WidgetState.hovered},
          opacity: .04,
        );
        await tester.pumpAndSettle();
        await check('other-hover', other: {WidgetState.hovered}, opacity: .04);
        await mouse.down(tester.getCenter(_row(fixture.otherLabel)));
        await tester.pump(kPressTimeout + const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        await check(
          'other-pressed',
          other: {WidgetState.hovered, WidgetState.pressed},
          opacity: .10,
        );
        fixture.expectDraft();
        // Moving far outside before release cancels the press without selecting.
        await mouse.moveTo(_away);
        await mouse.up();
        await tester.pumpAndSettle();
        await check('mouse-exit');
        fixture.expectDraft();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_entry(fixture.otherLabel), findsNothing);
        fixture.expectDraft();

        triggerFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await _keyboardFocus(tester, fixture.selectedLabel);
        await check(
          'selected-focus',
          selected: {WidgetState.focused},
          selectedOpacity: .08,
        );
        _expectFocusOutline(tester, fixture.selectedLabel);
        await mouse.moveTo(tester.getCenter(_row(fixture.selectedLabel)));
        await tester.pump();
        await mouse.down(tester.getCenter(_row(fixture.selectedLabel)));
        await tester.pump(kPressTimeout + const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        await check(
          'selected-focused-pressed',
          selected: {
            WidgetState.focused,
            WidgetState.hovered,
            WidgetState.pressed,
          },
          selectedOpacity: .10,
        );
        await mouse.moveTo(_away);
        await mouse.up();
        await tester.pumpAndSettle();
        await check(
          'selected-focus-after-cancel',
          selected: {WidgetState.focused},
          selectedOpacity: .08,
        );
        fixture.expectDraft();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        await check('other-focus', other: {WidgetState.focused}, opacity: .08);
        _expectFocusOutline(tester, fixture.otherLabel);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(_entry(fixture.otherLabel), findsNothing);
        expect(triggerFocus.hasPrimaryFocus, isTrue);
        fixture.expectDraft();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await _keyboardFocus(tester, fixture.otherLabel);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(_entry(fixture.otherLabel), findsNothing);
        fixture.expectDraft(changed: true);
        await _mouseOpen(tester, mouse, fixture);
        await capture?.call(tester, '$prefix-selection');
        expect(
          _geometry(
            tester,
            fixture.otherLabel,
            fixture.selectedLabel,
            TextDirection.ltr,
          ),
          geometry,
          reason:
              'Changing the checked item must not move labels or check slots',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        fixture.expectDraft(changed: true);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'real choices keep trailing RTL checks and content width when the field widens',
    (tester) async {
      await _prepareWindow(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: _away);
      addTearDown(mouse.removePointer);
      final reminder = await _mount(
        tester,
        _MenuKind.reminder,
        direction: TextDirection.rtl,
      );
      await _mouseOpen(tester, mouse, reminder);
      await capture?.call(tester, 'reminder-view-rtl-field-240');
      final geometry = _geometry(
        tester,
        reminder.selectedLabel,
        reminder.otherLabel,
        TextDirection.rtl,
      );
      expect(tester.getSize(reminder.trigger).width, closeTo(240, .1));
      final menuWidth = tester.getSize(_surface(reminder.selectedLabel)).width;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      reminder.width.value = 400;
      await tester.pumpAndSettle();
      await _mouseOpen(tester, mouse, reminder);
      await capture?.call(tester, 'reminder-view-rtl-field-400');
      expect(tester.getSize(reminder.trigger).width, closeTo(400, .1));
      expect(
        tester.getSize(_surface(reminder.selectedLabel)).width,
        closeTo(menuWidth, .1),
      );
      expect(
        _geometry(
          tester,
          reminder.selectedLabel,
          reminder.otherLabel,
          TextDirection.rtl,
        ),
        geometry,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      reminder.expectDraft();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final student = await _mount(
        tester,
        _MenuKind.studentView,
        direction: TextDirection.rtl,
      );
      await _mouseOpen(tester, mouse, student);
      await capture?.call(tester, 'reminder-view-rtl-student-view');
      expect(
        _geometry(
          tester,
          student.selectedLabel,
          student.otherLabel,
          TextDirection.rtl,
        ),
        geometry,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      student.expectDraft();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
