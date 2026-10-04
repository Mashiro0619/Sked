import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_drag_guard.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));

class _SaveStorage extends WorkspaceMemoryStorage {
  _SaveStorage(super.data);
  Completer<void>? gate;
  @override
  Future<void> save(AppData value) async {
    await gate?.future;
    await super.save(value);
  }
}

void main() {
  const channel = MethodChannel('com.mashiro.sked/window');
  final commands = <String>[];
  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          commands.add(call.method);
          return call.method == 'initialize'
              ? {'maximized': false, 'focused': true}
              : null;
        });
    await DesktopWindowBridge.instance.initialize();
    debugDefaultTargetPlatformOverride = null;
    commands.clear();
  });
  tearDown(() {
    DesktopWindowBridge.instance.available = false;
    DesktopWindowBridge.instance.prepareClose = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> drag(WidgetTester t, Offset from) async {
    commands.clear();
    await t.dragFrom(from, const Offset(60, 10), kind: PointerDeviceKind.mouse);
    await t.pump();
  }

  for (final mode in AppMode.values) {
    testWidgets(
      'floating $mode editor preserves native blank caption gestures without background input',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(1440, 1000);
        addTearDown(t.view.reset);
        final p = await workspaceProvider(mode: mode);
        addTearDown(p.dispose);
        await t.pumpWidget(WorkspaceHarness(provider: p));
        await t.pumpAndSettle();
        final trigger = k(
          mode == AppMode.general ? 'general-add-event' : 'student-add-course',
        );
        final buttonPoint = t.getCenter(trigger);
        await t.tap(trigger);
        await t.pumpAndSettle();
        final editor = find.byType(
          mode == AppMode.general ? GeneralEventEditorSheet : CourseEditorSheet,
        );
        final element = t.element(editor);
        final owner = DesktopWindowDragScope.maybeOf(element)!;
        expect(owner.protectsEditor, isTrue);
        final toolbar = t.getRect(
          k(
            mode == AppMode.general
                ? 'general-workspace-toolbar'
                : 'student-workspace-toolbar',
          ),
        );
        final blank = [
          for (double x = toolbar.left + 4; x < 1260; x += 8)
            Offset(x, toolbar.center.dy),
        ].firstWhere(owner.canDrag);
        await drag(t, blank);
        expect(commands.where((c) => c == 'startDrag'), hasLength(1));
        expect(t.element(editor), same(element));
        await drag(t, buttonPoint);
        expect(commands, isNot(contains('startDrag')));
        await t.tapAt(buttonPoint, kind: PointerDeviceKind.mouse);
        await t.pumpAndSettle();
        expect(t.element(editor), same(element));
        expect(p.activeMode, mode);
        await t.pump(const Duration(milliseconds: 350));
        commands.clear();
        await t.tapAt(blank, kind: PointerDeviceKind.mouse);
        await t.pump(const Duration(milliseconds: 70));
        await t.tapAt(blank, kind: PointerDeviceKind.mouse);
        await t.pumpAndSettle();
        expect(commands.where((c) => c == 'toggleMaximize'), hasLength(1));
        commands.clear();
        final mouse = await t.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await mouse.down(blank);
        await mouse.up();
        await t.pump();
        expect(commands, contains('systemMenu'));
        await drag(t, const Offset(620, 880));
        expect(commands, isNot(contains('startDrag')));
        await drag(t, t.getCenter(k('workspace-editor-drag')));
        expect(commands, isNot(contains('startDrag')));
        final input = find
            .descendant(of: editor, matching: find.byType(TextField))
            .first;
        await t.enterText(input, 'Keep this draft');
        await t.pumpAndSettle();
        await t.tap(k('workspace-editor-close'));
        await t.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await drag(t, blank);
        expect(commands.where((c) => c == 'startDrag'), hasLength(1));
        await t.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await t.pumpAndSettle();
        if (mode == AppMode.general) {
          await drag(t, t.getCenter(find.byTooltip('Pick date').first));
          expect(commands, isNot(contains('startDrag')));
          await t.tap(find.byTooltip('Pick date').first);
          await t.pumpAndSettle();
          await drag(t, blank);
          expect(commands.where((c) => c == 'startDrag'), hasLength(1));
          await t.sendKeyEvent(LogicalKeyboardKey.escape);
          await t.pumpAndSettle();
        }
        await t.tap(k('workspace-editor-close'));
        await t.pumpAndSettle();
        await t.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(FilledButton),
          ),
        );
        await t.pumpAndSettle();
        expect(owner.protectsEditor, isFalse);
        await drag(t, blank);
        expect(commands.where((c) => c == 'startDrag'), hasLength(1));
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets(
    'saving retains window drag through resize and releases the guard only on completion',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1440, 1000);
      addTearDown(t.view.reset);
      final seed = await workspaceProvider(mode: AppMode.general);
      final storage = _SaveStorage(seed.appData);
      seed.dispose();
      final p = await workspaceProvider(
        mode: AppMode.general,
        storage: storage,
      );
      addTearDown(p.dispose);
      await t.pumpWidget(WorkspaceHarness(provider: p));
      await t.pumpAndSettle();
      await t.tap(k('general-add-event'));
      await t.pumpAndSettle();
      final editor = find.byType(GeneralEventEditorSheet);
      final element = t.element(editor);
      final owner = DesktopWindowDragScope.maybeOf(element)!;
      await t.enterText(
        find.descendant(of: editor, matching: find.byType(TextField)).first,
        'Saved during drag',
      );
      final gate = storage.gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      await t.tap(find.widgetWithText(FilledButton, 'Save'));
      await t.pump();
      for (final size in [const Size(1440, 1000), const Size(900, 700)]) {
        t.view.physicalSize = size;
        await t.pump(const Duration(milliseconds: 400));
        await t.pump();
        final toolbar = t.getRect(k('general-workspace-toolbar'));
        final blank = [
          for (double x = toolbar.left + 4; x < size.width - 138; x += 8)
            Offset(x, toolbar.center.dy),
        ].firstWhere(owner.canDrag);
        await drag(t, blank);
        expect(commands.where((c) => c == 'startDrag'), hasLength(1));
        expect(t.element(editor), same(element));
        expect(
          t.widget<IconButton>(k('workspace-editor-close')).onPressed,
          isNull,
        );
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        await t.pump();
        expect(editor, findsOneWidget);
      }
      gate.complete();
      await t.pumpAndSettle();
      expect(editor, findsNothing);
      expect(owner.protectsEditor, isFalse);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'registry rejects controls, hidden and detached areas and removed leases',
    (t) async {
      final controller = DesktopWindowDragController();
      addTearDown(controller.dispose);
      bool active = true, hidden = false;
      late StateSetter update;
      var clicks = 0;
      await t.pumpWidget(
        MaterialApp(
          home: DesktopWindowDragScope(
            controller: controller,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return DesktopEditorWindowGuard(
                  active: active,
                  child: Scaffold(
                    body: Offstage(
                      offstage: hidden,
                      child: SizedBox(
                        width: 400,
                        height: 48,
                        child: DesktopDragRegion(
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () => clicks++,
                                child: const Text('Button'),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(controller.canDrag(const Offset(250, 24)), isTrue);
      expect(controller.canDrag(t.getCenter(find.byType(TextButton))), isFalse);
      expect(clicks, 0);
      update(() => hidden = true);
      await t.pumpAndSettle();
      expect(controller.canDrag(const Offset(250, 24)), isFalse);
      update(() {
        hidden = false;
        active = false;
      });
      await t.pumpAndSettle();
      expect(controller.protectsEditor, isFalse);
      update(() => active = true);
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      expect(controller.protectsEditor, isFalse);
      expect(controller.canDrag(const Offset(250, 24)), isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
