import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/desktop_panel_harness.dart';
import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
final _desktop = TargetPlatformVariant.only(TargetPlatform.windows);
void _viewport(WidgetTester t, [Size size = const Size(1440, 900)]) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.reset);
}

Finder _agendaText(String text) => find.descendant(
  of: _key('general-selected-day-agenda'),
  matching: find.text(text),
);

void main() {
  testWidgets('agenda and reminders remain actionable after dragging', (
    t,
  ) async {
    _viewport(t, const Size(1100, 900));
    final p = await workspaceProvider(
      mode: AppMode.general,
      storage: desktopPanelStorage(count: 3),
    );
    addTearDown(p.dispose);
    await t.pumpWidget(desktopPanelHarness(p));
    await t.pumpAndSettle();
    await t.tap(_key('general-day-agenda-toggle'));
    await t.pumpAndSettle();
    final agenda = t.getRect(_key('workspace-detail-surface'));
    await t.drag(_key('workspace-view-drag-handle'), const Offset(-80, 90));
    await t.pumpAndSettle();
    final movedAgenda = t.getRect(_key('workspace-detail-surface'));
    expect(movedAgenda.left, lessThan(agenda.left));
    expect(movedAgenda.top, greaterThan(agenda.top));
    await t.tap(_key('general-day-agenda-add'));
    await t.pumpAndSettle();
    expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
    expect(_key('workspace-view-drag-handle'), findsNothing);
    await t.tap(_key('workspace-inspector-close'));
    await t.pumpAndSettle();
    expect(t.getRect(_key('workspace-detail-surface')), movedAgenda);
    await t.tap(_key('workspace-inspector-close'));
    await t.pumpAndSettle();
    await t.tap(_key('general-reminders-action'));
    await t.pumpAndSettle();
    await t.drag(_key('workspace-view-drag-handle'), const Offset(-100, 120));
    await t.pumpAndSettle();
    final movedReminders = t.getRect(_key('workspace-detail-surface'));
    await t.tap(find.byTooltip('Mark handled').last);
    await t.pumpAndSettle();
    expect(find.text('In-app reminder · 2'), findsOneWidget);
    final updatedReminders = t.getRect(_key('workspace-detail-surface'));
    expect(updatedReminders.topLeft, movedReminders.topLeft);
    expect(updatedReminders.height, lessThan(movedReminders.height));
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(_key('workspace-view-drag-handle'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  }, variant: _desktop);

  testWidgets(
    'month agenda is permanent; narrow fallback opens once and restores',
    (t) async {
      _viewport(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: desktopPanelStorage(),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(desktopPanelHarness(p));
      await t.pumpAndSettle();
      expect(_key('general-day-agenda-toggle'), findsNothing);
      expect(_key('workspace-view-drag-handle'), findsNothing);
      expect(_key('workspace-inspector-close'), findsNothing);
      expect(_key('general-selected-day-agenda'), findsOneWidget);
      expect(t.getRect(_key('general-day-agenda-add')).bottom, lessThan(180));
      t.view.physicalSize = const Size(1100, 900);
      await t.pumpAndSettle();
      expect(_key('general-day-agenda-toggle'), findsOneWidget);
      await t.tap(_key('general-day-agenda-toggle'));
      await t.pumpAndSettle();
      final panel = t.getRect(_key('workspace-detail-surface'));
      expect(panel.height, lessThan(300));
      await t.tap(_key('general-day-agenda-toggle'));
      await t.pumpAndSettle();
      expect(_key('workspace-inspector-close'), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(_key('workspace-inspector-close'), findsNothing);
      t.view.physicalSize = const Size(1440, 900);
      await t.pumpAndSettle();
      expect(_agendaText('Review session'), findsOneWidget);
      expect(_key('general-day-agenda-toggle'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: _desktop,
  );

  testWidgets(
    'desktop details have one header, grouped actions and full-height editor',
    (t) async {
      _viewport(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: desktopPanelStorage(),
      );
      addTearDown(p.dispose);
      await t.pumpWidget(desktopPanelHarness(p));
      await t.pumpAndSettle();
      await t.tap(_agendaText('Review session'));
      await t.pumpAndSettle();
      expect(_key('workspace-inspector-header'), findsNothing);
      expect(_key('workspace-inspector-close'), findsOneWidget);
      expect(t.getSize(_key('workspace-detail-surface')).height, lessThan(450));
      expect(
        find.descendant(
          of: _key('general-event-action-bar'),
          matching: find.text('Edit event'),
        ),
        findsOneWidget,
      );
      for (final action in ['duplicate', 'reminder', 'delete']) {
        expect(
          find.descendant(
            of: _key('general-event-action-bar'),
            matching: _key('general-event-$action-action'),
          ),
          findsOneWidget,
        );
      }
      await t.tap(_key('general-event-delete-action'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(_key('general-event-delete-dialog'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await t.tap(_key('general-event-edit-action'));
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      expect(t.getRect(_key('workspace-detail-surface')).bottom, 900);
      expect(p.selectedGeneralDate, DateTime(2026, 9, 28));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: _desktop,
  );

  testWidgets(
    'reminder failures retain rows and successful handling shrinks immediately',
    (t) async {
      _viewport(t);
      final storage = desktopPanelStorage(count: 3);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: storage,
      );
      addTearDown(p.dispose);
      await t.pumpWidget(desktopPanelHarness(p));
      await t.pumpAndSettle();
      await t.tap(_key('general-reminders-action'));
      await t.pumpAndSettle();
      final original = t.getSize(_key('workspace-detail-surface')).height;
      expect(find.text('In-app reminder · 3'), findsOneWidget);
      storage.saveError = StateError('intentional test save failure');
      await t.tap(find.byTooltip('Mark handled').first);
      await t.pumpAndSettle();
      expect(find.text('In-app reminder · 3'), findsOneWidget);
      expect(_key('ui-command-failure-notice'), findsOneWidget);
      await t.tap(find.byTooltip('Mark handled').last);
      await t.pumpAndSettle();
      expect(find.text('In-app reminder · 2'), findsOneWidget);
      expect(
        t.getSize(_key('workspace-detail-surface')).height,
        lessThan(original),
      );
      await t.tap(find.byTooltip('Mark handled').last);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Mark handled').last);
      await t.pumpAndSettle();
      expect(find.text('In-app reminder · 0'), findsOneWidget);
      expect(_key('workspace-inspector-close'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: _desktop,
  );

  testWidgets(
    'docked details restore permanent agenda and add uses its selected date',
    (t) async {
      _viewport(t);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: desktopPanelStorage(),
      );
      addTearDown(p.dispose);
      await p.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.sideBySide,
      );
      await t.pumpWidget(desktopPanelHarness(p));
      await t.pumpAndSettle();
      await t.tap(_agendaText('Review session'));
      await t.pumpAndSettle();
      expect(_key('general-selected-day-agenda'), findsNothing);
      expect(_key('general-day-agenda-toggle'), findsOneWidget);
      expect(t.getRect(_key('workspace-detail-surface')).bottom, 900);
      await t.tap(_key('workspace-inspector-close'));
      await t.pumpAndSettle();
      expect(_key('general-selected-day-agenda'), findsOneWidget);
      expect(_key('general-day-agenda-toggle'), findsNothing);
      await p.setSelectedGeneralDate(DateTime(2026, 9, 30));
      await t.pumpAndSettle();
      await t.tap(_key('general-day-agenda-add'));
      await t.pumpAndSettle();
      expect(
        t
            .widget<GeneralEventEditorSheet>(
              find.byType(GeneralEventEditorSheet),
            )
            .initialDate,
        DateTime(2026, 9, 30),
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: _desktop,
  );

  for (final locale in ['en', 'zh']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('details and reminders support $locale at $scale', (t) async {
        _viewport(t, const Size(1100, 900));
        final p = await workspaceProvider(
          mode: AppMode.general,
          storage: desktopPanelStorage(locale: locale, longNotes: true),
          locale: locale,
        );
        addTearDown(p.dispose);
        await t.pumpWidget(
          desktopPanelHarness(
            p,
            locale: locale,
            scale: scale,
            brightness: scale == 1.5 ? Brightness.dark : Brightness.light,
          ),
        );
        await t.pumpAndSettle();
        final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
        // Open through the same desktop reminder entry, including compact menus.
        final entry = _key('general-reminders-action');
        if (entry.evaluate().isEmpty) {
          await t.tap(_key('general-desktop-toolbar-more'));
          await t.pumpAndSettle();
        }
        await t.tap(entry);
        await t.pumpAndSettle();
        final title = locale == 'zh' ? '复习计划' : 'Review session';
        await t.tap(
          find.descendant(
            of: _key('general-reminders-list'),
            matching: find.text(title),
          ),
        );
        await t.pumpAndSettle();
        final header = t.getRect(_key('workspace-view-header'));
        await t.drag(_key('workspace-view-body'), const Offset(0, -200));
        await t.pumpAndSettle();
        expect(t.getRect(_key('workspace-view-header')), header);
        expect(
          t.getRect(_key('workspace-detail-surface')).bottom,
          lessThanOrEqualTo(892),
        );
        expect(frame.controller.hasViewPanel, isTrue);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }, variant: _desktop);
    }
  }
}
