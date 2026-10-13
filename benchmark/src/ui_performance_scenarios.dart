import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import 'ui_performance_fixtures.dart';
import 'ui_performance_harness.dart';
import 'ui_performance_metrics.dart';

const uiPerformanceHarnessVersion = 1;

class UiPerformanceConfig {
  const UiPerformanceConfig({
    this.label = 'local',
    this.revision = 'unknown',
    this.datasets = uiPerformanceDatasetNames,
    this.warmRuns = 1,
    this.requireFrameTimings = true,
    this.desktopSize = const Size(1280, 720),
  });

  final String label, revision;
  final List<String> datasets;
  final int warmRuns;
  final bool requireFrameTimings;
  final Size desktopSize;
}

class _ActionWindow {
  _ActionWindow({
    required this.name,
    required this.dataset,
    required this.phase,
    required this.iteration,
    required this.start,
    required this.rssBefore,
    required this.viewport,
    required this.writesBefore,
  });

  final String name, dataset, phase;
  final int iteration, start, rssBefore, writesBefore;
  final Size viewport;
  late int end, rssAfter, writesAfter;
  final details = <String, Object?>{};
}

/// Frame timings may arrive in batches after an action ends. Keep one listener
/// for the run and attribute frames by engine vsync time, not callback arrival.
class _Recorder {
  _Recorder(this.tester, this.config);
  final WidgetTester tester;
  final UiPerformanceConfig config;
  final frames = <UiPerformanceFrame>[];
  final windows = <_ActionWindow>[];

  void onFrames(List<ui.FrameTiming> values) {
    for (final frame in values) {
      frames.add(
        UiPerformanceFrame(
          vsyncStart: frame.timestampInMicroseconds(ui.FramePhase.vsyncStart),
          build: frame.buildDuration.inMicroseconds,
          raster: frame.rasterDuration.inMicroseconds,
          total: frame.totalSpan.inMicroseconds,
          vsyncOverhead: frame.vsyncOverhead.inMicroseconds,
        ),
      );
    }
  }

  Future<void> record(
    String name,
    UiPerformanceSession session,
    String dataset,
    int iteration,
    Future<void> Function(Map<String, Object?> details) action,
  ) async {
    final context = tester.element(find.byType(UiPerformanceApp));
    final viewport = tester.binding.renderViews.first.size;
    final window = _ActionWindow(
      name: name,
      dataset: dataset,
      phase: iteration == 0 ? 'cold' : 'warm',
      iteration: iteration,
      start: developer.Timeline.now,
      rssBefore: ProcessInfo.currentRss,
      viewport: viewport,
      writesBefore: session.storage.writes,
    );
    // Touch the production root before dispatch: a disposed harness is a test
    // failure, not a silently empty timing sample.
    expect(context.mounted, isTrue);
    await action(window.details);
    await _settle(tester);
    window
      ..end = developer.Timeline.now
      ..rssAfter = ProcessInfo.currentRss
      ..writesAfter = session.storage.writes;
    windows.add(window);
    expect(tester.takeException(), isNull, reason: '$dataset / $name');
  }

  List<Map<String, Object?>> report(double frameBudgetUs) => [
    for (final window in windows) _windowReport(window, frameBudgetUs),
  ];

  Map<String, Object?> _windowReport(_ActionWindow window, double budget) {
    final selected = frames
        .where((f) => f.vsyncStart >= window.start && f.vsyncStart < window.end)
        .toList();
    if (config.requireFrameTimings && selected.isEmpty) {
      throw StateError(
        'No engine frames for ${window.dataset}/${window.name}/${window.phase}. '
        'Run the integration target with flutter drive --profile.',
      );
    }
    return {
      'scenario': window.name,
      'dataset': window.dataset,
      'phase': window.phase,
      'iteration': window.iteration,
      'startUs': window.start,
      'endUs': window.end,
      'elapsedUs': window.end - window.start,
      'viewportLogical': {
        'width': window.viewport.width,
        'height': window.viewport.height,
      },
      'rssBeforeBytes': window.rssBefore,
      'rssAfterBytes': window.rssAfter,
      'rssDeltaBytes': window.rssAfter - window.rssBefore,
      'memoryStoreWrites': window.writesAfter - window.writesBefore,
      'details': window.details,
      ...summarizeUiFrames(selected, frameBudgetUs: budget),
      'frames': selected.map((frame) => frame.toJson()).toList(),
    };
  }
}

Future<Map<String, Object?>> runUiPerformanceBenchmarks(
  WidgetTester tester, {
  UiPerformanceConfig config = const UiPerformanceConfig(),
}) async {
  if (config.warmRuns < 0 || config.warmRuns > 5) {
    throw ArgumentError.value(config.warmRuns, 'warmRuns', 'Use 0 through 5.');
  }
  if (config.requireFrameTimings && !kProfileMode) {
    throw StateError('UI performance evidence requires a profile build.');
  }
  final fixtures = buildUiPerformanceFixtures(names: config.datasets);
  final desktop = switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };
  final nativeSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  // A larger logical render surface would place menus outside the real view's
  // hit-test area. Constrain, but never spoof, the native size or display DPR.
  final baseSize = desktop
      ? Size(
          math.min(config.desktopSize.width, nativeSize.width),
          math.min(config.desktopSize.height, nativeSize.height),
        )
      : nativeSize;
  await tester.binding.setSurfaceSize(baseSize);
  final reportedRefreshRate = tester.view.display.refreshRate;
  final refreshRate = reportedRefreshRate.isFinite && reportedRefreshRate > 0
      ? reportedRefreshRate
      : 60.0;
  final recorder = _Recorder(tester, config);
  SchedulerBinding.instance.addTimingsCallback(recorder.onFrames);
  final mounts = <Map<String, Object?>>[];
  final started = DateTime.now().toUtc();
  try {
    for (var datasetIndex = 0; datasetIndex < fixtures.length; datasetIndex++) {
      final fixture = fixtures[datasetIndex];
      final session = UiPerformanceSession(fixture.data);
      try {
        final mountStart = developer.Timeline.now;
        final rssBefore = ProcessInfo.currentRss;
        await session.load();
        await tester.pumpWidget(UiPerformanceApp(session: session));
        await _settle(tester);
        mounts.add({
          'dataset': fixture.name,
          'phase': 'cold',
          'processFirstMount': datasetIndex == 0,
          'startUs': mountStart,
          'endUs': developer.Timeline.now,
          'rssBeforeBytes': rssBefore,
          'rssAfterBytes': ProcessInfo.currentRss,
        });
        expect(_key('general-month-calendar-panel'), findsOneWidget);
        final journey = _Journey(tester, session, baseSize);
        for (var iteration = 0; iteration <= config.warmRuns; iteration++) {
          debugPrint(
            'UI benchmark ${fixture.name}: ${iteration == 0 ? 'cold' : 'warm-$iteration'}',
          );
          Future<void> measure(
            String name,
            Future<void> Function(Map<String, Object?>) action,
          ) => recorder.record(name, session, fixture.name, iteration, action);

          await measure('general.month.swipe', journey.swipeMonth);
          await journey.prepareShortMonth();
          await measure('general.month.vertical_scroll', journey.scrollMonth);
          await journey.restoreSize();
          for (final view in [
            generalViewDay,
            generalViewWeek,
            generalViewList,
          ]) {
            await measure('general.$view.open_scroll', (details) async {
              await journey.selectGeneralView(view);
              await journey.scrollActive('general-home', details);
            });
          }
          await journey.selectGeneralView(generalViewMonth);
          await measure(
            'workspace.student.open',
            (_) => journey.switchWorkspace(AppMode.student),
          );
          await measure('student.timetable.switch', journey.switchTimetable);
          await measure(
            'student.week.scroll',
            (details) => journey.scrollActive('student-home', details),
          );
          await measure('student.day.open_scroll', journey.studentDay);
          await measure(
            'workspace.general.open',
            (_) => journey.switchWorkspace(AppMode.general),
          );
          await measure('settings.general.toggle', journey.settings);
          await journey.closeSettings();
        }
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await session.close();
      }
    }
    // The engine batches timing delivery for up to approximately one second.
    // This wait is outside every action window and is never scored as work.
    if (config.requireFrameTimings) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }
    final budget = 1000000 / refreshRate;
    for (final mount in mounts) {
      final selected = recorder.frames
          .where(
            (f) =>
                f.vsyncStart >= (mount['startUs']! as int) &&
                f.vsyncStart < (mount['endUs']! as int),
          )
          .toList();
      if (config.requireFrameTimings && selected.isEmpty) {
        throw StateError(
          'No engine frames for initial ${mount['dataset']} mount.',
        );
      }
      mount.addAll({
        'elapsedUs': (mount['endUs']! as int) - (mount['startUs']! as int),
        ...summarizeUiFrames(selected, frameBudgetUs: budget),
        'frames': selected.map((frame) => frame.toJson()).toList(),
      });
    }
    return {
      'schemaVersion': 1,
      'harnessVersion': uiPerformanceHarnessVersion,
      'label': config.label,
      'revision': config.revision,
      'startedAtUtc': started.toIso8601String(),
      'finishedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'measurement': config.requireFrameTimings
          ? 'profile-engine-frames'
          : 'widget-smoke-only',
      'runtime': {
        'os': Platform.operatingSystem,
        'osVersion': Platform.operatingSystemVersion,
        'dart': Platform.version,
        'processors': Platform.numberOfProcessors,
        'profile': kProfileMode,
        'dpr': tester.view.devicePixelRatio,
        'refreshRateHz': refreshRate,
        'refreshRateFallback': refreshRate != reportedRefreshRate,
        'nativeLogicalSize': {
          'width': nativeSize.width,
          'height': nativeSize.height,
        },
        'baseLogicalSize': {'width': baseSize.width, 'height': baseSize.height},
        'processMaxRssBytes': ProcessInfo.maxRss,
      },
      'protocol': {
        'warmRuns': config.warmRuns,
        'cold': 'First journey with a fresh Provider. Global font/lunar/engine caches may be shared by later datasets.',
        'warm': 'Repeat the same journey in the same mounted production shell.',
        'persistence': 'In-memory snapshots; production Provider mutations and save scheduling, without disk or native services.',
        'memory': 'RSS is whole-process resident memory, not Dart heap or a scenario peak.',
        'timestamps': 'Monotonic Timeline.now and engine FramePhase.vsyncStart microseconds.',
        'percentiles': 'Nearest rank over engine frame durations; missing samples remain null.',
        'overBudget': 'Build or raster stage exceeds the display interval; not an inferred FPS or presentation-drop count.',
        'gesture': '400ms timed drags at 60 pointer samples/second; production animation durations.',
      },
      'datasets': fixtures.map((fixture) => fixture.manifest).toList(),
      'mounts': mounts,
      'results': recorder.report(budget),
    };
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(recorder.onFrames);
    await tester.binding.setSurfaceSize(null);
  }
}

Finder _key(String value) => find.byKey(ValueKey(value));

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 15),
  );
}

class _Journey {
  _Journey(this.tester, this.session, this.baseSize);
  final WidgetTester tester;
  final UiPerformanceSession session;
  final Size baseSize;

  Finder _visible(List<String> keys) {
    for (final key in keys) {
      final candidate = _key(key).hitTestable();
      if (candidate.evaluate().isNotEmpty) return candidate.first;
    }
    throw StateError('None of these production controls is visible: $keys');
  }

  AppLocalizations get l =>
      AppLocalizations.of(tester.element(find.byType(AdaptiveSkedShell).first));

  Future<void> _tap(Finder finder) async {
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    await _settle(tester);
  }

  Future<void> swipeMonth(Map<String, Object?> details) async {
    final original = session.provider.selectedGeneralDate;
    final grid = _key('general-month-calendar-panel');
    final distance = math.min(480.0, tester.getSize(grid).width * .65);
    await tester.timedDrag(
      grid,
      Offset(-distance, 0),
      const Duration(milliseconds: 400),
    );
    await _settle(tester);
    final next = session.provider.selectedGeneralDate;
    expect(
      next.year * 12 + next.month,
      original.year * 12 + original.month + 1,
    );
    await tester.timedDrag(
      grid,
      Offset(distance, 0),
      const Duration(milliseconds: 400),
    );
    await _settle(tester);
    expect(session.provider.selectedGeneralDate, original);
    details['completedMonthChanges'] = 2;
  }

  Future<void> prepareShortMonth() async {
    await tester.binding.setSurfaceSize(
      Size(baseSize.width, math.min(baseSize.height, 360)),
    );
    await _settle(tester);
  }

  Future<void> restoreSize() async {
    await tester.binding.setSurfaceSize(baseSize);
    await _settle(tester);
  }

  Future<void> scrollMonth(Map<String, Object?> details) async {
    final surface = _visible([
      'desktop-month-vertical-scroll',
      'general-month-compact-scroll',
    ]);
    await _scroll(surface, details, requireOverflow: true);
  }

  Future<void> selectGeneralView(String view) async {
    await _tap(_visible(['general-view-switcher']));
    await _tap(
      find
          .byWidgetPredicate(
            (widget) => widget is PopupMenuItem<String> && widget.value == view,
          )
          .last,
    );
    if (view == generalViewMonth) {
      expect(_key('general-month-calendar-panel'), findsOneWidget);
    }
  }

  Future<void> switchWorkspace(AppMode mode) async {
    final keys = [
      'workspace-resource-mode-${mode.value}',
      'adaptive-shell-${mode.value}-destination',
    ];
    Finder? target;
    for (final key in keys) {
      final candidate = _key(key).hitTestable();
      if (candidate.evaluate().isNotEmpty) {
        target = candidate.first;
        break;
      }
    }
    if (target != null) {
      await _tap(target);
    } else {
      await _tap(find.byType(WorkspaceModeMenu).hitTestable().first);
      await _tap(
        find
            .text(
              mode == AppMode.student ? l.studentTimetable : l.generalSchedule,
            )
            .hitTestable()
            .last,
      );
    }
    expect(session.provider.activeMode, mode);
  }

  Future<void> switchTimetable(Map<String, Object?> details) async {
    final original = session.provider.activeTimetable.id;
    final target = session.provider.timetables
        .firstWhere((table) => table.id != original)
        .id;
    Future<void> choose(String id) async {
      final resource = _key('resource-timetable-$id').hitTestable();
      if (resource.evaluate().isNotEmpty) {
        await _tap(resource.first);
      } else {
        await _tap(
          _visible([
            'student-timetable-picker-button',
            'workspace-resource-open',
          ]),
        );
        await _tap(
          _visible(['timetable-picker-item-$id', 'resource-timetable-$id']),
        );
      }
      expect(session.provider.activeTimetable.id, id);
    }

    await choose(target);
    await choose(original);
    details['completedTimetableChanges'] = 2;
  }

  Future<void> scrollActive(String root, Map<String, Object?> details) async {
    final scrollables = find
        .descendant(of: _key(root), matching: find.byType(Scrollable))
        .hitTestable();
    final candidates = scrollables.evaluate().where((element) {
      final state = (element as StatefulElement).state as ScrollableState;
      return axisDirectionToAxis(state.axisDirection) == Axis.vertical &&
          state.position.hasContentDimensions;
    }).toList();
    if (candidates.isEmpty) {
      throw StateError('No visible vertical scroll surface in $root.');
    }
    candidates.sort(
      (a, b) => ((b as StatefulElement).state as ScrollableState)
          .position
          .maxScrollExtent
          .compareTo(
            ((a as StatefulElement).state as ScrollableState)
                .position
                .maxScrollExtent,
          ),
    );
    await _scroll(
      find.byElementPredicate((element) => element == candidates.first),
      details,
    );
  }

  Future<void> _scroll(
    Finder surface,
    Map<String, Object?> details, {
    bool requireOverflow = false,
  }) async {
    final scrollable = tester.widget(surface) is Scrollable
        ? surface
        : find.descendant(of: surface, matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(scrollable).position;
    details['maxScrollExtent'] = position.maxScrollExtent;
    if (requireOverflow) expect(position.maxScrollExtent, greaterThan(0));
    if (position.maxScrollExtent <= 0) {
      details['scrollStatus'] = 'content-fits-viewport';
      return;
    }
    final before = position.pixels;
    final distance = math.min(280.0, tester.getSize(scrollable).height * .65);
    await tester.timedDrag(
      scrollable,
      Offset(0, -distance),
      const Duration(milliseconds: 400),
    );
    await _settle(tester);
    final after = position.pixels;
    expect(
      after,
      greaterThan(before),
      reason: 'The gesture must actually move the production scroll position.',
    );
    await tester.timedDrag(
      scrollable,
      Offset(0, distance),
      const Duration(milliseconds: 400),
    );
    await _settle(tester);
    details.addAll({
      'scrollStatus': 'scrolled',
      'startOffset': before,
      'furthestOffset': after,
      'endOffset': position.pixels,
    });
  }

  Future<void> studentDay(Map<String, Object?> details) async {
    Future<void> choose(String mode) async {
      final toggle = _key('student-view-toggle-button').hitTestable();
      if (toggle.evaluate().isNotEmpty) {
        await _tap(toggle.first);
      } else {
        await _tap(_visible(['student-view-toggle']));
        await _tap(
          find.byWidgetPredicate((widget) {
            final value = widget is PopupMenuItem ? widget.value : null;
            return value is Enum && value.name == mode;
          }).last,
        );
      }
    }

    await choose('day');
    expect(_key('student-day-strip'), findsOneWidget);
    await scrollActive('student-home', details);
    await choose('week');
    expect(_key('student-day-strip'), findsNothing);
  }

  Future<void> settings(Map<String, Object?> details) async {
    final direct = [
      'workspace-resource-settings',
      'general-settings-button',
      'adaptive-shell-settings-action',
    ].where((key) => _key(key).hitTestable().evaluate().isNotEmpty).toList();
    if (direct.isNotEmpty) {
      await _tap(_visible(direct));
    } else {
      await _tap(_visible(['general-toolbar-more-button']));
      await _tap(_key('general-more-settings').last);
    }
    await _tap(_key('settings-general-display').hitTestable().first);
    final setting = _key('general-show-weekends-setting');
    await tester.ensureVisible(setting);
    await _settle(tester);
    final original = session.provider.generalShowWeekends;
    await _tap(setting.hitTestable());
    expect(session.provider.generalShowWeekends, !original);
    await _tap(setting.hitTestable());
    expect(session.provider.generalShowWeekends, original);
    details['completedSettingChanges'] = 2;
  }

  Future<void> closeSettings() async {
    Navigator.of(
      tester.element(find.byType(SettingsPage).first),
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
    await _settle(tester);
    expect(_key('general-month-calendar-panel'), findsOneWidget);
  }
}
