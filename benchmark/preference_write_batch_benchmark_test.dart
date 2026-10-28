import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/settings_commands.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal_io.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store_io.dart';
import 'package:sked/services/secret_store.dart';

import '../integration_test/support/capture_output_directory.dart';
import 'src/benchmark_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('measures durable preference commands over 5000 events', () async {
    const coalescing = bool.fromEnvironment(
      'SKED_BENCHMARK_COALESCING',
      defaultValue: true,
    );
    const verifyOnly = bool.fromEnvironment('SKED_BENCHMARK_VERIFY_ONLY');
    final output = createCaptureOutputDirectory(
      label: 'preference-write-benchmark',
      configuredPath: const String.fromEnvironment('SKED_BENCHMARK_OUTPUT_DIR'),
    );
    final label = safeBenchmarkLabel(
      const String.fromEnvironment(
        'SKED_BENCHMARK_LABEL',
        defaultValue: 'preference-local',
      ),
    );
    final seed = _fixture();
    final seedChecksum = _checksum(seed);
    final reports = <Map<String, Object>>[];
    for (final scenario in ['single', 'five-disjoint', 'five-same-field']) {
      final directory = await Directory.systemTemp.createTemp(
        'sked-preference-$scenario-',
      );
      final storage = _CountingStorage(directory);
      AppRuntime? runtime;
      try {
        await storage.save(seed);
        runtime = AppRuntime(
          storage: storage,
          secretStore: _EmptySecrets(),
          schoolSiteService: SchoolSiteService(
            store: PlatformSchoolSiteStore(
              directoryProvider: () async => directory,
            ),
          ),
          backupRestoreJournal: FileAppBackupRestoreJournal(
            directoryProvider: () async => directory,
          ),
          systemLocaleCodeResolver: () => 'en',
        );
        await runtime.lifecycle.load();
        expect(runtime.session.isLoaded && runtime.session.canWrite, isTrue);
        expect(_checksum(runtime.session.data), seedChecksum);
        // The reference uses the existing complete-snapshot callback. Both
        // sides run the same commands, services, queue and disk transaction.
        final commands = coalescing
            ? runtime.settingsCommands
            : SettingsCommands(
                session: runtime.session,
                persist: runtime.persistence.saveAndNotify,
                secrets: runtime.schoolImportSecrets,
              );
        final samples = <double>[];
        final memory = <Map<String, int>>[];
        final checksums = <String>{};
        final writeCounts = <int>[];
        final warmups = verifyOnly ? 0 : 5;
        final repetitions = verifyOnly ? 1 : 11;
        for (
          var iteration = 0;
          iteration < warmups + repetitions;
          iteration++
        ) {
          final before = runtime.session.data;
          final targetLocale = before.localeCode == 'en' ? 'zh' : 'en';
          final stages = <AppData>[];
          switch (scenario) {
            case 'single':
              stages.add(before.copyWith(localeCode: targetLocale));
            case 'five-disjoint':
              stages.add(before.copyWith(localeCode: targetLocale));
              stages.add(
                stages.last.copyWith(
                  includePrereleaseUpdates: !before.includePrereleaseUpdates,
                  availableUpdateVersion: null,
                ),
              );
              stages.add(
                stages.last.copyWith(
                  hideHomeWorkspaceNavigation:
                      !before.hideHomeWorkspaceNavigation,
                ),
              );
              stages.add(
                stages.last.copyWith(
                  homeWorkspaceNavigationCollapsed:
                      !before.homeWorkspaceNavigationCollapsed,
                ),
              );
              stages.add(
                stages.last.copyWith(
                  workspacePanelDisplayMode:
                      before.workspacePanelDisplayMode ==
                          WorkspacePanelDisplayMode.overlay
                      ? WorkspacePanelDisplayMode.sideBySide
                      : WorkspacePanelDisplayMode.overlay,
                ),
              );
            case 'five-same-field':
              for (var step = 0; step < 5; step++) {
                stages.add(
                  (stages.isEmpty ? before : stages.last).copyWith(
                    localeCode: step.isEven ? targetLocale : before.localeCode,
                  ),
                );
              }
          }
          storage.writes.clear();
          final rssBefore = ProcessInfo.currentRss;
          final timer = Stopwatch()..start();
          switch (scenario) {
            case 'single':
              await commands.updateLocaleCode(targetLocale);
            case 'five-disjoint':
              await Future.wait([
                commands.updateLocaleCode(targetLocale),
                commands.updateIncludePrereleaseUpdates(
                  stages[1].includePrereleaseUpdates,
                ),
                commands.updateHideHomeWorkspaceNavigation(
                  stages[2].hideHomeWorkspaceNavigation,
                ),
                commands.updateHomeWorkspaceNavigationCollapsed(
                  stages[3].homeWorkspaceNavigationCollapsed,
                ),
                commands.updateWorkspacePanelDisplayMode(
                  stages[4].workspacePanelDisplayMode,
                ),
              ]);
            case 'five-same-field':
              await Future.wait([
                for (final stage in stages)
                  commands.updateLocaleCode(stage.localeCode),
              ]);
          }
          timer.stop();
          final rssAfter = ProcessInfo.currentRss;
          final peak = ProcessInfo.maxRss;
          final expectedWrites = scenario == 'five-disjoint' && coalescing
              ? [stages.last]
              : stages;
          expect(
            storage.writes.map(_checksum).toList(),
            expectedWrites.map(_checksum).toList(),
          );
          final expected = _checksum(stages.last);
          expect(_checksum(runtime.session.data), expected);
          expect(_checksum(runtime.session.repository.persisted!), expected);
          final readback = await IoTimetableStorage(
            directoryProvider: () async => directory,
          ).load();
          expect(readback.canWrite, isTrue);
          expect(_checksum(readback.data!), expected);
          checksums.add(expected);
          if (iteration >= warmups) {
            samples.add(timer.elapsedMicroseconds.toDouble());
            writeCounts.add(storage.writes.length);
            memory.add({
              'rssBeforeBytes': rssBefore,
              'rssAfterBytes': rssAfter,
              'rssDeltaBytes': rssAfter - rssBefore,
              'processLifetimePeakRssBytes': peak,
            });
          }
        }
        final median = benchmarkMedian(samples);
        reports.add({
          'name': scenario,
          'unit': 'us/command-sequence',
          'operationsPerSample': 1,
          'warmups': warmups,
          'samples': samples,
          'median': median,
          'mad': benchmarkMedian(
            samples.map((sample) => (sample - median).abs()).toList(),
          ),
          'writesPerSample': writeCounts,
          'resultChecksums': checksums.toList()..sort(),
          'memory': memory,
        });
      } finally {
        if (runtime != null) {
          await runtime.persistence.flushPendingUiStateSaves();
          await runtime.session.repository.waitForPendingWrites();
          runtime.dispose();
        }
        await directory.delete(recursive: true);
      }
    }
    final report = {
      'schemaVersion': 1,
      'label': label,
      'revision': const String.fromEnvironment(
        'SKED_BENCHMARK_REVISION',
        defaultValue: 'unknown',
      ),
      'coalescing': coalescing,
      'runtime': {
        ...benchmarkRuntimeMetadata('flutter-test-host-jit-real-disk'),
        'measurement': verifyOnly ? 'verification-only' : 'timed',
      },
      'dataset': {
        'version': 1,
        'events': 5000,
        'calendars': 1,
        'seedChecksum': seedChecksum,
        'seedUtf8Bytes': utf8.encode(seed.encode()).length,
      },
      'protocol': {
        'reference': 'Same source with the optional preference callback unconnected; ordinary full snapshot writes.',
        'timing': 'One direct command sequence through AppRuntime per sample; 5 warmups and 11 samples, no calibration. Preparation, hashes, independent disk readback, RSS reads and cleanup excluded.',
        'disk': 'Production IoTimetableStorage flush, decode verification, rename and rollback. Synthetic temporary directories; OS page cache may be warm.',
        'memory': 'Per-sample whole-process RSS before/after and lifetime maximum; not Dart allocations or a per-sequence peak.',
        'scope': 'Windows host JIT durable commands, not UI frames, native app startup, Android or power-loss tests.',
      },
      'cases': reports,
    };
    final file = File(path.join(output.path, 'windows-host-$label.json'));
    await file.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    stdout.writeln('Benchmark report: ${file.path}');
  }, timeout: Timeout.none);
}

class _CountingStorage extends IoTimetableStorage {
  _CountingStorage(Directory directory)
    : super(directoryProvider: () async => directory);
  final writes = <AppData>[];
  @override
  Future<void> save(AppData data) async {
    await super.save(data);
    writes.add(data);
  }
}

class _EmptySecrets implements SecretStore {
  @override
  Future<String> readCustomSchoolImportApiKey() async => '';
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    if (value.isNotEmpty) throw StateError('Benchmark does not use API keys.');
  }
}

String _checksum(AppData data) =>
    sha256.convert(utf8.encode(jsonEncode(data.toJson()))).toString();

AppData _fixture() {
  final start = DateTime.utc(2026, 1, 1, 9);
  final events = [
    for (var index = 0; index < 5000; index++)
      GeneralEvent(
        id: 'event-$index',
        calendarId: 'calendar',
        title: 'Persisted event $index',
        startDateTimeIso: start
            .add(Duration(days: index % 365))
            .toIso8601String(),
        endDateTimeIso: start
            .add(Duration(days: index % 365, hours: 1))
            .toIso8601String(),
      ),
  ];
  return buildInitialAppData(buildDefaultPeriodTimes()).copyWith(
    localeCode: 'en',
    generalMode: GeneralScheduleData(
      activeScheduleId: 'calendar',
      selectedDateIso: '2026-01-01',
      schedules: [
        GeneralSchedule(
          id: 'calendar',
          name: 'Calendar',
          colorValue: 0xff6750a4,
          events: events,
        ),
      ],
    ),
  );
}
