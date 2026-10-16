import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/adaptive_sked_shell.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/general_occurrence_service.dart';
import 'package:sked/services/import_export_service.dart';
import 'package:sked/services/privacy_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/utils/calendar_timeline_layout.dart';
import 'package:sked/widgets/course_details_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_details_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/workspace_navigation.dart';

import 'data_operations_runtime.dart';
import 'ui_edit_session.dart';
import 'ui_performance_fixtures.dart';
import 'ui_performance_metrics.dart';

const _tempPrefix = 'sked_ui_edit_performance_';
const _secret = 'sked-ui-edit-synthetic-secret-only';
const _courseHitAlignment = Alignment(0, -0.5);

/// Separate from the frozen scroll workload. Gestures use production cards,
/// edit actions, TextFields and save buttons, with real isolated disk writes.
Future<Map<String, Object?>> runUiEditBenchmarks(
  WidgetTester tester, {
  required UiEditSessionFactory createSession,
  required String label,
  required String revision,
  List<String> datasets = uiPerformanceDatasetNames,
  bool requireProfile = true,
}) async {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(label)) {
    throw ArgumentError.value(label, 'label', 'Use a filename-safe label.');
  }
  if (requireProfile && !kProfileMode) {
    throw StateError('UI editing measurements require Profile mode.');
  }
  final fixtures = buildUiPerformanceFixtures(names: datasets);
  final started = DateTime.now().toUtc();
  final nativeSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final desktop =
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
  final size = desktop
      ? Size(math.min(1280, nativeSize.width), math.min(720, nativeSize.height))
      : nativeSize;
  final nativeRefresh = tester.view.display.refreshRate;
  final refresh = nativeRefresh.isFinite && nativeRefresh > 0
      ? nativeRefresh
      : 60.0;
  final frames = <UiPerformanceFrame>[];
  final windows = <Map<String, Object?>>[];
  final inputs = <Map<String, Object?>>[];
  void onFrames(List<ui.FrameTiming> batch) {
    for (final frame in batch) {
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

  await tester.binding.setSurfaceSize(size);
  SchedulerBinding.instance.addTimingsCallback(onFrames);
  final registerTextInput = !tester.testTextInput.isRegistered;
  try {
    if (registerTextInput) {
      // Profile rejects client ID -1; retain the actual setClient ID.
      // This transport injects text without changing editor controllers.
      tester.testTextInput.register();
    }
    for (final fixture in fixtures) {
      debugPrint('UI editor dataset: ${fixture.name}');
      final seed = const ImportExportService().normalizeAppData(
        fixture.data,
        localeCode: fixture.data.localeCode,
      );
      inputs.add({
        ...fixture.manifest,
        'inputSha256': _fingerprint(seed.toJson()),
      });
      final directory = await Directory.systemTemp.createTemp(_tempPrefix);
      UiEditSession? session;
      try {
        final storage = UiEditDiskStorage(directory, seed);
        await storage.save(seed);
        final siteStore = PlatformSchoolSiteStore(
          directoryProvider: () async => directory,
        );
        await siteStore.save('[]');
        final active = createSession(
          DataOperationsDependencies(
            storage: storage,
            secrets: _Secrets(),
            schoolSites: SchoolSiteService(store: siteStore),
            journal: FileAppBackupRestoreJournal(
              directoryProvider: () async => directory,
            ),
            privacy: _Privacy(),
            localeCode: seed.localeCode,
          ),
        );
        session = active;
        await active.load();
        await tester.pumpWidget(active.app);
        await _settle(tester);
        final journey = _EditorJourney(tester, active, fixture.name);

        Future<void> record(
          String name,
          Map<String, Object?> details,
          Future<void> Function() action,
        ) async {
          final rss = ProcessInfo.currentRss;
          final writes = storage.writes;
          final start = developer.Timeline.now;
          await action();
          final end = developer.Timeline.now;
          windows.add({
            'dataset': fixture.name,
            'operation': name,
            'startUs': start,
            'endUs': end,
            'elapsedUs': end - start,
            'rssBeforeBytes': rss,
            'rssAfterBytes': ProcessInfo.currentRss,
            'appDataWrites': storage.writes - writes,
            'details': details,
          });
        }

        await journey.switchWorkspace(AppMode.student);
        await active.quiesce();
        await _settle(tester);
        final table = active.data.studentMode.timetables.singleWhere(
          (table) => table.id == active.data.studentMode.activeTimetableId,
        );
        final course = _firstSlotDisplayedCourse(table.courses);
        final courseDetails = <String, Object?>{
          'timetableId': table.id,
          'courseId': course.id,
          'courseHitAlignment': {
            'x': _courseHitAlignment.x,
            'y': _courseHitAlignment.y,
          },
        };
        await record(
          'student.editor.open',
          courseDetails,
          () => journey.openCourse(course.id),
        );
        final generalBefore = _fingerprint(active.data.generalMode.toJson());
        final courseTitle = 'Edited course ${fixture.name}';
        await record('student.editor.edit_save', {
          ...courseDetails,
          'title': courseTitle,
        }, () => journey.saveCourse(table.id, course.id, courseTitle));
        final courseReadback = await _readback(directory);
        final storedCourse = courseReadback.studentMode.timetables
            .singleWhere((value) => value.id == table.id)
            .courses
            .singleWhere((value) => value.id == course.id);
        _require(
          storedCourse.name == courseTitle,
          'The course title must survive a separate disk readback.',
        );
        _require(
          _fingerprint(courseReadback.generalMode.toJson()) == generalBefore,
          'Course UI save changed General data.',
        );

        await journey.switchWorkspace(AppMode.general);
        await journey.selectDayView();
        await active.quiesce();
        await _settle(tester);
        final selected = active.data.generalMode.selectedDate;
        final end = DateTime(selected.year, selected.month, selected.day + 1);
        final candidates = const GeneralOccurrenceService()
            .occurrencesForRange(
              active.data.generalMode,
              startInclusive: selected,
              endExclusive: end,
            )
            .where(
              (occurrence) =>
                  !occurrence.isAllDay &&
                  !occurrence.calendarDisplayStart.isBefore(selected) &&
                  !occurrence.calendarDisplayEnd.isAfter(end) &&
                  occurrence.calendarDisplayStart.hour >=
                      active.data.generalMode.dayStartHour &&
                  occurrence.calendarDisplayStart.hour <
                      math.min(20, active.data.generalMode.dayEndHour),
            );
        // Dense timelines put higher columns behind their overflow control.
        // The first overlap group's first column stays visible at every width.
        // Use the shared production ordering on both revisions, outside timing.
        final groups = layoutTimelineEventColumns([
          for (final occurrence in candidates)
            TimelineEventSpan(
              occurrence,
              occurrence.calendarDisplayStart.hour * 60 +
                  occurrence.calendarDisplayStart.minute,
              occurrence.calendarDisplayEnd.hour * 60 +
                  occurrence.calendarDisplayEnd.minute,
            ),
        ]);
        _require(groups.isNotEmpty, 'The fixed day needs a timed event card.');
        final occurrence = groups.first.events.first.span.value;
        final eventDetails = <String, Object?>{
          'calendarId': occurrence.calendar.id,
          'eventId': occurrence.event.id,
          'occurrenceStart': occurrence.start.toIso8601String(),
          'eventSelection': 'first-timed-column',
          'editScope': occurrence.event.recurrenceRule.isRepeating
              ? 'entireSeries'
              : 'event',
        };
        await record(
          'general.editor.open',
          eventDetails,
          () => journey.openEvent(occurrence),
        );
        final studentBefore = _fingerprint(active.data.studentMode.toJson());
        final eventTitle = 'Edited event ${fixture.name}';
        await record('general.editor.edit_save', {
          ...eventDetails,
          'title': eventTitle,
        }, () => journey.saveEvent(occurrence.event.id, eventTitle));
        final eventReadback = await _readback(directory);
        _require(
          eventReadback.generalMode.schedules
                  .expand((calendar) => calendar.events)
                  .singleWhere((event) => event.id == occurrence.event.id)
                  .title ==
              eventTitle,
          'The event title must survive a separate disk readback.',
        );
        _require(
          _fingerprint(eventReadback.studentMode.toJson()) == studentBefore,
          'Event UI save changed Student data.',
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await _settle(tester);
        await session?.close();
        final resolved = await directory.resolveSymbolicLinks();
        final temporaryRoot = await Directory.systemTemp.resolveSymbolicLinks();
        if (!path.isWithin(temporaryRoot, resolved) ||
            !path.basename(resolved).startsWith(_tempPrefix)) {
          throw StateError(
            'Refusing cleanup outside the editor benchmark temp directory.',
          );
        }
        await Directory(resolved).delete(recursive: true);
      }
    }
    // Engine batches can arrive after an action ends; delivery is unmeasured.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  } finally {
    if (registerTextInput) tester.testTextInput.unregister();
    SchedulerBinding.instance.removeTimingsCallback(onFrames);
    await tester.binding.setSurfaceSize(null);
  }

  final results = <Map<String, Object?>>[];
  for (final window in windows) {
    final selected = frames
        .where(
          (frame) =>
              frame.vsyncStart >= (window['startUs']! as int) &&
              frame.vsyncStart < (window['endUs']! as int),
        )
        .toList();
    if (requireProfile && selected.isEmpty) {
      throw StateError(
        'Missing native frame samples for ${window['operation']}.',
      );
    }
    results.add({
      ...window,
      'rssDeltaBytes':
          (window['rssAfterBytes']! as int) -
          (window['rssBeforeBytes']! as int),
      ...summarizeUiFrames(selected, frameBudgetUs: 1000000 / refresh),
      'frames': selected.map((frame) => frame.toJson()).toList(),
    });
  }
  return {
    'schemaVersion': 1,
    'harnessVersion': 1,
    'label': label,
    'revision': revision,
    'measurement': kProfileMode
        ? 'native-ui-edit-profile'
        : 'native-ui-edit-smoke',
    'validation': 'passed',
    'startedAtUtc': started.toIso8601String(),
    'finishedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'runtime': {
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'dart': Platform.version,
      'processors': Platform.numberOfProcessors,
      'profile': kProfileMode,
      'dpr': tester.view.devicePixelRatio,
      'refreshRateHz': refresh,
      'refreshRateFallback': refresh != nativeRefresh,
      'nativeLogicalSize': {
        'width': nativeSize.width,
        'height': nativeSize.height,
      },
      'viewportLogical': {'width': size.width, 'height': size.height},
      'processMaxRssBytes': ProcessInfo.maxRss,
    },
    'protocol': {
      'actionsPerDataset': 4,
      'input': 'Injected native Flutter pointer/text input through production cards, details, edit controls and save buttons; not OS IME latency.',
      'persistence': 'Real isolated disk writes; readback validation is outside action windows. Native default codecs and save debounce retained.',
      'preparation': 'Fixed UI fixtures, normalization, mount, workspace/view selection and initial flush are unmeasured.',
      'timing': 'Open includes card-to-details-to-editor; edit_save includes text input, save, durable completion and editor closure.',
      'frames': 'Attributed by monotonic engine vsync timestamp, with unmeasured final delivery wait; over-budget ratio is not FPS.',
      'memory':
          'RSS is whole-process memory, not Dart heap or a per-action peak.',
      'startup':
          'This is an already-running native process; no OS cold-start claim.',
    },
    'datasets': inputs,
    'results': results,
  };
}

class _EditorJourney {
  _EditorJourney(this.tester, this.session, this.dataset);
  final WidgetTester tester;
  final UiEditSession session;
  final String dataset;
  Finder key(String value) => find.byKey(ValueKey(value));
  AppLocalizations get l =>
      AppLocalizations.of(tester.element(find.byType(AdaptiveSkedShell).first));

  Future<void> tap(
    Finder target, {
    Alignment alignment = Alignment.center,
  }) async {
    _require(target.evaluate().isNotEmpty, 'Missing production UI control.');
    await tester.ensureVisible(target.last);
    await _settle(tester);
    final hit = target.hitTestable(at: alignment);
    if (hit.evaluate().isEmpty) {
      final bounds = target.evaluate().isEmpty
          ? 'target disappeared'
          : tester.getRect(target.last).toString();
      throw StateError(
        'Production UI control is not hit-testable: '
        '$target; alignment=$alignment; bounds=$bounds',
      );
    }
    await tester.tapAt(alignment.withinRect(tester.getRect(hit.last)));
    await _settle(tester);
  }

  Future<void> switchWorkspace(AppMode mode) async {
    if (session.data.activeMode == mode) return;
    for (final value in [
      'workspace-resource-mode-${mode.value}',
      'adaptive-shell-${mode.value}-destination',
    ]) {
      if (key(value).hitTestable().evaluate().isNotEmpty) {
        await tap(key(value).hitTestable().first);
        await _waitForWorkspace(mode);
        return;
      }
    }
    await tap(find.byType(WorkspaceModeMenu).hitTestable().first);
    await tap(
      find
          .text(
            mode == AppMode.student ? l.studentTimetable : l.generalSchedule,
          )
          .hitTestable()
          .last,
    );
    await _waitForWorkspace(mode);
  }

  Future<void> _waitForWorkspace(AppMode mode) => _waitUntil(
    tester,
    () =>
        session.data.activeMode == mode &&
        session.storage.data.activeMode == mode &&
        key('${mode.value}-home').hitTestable().evaluate().isNotEmpty,
    'Workspace switch did not complete.',
  );

  Future<void> selectDayView() async {
    await tap(key('general-view-switcher').hitTestable().first);
    await tap(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is PopupMenuItem<String> &&
                widget.value == generalViewDay,
          )
          .last,
    );
  }

  Future<void> openCourse(String id) async {
    await tap(
      key('timetable-course-hit-$id').first,
      alignment: _courseHitAlignment,
    );
    final details = find.byType(CourseDetailsSheet).last;
    _require(details.evaluate().isNotEmpty, 'Course details did not open.');
    await tap(
      find.descendant(
        of: details,
        matching: find.byTooltip(l.editCourseTooltip),
      ),
    );
    _require(
      find.byType(CourseEditorSheet).evaluate().isNotEmpty,
      'Course editor did not open.',
    );
  }

  Future<void> saveCourse(String tableId, String courseId, String title) async {
    final editor = find.byType(CourseEditorSheet).last;
    final writes = session.storage.writes;
    await tester.enterText(key('course-desktop-title').last, title);
    _require(
      session.storage.writes == writes,
      'Editing a course draft must not persist before Save.',
    );
    await tap(find.descendant(of: editor, matching: find.text(l.save)));
    await _waitUntil(
      tester,
      () =>
          find.byType(CourseEditorSheet).evaluate().isEmpty &&
          session.storage.writes > writes,
      'Course Save must complete durably and close its editor.',
    );
    _require(
      session.storage.data.studentMode.timetables
              .singleWhere((value) => value.id == tableId)
              .courses
              .singleWhere((value) => value.id == courseId)
              .name ==
          title,
      'Course UI Save did not persist the entered title.',
    );
  }

  Future<void> openEvent(GeneralEventOccurrence occurrence) async {
    final target = key(
      'general-timed-occurrence-${occurrence.event.id}-${occurrence.start.toIso8601String()}',
    );
    if (target.evaluate().isEmpty) {
      final timedKeys = find
          .byWidgetPredicate((widget) {
            final widgetKey = widget.key;
            return widgetKey is ValueKey<String> &&
                widgetKey.value.startsWith('general-timed-occurrence-');
          })
          .evaluate()
          .map((element) => (element.widget.key! as ValueKey<String>).value)
          .toList();
      final diagnostics =
          'dataset=$dataset; '
          'selectedDate=${session.data.generalMode.selectedDateIso}; '
          'defaultView=${session.data.generalMode.defaultView}; '
          'eventId=${occurrence.event.id}; '
          'start=${occurrence.start.toIso8601String()}; '
          'renderedTimedKeyCount=${timedKeys.length}; '
          'first8=${timedKeys.take(8).toList()}';
      debugPrint('UI editor missing timed occurrence: $diagnostics');
      throw StateError('Missing production event card: $diagnostics');
    }
    await tap(target.first);
    _require(
      find.byType(GeneralEventDetailsSheet).evaluate().isNotEmpty,
      'Event details did not open.',
    );
    await tap(key('general-event-edit-action').last);
    if (occurrence.event.recurrenceRule.isRepeating) {
      _require(
        key('general-event-edit-scope-dialog').evaluate().isNotEmpty,
        'Recurring edit must choose a scope.',
      );
      await tap(key('event-edit-scope-entireSeries'));
    }
    _require(
      find.byType(GeneralEventEditorSheet).evaluate().isNotEmpty,
      'Event editor did not open.',
    );
  }

  Future<void> saveEvent(String eventId, String title) async {
    final editor = find.byType(GeneralEventEditorSheet).last;
    final writes = session.storage.writes;
    await tester.enterText(key('event-desktop-title').last, title);
    _require(
      session.storage.writes == writes,
      'Editing an event draft must not persist before Save.',
    );
    await tap(find.descendant(of: editor, matching: find.text(l.save)));
    await _waitUntil(
      tester,
      () =>
          find.byType(GeneralEventEditorSheet).evaluate().isEmpty &&
          session.storage.writes > writes,
      'Event Save must complete durably and close its editor.',
    );
    _require(
      session.storage.data.generalMode.schedules
              .expand((calendar) => calendar.events)
              .singleWhere((event) => event.id == eventId)
              .title ==
          title,
      'Event UI Save did not persist the entered title.',
    );
  }
}

CourseItem _firstSlotDisplayedCourse(List<CourseItem> courses) {
  final first = courses.first;
  // Fixed stress data has identical time ranges inside larger overlap groups.
  // Select the last-painted member of that same first slot on both revisions.
  final sameSlot =
      courses
          .where(
            (course) =>
                course.dayOfWeek == first.dayOfWeek &&
                course.startMinutes == first.startMinutes &&
                course.endMinutes == first.endMinutes,
          )
          .toList()
        ..sort(compareCoursePaintPriority);
  return sameSlot.last;
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() condition,
  String reason,
) async {
  final timer = Stopwatch()..start();
  while (!condition()) {
    if (timer.elapsed > const Duration(minutes: 2)) {
      throw StateError(reason);
    }
    await tester.pump(const Duration(milliseconds: 16));
    final error = tester.takeException();
    if (error != null) {
      throw StateError('UI benchmark framework error: $error');
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(minutes: 2),
  );
  final error = tester.takeException();
  if (error != null) throw StateError('UI benchmark framework error: $error');
}

Future<AppData> _readback(Directory directory) async {
  final raw = await File(path.join(directory.path, 'Sked_data.json'))
      .readAsString();
  _require(
    !raw.contains(_secret),
    'Synthetic secret leaked into the raw saved archive.',
  );
  final read = await IoTimetableStorage(
    directoryProvider: () async => directory,
  ).load();
  _require(
    read.canWrite && read.data != null,
    'Saved data must reload as writable.',
  );
  _require(
    !read.data!.encode().contains(_secret),
    'Synthetic secret leaked into a saved snapshot.',
  );
  return read.data!;
}

class _Secrets implements SecretStore {
  String _value = _secret;
  @override
  Future<String> readCustomSchoolImportApiKey() async => _value;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    _value = value;
  }
}

class _Privacy extends PrivacyService {
  @override
  Future<String?> fetchCurrentPrivacyPolicyVersion() async => null;
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  return value is List ? value.map(_canonical).toList() : value;
}

String _fingerprint(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonical(value)))).toString();
void _require(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}
