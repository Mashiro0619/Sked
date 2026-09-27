import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/settings_list.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);
void _viewport(WidgetTester t, [Size size = const Size(1440, 1000)]) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> _choose(WidgetTester t, String key, String label) async {
  final field = _key(key);
  await t.ensureVisible(field);
  await t.pumpAndSettle();
  await t.tap(field);
  await t.pumpAndSettle();
  await t.tap(find.text(label).last);
  await t.pumpAndSettle();
}

void main() {
  for (final mode in AppMode.values) {
    testWidgets(
      'real $mode editor and AI expand to four fifths without losing drafts',
      (t) async {
        _viewport(t, const Size(1920, 1000));
        final provider = await workspaceProvider(mode: mode);
        addTearDown(provider.dispose);
        final preferences = DeveloperUiPreferences.memory(visible: true);
        addTearDown(preferences.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            developerUiPreferences: preferences,
          ),
        );
        await t.pumpAndSettle();
        await t.tap(_key('assistant-toggle'));
        await t.pumpAndSettle();
        final sidebar = t.getRect(_key('workspace-resource-width'));
        final canvas = t.getRect(_key('workspace-canvas-viewport'));
        final maximum = (1920 - sidebar.width - 1) * .8;
        final l = AppLocalizations.of(t.element(find.byType(WorkspaceFrame)));
        await t.tap(
          mode == AppMode.general
              ? _key('general-add-event')
              : find.widgetWithText(FilledButton, l.addCourse).first,
        );
        await t.pumpAndSettle();
        final editor = mode == AppMode.general
            ? find.byType(GeneralEventEditorSheet)
            : find.byType(CourseEditorSheet);
        final state = t.state(editor);
        final field = find
            .descendant(of: editor, matching: find.byType(TextField))
            .first;
        await t.enterText(field, 'Resizable editor draft');
        await t.drag(_key('workspace-detail-resize'), const Offset(-1800, 0));
        await t.pumpAndSettle();
        expect(
          t.getSize(_key('workspace-detail-pane')).width,
          closeTo(maximum, .01),
        );
        expect(t.getSize(editor).width, closeTo(maximum, .01));
        expect(t.getRect(_key('workspace-resource-width')), sidebar);
        expect(t.getRect(_key('workspace-canvas-viewport')), canvas);
        await t.tap(_key('assistant-toggle'));
        await t.pumpAndSettle();
        await t.enterText(_key('assistant-draft'), 'Resizable AI draft');
        await t.drag(
          _key('workspace-assistant-resize'),
          const Offset(-1800, 0),
        );
        await t.pumpAndSettle();
        expect(
          t.getSize(_key('workspace-assistant-pane')).width,
          closeTo(maximum, .01),
        );
        expect(t.getRect(_key('workspace-resource-width')), sidebar);
        expect(t.getRect(_key('workspace-canvas-viewport')), canvas);
        expect(
          t.widget<TextField>(_key('assistant-draft')).controller!.text,
          'Resizable AI draft',
        );
        await t.tap(_key('assistant-toggle'));
        await t.pumpAndSettle();
        expect(t.state(editor), same(state));
        expect(
          t.widget<TextField>(field).controller!.text,
          'Resizable editor draft',
        );
        expect(t.getSize(editor).width, closeTo(maximum, .01));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: _desktop,
    );
  }

  for (final workspace in AppMode.values) {
    for (final collapsed in [false, true]) {
      testWidgets(
        'IME keeps the $workspace sidebar and calendar widths: collapsed=$collapsed',
        (t) async {
          _viewport(t, const Size(1200, 800));
          addTearDown(t.view.resetViewInsets);
          final provider = await workspaceProvider(mode: workspace);
          addTearDown(provider.dispose);
          await provider.updateHomeWorkspaceNavigationCollapsed(collapsed);
          final preferences = DeveloperUiPreferences.memory(visible: true);
          addTearDown(preferences.dispose);
          await t.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              developerUiPreferences: preferences,
            ),
          );
          await t.pumpAndSettle();
          final sidebar = t.getRect(_key('workspace-resource-width'));
          final canvas = t.getRect(_key('workspace-canvas-viewport'));
          await t.enterText(
            _key('assistant-draft'),
            'Keep the layout while typing',
          );
          t.view.viewInsets = const FakeViewPadding(bottom: 400);
          await t.pumpAndSettle();
          final keyboardCanvas = t.getRect(_key('workspace-canvas-viewport'));
          expect(
            t.getSize(_key('workspace-resource-width')).width,
            sidebar.width,
          );
          expect(keyboardCanvas.left, canvas.left);
          expect(keyboardCanvas.width, canvas.width);
          expect(keyboardCanvas.height, lessThan(canvas.height));
          expect(provider.homeWorkspaceNavigationCollapsed, collapsed);
          expect(
            t.widget<TextField>(_key('assistant-draft')).controller!.text,
            'Keep the layout while typing',
          );
          t.view.resetViewInsets();
          await t.pumpAndSettle();
          expect(t.getRect(_key('workspace-resource-width')), sidebar);
          expect(t.getRect(_key('workspace-canvas-viewport')), canvas);
          // Real window resizing still selects the short-window layout.
          t.view.physicalSize = const Size(1200, 400);
          await t.pumpAndSettle();
          expect(t.getSize(_key('workspace-resource-width')).width, 80);
          expect(provider.homeWorkspaceNavigationCollapsed, collapsed);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.android),
      );
    }
  }

  testWidgets(
    'visible sidebar can navigate without closing or retargeting a course draft',
    (t) async {
      _viewport(t);
      final provider = await workspaceProvider();
      addTearDown(provider.dispose);
      final original = provider.activeTimetable;
      await provider.addTimetable(
        original.config.copyWith(name: 'Another timetable'),
      );
      final other = provider.activeTimetable;
      await provider.switchTimetable(original.id);
      await t.pumpWidget(WorkspaceHarness(provider: provider));
      await t.pumpAndSettle();
      final l = AppLocalizations.of(t.element(find.byType(WorkspaceFrame)));
      await t.tap(find.widgetWithText(FilledButton, l.addCourse).first);
      await t.pumpAndSettle();
      final editor = find.byType(CourseEditorSheet);
      final state = t.state(editor);
      final field = find
          .descendant(of: editor, matching: find.byType(TextField))
          .first;
      await t.enterText(field, 'Original timetable draft');
      await t.tap(_key('resource-timetable-${other.id}'));
      await t.pumpAndSettle();
      expect(provider.activeTimetable.id, other.id);
      expect(t.state(editor), same(state));
      expect(
        t.widget<TextField>(field).controller!.text,
        'Original timetable draft',
      );
      await t.tap(
        find.descendant(of: editor, matching: find.text(l.save)).last,
      );
      await t.pumpAndSettle();
      expect(editor, findsNothing);
      expect(
        provider.timetables
            .singleWhere((table) => table.id == original.id)
            .courses
            .where((course) => course.name == 'Original timetable draft'),
        hasLength(1),
      );
      expect(provider.activeTimetable.id, other.id);
      expect(provider.activeTimetable.courses, other.courses);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
    variant: _desktop,
  );

  for (final overview in [true, false]) {
    testWidgets('panel setting is global in appearance overview=$overview', (
      t,
    ) async {
      _viewport(t);
      final storage = WorkspaceMemoryStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final provider = await workspaceProvider(storage: storage);
      addTearDown(provider.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: provider,
          home: overview
              ? SettingsPage(
                  packageInfoLoader: () async => PackageInfo(
                    appName: 'Sked',
                    packageName: 'test.sked',
                    version: '2.3.0-alpha.1',
                    buildNumber: '14',
                  ),
                )
              : const ThemeSettingsPage(initialWorkspace: AppMode.general),
        ),
      );
      await t.pumpAndSettle();
      final choice = _key('settings-panel-display-mode');
      await t.ensureVisible(choice);
      await t.pumpAndSettle();
      final l = AppLocalizations.of(t.element(choice));
      SettingsChoiceTile<WorkspacePanelDisplayMode> tile() =>
          t.widget<SettingsChoiceTile<WorkspacePanelDisplayMode>>(choice);
      expect(tile().value, WorkspacePanelDisplayMode.overlay);
      expect(tile().workspace, isNull);
      expect(
        tile().entries.map((entry) => entry.value),
        WorkspacePanelDisplayMode.values,
      );
      await _choose(
        t,
        'settings-panel-display-mode',
        l.settingsPanelDisplaySideBySide,
      );
      expect(
        provider.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.sideBySide,
      );
      expect(
        storage.data.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.sideBySide,
      );
      await _choose(
        t,
        'theme-workspace-target',
        overview ? l.themeWorkspaceSchedule : l.timetable,
      );
      expect(tile().value, WorkspacePanelDisplayMode.sideBySide);
      expect(provider.activeMode, AppMode.student);
      await _choose(
        t,
        'settings-panel-display-mode',
        l.settingsPanelDisplayAutomatic,
      );
      expect(
        provider.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.automatic,
      );
      storage.saveError = StateError('save failed');
      await _choose(
        t,
        'settings-panel-display-mode',
        l.settingsPanelDisplayOverlay,
      );
      expect(
        provider.workspacePanelDisplayMode,
        WorkspacePanelDisplayMode.automatic,
      );
      expect(tile().value, WorkspacePanelDisplayMode.automatic);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    }, variant: _desktop);
  }

  for (final collapsed in [false, true]) {
    for (final view in [generalViewWeek, generalViewMonth]) {
      testWidgets(
        'actual schedule toolbar overlays retain geometry: $view collapsed=$collapsed',
        (t) async {
          _viewport(t);
          final provider = await workspaceProvider(mode: AppMode.general);
          addTearDown(provider.dispose);
          await provider.updateHomeWorkspaceNavigationCollapsed(collapsed);
          await provider.updateGeneralDisplaySettings(defaultView: view);
          final preferences = DeveloperUiPreferences.memory(visible: true);
          addTearDown(preferences.dispose);
          await t.pumpWidget(
            WorkspaceHarness(
              provider: provider,
              developerUiPreferences: preferences,
            ),
          );
          await t.pumpAndSettle();
          await t.tap(_key('assistant-toggle'));
          await t.pumpAndSettle();
          expect(find.byType(AssistantPreviewPane), findsNothing);
          final sidebar = t.getRect(_key('workspace-resource-width'));
          final calendar = t.getRect(_key('workspace-canvas-viewport'));
          final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
          void expectStable() {
            expect(t.getRect(_key('workspace-resource-width')), sidebar);
            expect(t.getRect(_key('workspace-canvas-viewport')), calendar);
            expect(provider.homeWorkspaceNavigationCollapsed, collapsed);
            expect(_key('assistant-toggle').hitTestable(), findsOneWidget);
          }

          for (final key in [
            'general-reminders-action',
            'general-day-agenda-toggle',
            'general-add-event',
          ]) {
            await t.tap(_key(key));
            await t.pumpAndSettle();
            expect(frame.controller.hasPaneTasks, isTrue, reason: key);
            expectStable();
            expect(t.getRect(_key('workspace-detail-pane')).top, calendar.top);
            await t.tap(_key('workspace-inspector-close'));
            await t.pumpAndSettle();
            expect(frame.controller.hasPaneTasks, isFalse, reason: key);
            expectStable();
          }
          await t.tap(_key('assistant-toggle'));
          await t.pumpAndSettle();
          expectStable();
          expect(find.byType(AssistantPreviewPane), findsOneWidget);
          expect(preferences.assistantVisible, isTrue);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox.shrink());
        },
        variant: _desktop,
      );
    }
  }

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
      'actual timetable keeps its geometry and applies the shared mode at text scale $scale',
      (t) async {
        _viewport(t, const Size(1920, 1100));
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        await t.pumpWidget(
          WorkspaceHarness(provider: provider, textScale: scale),
        );
        await t.pumpAndSettle();
        final sidebar = t.getRect(_key('workspace-resource-width'));
        final calendar = t.getRect(_key('workspace-canvas-viewport'));
        final toolbar = t.getRect(_key('student-workspace-toolbar'));
        final dayHeader = t.getRect(_key('timetable-day-header').first);
        // Keep both the pager spacing and the grid's existing inner spacing.
        expect(dayHeader.top, toolbar.bottom + 8);
        final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
        final l = AppLocalizations.of(t.element(find.byType(WorkspaceFrame)));
        await t.tap(find.widgetWithText(FilledButton, l.addCourse).first);
        await t.pumpAndSettle();
        expect(frame.controller.hasPaneTasks, isTrue);
        expect(t.getRect(_key('workspace-resource-width')), sidebar);
        expect(t.getRect(_key('workspace-canvas-viewport')), calendar);
        expect(t.getRect(_key('workspace-detail-pane')).top, toolbar.bottom);
        expect(t.getRect(_key('workspace-detail-resize')).top, toolbar.bottom);
        expect(t.getRect(_key('timetable-day-header').first), dayHeader);
        await provider.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.sideBySide,
        );
        await t.pumpAndSettle();
        expect(
          t
              .widget<WorkspaceFrame>(find.byType(WorkspaceFrame))
              .panelDisplayMode,
          WorkspacePanelDisplayMode.sideBySide,
        );
        expect(t.getRect(_key('workspace-resource-width')), sidebar);
        expect(t.getRect(_key('workspace-detail-pane')).top, toolbar.bottom);
        expect(t.getRect(_key('workspace-detail-resize')).top, toolbar.bottom);
        expect(
          t.getRect(_key('timetable-day-header').first).top,
          dayHeader.top,
        );
        if (scale < 2) {
          expect(
            t.getSize(_key('workspace-canvas-viewport')).width,
            lessThan(calendar.width),
          );
        }
        await t.tap(_key('workspace-inspector-close'));
        await t.pumpAndSettle();
        expect(frame.controller.hasPaneTasks, isFalse);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: _desktop,
    );
  }
}
