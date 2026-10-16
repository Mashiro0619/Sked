import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/semantics_update_audit.dart';
import '../support/workspace_harness.dart';

class _AuditedBinding extends AutomatedTestWidgetsFlutterBinding {
  final audit = SemanticsUpdateAudit();

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

Finder _key(String value) => find.byKey(ValueKey(value));

List<int> _traversalAncestors(SemanticsNode node) {
  final result = <int>[];
  SemanticsNode? current = node;
  while (current != null) {
    expect(result, isNot(contains(current.id)), reason: 'Semantics cycle.');
    result.add(current.id);
    current = current.traversalParent;
  }
  return result;
}

void main() {
  final binding = _AuditedBinding();
  setUp(binding.audit.reset);

  for (final outsideDismiss in [true, false]) {
    testWidgets('hovered navigation retains its semantic parents and panel actions '
        'when outside dismissal is $outsideDismiss', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 720);
      final semantics = tester.ensureSemantics();
      final app = await workspaceProvider(mode: AppMode.general);
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      var pointerAdded = false;
      try {
        await app.settingsCommands.updateWorkspacePanelDisplayMode(
          WorkspacePanelDisplayMode.sideBySide,
        );
        await app.generalCommands.updateDisplaySettings(
          closeEventPopupOnOutsideTap: outsideDismiss,
        );
        await tester.pumpWidget(WorkspaceHarness(provider: app));
        await tester.pumpAndSettle();
        final originalDate = app.generalView.selectedDate;
        final originalEventCount = app
            .session
            .committedData
            .generalMode
            .schedules
            .expand((calendar) => calendar.events)
            .length;
        final navigation = _key('general-next-period');
        final canvas = _key('workspace-canvas');
        final navigationBefore = tester.getSemantics(navigation);
        final parentsBefore = _traversalAncestors(navigationBefore);
        final canvasBefore = tester.getSemantics(canvas);
        expect(
          navigationBefore.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(
          canvasBefore.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        final viewSwitcher = _key('general-view-switcher');
        final viewSemantics = tester.getSemantics(viewSwitcher);
        expect(viewSemantics.id, isNot(canvasBefore.id));
        expect(
          viewSemantics.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(
          viewSemantics.rect.size.width,
          lessThan(canvasBefore.rect.width),
        );

        final ancestor = find.ancestor(
          of: navigation,
          matching: find.byType(Tooltip),
        );
        final descendant = find.descendant(
          of: navigation,
          matching: find.byType(Tooltip),
        );
        final tooltip = tester.widget<Tooltip>(
          ancestor.evaluate().isNotEmpty ? ancestor.first : descendant.first,
        );
        final tooltipText =
            tooltip.message ?? tooltip.richMessage!.toPlainText();
        await mouse.addPointer(location: const Offset(8, 100));
        pointerAdded = true;
        await mouse.moveTo(tester.getCenter(navigation));
        await tester.pump(const Duration(milliseconds: 900));
        expect(find.text(tooltipText), findsOneWidget);

        // Open during the real tooltip's exit transition, before settling.
        final open = tester.getCenter(_key('general-add-event'));
        await mouse.moveTo(open);
        await mouse.down(open);
        await mouse.up();
        await tester.pump();
        expect(
          _traversalAncestors(tester.getSemantics(navigation)),
          parentsBefore,
          reason:
              'Opening a pane must not move a live tooltip traversal subtree.',
        );
        final canvasWithPanel = tester.getSemantics(canvas);
        expect(canvasWithPanel.id, canvasBefore.id);
        expect(
          canvasWithPanel.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          outsideDismiss,
        );
        expect(
          tester
              .getSemantics(navigation)
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(
          tester.getSemantics(navigation).getSemanticsData().tooltip,
          tooltipText,
        );
        expect(binding.audit.errors, isEmpty);
        await tester.pumpAndSettle();

        final editor = find.byType(GeneralEventEditorSheet);
        expect(editor, findsOneWidget);
        final editorState = tester.state(editor);
        final l10n = AppLocalizations.of(tester.element(editor));
        final title = _key('event-desktop-title');
        const draft = 'Keep the accessible event draft';
        await tester.enterText(title, draft);
        await tester.pumpAndSettle();
        final titleNode = tester.getSemantics(title).getSemanticsData();
        expect(titleNode.flagsCollection.isTextField, isTrue);
        expect(titleNode.value, draft);
        final focusBefore = FocusManager.instance.primaryFocus;
        await tester.sendKeyEvent(
          LogicalKeyboardKey.tab,
          physicalKey: PhysicalKeyboardKey.tab,
        );
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNot(same(focusBefore)));

        if (outsideDismiss) {
          // Use the actual published accessibility action, not a direct
          // controller callback. A dirty editor must still guard dismissal.
          final dismiss = tester.getSemantics(canvas);
          dismiss.owner!.performAction(dismiss.id, ui.SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(find.text(l10n.unsavedChangesMessage), findsOneWidget);
          await tester.tap(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(TextButton, l10n.cancel),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.state(editor), same(editorState));
          expect(find.text(draft), findsOneWidget);
        }

        await tester.sendKeyEvent(
          LogicalKeyboardKey.escape,
          physicalKey: PhysicalKeyboardKey.escape,
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.unsavedChangesMessage), findsOneWidget);
        await tester.tap(find.text(l10n.discardChangesAndExit));
        await tester.pumpAndSettle();
        expect(editor, findsNothing);
        expect(
          _traversalAncestors(tester.getSemantics(navigation)),
          parentsBefore,
        );
        final canvasAfter = tester.getSemantics(canvas);
        expect(canvasAfter.id, canvasBefore.id);
        expect(
          canvasAfter.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isFalse,
        );
        expect(
          tester
              .getSemantics(navigation)
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(app.generalView.selectedDate, originalDate);
        expect(
          app.session.committedData.generalMode.schedules
              .expand((calendar) => calendar.events)
              .length,
          originalEventCount,
        );
        expect(binding.audit.errors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        if (pointerAdded) await mouse.removePointer();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        app.dispose();
        semantics.dispose();
        tester.view.reset();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
