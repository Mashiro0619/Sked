import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_backup_controller.dart' show AppImportMode;
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/developer_sample_data_service.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';

import '../test/support/workspace_harness.dart';

class _Secrets implements SecretStore {
  String value = '';
  @override
  Future<String> readCustomSchoolImportApiKey() async => value;
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    this.value = value;
  }
}

Future<AppRuntime> _load(Directory directory) async {
  final provider = AppRuntime(
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
  await provider.lifecycle.load();
  return provider;
}

void _expectSnapshot(
  Map<String, dynamic> actual,
  Map<String, dynamic> expected,
) {
  expect(actual.keys.toSet(), expected.keys.toSet());
  for (final key in expected.keys) {
    expect(actual[key], expected[key], reason: 'Persisted field: $key');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native disk edit, provider reload, backup and restore preserve both workspaces',
    (t) async {
      // Use actual filesystem storage and restore journals, never the user's
      // profile, secure storage, preferences, notification identity or data.
      SharedPreferences.setMockInitialValues({});
      final temporary = await Directory.systemTemp.createTemp(
        'sked_data_smoke_',
      );
      final providers = <AppRuntime>[];
      addTearDown(() async {
        for (final provider in providers) {
          provider.dispose();
        }
        final resolved = await temporary.resolveSymbolicLinks();
        final parent = await Directory.systemTemp.resolveSymbolicLinks();
        if (!path.isWithin(parent, resolved) ||
            !path.basename(resolved).startsWith('sked_data_smoke_')) {
          throw StateError(
            'Refusing cleanup outside the smoke-test directory.',
          );
        }
        await Directory(resolved).delete(recursive: true);
      });
      final source = await Directory(path.join(temporary.path, 'source'))
          .create();
      final restored = await Directory(path.join(temporary.path, 'restored'))
          .create();
      var sample = DeveloperSampleDataService.append(
        current: buildInitialAppData(
          buildDefaultPeriodTimes(),
          localeCode: 'en',
        ),
        language: DeveloperSampleLanguage.english,
        now: DateTime(2026, 9, 29, 9),
      ).data;
      // Persist explicit user colours; loading an uninitialised sample normally
      // fills missing course colours, which is not a data-loss regression.
      sample = sample.copyWith(
        studentMode: sample.studentMode.copyWith(
          courseNameColorValues: {
            for (final timetable in sample.studentMode.timetables)
              for (final course in timetable.courses) course.name: 0xff6750a4,
          },
        ),
      );
      await IoTimetableStorage(directoryProvider: () async => source)
          .save(sample);

      final first = await _load(source);
      providers.add(first);
      expect(first.session.canWrite, isTrue);
      _expectSnapshot(
        first.workspaceView.data.studentMode.toJson(),
        sample.studentMode.toJson(),
      );
      _expectSnapshot(
        first.workspaceView.data.generalMode.toJson(),
        sample.generalMode.toJson(),
      );
      expect(first.studentView.timetables, isNotEmpty);
      final table = first.studentView.timetables.first;
      final course = table.courses.first.copyWith(
        name: 'RC smoke edited course',
      );
      await first.studentCommands.saveCourse(course, timetableId: table.id);
      final calendar = first.generalView.schedules.firstWhere(
        (item) => item.events.isNotEmpty,
      );
      final event = calendar.events.first.copyWith(
        title: 'RC smoke edited event',
      );
      await first.generalCommands.saveEvent(event);
      await first.persistence.flushPendingUiStateSaves();

      first.dispose();
      providers.remove(first);
      final reopened = await _load(source);
      providers.add(reopened);
      expect(
        reopened.studentView.timetables.first.courses.first.name,
        course.name,
      );
      expect(
        reopened.generalView.schedules
            .expand((item) => item.events)
            .singleWhere((item) => item.id == event.id)
            .title,
        event.title,
      );
      final exported = await reopened.backups.exportJson();
      final backup = File(path.join(temporary.path, 'backup.json'));
      await backup.writeAsString(exported, flush: true);

      final destination = await _load(restored);
      providers.add(destination);
      await destination.backups.importJson(
        await backup.readAsString(),
        mode: AppImportMode.replaceAll,
      );
      await destination.persistence.flushPendingUiStateSaves();
      destination.dispose();
      providers.remove(destination);
      final afterRestore = await _load(restored);
      providers.add(afterRestore);
      expect(afterRestore.session.canWrite, isTrue);
      expect(
        afterRestore.workspaceView.data.studentMode.toJson(),
        reopened.workspaceView.data.studentMode.toJson(),
      );
      expect(
        afterRestore.workspaceView.data.generalMode.toJson(),
        reopened.workspaceView.data.generalMode.toJson(),
      );
      expect(
        afterRestore.workspaceView.data.enabledWorkspaces,
        reopened.workspaceView.data.enabledWorkspaces,
      );
      expect(
        await File(path.join(restored.path, 'Sked_backup_restore_journal.json'))
            .exists(),
        isFalse,
      );

      // Render each restored workspace using the production shell and theme.
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(WorkspaceHarness(provider: afterRestore));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(
        find.byKey(const ValueKey('workspace-resource-mode-general')),
      );
      await t.pumpAndSettle();
      expect(afterRestore.workspaceView.activeMode, AppMode.general);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await afterRestore.persistence.flushPendingUiStateSaves();
    },
  );
}
