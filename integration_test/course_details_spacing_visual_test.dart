import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';

import '../test/support/workspace_harness.dart';

const _captureKey = ValueKey('course-details-spacing-visual-capture');
const _courseId = 'spacing-visual-course';
Finder _key(String value) => find.byKey(ValueKey(value));

/// Uses the actual course-card entry point and native Flutter fonts with only
/// in-memory data. SKED_VISUAL_GROUP=zh/en/rtl can split native runner processes;
/// the default "all" runs every scenario in the student workspace.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const group = String.fromEnvironment(
    'SKED_VISUAL_GROUP',
    defaultValue: 'all',
  );
  if (!const ['all', 'zh', 'en', 'rtl'].contains(group)) {
    throw ArgumentError.value(group, 'SKED_VISUAL_GROUP');
  }
  const scenarios = [
    _Scenario(group: 'zh', name: 'zh', locale: 'zh'),
    _Scenario(group: 'zh', name: 'zh-long', locale: 'zh', longContent: true),
    _Scenario(group: 'en', name: 'en', locale: 'en'),
    _Scenario(
      group: 'rtl',
      name: 'en-dark-rtl-2.0x',
      locale: 'en',
      textScale: 2,
      brightness: Brightness.dark,
      direction: TextDirection.rtl,
    ),
  ];
  for (final scene in scenarios) {
    if (group != 'all' && group != scene.group) continue;
    testWidgets('course details Windows spacing: ${scene.name}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 1000);
      addTearDown(tester.view.reset);
      final provider = await workspaceProvider(
        locale: scene.locale,
        storage: WorkspaceMemoryStorage(_fixtureData(scene)),
      );
      await provider.setSelectedWeek(3);
      await provider.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.overlay,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: WorkspaceHarness(
            provider: provider,
            locale: Locale(scene.locale),
            textScale: scene.textScale,
            brightness: scene.brightness,
            textDirection: scene.direction,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = _key('timetable-course-hit-$_courseId');
      expect(card, findsOneWidget);
      await Scrollable.ensureVisible(tester.element(card));
      await tester.pumpAndSettle();
      expect(card.hitTestable(), findsOneWidget);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final details = find.byType(CourseDetailsSheet);
      expect(details, findsOneWidget);
      final detailsElement = tester.element(details);
      final course = provider.activeTimetable.courses.single;
      final strings = AppLocalizations.of(detailsElement);
      final edit = find.descendant(
        of: details,
        matching: find.byTooltip(strings.editCourseTooltip),
      );
      expect(
        find.descendant(
          of: _key('workspace-view-header'),
          matching: find.text(course.name),
        ),
        findsOneWidget,
      );
      expect(edit.hitTestable(), findsOneWidget);
      await _capture(tester, '${scene.name}-floating');

      if (scene.name == 'zh') {
        // Enter from the real header action, then return without modifying the
        // course. The view task and its original anchor must survive the handoff.
        final originalBounds = tester.getRect(_key('workspace-detail-surface'));
        await tester.tap(edit);
        await tester.pumpAndSettle();
        final editor = find.byType(CourseEditorSheet);
        expect(editor, findsOneWidget);
        expect(
          tester.widget<CourseEditorSheet>(editor).initialCourse?.id,
          _courseId,
        );
        await tester.tap(_key('workspace-editor-close'));
        await tester.pumpAndSettle();
        expect(editor, findsNothing);
        expect(tester.element(details), same(detailsElement));
        expect(
          tester.getRect(_key('workspace-detail-surface')),
          originalBounds,
        );
        expect(edit.hitTestable(), findsOneWidget);
        await _capture(tester, '${scene.name}-editor-return');

        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.sideBySide,
        );
        await tester.pumpAndSettle();
        expect(tester.element(details), same(detailsElement));
        await _capture(tester, '${scene.name}-docked');
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.overlay,
        );
        await tester.pumpAndSettle();
      }

      if (scene.group == 'zh') {
        final surface = _key('workspace-detail-surface');
        final delta = tester.getSize(surface).width - 320;
        await tester.drag(_key('workspace-detail-resize'), Offset(delta, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(surface).width, closeTo(320, .1));
        expect(tester.element(details), same(detailsElement));
        expect(edit.hitTestable(), findsOneWidget);
        await _capture(tester, '${scene.name}-width-320');

        if (!scene.longContent) {
          tester.view.physicalSize = const Size(720, 420);
          await tester.pumpAndSettle();
          expect(tester.element(details), same(detailsElement));
          expect(edit.hitTestable(), findsOneWidget);
          await _capture(tester, '${scene.name}-short');
          final scrollable = find.descendant(
            of: _key('workspace-view-body'),
            matching: find.byType(Scrollable),
          );
          final position = tester.state<ScrollableState>(scrollable).position;
          expect(position.maxScrollExtent, greaterThan(0));
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(edit.hitTestable(), findsOneWidget);
          expect(
            find.descendant(of: details, matching: find.text(course.remarks)),
            findsOneWidget,
          );
          await _capture(tester, '${scene.name}-short-scrolled');
        }
      }
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

class _Scenario {
  const _Scenario({
    required this.group,
    required this.name,
    required this.locale,
    this.longContent = false,
    this.textScale = 1,
    this.brightness = Brightness.light,
    this.direction = TextDirection.ltr,
  });
  final String group, name, locale;
  final bool longContent;
  final double textScale;
  final Brightness brightness;
  final TextDirection direction;
}

AppData _fixtureData(_Scenario scene) {
  final times = [...buildDefaultPeriodTimes()];
  times[0] = times[0].copyWith(startMinutes: 480, endMinutes: 525);
  times[1] = times[1].copyWith(startMinutes: 535, endMinutes: 575);
  final initial = buildInitialAppData(times, localeCode: scene.locale);
  final zh = scene.locale == 'zh';
  final remarks = zh
      ? '考查 理论:32,实验:8 周学时:4 总学时:40 必修专业基础 '
            '教学班:(2026-2027-1)-0300058-01 教学班组成:25软件二;25软件一'
      : 'Assessment: coursework. Theory: 32 hours; lab: 8 hours; '
            '4 hours per week, 40 hours total. Required major foundation. '
            'Teaching group: (2026-2027-1)-0300058-01; '
            'Software Engineering classes 1 and 2.';
  return initial.copyWith(
    activeMode: AppMode.student,
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: 'spacing-visual-timetable',
      timetables: [
        TimetableData(
          id: 'spacing-visual-timetable',
          config: TimetableConfig(
            name: zh ? '2026—2027 秋季学期' : 'Autumn semester 2026–2027',
            startDate: DateTime(2026, 9, 21),
            totalWeeks: 18,
            periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
          ),
          courses: [
            CourseItem(
              id: _courseId,
              name: scene.longContent
                  ? '计算方法与科学计算实验（数值分析进阶专题）'
                  : zh
                  ? '计算方法'
                  : 'Numerical methods',
              teacher: zh ? '肖莎莎' : 'Shasha Xiao',
              location: scene.longContent
                  ? '辽河路校区 玉衡B308(公共机房)，南侧连廊三楼计算机实验中心'
                  : zh
                  ? '辽河路校区 玉衡B308(公共机房)'
                  : 'Liaohe Campus · Yuheng B308 (Computer lab)',
              dayOfWeek: 1,
              semesterWeeks: List<int>.generate(10, (index) => index + 3),
              periods: const [1, 2],
              startMinutes: 480,
              endMinutes: 575,
              timeRange: '08:00 - 09:35',
              credit: 2.5,
              remarks: scene.longContent
                  ? '$remarks\n实验安排：每次课携带教材和实验报告，完成数值计算练习。'
                        '\n补充说明：分组提交课程项目，参考资料在课程平台持续更新。'
                  : remarks,
              customFields: const {},
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  final surface = tester.getRect(_key('workspace-detail-surface'));
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  expect(surface.left, greaterThanOrEqualTo(0), reason: name);
  expect(surface.top, greaterThanOrEqualTo(0), reason: name);
  expect(surface.right, lessThanOrEqualTo(size.width), reason: name);
  expect(surface.bottom, lessThanOrEqualTo(size.height), reason: name);
  expect(
    _key('workspace-inspector-close').hitTestable(),
    findsOneWidget,
    reason: name,
  );
  final output = Directory(
    const String.fromEnvironment(
      'SKED_VISUAL_OUTPUT',
      defaultValue: '.scratch/course-details-spacing-visual',
    ),
  );
  await output.create(recursive: true);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('${output.path}/course-details-$name.png')
        .writeAsBytes(data.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}
