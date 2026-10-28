import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/widgets/desktop_window_drag_guard.dart';
import 'package:sked/widgets/sked_popup_menu.dart';
import 'package:sked/widgets/workbench_chrome_metrics.dart';

import '../test/support/workspace_harness.dart';
import 'support/capture_output_directory.dart';

class _MenuStorage extends WorkspaceMemoryStorage {
  _MenuStorage(super.data);

  var writes = 0;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

class _MenuScene {
  const _MenuScene(this.name, this.mode, this.size, {this.compact = false});

  final String name;
  final AppMode mode;
  final Size size;
  final bool compact;

  String get triggerKey => compact
      ? '${mode.value}-desktop-toolbar-more'
      : mode == AppMode.student
      ? 'student-view-toggle'
      : 'general-view-switcher';

  Finder choice(String value, String label) => compact
      ? find.byKey(ValueKey('${mode.value}-view-choice-$value'))
      : find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is SkedPopupMenuItem,
          ),
        );
}

Map<String, double> _point(Offset point) => {'x': point.dx, 'y': point.dy};
Map<String, double> _rect(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'width': rect.width,
  'height': rect.height,
};

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'workspace menus survive real Win32 caption dragging without selecting or saving',
    (tester) async {
      if (!Platform.isWindows) {
        throw UnsupportedError('This regression requires the Windows engine.');
      }
      final output = createCaptureOutputDirectory(label: 'menu-window-drag');
      final evidenceFile = File('${output.path}/evidence.json');
      if (await evidenceFile.exists()) {
        throw StateError(
          'Preserve the existing evidence: ${evidenceFile.path}',
        );
      }
      await output.create(recursive: true);
      final evidence = <Map<String, dynamic>>[];
      final previousPointerPropagation =
          binding.shouldPropagateDevicePointerEvents;
      // Only native drag gestures are injected into the desktop. Opening menus
      // and Escape target this test's Flutter tree directly.
      binding.shouldPropagateDevicePointerEvents = true;
      const chrome = WorkbenchChromeMetrics(desktop: true, textScale: 1);
      const waitForForeground = bool.fromEnvironment(
        'SKED_MENU_DRAG_WAIT_FOR_FOREGROUND',
        defaultValue: false,
      );
      var foregroundWaitPending = waitForForeground;
      var completed = false;
      String? failure;

      Future<Map<String, dynamic>> window(
        _MenuScene scene,
        String action, {
        Offset? point,
        Offset? endPoint,
        String? capture,
        Size? size,
      }) async {
        final captureFile = capture == null
            ? null
            : File('${output.path}/${scene.name}-$capture.png');
        if (captureFile != null && await captureFile.exists()) {
          throw StateError(
            'Preserve the existing capture: ${captureFile.path}',
          );
        }
        final result = await tester.runAsync(
          () => Process.run('powershell', [
            '-NoProfile',
            '-WindowStyle',
            'Hidden',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            File('tool/capture_workbench_window.ps1').absolute.path,
            '-ProcessId',
            '$pid',
            '-Action',
            action,
            '-WidthDp',
            '${(size ?? scene.size).width}',
            '-HeightDp',
            '${(size ?? scene.size).height}',
            '-CaptionHeightDp',
            '${chrome.toolbarHeight}',
            '-CaptionButtonWidthDp',
            '${chrome.captionButtonWidth}',
            if (point != null) ...[
              '-PointXDp',
              '${point.dx}',
              '-PointYDp',
              '${point.dy}',
            ],
            if (endPoint != null) ...[
              '-EndPointXDp',
              '${endPoint.dx}',
              '-EndPointYDp',
              '${endPoint.dy}',
            ],
            if (captureFile != null) ...['-OutputPath', captureFile.path],
          ]),
        );
        if (result!.exitCode != 0) {
          evidence.add({
            'case': scene.name,
            'action': action,
            'processId': pid,
            'exitCode': result.exitCode,
            'stderr': '${result.stderr}',
          });
        }
        expect(result.exitCode, 0, reason: '${result.stderr}');
        final report =
            jsonDecode('${result.stdout}'.trim()) as Map<String, dynamic>;
        evidence.add({
          ...report,
          'case': scene.name,
          'processId': pid,
          if (point != null) 'pointDp': _point(point),
          if (endPoint != null) 'endPointDp': _point(endPoint),
          'capture': ?capture,
        });
        return report;
      }

      Future<void> awaitForeground(_MenuScene scene) async {
        final elapsed = Stopwatch()..start();
        debugPrint(
          'Waiting up to 60 seconds for test window PID $pid to gain foreground focus.',
        );
        while (elapsed.elapsedMilliseconds < 60000) {
          final pollStarted = elapsed.elapsedMilliseconds;
          final state = await window(scene, 'inspect');
          if (state['foregroundIsApp'] == true) {
            evidence.add({
              'case': scene.name,
              'action': 'foreground-ready',
              'waitedMs': elapsed.elapsedMilliseconds,
            });
            return;
          }
          final remaining = 60000 - elapsed.elapsedMilliseconds;
          if (remaining <= 0) break;
          final delay = (1500 - (elapsed.elapsedMilliseconds - pollStarted))
              .clamp(0, remaining)
              .toInt();
          if (delay > 0) {
            await tester.runAsync(
              () => Future<void>.delayed(Duration(milliseconds: delay)),
            );
          }
          await tester.pump();
        }
        fail(
          'Test window PID $pid did not gain foreground focus within 60 seconds.',
        );
      }

      try {
        await DesktopWindowBridge.instance.initialize();
        expect(DesktopWindowBridge.instance.available, isTrue);
        for (final scene in const [
          _MenuScene('student-wide', AppMode.student, Size(1280, 800)),
          _MenuScene(
            'student-narrow-more',
            AppMode.student,
            Size(520, 800),
            compact: true,
          ),
          _MenuScene('general-wide', AppMode.general, Size(1280, 800)),
        ]) {
          // Data and preferences remain in memory; native commands identify only
          // this integration test process and never find a user app by its name.
          final sample = DeveloperSampleDataService.append(
            current: buildInitialAppData(
              buildDefaultPeriodTimes(),
              localeCode: 'zh',
            ),
            language: DeveloperSampleLanguage.simplifiedChinese,
            now: DateTime(2026, 9, 8, 9),
          ).data;
          final storage = _MenuStorage(
            sample.copyWith(
              activeMode: scene.mode,
              generalMode: sample.generalMode.copyWith(
                defaultView: generalViewWeek,
              ),
            ),
          );
          final provider = await workspaceProvider(
            mode: scene.mode,
            locale: 'zh',
            storage: storage,
          );
          try {
            if (scene.mode == AppMode.student) {
              await provider.studentCommands.setSelectedWeek(1);
            }
            await window(scene, 'resize');
            await tester.pumpWidget(
              WorkspaceHarness(provider: provider, locale: const Locale('zh')),
            );
            await tester.pumpAndSettle();
            if (foregroundWaitPending) {
              foregroundWaitPending = false;
              await awaitForeground(scene);
            }
            final trigger = find.byKey(ValueKey(scene.triggerKey));
            expect(trigger.hitTestable(), findsOneWidget);
            final l10n = AppLocalizations.of(tester.element(trigger));
            final week = scene.choice('week', l10n.viewWeek);
            final day = scene.choice('day', l10n.viewDay);
            final writes = storage.writes;
            final saved = storage.data;
            final committed = provider.session.committedData;
            final selectedWeek = provider.studentView.selectedWeek;
            final selectedDate = provider.generalView.data.selectedDateIso;

            void expectDataUnchanged() {
              expect(storage.writes, writes);
              expect(storage.data, same(saved));
              expect(provider.session.committedData, same(committed));
              expect(provider.studentView.selectedWeek, selectedWeek);
              expect(provider.generalView.data.selectedDateIso, selectedDate);
              expect(provider.generalView.data.defaultView, generalViewWeek);
              expect(provider.workspaceView.activeMode, scene.mode);
            }

            void expectWeekSelected() {
              expect(week, findsOneWidget);
              expect(day, findsOneWidget);
              expect(tester.widget<SkedPopupMenuItem>(week).selected, isTrue);
              expect(tester.widget<SkedPopupMenuItem>(day).selected, isFalse);
            }

            Future<void> openMenu() async {
              await tester.tap(trigger, kind: PointerDeviceKind.mouse);
              await tester.pumpAndSettle();
              expectWeekSelected();
            }

            await openMenu();
            await tester.ensureVisible(day);
            await tester.pumpAndSettle();
            expect(day.hitTestable(), findsOneWidget);
            final surface = find
                .ancestor(
                  of: day,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Material && widget.type == MaterialType.card,
                  ),
                )
                .first;
            final menuElement = tester.element(surface);
            final menuRoute = ModalRoute.of(tester.element(day))!;
            final menuRectBefore = tester.getRect(surface);
            Rect expectMenuRetained() {
              expect(menuElement.mounted, isTrue);
              expect(tester.element(surface), same(menuElement));
              expect(ModalRoute.of(tester.element(day)), same(menuRoute));
              expect(menuRoute.isCurrent, isTrue);
              final rect = tester.getRect(surface);
              expect(rect.left, closeTo(menuRectBefore.left, .1));
              expect(rect.top, closeTo(menuRectBefore.top, .1));
              expect(rect.width, closeTo(menuRectBefore.width, .1));
              expect(rect.height, closeTo(menuRectBefore.height, .1));
              expectWeekSelected();
              expectDataUnchanged();
              return rect;
            }

            await window(scene, 'capture', capture: 'menu-open');
            final itemRect = tester.getRect(day);
            final itemStart = itemRect.center;
            final itemEnd = itemStart + const Offset(32, 0);
            expect(itemRect.deflate(2).contains(itemEnd), isTrue);
            final menuDrag = await window(
              scene,
              'range-drag',
              point: itemStart,
              endPoint: itemEnd,
            );
            await tester.pumpAndSettle();
            expect(menuDrag['movedX'], 0);
            expect(menuDrag['movedY'], 0);
            expectWeekSelected();
            expectDataUnchanged();
            final windowBefore = await window(
              scene,
              'capture',
              capture: 'menu-body-not-draggable',
            );

            final toolbar = find.byKey(
              ValueKey('${scene.mode.value}-workspace-toolbar'),
            );
            final toolbarRect = tester.getRect(toolbar);
            final controller = DesktopWindowDragScope.maybeOf(
              tester.element(toolbar),
            )!;
            final caption = tester.getRect(
              find.bySemanticsLabel(l10n.minimizeWindow),
            );
            final candidates =
                [
                  for (var x = toolbarRect.left + 16; x < caption.left - 4; x++)
                    Offset(x, toolbarRect.center.dy),
                ].where((point) {
                  // Native input rounds logical coordinates to physical pixels.
                  // Reject a boundary that could round back onto a toolbar button.
                  return [
                    for (final dx in [-2.0, 0.0, 2.0])
                      for (final dy in [-2.0, 0.0, 2.0]) point + Offset(dx, dy),
                  ].every(controller.canDrag);
                }).toList();
            expect(
              candidates,
              isNotEmpty,
              reason: '${scene.name} must expose a real blank caption region.',
            );
            final captionDrag = await window(
              scene,
              'drag',
              point: candidates[candidates.length ~/ 2],
            );
            await tester.pumpAndSettle();
            expect((captionDrag['movedX'] as num).abs(), greaterThan(10));
            expect((captionDrag['movedY'] as num).abs(), greaterThan(5));
            final menuRectAfter = expectMenuRetained();
            evidence.add({
              'case': scene.name,
              'action': 'menu-retained-after-caption-drag',
              'menuRectBeforeDp': _rect(menuRectBefore),
              'menuRectAfterDp': _rect(menuRectAfter),
              'sameMenuElement': true,
              'sameMenuRoute': true,
              'movedX': captionDrag['movedX'],
              'movedY': captionDrag['movedY'],
            });

            // Return only the native position to the safe capture area, using
            // the measured dimensions so compact menus are not retired by resize.
            final windowAfter = await window(
              scene,
              'resize',
              size: Size(
                (windowBefore['clientWidthDp'] as num).toDouble(),
                (windowBefore['clientHeightDp'] as num).toDouble(),
              ),
            );
            await tester.pumpAndSettle();
            expect(windowAfter['clientWidthDp'], windowBefore['clientWidthDp']);
            expect(
              windowAfter['clientHeightDp'],
              windowBefore['clientHeightDp'],
            );
            final menuRectAfterReset = expectMenuRetained();
            evidence.add({
              'case': scene.name,
              'action': 'capture-position-reset',
              'clientWidthBeforeDp': windowBefore['clientWidthDp'],
              'clientHeightBeforeDp': windowBefore['clientHeightDp'],
              'clientWidthAfterDp': windowAfter['clientWidthDp'],
              'clientHeightAfterDp': windowAfter['clientHeightDp'],
              'menuRectAfterDp': _rect(menuRectAfterReset),
            });
            await window(
              scene,
              'capture',
              capture: 'menu-retained-after-caption-drag',
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(menuElement.mounted, isFalse);
            expect(week, findsNothing);
            expect(day, findsNothing);
            expectDataUnchanged();
            await openMenu();
            expect(ModalRoute.of(tester.element(day)), isNot(same(menuRoute)));
            expectDataUnchanged();
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(week, findsNothing);
            expect(day, findsNothing);
            expectDataUnchanged();
            expect(tester.takeException(), isNull);
            evidence.add({
              'case': scene.name,
              'verified': true,
              'menuRetainedAfterDrag': true,
              'selectedView': 'week',
              'writesDelta': storage.writes - writes,
              'committedDataUnchanged': identical(
                provider.session.committedData,
                committed,
              ),
            });
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            provider.dispose();
          }
        }
        completed = true;
      } catch (error) {
        failure = '$error';
        rethrow;
      } finally {
        binding.shouldPropagateDevicePointerEvents = previousPointerPropagation;
        final report = <String, Object?>{
          'scope': 'Real Win32 window movement with in-memory workspace data',
          'processId': pid,
          'menuInteraction': 'WidgetTester mouse tap and Escape',
          'dragInteraction': 'Win32 mouse_event and SetCursorPos',
          'waitForForeground': waitForForeground,
          'completed': completed,
          'failure': ?failure,
          'evidence': evidence,
        };
        binding.reportData = report;
        await evidenceFile.writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(report)}\n',
          flush: true,
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
