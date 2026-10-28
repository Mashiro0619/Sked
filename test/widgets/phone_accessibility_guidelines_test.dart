import '../support/agenda_notification_memory.dart';

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/theme/color_contrast.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/general_schedule_home_screen.dart';
import 'package:sked/screens/home_screen.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/timetable_day_agenda.dart';

import '../support/workspace_harness.dart';

const _fontFamily = 'SkedAccessibility';
const _desktopTapTargetGuideline = MinimumTapTargetGuideline(
  size: Size(24, 24),
  link: 'DESIGN.md: desktop pointer targets',
);

Future<void> _expectDesktopClippedTargets(WidgetTester tester) async {
  final targets = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    node.visitChildren((child) {
      visit(child);
      return true;
    });
    final data = node.getSemanticsData();
    if (node.isMergedIntoParent ||
        node.isInvisible ||
        data.flagsCollection.isHidden ||
        (!data.hasAction(ui.SemanticsAction.tap) &&
            !data.hasAction(ui.SemanticsAction.longPress))) {
      return;
    }
    targets.add(node);
  }

  ({Rect effective, Rect nominal}) bounds(SemanticsNode node) {
    var rect = node.rect;
    var nominal = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      for (final clip in [
        current.parentPaintClipRect,
        current.parentSemanticsClipRect,
      ]) {
        if (clip != null) rect = rect.intersect(clip);
      }
      if (current.transform != null) {
        rect = MatrixUtils.transformRect(current.transform!, rect);
        nominal = MatrixUtils.transformRect(current.transform!, nominal);
      }
      current = current.parent;
    }
    rect = rect.intersect(Offset.zero & tester.view.physicalSize);
    return (effective: rect, nominal: nominal);
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  for (final node in targets) {
    final initial = bounds(node);
    var rect = initial.effective;
    if (rect.isEmpty) continue;
    for (var attempt = 0; attempt < 3; attempt++) {
      final size = rect.size / tester.view.devicePixelRatio;
      if (size.width >= 24 - .001 && size.height >= 24 - .001) break;
      final direction = rect.top > bounds(node).nominal.top + .001
          ? ui.SemanticsAction.scrollDown
          : ui.SemanticsAction.scrollUp;
      var parent = node.parent;
      while (parent != null &&
          !parent.getSemanticsData().hasAction(direction)) {
        parent = parent.parent;
      }
      expect(
        parent,
        isNotNull,
        reason: '${node.label} must be reachable by semantic scrolling',
      );
      parent!.owner!.performAction(parent.id, direction);
      await tester.pumpAndSettle();
      expect(
        node.owner,
        isNotNull,
        reason: '${node.label} disappeared while revealing its target',
      );
      rect = bounds(node).effective;
    }
    final size = rect.size / tester.view.devicePixelRatio;
    expect(
      size.width,
      greaterThanOrEqualTo(24 - .001),
      reason: '${node.label}: effective $rect',
    );
    expect(
      size.height,
      greaterThanOrEqualTo(24 - .001),
      reason: '${node.label}: effective $rect',
    );
  }
}

// These exact labels at 1x were found to be false positives from Flutter's
// modal-light/modal-dark pixel partition: thin antialiased strokes dominated
// its darker bucket. Each exception is rechecked below using the actual
// RenderParagraph foreground and the dominant painted background. WCAG 1.4.3
// permits ignoring user-agent antialiasing; all other nodes use the stock rule.
const _samplingLabels = <_AccessibilityPage, Set<String>>{
  _AccessibilityPage.studentWeek: {'Today', '1', '11:40', '21:40'},
  _AccessibilityPage.month: {
    'Today',
    'Month',
    'Thu',
    'Morning reading',
    'Study group',
    'Bill payment',
    'Household chores',
    'Evening walk',
    'My calendar',
    'Study',
  },
  _AccessibilityPage.list: {'Today', 'My calendar', 'Study'},
  _AccessibilityPage.timeline: {'Today', 'My calendar', 'Study'},
  _AccessibilityPage.settings: {
    'Student timetable',
    'Reminders & notifications',
    'Features',
    'Data and privacy',
  },
  _AccessibilityPage.courseEditor: {
    'Course name',
    'Location',
    'Weeks',
    'End time',
    'Credits',
    'Remarks',
    'Custom fields',
  },
  _AccessibilityPage.eventEditor: {
    'Title',
    'Location',
    'End time',
    'Repeat',
    'Notes',
    'Color',
  },
};

class _VerifiedNodeContrastGuideline extends MinimumTextContrastGuideline {
  const _VerifiedNodeContrastGuideline(this.labels);
  final Set<String> labels;
  @override
  bool shouldSkipNode(SemanticsData data) =>
      super.shouldSkipNode(data) || labels.contains(data.label);
}

Future<({Set<String> labels, Evaluation result})> _verifySamplingLabels(
  WidgetTester tester,
  Set<String> candidates,
) async {
  if (candidates.isEmpty) {
    return (labels: const <String>{}, result: const Evaluation.pass());
  }
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(
    () => layer.toImage(
      view.paintBounds,
      pixelRatio: 1 / tester.view.devicePixelRatio,
    ),
  );
  final bytes = await tester.runAsync(() => image!.toByteData());
  var result = const Evaluation.pass();
  final labels = <String>{};
  try {
    for (final label in candidates) {
      final elements = find.text(label).hitTestable().evaluate().toList();
      if (elements.isEmpty) continue;
      var verified = true;
      for (final element in elements) {
        final render = element.renderObject;
        final span = render is RenderParagraph ? render.text : null;
        if (span is! TextSpan ||
            span.children?.isNotEmpty == true ||
            span.style?.color == null) {
          result += Evaluation.fail(
            '$label needs an explicit foreground verification',
          );
          verified = false;
          continue;
        }
        var rect = MatrixUtils.transformRect(
          render!.getTransformTo(null),
          render.paintBounds.inflate(4),
        );
        var opacity = 1.0;
        RenderObject child = render;
        while (child.parent != null) {
          final parent = child.parent!;
          final clip = parent.describeApproximatePaintClip(child);
          if (clip != null) {
            rect = rect.intersect(
              MatrixUtils.transformRect(parent.getTransformTo(null), clip),
            );
          }
          if (parent is RenderOpacity) opacity *= parent.opacity;
          if (parent is RenderAnimatedOpacity) opacity *= parent.opacity.value;
          child = parent;
        }
        if ((opacity - 1).abs() > .001) {
          result += Evaluation.fail(
            '$label needs a dedicated group-opacity contrast check',
          );
          verified = false;
          continue;
        }
        rect = rect.intersect(
          Rect.fromLTWH(0, 0, image!.width.toDouble(), image.height.toDouble()),
        );
        final histogram = <int, int>{};
        for (
          var y = math.max(0, rect.top.ceil());
          y < rect.bottom.floor();
          y++
        ) {
          for (
            var x = math.max(0, rect.left.ceil());
            x < rect.right.floor();
            x++
          ) {
            final pixel = bytes!.getUint32((y * image.width + x) * 4);
            histogram[pixel] = (histogram[pixel] ?? 0) + 1;
          }
        }
        if (histogram.isEmpty) {
          result += Evaluation.fail('$label has no visible painted background');
          verified = false;
          continue;
        }
        final backgroundPixel = histogram.entries.reduce(
          (a, b) => a.value > b.value ? a : b,
        );
        final count = histogram.values.fold(0, (sum, count) => sum + count);
        if (backgroundPixel.value < count / 2) {
          result += Evaluation.fail(
            '$label has no unambiguous flat background',
          );
          verified = false;
          continue;
        }
        final pixel = backgroundPixel.key;
        final background = Color.fromARGB(
          pixel & 255,
          pixel >> 24,
          (pixel >> 16) & 255,
          (pixel >> 8) & 255,
        );
        if (background.a < 1) {
          result += Evaluation.fail(
            '$label has a translucent captured background',
          );
          verified = false;
          continue;
        }
        final foreground = span.style!.color!.withValues(
          alpha: span.style!.color!.a * opacity,
        );
        final ratio = colorContrastRatio(
          Color.alphaBlend(foreground, background),
          background,
        );
        final threshold = const MinimumTextContrastGuideline()
            .targetContrastRatio(
              span.style!.fontSize,
              bold: span.style!.fontWeight == FontWeight.bold,
            );
        if (ratio < threshold) {
          result += Evaluation.fail(
            '$label: foreground $foreground on painted $background is $ratio, required $threshold',
          );
          verified = false;
        }
      }
      if (verified) labels.add(label);
    }
  } finally {
    image?.dispose();
  }
  return (labels: labels, result: result);
}

enum _AccessibilityPage {
  month,
  list,
  studentDay,
  studentWeek,
  timeline,
  settings,
  notificationSettings,
  courseEditor,
  eventEditor;

  AppMode get mode => switch (this) {
    month || list || timeline || eventEditor => AppMode.general,
    _ => AppMode.student,
  };
}

Widget _screen(
  _AccessibilityPage page,
  AppRuntime app,
  AgendaNotificationService notifications,
) => switch (page) {
  _AccessibilityPage.month ||
  _AccessibilityPage.list ||
  _AccessibilityPage.timeline => const GeneralScheduleHomeScreen(),
  _AccessibilityPage.studentDay ||
  _AccessibilityPage.studentWeek => const HomeScreen(),
  _AccessibilityPage.settings ||
  _AccessibilityPage.notificationSettings => SettingsPage(
    packageInfoLoader: () async => PackageInfo(
      appName: 'Sked',
      packageName: 'com.mashiro.sked',
      version: '1.0.0',
      buildNumber: '1',
    ),
    notificationService: notifications,
    initialDestination: page == _AccessibilityPage.notificationSettings
        ? SettingsDestination.notifications
        : null,
    initialWorkspace: AppMode.student,
  ),
  _AccessibilityPage.courseEditor => Scaffold(
    body: CourseEditorSheet(
      periodTimes: app.studentView.activePeriodTimeSet.periodTimes
          .take(8)
          .toList(),
      totalWeeks: app.studentView.activeTimetable.config.totalWeeks,
      dayOfWeek: DateTime.monday,
      initialCourse: app.studentView.activeTimetable.courses.first,
    ),
  ),
  _AccessibilityPage.eventEditor => _eventEditor(app),
};

Widget _eventEditor(AppRuntime app) {
  final calendar = app.generalView.data.schedules.firstWhere(
    (calendar) => calendar.events.isNotEmpty,
  );
  return Scaffold(
    body: GeneralEventEditorSheet(
      initialEvent: calendar.events.first,
      calendars: [calendar],
      activeCalendarId: calendar.id,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Flutter's bundled fonts keep text geometry consistent across hosts and
    // avoid the solid Ahem glyphs' contrast-sampling artifacts on clipped text.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    expect(flutterRoot, isNotNull, reason: 'Flutter provides the test fonts.');
    final fonts = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
    final loader = FontLoader(_fontFamily);
    for (final weight in ['Regular', 'Medium', 'Bold']) {
      loader.addFont(
        File.fromUri(fonts.uri.resolve('Roboto-$weight.ttf'))
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    }
    await loader.load();
  });

  for (final (foreground, background, passes) in [
    (const Color(0xff42474e), const Color(0xfff8f9ff), true),
    (const Color(0xffcccccc), const Color(0xfff8f9ff), false),
    (Colors.white, const Color(0xff183f69), true),
    (const Color(0x33ffffff), const Color(0xff183f69), false),
  ]) {
    testWidgets(
      'resolved contrast validates actual paint $foreground/$background',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                backgroundColor: background,
                body: Center(
                  child: Text(
                    'Known caption',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      color: foreground,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final verified = await _verifySamplingLabels(tester, {
            'Known caption',
          });
          expect(
            verified.result.passed,
            passes,
            reason: verified.result.reason,
          );
          expect(verified.labels.contains('Known caption'), passes);
        } finally {
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
        }
      },
    );
  }

  for (final (foreground, passes) in [
    (const Color(0xff42474e), true),
    (const Color(0xffcccccc), false),
  ]) {
    testWidgets(
      'contrast samples the offset local surface at DPR 2.75: $passes',
      (tester) async {
        tester.view.devicePixelRatio = 2.75;
        tester.view.physicalSize = const Size(393, 852) * 2.75;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                backgroundColor: const Color(0xff101010),
                body: Stack(
                  children: [
                    Positioned(
                      left: 96,
                      top: 224,
                      width: 260,
                      height: 100,
                      child: ColoredBox(
                        color: const Color(0xfff8f9ff),
                        child: Center(
                          child: Text(
                            'Offset caption',
                            style: TextStyle(
                              fontFamily: _fontFamily,
                              fontSize: 12,
                              color: foreground,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final bounds = tester.getRect(find.text('Offset caption'));
          expect(bounds.left, greaterThan(96));
          expect(bounds.top, greaterThan(224));
          final verified = await _verifySamplingLabels(tester, {
            'Offset caption',
          });
          expect(
            verified.result.passed,
            passes,
            reason: verified.result.reason,
          );
          expect(verified.labels.contains('Offset caption'), passes);
        } finally {
          await tester.pumpWidget(const SizedBox());
          semantics.dispose();
        }
      },
    );
  }

  testWidgets('every visible occurrence of a sampling label must pass', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xfff8f9ff),
            body: Column(
              children: [
                for (final foreground in [
                  const Color(0xff42474e),
                  const Color(0xffcccccc),
                ])
                  SizedBox(
                    height: 100,
                    child: Center(
                      child: Text(
                        'Repeated caption',
                        style: TextStyle(
                          fontFamily: _fontFamily,
                          fontSize: 12,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Repeated caption').hitTestable(), findsNWidgets(2));
      final verified = await _verifySamplingLabels(tester, {
        'Repeated caption',
      });
      expect(verified.result.passed, isFalse);
      expect(verified.labels, isEmpty);
    } finally {
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final page in _AccessibilityPage.values.where(
      (page) =>
          platform == TargetPlatform.android ||
          page != _AccessibilityPage.studentDay,
    )) {
      for (final (scale, brightness) in [
        (1.0, Brightness.light),
        (2.0, Brightness.light),
        if (page == _AccessibilityPage.settings) (1.0, Brightness.dark),
      ]) {
        testWidgets(
          '${page.name} ${platform.name} meets accessibility guidelines at $scale/${brightness.name}',
          (tester) async {
            final desktop = platform == TargetPlatform.windows;
            tester.view.devicePixelRatio = desktop ? 1 : 2.75;
            tester.view.physicalSize = desktop
                ? const Size(1440, 1000)
                : const Size(393, 852) * 2.75;
            addTearDown(tester.view.reset);
            final app = await workspaceProvider(mode: page.mode);
            final notifications = AgendaNotificationService(
              enabled: false,
              gateway: MemoryAgendaNotificationGateway(),
              runtimeStore: MemoryAgendaNotificationRuntimeStore(),
            );
            final semantics = tester.ensureSemantics();
            try {
              if (page == _AccessibilityPage.month ||
                  page == _AccessibilityPage.list ||
                  page == _AccessibilityPage.timeline) {
                await app.generalCommands.updateDisplaySettings(
                  defaultView: switch (page) {
                    _AccessibilityPage.month => generalViewMonth,
                    _AccessibilityPage.list => generalViewList,
                    _ => generalViewWeek,
                  },
                );
              }
              if (page == _AccessibilityPage.studentDay ||
                  page == _AccessibilityPage.studentWeek) {
                await app.studentCommands.setSelectedWeek(1);
              }
              await tester.pumpWidget(
                WorkspaceHarness(
                  provider: app,
                  fontFamily: _fontFamily,
                  textScale: scale,
                  brightness: brightness,
                  home: _screen(page, app, notifications),
                ),
              );
              await tester.pumpAndSettle();
              if (page == _AccessibilityPage.studentDay) {
                await tester.tap(
                  find.byKey(const ValueKey('student-view-toggle-button')),
                );
                await tester.pumpAndSettle();
                await tester.tap(find.byKey(const ValueKey('student-day-1')));
                await tester.pumpAndSettle();
                expect(find.byType(TimetableDayAgenda), findsOneWidget);
              }
              if (page == _AccessibilityPage.timeline) {
                // Dense proportional blocks intentionally remain small. C-E2's
                // explicit 48dp expansion/list path is their equivalent target.
                final expand = find.byKey(
                  const ValueKey('general-timeline-expand-events'),
                );
                expect(expand, findsOneWidget);
                expect(tester.getSize(expand).height, greaterThanOrEqualTo(48));
                await tester.tap(expand);
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const ValueKey('general-more-occurrences-sheet')),
                  findsOneWidget,
                );
              }
              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(
                  desktop
                      ? _desktopTapTargetGuideline
                      : androidTapTargetGuideline,
                ),
              );
              if (desktop) await _expectDesktopClippedTargets(tester);
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              final sampling = await _verifySamplingLabels(
                tester,
                scale == 1 &&
                        brightness == Brightness.light &&
                        (desktop || page == _AccessibilityPage.studentWeek)
                    ? _samplingLabels[page] ?? const {}
                    : const {},
              );
              expect(
                sampling.result.passed,
                isTrue,
                reason: sampling.result.reason,
              );
              await expectLater(
                tester,
                meetsGuideline(_VerifiedNodeContrastGuideline(sampling.labels)),
              );
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
              semantics.dispose();
              notifications.dispose();
              app.dispose();
            }
          },
          variant: TargetPlatformVariant.only(platform),
        );
      }
    }
  }
}
