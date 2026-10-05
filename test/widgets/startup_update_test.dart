import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/app_update_coordinator.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/services/update_service.dart';
import 'package:sked/services/update_distribution.dart';
import 'package:sked/widgets/app_update_dialog.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/update_prompt_scope.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';
import '../support/reminder_summary_harness.dart';

class _Updates extends UpdateService {
  int calls = 0;
  final pending = Completer<UpdateCheckResult>();
  @override
  Future<UpdateCheckResult> checkForUpdates({bool includePrereleases = false}) {
    calls++;
    return pending.future;
  }

  void complete() => pending.complete(
    const UpdateCheckResult(
      localVersion: '1.0.0',
      remoteVersion: '2.0.0',
      releaseUrl: 'https://example.com/release',
      updateContent: 'Notes',
      hasUpdate: true,
    ),
  );
}

Finder k(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets(
    'home checks only after privacy acceptance and only once across rebuilds',
    (tester) async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final prompts = UpdatePromptController(isForeground: () => true);
      addTearDown(prompts.dispose);
      final updates = _Updates();
      Widget harness() => UpdatePromptScope(
        controller: prompts,
        child: WorkspaceHarness(
          provider: p,
          home: AppHomeScreen(
            updateService: updates,
            updateDistribution: const UpdateDistribution(UpdateChannel.github),
          ),
        ),
      );
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(updates.calls, 0);
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(updates.calls, 1);
      updates.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AppUpdateDialog), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await p.switchMode(AppMode.general);
      await tester.pumpAndSettle();
      expect(updates.calls, 1);
    },
  );

  for (final foreground in [true, false]) {
    testWidgets(
      'startup reminder wins and hidden windows do not show updates (foreground=$foreground)',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1440, 900);
        addTearDown(tester.view.reset);
        final p = await workspaceProvider(
          mode: AppMode.general,
          storage: reminderSummaryStorage(),
        );
        addTearDown(p.dispose);
        await p.acceptPrivacyPolicyCurrentVersion();
        final prompts = UpdatePromptController(isForeground: () => foreground);
        addTearDown(prompts.dispose);
        final updates = _Updates();
        await tester.pumpWidget(
          UpdatePromptScope(
            controller: prompts,
            child: reminderSummaryHarness(
              p,
              ReminderSummaryClock(),
              home: AppHomeScreen(
                updateService: updates,
                updateDistribution: const UpdateDistribution(
                  UpdateChannel.github,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(updates.calls, 1);
        expect(k('general-reminders-list'), findsOneWidget);
        expect(prompts.canPrompt, isFalse);
        updates.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AppUpdateDialog), findsNothing);
        expect(p.availableUpdateVersion, '2.0.0');
        await tester.pump(const Duration(seconds: 20));
        await tester.pumpAndSettle();
        expect(find.byType(AppUpdateDialog), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'independent detail remains a blocker after its parent reminder closes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: reminderSummaryStorage(),
      );
      addTearDown(p.dispose);
      final prompts = UpdatePromptController(isForeground: () => true);
      addTearDown(prompts.dispose);
      await tester.pumpWidget(
        UpdatePromptScope(
          controller: prompts,
          child: reminderSummaryHarness(p, ReminderSummaryClock()),
        ),
      );
      await tester.pumpAndSettle();
      expect(prompts.canPrompt, isTrue);
      await tester.tap(k('general-reminders-action'));
      await tester.pumpAndSettle();
      expect(prompts.canPrompt, isFalse);
      await tester.tap(
        find.descendant(
          of: k('general-reminders-list'),
          matching: find.text('Study group'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GeneralEventDetailsSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: k('general-reminders-list'),
          matching: k('workspace-inspector-close'),
        ),
      );
      await tester.pumpAndSettle();
      expect(k('general-reminders-list'), findsNothing);
      expect(prompts.canPrompt, isFalse);
      await tester.tap(
        find.descendant(
          of: find.byType(GeneralEventDetailsSheet),
          matching: k('workspace-inspector-close'),
        ),
      );
      await tester.pumpAndSettle();
      expect(prompts.canPrompt, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final mode in AppMode.values) {
    for (final layout in [
      WorkspacePanelDisplayMode.overlay,
      WorkspacePanelDisplayMode.sideBySide,
    ]) {
      testWidgets(
        'late startup result does not interrupt $mode $layout editor',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(1440, 900);
          addTearDown(tester.view.reset);
          final p = await workspaceProvider(
            mode: mode,
            storage: mode == AppMode.general
                ? reminderSummaryStorage(empty: true)
                : null,
          );
          addTearDown(p.dispose);
          await p.updateWorkspacePanelDisplayMode(layout);
          final prompts = UpdatePromptController(isForeground: () => true);
          addTearDown(prompts.dispose);
          await tester.pumpWidget(
            UpdatePromptScope(
              controller: prompts,
              child: WorkspaceHarness(provider: p),
            ),
          );
          await tester.pumpAndSettle();
          expect(prompts.canPrompt, isTrue);
          final updates = _Updates();
          final task = AppUpdateCoordinator.checkForUpdates(
            tester.element(find.byType(Scaffold).first),
            provider: p,
            source: UpdateCheckSource.startup,
            updateService: updates,
            distribution: const UpdateDistribution(UpdateChannel.github),
            canShowStartupPrompt: () => prompts.canPrompt,
          );
          await tester.tap(
            k(
              mode == AppMode.general
                  ? 'general-add-event'
                  : 'student-add-course',
            ),
          );
          await tester.pumpAndSettle();
          final editor = find.byType(
            mode == AppMode.general
                ? GeneralEventEditorSheet
                : CourseEditorSheet,
          );
          final element = tester.element(editor);
          expect(prompts.canPrompt, isFalse);
          updates.complete();
          await task;
          await tester.pumpAndSettle();
          expect(find.byType(AppUpdateDialog), findsNothing);
          expect(tester.element(editor), same(element));
          expect(p.availableUpdateVersion, '2.0.0');
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  for (final presentation in [
    WorkspacePanePresentation.editor,
    WorkspacePanePresentation.view,
  ]) {
    testWidgets('workspace $presentation blocks without a root route', (
      tester,
    ) async {
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final prompts = UpdatePromptController(isForeground: () => true);
      addTearDown(prompts.dispose);
      await tester.pumpWidget(
        UpdatePromptScope(
          controller: prompts,
          child: WorkspaceHarness(provider: p),
        ),
      );
      await tester.pumpAndSettle();
      final pane = tester
          .widgetList<WorkspaceFrame>(find.byType(WorkspaceFrame))
          .firstWhere((w) => w.active)
          .controller;
      unawaited(
        pane.show<void>((_) => const Text('Task'), presentation: presentation),
      );
      await tester.pumpAndSettle();
      expect(prompts.canPrompt, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(prompts.canPrompt, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }
}
