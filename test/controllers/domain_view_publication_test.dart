import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sked/controllers/app_data_maintenance.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/controllers/general_view_state.dart';
import 'package:sked/controllers/settings_view_state.dart';
import 'package:sked/controllers/student_commands.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_backup_controller.dart' show AppImportMode;

import '../support/workspace_harness.dart';

class _ViewCounts {
  _ViewCounts(AppRuntime app) {
    app.studentView.addListener(() => student += 1);
    app.generalView.addListener(() => general += 1);
    app.settingsView.addListener(() => settings += 1);
    app.workspaceView.addListener(() => workspace += 1);
  }

  int student = 0;
  int general = 0;
  int settings = 0;
  int workspace = 0;

  Object get value => (
    student: student,
    general: general,
    settings: settings,
    workspace: workspace,
  );
}

class _GatedStorage extends WorkspaceMemoryStorage {
  _GatedStorage(super.data);

  Completer<void>? started;
  Completer<void>? release;

  void blockNextSave() {
    started = Completer<void>();
    release = Completer<void>();
  }

  @override
  Future<void> save(AppData data) async {
    final gate = release;
    if (gate != null) {
      started!.complete();
      await gate.future;
      release = null;
    }
    await super.save(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'course edits retain unrelated view and warm occurrence identities',
    () async {
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final views = _ViewCounts(app);
      final general = app.generalView;
      final start = DateTime(2026, 9, 1);
      final end = DateTime(2026, 10, 1);
      final warm = general.occurrencesForRange(
        startInclusive: start,
        endExclusive: end,
      );
      var generalProjectionRuns = 0;
      general.addListener(() {
        generalProjectionRuns += 1;
        general.occurrencesForRange(startInclusive: start, endExclusive: end);
      });
      final before = app.studentView.data;
      final course = app.studentView.activeTimetable.courses.first;

      await app.studentCommands.saveCourse(
        course.copyWith(teacher: '${course.teacher} updated'),
      );

      expect(views.value, (student: 1, general: 0, settings: 0, workspace: 0));
      expect(generalProjectionRuns, 0);
      expect(
        general.occurrencesForRange(startInclusive: start, endExclusive: end),
        same(warm),
      );
      expect(
        app.studentView.data.toolbarNavigationOrder,
        same(before.toolbarNavigationOrder),
      );
      expect(
        app.studentView.data.hiddenToolbarNavigationIds,
        same(before.hiddenToolbarNavigationIds),
      );
      expect(
        app.studentView.data.courseNameColorValues,
        same(before.courseNameColorValues),
      );
    },
  );

  test('event edits publish the general view without rebuilding settings or student views', () async {
    final app = await workspaceProvider();
    addTearDown(app.dispose);
    final views = _ViewCounts(app);
    final event = app.generalView.schedules
        .firstWhere((schedule) => schedule.events.isNotEmpty)
        .events
        .first;

    await app.generalCommands.saveEvent(
      event.copyWith(location: '${event.location} updated'),
    );

    expect(views.value, (student: 0, general: 1, settings: 0, workspace: 0));
  });

  test(
    'only relevant notification settings invalidate general reminder queries',
    () async {
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final views = _ViewCounts(app);

      await app.settingsCommands.updateNotificationsEnabled(
        !app.settingsView.notificationsEnabled,
      );
      expect(views.value, (student: 0, general: 0, settings: 1, workspace: 0));

      await app.settingsCommands.updateGeneralDefaultReminder(
        app.settingsView.generalDefaultMinutesBefore == 15 ? 10 : 15,
      );
      expect(views.value, (student: 0, general: 1, settings: 2, workspace: 0));
    },
  );

  test(
    'unrelated secret publication cannot reveal a pending date range',
    () async {
      final storage = _GatedStorage(
        buildInitialAppData(buildDefaultPeriodTimes()),
      );
      final app = await workspaceProvider(storage: storage);
      addTearDown(app.dispose);
      final views = _ViewCounts(app);
      final previousDate = app.generalView.selectedDate;
      final range = GeneralDateRange(
        DateTime(2027, 1, 4),
        DateTime(2027, 1, 10),
      );
      storage.blockNextSave();
      addTearDown(() {
        final gate = storage.release;
        if (gate != null && !gate.isCompleted) gate.complete();
      });

      final navigation = app.generalNavigation.setDateRange(range);
      await storage.started!.future;
      await app.schoolImportSecrets.update('typed-view-test-key');

      expect(app.session.data.generalMode.customDateRange, range);
      expect(app.generalView.customDateRange, isNull);
      expect(app.generalView.selectedDate, previousDate);
      expect(views.value, (student: 0, general: 0, settings: 1, workspace: 0));

      storage.release!.complete();
      await navigation;
      expect(app.generalView.customDateRange, range);
      expect(views.value, (student: 0, general: 1, settings: 1, workspace: 0));
    },
  );

  test(
    'every maintenance generation publishes without waking domain views',
    () async {
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      final views = _ViewCounts(app);
      final observed = <(AppDataSessionToken, bool)>[];
      final maintenance = app.maintenance;
      maintenance.addListener(() {
        observed.add((maintenance.dataSessionToken, maintenance.isReserved));
      });

      final first = maintenance.reserve();
      final second = maintenance.reserve();
      maintenance.release(first);
      maintenance.release(second);

      expect(observed, [(first, true), (second, true), (second, false)]);
      expect(views.value, (student: 0, general: 0, settings: 0, workspace: 0));
    },
  );

  test('workspace observers receive a changed reminder boundary with unchanged availability', () async {
    final app = await workspaceProvider();
    addTearDown(app.dispose);
    final boundary = DateTime.utc(2027, 1, 4, 9);
    final observed = <DateTime?>[];
    app.workspaceView.addListener(() {
      observed.add(
        app.workspaceView.data.workspaceReminderNotBefore[AppMode.general],
      );
    });
    final replacement = app.session.data.copyWith(
      workspaceReminderNotBefore: {AppMode.general: boundary},
    );

    await app.backups.importJson(
      encodeAppDataEnvelope(replacement),
      mode: AppImportMode.replaceAll,
    );

    expect(app.workspaceView.enabledWorkspaces, AppMode.values.toSet());
    expect(observed, [boundary]);
  });

  testWidgets(
    'typed scope separates widget rebuilds from readiness transitions',
    (tester) async {
      final app = await workspaceProvider();
      addTearDown(app.dispose);
      var generalBuilds = 0;
      var settingsBuilds = 0;
      var readinessBuilds = 0;
      late StudentCommands commands;

      await tester.pumpWidget(
        AppScope(
          app: app,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                Consumer<GeneralViewState>(
                  builder: (context, view, _) {
                    generalBuilds += 1;
                    commands = context.read<StudentCommands>();
                    return Text(view.schedules.length.toString());
                  },
                ),
                Consumer<SettingsViewState>(
                  builder: (_, view, _) {
                    settingsBuilds += 1;
                    return Text(view.localeCode);
                  },
                ),
                Consumer<AppSessionReadiness>(
                  builder: (_, readiness, _) {
                    readinessBuilds += 1;
                    return Text(readiness.isReady.toString());
                  },
                ),
              ],
            ),
          ),
        ),
      );
      expect(commands, same(app.studentCommands));
      final timetable = app.studentView.activeTimetable;
      await commands.updateTimetableConfig(
        timetable.config.copyWith(name: '${timetable.config.name} updated'),
      );
      await tester.pump();
      expect((generalBuilds, settingsBuilds, readinessBuilds), (1, 1, 1));

      app.session.updateLoadState(isLoading: true);
      await tester.pump();
      expect((generalBuilds, settingsBuilds, readinessBuilds), (1, 1, 2));
      app.session.updateLoadState(isLoading: false);
      await tester.pump();
      expect((generalBuilds, settingsBuilds, readinessBuilds), (1, 1, 3));
    },
  );
}
