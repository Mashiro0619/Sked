import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../test/support/workspace_harness.dart';

// Native Flutter renderer + production widgets, with exclusively in-memory data.
// Capture only the Windows desktop surface; do not replace phone screenshots.
Finder _key(String value) => find.byKey(ValueKey(value));
final _anchor = DateTime(2026, 9, 28);

AppData _sample(String locale, AppMode mode, String scene) {
  final zh = locale == 'zh';
  final sample = DeveloperSampleDataService.append(
    current: buildInitialAppData(buildDefaultPeriodTimes(), localeCode: locale),
    language: zh
        ? DeveloperSampleLanguage.simplifiedChinese
        : DeveloperSampleLanguage.english,
    now: _anchor,
  ).data;
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 9, 28 + day, hour, minute);
  final events = <(int, String, String, int, int, int, int, String, String)>[
    (0, '项目讨论', 'Project discussion', 0, 9, 0, 90, '研讨室 1', 'Seminar room 1'),
    (0, '阅读与笔记', 'Reading & notes', 1, 10, 0, 90, '图书馆', 'Library'),
    (0, '学习小组', 'Study group', 2, 14, 0, 90, '研讨室 2', 'Seminar room 2'),
    (0, '课程答疑', 'Office hours', 3, 9, 0, 60, 'A203', 'A203'),
    (0, '展示彩排', 'Presentation rehearsal', 4, 10, 30, 90, '报告厅', 'Auditorium'),
    (1, '健身训练', 'Workout', 0, 16, 0, 60, '体育馆', 'Sports center'),
    (1, '午间散步', 'Lunch walk', 1, 13, 0, 45, '校园步道', 'Campus trail'),
    (1, '牙医预约', 'Dentist appointment', 3, 13, 30, 60, '社区诊所', 'Local clinic'),
    (1, '周末采购', 'Weekend groceries', 5, 10, 0, 60, '市集', 'Market'),
    (2, '社团例会', 'Club meeting', 3, 15, 0, 90, '活动中心', 'Activity center'),
    (2, '创意工作坊', 'Creative workshop', 5, 14, 0, 120, 'D105', 'D105'),
    (2, '下周计划', 'Plan next week', 6, 16, 0, 60, '', ''),
  ];
  final calendars = [
    for (var index = 0; index < 3; index++)
      GeneralSchedule(
        id: 'docs-calendar-$index',
        name: (zh
            ? ['学习', '生活', '活动']
            : ['Study', 'Personal', 'Activities'])[index],
        colorValue: [0xff5c6bc0, 0xff26a69a, 0xffef9a43][index],
        sortOrder: index,
        events: [
          for (var i = 0; i < events.length; i++)
            if (events[i].$1 == index)
              GeneralEvent(
                id: 'docs-event-$i',
                calendarId: 'docs-calendar-$index',
                title: zh ? events[i].$2 : events[i].$3,
                startDateTimeIso: at(
                  events[i].$4,
                  events[i].$5,
                  events[i].$6,
                ).toIso8601String(),
                endDateTimeIso: at(
                  events[i].$4,
                  events[i].$5,
                  events[i].$6,
                ).add(Duration(minutes: events[i].$7)).toIso8601String(),
                location: zh ? events[i].$8 : events[i].$9,
                notes: zh
                    ? '提前准备资料，记录讨论要点。'
                    : 'Prepare materials and note the key discussion points.',
                recurrenceRule: const GeneralEventRecurrenceRule(
                  type: GeneralEventRecurrence.weekly,
                  unit: GeneralEventRecurrenceUnit.week,
                  count: 8,
                ),
                reminders: const [GeneralEventReminder(minutesBefore: 30)],
                createdAtIso: _anchor.toIso8601String(),
                updatedAtIso: _anchor.toIso8601String(),
              ),
          if (index == 0)
            GeneralEvent(
              id: 'docs-deadline',
              calendarId: 'docs-calendar-0',
              title: zh ? '提交课程项目' : 'Course project due',
              startDateTimeIso: at(2, 0).toIso8601String(),
              endDateTimeIso: at(3, 0).toIso8601String(),
              isAllDay: true,
              recurrenceRule: const GeneralEventRecurrenceRule(
                type: GeneralEventRecurrence.weekly,
                unit: GeneralEventRecurrenceUnit.week,
                count: 8,
              ),
              createdAtIso: _anchor.toIso8601String(),
              updatedAtIso: _anchor.toIso8601String(),
            ),
        ],
      ),
  ];
  return sample.copyWith(
    activeMode: mode,
    hideHomeWorkspaceNavigation: false,
    studentMode: sample.studentMode.copyWith(
      fitWeekColumnsToWidth: true,
      timetables: [
        for (final table in sample.studentMode.timetables)
          table.copyWith(
            config: table.config.copyWith(
              name: zh ? '2026 秋季学期' : 'Autumn semester 2026',
            ),
          ),
      ],
    ),
    generalMode: sample.generalMode.copyWith(
      schedules: calendars,
      activeScheduleId: 'docs-calendar-0',
      selectedDateIso: scene.contains('month') ? '2026-10-13' : '2026-09-28',
      defaultView: scene.contains('month') ? generalViewMonth : generalViewWeek,
      dayStartHour: 8,
      dayEndHour: 21,
      timeGridHourHeight: 64,
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture bilingual desktop documentation from current UI', (
    t,
  ) async {
    if (!Platform.isWindows) {
      throw UnsupportedError('Run this documentation capture on Windows.');
    }
    const outputPath = String.fromEnvironment('SKED_VISUAL_OUTPUT');
    if (outputPath.isEmpty) {
      throw StateError(
        'Set SKED_VISUAL_OUTPUT to an ignored capture directory.',
      );
    }
    final out = Directory(outputPath);
    await out.create(recursive: true);
    await DesktopWindowBridge.instance.initialize();
    expect(DesktopWindowBridge.instance.available, isTrue);
    const version = String.fromEnvironment('SKED_DOC_VERSION');
    const revision = String.fromEnvironment('SKED_DOC_REVISION');
    if (version.isEmpty || revision.isEmpty) {
      throw StateError(
        'Set SKED_DOC_VERSION and SKED_DOC_REVISION for provenance.',
      );
    }
    final captures = <Map<String, Object?>>[];
    const scenes = [
      'student-week-desktop',
      'general-week-desktop',
      'general-month-desktop',
      'course-editor-desktop',
      'settings-desktop',
      'course-details-desktop',
      'event-details-desktop',
      'event-editor-desktop',
    ];
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final locale in ['zh', 'en']) {
      await Directory('${out.path}/$locale').create(recursive: true);
      for (final scene in scenes) {
        const size = Size(1440, 900);
        const brightness = Brightness.light;
        final mode = scene.startsWith('general') || scene.startsWith('event')
            ? AppMode.general
            : AppMode.student;
        t.view.physicalSize = size;
        t.view.viewInsets = const FakeViewPadding();
        t.view.padding = const FakeViewPadding();
        t.view.viewPadding = const FakeViewPadding();
        final p = await workspaceProvider(
          locale: locale,
          storage: WorkspaceMemoryStorage(_sample(locale, mode, scene)),
        );
        try {
          await p.setSelectedWeek(1);
          final boundary = GlobalKey();
          final versions = version.split('+');
          Widget settings() => SettingsPage(
            packageInfoLoader: () async => PackageInfo(
              appName: 'Sked',
              packageName: 'com.mashiro.sked',
              version: versions.first,
              buildNumber: versions.last,
            ),
          );
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: WorkspaceHarness(
                provider: p,
                locale: Locale(locale),
                brightness: brightness,
                home: scene == 'settings-desktop'
                    ? settings()
                    : Builder(
                        builder: (context) => Consumer<TimetableProvider>(
                          builder: (_, provider, _) => AdaptiveSkedShell(
                            provider: provider,
                            activeMode: provider.activeMode,
                            onOpenSettings: () => Navigator.of(context)
                                .push<void>(
                                  MaterialPageRoute(builder: (_) => settings()),
                                ),
                          ),
                        ),
                      ),
              ),
            ),
          );
          await t.pumpAndSettle();
          Future<void> tap(Finder target) async {
            await t.ensureVisible(target);
            await t.pumpAndSettle();
            expect(
              target.hitTestable(),
              findsOneWidget,
              reason: '$locale/$scene',
            );
            await t.tap(target);
            await t.pumpAndSettle();
          }

          if (scene.startsWith('course-')) {
            await tap(
              _key(
                'timetable-course-hit-${p.activeTimetable.courses.first.id}',
              ),
            );
            final details = find.byType(CourseDetailsSheet);
            expect(details, findsOneWidget);
            if (scene == 'course-editor-desktop') {
              final l = AppLocalizations.of(t.element(details));
              await tap(
                find.descendant(
                  of: details,
                  matching: find.byTooltip(l.editCourseTooltip),
                ),
              );
              expect(find.byType(CourseEditorSheet), findsOneWidget);
            }
          } else if (scene.startsWith('event-')) {
            await tap(
              _key(
                'general-timed-occurrence-docs-event-0-2026-09-28T09:00:00.000',
              ),
            );
            final details = find.byType(GeneralEventDetailsSheet);
            expect(details, findsOneWidget);
            if (scene == 'event-editor-desktop') {
              await tap(_key('general-event-edit-action'));
              expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
            }
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: '$locale/$scene');
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage();
          try {
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            final file = '$locale/$scene.png';
            await File('${out.path}/$file').writeAsBytes(
              data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
            );
            captures.add({
              'file': file,
              'scene': scene,
              'locale': locale,
              'widthDp': size.width,
              'heightDp': size.height,
              'widthPx': image.width,
              'heightPx': image.height,
              'platformStyle': 'windows',
              'brightness': brightness.name,
            });
          } finally {
            image.dispose();
          }
        } finally {
          await t.pumpWidget(const SizedBox.shrink());
          await t.pumpAndSettle();
          p.dispose();
        }
      }
    }
    expect(captures.length, 16);
    await File('${out.path}/manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'appVersion': version,
        'sourceRevision': revision,
        'capturedAt': DateTime.now().toUtc().toIso8601String(),
        'rendererHost': 'windows',
        'captureMethod': 'Native Windows Flutter RepaintBoundary, production desktop widgets, 1x pixel/text scale; no composited device frame.',
        'data': 'Isolated in-memory bilingual documentation fixtures; anchor 2026-09-28; October for month scene; no user storage or notification delivery.',
        'captures': captures,
      }),
    );
  });
}
