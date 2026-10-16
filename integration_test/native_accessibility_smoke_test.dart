import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_week_picker.dart';

import '../test/support/semantics_update_audit.dart';
import '../test/support/workspace_harness.dart';

class _NativeSemanticsBinding extends IntegrationTestWidgetsFlutterBinding {
  // Keep this audit alive for the entire native runner lifetime. Resetting it
  // between already-mounted trees would lose the bridge's incremental history.
  final audit = SemanticsUpdateAudit();

  // Profile rejects the debug-only client ID -1. Register the test input
  // transport so enterText sends the actual TextInput.setClient ID.
  @override
  bool get registerTestTextInput => true;

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      audit.createBuilder();
}

Finder _key(String value) => find.byKey(ValueKey(value));

String _requiredProbePath() {
  const probe = String.fromEnvironment('SKED_A11Y_PROBE');
  if (probe.isEmpty || !path.isAbsolute(probe)) {
    throw StateError(
      'SKED_A11Y_PROBE must be the absolute path of '
      'probe_native_accessibility.ps1.',
    );
  }
  if (!File(probe).existsSync()) {
    throw StateError('SKED_A11Y_PROBE does not exist: $probe');
  }
  return probe;
}

Future<Map<String, dynamic>> _queryNativeProvider({
  String expectedText = '',
}) async {
  final process = await Process.start('powershell', [
    '-NoProfile',
    '-NonInteractive',
    '-STA',
    '-WindowStyle',
    'Hidden',
    '-File',
    _requiredProbePath(),
    '-TargetProcessId',
    '$pid',
    if (expectedText.isNotEmpty) ...['-ExpectedText', expectedText],
  ]);
  final output = process.stdout.transform(utf8.decoder).join();
  final errors = process.stderr.transform(utf8.decoder).join();
  try {
    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 20),
    );
    final stderr = await errors;
    expect(exitCode, 0, reason: stderr);
    final report = jsonDecode(await output) as Map<String, dynamic>;
    expect(report['nativeApi'], 'MSAA');
    expect(report['processId'], pid);
    return report;
  } finally {
    process.kill();
  }
}

Future<Map<String, dynamic>> _probeNative(
  WidgetTester tester, {
  String expectedText = '',
}) async => (await tester.runAsync(
  () => _queryNativeProvider(expectedText: expectedText),
))!;

List<SemanticsData> _semanticsBelow(SemanticsNode root) {
  final result = <SemanticsData>[];
  void visit(SemanticsNode node) {
    result.add(node.getSemanticsData());
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return result;
}

SemanticsNode? _publishedEditableSemantics(EditableTextState editable) {
  RenderObject? renderObject = editable.renderEditable;
  while (renderObject != null) {
    final node = renderObject.debugSemantics;
    if (node != null && !node.isMergedIntoParent) return node;
    renderObject = renderObject.parent;
  }
  return null;
}

Map<String, Object?> _semanticFields(SemanticsNode? node) {
  if (node == null) return {'present': false};
  final data = node.getSemanticsData();
  return {
    'id': node.id,
    'mergedIntoParent': node.isMergedIntoParent,
    'label': data.label,
    'value': data.value,
    'isTextField': data.flagsCollection.isTextField,
    'isReadOnly': data.flagsCollection.isReadOnly,
    'isFocused': data.flagsCollection.isFocused.toString(),
    'canSetText': data.hasAction(ui.SemanticsAction.setText),
  };
}

Future<void> _enterTextAndCheckSemantics(
  WidgetTester tester,
  Finder field,
  String value,
  List<Map<String, Object?>> diagnostics,
) async {
  final editable = find.descendant(
    of: field,
    matching: find.byType(EditableText),
    matchRoot: true,
  );
  expect(editable, findsOneWidget);
  expect(tester.testTextInput.isRegistered, isTrue);
  await tester.enterText(field, value);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 15),
  );
  final state = tester.state<EditableTextState>(editable);
  final published = _publishedEditableSemantics(state);
  final clientCalls = tester.testTextInput.log.where(
    (call) => call.method == 'TextInput.setClient',
  );
  final clientArguments = clientCalls.isEmpty
      ? null
      : clientCalls.last.arguments as List<dynamic>;
  final clientId = clientArguments?.first;
  final record = <String, Object?>{
    'expectedValue': value,
    'textInputRegistered': tester.testTextInput.isRegistered,
    'textInputHasClient': tester.testTextInput.hasAnyClients,
    'textInputClientId': clientId,
    'controllerValue': state.widget.controller.text,
    'renderedValue': state.renderEditable.text?.toPlainText(),
    'controlNode': _semanticFields(tester.getSemantics(field)),
    'editableNode': _semanticFields(tester.getSemantics(editable)),
    'publishedEditableNode': _semanticFields(published),
  };
  diagnostics.add(record);
  debugPrint('SKED_A11Y_TEXT ${jsonEncode(record)}');
  expect(tester.testTextInput.hasAnyClients, isTrue);
  expect(clientId, isA<int>().having((id) => id, 'client ID', greaterThan(0)));
  expect(state.widget.controller.text, value);
  expect(state.renderEditable.text?.toPlainText(), value);
  expect(published, isNotNull, reason: 'The editor must publish semantics.');
  final data = published!.getSemanticsData();
  expect(data.flagsCollection.isTextField, isTrue);
  expect(data.value, value);
}

Future<void> _waitForNativeSemantics(WidgetTester tester) async {
  final timer = Stopwatch()..start();
  while (!tester.binding.platformDispatcher.semanticsEnabled) {
    if (timer.elapsed > const Duration(seconds: 10)) {
      throw StateError('The Windows provider did not enable engine semantics.');
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
}

int _checkCurrentTree(WidgetTester tester) {
  final root =
      tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
  expect(root, isNotNull, reason: 'The real view must publish semantics.');
  final parents = <int, int?>{};
  final active = <int>{};
  void visit(SemanticsNode node, int? parent) {
    expect(active.contains(node.id), isFalse, reason: 'Semantics cycle.');
    expect(
      parents.containsKey(node.id),
      isFalse,
      reason: 'A semantic node must have one traversal parent.',
    );
    parents[node.id] = parent;
    active.add(node.id);
    node.visitChildren((child) {
      visit(child, node.id);
      return true;
    });
    active.remove(node.id);
  }

  visit(root!, null);
  return parents.length;
}

Future<void> _mouseClick(
  WidgetTester tester,
  TestGesture mouse,
  Finder source,
) async {
  final visible = source.hitTestable();
  expect(visible, findsOneWidget);
  final semantics = _semanticsBelow(tester.getSemantics(visible));
  expect(
    semantics.any((data) => data.hasAction(ui.SemanticsAction.tap)),
    isTrue,
    reason: 'The displayed control must retain its accessible action.',
  );
  await mouse.moveTo(tester.getCenter(visible));
  await mouse.down(tester.getCenter(visible));
  await mouse.up();
}

Future<void> _hover(
  WidgetTester tester,
  TestGesture mouse,
  Finder source,
) async {
  final visible = source.hitTestable();
  expect(visible, findsOneWidget);
  final ancestors = find.ancestor(of: visible, matching: find.byType(Tooltip));
  final descendants = find.descendant(
    of: visible,
    matching: find.byType(Tooltip),
  );
  final tooltip = tester.widget<Tooltip>(
    ancestors.evaluate().isNotEmpty ? ancestors.first : descendants.first,
  );
  final label = tooltip.message ?? tooltip.richMessage!.toPlainText();
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  await mouse.moveTo(Offset(size.width - 2, size.height - 2));
  await tester.pump(const Duration(milliseconds: 300));
  final before = find.text(label).evaluate().length;
  await mouse.moveTo(tester.getCenter(visible));
  await tester.pump(const Duration(milliseconds: 900));
  expect(
    find.text(label).evaluate().length,
    greaterThan(before),
    reason: 'Mouse hover must display the actual tooltip overlay: $label',
  );
}

void main() {
  final binding = _NativeSemanticsBinding();
  final phases = <Map<String, Object?>>[];
  final nativeProbes = <Map<String, dynamic>>[];
  final textSemanticsDiagnostics = <Map<String, Object?>>[];
  final nativeBootstrap = <String, Object?>{};
  var completed = false;

  // The platform owns this handle. Activate before testWidgets records its
  // baseline handle count, so its normal leak check remains meaningful.
  setUpAll(() async {
    _requiredProbePath();
    await DesktopWindowBridge.instance.initialize();
    final previousPolicy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    try {
      runApp(const SizedBox.shrink());
      await binding.endOfFrame;
      nativeBootstrap['engineSemanticsEnabledBefore'] =
          binding.platformDispatcher.semanticsEnabled;
      nativeBootstrap['updatesBefore'] = binding.audit.updateCount;
      final probe = await _queryNativeProvider();
      nativeProbes.add({'phase': 'native-bootstrap', ...probe});
      final timer = Stopwatch()..start();
      while (!binding.platformDispatcher.semanticsEnabled) {
        if (timer.elapsed > const Duration(seconds: 10)) {
          throw StateError(
            'The Windows provider did not enable engine semantics.',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await binding.endOfFrame;
      nativeBootstrap['engineSemanticsEnabledAfter'] =
          binding.platformDispatcher.semanticsEnabled;
      nativeBootstrap['frameworkSemanticsEnabled'] = binding.semanticsEnabled;
      nativeBootstrap['updatesAfter'] = binding.audit.updateCount;
      debugPrint('SKED_A11Y_BOOTSTRAP ${jsonEncode(nativeBootstrap)}');
    } finally {
      binding.framePolicy = previousPolicy;
    }
  });

  testWidgets(
    'native Windows semantics survives real task transitions',
    (tester) async {
      expect(Platform.isWindows, isTrue);
      final probePath = _requiredProbePath();
      await DesktopWindowBridge.instance.initialize();
      expect(DesktopWindowBridge.instance.available, isTrue);
      final logicalSize =
          tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(logicalSize.width, greaterThanOrEqualTo(1100));
      expect(logicalSize.height, greaterThanOrEqualTo(600));
      final layout = DesktopLayoutPreferences.memory();
      final developer = DeveloperUiPreferences.memory();
      final app = await workspaceProvider();
      await app.settingsCommands.updateWorkspacePanelDisplayMode(
        WorkspacePanelDisplayMode.sideBySide,
      );
      await app.studentCommands.setSelectedWeek(2);
      await app.generalNavigation.setSelectedDate(DateTime(2026, 9, 8));
      final originalWeek = app.studentView.selectedWeek;
      final originalDate = app.generalView.selectedDate;
      final originalEvents = app.generalView.schedules
          .expand((calendar) => calendar.events)
          .length;
      expect(app.studentView.hasTimetables, isTrue);
      expect(originalEvents, greaterThan(0));
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      var pointerAdded = false;

      Future<void> phase(String name, Future<void> Function() action) async {
        final before = binding.audit.updateCount;
        final engineEnabledBefore = binding.platformDispatcher.semanticsEnabled;
        debugPrint('SKED_A11Y_PHASE_BEGIN $name updates=$before');
        await action();
        await tester.pumpAndSettle(
          const Duration(milliseconds: 50),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 15),
        );
        final nodes = _checkCurrentTree(tester);
        final record = <String, Object?>{
          'phase': name,
          'updatesBefore': before,
          'updatesAfter': binding.audit.updateCount,
          'reachableNodes': nodes,
          'graphErrors': binding.audit.errors.length,
          'engineSemanticsEnabledBefore': engineEnabledBefore,
          'engineSemanticsEnabledAfter':
              binding.platformDispatcher.semanticsEnabled,
          'frameworkSemanticsEnabled': binding.semanticsEnabled,
        };
        phases.add(record);
        debugPrint('SKED_A11Y_PHASE_END ${jsonEncode(record)}');
        expect(tester.takeException(), isNull, reason: name);
        expect(binding.audit.errors, isEmpty, reason: name);
      }

      try {
        // Activate the native bridge before publishing the populated tree. A
        // Dart-only handle can otherwise emit its first full update too early.
        await tester.pumpWidget(const SizedBox.shrink());
        await phase('activate-native-accessibility-provider', () async {
          nativeProbes.add({
            'phase': 'activate-native-accessibility-provider',
            ...await _probeNative(tester),
          });
          await _waitForNativeSemantics(tester);
        });
        await phase('populated-student-mount', () async {
          await tester.pumpWidget(
            WorkspaceHarness(
              provider: app,
              layoutPreferences: layout,
              developerUiPreferences: developer,
            ),
          );
        });
        expect(binding.semanticsEnabled, isTrue);
        expect(binding.audit.updateCount, greaterThan(0));
        await phase('native-provider-exposes-controls', () async {
          final probe = await _probeNative(tester);
          nativeProbes.add({
            'phase': 'native-provider-exposes-controls',
            ...probe,
          });
          expect(probe['descendants'], greaterThan(0));
          expect(probe['nativeButtons'], greaterThan(0));
        });
        await mouse.addPointer(location: const Offset(8, 100));
        pointerAdded = true;
        await phase(
          'student-navigation-tooltip',
          () => _hover(tester, mouse, _key('student-previous-week')),
        );
        await phase(
          'week-route-open-after-tooltip',
          () => _mouseClick(tester, mouse, _key('student-week-picker-button')),
        );
        expect(find.byType(SkedWeekPicker), findsOneWidget);
        await phase('week-picker-keyboard-escape', () async {
          // Profile strips debug key names used by the simulator's inference.
          await tester.sendKeyEvent(
            LogicalKeyboardKey.tab,
            physicalKey: PhysicalKeyboardKey.tab,
          );
          expect(FocusManager.instance.primaryFocus, isNotNull);
          await tester.sendKeyEvent(
            LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
          );
        });
        expect(find.byType(SkedWeekPicker), findsNothing);
        expect(app.studentView.selectedWeek, originalWeek);

        await phase(
          'workspace-student-to-general',
          () => _mouseClick(
            tester,
            mouse,
            _key('workspace-resource-mode-general'),
          ),
        );
        expect(app.workspaceView.activeMode, AppMode.general);
        await phase(
          'general-date-tooltip',
          () => _hover(tester, mouse, _key('general-date-picker')),
        );
        final dateOwner = ModalRoute.of(
          tester.element(_key('general-date-picker')),
        )!;
        await phase(
          'hovered-date-route-open',
          () => _mouseClick(tester, mouse, _key('general-date-picker')),
        );
        expect(dateOwner.isCurrent, isFalse);
        await phase('date-picker-keyboard-escape', () async {
          await tester.sendKeyEvent(
            LogicalKeyboardKey.escape,
            physicalKey: PhysicalKeyboardKey.escape,
          );
        });
        expect(dateOwner.isCurrent, isTrue);
        expect(app.generalView.selectedDate, originalDate);

        await phase(
          'general-navigation-tooltip',
          () => _hover(tester, mouse, _key('general-next-period')),
        );
        await phase(
          'event-editor-open-after-tooltip',
          () => _mouseClick(tester, mouse, _key('general-add-event')),
        );
        final editor = find.byType(GeneralEventEditorSheet);
        expect(editor, findsOneWidget);
        final editorState = tester.state(editor);
        final title = _key('event-desktop-title');
        const savedTitle = 'Native semantics saved event';
        const discardedTitle = 'Native semantics discarded event';
        final l = AppLocalizations.of(tester.element(editor));

        await phase('event-text-and-keyboard-focus', () async {
          await _enterTextAndCheckSemantics(
            tester,
            title,
            savedTitle,
            textSemanticsDiagnostics,
          );
          final beforeTab = FocusManager.instance.primaryFocus;
          await tester.sendKeyEvent(
            LogicalKeyboardKey.tab,
            physicalKey: PhysicalKeyboardKey.tab,
          );
          await tester.pump();
          expect(FocusManager.instance.primaryFocus, isNot(same(beforeTab)));
        });
        await phase('native-provider-exposes-editor-value', () async {
          final probe = await _probeNative(tester, expectedText: savedTitle);
          nativeProbes.add({
            'phase': 'native-provider-exposes-editor-value',
            ...probe,
          });
          expect(probe['matchedExpectedText'], greaterThan(0));
          expect(probe['matchedEditableValues'], greaterThan(0));
        });
        await phase(
          'draft-workspace-hide',
          () => _mouseClick(
            tester,
            mouse,
            _key('workspace-resource-mode-student'),
          ),
        );
        expect(app.workspaceView.activeMode, AppMode.student);
        expect(editor, findsNothing);
        await phase(
          'draft-workspace-return',
          () => _mouseClick(
            tester,
            mouse,
            _key('workspace-resource-mode-general'),
          ),
        );
        expect(tester.state(editor), same(editorState));
        expect(find.text(savedTitle), findsOneWidget);
        await phase(
          'settings-route-over-draft',
          () => _mouseClick(tester, mouse, _key('workspace-resource-settings')),
        );
        expect(find.byType(SettingsPage), findsOneWidget);
        await phase(
          'settings-route-return',
          () => _mouseClick(tester, mouse, find.byType(BackButton).first),
        );
        expect(tester.state(editor), same(editorState));
        expect(find.text(savedTitle), findsOneWidget);

        Finder cancelEditor() => find.descendant(
          of: editor,
          matching: find.widgetWithText(TextButton, l.cancel),
        );
        await phase(
          'dirty-editor-cancel-opens-confirmation',
          () => _mouseClick(tester, mouse, cancelEditor()),
        );
        expect(find.text(l.unsavedChangesMessage), findsOneWidget);
        await phase('native-provider-exposes-discard-dialog', () async {
          final probe = await _probeNative(
            tester,
            expectedText: l.unsavedChangesMessage,
          );
          nativeProbes.add({
            'phase': 'native-provider-exposes-discard-dialog',
            ...probe,
          });
          expect(probe['matchedExpectedText'], greaterThan(0));
        });
        await phase(
          'cancel-discard-keeps-draft',
          () => _mouseClick(
            tester,
            mouse,
            find.widgetWithText(TextButton, l.cancel).hitTestable().last,
          ),
        );
        expect(tester.state(editor), same(editorState));
        expect(find.text(savedTitle), findsOneWidget);
        expect(
          app.generalView.schedules
              .expand((calendar) => calendar.events)
              .length,
          originalEvents,
        );
        await phase(
          'event-save-commits-and-retires-editor',
          () => _mouseClick(
            tester,
            mouse,
            find.descendant(
              of: editor,
              matching: find.widgetWithText(FilledButton, l.save),
            ),
          ),
        );
        expect(editor, findsNothing);
        expect(
          app.session.committedData.generalMode.schedules
              .expand((calendar) => calendar.events)
              .where((event) => event.title == savedTitle),
          hasLength(1),
        );

        await phase(
          'second-editor-open',
          () => _mouseClick(tester, mouse, _key('general-add-event')),
        );
        await phase(
          'second-editor-draft',
          () => _enterTextAndCheckSemantics(
            tester,
            title,
            discardedTitle,
            textSemanticsDiagnostics,
          ),
        );
        await phase(
          'second-editor-cancel',
          () => _mouseClick(tester, mouse, cancelEditor()),
        );
        expect(find.text(l.unsavedChangesMessage), findsOneWidget);
        await phase(
          'discard-retires-without-saving',
          () => _mouseClick(tester, mouse, find.text(l.discardChangesAndExit)),
        );
        expect(editor, findsNothing);
        final committed = app.session.committedData.generalMode.schedules
            .expand((calendar) => calendar.events);
        expect(committed.length, originalEvents + 1);
        expect(
          committed.any((event) => event.title == discardedTitle),
          isFalse,
        );
        expect(app.studentView.selectedWeek, originalWeek);
        expect(app.generalView.selectedDate, originalDate);
        completed = true;
      } finally {
        try {
          if (pointerAdded) await mouse.removePointer();
          await phase(
            'native-tree-unmount',
            () => tester.pumpWidget(const SizedBox.shrink()),
          );
        } finally {
          try {
            await app.persistence.flushPendingUiStateSaves();
          } finally {
            app.dispose();
            layout.dispose();
            developer.dispose();
            binding.reportData = {
              'nativeAccessibility': {
                'completedInteractions': completed,
                'platform': Platform.operatingSystem,
                'processId': pid,
                'nativeApi': 'MSAA',
                'dart': Platform.version,
                'profile': kProfileMode,
                'revision': const String.fromEnvironment('SKED_A11Y_REVISION'),
                'logicalWidth': logicalSize.width,
                'logicalHeight': logicalSize.height,
                'dpr': tester.view.devicePixelRatio,
                'nativeWorkingDirectory': Directory.current.path,
                'nativeProbePath': probePath,
                'workspacePanelDisplayMode':
                    app.settingsView.workspacePanelDisplayMode.value,
                'semanticsUpdates': binding.audit.updateCount,
                'engineSemanticsEnabled':
                    binding.platformDispatcher.semanticsEnabled,
                'nativeBootstrap': nativeBootstrap,
                'textInputTransport': 'registered-flutter-test-client',
                'textSemanticsDiagnostics': textSemanticsDiagnostics,
                'graphErrors': binding.audit.errors,
                'phases': phases,
                'nativeProbes': nativeProbes,
                'dataIsolation':
                    'WorkspaceHarness memory data, secrets, sites, '
                    'journal, notification runtime, developer and layout preferences',
                'input':
                    'Synthetic Flutter mouse and key events in a native Windows '
                    'runner; actual native semantics serialization remains enabled',
                'nativeLogCheckRequired': true,
              },
            };
          }
        }
      }
    },
    semanticsEnabled: false,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
