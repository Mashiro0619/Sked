import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import '../support/workspace_harness.dart';

void recordLayoutErrors() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    debugPrint(details.toString());
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

void main() {
  testWidgets(
    'wide settings keep the category navigation in the semantics tree',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1280);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();
      try {
        final p = await workspaceProvider(mode: AppMode.general);
        await tester.pumpWidget(
          WorkspaceHarness(provider: p, home: const SettingsPage()),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ThemeSettingsPage), findsOneWidget);
        expect(find.bySemanticsLabel('Language'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('settings-category-language')),
        );
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Appearance'), findsOneWidget);
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Appearance'), findsNothing);
        tester.view.physicalSize = const Size(800, 1280);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Appearance'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        p.dispose();
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'pointer double click opens the timed editor and Escape returns the canvas',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final p = await workspaceProvider(mode: AppMode.general);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final slot = find
          .byWidgetPredicate(
            (w) =>
                w is GestureDetector &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'general-timeline-empty-slot-',
                ),
          )
          .first;
      final point = tester.getTopLeft(slot) + const Offset(16, 100);
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      expect(
        tester
            .widget<GeneralEventEditorSheet>(
              find.byType(GeneralEventEditorSheet),
            )
            .initialDate!
            .weekday,
        DateTime.monday,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'explicit calendar navigation keeps date semantics and month-end clipping',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final p = await workspaceProvider(mode: AppMode.general);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final date = p.selectedGeneralDate;
      await tester.tap(find.byKey(const ValueKey('general-next-period')));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, addCalendarDays(date, 7));
      await tester.tap(find.byKey(const ValueKey('general-previous-period')));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, date);
      await tester.tap(find.byKey(const ValueKey('general-view-switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Month').last);
      await tester.pumpAndSettle();
      await p.setSelectedGeneralDate(DateTime(2026, 1, 31));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('general-next-period')));
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 2, 28));
      await tester.tap(
        find.byKey(const ValueKey('general-resource-previous-month')),
      );
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 2, 28));
      final navigator = find.byKey(
        const ValueKey('general-resource-date-picker'),
      );
      expect(
        find.descendant(of: navigator, matching: find.text('January 2026')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('general-resource-next-month')),
      );
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2026, 2, 28));
      expect(
        find.descendant(of: navigator, matching: find.text('February 2026')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('general-day-agenda-toggle')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Selected day'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'task editor fills its pane and applies the keyboard inset only once',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final p = await workspaceProvider(mode: AppMode.general);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add event'));
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField).first;
      await tester.enterText(field, 'Keyboard draft');
      final save = find.text('Save');
      expect(tester.getBottomRight(save).dy, greaterThan(700));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.getBottomRight(save).dy, lessThan(500));
      expect(tester.getBottomRight(save).dy, greaterThan(400));
      expect(
        tester.widget<TextFormField>(field).controller!.text,
        'Keyboard draft',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );

  testWidgets(
    'full restore retires an approved discarded draft even when the workspace remains enabled',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final p = await workspaceProvider(mode: AppMode.general);
      final backup = await p.exportAppDataJson();
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add event'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Must not survive replacement',
      );
      final l = AppLocalizations.of(
        tester.element(find.byType(GeneralEventEditorSheet)),
      );
      final restore = p.importAppDataJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.discardChangesAndExit));
      await restore;
      await tester.pumpAndSettle();
      expect(p.enabledWorkspaces, AppMode.values.toSet());
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      expect(
        p.generalSchedules
            .expand((s) => s.events)
            .where((e) => e.title == 'Must not survive replacement'),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );

  testWidgets(
    'event draft survives workspace switching and a settings round trip',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await workspaceProvider(mode: AppMode.general);
      final selectedDate = p.selectedGeneralDate;
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add event'));
      await tester.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      final state = tester.state(editor);
      final title = find
          .descendant(of: editor, matching: find.byType(TextField))
          .first;
      await tester.enterText(title, 'Retained event draft');
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Retained event draft',
        reason: 'input reaches the draft before navigation',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('workspace-resource-mode-student')),
      );
      await tester.pumpAndSettle();
      expect(p.activeMode, AppMode.student);
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      expect(
        tester.state(find.byType(GeneralEventEditorSheet, skipOffstage: false)),
        same(state),
      );
      await tester.tap(
        find.byKey(const ValueKey('workspace-resource-mode-general')),
      );
      await tester.pumpAndSettle();
      expect(tester.state(editor), same(state));
      expect(find.text('Retained event draft'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('workspace-resource-settings')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('settings-category-appearance')),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton).first);
      await tester.pumpAndSettle();
      expect(tester.state(editor), same(state));
      expect(find.text('Retained event draft'), findsOneWidget);
      expect(p.selectedGeneralDate, selectedDate);
      expect(
        p.generalSchedules
            .expand((calendar) => calendar.events)
            .any((event) => event.title == 'Retained event draft'),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resource month browsing stays transient and a single date click navigates',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = await workspaceProvider(mode: AppMode.general);
      await p.setSelectedGeneralDate(DateTime(2028, 1, 31));
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      final canvas = tester.element(
        find.byKey(const ValueKey('workspace-canvas')),
      );
      await tester.tap(
        find.byKey(const ValueKey('general-resource-next-month')),
      );
      await tester.pumpAndSettle();
      expect(p.selectedGeneralDate, DateTime(2028, 1, 31));
      await tester.tap(find.byKey(const ValueKey('sked-date-2028-02-29')));
      await tester.pumpAndSettle();
      expect(p.customGeneralDateRange, isNull);
      expect(p.selectedGeneralDate, DateTime(2028, 2, 29));
      expect(
        tester.element(find.byKey(const ValueKey('workspace-canvas'))),
        same(canvas),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  setUp(() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  });
  for (final mode in AppMode.values) {
    for (final width in [
      360.0,
      599.0,
      600.0,
      800.0,
      839.0,
      840.0,
      1199.0,
      1200.0,
      1280.0,
      1440.0,
      1920.0,
    ]) {
      testWidgets('${mode.name} uses available width at $width', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final p = await workspaceProvider(mode: mode);
        await tester.pumpWidget(WorkspaceHarness(provider: p));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final canvas = tester.getRect(
          find.byKey(const ValueKey('workspace-canvas')),
        );
        expect(canvas.width, greaterThan(width < 840 ? 260 : 590));
        if (width >= 1280) {
          expect(find.byType(WorkspaceResourcePanel), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        p.dispose();
      });
    }
  }
  for (final scale in [1.3, 2.0]) {
    for (final mode in AppMode.values) {
      testWidgets('${mode.name} remains operable at $scale text scale', (
        tester,
      ) async {
        recordLayoutErrors();
        await tester.binding.setSurfaceSize(const Size(800, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final p = await workspaceProvider(mode: mode);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: p,
            textScale: scale,
            locale: const Locale('de'),
            brightness: Brightness.dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        p.dispose();
      });
    }
  }
  testWidgets(
    'resizing an editor preserves its state and draft; close asks before losing it',
    (tester) async {
      recordLayoutErrors();
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final p = await workspaceProvider();
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Add course'));
      await tester.pumpAndSettle();
      final editor = tester.state(find.byType(CourseEditorSheet));
      final name = find
          .descendant(
            of: find.byType(CourseEditorSheet),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(name, 'Draft course');
      for (final width in [360.0, 1280.0, 800.0, 1440.0]) {
        await tester.binding.setSurfaceSize(Size(width, 900));
        await tester.pumpAndSettle();
        expect(
          identical(tester.state(find.byType(CourseEditorSheet)), editor),
          isTrue,
        );
        expect(find.text('Draft course'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Close').first);
      await tester.pumpAndSettle();
      expect(
        find.text('You have unsaved changes. Discard them and leave?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();
      expect(find.byType(CourseEditorSheet), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );
  testWidgets(
    'single workspace removes disabled pages and settings targets without a search',
    (tester) async {
      final p = await workspaceProvider();
      await p.setWorkspaceEnabled(AppMode.student, false);
      await tester.pumpWidget(WorkspaceHarness(provider: p));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen, skipOffstage: false), findsNothing);
      expect(find.byType(GeneralScheduleHomeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-search')), findsNothing);
      expect(
        find.byKey(const ValueKey('theme-workspace-target')),
        findsNothing,
      );
      expect(find.text('Student timetable'), findsNothing);
      expect(
        find.byKey(const ValueKey('settings-category-features')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );
  testWidgets(
    'editing the other workspace theme does not navigate away from the current workspace',
    (tester) async {
      final p = await workspaceProvider();
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const ThemeSettingsPage(initialWorkspace: AppMode.general),
        ),
      );
      await tester.pumpAndSettle();
      final brightness = find.byKey(
        const ValueKey('theme-brightness-mode-choice-list'),
      );
      await tester.ensureVisible(brightness);
      await tester.tap(brightness);
      await tester.pumpAndSettle();
      final dark = find.text('Dark');
      await tester.ensureVisible(dark.first);
      await tester.pumpAndSettle();
      await tester.tap(dark.first);
      await tester.pumpAndSettle();
      expect(p.activeMode, AppMode.student);
      expect(p.generalMode.themeMode, 'dark');
      expect(p.studentMode.themeMode, 'light');
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );
}
