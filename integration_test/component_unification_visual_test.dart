import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/school_import_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/school_web_import_result_sheet.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_editor_form.dart';

import '../test/support/mobile_layout_data.dart';
import '../test/support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

typedef _Profile = ({
  String name,
  Size size,
  double scale,
  double keyboard,
  Brightness brightness,
  TargetPlatform platform,
  String locale,
  TextDirection direction,
  WorkspacePanelDisplayMode mode,
});

const _profiles = <_Profile>[
  (
    name: 'phone-393-zh',
    size: Size(393, 852),
    scale: 1,
    keyboard: 0,
    brightness: Brightness.light,
    platform: TargetPlatform.android,
    locale: 'zh',
    direction: TextDirection.ltr,
    mode: WorkspacePanelDisplayMode.overlay,
  ),
  (
    name: 'phone-320-2x-ime',
    size: Size(320, 568),
    scale: 2,
    keyboard: 220,
    brightness: Brightness.light,
    platform: TargetPlatform.android,
    locale: 'zh',
    direction: TextDirection.ltr,
    mode: WorkspacePanelDisplayMode.overlay,
  ),
  (
    name: 'phone-landscape',
    size: Size(800, 393),
    scale: 1,
    keyboard: 0,
    brightness: Brightness.light,
    platform: TargetPlatform.android,
    locale: 'zh',
    direction: TextDirection.ltr,
    mode: WorkspacePanelDisplayMode.overlay,
  ),
  (
    name: 'phone-landscape-ime',
    size: Size(568, 320),
    scale: 1,
    keyboard: 214,
    brightness: Brightness.light,
    platform: TargetPlatform.android,
    locale: 'zh',
    direction: TextDirection.ltr,
    mode: WorkspacePanelDisplayMode.overlay,
  ),
  (
    name: 'phone-dark-rtl',
    size: Size(393, 852),
    scale: 1.3,
    keyboard: 0,
    brightness: Brightness.dark,
    platform: TargetPlatform.android,
    locale: 'en',
    direction: TextDirection.rtl,
    mode: WorkspacePanelDisplayMode.overlay,
  ),
  (
    name: 'tablet-1280-en',
    size: Size(1280, 1000),
    scale: 1,
    keyboard: 0,
    brightness: Brightness.light,
    platform: TargetPlatform.android,
    locale: 'en',
    direction: TextDirection.ltr,
    mode: WorkspacePanelDisplayMode.overlay,
  ),
  (
    name: 'windows-overlay',
    size: Size(1440, 900),
    scale: 1,
    keyboard: 0,
    brightness: Brightness.light,
    platform: TargetPlatform.windows,
    locale: 'zh',
    direction: TextDirection.ltr,
    mode: WorkspacePanelDisplayMode.overlay,
  ),
  (
    name: 'windows-side-by-side',
    size: Size(2000, 1000),
    scale: 1,
    keyboard: 0,
    brightness: Brightness.dark,
    platform: TargetPlatform.windows,
    locale: 'en',
    direction: TextDirection.ltr,
    mode: WorkspacePanelDisplayMode.sideBySide,
  ),
];

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(finder.hitTestable(), findsOneWidget);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openTimetable(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  final l = AppLocalizations.of(tester.element(find.byType(HomeScreen)));
  final id = provider.activeTimetable.id;
  final row = _key('resource-timetable-$id');
  final edit = _key('resource-timetable-edit-$id');
  if (row.hitTestable().evaluate().isEmpty) {
    final picker = _key('student-timetable-picker-button').hitTestable();
    await _tap(
      tester,
      picker.evaluate().isNotEmpty
          ? picker
          : _key('workspace-resource-collapse'),
    );
  }
  if (row.hitTestable().evaluate().isNotEmpty) {
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    try {
      await mouse.addPointer(location: tester.getCenter(row));
      await tester.pumpAndSettle();
      await _tap(tester, edit);
    } finally {
      await mouse.removePointer();
    }
  } else {
    await _tap(tester, find.byTooltip(l.editTimetable).hitTestable());
  }
  expect(find.byType(TimetableInformationForm), findsOneWidget);
}

Future<void> _openCategoryManager(WidgetTester tester) async {
  final resources = _key('workspace-resource-open').hitTestable();
  final selector = _key('general-calendar-selector').hitTestable();
  if (resources.evaluate().isNotEmpty) {
    await _tap(tester, resources);
  } else if (selector.evaluate().isNotEmpty) {
    await _tap(tester, selector);
  } else {
    final more = _key('general-desktop-toolbar-more').hitTestable();
    await _tap(
      tester,
      more.evaluate().isNotEmpty ? more : _key('general-toolbar-more-button'),
    );
    final entry = _key('general-calendar-selector').hitTestable();
    await _tap(
      tester,
      entry.evaluate().isNotEmpty
          ? entry
          : _key('general-calendar-manager-action'),
    );
  }
}

Future<void> _openSettings(WidgetTester tester) async {
  final resource = _key('workspace-resource-settings').hitTestable();
  final toolbar = _key('student-settings-button').hitTestable();
  if (resource.evaluate().isNotEmpty) {
    await _tap(tester, resource);
  } else if (toolbar.evaluate().isNotEmpty) {
    await _tap(tester, toolbar);
  } else {
    await _tap(tester, _key('student-toolbar-more-button'));
    await _tap(tester, _key('student-more-settings'));
  }
  expect(find.byType(SettingsPage), findsOneWidget);
}

SchoolImportResponse _reviewFixture() => SchoolImportResponse(
  meta: const SchoolImportMeta(
    sourceUrl: 'https://example.edu/timetable',
    pageTitle: '示例学校课表',
    parser: 'visual-fixture',
    warnings: [],
  ),
  timetable: SchoolImportTimetableDraft(
    name: '待导入的示例课表',
    startDate: DateTime(2026, 9, 21),
    totalWeeks: 18,
    periodTimeSet: const ImportedPeriodTimeSetDraft(name: '', periodTimes: []),
    courses: const [
      ImportedCourseDraft(
        name: '高等数学',
        teacher: '张老师',
        location: 'A101',
        dayOfWeek: 1,
        semesterWeeks: [1, 2, 3, 4],
        periods: [1, 2],
        startMinutes: 480,
        endMinutes: 580,
        credit: 3,
        remarks: '',
        customFields: {},
      ),
    ],
  ),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final output = Directory(
    const String.fromEnvironment(
      'SKED_VISUAL_OUTPUT',
      defaultValue: '.scratch/component-unification-visual',
    ),
  );
  const revision = String.fromEnvironment('SKED_VISUAL_REVISION');
  const baseline = bool.fromEnvironment('SKED_VISUAL_BASELINE');
  const onlyProfile = String.fromEnvironment('SKED_VISUAL_PROFILE');
  // Keep native Windows and simulated touch batches in separate processes
  // when needed, while preserving exactly the same per-profile scenarios.
  final selectedProfiles = onlyProfile
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();
  final captures = <Map<String, Object?>>[];

  for (final profile in _profiles) {
    if (selectedProfiles.isNotEmpty &&
        !selectedProfiles.contains(profile.name)) {
      continue;
    }
    testWidgets('shared components: ${profile.name}', (tester) async {
      final bridge = DesktopWindowBridge.instance;
      await bridge.initialize();
      final originalPlatform = debugDefaultTargetPlatformOverride;
      final originalAvailable = bridge.available;
      await output.create(recursive: true);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = profile.platform;
      bridge.available =
          originalAvailable && profile.platform == TargetPlatform.windows;
      tester.view.physicalSize = profile.size;
      final safe = profile.platform == TargetPlatform.android
          ? const FakeViewPadding(top: 24, bottom: 24)
          : const FakeViewPadding();
      tester.view.padding = safe;
      tester.view.viewPadding = safe;
      tester.view.viewInsets = const FakeViewPadding();
      final extraFamilies =
          profile.name == 'phone-393-zh' || profile.name == 'windows-overlay';

      try {
        for (final scene in [
          'timetable-edit',
          'course-new',
          'event-new',
          if (extraFamilies) 'category-manager',
          if (extraFamilies) 'course-details',
          if (extraFamilies) 'event-details',
          if (extraFamilies) 'settings-transfer',
          if (extraFamilies) 'import-review',
        ]) {
          final mode = scene.startsWith('event') || scene.startsWith('category')
              ? AppMode.general
              : AppMode.student;
          final provider = await workspaceProvider(
            locale: profile.locale,
            storage: WorkspaceMemoryStorage(
              mobileLayoutData(locale: profile.locale)
                  .copyWith(activeMode: mode),
            ),
          );
          await provider.updateWorkspacePanelDisplayMode(profile.mode);
          final boundary = GlobalKey();
          tester.view.padding = safe;
          tester.view.viewInsets = const FakeViewPadding();
          try {
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: WorkspaceHarness(
                  provider: provider,
                  locale: Locale(profile.locale),
                  textScale: profile.scale,
                  brightness: profile.brightness,
                  textDirection: profile.direction,
                  home: mode == AppMode.student ? const HomeScreen() : null,
                ),
              ),
            );
            await tester.pumpAndSettle();

            Future<void> capture(String name) async {
              expect(tester.takeException(), isNull, reason: '$profile $name');
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              try {
                final bytes = (await image.toByteData(
                  format: ui.ImageByteFormat.png,
                ))!;
                final file = '${profile.name}-$name.png';
                await File('${output.path}/$file')
                    .writeAsBytes(bytes.buffer.asUint8List());
                captures.add({
                  'file': file,
                  'scene': name,
                  'widthDp': profile.size.width,
                  'heightDp': profile.size.height,
                  'textScale': profile.scale,
                  'keyboardInsetDp': tester.view.viewInsets.bottom,
                  'brightness': profile.brightness.name,
                  'platformStyle': profile.platform.name,
                  'locale': profile.locale,
                  'direction': profile.direction.name,
                  'panelMode': profile.mode.name,
                  'revision': revision,
                  'baseline': baseline,
                  if (name == 'import-review')
                    'entryEvidence':
                        'Local parsed-response fixture in the production '
                        'review sheet. The source page, parser and network '
                        'are not exercised by this capture.',
                  'capturedAtUtc': DateTime.now().toUtc().toIso8601String(),
                  'evidence':
                      'Native Windows Flutter renderer and production widgets. '
                      'Android geometry, text scale, safe area and IME inset '
                      'are simulated; the system keyboard is not captured.',
                });
                await File('${output.path}/manifest.json').writeAsString(
                  const JsonEncoder.withIndent('  ').convert(captures),
                );
              } finally {
                image.dispose();
              }
            }

            Finder? editor;
            if (scene == 'timetable-edit') {
              await _openTimetable(tester, provider);
              editor = find.byType(TimetableInformationForm);
            } else if (scene == 'category-manager') {
              await _openCategoryManager(tester);
            } else if (scene == 'settings-transfer') {
              await _openSettings(tester);
              await capture('settings-overview');
              await _tap(tester, _key('settings-student-transfer'));
              await capture(scene);
              continue;
            } else if (scene == 'import-review') {
              unawaited(
                showAppModalSheet<SchoolImportApplyRequest>(
                  context: tester.element(find.byType(HomeScreen)),
                  workspace: AppMode.student,
                  builder: (_) => SchoolWebImportResultSheet(
                    response: _reviewFixture(),
                    canReplaceCurrent: true,
                    initialPeriodTimeSetId: provider.periodTimeSets.first.id,
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(find.byType(SchoolWebImportResultSheet), findsOneWidget);
              await capture(scene);
              continue;
            } else if (scene.endsWith('-details')) {
              final course = scene == 'course-details';
              final details = find.byType(
                course ? CourseDetailsSheet : GeneralEventDetailsSheet,
              );
              await _tap(
                tester,
                course
                    ? _key(
                        'timetable-course-hit-${provider.activeTimetable.courses.first.id}',
                      )
                    : _key(
                        'general-timed-occurrence-mobile-day-21-2026-09-21T08:10:00.000',
                      ),
              );
              expect(details, findsOneWidget);
              await capture(scene);
              final l = AppLocalizations.of(tester.element(details));
              await _tap(
                tester,
                find.descendant(
                  of: details,
                  matching: course
                      ? find.byTooltip(l.editCourseTooltip)
                      : _key('general-event-edit-action'),
                ),
              );
              editor = find.byType(
                course ? CourseEditorSheet : GeneralEventEditorSheet,
              );
              expect(editor, findsOneWidget);
              final family = course ? 'course' : 'event';
              await capture('$family-edit-from-details');
              await tester.enterText(
                find
                    .descendant(of: editor, matching: find.byType(TextField))
                    .first,
                '从详情进入后保留的编辑草稿',
              );
              await tester.pumpAndSettle();
              await _tap(
                tester,
                find.descendant(of: editor, matching: find.text(l.cancel)),
              );
              expect(find.text(l.unsavedChangesMessage), findsOneWidget);
              await capture('$family-discard-draft');
              continue;
            } else {
              final action = _key(
                mode == AppMode.student
                    ? 'student-add-course'
                    : 'general-add-event',
              ).hitTestable();
              final l = AppLocalizations.of(
                tester.element(find.byType(Scaffold).first),
              );
              final inlineAction = find
                  .byTooltip(mode == AppMode.student ? l.addCourse : l.addEvent)
                  .hitTestable();
              // Wide touch layouts have an inline action without the desktop
              // key or phone FAB. Keep its real source visible in the evidence.
              if (action.evaluate().isEmpty &&
                  find.byType(FloatingActionButton).evaluate().isEmpty) {
                await capture('$scene-source-entry');
              }
              if (mode == AppMode.general &&
                  action.evaluate().isEmpty &&
                  inlineAction.evaluate().isEmpty &&
                  find.byType(FloatingActionButton).evaluate().isEmpty) {
                final slot = _key(
                  'general-timeline-empty-slot-2026-09-23T00:00:00.000',
                );
                expect(slot, findsOneWidget);
                final bounds = tester.getRect(slot);
                await tester.longPressAt(
                  Offset(bounds.center.dx, bounds.top + 40),
                );
                await tester.pumpAndSettle();
              } else {
                await _tap(
                  tester,
                  action.evaluate().isNotEmpty
                      ? action
                      : inlineAction.evaluate().isNotEmpty
                      ? inlineAction
                      : find.byType(FloatingActionButton).first,
                );
              }
              editor = find.byType(
                mode == AppMode.student
                    ? CourseEditorSheet
                    : GeneralEventEditorSheet,
              );
              expect(editor, findsOneWidget);
            }
            if (profile.keyboard != 0 && editor != null) {
              final input = find
                  .descendant(of: editor, matching: find.byType(TextField))
                  .first;
              await tester.enterText(input, '键盘上方保留的编辑草稿');
              tester.view.padding = const FakeViewPadding(top: 24);
              tester.view.viewInsets = FakeViewPadding(
                bottom: profile.keyboard,
              );
              await tester.pumpAndSettle();
            }
            await capture(scene);
            if (extraFamilies && scene == 'course-new') {
              final currentEditor = editor!;
              final l = AppLocalizations.of(tester.element(currentEditor));
              await _tap(tester, _key('course-start-time-action'));
              await capture('course-time-picker');
              await _tap(tester, find.text(l.cancel).hitTestable().last);
              await _tap(
                tester,
                find
                    .descendant(of: currentEditor, matching: find.text(l.more))
                    .first,
              );
              await _tap(tester, _key('course-reminder-behavior'));
              await _tap(
                tester,
                find.text(l.recurrenceCustom).hitTestable().last,
              );
              await tester.enterText(
                _key('course-reminder-custom-minutes'),
                '15',
              );
              await tester.pumpAndSettle();
              await capture('course-custom-reminder');
            } else if (extraFamilies && scene == 'event-new') {
              final l = AppLocalizations.of(tester.element(editor!));
              await _tap(tester, _key('event-recurrence-field'));
              await capture('event-recurrence-picker');
              await _tap(
                tester,
                find.text(l.recurrenceCustom).hitTestable().last,
              );
              final count = find.byWidgetPredicate(
                (widget) =>
                    widget is SkedEditorTextField &&
                    widget.label == l.recurrenceRepeatCount,
              );
              expect(count, findsOneWidget);
              await tester.ensureVisible(count);
              await tester.enterText(
                find.descendant(of: count, matching: find.byType(TextField)),
                '4',
              );
              await tester.pumpAndSettle();
              await capture('event-custom-recurrence-picker');
              await _tap(tester, find.text(l.cancel).hitTestable().last);
              await _tap(tester, _key('event-reminder-field'));
              await _tap(tester, _key('general-reminder-custom'));
              await capture('event-custom-reminder-picker');
            } else if (scene == 'category-manager') {
              await _tap(
                tester,
                find.descendant(
                  of: _key('calendar-manager-tile-mobile-calendar'),
                  matching: find.text(provider.activeGeneralSchedule.name),
                ),
              );
              await capture('category-rename');
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            provider.dispose();
          }
        }
      } finally {
        debugDefaultTargetPlatformOverride = originalPlatform;
        bridge.available = originalAvailable;
      }
    });
  }
}
