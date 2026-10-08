import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _editor => find.byType(GeneralEventEditorSheet);
Finder _inside(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);
Finder _menuValue(String value) => find
    .byWidgetPredicate(
      (widget) => widget is PopupMenuItem<String> && widget.value == value,
    )
    .hitTestable();

typedef _Fixture = ({
  TimetableProvider provider,
  WorkspaceMemoryStorage storage,
  DateTime date,
});

Future<_Fixture> _mount(
  WidgetTester tester, {
  required bool phone,
  String view = generalViewDay,
  int startHour = 6,
  int endHour = 23,
  DateTime? date,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = phone
      ? const Size(430, 950)
      : const Size(1600, 1000);
  addTearDown(tester.view.reset);
  // A future Monday always exercises the non-today default and remains visible
  // in the first week column, without relying on the host's calendar date.
  final selectedDate =
      date ??
      startOfCalendarWeek(
        addCalendarDays(DateTime.now(), 7),
        firstWeekday: DateTime.monday,
      );
  final storage = WorkspaceMemoryStorage(
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        activeScheduleId: 'work',
        defaultView: view,
        viewSwitchBehavior: generalViewSwitchBehaviorMenu,
        selectedDateIso: selectedDate.toIso8601String().split('T').first,
        dayStartHour: startHour,
        dayEndHour: endHour,
        timeGridMinutes: 15,
        schedules: const [
          GeneralSchedule(id: 'work', name: 'Work', events: []),
        ],
      ),
    ),
  );
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: storage,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    provider.dispose();
  });
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      home: GeneralReminderTimeScope(
        now: () => DateTime(2026, 1, 1, 8),
        createTimer: (delay, callback) => Timer(delay, callback),
        child: const GeneralScheduleHomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (provider: provider, storage: storage, date: selectedDate);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _saveTitle(WidgetTester tester, String title) async {
  await tester.enterText(
    _inside(_editor, find.byType(EditableText)).first,
    title,
  );
  await _tap(
    tester,
    _inside(_editor, find.widgetWithText(FilledButton, 'Save')),
  );
  expect(_editor, findsNothing);
}

Future<void> _switchView(WidgetTester tester, String view) async {
  await _tap(tester, _key('general-view-switcher'));
  await _tap(tester, _menuValue(view));
}

void _expectCalendarTitle(String title) {
  expect(
    // Cross-midnight events use the spanning lane above the timed grid.
    _inside(_key('workspace-canvas-viewport'), find.text(title)).hitTestable(),
    findsOneWidget,
  );
}

void main() {
  for (final phone in [true, false]) {
    for (final (startHour, endHour) in [(6, 23), (23, 24)]) {
      testWidgets(
        '${phone ? 'phone' : 'desktop'} title-only creation is visible from $startHour:00',
        (tester) async {
          final f = await _mount(
            tester,
            phone: phone,
            startHour: startHour,
            endHour: endHour,
          );
          await _tap(
            tester,
            phone ? find.byTooltip('Add event') : _key('general-add-event'),
          );
          final expected = DateTime(
            f.date.year,
            f.date.month,
            f.date.day,
            startHour,
          );
          expect(
            tester.widget<GeneralEventEditorSheet>(_editor).initialDate,
            expected,
          );
          await _saveTitle(tester, 'Created with default time');

          final saved =
              f.storage.data.generalMode.schedules.single.events.single;
          expect(DateTime.parse(saved.startDateTimeIso), expected);
          expect(
            DateTime.parse(saved.endDateTimeIso),
            expected.add(const Duration(hours: 1)),
          );
          expect(f.provider.selectedGeneralDate, f.date);
          _expectCalendarTitle('Created with default time');
          await _switchView(tester, generalViewWeek);
          _expectCalendarTitle('Created with default time');
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(
          phone ? TargetPlatform.android : TargetPlatform.windows,
        ),
      );
    }

    for (final source in ['agenda', 'month']) {
      testWidgets(
        '${phone ? 'phone' : 'desktop'} $source creation uses the selected date and display start',
        (tester) async {
          final f = await _mount(
            tester,
            phone: phone,
            view: source == 'month' ? generalViewMonth : generalViewDay,
            startHour: 9,
            endHour: 18,
          );
          if (source == 'month') {
            await _tap(
              tester,
              _key(
                phone ? 'general-month-agenda-add' : 'general-day-agenda-add',
              ),
            );
          } else {
            final agendaAction = _key('general-day-agenda-toggle');
            if (agendaAction.evaluate().isNotEmpty) {
              await _tap(tester, agendaAction);
            } else {
              await _tap(tester, _key('general-toolbar-more-button'));
              await _tap(tester, _menuValue('agenda'));
            }
            await _tap(
              tester,
              _inside(
                _key('general-selected-day-agenda'),
                find.text('Add event'),
              ),
            );
          }
          final expected = DateTime(f.date.year, f.date.month, f.date.day, 9);
          expect(
            tester.widget<GeneralEventEditorSheet>(_editor).initialDate,
            expected,
          );
          await _saveTitle(tester, 'Created from $source');

          final saved =
              f.storage.data.generalMode.schedules.single.events.single;
          expect(DateTime.parse(saved.startDateTimeIso), expected);
          expect(f.provider.selectedGeneralDate, f.date);
          if (source == 'month') {
            await _switchView(tester, generalViewDay);
          } else {
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          _expectCalendarTitle('Created from $source');
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(
          phone ? TargetPlatform.android : TargetPlatform.windows,
        ),
      );
    }

    for (final view in [generalViewDay, generalViewWeek]) {
      for (final clickedMinutes in [0, 23 * 60 + 30]) {
        testWidgets(
          '${phone ? 'phone' : 'desktop'} $view grid preserves an explicit start at minute $clickedMinutes',
          (tester) async {
            final startHour = clickedMinutes == 0 ? 0 : 23;
            final endHour = startHour + 1;
            final f = await _mount(
              tester,
              phone: phone,
              view: view,
              startHour: startHour,
              endHour: endHour,
              date: DateTime(2026, 12, 31),
            );
            final slot = _key(
              'general-timeline-empty-slot-${f.date.toIso8601String()}',
            );
            await tester.ensureVisible(slot);
            await tester.pumpAndSettle();
            final rect = tester.getRect(slot);
            final elapsed = clickedMinutes - startHour * 60;
            final point = Offset(
              rect.center.dx,
              rect.top + (elapsed == 0 ? 1 : rect.height * elapsed / 60),
            );
            if (phone) {
              await tester.longPressAt(point);
            } else {
              await tester.tapAt(point);
              await tester.pump(const Duration(milliseconds: 80));
              await tester.tapAt(point);
            }
            await tester.pumpAndSettle();
            final expected = DateTime(
              2026,
              12,
              31,
              clickedMinutes ~/ 60,
              clickedMinutes % 60,
            );
            expect(
              tester.widget<GeneralEventEditorSheet>(_editor).initialDate,
              expected,
            );
            await _saveTitle(tester, 'Explicit grid time');

            final saved =
                f.storage.data.generalMode.schedules.single.events.single;
            expect(DateTime.parse(saved.startDateTimeIso), expected);
            expect(
              DateTime.parse(saved.endDateTimeIso),
              expected.add(const Duration(hours: 1)),
            );
            _expectCalendarTitle('Explicit grid time');
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(
            phone ? TargetPlatform.android : TargetPlatform.windows,
          ),
        );
      }
    }
  }
}
