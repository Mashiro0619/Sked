import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/secret_store.dart';

import '../support/data_transfer_codec.dart';
import '../support/timetable_storage_fakes.dart';

class _EmptySecrets implements SecretStore {
  const _EmptySecrets();

  @override
  Future<String> readCustomSchoolImportApiKey() async => '';

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {}
}

Future<AppRuntime> _load(
  MemoryTimetableStorage storage,
  Future<String> Function() versionLoader,
) async {
  final app = AppRuntime(
    storage: storage,
    secretStore: const _EmptySecrets(),
    dataTransferCodec: inlineDataTransferCodec,
    systemLocaleCodeResolver: () => 'en',
    appVersionLoader: versionLoader,
  );
  addTearDown(app.dispose);
  await app.lifecycle.load();
  return app;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final (version, expected) in [
    ('2.3.0', false),
    ('2.3.0+19', false),
    ('2.3.0-alpha.1', true),
    ('2.3.0-beta.2', true),
    ('v2.3.0-rc.4+19', true),
    ('not a version', false),
    ('', false),
  ]) {
    test('fresh installation uses $expected for $version', () async {
      final storage = MemoryTimetableStorage();
      var calls = 0;
      final app = await _load(storage, () async {
        calls++;
        return version;
      });

      expect(app.session.canWrite, isTrue);
      expect(app.settingsView.includePrereleaseUpdates, expected);
      expect(calls, 1);
      await app.lifecycle.completeFirstLaunch(
        AppMode.general,
        hideWorkspaceNavigation: false,
      );
      expect(storage.data!.includePrereleaseUpdates, expected);

      final reopened = await _load(storage, () async {
        throw StateError('Existing settings must not resolve the version.');
      });
      expect(reopened.settingsView.includePrereleaseUpdates, expected);
    });
  }

  test(
    'unavailable local metadata does not block a stable-only first run',
    () async {
      final app = await _load(MemoryTimetableStorage(), () async {
        throw StateError('No package metadata');
      });
      expect(app.lifecycle.isLoaded, isTrue);
      expect(app.session.canWrite, isTrue);
      expect(app.settingsView.includePrereleaseUpdates, isFalse);
    },
  );

  test(
    'unresponsive metadata times out and late results cannot opt in',
    () async {
      final version = Completer<String>();
      var requested = false;
      final app = await _load(MemoryTimetableStorage(), () {
        requested = true;
        return version.future;
      });
      expect(requested, isTrue);
      expect(app.lifecycle.isLoaded, isTrue);
      expect(app.session.canWrite, isTrue);
      expect(app.settingsView.includePrereleaseUpdates, isFalse);
      version.complete('2.4.0-beta.1');
      await Future<void>.value();
      expect(app.settingsView.includePrereleaseUpdates, isFalse);
    },
  );

  for (final selected in [false, true]) {
    for (final version in ['2.3.0', '2.4.0-beta.1', 'unknown']) {
      test('existing choice $selected is preserved on $version', () async {
        final stored = buildInitialAppData(buildDefaultPeriodTimes())
            .copyWith(includePrereleaseUpdates: selected);
        var calls = 0;
        final storage = MemoryTimetableStorage(initialData: stored);
        final app = await _load(storage, () async {
          calls++;
          return version;
        });
        expect(app.settingsView.includePrereleaseUpdates, selected);
        expect(storage.saveCount, 0);
        expect(calls, 0);
      });
    }
  }

  test(
    'legacy missing preference remains off on a prerelease install',
    () async {
      final json = buildInitialAppData(buildDefaultPeriodTimes()).toJson()
        ..remove('includePrereleaseUpdates');
      final stored = AppData.decode(jsonEncode(json));
      var calls = 0;
      final app = await _load(
        MemoryTimetableStorage(initialData: stored),
        () async {
          calls++;
          return '2.4.0-rc.1';
        },
      );
      expect(app.settingsView.includePrereleaseUpdates, isFalse);
      expect(calls, 0);
    },
  );
}
