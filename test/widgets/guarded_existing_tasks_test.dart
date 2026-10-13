import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/sked_task_route.dart';
import 'package:sked/widgets/sked_task_header.dart';

import '../support/mobile_layout_data.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

class _GateStorage extends WorkspaceMemoryStorage {
  _GateStorage(super.data);

  int writes = 0;
  Completer<void>? gate;

  void hold() => gate = Completer<void>();

  void release() {
    final pending = gate;
    gate = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<void> save(AppData data) async {
    writes++;
    await gate?.future;
    await super.save(data);
  }
}

AppData _studentData() {
  final base = mobileLayoutData(locale: 'en');
  final periodTimeSet = base.studentMode.periodTimeSets.first;
  CourseItem course(String id, String name) => CourseItem(
    id: id,
    name: name,
    teacher: '',
    location: 'Room 101',
    dayOfWeek: 1,
    semesterWeeks: const [],
    periods: const [1, 2],
    startMinutes: 8 * 60,
    endMinutes: 9 * 60 + 40,
    timeRange: buildTimeRange(8 * 60, 9 * 60 + 40),
    credit: 0,
    remarks: '',
    customFields: const {},
  );
  final first = TimetableData(
    id: 'guarded-first',
    config: TimetableConfig(
      name: 'First timetable',
      startDate: DateTime(2026, 9, 21),
      totalWeeks: 20,
      periodTimeSetId: periodTimeSet.id,
    ),
    courses: [course('guarded-a', 'Course A'), course('guarded-b', 'Course B')],
  );
  return base.copyWith(
    activeMode: AppMode.student,
    studentMode: base.studentMode.copyWith(
      activeTimetableId: first.id,
      timetables: [
        first,
        first.copyWith(
          id: 'guarded-second',
          config: first.config.copyWith(name: 'Second timetable'),
          courses: const [],
        ),
      ],
    ),
  );
}

Future<(TimetableProvider, _GateStorage)> _mount(
  WidgetTester tester,
  AppData data,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
  final storage = _GateStorage(data);
  final provider = await workspaceProvider(storage: storage);
  addTearDown(provider.dispose);
  addTearDown(storage.release);
  await tester.pumpWidget(WorkspaceHarness(provider: provider));
  await tester.pumpAndSettle();
  return (provider, storage);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _dragWhileSaving(WidgetTester tester) async {
  final sheet = find.byType(BottomSheet).last;
  final header = find.descendant(
    of: sheet,
    matching: find.byType(SkedTaskHeader),
  );
  await tester.fling(header, const Offset(0, 450), 1600);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _completeWrite(WidgetTester tester, _GateStorage storage) async {
  storage.release();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets(
    'system recovery retires blocked sheets without requesting discard and retains its boundary',
    (tester) async {
      final provider = await workspaceProvider();
      addTearDown(provider.dispose);
      late BuildContext source;
      var rejectedExits = 0;
      Widget blockedTask(String label) => PopScope<void>(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) rejectedExits++;
        },
        child: SizedBox(height: 240, child: Text(label)),
      );
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: Builder(
            builder: (context) {
              source = context;
              return const Scaffold(body: Text('Recovery destination'));
            },
          ),
        ),
      );
      final retained = showAppModalSheet<void>(
        context: source,
        builder: (_) => blockedTask('Retained import draft'),
      );
      await tester.pumpAndSettle();
      final retainedContext = tester.element(
        find.text('Retained import draft'),
      );
      final boundary = ModalRoute.of(retainedContext)!;
      final retired = showAppModalSheet<void>(
        context: retainedContext,
        builder: (_) => blockedTask('Invalidated task'),
      );
      await tester.pumpAndSettle();
      final navigator = Navigator.of(source);

      retireSkedTaskRoutesUntil(
        navigator,
        (route) => identical(route, boundary) || route.isFirst,
      );
      expect(rejectedExits, 0);
      await tester.pumpAndSettle();
      await retired;
      expect(find.text('Invalidated task'), findsNothing);
      expect(find.text('Retained import draft'), findsOneWidget);
      expect(boundary.isCurrent, isTrue);
      expect(rejectedExits, 0);

      // System retirement must not leave the retained route authorized for
      // later user exits; it still enforces its own unfinished-task guard.
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(rejectedExits, 1);
      expect(boundary.isCurrent, isTrue);
      completeSkedTaskRoute(retainedContext);
      await tester.pumpAndSettle();
      await retained;
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Recovery destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'mobile timetable switch blocks dragging during persistence and closes after success',
    (tester) async {
      final (provider, storage) = await _mount(tester, _studentData());
      await _tap(tester, _key('student-timetable-picker-button'));
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final before = storage.writes;
      storage.hold();
      await tester.tap(_key('timetable-picker-item-guarded-second'));
      await tester.pump();
      expect(storage.writes, before + 1);
      await _dragWhileSaving(tester);
      expect(sheet, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(sheet, findsOneWidget);

      await _completeWrite(tester, storage);
      expect(sheet, findsNothing);
      expect(provider.activeTimetable.id, 'guarded-second');
      expect(storage.writes, before + 1);
      await _tap(tester, _key('student-timetable-picker-button'));
      expect(_key('timetable-picker-close').hitTestable(), findsOneWidget);
      await _tap(tester, _key('timetable-picker-close'));
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'mobile conflict display selection closes its busy details after committing once',
    (tester) async {
      final (provider, storage) = await _mount(tester, _studentData());
      await _tap(tester, _key('timetable-course-hit-guarded-a'));
      final details = find.byType(CourseDetailsSheet);
      expect(details, findsOneWidget);
      final l = AppLocalizations.of(tester.element(details));
      final choose = find.descendant(
        of: details,
        matching: find.byTooltip(l.setAsDisplayed),
      );
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      final before = storage.writes;
      storage.hold();
      await tester.tap(choose);
      await tester.pump();
      expect(storage.writes, before + 1);
      await _dragWhileSaving(tester);
      expect(details, findsOneWidget);

      await _completeWrite(tester, storage);
      expect(details, findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(storage.writes, before + 1);
      final table = provider.activeTimetable;
      final conflictKey = buildConflictKeyForCourses(
        table.id,
        1,
        table.courses,
      );
      expect(
        provider.studentMode.conflictDisplayCourseIds[conflictKey],
        'guarded-b',
      );
      await _tap(tester, _key('timetable-course-hit-guarded-b'));
      expect(details, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'mobile duplicate task stays open while saving and retires exactly once afterward',
    (tester) async {
      final (provider, storage) = await _mount(
        tester,
        mobileLayoutData(locale: 'en'),
      );
      final beforeEvents = provider.generalSchedules
          .expand((calendar) => calendar.events)
          .map((event) => event.id)
          .toSet();
      await _tap(
        tester,
        _key('general-timed-occurrence-mobile-day-21-2026-09-21T08:10:00.000'),
      );
      final details = find.byType(GeneralEventDetailsSheet);
      expect(details, findsOneWidget);
      final before = storage.writes;
      storage.hold();
      await tester.tap(_key('general-event-duplicate-action'));
      await tester.pump();
      expect(storage.writes, before + 1);
      await _dragWhileSaving(tester);
      expect(details, findsOneWidget);

      await _completeWrite(tester, storage);
      expect(details, findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      final afterEvents = provider.generalSchedules
          .expand((calendar) => calendar.events)
          .map((event) => event.id)
          .toSet();
      expect(afterEvents.difference(beforeEvents), hasLength(1));
      expect(storage.writes, before + 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
