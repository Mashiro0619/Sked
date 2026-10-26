import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import '../../test/support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _page => _key('student-week-page-1');
Finder get _agenda =>
    find.descendant(of: _page, matching: _key('student-day-agenda-scroll'));
Finder _day(int weekday) => find.descendant(
  of: find.descendant(of: _page, matching: _key('student-day-strip')),
  matching: _key('student-day-$weekday'),
);
Finder _agendaCourse(String id) =>
    find.descendant(of: _agenda, matching: _key('student-day-course-$id'));

const _periodTimes = [
  CoursePeriodTime(index: 1, startMinutes: 490, endMinutes: 535),
  CoursePeriodTime(index: 2, startMinutes: 545, endMinutes: 590),
  CoursePeriodTime(index: 3, startMinutes: 615, endMinutes: 660),
  CoursePeriodTime(index: 4, startMinutes: 670, endMinutes: 715),
];

CourseItem _course(
  String id,
  String name, {
  int start = 490,
  int end = 590,
  List<int> periods = const [],
  String teacher = '陈老师',
  String location = '教学楼 A-302',
}) => CourseItem(
  id: id,
  name: name,
  teacher: teacher,
  location: location,
  dayOfWeek: DateTime.monday,
  semesterWeeks: const [1, 2, 3, 4, 5, 6, 7, 8],
  periods: periods,
  startMinutes: start,
  endMinutes: end,
  timeRange: start == 0 && end == 0 ? '' : buildTimeRange(start, end),
  credit: 2,
  remarks: '',
  customFields: const {},
);

AppData _fixture() {
  final base = buildInitialAppData(_periodTimes, localeCode: 'zh');
  final courses = [
    _course('period-course', '高等数学', start: 0, end: 0, periods: const [1, 2]),
    _course('full-a', '大学英语', start: 615, end: 715),
    _course('full-b', '学术英语讨论课', start: 615, end: 715),
    _course(
      'partial-a',
      '数字媒体艺术与跨学科创新设计实践——项目研究和团队协作',
      start: 810,
      end: 900,
      location: '设计与创新中心东区三层综合研讨室 A-301（靠近电梯）',
      teacher: '李老师、王老师',
    ),
    _course('partial-b', '计算机图形学', start: 870, end: 945, location: ''),
    _course(
      'no-metadata',
      '自主学习与阅读',
      start: 970,
      end: 1020,
      location: '',
      teacher: '',
    ),
  ];
  final timetable = TimetableData(
    id: 'visual-student-day',
    config: TimetableConfig(
      name: '秋季学期',
      startDate: startOfWeekMonday(DateTime.now()),
      totalWeeks: 18,
      periodTimeSetId: base.studentMode.periodTimeSets.first.id,
    ),
    courses: courses,
  );
  return base.copyWith(
    activeMode: AppMode.student,
    homeWorkspaceNavigationCollapsed: true,
    studentMode: base.studentMode.copyWith(
      activeTimetableId: timetable.id,
      timetables: [timetable],
      themeColorMode: themeColorModeColorful,
      courseNameColorValues: {
        for (final (index, course) in courses.indexed)
          normalizeCourseColorName(course.name): const [
            0xff5b6ba9,
            0xff7c5b9f,
            0xff96659a,
            0xff397d76,
            0xffaf743b,
            0xff637a44,
          ][index],
      },
    ),
  );
}

/// Isolated real-font Windows rendering; Android viewports are simulations.
void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('student day agenda across desktop and simulated phone layouts', (
    tester,
  ) async {
    await DesktopWindowBridge.instance.initialize();
    final output = Directory(
      const String.fromEnvironment(
        'SKED_VISUAL_OUTPUT',
        defaultValue: '.scratch/capture-scenes/student-day-agenda',
      ),
    );
    await output.create(recursive: true);
    final manifest = <Map<String, Object?>>[];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cases = <(String, Size, double, Brightness, TargetPlatform)>[
      for (final brightness in Brightness.values)
        (
          'windows-1362-1x-${brightness.name}',
          const Size(1362, 768),
          1,
          brightness,
          TargetPlatform.windows,
        ),
      (
        'windows-1920-1x-light',
        const Size(1920, 1080),
        1,
        Brightness.light,
        TargetPlatform.windows,
      ),
      (
        'windows-1362-2x-dark',
        const Size(1362, 768),
        2,
        Brightness.dark,
        TargetPlatform.windows,
      ),
      for (final width in [320.0, 430.0])
        for (final scale in [1.0, 2.0])
          for (final brightness in Brightness.values)
            (
              'phone-${width.toInt()}-${scale.toInt()}x-${brightness.name}',
              Size(width, 932),
              scale,
              brightness,
              TargetPlatform.android,
            ),
    ];
    try {
      for (final (name, size, scale, brightness, platform) in cases) {
        debugDefaultTargetPlatformOverride = platform;
        DesktopWindowBridge.instance.available =
            platform == TargetPlatform.windows;
        tester.view.physicalSize = size;
        final insets = platform == TargetPlatform.android
            ? const FakeViewPadding(top: 24, bottom: 24)
            : const FakeViewPadding();
        tester.view.padding = insets;
        tester.view.viewPadding = insets;
        final provider = await workspaceProvider(
          locale: 'zh',
          storage: WorkspaceMemoryStorage(_fixture()),
        );
        final boundary = GlobalKey();
        try {
          await provider.studentCommands.setSelectedWeek(1);
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: provider,
                locale: const Locale('zh'),
                brightness: brightness,
                textScale: scale,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (platform == TargetPlatform.windows) {
            final toggle = _key('student-view-toggle');
            if (toggle.evaluate().isNotEmpty) {
              final dayLabel = AppLocalizations.of(tester.element(toggle))
                  .viewDay;
              await tester.tap(toggle);
              await tester.pumpAndSettle();
              await tester.tap(
                find.ancestor(
                  of: find.text(dayLabel),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is PopupMenuItem || widget is MenuItemButton,
                  ),
                ),
              );
            } else {
              await tester.tap(_key('student-desktop-toolbar-more'));
              await tester.pumpAndSettle();
              await tester.tap(_key('student-view-choice-day'));
            }
          } else {
            await tester.tap(_key('student-view-toggle-button'));
          }
          await tester.pumpAndSettle();
          Future<void> selectDay(int weekday) async {
            final stripPosition = tester
                .state<ScrollableState>(
                  find.descendant(
                    of: find.descendant(
                      of: _page,
                      matching: _key('student-day-strip'),
                    ),
                    matching: find.byType(Scrollable),
                  ),
                )
                .position;
            stripPosition.jumpTo(
              stripPosition.maxScrollExtent * (weekday - 1) / 6,
            );
            await tester.pumpAndSettle();
            final day = _day(weekday);
            await stripPosition.ensureVisible(
              tester.renderObject(day),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(day);
            await tester.pumpAndSettle();
          }

          await selectDay(1);
          expect(_agenda, findsOneWidget);

          Future<void> capture(String scene) async {
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: '$name $scene');
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 1);
            try {
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              final filename = '$name-$scene.png';
              await File('${output.path}/$filename')
                  .writeAsBytes(bytes.buffer.asUint8List());
              manifest.add({
                'file': filename,
                'widthDp': size.width,
                'heightDp': size.height,
                'textScale': scale,
                'brightness': brightness.name,
                'platformStyle': platform.name,
                'scene': scene,
                'evidence': 'Isolated in-memory data; Windows Flutter renderer and actual fonts. Android sizes and safe insets simulated, not Android device acceptance.',
              });
            } finally {
              image.dispose();
            }
          }

          Future<void> showCourse(String id) async {
            final position = tester
                .state<ScrollableState>(
                  find.descendant(
                    of: _agenda,
                    matching: find.byType(Scrollable),
                  ),
                )
                .position;
            final course = _agendaCourse(id);
            for (
              var attempt = 0;
              attempt < 30 && course.evaluate().isEmpty;
              attempt++
            ) {
              position.jumpTo(
                (position.pixels + 180)
                    .clamp(0, position.maxScrollExtent)
                    .toDouble(),
              );
              await tester.pumpAndSettle();
            }
            expect(course, findsOneWidget);
            await position.ensureVisible(tester.renderObject(course));
            await tester.pumpAndSettle();
          }

          expect(_agendaCourse('period-course'), findsOneWidget);
          await capture('overview');
          await showCourse('full-a');
          expect(_agendaCourse('full-b'), findsNothing);
          await capture('full-conflict');
          await showCourse('partial-a');
          await capture('long-course');
          await showCourse('no-metadata');
          await capture('partial-and-missing-metadata');
          await selectDay(2);
          expect(
            find.descendant(of: _agenda, matching: find.text('当天暂无课程')),
            findsOneWidget,
          );
          await capture('empty');
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          provider.dispose();
        }
      }
      expect(manifest, hasLength(cases.length * 5));
    } finally {
      debugDefaultTargetPlatformOverride = null;
      DesktopWindowBridge.instance.available = true;
      await File('${output.path}/manifest.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    }
  });
}
