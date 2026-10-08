import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/models/workspace_context_snapshot.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/workspace_frame.dart';

class _Editor extends StatefulWidget {
  const _Editor();
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  final draft = TextEditingController();
  @override
  void dispose() {
    draft.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TextField(key: const ValueKey('draft'), controller: draft);
}

void main() {
  test(
    'single-pane reservation is continuous across scaled docking limits',
    () {
      for (final mode in [
        WorkspacePanelDisplayMode.sideBySide,
        WorkspacePanelDisplayMode.automatic,
      ]) {
        for (final width in [1440.0, 1920.0, 2560.0]) {
          for (final scale in [1.0, 1.3, 2.0]) {
            for (final collapsed in [false, true]) {
              for (final minimumCanvas in [600.0, 800.0]) {
                for (final assistant in [false, true]) {
                  WorkbenchLayoutPolicy resolve(double preference) =>
                      WorkbenchLayoutPolicy.resolve(
                        width,
                        scale,
                        detailOpen: !assistant,
                        assistantOpen: assistant,
                        hasSupporting: true,
                        pointer: true,
                        resourcesCollapsed: collapsed,
                        panelDisplayMode: mode,
                        minimumCanvas: minimumCanvas,
                        preferredDetailWidth: preference,
                        preferredAssistantWidth: preference,
                      );
                  final base = resolve(400);
                  final content =
                      width - (base.resources ? base.resourceWidth + 1 : 0);
                  final floor =
                      (mode == WorkspacePanelDisplayMode.sideBySide
                          ? 360
                          : minimumCanvas) *
                      scale;
                  final boundary = (content - floor - 1) / scale;
                  final maximum =
                      (assistant
                          ? base.maximumAssistantWidth
                          : base.maximumDetailWidth) /
                      scale;
                  if (boundary <= 400 || boundary + 1 >= maximum) continue;
                  final before = resolve(boundary - 1);
                  final after = resolve(boundary + 1);
                  expect(before.dockedAssistant || before.dockedDetail, isTrue);
                  expect(after.dockedAssistant || after.dockedDetail, isFalse);
                  expect(
                    after.canvasEndInset - before.canvasEndInset,
                    closeTo(scale, .00001),
                  );
                  expect(
                    content - after.canvasEndInset,
                    closeTo(floor, .00001),
                  );
                  expect(after.supporting, isFalse);
                  expect(after.resourceWidth, before.resourceWidth);
                  expect(after.resources, before.resources);
                }
              }
            }
          }
        }
      }
    },
  );

  for (final mode in [
    WorkspacePanelDisplayMode.sideBySide,
    WorkspacePanelDisplayMode.automatic,
  ]) {
    test(
      'two-pane reservation stays continuous and releases on close: $mode',
      () {
        for (final scale in [1.0, 1.3, 2.0]) {
          for (final collapsed in [false, true]) {
            for (final minimumCanvas in [600.0, 736.0, 800.0]) {
              for (final resizeAssistant in [false, true]) {
                final width =
                    (mode == WorkspacePanelDisplayMode.automatic
                        ? 1920.0
                        : 1440.0) *
                    scale;
                WorkbenchLayoutPolicy resolve(
                  double preference, {
                  bool detailOpen = true,
                  bool assistantOpen = true,
                  bool? assistantActive,
                }) => WorkbenchLayoutPolicy.resolve(
                  width,
                  scale,
                  detailOpen: detailOpen,
                  assistantOpen: assistantOpen,
                  assistantActive: assistantActive ?? resizeAssistant,
                  hasSupporting: true,
                  pointer: true,
                  resourcesCollapsed: collapsed,
                  panelDisplayMode: mode,
                  minimumCanvas: minimumCanvas,
                  preferredDetailWidth: resizeAssistant ? 360 : preference,
                  preferredAssistantWidth: resizeAssistant ? preference : 400,
                );
                final base = resolve(resizeAssistant ? 400 : 360);
                final content =
                    width - (base.resources ? base.resourceWidth + 1 : 0);
                final floor =
                    (mode == WorkspacePanelDisplayMode.sideBySide
                        ? 360
                        : minimumCanvas) *
                    scale;
                final peerWidth = resizeAssistant
                    ? base.detailWidth
                    : base.assistantWidth;
                final boundary = (content - floor - peerWidth - 2) / scale;
                final before = resolve(boundary - 1);
                final after = resolve(boundary + 1);
                expect(before.dockedDetail && before.dockedAssistant, isTrue);
                expect(after.detailVisible, !resizeAssistant);
                expect(after.assistantVisible, resizeAssistant);
                expect(content - after.canvasEndInset, closeTo(floor, .00001));

                final preferences = [
                  for (var offset = -24; offset <= 24; offset++)
                    boundary + offset,
                ];
                for (final widening in [true, false]) {
                  final sequence = widening
                      ? preferences
                      : preferences.reversed;
                  var previous = resolve(sequence.first);
                  for (final preference in sequence.skip(1)) {
                    final current = resolve(preference);
                    final reservedDelta =
                        current.canvasEndInset - previous.canvasEndInset;
                    expect(
                      widening ? reservedDelta : -reservedDelta,
                      inInclusiveRange(-.00001, scale + .00001),
                      reason: 'Hiding an open peer must not release its calendar budget.',
                    );
                    expect(
                      current.resourcePresentation,
                      base.resourcePresentation,
                    );
                    expect(current.resourceWidth, base.resourceWidth);
                    expect(
                      content - current.canvasEndInset,
                      greaterThanOrEqualTo(floor - .00001),
                    );
                    previous = current;
                  }
                }

                final hiddenPeer = resolve(boundary + 24);
                final otherActive = resolve(
                  boundary + 24,
                  assistantActive: !resizeAssistant,
                );
                expect(otherActive.canvasEndInset, hiddenPeer.canvasEndInset);
                final peerClosed = resolve(
                  boundary + 24,
                  detailOpen: !resizeAssistant,
                  assistantOpen: resizeAssistant,
                );
                final remainingWidth = resizeAssistant
                    ? peerClosed.assistantWidth
                    : peerClosed.detailWidth;
                expect(
                  peerClosed.canvasEndInset,
                  closeTo(remainingWidth + 1, .00001),
                );
                expect(
                  peerClosed.canvasEndInset,
                  lessThan(hiddenPeer.canvasEndInset),
                );
                final allClosed = resolve(
                  boundary + 24,
                  detailOpen: false,
                  assistantOpen: false,
                );
                expect(allClosed.supporting, isTrue);
                expect(allClosed.canvasEndInset, allClosed.supportingWidth + 1);
              }
            }
          }
        }
      },
    );
  }

  test('panel upper bounds use four fifths of the work area and preserve narrow defaults', () {
    for (final width in [320.0, 393.0, 600.0, 900.0, 1440.0, 1920.0, 2560.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final collapsed in [false, true]) {
          for (final supporting in [false, true]) {
            for (final mode in WorkspacePanelDisplayMode.values) {
              final base = WorkspaceLayout.resolve(
                width,
                scale,
                detailOpen: false,
                hasSupporting: supporting,
                pointer: true,
                resourcesCollapsed: collapsed,
                panelDisplayMode: mode,
              );
              final resized = WorkspaceLayout.resolve(
                width,
                scale,
                detailOpen: true,
                assistantOpen: true,
                hasSupporting: supporting,
                pointer: true,
                resourcesCollapsed: collapsed,
                panelDisplayMode: mode,
                preferredDetailWidth: 10000,
                preferredAssistantWidth: 10000,
              );
              final content =
                  width - (base.resources ? base.resourceWidth + 1 : 0);
              final maxDetail = math.min(
                content,
                math.max(360 * scale, content * .8),
              );
              final maxAssistant = math.min(
                content,
                math.max(400 * scale, content * .8),
              );
              expect(resized.detailWidth, closeTo(maxDetail, .0001));
              expect(resized.assistantWidth, closeTo(maxAssistant, .0001));
              expect(resized.maximumDetailWidth, closeTo(maxDetail, .0001));
              expect(
                resized.maximumAssistantWidth,
                closeTo(maxAssistant, .0001),
              );
              expect(resized.resources, base.resources);
              expect(resized.resourceWidth, base.resourceWidth);
              expect(
                base.detailWidth,
                closeTo(math.min(content, 360 * scale), .0001),
              );
              expect(
                base.assistantWidth,
                closeTo(math.min(content, 400 * scale), .0001),
              );
              if (mode == WorkspacePanelDisplayMode.overlay) {
                expect(resized.supporting, base.supporting);
              }
            }
          }
        }
      }
    }
  });

  test(
    'assistant remembers wide preferences while layout owns the maximum',
    () {
      final assistant = AssistantPaneController();
      addTearDown(assistant.dispose);
      var notifications = 0;
      assistant.addListener(() => notifications++);
      assistant.resize(1400);
      expect(assistant.width, 1400);
      expect(notifications, 1);
      assistant.resize(1400);
      assistant.resize(double.nan);
      assistant.resize(double.infinity);
      expect(assistant.width, 1400);
      expect(notifications, 1);
      assistant.resize(10);
      expect(assistant.width, 360);
      expect(notifications, 2);
    },
  );

  test('task modes preserve the base sidebar and their calendar budgets', () {
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
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final canvas in [600.0, 800.0]) {
          for (final mode in WorkspacePanelDisplayMode.values) {
            for (final pointer in [false, true]) {
              for (final collapsed in [false, true]) {
                final base = WorkbenchLayoutPolicy.resolve(
                  width,
                  scale,
                  detailOpen: false,
                  hasSupporting: true,
                  minimumCanvas: canvas,
                  pointer: pointer,
                  resourcesCollapsed: collapsed,
                  panelDisplayMode: mode,
                );
                for (final detail in [false, true]) {
                  for (final assistant in [false, true]) {
                    for (final assistantActive in [false, true]) {
                      final p = WorkbenchLayoutPolicy.resolve(
                        width,
                        scale,
                        detailOpen: detail,
                        assistantOpen: assistant,
                        assistantActive: assistantActive,
                        hasSupporting: true,
                        minimumCanvas: canvas,
                        pointer: pointer,
                        resourcesCollapsed: collapsed,
                        panelDisplayMode: mode,
                      );
                      expect(p.resources, base.resources);
                      expect(p.resourceWidth, base.resourceWidth);
                      final side =
                          (p.resources ? p.resourceWidth + 1 : 0) +
                          p.canvasEndInset;
                      // Navigation can remain compact below the content
                      // preference; only docked task reservations promise it.
                      if (p.canvasEndInset > 0) {
                        expect(
                          width - side,
                          greaterThanOrEqualTo(p.minimumCanvasWidth - .000001),
                        );
                      }
                      expect(
                        p.supporting && (p.dockedDetail || p.dockedAssistant),
                        isFalse,
                      );
                      if (p.detailVisible && p.assistantVisible) {
                        expect(p.dockedDetail && p.dockedAssistant, isTrue);
                      }
                      final content =
                          width - (p.resources ? p.resourceWidth + 1 : 0);
                      expect(p.detailWidth, lessThanOrEqualTo(content));
                      expect(p.assistantWidth, lessThanOrEqualTo(content));
                      if (mode == WorkspacePanelDisplayMode.overlay) {
                        expect(p.dockedDetail || p.dockedAssistant, isFalse);
                        expect(p.supporting, base.supporting);
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  });
  test('portrait tablet settings split while the week canvas stays single', () {
    expect(WorkbenchLayoutPolicy.formCanSplit(800, 1), isTrue);
    expect(WorkbenchLayoutPolicy.formCanSplit(800, 1.3), isFalse);
    expect(
      WorkbenchLayoutPolicy.resolve(
        800,
        1,
        minimumCanvas: 800,
        detailOpen: false,
        hasSupporting: false,
      ).resources,
      isFalse,
    );
    final wide = WorkbenchLayoutPolicy.resolve(
      1920,
      1,
      panelDisplayMode: WorkspacePanelDisplayMode.automatic,
      minimumCanvas: 800,
      detailOpen: true,
      hasSupporting: false,
      assistantOpen: true,
    );
    expect(
      [wide.resources, wide.dockedDetail, wide.dockedAssistant],
      [true, true, true],
    );
    final medium = WorkbenchLayoutPolicy.resolve(
      1280,
      1,
      panelDisplayMode: WorkspacePanelDisplayMode.automatic,
      minimumCanvas: 800,
      detailOpen: true,
      hasSupporting: false,
      assistantOpen: true,
    );
    expect(medium.resources, isTrue);
    expect(medium.dockedDetail, isFalse);
    expect(medium.dockedAssistant, isFalse);
    expect(medium.detailVisible, isTrue);
    expect(medium.assistantVisible, isFalse);
  });
  test(
    'assistant context is immutable and cannot expose a disabled workspace',
    () {
      final enabled = {AppMode.general};
      final snapshot = WorkspaceContextSnapshot(
        enabledWorkspaces: enabled,
        mode: AppMode.general,
        view: 'week',
        date: DateTime(2026, 9, 8),
      );
      enabled.add(AppMode.student);
      expect(snapshot.enabledWorkspaces, {AppMode.general});
      expect(() => snapshot.enabledWorkspaces.clear(), throwsUnsupportedError);
      expect(snapshot.withSelection('event').selectionId, 'event');
      expect(
        () => WorkspaceContextSnapshot(
          enabledWorkspaces: {AppMode.general},
          mode: AppMode.student,
          view: 'week',
        ),
        throwsArgumentError,
      );
    },
  );
  testWidgets(
    'independent editor and assistant survive rotation, keyboard and overlay focus',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      final pane = WorkspacePaneController();
      final assistant = AssistantPaneController();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: WorkspaceFrame(
              controller: pane,
              assistantController: assistant,
              assistantPreview: true,
              panelDisplayMode: WorkspacePanelDisplayMode.automatic,
              minimumCanvas: 800,
              contextSnapshot: WorkspaceContextSnapshot(
                enabledWorkspaces: {AppMode.general},
                mode: AppMode.general,
                view: 'week',
              ),
              resources: const Text('Resources'),
              canvas: Column(
                children: [
                  const AssistantPaneToggle(),
                  TextButton(
                    onPressed: () => pane.show<void>(
                      (_) => const _Editor(),
                      selectionId: 'event',
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      final original = tester.state<_EditorState>(find.byType(_Editor));
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'Retained event',
      );
      await tester.tap(find.byKey(const ValueKey('assistant-toggle')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('assistant-draft')),
        'Retained conversation',
      );
      expect(find.byType(_Editor), findsOneWidget);
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      tester.view.physicalSize = const Size(800, 1280);
      await tester.pumpAndSettle();
      expect(find.byType(_Editor), findsNothing);
      expect(original.draft.text, 'Retained event');
      expect(pane.focusScope.descendantsAreFocusable, isFalse);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(assistant.isOpen, isFalse);
      expect(find.byType(_Editor), findsOneWidget);
      expect(tester.state<_EditorState>(find.byType(_Editor)), same(original));
      await tester.enterText(
        find.byKey(const ValueKey('draft')),
        'Still editable',
      );
      tester.view.resetViewInsets();
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpAndSettle();
      assistant.setOpen(true);
      await tester.pumpAndSettle();
      expect(assistant.draft.text, 'Retained conversation');
      assistant.resize(450);
      await tester.pumpAndSettle();
      expect(assistant.width, 450);
      final handles = find.bySemanticsLabel('Resize panel');
      expect(tester.getSize(handles.first), const Size(48, 48));
      final beforeResize = tester.getSize(find.byType(_Editor)).width;
      await tester.drag(handles.first, const Offset(-36, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(_Editor)).width,
        greaterThan(beforeResize),
      );
      final mouse = find
          .descendant(of: handles.first, matching: find.byType(MouseRegion))
          .first;
      Focus.of(tester.element(mouse)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      await pane.close();
      await tester.pumpAndSettle();
      expect(find.byType(_Editor), findsNothing);
      expect(find.byType(AssistantPreviewPane), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      pane.dispose();
      assistant.dispose();
    },
  );
  testWidgets('production frame has no AI placeholder or entry', (
    tester,
  ) async {
    final pane = WorkspacePaneController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkspaceFrame(
            controller: pane,
            assistantPreview: false,
            resources: const SizedBox(),
            canvas: const AssistantPaneToggle(),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('assistant-toggle')), findsNothing);
    expect(find.byType(AssistantPreviewPane), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    pane.dispose();
  });
}
