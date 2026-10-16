import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';

import 'startup_clock.dart';
import 'startup_memory.dart';
import 'startup_native_clock.dart';
import 'startup_native_window.dart';
import 'startup_protocol.dart';

export 'startup_native_clock.dart' show StartupClock;

/// Production WidgetsFlutterBinding behavior with two observation hooks.
/// No IntegrationTest binding, overridden surface, synthetic semantics handle,
/// empty runApp, manual warm-up frame, or pump/settle loop is used.
class StartupBinding extends WidgetsFlutterBinding {
  StartupBinding(this.probe);
  final StartupProbe probe;

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    probe.beginFrame(rawTimeStamp);
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void handleDrawFrame() {
    probe.drawFrameStart();
    super.handleDrawFrame();
    if (!probe.stopped) {
      final before = probe.clock.stopwatch.elapsedMicroseconds;
      probe.afterFrame();
      probe.observationCosts.add({
        'frameNumber': probe._drawFrameNumber ?? -1,
        'afterFrameObserverUs':
            probe.clock.stopwatch.elapsedMicroseconds - before,
      });
    }
  }
}

class StartupFrame {
  StartupFrame(this.timing, this.receipt);
  final ui.FrameTiming timing;
  final Map<String, int> receipt;
  int get number => timing.frameNumber;
  int phase(ui.FramePhase phase) => timing.timestampInMicroseconds(phase);
  Map<String, Object> toJson() => {
    'frameNumber': number,
    for (final phase in ui.FramePhase.values)
      '${phase.name}Us': this.phase(phase),
    'buildUs': timing.buildDuration.inMicroseconds,
    'rasterUs': timing.rasterDuration.inMicroseconds,
    'totalSpanUs': timing.totalSpan.inMicroseconds,
    'callbackReceipt': receipt,
  };
}

class StartupProbe {
  StartupProbe(this.clock, {required this.memory});
  final StartupClock clock;
  final StartupMemoryRecorder memory;
  StartupRuntime? runtime;
  bool Function() preferencesReady = () => false;
  final events = <Map<String, Object?>>[];
  final errors = <String>[];
  final beginAssociation = StartupBeginAssociation();
  Map<int, Map<String, Object?>> get begins => beginAssociation.frames;
  final frames = <StartupFrame>[];
  final frameworkFrames = <Map<String, Object?>>[];
  final semantics = <Map<String, Object?>>[];
  final observationCosts = <Map<String, int>>[];
  final nativeWindowObservations = <Map<String, Object?>>[];
  final nativeWindowMilestones = <String, Map<String, Object?>>{};
  final ready = Completer<StartupFrame>();
  final response = Completer<StartupFrame>();
  AppData? readyData;
  int? readyNumber, responseNumber;
  Map<String, Object?>? readyView, responseView;
  Map<String, int>? inputStamp;
  Offset? inputPosition;
  bool stopped = false;
  Element? _target, _initial, _home;
  StartupNativeWindowProbe? _nativeWindow;
  Timer? _visibilityRetry;
  int _visibilityFramesRequested = 0;
  int? _drawFrameNumber;

  void attach() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    SemanticsBinding.instance.addSemanticsEnabledListener(_semanticsChanged);
    _semanticsChanged();
  }

  void event(String name, [Map<String, Object?> details = const {}]) {
    events.add({'name': name, ...clock.stamp(), ...details});
  }

  void beginFrame(Duration? stamp) {
    if (stopped) return;
    beginAssociation.record(
      stamp: clock.stamp(),
      rawBeginUs: stamp?.inMicroseconds,
    );
  }

  void drawFrameStart() {
    _drawFrameNumber = null;
    if (stopped) return;
    // frameData is updated after onBeginFrame returns, before onDrawFrame.
    // Consume exactly one pending begin here rather than using the stale ID.
    _drawFrameNumber = beginAssociation.bindDrawFrame(
      ui.PlatformDispatcher.instance.frameData.frameNumber,
    );
    if (_drawFrameNumber != null) {
      begins[_drawFrameNumber]!['associatedAtDrawStart'] = clock.stamp();
    }
  }

  Map<String, Object?> viewState(Map<String, Object?> nativeWindow) {
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final features = ui.PlatformDispatcher.instance.accessibilityFeatures;
    return {
      'viewId': view.viewId,
      'physicalWidth': view.physicalSize.width,
      'physicalHeight': view.physicalSize.height,
      'devicePixelRatio': view.devicePixelRatio,
      'displayId': view.display.id,
      'refreshRateHz': view.display.refreshRate,
      'nativeWindowBridge': DesktopWindowBridge.instance.available,
      'nativeWindowFocused': DesktopWindowBridge.instance.focused,
      'nativeWindow': nativeWindow,
      'nativeSemantics': ui.PlatformDispatcher.instance.semanticsEnabled,
      'frameworkSemantics': SemanticsBinding.instance.semanticsEnabled,
      'disableAnimations': features.disableAnimations,
      'reduceMotion': features.reduceMotion,
      'accessibleNavigation': features.accessibleNavigation,
      'boldText': features.boldText,
      'highContrast': features.highContrast,
    };
  }

  Map<String, Object?> _observeNativeWindow(String phase, {int? frameNumber}) {
    final before = clock.stopwatch.elapsedMicroseconds;
    final start = clock.stamp();
    Map<String, Object?> native;
    try {
      native = (_nativeWindow ??= StartupNativeWindowProbe()).observe();
    } catch (error, stack) {
      native = {
        'validatedVisible': false,
        'failures': ['$error\n$stack'],
      };
    }
    final observed = <String, Object?>{
      'phase': phase,
      'frameNumber': frameNumber,
      'observationStart': start,
      ...native,
      'observationEnd': clock.stamp(),
      'observerUs': clock.stopwatch.elapsedMicroseconds - before,
    };
    nativeWindowObservations.add(observed);
    observationCosts.add({
      'frameNumber': frameNumber ?? -1,
      'nativeWindowObserverUs': observed['observerUs']! as int,
    });
    return observed;
  }

  void _waitForVisibleReadyFrame() {
    if (stopped || readyNumber != null || _visibilityRetry != null) return;
    _visibilityRetry = Timer(const Duration(milliseconds: 16), () {
      _visibilityRetry = null;
      if (stopped || readyNumber != null) return;
      final native = _observeNativeWindow('waitingForVisibleReady');
      if (native['validatedVisible'] == true) {
        // The runner's first ShowWindow occurs after first raster. Request an
        // ordinary engine frame once Win32 visibility is real; never pump an
        // empty widget or pretend that a previously hidden frame was visible.
        final scheduler = SchedulerBinding.instance;
        native['frameworkFramesEnabled'] = scheduler.framesEnabled;
        native['frameworkFrameAlreadyScheduled'] = scheduler.hasScheduledFrame;
        if (scheduler.framesEnabled && !scheduler.hasScheduledFrame) {
          _visibilityFramesRequested++;
          event('native.visibility.confirmationFrameRequested');
          scheduler.scheduleFrame();
        }
      }
      // Lifecycle delivery may lag native ShowWindow. Continue until an
      // actual ready frame is observed even if scheduling was temporarily off.
      _waitForVisibleReadyFrame();
    });
  }

  void _semanticsChanged() {
    semantics.add({
      ...clock.stamp(),
      'native': ui.PlatformDispatcher.instance.semanticsEnabled,
      'framework': SemanticsBinding.instance.semanticsEnabled,
    });
  }

  void afterFrame() {
    if (stopped) return;
    final number = _drawFrameNumber;
    final app = runtime;
    final baseReady =
        app != null &&
        app.loaded &&
        !app.loading &&
        app.writable &&
        app.privacyAccepted &&
        app.repository.lastLoadStatus.name == 'success' &&
        !app.repository.isWriteStateUnknown &&
        preferencesReady();
    frameworkFrames.add({
      'frameNumber': number,
      ...clock.stamp(),
      'loaded': app?.loaded,
      'loading': app?.loading,
      'writable': app?.writable,
      'baseReady': baseReady,
      'engineFrameIdentityAvailable': number != null,
    });
    if (!baseReady) return;
    if (number == null) {
      // Production warm-up callbacks have rawBeginUs == null and cannot be
      // relabelled with a previous engine ID. Wait for a real engine frame.
      event('ready.waiting-for-engine-frame');
      SchedulerBinding.instance.scheduleFrame();
      return;
    }
    if (_home?.mounted != true || _target?.mounted != true) _locate();
    if (_home == null || _target == null || _initial == null) return;
    if (ModalRoute.of(_home!)?.isCurrent != true) return;
    if (!DesktopWindowBridge.instance.available) return;
    if (readyNumber == null &&
        app.data.generalMode.selectedDateIso == startupSelectedDate &&
        _selected(_initial!) &&
        !_selected(_target!) &&
        _hit(_target!) != null) {
      if (number < 0) {
        errors.add('Ready framework frame has no engine frame number.');
        return;
      }
      final native = _observeNativeWindow(
        'readyFramework',
        frameNumber: number,
      );
      if (native['validatedVisible'] != true) {
        _waitForVisibleReadyFrame();
        return;
      }
      nativeWindowMilestones['readyFramework'] = native;
      _visibilityRetry?.cancel();
      _visibilityRetry = null;
      readyNumber = number;
      readyData = app.data;
      readyView = viewState(native);
      event('home.ready.framework', {'frameNumber': number});
    }
    if (inputStamp != null &&
        responseNumber == null &&
        app.data.generalMode.selectedDateIso == startupInputDate &&
        _selected(_target!) &&
        !_selected(_initial!)) {
      if (number < 0) {
        errors.add('Response framework frame has no engine frame number.');
        return;
      }
      final native = _observeNativeWindow(
        'responseFramework',
        frameNumber: number,
      );
      nativeWindowMilestones['responseFramework'] = native;
      responseNumber = number;
      responseView = viewState(native);
      event('input.response.framework', {'frameNumber': number});
    }
    _resolveFrames();
  }

  void _locate() {
    void visit(Element element) {
      if (element.widget is AppHomeScreen) _home = element;
      final key = element.widget.key;
      if (key == const ValueKey('general-month-day-cell-2026-8-17') &&
          _hit(element) != null) {
        _initial = element;
      }
      if (key == const ValueKey('general-month-day-cell-2026-8-18') &&
          _hit(element) != null) {
        _target = element;
      }
      if (_home != null && _initial != null && _target != null) return;
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }

  bool _selected(Element element) {
    bool? selected;
    void visit(Element node) {
      final widget = node.widget;
      if (widget is Semantics && widget.properties.selected != null) {
        selected ??= widget.properties.selected;
      }
      if (selected == null) node.visitChildren(visit);
    }

    visit(element);
    return selected == true;
  }

  Offset? _hit(Element element) {
    final render = element.findRenderObject();
    if (render is! RenderBox ||
        !render.attached ||
        !render.hasSize ||
        render.size.isEmpty) {
      return null;
    }
    final position = render.localToGlobal(render.size.center(Offset.zero));
    if (!position.dx.isFinite || !position.dy.isFinite) return null;
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    final logicalSize = view.physicalSize / view.devicePixelRatio;
    if (!(Offset.zero & logicalSize).contains(position)) return null;
    final hit = HitTestResult();
    RendererBinding.instance.hitTestInView(hit, position, view.viewId);
    return hit.path.any((entry) => identical(entry.target, render))
        ? position
        : null;
  }

  void _onTimings(List<ui.FrameTiming> batch) {
    if (stopped) return;
    for (final frame in batch) {
      frames.add(StartupFrame(frame, clock.stamp()));
    }
    _resolveFrames();
  }

  void _resolveFrames() {
    for (final frame in frames) {
      if (frame.number == readyNumber && !ready.isCompleted) {
        memory.capture(
          'readyRasterReportObserved',
          frameNumber: frame.number,
          rasterFinishWallTimeUs: frame.phase(
            ui.FramePhase.rasterFinishWallTime,
          ),
          reportStamp: frame.receipt,
        );
        nativeWindowMilestones['readyFrameReport'] = _observeNativeWindow(
          'readyFrameReport',
          frameNumber: frame.number,
        );
        ready.complete(frame);
      }
      if (frame.number == responseNumber && !response.isCompleted) {
        memory.capture(
          'responseRasterReportObserved',
          frameNumber: frame.number,
          rasterFinishWallTimeUs: frame.phase(
            ui.FramePhase.rasterFinishWallTime,
          ),
          reportStamp: frame.receipt,
        );
        nativeWindowMilestones['responseFrameReport'] = _observeNativeWindow(
          'responseFrameReport',
          frameNumber: frame.number,
        );
        response.complete(frame);
      }
    }
  }

  Future<void> tapInputDay() async {
    final position = _target == null ? null : _hit(_target!);
    if (position == null) {
      throw StateError('The input day is not hit-testable.');
    }
    final native = _observeNativeWindow('inputDispatch');
    nativeWindowMilestones['inputDispatch'] = native;
    if (native['validatedVisible'] != true ||
        native['hwnd'] != nativeWindowMilestones['readyFramework']?['hwnd']) {
      throw StateError(
        'The verified Win32 runner window is unavailable for input.',
      );
    }
    inputPosition = position;
    inputStamp = clock.stamp();
    final view = WidgetsBinding.instance.platformDispatcher.views.single;
    const device = 99171;
    const pointer = 99171;
    final gestures = GestureBinding.instance;
    gestures.handlePointerEvent(
      PointerAddedEvent(
        timeStamp: Duration(microseconds: clock.stopwatch.elapsedMicroseconds),
        device: device,
        kind: ui.PointerDeviceKind.mouse,
        position: position,
        viewId: view.viewId,
      ),
    );
    gestures.handlePointerEvent(
      PointerDownEvent(
        timeStamp: Duration(microseconds: clock.stopwatch.elapsedMicroseconds),
        device: device,
        pointer: pointer,
        kind: ui.PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
        position: position,
        viewId: view.viewId,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 16));
    gestures.handlePointerEvent(
      PointerUpEvent(
        timeStamp: Duration(microseconds: clock.stopwatch.elapsedMicroseconds),
        device: device,
        pointer: pointer,
        kind: ui.PointerDeviceKind.mouse,
        position: position,
        viewId: view.viewId,
      ),
    );
    gestures.handlePointerEvent(
      PointerRemovedEvent(
        timeStamp: Duration(microseconds: clock.stopwatch.elapsedMicroseconds),
        device: device,
        kind: ui.PointerDeviceKind.mouse,
        position: position,
        viewId: view.viewId,
      ),
    );
    event('input.dispatched', {
      'kind': 'Flutter GestureBinding mouse pointer events',
    });
  }

  Map<String, Object?> stop() {
    // Sample before clock validation, source checks, or report encoding grows memory.
    memory.capture('measurementEnd');
    stopped = true;
    _visibilityRetry?.cancel();
    _visibilityRetry = null;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    SemanticsBinding.instance.removeSemanticsEnabledListener(_semanticsChanged);
    _semanticsChanged();
    _observeNativeWindow('measurementEnd');
    final end = clock.stamp();
    final clockReport = validateStartupClock(
      samples: clock.samples,
      frames: frames.map((frame) {
        final begin = begins[frame.number];
        return StartupFrameClockEvidence(
          frameNumber: frame.number,
          buildStartUs: frame.phase(ui.FramePhase.buildStart),
          buildFinishUs: frame.phase(ui.FramePhase.buildFinish),
          rasterFinishUs: frame.phase(ui.FramePhase.rasterFinish),
          rasterFinishWallTimeUs: frame.phase(
            ui.FramePhase.rasterFinishWallTime,
          ),
          receiptSampleIndex: frame.receipt['nativeSampleIndex'] ?? -1,
          beginSampleIndex: begin?['nativeSampleIndex'] as int?,
          rawBeginUs: begin?['rawBeginUs'] as int?,
        );
      }).toList(),
      requiredBeginFrameNumbers: {?readyNumber, ?responseNumber},
      observationIssues: [...clock.issues, ...beginAssociation.issues],
    );
    final ordered = frames.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    StartupFrame? numbered(int? number) {
      for (final frame in ordered) {
        if (frame.number == number) return frame;
      }
      return null;
    }

    final first = ordered.isEmpty ? null : ordered.first;
    final readyFrame = numbered(readyNumber);
    final responseFrame = numbered(responseNumber);
    final memoryReport = memory.report(
      readyRaster: readyFrame?.toJson(),
      responseRaster: responseFrame?.toJson(),
      measurementEnd: end,
    );
    errors.addAll((memoryReport['issues']! as List).cast<String>());
    if (readyFrame == null || responseFrame == null) {
      errors.add('A required raster frame is missing.');
    }
    if (first == null || first.number < 0) {
      errors.add('The first raster has no engine frame identity.');
    }
    for (final key in [
      'physicalWidth',
      'physicalHeight',
      'devicePixelRatio',
      'refreshRateHz',
    ]) {
      if (readyView?[key] != responseView?[key]) {
        errors.add('View changed during input: $key');
      }
    }
    const requiredNativePhases = [
      'readyFramework',
      'readyFrameReport',
      'inputDispatch',
      'responseFramework',
      'responseFrameReport',
    ];
    final nativeIssues = <String>[];
    for (final key in ['clientWidth', 'clientHeight']) {
      if (nativeWindowMilestones['readyFramework']?[key] !=
          nativeWindowMilestones['responseFramework']?[key]) {
        nativeIssues.add('Native client geometry changed during input: $key');
      }
    }
    final expectedHandle = nativeWindowMilestones['readyFramework']?['hwnd'];
    for (final phase in requiredNativePhases) {
      final observed = nativeWindowMilestones[phase];
      if (observed == null || observed['validatedVisible'] != true) {
        nativeIssues.add('Win32 visibility was not verified at $phase.');
      } else if (expectedHandle == null || observed['hwnd'] != expectedHandle) {
        nativeIssues.add('The Win32 runner HWND changed at $phase.');
      }
    }
    errors.addAll(nativeIssues);
    return {
      'entry': clock.entry,
      'measurementEnd': end,
      'clock': clockReport,
      'memory': memoryReport,
      'firstRaster': first?.toJson(),
      'readyRaster': readyFrame?.toJson(),
      'responseRaster': responseFrame?.toJson(),
      'input': {
        'stamp': inputStamp,
        'x': inputPosition?.dx,
        'y': inputPosition?.dy,
        'method': 'Flutter GestureBinding mouse down/up; 16 ms hold; real day-cell hit test',
        'targetDate': startupInputDate,
        'readyObservationDelayIncludedInProcessToResponse': true,
      },
      'readyView': readyView,
      'responseView': responseView,
      'nativeWindowVisibility': {
        'validated': nativeIssues.isEmpty,
        'expectedWindowHandle': expectedHandle,
        'requiredObservations': requiredNativePhases,
        'milestones': nativeWindowMilestones,
        'observations': nativeWindowObservations,
        'visibilityConfirmationFramesRequested': _visibilityFramesRequested,
        'visibilityRetryIntervalMs': 16,
        'failures': nativeIssues,
        'scope': 'Win32 visible, enabled, non-minimized, uncloaked runner with an on-screen client rectangle; no unobscured-pixels or physical-input claim.',
      },
      'semantics': semantics,
      'events': events,
      'observationCosts': observationCosts,
      'frameworkFrames': frameworkFrames,
      'frames': frames.map((frame) => frame.toJson()).toList(),
      'beginFrames': begins.values.toList(),
      'warmUpBeginFrames': beginAssociation.warmUps,
      'pendingBeginAtMeasurementEnd': beginAssociation.pending,
      'errors': errors,
    };
  }
}
