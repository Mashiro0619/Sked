import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/assistant_pane.dart';
import 'package:sked/widgets/workspace_frame.dart';

import '../support/workspace_harness.dart';

Finder _key(String key) => find.byKey(ValueKey(key));
Rect _calendarRect(WidgetTester t) =>
    t.getRect(_key('workspace-canvas-viewport'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.mashiro.sked/window');
  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => call.method == 'initialize'
              ? {'maximized': false, 'focused': true}
              : null,
        );
    await DesktopWindowBridge.instance.initialize();
  });
  tearDown(() {
    DesktopWindowBridge.instance.available = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final workspace in AppMode.values) {
    for (final mode in WorkspacePanelDisplayMode.values) {
      for (final (scale, collapsed) in [
        (1.0, false),
        (1.3, true),
        (2.0, false),
      ]) {
        testWidgets(
          'real $workspace $mode resizing keeps commands fixed and calendar continuous: scale=$scale collapsed=$collapsed',
          (t) async {
            final width =
                (mode == WorkspacePanelDisplayMode.automatic
                    ? 1920.0
                    : 1440.0) *
                scale;
            t.view.devicePixelRatio = 1;
            t.view.physicalSize = Size(width, 1100);
            addTearDown(t.view.resetPhysicalSize);
            addTearDown(t.view.resetDevicePixelRatio);
            final p = await workspaceProvider(mode: workspace);
            addTearDown(p.dispose);
            await p.updateWorkspacePanelDisplayMode(mode);
            await p.updateHomeWorkspaceNavigationCollapsed(collapsed);
            if (workspace == AppMode.general) {
              await p.setSelectedGeneralDate(DateTime(2026, 9, 8));
            }
            final preferences = DeveloperUiPreferences.memory(visible: true);
            addTearDown(preferences.dispose);
            await t.pumpWidget(
              WorkspaceHarness(
                provider: p,
                developerUiPreferences: preferences,
                textScale: scale,
              ),
            );
            await t.pumpAndSettle();
            await t.tap(_key('assistant-toggle'));
            await t.pumpAndSettle();
            final toolbarKey = workspace == AppMode.general
                ? 'general-workspace-toolbar'
                : 'student-workspace-toolbar';
            final toolbar = t.getRect(_key(toolbarKey));
            final sidebar = t.getRect(_key('workspace-resource-width'));
            final calendar = _calendarRect(t);
            final day = workspace == AppMode.general
                ? _key('general-week-day-header-2026-09-07T00:00:00.000')
                : _key('timetable-day-column-1').first;
            final commands = {
              for (final key
                  in workspace == AppMode.general
                      ? [
                          'general-view-switcher',
                          'general-day-agenda-toggle',
                          'assistant-toggle',
                          'general-add-event',
                        ]
                      : [
                          'student-today',
                          'student-view-toggle',
                          'assistant-toggle',
                        ])
                key: t.getRect(_key(key)),
            };
            void expectStableCommands() {
              expect(t.getRect(_key(toolbarKey)), toolbar);
              expect(t.getRect(_key('workspace-resource-width')), sidebar);
              for (final entry in commands.entries) {
                expect(_key(entry.key), findsOneWidget);
                expect(t.getRect(_key(entry.key)), entry.value);
                expect(_key(entry.key).hitTestable(), findsOneWidget);
              }
              expect(find.byType(FloatingActionButton), findsNothing);
              if (find.byType(AssistantPreviewPane).evaluate().isNotEmpty) {
                expect(
                  t.getRect(_key('workspace-assistant-pane')).top,
                  toolbar.bottom,
                  reason: 'Calendar spacing must not leave a gap above the AI panel.',
                );
                expect(
                  t.getRect(_key('workspace-assistant-resize')).top,
                  toolbar.bottom,
                );
              }
            }

            await t.tap(_key('assistant-toggle'));
            await t.pumpAndSettle();
            expectStableCommands();
            await t.enterText(
              _key('assistant-draft'),
              'Keep this draft while resizing',
            );
            final pane = t
                .widget<AssistantPreviewPane>(find.byType(AssistantPreviewPane))
                .controller;
            final frame = t.widget<WorkspaceFrame>(find.byType(WorkspaceFrame));
            final floor =
                (mode == WorkspacePanelDisplayMode.sideBySide
                    ? 360.0
                    : frame.minimumCanvas) *
                scale;
            var previous = _calendarRect(t);
            var previousDay = t.getRect(day);
            final gesture = await t.startGesture(
              t.getCenter(_key('workspace-assistant-resize')),
              kind: PointerDeviceKind.mouse,
            );
            try {
              for (var i = 0; i < 85; i++) {
                await gesture.moveBy(Offset(-16 * scale, 0));
                await t.pump();
                expectStableCommands();
                final next = _calendarRect(t);
                expect(next.left, calendar.left);
                expect(next.top, calendar.top);
                expect(
                  next.width,
                  lessThanOrEqualTo(previous.width + .01),
                  reason: 'Crossing the docking threshold must not spring the calendar back to full width.',
                );
                expect(
                  (previous.width - next.width).abs(),
                  lessThanOrEqualTo(32 * scale + .01),
                );
                final nextDay = t.getRect(day);
                expect(
                  nextDay.width,
                  lessThanOrEqualTo(previousDay.width + .01),
                );
                if ((next.width - previous.width).abs() < .01) {
                  expect(nextDay, previousDay);
                }
                previousDay = nextDay;
                if (mode == WorkspacePanelDisplayMode.overlay) {
                  expect(next, calendar);
                } else {
                  expect(next.width, greaterThanOrEqualTo(floor - .01));
                }
                previous = next;
              }
              expect(
                t.getSize(_key('workspace-assistant-pane')).width,
                closeTo((width - sidebar.width - 1) * .8, .01),
              );
              // Reverse without releasing the pointer, including at the cap.
              for (var i = 0; i < 70; i++) {
                await gesture.moveBy(Offset(16 * scale, 0));
                await t.pump();
                expectStableCommands();
                final next = _calendarRect(t);
                expect(next.width, greaterThanOrEqualTo(previous.width - .01));
                expect(
                  (next.width - previous.width).abs(),
                  lessThanOrEqualTo(16 * scale + .01),
                );
                if (mode == WorkspacePanelDisplayMode.overlay) {
                  expect(next, calendar);
                }
                previous = next;
              }
            } finally {
              await gesture.up();
            }
            await t.pumpAndSettle();
            expect(_calendarRect(t), previous);
            expectStableCommands();
            expect(pane.draft.text, 'Keep this draft while resizing');
            await t.tap(_key('assistant-toggle'));
            await t.pumpAndSettle();
            expect(_calendarRect(t), calendar);
            expectStableCommands();
            expect(p.workspacePanelDisplayMode, mode);
            expect(t.takeException(), isNull);
            await t.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }
    }
  }
}
