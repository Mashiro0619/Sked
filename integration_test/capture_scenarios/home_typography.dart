import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/timetable_grid.dart';

import '../../test/support/workspace_harness.dart';
import '../support/visual_capture_session.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const group = String.fromEnvironment('SKED_VISUAL_GROUP');
  if (!const ['status', 'range'].contains(group)) {
    throw ArgumentError.value(group, 'SKED_VISUAL_GROUP', 'status or range');
  }
  testWidgets('native home typography: $group', (tester) async {
    await DesktopWindowBridge.instance.initialize();
    DesktopWindowBridge.instance.available = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(group == 'status' ? 320 : 600, 900);
    addTearDown(() {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = false;
    });
    try {
      final range = GeneralDateRange(
        DateTime(2026, 12, 29),
        DateTime(2027, 1, 4),
      );
      final initial = buildInitialAppData(buildDefaultPeriodTimes());
      final provider = await workspaceProvider(
        storage: WorkspaceMemoryStorage(
          initial.copyWith(
            activeMode: group == 'status' ? AppMode.student : AppMode.general,
            homeWorkspaceNavigationCollapsed: true,
            generalMode: GeneralScheduleData(
              activeScheduleId: 'typography-calendar',
              selectedDateIso: '2026-12-29',
              defaultView: generalViewWeek,
              customDateRange: range,
              dateLabelFormat: generalDateLabelFormatSlash,
              toolbarNavigationOrder: generalToolbarNavigationDefaultOrder,
              hiddenToolbarNavigationIds: const [],
              schedules: const [
                GeneralSchedule(
                  id: 'typography-calendar',
                  name: 'Learning, work and everyday life with a long category name',
                  events: [],
                ),
              ],
            ),
          ),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      });
      final boundary = GlobalKey();
      final selections = <String>[];
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: WorkspaceHarness(
            provider: provider,
            locale: const Locale('en'),
            textScale: 2,
            brightness: group == 'status' ? Brightness.dark : Brightness.light,
            home: group == 'status'
                ? Scaffold(body: _statusGrid(selections.add))
                : const GeneralScheduleHomeScreen(
                    interactive: true,
                    showSettingsAction: true,
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final captures = VisualCaptureSession(label: 'home-typography-$group');
      final Finder text;
      final String name;
      if (group == 'status') {
        name = 'phone-320-2x-en-week-status';
        text = find.descendant(
          of: _key('timetable-course-week-status-inactive'),
          matching: find.text('Off week'),
        );
        expect(text, findsOneWidget);
        final card = _key('timetable-course-visual-inactive');
        expect(tester.getRect(card).contains(tester.getCenter(text)), isTrue);
        final textRect = tester.getRect(text);
        expect(
          textRect.intersect(tester.getRect(find.byKey(boundary))),
          textRect,
        );
      } else {
        name = 'tablet-600-2x-en-cross-year-range';
        expect(_key('general-compact-toolbar-scroll'), findsNothing);
        expect(provider.generalView.customDateRange, range);
        text = find.descendant(
          of: _key('general-date-title-button'),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'general-date-label-',
                ),
          ),
        );
        expect(text, findsOneWidget);
        final value = tester.widget<Text>(text).data!;
        expect(value, contains('2026/12/29'));
        expect(value, contains('2027/1/4'));
      }
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: text, matching: find.byType(RichText)),
      );
      await captures.capture(
        tester,
        boundary: find.byKey(boundary),
        name: name,
        pixelRatio: group == 'status' ? 2 : 1,
        metadata: {
          'locale': 'en',
          'textScale': 2,
          'brightness': group == 'status' ? 'dark' : 'light',
          'fixture': group == 'status'
              ? '2026-12-28 week 2; seven columns; course occurs in week 1'
              : '2026-12-29 through 2027-01-04; noncompact Android toolbar',
          // Baselines may intentionally contain clipped text. Record actual
          // layout rather than treating a successful capture as readability proof.
          'observations': _observeParagraph(paragraph),
        },
      );
      if (group == 'status') {
        final target = _key('timetable-course-hit-inactive');
        expect(target.hitTestable(), findsOneWidget);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(selections, ['inactive']);
      } else {
        final button = _key('general-date-title-button');
        expect(button.hitTestable(), findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(_key('sked-date-picker-content'), findsOneWidget);
        await tester.tap(_key('sked-date-picker-close'));
        await tester.pumpAndSettle();
        expect(provider.generalView.customDateRange, range);
      }
      expect(tester.takeException(), isNull);
      await captures.writeManifest(expectedCount: 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = false;
    }
  });
}

Widget _statusGrid(ValueChanged<String> onTap) => TimetableGrid(
  timetable: TimetableData(
    id: 'typography-timetable',
    config: TimetableConfig(
      name: 'Timetable',
      startDate: DateTime(2026, 12, 21),
      totalWeeks: 18,
      periodTimeSetId: defaultPeriodTimeSetId,
    ),
    courses: [
      CourseItem(
        id: 'inactive',
        name: 'Physics',
        location: 'Lab',
        teacher: 'Dr. Chen',
        dayOfWeek: 1,
        semesterWeeks: const [1],
        periods: const [1],
        startMinutes: 480,
        endMinutes: 660,
        timeRange: buildTimeRange(480, 660),
        credit: 0,
        remarks: '',
        customFields: const {},
      ),
    ],
  ),
  periodTimes: const [
    CoursePeriodTime(index: 1, startMinutes: 480, endMinutes: 720),
  ],
  weekDateStart: DateTime(2026, 12, 28),
  selectedWeek: 2,
  realCurrentWeek: 2,
  localeCode: 'en',
  preserveGaps: true,
  showPastEndedCourses: true,
  showFutureCourses: true,
  showGridLines: true,
  showDayHeader: true,
  fitVisibleDaysToWidth: true,
  onCourseTap: (info) => onTap(info.course.id),
  onEmptySlotTap: (_) {},
  themeColorMode: themeColorModeSingle,
  courseNameColorValues: const {},
  colorfulCourseTextColorMode: colorfulCourseTextColorModeAuto,
  liveCourseOutlineEnabled: false,
  liveCourseOutlineMode: liveCourseOutlineModeCurrentOrNext,
  liveCourseOutlineColorValue: 0xff6750a4,
  liveCourseOutlineWidth: 2,
);

Map<String, Object?> _observeParagraph(RenderParagraph paragraph) {
  final value = paragraph.text.toPlainText();
  return {
    'text': value,
    'width': paragraph.size.width,
    'height': paragraph.size.height,
    'maxLines': paragraph.maxLines,
    'didExceedMaxLines': paragraph.didExceedMaxLines,
    'missingGlyphIndices': [
      for (var index = 0; index < value.length; index++)
        if (value[index].trim().isNotEmpty &&
            paragraph
                .getBoxesForSelection(
                  TextSelection(baseOffset: index, extentOffset: index + 1),
                )
                .isEmpty)
          index,
    ],
    'latinWords': [
      for (final word in RegExp(r'[A-Za-z]+').allMatches(value))
        _observeWord(paragraph, word),
    ],
  };
}

Map<String, Object?> _observeWord(RenderParagraph paragraph, RegExpMatch word) {
  final painter = TextPainter(
    text: TextSpan(text: word.group(0), style: paragraph.text.style),
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    locale: paragraph.locale,
    textHeightBehavior: paragraph.textHeightBehavior,
  )..layout();
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: word.start, extentOffset: word.end),
  );
  final result = <String, Object?>{
    'word': word.group(0),
    'naturalWidth': painter.width,
    'exceedsAvailableWidth': painter.width > paragraph.size.width,
    'paintedLineTops': boxes.map((box) => box.top).toSet().toList()..sort(),
  };
  painter.dispose();
  return result;
}
