// Local audit acceptance. All data and evidence stay in an isolated directory.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/course_editor_sheet.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';

import '../test/support/workspace_harness.dart';

class _Secrets implements SecretStore {
  @override
  Future<String> readCustomSchoolImportApiKey() async => '';
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _LifecycleLog extends WidgetsBindingObserver {
  final states = <String?>[];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    states.add(state.name);
    debugPrint('Native workflow lifecycle: ${state.name}');
  }
}

AppRuntime _runtime(Directory directory) => AppRuntime(
  storage: IoTimetableStorage(directoryProvider: () async => directory),
  secretStore: _Secrets(),
  schoolSiteService: SchoolSiteService(
    store: PlatformSchoolSiteStore(directoryProvider: () async => directory),
  ),
  backupRestoreJournal: FileAppBackupRestoreJournal(
    directoryProvider: () async => directory,
  ),
  workspaceMutationLock: (action) => action(),
  systemLocaleCodeResolver: () => 'en',
  uiStateSaveDelay: Duration.zero,
);

Future<void> _until(
  WidgetTester t,
  bool Function() ready,
  String reason,
) async {
  for (var frame = 0; frame < 240 && !ready(); frame++) {
    await t
        .pump(const Duration(milliseconds: 50))
        .timeout(const Duration(seconds: 15));
  }
  expect(ready(), isTrue, reason: reason);
}

Future<void> _settle(WidgetTester t) => t
    .pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    )
    .timeout(const Duration(seconds: 15));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'SKED_AUDIT_NATIVE_PHASE',
    defaultValue: 'exercise',
  );
  const output = String.fromEnvironment('SKED_AUDIT_NATIVE_DATA');
  testWidgets(
    'isolated native forms, hover, route switches and process restart: $phase',
    (t) async {
      if (!const ['exercise', 'read'].contains(phase) || output.isEmpty) {
        throw ArgumentError(
          'Supply an exercise/read phase and isolated SKED_AUDIT_NATIVE_DATA',
        );
      }
      SharedPreferences.setMockInitialValues({});
      final directory = Directory(output);
      await directory.create(recursive: true);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size(
        const int.fromEnvironment(
          'SKED_AUDIT_NATIVE_WIDTH',
          defaultValue: 1440,
        ).toDouble(),
        1000,
      );
      addTearDown(t.view.reset);
      final previousPolicy = binding.framePolicy;
      binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
      final semantics = t.ensureSemantics();
      final lifecycle = _LifecycleLog()
        ..states.add(binding.lifecycleState?.name);
      binding.addObserver(lifecycle);
      AppRuntime? p;
      Object? primaryFailure;
      final observations = <Map<String, Object?>>[];
      try {
        if (phase == 'exercise') {
          final auditDate = DateUtils.dateOnly(DateTime.now());
          final sample = DeveloperSampleDataService.append(
            current: buildInitialAppData(
              buildDefaultPeriodTimes(),
              localeCode: 'en',
            ),
            language: DeveloperSampleLanguage.english,
            now: auditDate.add(const Duration(hours: 9)),
          ).data;
          await IoTimetableStorage(directoryProvider: () async => directory)
              .save(sample);
        }
        p = _runtime(directory);
        debugPrint('Native workflow $phase: load');
        await p.lifecycle.load().timeout(const Duration(seconds: 30));
        final provider = p;
        await t
            .pumpWidget(WorkspaceHarness(provider: provider))
            .timeout(const Duration(seconds: 15));
        await _settle(t);
        if (phase == 'read') {
          final expected = jsonDecode(
            await File('${directory.path}/expected.json').readAsString(),
          ) as Map;
          expect(
            provider.workspaceView.data.studentMode.toJson(),
            expected['student'],
          );
          expect(
            provider.workspaceView.data.generalMode.toJson(),
            expected['general'],
          );
          final names = provider.studentView.timetables
              .expand((table) => table.courses)
              .map((course) => course.name);
          final titles = provider.generalView.schedules
              .expand((calendar) => calendar.events)
              .map((event) => event.title);
          expect(
            names.where((name) => name.startsWith('Audit course ')),
            hasLength(10),
          );
          expect(
            titles.where((title) => title.startsWith('Audit event ')),
            hasLength(10),
          );
          expect(names, contains('Audit course edited'));
          expect(titles, contains('Audit event edited'));
          observations.add({
            'task': 'read after independent process restart',
            'studentAndGeneralSnapshotsEqual': true,
          });
        } else {
          final mouse = await t.createGesture(kind: PointerDeviceKind.mouse);
          await mouse.addPointer(location: const Offset(10, 10));
          try {
            for (var round = 0; round < 10; round++) {
              for (final mode in [AppMode.student, AppMode.general]) {
                debugPrint('Native workflow round ${round + 1}: ${mode.name}');
                await provider.workspaces
                    .switchMode(mode)
                    .timeout(const Duration(seconds: 30));
                debugPrint('Native workflow switched to ${mode.name}');
                await _settle(t);
                final editor = find.byType(
                  mode == AppMode.student
                      ? CourseEditorSheet
                      : GeneralEventEditorSheet,
                );
                await t.tap(
                  find.byKey(
                    ValueKey(
                      mode == AppMode.student
                          ? 'student-add-course'
                          : 'general-add-event',
                    ),
                  ),
                );
                await _settle(t);
                expect(editor, findsOneWidget);
                final title = find
                    .descendant(of: editor, matching: find.byType(EditableText))
                    .first;
                final value =
                    '${mode == AppMode.student ? 'Audit course' : 'Audit event'} $round';
                await t.enterText(title, value);
                debugPrint('Native workflow entered $value');
                await _settle(t);
                if (round == 0) {
                  await t.sendKeyEvent(LogicalKeyboardKey.escape);
                  await _settle(t);
                  await t.tap(find.widgetWithText(TextButton, 'Cancel').last);
                  await _settle(t);
                  expect(t.widget<EditableText>(title).controller.text, value);
                }
                final l = AppLocalizations.of(t.element(editor));
                final save = find
                    .descendant(
                      of: editor,
                      matching: find.widgetWithText(FilledButton, l.save),
                    )
                    .last;
                await t.ensureVisible(save);
                debugPrint('Native workflow showing Save for $value');
                await _settle(t);
                expect(save.hitTestable(), findsOneWidget);
                await mouse.moveTo(t.getCenter(save));
                await t
                    .pump(const Duration(milliseconds: 600))
                    .timeout(const Duration(seconds: 15));
                await t.tap(save);
                debugPrint('Native workflow saving $value');
                await _until(
                  t,
                  () => editor.evaluate().isEmpty,
                  'Saving $value must complete',
                );
                debugPrint('Native workflow saved $value');
                await _settle(t);
                expect(t.takeException(), isNull);
                observations.add({
                  'round': round + 1,
                  'mode': mode.name,
                  'savedTitle': value,
                  'hoverAndRouteSurvived': true,
                });
              }
            }
            // Exercise the same production forms for edit, with an explicit saved entity.
            for (final mode in [AppMode.student, AppMode.general]) {
              debugPrint('Native workflow edit: ${mode.name}');
              await provider.workspaces
                  .switchMode(mode)
                  .timeout(const Duration(seconds: 30));
              await _settle(t);
              final owner = t.element(
                find.byKey(
                  ValueKey(
                    mode == AppMode.student
                        ? 'student-add-course'
                        : 'general-add-event',
                  ),
                ),
              );
              final table = provider.studentView.timetables.firstWhere(
                (table) => table.courses.any(
                  (item) => item.name.startsWith('Audit course '),
                ),
              );
              final course = table.courses.firstWhere(
                (item) => item.name.startsWith('Audit course '),
              );
              final calendar = provider.generalView.schedules.firstWhere(
                (calendar) => calendar.events.any(
                  (event) => event.title == 'Audit event 0',
                ),
              );
              final event = calendar.events.firstWhere(
                (item) => item.title == 'Audit event 0',
              );
              unawaited(
                showAppModalSheet<void>(
                  context: owner,
                  workspace: mode,
                  builder: (_) => mode == AppMode.student
                      ? CourseEditorSheet(
                          periodTimes: provider
                              .studentView
                              .activePeriodTimeSet
                              .periodTimes,
                          totalWeeks: table.config.totalWeeks,
                          dayOfWeek: course.dayOfWeek,
                          initialCourse: course,
                          onSave: (edited) => provider.studentCommands
                              .saveCourse(edited, timetableId: table.id),
                        )
                      : GeneralEventEditorSheet(
                          initialEvent: event,
                          calendars: provider.generalView.schedules,
                          activeCalendarId: calendar.id,
                          onSave: provider.generalCommands.saveEvent,
                        ),
                ),
              );
              await _settle(t);
              final editor = find.byType(
                mode == AppMode.student
                    ? CourseEditorSheet
                    : GeneralEventEditorSheet,
              );
              await t.enterText(
                find
                    .descendant(of: editor, matching: find.byType(EditableText))
                    .first,
                mode == AppMode.student
                    ? 'Audit course edited'
                    : 'Audit event edited',
              );
              final save = find
                  .descendant(
                    of: editor,
                    matching: find.widgetWithText(FilledButton, 'Save'),
                  )
                  .last;
              await t.ensureVisible(save);
              await _settle(t);
              await t.tap(save);
              await _until(
                t,
                () => editor.evaluate().isEmpty,
                'Editing must complete',
              );
              await _settle(t);
            }
          } finally {
            await mouse.removePointer();
          }
          await provider.persistence.flushPendingUiStateSaves().timeout(
            const Duration(seconds: 30),
          );
          await File('${directory.path}/expected.json').writeAsString(
            jsonEncode({
              'student': provider.workspaceView.data.studentMode.toJson(),
              'general': provider.workspaceView.data.generalMode.toJson(),
            }),
            flush: true,
          );
        }
        await File('${directory.path}/$phase-result.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'phase': phase,
            'processId': pid,
            'platform': Platform.operatingSystem,
            'source': const String.fromEnvironment('SKED_AUDIT_SOURCE_STATE'),
            'input': 'Flutter test-dispatched pointer/keyboard/hover; not physical desktop automation',
            'storage': 'actual isolated filesystem; no production data',
            'lifecycleStates': lifecycle.states,
            'observations': observations,
          }),
          flush: true,
        );
        expect(t.takeException(), isNull);
      } catch (error, stack) {
        primaryFailure = error;
        debugPrint('Native workflow failed: $error\n$stack');
        rethrow;
      } finally {
        debugPrint('Native workflow teardown: ${binding.lifecycleState?.name}');
        try {
          await t
              .pumpWidget(const SizedBox())
              .timeout(const Duration(seconds: 15));
          await _settle(t);
        } catch (error, stack) {
          debugPrint('Native workflow teardown failed: $error\n$stack');
          if (primaryFailure == null) rethrow;
        } finally {
          p?.dispose();
          semantics.dispose();
          binding.removeObserver(lifecycle);
          binding.framePolicy = previousPolicy;
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
