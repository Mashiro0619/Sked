import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/agenda_detail_harness.dart';
import '../support/desktop_panel_harness.dart';
import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
Finder get agenda => k('general-selected-day-agenda');
Finder get reminders => k('general-reminders-list');
Finder get detail => find.byType(GeneralEventDetailsSheet);
Finder get surface => k('workspace-companion-view-surface');
Finder inside(String key) => find.descendant(of: detail, matching: k(key));
Finder row(int i, {bool reminder = false}) => find.descendant(
  of: reminder ? reminders : agenda,
  matching: find.text(i == 0 ? 'Review session' : 'Event $i'),
);
Finder get agendaClose =>
    find.descendant(of: agenda, matching: k('workspace-inspector-close'));
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);

Future<TimetableProvider> mount(
  WidgetTester t, {
  bool fixed = false,
  GeneralReminderStartupSession? startupSession,
  WorkspaceMemoryStorage? storage,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
  Size size = const Size(1440, 900),
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
  final p = await workspaceProvider(
    mode: AppMode.general,
    storage:
        storage ??
        agendaDetailStorage(view: fixed ? generalViewMonth : generalViewWeek),
  );
  addTearDown(p.dispose);
  await t.pumpWidget(
    agendaDetailHarness(
      p,
      scale: scale,
      direction: direction,
      startupSession: startupSession,
    ),
  );
  await t.pumpAndSettle();
  if (!fixed) {
    if (k('general-day-agenda-toggle').evaluate().isEmpty) {
      await t.tap(k('general-desktop-toolbar-more'));
      await t.pumpAndSettle();
    }
    await t.tap(k('general-day-agenda-toggle'));
    await t.pumpAndSettle();
  }
  return p;
}

Future<TestGesture> mouse(WidgetTester t) async {
  final m = await t.createGesture(kind: PointerDeviceKind.mouse);
  await m.addPointer(location: const Offset(2, 2));
  return m;
}

Future<void> hover(WidgetTester t, TestGesture m, Finder target) async {
  await m.moveTo(t.getCenter(target));
  await t.pump(const Duration(milliseconds: 301));
  await t.pumpAndSettle();
}

class _GateStorage extends WorkspaceMemoryStorage {
  _GateStorage(super.data);
  Completer<void>? gate;
  @override
  Future<void> save(AppData value) async {
    await gate?.future;
    await super.save(value);
  }
}

void main() {
  for (final fixed in [false, true]) {
    testWidgets(
      'agenda preview delay, corridor and no focus or X; fixed=$fixed',
      (t) async {
        await mount(t, fixed: fixed);
        final parent = t.element(agenda), geometry = t.getRect(agenda);
        final focus = FocusManager.instance.primaryFocus;
        final m = await mouse(t);
        await m.moveTo(t.getCenter(row(0)));
        await t.pump(const Duration(milliseconds: 299));
        expect(detail, findsNothing);
        await t.pump(const Duration(milliseconds: 1));
        await t.pump();
        expect(detail, findsOneWidget);
        expect(inside('workspace-inspector-close'), findsNothing);
        expect(inside('workspace-view-drag-handle'), findsNothing);
        expect(find.text('Open independently'), findsOneWidget);
        expect(FocusManager.instance.primaryFocus, same(focus));
        final anchor = t.getRect(
          k(
            'general-agenda-${buildGeneralOccurrenceKey('panel-calendar', 'panel-event-0', '2026-09-28T19:00:00.000')}',
          ),
        );
        final rect = t.getRect(surface);
        expect(rect.right, closeTo(anchor.left - 6, 1));
        await m.moveTo(Offset((rect.right + anchor.left) / 2, anchor.top + 10));
        await t.pump(const Duration(milliseconds: 250));
        expect(detail, findsOneWidget);
        await m.moveTo(rect.center);
        await t.pump(const Duration(milliseconds: 400));
        expect(detail, findsOneWidget);
        await m.moveTo(const Offset(10, 850));
        await t.pump(const Duration(milliseconds: 199));
        expect(detail, findsOneWidget);
        await t.pump(const Duration(milliseconds: 1));
        await t.pump();
        expect(detail, findsNothing);
        expect(t.element(agenda), same(parent));
        expect(t.getRect(agenda), geometry);
        expect(FocusManager.instance.primaryFocus, same(focus));
        await m.removePointer();
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'agenda promotion preserves element and scroll; own X and source X are independent',
    (t) async {
      await mount(t, storage: agendaDetailStorage(longNotes: true));
      final m = await mouse(t);
      await hover(t, m, row(0));
      await t.drag(inside('workspace-view-body'), const Offset(0, -150));
      await t.pumpAndSettle();
      final element = t.element(detail);
      final body = t.state<ScrollableState>(
        find.descendant(of: detail, matching: find.byType(Scrollable)).last,
      );
      final scroll = body.position.pixels;
      expect(scroll, greaterThan(0));
      await t.tap(k('reminder-detail-detach'));
      await t.pumpAndSettle();
      expect(t.element(detail), same(element));
      expect(body.position.pixels, scroll);
      await t.drag(inside('workspace-view-drag-handle'), const Offset(-55, 15));
      await t.pumpAndSettle();
      final pos = t.getRect(surface);
      await t.tap(agendaClose);
      await t.pumpAndSettle();
      expect(agenda, findsNothing);
      expect(t.element(detail), same(element));
      expect(t.getRect(surface), pos);
      expect(body.position.pixels, scroll);
      await t.tapAt(const Offset(280, 700));
      await t.pumpAndSettle();
      expect(detail, findsOneWidget);
      await t.tap(inside('workspace-inspector-close'));
      await t.pumpAndSettle();
      expect(detail, findsNothing);
      await t.tap(k('general-day-agenda-toggle'));
      await t.pumpAndSettle();
      await m.moveTo(const Offset(2, 2));
      await hover(t, m, row(0));
      expect(detail, findsOneWidget);
      expect(inside('workspace-view-drag-handle'), findsNothing);
      expect(t.getRect(surface).left, isNot(pos.left));
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'agenda preview closes with date or source changes; independent detail survives',
    (t) async {
      final p = await mount(t);
      final m = await mouse(t);
      await hover(t, m, row(0));
      await p.setSelectedGeneralDate(DateTime(2026, 9, 29));
      await t.pumpAndSettle();
      expect(detail, findsNothing);
      await p.setSelectedGeneralDate(desktopPanelNow);
      await t.pumpAndSettle();
      await m.moveTo(const Offset(2, 2));
      await hover(t, m, row(0));
      await t.tap(agendaClose);
      await t.pumpAndSettle();
      expect(agenda, findsNothing);
      expect(detail, findsNothing);
      await t.tap(k('general-day-agenda-toggle'));
      await t.pumpAndSettle();
      await t.tap(row(0));
      await t.pumpAndSettle();
      final element = t.element(detail);
      await p.setSelectedGeneralDate(DateTime(2026, 9, 29));
      await t.pumpAndSettle();
      expect(t.element(detail), same(element));
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets('fixed agenda hiding on resize retires only preview', (t) async {
    await mount(t, fixed: true);
    final m = await mouse(t);
    await hover(t, m, row(0));
    t.view.physicalSize = const Size(1100, 900);
    await t.pumpAndSettle();
    expect(detail, findsNothing);
    t.view.physicalSize = const Size(1440, 900);
    await t.pumpAndSettle();
    await t.tap(row(0));
    await t.pumpAndSettle();
    final element = t.element(detail);
    t.view.physicalSize = const Size(1100, 900);
    await t.pumpAndSettle();
    expect(t.element(detail), same(element));
    await m.removePointer();
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  testWidgets(
    'simultaneous reminder and fixed agenda sources share one independent event',
    (t) async {
      await mount(t, fixed: true);
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      // Move the reminder list out of the fixed agenda to expose both sources.
      await t.drag(
        find.descendant(
          of: reminders,
          matching: k('workspace-view-drag-handle'),
        ),
        const Offset(-820, 180),
      );
      await t.pumpAndSettle();
      final m = await mouse(t);
      await hover(t, m, row(0));
      final first = t.element(detail);
      await t.tap(row(0));
      await t.pumpAndSettle();
      expect(t.element(detail), same(first));
      await t.drag(
        inside('workspace-view-drag-handle'),
        const Offset(-60, 320),
      );
      await t.pumpAndSettle();
      final pos = t.getRect(surface);
      await t.tap(row(0, reminder: true));
      await t.pumpAndSettle();
      expect(t.element(detail), same(first));
      expect(t.getRect(surface), pos);
      await hover(t, m, row(1));
      expect(t.element(detail), same(first));
      await t.tap(row(1));
      await t.pumpAndSettle();
      expect(detail, findsOneWidget);
      expect(
        find.descendant(of: detail, matching: find.text('Event 1')),
        findsOneWidget,
      );
      expect(t.getRect(surface).topLeft, pos.topLeft);
      await t.tap(
        find.descendant(
          of: reminders,
          matching: k('workspace-inspector-close'),
        ),
      );
      await t.pumpAndSettle();
      expect(detail, findsOneWidget);
      expect(agenda, findsOneWidget);
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'hover candidates from simultaneous sources keep the old panel until delay',
    (t) async {
      await mount(t, fixed: true);
      await t.tap(k('general-reminders-action'));
      await t.pumpAndSettle();
      await t.drag(
        find.descendant(
          of: reminders,
          matching: k('workspace-view-drag-handle'),
        ),
        const Offset(-820, 180),
      );
      await t.pumpAndSettle();
      final m = await mouse(t);
      await hover(t, m, row(0));
      final element = t.element(detail);
      final rect = t.getRect(surface);
      await m.moveTo(t.getCenter(row(1, reminder: true)));
      await t.pump(const Duration(milliseconds: 200));
      expect(t.element(detail), same(element));
      expect(t.getRect(surface), rect);
      await m.moveTo(rect.center);
      await t.pump(const Duration(milliseconds: 350));
      expect(t.element(detail), same(element));
      await hover(t, m, row(1, reminder: true));
      expect(detail, findsOneWidget);
      expect(
        find.descendant(of: detail, matching: find.text('Event 1')),
        findsOneWidget,
      );
      expect(t.getRect(surface), isNot(rect));
      await m.removePointer();
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'agenda ignores stylus hover; workspace/data retirement still wins',
    (t) async {
      final p = await mount(t);
      final pen = await t.createGesture(kind: PointerDeviceKind.stylus);
      await pen.addPointer(location: t.getCenter(row(0)));
      await t.pump(const Duration(milliseconds: 500));
      expect(detail, findsNothing);
      await pen.removePointer();
      await t.tap(row(0));
      await t.pumpAndSettle();
      final backup = await p.exportAppDataJson();
      await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      await t.pumpAndSettle();
      expect(detail, findsNothing);
      await t.tap(row(0));
      await t.pumpAndSettle();
      expect(detail, findsOneWidget);
      await t.pumpWidget(agendaDetailHarness(p, active: false));
      await t.pumpAndSettle();
      expect(detail, findsNothing);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets('scrolling one list cannot retire another list preview', (
    t,
  ) async {
    await mount(t, fixed: true);
    await t.tap(k('general-reminders-action'));
    await t.pumpAndSettle();
    await t.drag(
      find.descendant(of: reminders, matching: k('workspace-view-drag-handle')),
      const Offset(-820, 180),
    );
    await t.pumpAndSettle();
    final m = await mouse(t);
    await hover(t, m, row(0));
    final element = t.element(detail);
    await t.sendEventToBinding(
      PointerScrollEvent(
        position: t.getCenter(row(1, reminder: true)),
        scrollDelta: const Offset(0, 30),
      ),
    );
    await t.pumpAndSettle();
    expect(t.element(detail), same(element));
    await t.sendEventToBinding(
      PointerScrollEvent(
        position: t.getCenter(row(1)),
        scrollDelta: const Offset(0, 30),
      ),
    );
    await t.pumpAndSettle();
    expect(detail, findsNothing);
    await m.removePointer();
    await t.pumpWidget(const SizedBox());
  }, variant: desktop);

  testWidgets(
    'agenda details use latest data and reject editing while another editor is active',
    (t) async {
      final p = await mount(t);
      await t.tap(row(0));
      await t.pumpAndSettle();
      final element = t.element(detail);
      await t.tap(
        find.descendant(of: agenda, matching: k('general-day-agenda-add')),
      );
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      expect(
        t.widget<FilledButton>(inside('general-event-edit-action')).onPressed,
        isNull,
      );
      expect(t.element(detail), same(element));
      await t.tap(
        find.descendant(
          of: find.byType(GeneralEventEditorSheet),
          matching: find.text('Cancel'),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(agendaClose);
      await t.pumpAndSettle();
      final event = p.generalSchedules.single.events.first;
      await p.saveGeneralEvent(event.copyWith(notes: 'Latest agenda note'));
      await t.tap(inside('general-event-edit-action'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<GeneralEventEditorSheet>(
              find.byType(GeneralEventEditorSheet),
            )
            .initialEvent!
            .notes,
        'Latest agenda note',
      );
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'agenda deletion failure survives source close and retries without duplicate submit',
    (t) async {
      final storage = _GateStorage(agendaDetailStorage().data);
      final p = await mount(t, storage: storage);
      await t.tap(row(0));
      await t.pumpAndSettle();
      await t.tap(inside('general-event-delete-action'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      final gate = Completer<void>();
      storage.gate = gate;
      storage.saveError = StateError('Expected agenda deletion failure');
      await t.tap(k('general-event-confirm-delete'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(agendaClose);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(agenda, findsNothing);
      expect(detail, findsOneWidget);
      await t.tap(inside('workspace-inspector-close'));
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      expect(detail, findsOneWidget);
      gate.complete();
      await t.pumpAndSettle();
      expect(k('ui-command-failure-notice'), findsOneWidget);
      expect(p.generalSchedules.single.events, hasLength(3));
      await t.tap(k('ui-command-failure-dismiss'));
      await t.pumpAndSettle();
      await t.tap(inside('general-event-delete-action'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await t.tap(k('general-event-confirm-delete'));
      await t.pumpAndSettle();
      expect(detail, findsNothing);
      expect(p.generalSchedules.single.events, hasLength(2));
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'keyboard activation of an agenda row opens independent detail immediately',
    (t) async {
      await mount(t);
      final focus = Focus.of(t.element(row(0)));
      focus.requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await t.pumpAndSettle();
      expect(detail, findsOneWidget);
      expect(inside('workspace-view-drag-handle'), findsOneWidget);
      expect(k('reminder-detail-detach'), findsNothing);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(detail, findsNothing);
      expect(FocusScope.of(t.element(agenda)).hasFocus, isTrue);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'agenda Escape targets focus; closing detail restores source focus',
    (t) async {
      await mount(t);
      await t.tap(row(0));
      await t.pumpAndSettle();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(detail, findsNothing);
      expect(agenda, findsOneWidget);
      expect(FocusScope.of(t.element(agenda)).hasFocus, isTrue);
      await t.tap(row(0));
      await t.pumpAndSettle();
      FocusScope.of(t.element(agenda)).requestFocus();
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(agenda, findsNothing);
      expect(detail, findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'agenda bounds, body scroll and source-independent geometry $direction $scale',
        (t) async {
          await mount(
            t,
            scale: scale,
            direction: direction,
            storage: agendaDetailStorage(longNotes: true),
          );
          await t.tap(row(0));
          await t.pumpAndSettle();
          // Adjacent overlap is allowed at 2x: uncover the source X first.
          await t.drag(
            inside('workspace-view-drag-handle'),
            Offset(direction == TextDirection.rtl ? 65 : -65, 0),
          );
          await t.pumpAndSettle();
          await t.drag(inside('workspace-view-body'), const Offset(0, -120));
          await t.pumpAndSettle();
          final pos = t.getRect(surface);
          final body = t.state<ScrollableState>(
            find.descendant(of: detail, matching: find.byType(Scrollable)).last,
          );
          final offset = body.position.pixels;
          await t.tap(agendaClose);
          await t.pumpAndSettle();
          expect(t.getRect(surface), pos);
          expect(body.position.pixels, offset);
          t.view.physicalSize = const Size(900, 600);
          t.view.viewInsets = const FakeViewPadding(bottom: 100);
          await t.pumpAndSettle();
          final bounds = t.getRect(surface);
          expect(bounds.left, greaterThanOrEqualTo(8));
          expect(bounds.right, lessThanOrEqualTo(892));
          expect(bounds.bottom, lessThanOrEqualTo(492));
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
        variant: desktop,
      );
    }
  }
  for (final priorHover in [false, true]) {
    testWidgets(
      'agenda activation does not cancel reminder startup timeout: priorHover=$priorHover',
      (t) async {
        final storage = agendaDetailStorage(view: generalViewMonth, count: 8);
        final calendar = storage.data.generalMode.schedules.single;
        storage.data = storage.data.copyWith(
          generalMode: storage.data.generalMode.copyWith(
            schedules: [
              calendar.copyWith(
                events: [
                  for (final event in calendar.events)
                    event.copyWith(
                      reminders: event.id == 'panel-event-0'
                          ? event.reminders
                          : [],
                    ),
                ],
              ),
            ],
          ),
        );
        await mount(
          t,
          fixed: true,
          storage: storage,
          startupSession: GeneralReminderStartupSession(),
        );
        final m = await mouse(t);
        if (priorHover) {
          await hover(t, m, row(0, reminder: true));
          await m.moveTo(const Offset(250, 850));
          await t.pump(const Duration(milliseconds: 250));
          await t.pumpAndSettle();
          expect(detail, findsNothing);
        }
        await t.tap(row(7));
        await t.pumpAndSettle();
        expect(detail, findsOneWidget);
        await t.tap(inside('workspace-inspector-close'));
        await t.pumpAndSettle();
        await m.moveTo(const Offset(250, 850));
        await t.pump(const Duration(seconds: 11));
        await t.pumpAndSettle();
        expect(reminders, findsNothing);
        expect(agenda, findsOneWidget);
        expect(t.takeException(), isNull);
        await m.removePointer();
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  for (final toReminder in [false, true]) {
    for (final action in ['close', 'cancel-delete', 'failed-delete']) {
      testWidgets(
        'same instance cross-list focus survives detail action: reminder=$toReminder action=$action',
        (t) async {
          final storage = agendaDetailStorage(view: generalViewMonth);
          await mount(t, fixed: true, storage: storage);
          await t.tap(k('general-reminders-action'));
          await t.pumpAndSettle();
          await t.drag(
            find.descendant(
              of: reminders,
              matching: k('workspace-view-drag-handle'),
            ),
            const Offset(-820, 180),
          );
          await t.pumpAndSettle();
          await t.tap(row(0, reminder: !toReminder));
          await t.pumpAndSettle();
          await t.drag(
            inside('workspace-view-drag-handle'),
            const Offset(0, 400),
          );
          await t.pumpAndSettle();
          final element = t.element(detail);
          final position = t.getRect(surface);
          await t.tap(row(0, reminder: toReminder));
          await t.pumpAndSettle();
          final entryFocus = Focus.of(t.element(row(0, reminder: toReminder)));
          expect(t.element(detail), same(element));
          expect(t.getRect(surface), position);
          if (action != 'close') {
            await t.tap(inside('general-event-delete-action'));
            await t.pump();
            await t.pump(const Duration(seconds: 1));
            if (action == 'cancel-delete') {
              await t.tap(
                find.descendant(
                  of: k('general-event-delete-dialog'),
                  matching: find.text('Cancel'),
                ),
              );
            } else {
              storage.saveError = StateError(
                'Expected cross-source delete failure',
              );
              await t.tap(k('general-event-confirm-delete'));
            }
            await t.pumpAndSettle();
            if (action == 'failed-delete') {
              await t.tap(k('ui-command-failure-dismiss'));
              await t.pumpAndSettle();
            }
            expect(t.element(detail), same(element));
            expect(t.getRect(surface), position);
          }
          await t.tap(inside('workspace-inspector-close'));
          await t.pumpAndSettle();
          expect(detail, findsNothing);
          expect(entryFocus.hasFocus, isTrue);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
        variant: desktop,
      );
    }
  }

  for (final fixed in [false, true]) {
    for (final phase in ['pending', 'preview', 'independent']) {
      testWidgets(
        'cross-day agenda context invalidates only transient state: fixed=$fixed phase=$phase',
        (t) async {
          final storage = agendaDetailStorage(
            view: fixed ? generalViewMonth : generalViewWeek,
            count: 1,
          );
          final calendar = storage.data.generalMode.schedules.single;
          storage.data = storage.data.copyWith(
            generalMode: storage.data.generalMode.copyWith(
              schedules: [
                calendar.copyWith(
                  events: [
                    calendar.events.single.copyWith(
                      isAllDay: true,
                      startDateTimeIso: '2026-09-28T00:00:00.000',
                      endDateTimeIso: '2026-09-30T00:00:00.000',
                    ),
                  ],
                ),
              ],
            ),
          );
          final p = await mount(t, fixed: fixed, storage: storage);
          final m = await mouse(t);
          await m.moveTo(t.getCenter(row(0)));
          await t.pump(Duration(milliseconds: phase == 'pending' ? 150 : 301));
          if (phase != 'pending') {
            await t.pumpAndSettle();
            await m.moveTo(t.getCenter(surface));
            await t.pump();
          }
          if (phase == 'independent') {
            await t.tap(k('reminder-detail-detach'));
            await t.pumpAndSettle();
          }
          final element = phase == 'independent' ? t.element(detail) : null;
          final position = phase == 'independent' ? t.getRect(surface) : null;
          await p.setSelectedGeneralDate(DateTime(2026, 9, 29));
          await t.pumpAndSettle();
          await t.pump(const Duration(milliseconds: 500));
          await t.pumpAndSettle();
          expect(row(0), findsOneWidget);
          if (phase == 'independent') {
            expect(t.element(detail), same(element));
            expect(t.getRect(surface), position);
          } else {
            expect(detail, findsNothing);
            await m.moveTo(const Offset(250, 850));
            await hover(t, m, row(0));
            expect(detail, findsOneWidget);
          }
          expect(t.takeException(), isNull);
          await m.removePointer();
          await t.pumpWidget(const SizedBox());
        },
        variant: desktop,
      );
    }
  }
}
