import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/settings_data_transfer_controller.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/services/update_service.dart';
import 'package:sked/widgets/app_update_dialog.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_panel_header.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:sked/widgets/sked_task_session.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/sked_week_picker.dart';
import 'package:sked/widgets/timetable_information_form.dart';
import 'package:sked/widgets/workspace_editor_form.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../../test/support/category_manager_harness.dart';
import '../../test/support/workspace_harness.dart';
import '../support/capture_output_directory.dart';

enum _Group { course, timetable, event, categories, pickers, secondary }

const _captureKey = ValueKey('panel-heading-visual-capture');
const _courseId = 'panel-heading-course';
const _timetableId = 'panel-heading-timetable';
const _wideSize = Size(1440, 1000);
const _shortSize = Size(720, 420);
Finder _key(String key) => find.byKey(ValueKey(key));
Finder _inside(Finder parent, Finder child) =>
    find.descendant(of: parent, matching: child);

/// Native Windows rendering with memory-only fixtures and synthetic pointers.
/// Run each SKED_VISUAL_GROUP in a separate process to bound native resources.
/// SKED_VISUAL_SCENE=zh/en/rtl can further isolate one locale/scale scenario.
void registerCaptureScenarios() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final group = _Group.values.byName(
    const String.fromEnvironment('SKED_VISUAL_GROUP', defaultValue: 'course'),
  );
  const selectedScene = String.fromEnvironment(
    'SKED_VISUAL_SCENE',
    defaultValue: 'all',
  );
  const scenes = [
    _Scene('zh', 'zh'),
    _Scene('en', 'en'),
    _Scene(
      'rtl',
      'en',
      scale: 2,
      brightness: Brightness.dark,
      direction: TextDirection.rtl,
    ),
  ];
  if (!const ['all', 'zh', 'en', 'rtl'].contains(selectedScene)) {
    throw ArgumentError.value(selectedScene, 'SKED_VISUAL_SCENE');
  }
  for (final scene in scenes) {
    if (selectedScene != 'all' && selectedScene != scene.name) continue;
    // The extra feature gallery defaults to one Chinese scene; explicit
    // SKED_VISUAL_SCENE can still exercise its other locale/scale variants.
    if (group == _Group.secondary &&
        selectedScene == 'all' &&
        scene.name != 'zh') {
      continue;
    }
    testWidgets('Windows panel headings: ${group.name}-${scene.name}', (
      tester,
    ) async {
      final output = createCaptureOutputDirectory(label: 'panel-headings');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _wideSize;
      addTearDown(tester.view.reset);
      final mode = group == _Group.event || group == _Group.categories
          ? AppMode.general
          : AppMode.student;
      final provider = await workspaceProvider(
        mode: mode,
        locale: scene.locale,
        storage: group == _Group.categories
            ? categoryManagerStorage(locale: scene.locale)
            : WorkspaceMemoryStorage(_fixtureData(mode, scene.locale)),
      );
      await provider.settingsCommands.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.overlay,
      );
      if (mode == AppMode.student) {
        await provider.studentCommands.setSelectedWeek(3);
      }
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        provider.dispose();
      });
      final captures = <Map<String, Object?>>[];
      addTearDown(() async {
        await output.create(recursive: true);
        await File('${output.path}/${group.name}-${scene.name}-manifest.json')
            .writeAsString(
              const JsonEncoder.withIndent('  ').convert({
                'evidence':
                    'Actual Windows Flutter fonts; synthetic pointer; '
                    'memory-only application data.',
                'group': group.name,
                'locale': scene.locale,
                'textScale': scene.scale,
                'brightness': scene.brightness.name,
                'direction': scene.direction.name,
                'captures': captures,
              }),
            );
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: group == _Group.categories
              ? categoryManagerHarness(
                  provider,
                  locale: scene.locale,
                  scale: scene.scale,
                  direction: scene.direction,
                  brightness: scene.brightness,
                )
              : WorkspaceHarness(
                  provider: provider,
                  locale: Locale(scene.locale),
                  textScale: scene.scale,
                  textDirection: scene.direction,
                  brightness: scene.brightness,
                  home: switch (group) {
                    _Group.pickers => _PickerGallery(
                      config: provider.studentView.activeTimetable.config,
                    ),
                    _Group.secondary => const Scaffold(
                      key: ValueKey('heading-secondary-home'),
                      body: SizedBox.expand(),
                    ),
                    _ => null,
                  },
                ),
        ),
      );
      await tester.pumpAndSettle();
      final capture = _Capture(tester, group, scene, captures, output);
      switch (group) {
        case _Group.course:
          await _courseScenes(tester, provider, scene, capture);
        case _Group.timetable:
          await _timetableScenes(tester, provider, scene, capture);
        case _Group.event:
          await _eventScenes(tester, provider, scene, capture);
        case _Group.categories:
          await _categoryScenes(tester, scene, capture);
        case _Group.pickers:
          await _pickerScenes(tester, scene, capture);
        case _Group.secondary:
          await _secondaryScenes(tester, capture);
      }
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}

Future<void> _secondaryScenes(WidgetTester tester, _Capture capture) async {
  final context = tester.element(_key('heading-secondary-home'));
  final l = AppLocalizations.of(context);
  final themeRoute = Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => const ThemeSettingsPage()));
  await tester.pumpAndSettle();
  await _tap(tester, find.text(l.themeCustomColor).last);
  final color = find.byType(SkedTaskDialog).last;
  await capture('theme-color', [_panelHeading(color)]);
  await _tap(tester, _inside(color, _key('floating-form-close')));
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
  await themeRoute;

  const updateResult = UpdateCheckResult(
    localVersion: '3.0.0',
    remoteVersion: '3.0.1',
    releaseUrl: 'https://example.com/release',
    updateContent: '## 界面优化\n\n统一面板标题层级、字号和间距。',
    hasUpdate: true,
  );
  final updateSession = SkedTaskSession();
  addTearDown(updateSession.dispose);
  final updateRoute = showExpressiveDialog<void>(
    context: context,
    session: updateSession,
    builder: (_) => AppUpdateDialog(
      distribution: UpdateDistribution(
        UpdateChannel.github,
        urlLauncher: (_, _) async => true,
      ),
      session: updateSession,
      result: updateResult,
      startup: false,
      fallbackUrl: updateResult.releaseUrl,
      retry: () async => updateResult,
      recordResult: (_) async {},
      ignoreVersion: (_) async {},
    ),
  );
  await tester.pumpAndSettle();
  await capture('update', [_panelHeading(find.byType(AppUpdateDialog))]);
  await _tap(tester, _key('app-update-close'));
  await updateRoute;

  final assistant = AssistantPaneController();
  addTearDown(assistant.dispose);
  final assistantRoute = showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      child: SizedBox(
        width: 380,
        height: 560,
        child: AssistantPreviewPane(
          controller: assistant,
          onClose: () => Navigator.of(dialogContext).pop(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final assistantHeading = _panelHeading(find.byType(AssistantPreviewPane));
  await capture('assistant', [assistantHeading]);
  await _tap(tester, assistantHeading.close!);
  await assistantRoute;

  SettingsAppDataAction? selectedAction;
  final backupRoute = const SettingsDataTransferController().runAppDataFlow(
    context,
    hasRecoveryArtifacts: () => false,
    onAction: (action) async => selectedAction = action,
  );
  await tester.pumpAndSettle();
  final backupTitle = find.text(l.appBackupTitle);
  await capture('backup', [
    _Heading(backupTitle),
    _Heading(
      find.text(l.appBackupSheetSubtitle),
      size: 12,
      weight: FontWeight.w400,
      lineHeight: 1.4,
      role: 'context',
      afterRow: [backupTitle],
    ),
  ]);
  // The injected action only records the choice; it never accesses files.
  await _tap(tester, find.text(l.saveBackupTitle));
  await backupRoute;
  expect(selectedAction, SettingsAppDataAction.saveBackupFile);
}

Future<void> _courseScenes(
  WidgetTester tester,
  AppRuntime provider,
  _Scene scene,
  _Capture capture,
) async {
  await _tap(tester, _key('timetable-course-hit-$_courseId'));
  final details = find.byType(CourseDetailsSheet);
  expect(details, findsOneWidget);
  final l = AppLocalizations.of(tester.element(details));
  await capture('details', [_panelHeading(details, prominent: true)]);
  await _tap(tester, _inside(details, find.byTooltip(l.editCourseTooltip)));
  final editor = find.byType(CourseEditorSheet);
  expect(editor, findsOneWidget);
  final title = _key('course-desktop-title');
  final controller = _expectEditorName(tester, title);
  final draft = controller.text;
  await capture('editor', [_panelHeading(editor)]);
  final weeks = _inside(
    editor,
    find.byWidgetPredicate(
      (widget) =>
          widget is WorkspaceEditorValue && widget.label == l.semesterWeeks,
    ),
  );
  await _tap(tester, weeks);
  final picker = find.byType(SkedTaskDialog).last;
  expect(_inside(picker, find.text(l.selectSemesterWeeks)), findsOneWidget);
  final headings = [_panelHeading(editor), _panelHeading(picker)];
  await capture('editor-weeks', headings);
  if (scene.name == 'zh') {
    tester.view.physicalSize = const Size(850, 620);
    await tester.pumpAndSettle();
    await capture('editor-weeks-narrow', headings);
    tester.view.physicalSize = _shortSize;
    await tester.pumpAndSettle();
    expect(
      _inside(picker, _key('floating-form-close')).hitTestable(),
      findsOneWidget,
    );
    await capture('editor-weeks-short', headings);
    tester.view.physicalSize = _wideSize;
    await tester.pumpAndSettle();
  }
  await _tap(tester, _inside(picker, _key('floating-form-close')));
  expect(tester.widget<TextField>(title).controller, same(controller));
  expect(controller.text, draft);
  await capture('editor-return', [_panelHeading(editor)]);
  if (scene.name == 'zh') {
    await provider.settingsCommands.updateWorkspacePanelDisplayMode(
      WorkspacePanelDisplayMode.sideBySide,
    );
    await tester.pumpAndSettle();
    await capture('editor-docked', [_panelHeading(editor)]);
  }
}

Future<void> _timetableScenes(
  WidgetTester tester,
  AppRuntime provider,
  _Scene scene,
  _Capture capture,
) async {
  final l = AppLocalizations.of(tester.element(find.byType(WorkspaceFrame)));
  for (final editing in [false, true]) {
    if (!editing) {
      final create = find.byTooltip(l.createTimetable).hitTestable();
      if (create.evaluate().isEmpty) await _openStudentResources(tester);
      await _tap(tester, find.byTooltip(l.createTimetable).hitTestable());
    } else {
      final row = _key('resource-timetable-$_timetableId');
      if (row.hitTestable().evaluate().isEmpty) {
        await _openStudentResources(tester);
      }
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(row));
      await tester.pumpAndSettle();
      await _tap(tester, _key('resource-timetable-edit-$_timetableId'));
      await mouse.removePointer();
    }
    final editor = find.byType(TimetableInformationDialogSurface);
    expect(editor, findsOneWidget);
    final title = _inside(editor, find.byType(TextField)).first;
    _expectEditorName(tester, title);
    final state = editing ? 'edit' : 'add';
    await capture(state, [_panelHeading(editor)]);
    if (scene.name == 'zh') {
      tester.view.physicalSize = _shortSize;
      await tester.pumpAndSettle();
      expect(_key('workspace-editor-close').hitTestable(), findsOneWidget);
      await capture('$state-short', [_panelHeading(editor)]);
      tester.view.physicalSize = _wideSize;
      await tester.pumpAndSettle();
    }
    await _tap(tester, _key('workspace-editor-close'));
    expect(editor, findsNothing);
  }
  expect(provider.studentView.timetables, hasLength(1));
}

Future<void> _openStudentResources(WidgetTester tester) async {
  final picker = _key('student-timetable-picker-button').hitTestable();
  await _tap(
    tester,
    picker.evaluate().isNotEmpty
        ? picker
        : _key('workspace-resource-collapse').hitTestable(),
  );
}

Future<void> _eventScenes(
  WidgetTester tester,
  AppRuntime provider,
  _Scene scene,
  _Capture capture,
) async {
  final calendar = provider.generalView.schedules.first;
  final event = calendar.events.single;
  await _tap(
    tester,
    _key('general-timed-occurrence-${event.id}-${event.startDateTimeIso}'),
  );
  final details = find.byType(GeneralEventDetailsSheet);
  expect(details, findsOneWidget);
  final mainHeading = _panelHeading(details, prominent: true);
  final subtitle = _Heading(
    _inside(mainHeading.header!, find.text(calendar.name)),
    size: 12,
    weight: FontWeight.w400,
    lineHeight: 1.4,
    role: 'context',
    afterRow: [mainHeading.text, mainHeading.close!],
  );
  await capture('details', [mainHeading, subtitle]);
  if (scene.name == 'zh') {
    tester.view.physicalSize = _shortSize;
    await tester.pumpAndSettle();
    expect(mainHeading.close!.hitTestable(), findsOneWidget);
    await capture('details-short', [mainHeading, subtitle]);
    tester.view.physicalSize = _wideSize;
    await tester.pumpAndSettle();
  }
  await _tap(tester, _inside(details, _key('general-event-edit-action')));
  final editor = find.byType(GeneralEventEditorSheet);
  expect(editor, findsOneWidget);
  final l = AppLocalizations.of(tester.element(editor));
  final title = _inside(_key('event-desktop-title'), find.byType(TextField));
  final controller = _expectEditorName(tester, title);
  final draft = controller.text;
  await capture('editor', [_panelHeading(editor)]);
  await _tap(tester, _key('event-recurrence-field'));
  final recurrence = find.byType(SkedTaskDialog).last;
  await capture('recurrence', [_panelHeading(recurrence)]);
  await _tap(tester, _key('general-recurrence-choice-custom'));
  await capture('recurrence-custom', [_panelHeading(recurrence)]);
  await _tap(tester, _inside(recurrence, find.text(l.recurrenceEndDate)));
  final date = _key('sked-date-picker-surface');
  await capture('recurrence-date', [_dateHeading(tester, date)]);
  await _tap(tester, _inside(date, _key('sked-date-picker-close')));
  await _tap(tester, _key('general-recurrence-cancel'));
  await _tap(tester, _key('event-reminder-field'));
  final reminder = find.byType(SkedTaskDialog).last;
  await capture('reminder', [_panelHeading(reminder)]);
  if (scene.name == 'zh') {
    tester.view.physicalSize = _shortSize;
    await tester.pumpAndSettle();
    expect(
      _inside(reminder, _key('floating-form-close')).hitTestable(),
      findsOneWidget,
    );
    await capture('reminder-short', [_panelHeading(reminder)]);
    tester.view.physicalSize = _wideSize;
    await tester.pumpAndSettle();
  }
  await _tap(tester, _key('general-reminder-cancel'));
  expect(tester.widget<TextField>(title).controller, same(controller));
  expect(controller.text, draft);
}

Future<void> _categoryScenes(
  WidgetTester tester,
  _Scene scene,
  _Capture capture,
) async {
  await _tap(tester, _key('workspace-resource-open'));
  final manager = _key('category-manager-panel');
  expect(manager, findsOneWidget);
  final l = AppLocalizations.of(tester.element(manager));
  await capture('manager', [_panelHeading(manager)]);
  await _tap(tester, _key('calendar-name-category-1'));
  final name = _key('calendar-name-dialog');
  await capture('rename', [_panelHeading(name)]);
  await _tap(tester, _inside(name, _key('floating-form-close')));
  await _tap(tester, _inside(manager, find.text(l.addCalendar)));
  expect(_key('add-calendar-field'), findsOneWidget);
  await capture('add', [_panelHeading(name)]);
  await _tap(tester, _inside(name, _key('floating-form-close')));
  await _tap(tester, _key('calendar-color-category-1'));
  final color = _key('category-color-dialog');
  await capture('color', [_panelHeading(color)]);
  await _tap(tester, _inside(color, _key('floating-form-close')));
  if (scene.name == 'zh') {
    tester.view.physicalSize = const Size(850, 620);
    await tester.pumpAndSettle();
    await capture('manager-narrow', [_panelHeading(manager)]);
    tester.view.physicalSize = _shortSize;
    await tester.pumpAndSettle();
    expect(
      _inside(manager, _key('floating-form-close')).hitTestable(),
      findsOneWidget,
    );
    await capture('manager-short', [_panelHeading(manager)]);
  }
}

Future<void> _pickerScenes(
  WidgetTester tester,
  _Scene scene,
  _Capture capture,
) async {
  final l = AppLocalizations.of(tester.element(find.byType(_PickerGallery)));
  final m = MaterialLocalizations.of(
    tester.element(find.byType(_PickerGallery)),
  );
  for (final kind in ['date', 'range', 'month', 'time', 'week']) {
    await _tap(tester, _key('heading-gallery-$kind'));
    final surface = _key(switch (kind) {
      'time' => 'sked-time-picker-surface',
      'week' => 'sked-week-picker-surface',
      _ => 'sked-date-picker-surface',
    });
    expect(surface, findsOneWidget);
    final title = switch (kind) {
      'time' => m.timePickerDialHelpText,
      'week' => l.jumpToWeek,
      'range' => l.dateRangeTitle,
      'month' => l.datePickerSelectMonth,
      _ => l.pickDate,
    };
    final heading = _Heading(
      _inside(surface, find.text(title)).first,
      close: _inside(surface, find.byWidgetPredicate(_isCloseButton)).first,
    );
    final month = _key('sked-date-month-year');
    final headings = [
      heading,
      if (kind != 'time' && kind != 'week')
        _Heading(
          _inside(month, find.byType(Text)).first,
          size: 18,
          role: 'calendar-month',
        ),
    ];
    await capture(kind, headings);
    if (kind == 'date') {
      await _tap(tester, month);
      await capture('date-months', headings);
      await _tap(tester, month);
      await capture('date-years', headings);
    }
    if (scene.name == 'zh' && (kind == 'time' || kind == 'week')) {
      tester.view.physicalSize = _shortSize;
      await tester.pumpAndSettle();
      expect(heading.close!.hitTestable(), findsOneWidget);
      await capture('$kind-short', headings);
      tester.view.physicalSize = _wideSize;
      await tester.pumpAndSettle();
    }
    await _tap(tester, heading.close!);
    expect(surface, findsNothing);
  }
}

_Heading _dateHeading(WidgetTester tester, Finder surface) => _Heading(
  _inside(
    surface,
    find.text(AppLocalizations.of(tester.element(surface)).pickDate),
  ),
  close: _inside(surface, _key('sked-date-picker-close')),
);

_Heading _panelHeading(Finder scope, {bool prominent = false}) {
  final header = _inside(scope, find.byType(SkedPanelHeader)).first;
  return _Heading(
    _inside(header, find.byType(Text)).first,
    close: _inside(header, find.byWidgetPredicate(_isCloseButton)).last,
    size: prominent ? 18 : 16,
    role: prominent ? 'object' : 'operation',
    header: header,
  );
}

bool _isCloseButton(Widget widget) =>
    widget is IconButton &&
    widget.icon is Icon &&
    (widget.icon as Icon).icon == Icons.close;

TextEditingController _expectEditorName(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final field = tester.widget<TextField>(finder);
  expect(field.style!.fontSize, 18);
  expect(field.style!.fontWeight, FontWeight.w500);
  expect(field.style!.fontFamily, isNot('Ahem'));
  return field.controller!;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  // Keep the existing viewport when the control is already reachable. Forcing
  // it to the top would hide the editor's name in nested-picker screenshots.
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _Scene {
  const _Scene(
    this.name,
    this.locale, {
    this.scale = 1,
    this.brightness = Brightness.light,
    this.direction = TextDirection.ltr,
  });
  final String name, locale;
  final double scale;
  final Brightness brightness;
  final TextDirection direction;
}

class _Heading {
  const _Heading(
    this.text, {
    this.close,
    this.size = 16,
    this.role = 'operation',
    this.header,
    this.weight = FontWeight.w600,
    this.lineHeight = 1.35,
    this.afterRow = const [],
  });
  final Finder text;
  final Finder? close, header;
  final double size;
  final String role;
  final FontWeight weight;
  final double lineHeight;
  final List<Finder> afterRow;

  Map<String, Object?> inspect(WidgetTester tester) {
    expect(text, findsOneWidget, reason: role);
    final rich = _inside(text, find.byType(RichText)).first;
    final render = tester.renderObject<RenderParagraph>(rich);
    final style = render.text.style!;
    final label = render.text.toPlainText();
    expect(style.fontSize, size, reason: label);
    expect(style.fontWeight, weight, reason: label);
    expect(style.height, lineHeight, reason: label);
    expect(style.letterSpacing, 0, reason: label);
    expect(style.fontFamily, isNot('Ahem'), reason: label);
    final textBounds = tester.getRect(rich);
    if (afterRow.isNotEmpty) {
      final rowBottom = afterRow
          .map((finder) => tester.getRect(finder).bottom)
          .reduce((a, b) => a > b ? a : b);
      expect(textBounds.top - rowBottom, closeTo(4, .5), reason: label);
    }
    final closeFinder = close;
    Rect? closeBounds;
    if (closeFinder != null) {
      expect(closeFinder, findsOneWidget, reason: label);
      closeBounds = tester.getRect(closeFinder);
      expect(
        textBounds.center.dy,
        closeTo(closeBounds.center.dy, .5),
        reason: label,
      );
      final rtl = Directionality.of(tester.element(text)) == TextDirection.rtl;
      expect(
        rtl
            ? textBounds.left - closeBounds.right
            : closeBounds.left - textBounds.right,
        greaterThanOrEqualTo(-.5),
        reason: '$label must not overlap its close button',
      );
    }
    if (header case final header?) {
      final paddingFinder = find
          .ancestor(of: header, matching: find.byType(Padding))
          .first;
      final padding = tester
          .widget<Padding>(paddingFinder)
          .padding
          .resolve(Directionality.of(tester.element(header)));
      final rtl =
          Directionality.of(tester.element(header)) == TextDirection.rtl;
      expect(padding.top, 8, reason: label);
      expect(padding.bottom, 8, reason: label);
      expect(rtl ? padding.right : padding.left, 16, reason: label);
      expect(rtl ? padding.left : padding.right, 12, reason: label);
      expect(
        tester.getSize(paddingFinder).height,
        greaterThanOrEqualTo(48),
        reason: label,
      );
    }
    return {
      'text': label,
      'role': role,
      'fontSize': style.fontSize,
      'fontWeight': style.fontWeight!.value,
      'lineHeight': style.height,
      'letterSpacing': style.letterSpacing,
      'requestedFontFamily': style.fontFamily,
      'requestedFontFallback': style.fontFamilyFallback,
      'textRect': _rect(textBounds),
      if (closeBounds != null) 'closeRect': _rect(closeBounds),
    };
  }
}

class _Capture {
  const _Capture(
    this.tester,
    this.group,
    this.scene,
    this.captures,
    this.output,
  );
  final Directory output;
  final WidgetTester tester;
  final _Group group;
  final _Scene scene;
  final List<Map<String, Object?>> captures;

  Future<void> call(String state, List<_Heading> headings) async {
    await tester.pumpAndSettle();
    final name = '${group.name}-${scene.name}-$state';
    expect(tester.takeException(), isNull, reason: name);
    final metrics = headings.map((heading) => heading.inspect(tester)).toList();
    final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
    for (final surfaces in [
      _key('workspace-detail-surface'),
      _key('floating-form-surface'),
      find.byType(SkedFloatingSurface),
    ]) {
      for (var i = 0; i < surfaces.evaluate().length; i++) {
        final bounds = tester.getRect(surfaces.at(i));
        expect(bounds.left, greaterThanOrEqualTo(-.5), reason: name);
        expect(bounds.top, greaterThanOrEqualTo(-.5), reason: name);
        expect(
          bounds.right,
          lessThanOrEqualTo(viewport.width + .5),
          reason: name,
        );
        expect(
          bounds.bottom,
          lessThanOrEqualTo(viewport.height + .5),
          reason: name,
        );
      }
    }
    final image = await tester
        .renderObject<RenderRepaintBoundary>(find.byKey(_captureKey))
        .toImage(pixelRatio: 1);
    try {
      final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      await output.create(recursive: true);
      await File('${output.path}/$name.png')
          .writeAsBytes(data.buffer.asUint8List());
      captures.add({
        'file': '$name.png',
        'viewport': {'width': viewport.width, 'height': viewport.height},
        'headings': metrics,
      });
    } finally {
      image.dispose();
    }
  }
}

Map<String, double> _rect(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'width': rect.width,
  'height': rect.height,
};

class _PickerGallery extends StatelessWidget {
  const _PickerGallery({required this.config});
  final TimetableConfig config;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(64, 96, 64, 24),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            for (final kind in ['date', 'range', 'month', 'time', 'week'])
              Builder(
                builder: (anchor) => OutlinedButton(
                  key: ValueKey('heading-gallery-$kind'),
                  onPressed: () {
                    switch (kind) {
                      case 'time':
                        unawaited(
                          showSkedTimePicker(
                            context: anchor,
                            anchorContext: anchor,
                            initialTime: const TimeOfDay(hour: 10, minute: 30),
                          ),
                        );
                      case 'week':
                        unawaited(
                          showSkedWeekPicker(
                            context: anchor,
                            anchorContext: anchor,
                            config: config,
                            selectedWeek: 3,
                            currentDate: DateTime(2026, 10, 9),
                          ),
                        );
                      case 'range':
                        unawaited(
                          showSkedDateRangePicker(
                            context: anchor,
                            anchorContext: anchor,
                            initialRange: GeneralDateRange(
                              DateTime(2026, 10, 5),
                              DateTime(2026, 10, 11),
                            ),
                          ),
                        );
                      default:
                        unawaited(
                          showSkedDatePicker(
                            context: anchor,
                            anchorContext: anchor,
                            initialDate: DateTime(2026, 10, 9),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            selectionUnit: kind == 'month'
                                ? DateSelectionUnit.month
                                : DateSelectionUnit.day,
                          ),
                        );
                    }
                  },
                  child: Text(switch (kind) {
                    'time' => l.pickTime,
                    'week' => l.jumpToWeek,
                    'range' => l.dateRangeTitle,
                    'month' => l.datePickerSelectMonth,
                    _ => l.pickDate,
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

AppData _fixtureData(AppMode mode, String locale) {
  final initial = buildInitialAppData(
    buildDefaultPeriodTimes(),
    localeCode: locale,
  );
  final zh = locale == 'zh';
  return initial.copyWith(
    activeMode: mode,
    studentMode: initial.studentMode.copyWith(
      activeTimetableId: _timetableId,
      timetables: [
        TimetableData(
          id: _timetableId,
          config: TimetableConfig(
            name: zh ? '2026 秋季学期' : 'Autumn semester 2026',
            startDate: DateTime(2026, 9, 21),
            totalWeeks: 19,
            periodTimeSetId: initial.studentMode.periodTimeSets.first.id,
          ),
          courses: [
            CourseItem(
              id: _courseId,
              name: zh ? '大学物理A(下)' : 'University physics A (II)',
              teacher: zh ? '陈老师' : 'Professor Chen',
              location: zh
                  ? '辽河路校区 天璇B221阶(智慧教室)'
                  : 'Liaohe Campus · Tianxuan B221',
              dayOfWeek: 1,
              semesterWeeks: [
                for (var week = 1; week <= 18; week++)
                  if (week < 13 || week > 14) week,
              ],
              periods: const [3, 4],
              startMinutes: 630,
              endMinutes: 735,
              timeRange: '10:30 - 12:15',
              credit: 3,
              remarks: zh ? '课前预习教材，课后完成练习。' : 'Read the textbook before class; complete the exercises afterwards.',
              customFields: const {},
            ),
          ],
        ),
      ],
    ),
    generalMode: initial.generalMode.copyWith(
      activeScheduleId: 'panel-heading-calendar',
      selectedDateIso: '2026-10-09',
      defaultView: generalViewWeek,
      schedules: [
        GeneralSchedule(
          id: 'panel-heading-calendar',
          name: zh ? '学习' : 'Study',
          events: [
            GeneralEvent(
              id: 'panel-heading-event',
              calendarId: 'panel-heading-calendar',
              title: zh ? '项目进度讨论' : 'Project review',
              location: zh ? '图书馆研讨室' : 'Library seminar room',
              startDateTimeIso: '2026-10-09T10:00:00.000',
              endDateTimeIso: '2026-10-09T11:30:00.000',
              notes: zh
                  ? '整理本周进度，安排下一步工作。'
                  : 'Review this week and plan the next steps.',
            ),
          ],
        ),
        GeneralSchedule(
          id: 'panel-heading-personal',
          name: zh ? '生活' : 'Personal',
          events: const [],
        ),
      ],
    ),
  );
}
