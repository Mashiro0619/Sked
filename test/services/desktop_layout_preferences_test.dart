import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/app_data_clear_coordinator.dart';
import 'package:sked/services/app_data_clear_service.dart';
import 'package:sked/services/app_exit_controller.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/school_site_store.dart';
import 'package:sked/services/secret_store.dart';

const _resources = DesktopLayoutRegion.resources;
const _editor = DesktopLayoutRegion.eventEditor;
const _dayAgenda = DesktopLayoutRegion.dayAgenda;

String _record(Map<String, Object?> regions) =>
    jsonEncode({'version': 1, 'regions': regions});

class _MemoryStorage implements TimetableStorage {
  AppData data = buildInitialAppData(buildDefaultPeriodTimes());
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async => data = value;
  @override
  Future<String?> filePath() async => 'memory://desktop-layout-data';
}

class _Sites extends SchoolSiteStore {
  _Sites() : super.base();
  @override
  Future<String?> load() async => '[]';
  @override
  Future<void> save(String source) async {}
  @override
  Future<String?> filePath() async => 'memory://desktop-layout-sites';
}

class _Secrets implements SecretStore {
  @override
  Future<String> readCustomSchoolImportApiKey() async => '';
  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

class _ClearService implements AppDataClearService {
  _ClearService(this.action);
  final Future<void> Function() action;
  @override
  Future<void> clear() => action();
}

class _ExitController implements AppExitController {
  _ExitController({this.error});
  final Object? error;
  @override
  Future<void> exitApp() async {
    if (error != null) throw error!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'new instances restore separate floating and docked preferences',
    () async {
      final data = buildInitialAppData(buildDefaultPeriodTimes());
      final backup = encodeAppBackup(data, []);
      final p = DesktopLayoutPreferences();
      addTearDown(p.dispose);
      await p.load();
      p.setPreferredSize(_resources, const PreferredRegionSize(width: 300));
      p.setPreferredSize(
        _editor,
        const PreferredRegionSize(width: 520, height: 610, dockedWidth: 420),
      );
      expect(await p.flush(), isTrue);
      expect(p.hasUnsavedChanges, isFalse);

      final restored = DesktopLayoutPreferences();
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.preferenceFor(_resources)?.width, 300);
      expect(
        restored.preferenceFor(_editor),
        const PreferredRegionSize(width: 520, height: 610, dockedWidth: 420),
      );
      restored.setPreferredSize(
        _editor,
        restored.preferenceFor(_editor)!.copyWith(dockedWidth: 460),
      );
      expect(await restored.flush(), isTrue);
      expect(restored.preferenceFor(_editor)?.width, 520);
      expect(restored.preferenceFor(_editor)?.height, 610);
      expect(encodeAppBackup(data, []), backup);
      expect(backup, isNot(contains(DesktopLayoutPreferences.storageKey)));
    },
  );

  test(
    'late startup reads merge explicit edits and removals before saving',
    () async {
      final read = Completer<Object?>();
      final writes = <String>[];
      final p = DesktopLayoutPreferences(
        read: () => read.future,
        write: (value) async {
          writes.add(value);
          return true;
        },
        saveDelay: const Duration(days: 1),
      );
      addTearDown(p.dispose);
      final loading = p.load();
      p.setPreferredSize(_resources, const PreferredRegionSize(width: 330));
      p.setPreferredSize(_editor, const PreferredRegionSize());
      final saving = p.flush();
      expect(writes, isEmpty);
      read.complete(
        _record({
          'resources': {'width': 224},
          'eventEditor': {'width': 480},
          'dayAgenda': {'height': 290},
        }),
      );
      await loading;
      expect(await saving, isTrue);
      expect(p.preferenceFor(_resources)?.width, 330);
      expect(p.preferenceFor(_editor), isNull);
      expect(p.preferenceFor(_dayAgenda)?.height, 290);
      expect(writes, hasLength(1));
      final regions = (jsonDecode(writes.single) as Map)['regions'] as Map;
      expect(regions['resources'], {'width': 330.0});
      expect(regions.containsKey('eventEditor'), isFalse);
      expect(regions['dayAgenda'], {'height': 290.0});
    },
  );

  test(
    'a failed read does not overwrite unread regions with defaults',
    () async {
      var readable = false;
      var writes = 0;
      final p = DesktopLayoutPreferences(
        read: () async {
          if (!readable) throw StateError('unavailable');
          return _record({
            'dayAgenda': {'height': 280},
          });
        },
        write: (_) async {
          writes++;
          return true;
        },
        saveDelay: const Duration(days: 1),
      );
      addTearDown(p.dispose);
      await p.load();
      expect(p.ready, isTrue);
      expect(p.hasError, isTrue);
      p.setPreferredSize(_resources, const PreferredRegionSize(width: 310));
      expect(await p.flush(), isFalse);
      expect(writes, 0);
      expect(p.preferenceFor(_resources)?.width, 310);
      readable = true;
      expect(await p.retry(), isTrue);
      expect(p.preferenceFor(_dayAgenda)?.height, 280);
      expect(p.hasError, isFalse);
      expect(writes, 1);
    },
  );

  for (final throwsError in [false, true]) {
    test(
      'failed save retains editable geometry and retries latest intent: $throwsError',
      () async {
        var writable = false;
        final attempts = <String>[];
        final p = DesktopLayoutPreferences(
          read: () async => null,
          write: (value) async {
            attempts.add(value);
            if (!writable && throwsError) throw StateError('disk');
            return writable;
          },
          saveDelay: const Duration(days: 1),
        );
        addTearDown(p.dispose);
        await p.load();
        p.setPreferredSize(_resources, const PreferredRegionSize(width: 300));
        expect(await p.flush(), isFalse);
        expect(p.preferenceFor(_resources)?.width, 300);
        expect(p.hasError, isTrue);
        expect(p.hasUnsavedChanges, isTrue);
        p.setPreferredSize(_resources, const PreferredRegionSize(width: 350));
        writable = true;
        expect(await p.retry(), isTrue);
        expect(p.preferenceFor(_resources)?.width, 350);
        expect(p.hasError, isFalse);
        expect(p.hasUnsavedChanges, isFalse);
        expect(attempts, hasLength(2));
      },
    );
  }

  test('one serial flush coalesces edits made during an older write', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final writes = <String>[];
    final p = DesktopLayoutPreferences(
      read: () async => null,
      write: (value) async {
        writes.add(value);
        if (writes.length == 1) {
          started.complete();
          await release.future;
        }
        return true;
      },
      saveDelay: const Duration(days: 1),
    );
    addTearDown(p.dispose);
    await p.load();
    p.setPreferredSize(_resources, const PreferredRegionSize(width: 280));
    final saving = p.flush();
    await started.future;
    p.setPreferredSize(_resources, const PreferredRegionSize(width: 310));
    p.setPreferredSize(_resources, const PreferredRegionSize(width: 360));
    p.setPreferredSize(_editor, const PreferredRegionSize(dockedWidth: 430));
    final joined = p.flush();
    expect(joined, same(saving));
    expect(writes, hasLength(1));
    release.complete();
    expect(await saving, isTrue);
    expect(writes, hasLength(2));
    final regions = (jsonDecode(writes.last) as Map)['regions'] as Map;
    expect(regions['resources'], {'width': 360.0});
    expect(regions['eventEditor'], {'dockedWidth': 430.0});
    expect(p.hasUnsavedChanges, isFalse);
  });

  test(
    'invalid fields fall back independently without rewriting storage',
    () async {
      var writes = 0;
      final p = DesktopLayoutPreferences(
        read: () async => '''{"version":1,"regions":{
        "resources":{"width":-2,"height":1e309},
        "eventEditor":{"width":"large","height":610,"dockedWidth":420},
        "dayAgenda":false,
        "unknown":{"width":700}
      }}''',
        write: (_) async {
          writes++;
          return true;
        },
      );
      addTearDown(p.dispose);
      await p.load();
      expect(p.ready, isTrue);
      expect(p.preferenceFor(_resources), isNull);
      expect(
        p.preferenceFor(_editor),
        const PreferredRegionSize(height: 610, dockedWidth: 420),
      );
      expect(p.preferenceFor(_dayAgenda), isNull);
      expect(await p.flush(), isTrue);
      expect(writes, 0);
    },
  );

  test(
    'malformed records use defaults until an explicit replacement',
    () async {
      for (final raw in [42, '{broken', '{"version":99,"regions":{}}']) {
        var writes = 0;
        final p = DesktopLayoutPreferences(
          read: () async => raw,
          write: (_) async {
            writes++;
            return true;
          },
        );
        try {
          await p.load();
          expect(p.ready, isTrue);
          expect(p.hasError, isTrue);
          expect(p.preferenceFor(_resources), isNull);
          expect(writes, 0);
          p.setPreferredSize(_resources, const PreferredRegionSize(width: 320));
          expect(await p.flush(), isTrue);
          expect(p.hasError, isFalse);
          expect(writes, 1);
        } finally {
          p.dispose();
        }
      }
    },
  );

  test(
    'retry re-reads a corrected record without writing guessed defaults',
    () async {
      Object? stored = '{broken';
      var writes = 0;
      final p = DesktopLayoutPreferences(
        read: () async => stored,
        write: (_) async {
          writes++;
          return true;
        },
      );
      addTearDown(p.dispose);
      await p.load();
      expect(await p.retry(), isFalse);
      stored = _record({
        'resources': {'width': 340},
      });
      expect(await p.retry(), isTrue);
      expect(p.hasError, isFalse);
      expect(p.preferenceFor(_resources)?.width, 340);
      expect(writes, 0);
    },
  );

  testWidgets('continuous resize updates cause one deferred preference write', (
    t,
  ) async {
    var writes = 0;
    final p = DesktopLayoutPreferences(
      read: () async => null,
      write: (_) async {
        writes++;
        return true;
      },
    );
    addTearDown(p.dispose);
    await p.load();
    for (final width in [280.0, 290.0, 300.0, 310.0]) {
      p.setPreferredSize(_resources, PreferredRegionSize(width: width));
      await t.pump(const Duration(milliseconds: 100));
      expect(writes, 0);
    }
    await t.pump(const Duration(milliseconds: 200));
    expect(writes, 1);
    expect(p.hasUnsavedChanges, isFalse);
  });

  test(
    'empty preferences remove only the requested role and the layout key',
    () async {
      SharedPreferences.setMockInitialValues({'unrelated.preference': true});
      final p = DesktopLayoutPreferences();
      addTearDown(p.dispose);
      await p.load();
      p.setPreferredSize(_resources, const PreferredRegionSize(width: 300));
      p.setPreferredSize(_editor, const PreferredRegionSize(height: 590));
      expect(await p.flush(), isTrue);
      p.setPreferredSize(_resources, const PreferredRegionSize());
      expect(await p.flush(), isTrue);
      expect(p.preferenceFor(_resources), isNull);
      expect(p.preferenceFor(_editor)?.height, 590);
      p.setPreferredSize(_editor, const PreferredRegionSize());
      expect(await p.flush(), isTrue);
      final stored = await SharedPreferences.getInstance();
      expect(stored.containsKey(DesktopLayoutPreferences.storageKey), isFalse);
      expect(stored.getBool('unrelated.preference'), isTrue);
    },
  );

  test('clear drains an older write and prevents newer intents from resurrecting it', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    Object? stored;
    var writes = 0;
    var removes = 0;
    final p = DesktopLayoutPreferences(
      read: () async => stored,
      write: (value) async {
        writes++;
        started.complete();
        await release.future;
        stored = value;
        return true;
      },
      remove: () async {
        removes++;
        stored = null;
        return true;
      },
      saveDelay: const Duration(days: 1),
    );
    addTearDown(p.dispose);
    await p.load();
    p.setPreferredSize(_resources, const PreferredRegionSize(width: 280));
    final saving = p.flush();
    await started.future;
    p.setPreferredSize(_resources, const PreferredRegionSize(width: 320));
    final clearing = p.clearForDataClear();
    p.setPreferredSize(_editor, const PreferredRegionSize(height: 600));
    expect(removes, 0);
    release.complete();
    await saving;
    await clearing;
    expect(stored, isNull);
    expect(writes, 1);
    expect(removes, 1);
    p.setPreferredSize(_resources, const PreferredRegionSize(width: 350));
    expect(await p.flush(), isTrue);
    expect(p.preferenceFor(_resources), isNull);
    expect(p.hasUnsavedChanges, isFalse);
    expect(writes, 1);
  });

  test('a late startup read cannot repopulate cleared preferences', () async {
    final read = Completer<Object?>();
    var removes = 0;
    final p = DesktopLayoutPreferences(
      read: () => read.future,
      remove: () async {
        removes++;
        return true;
      },
    );
    addTearDown(p.dispose);
    final loading = p.load();
    final clearing = p.clearForDataClear();
    read.complete(
      _record({
        'resources': {'width': 330},
      }),
    );
    await loading;
    await clearing;
    expect(p.preferenceFor(_resources), isNull);
    expect(p.ready, isTrue);
    expect(removes, 1);
  });

  for (final clearFails in [false, true]) {
    test(
      'app clear ${clearFails ? 'failure releases' : 'commit retains'} the layout write freeze',
      () async {
        final p = DesktopLayoutPreferences.memory(
          initialValues: {_resources: const PreferredRegionSize(width: 300)},
        );
        addTearDown(p.dispose);
        final provider = TimetableProvider(
          storage: _MemoryStorage(),
          secretStore: _Secrets(),
          schoolSiteService: SchoolSiteService(
            store: _Sites(),
            coordinator: SchoolSiteStorageCoordinator(),
          ),
        );
        await provider.lifecycle.load();
        addTearDown(provider.dispose);
        final notifications = AgendaNotificationService(
          enabled: false,
          gateway: MemoryAgendaNotificationGateway(),
          runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        );
        addTearDown(notifications.dispose);
        final coordinator = AppDataClearCoordinator(
          desktopLayoutPreferences: p,
          notificationService: notifications,
          projectionFenceStore: MemoryAgendaNotificationRuntimeStore(),
          clearService: _ClearService(() async {
            expect(p.preferenceFor(_resources), isNull);
            if (clearFails) throw StateError('clear failed');
          }),
          exitController: _ExitController(error: StateError('exit failed')),
        );
        await expectLater(
          coordinator.clearAndExit(provider.dataClear),
          throwsStateError,
        );
        p.setPreferredSize(_resources, const PreferredRegionSize(width: 360));
        expect(await p.flush(), isTrue);
        expect(p.preferenceFor(_resources)?.width, clearFails ? 360 : null);
        expect(provider.dataClear.isCommitted, !clearFails);
      },
    );
  }
}
