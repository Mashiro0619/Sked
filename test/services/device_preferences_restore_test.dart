import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/services/desktop_layout_preferences.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/services/device_preferences_store.dart';

Map<String, Object?> _geometry(double width) => {
  'regions': {
    'assistant': {'width': width},
  },
};

class _PreferencesFixture {
  Object? geometry = jsonEncode({'version': 1, ..._geometry(280)});
  bool? preview = false;
  int geometryWrites = 0, previewWrites = 0;
  bool persistGeometry = true, acceptGeometry = true;
  Completer<void>? geometryGate, previewGate;
  final geometryStarted = Completer<void>(), previewStarted = Completer<void>();
  late final layout = DesktopLayoutPreferences(
    read: () async => geometry,
    write: (value) async {
      if (!geometryStarted.isCompleted) geometryStarted.complete();
      await geometryGate?.future;
      geometryWrites++;
      if (persistGeometry) geometry = value;
      return acceptGeometry;
    },
    remove: () async {
      geometryWrites++;
      geometry = null;
      return true;
    },
    saveDelay: const Duration(days: 1),
  );
  late final developer = DeveloperUiPreferences(
    read: () async => preview,
    write: (value) async {
      if (!previewStarted.isCompleted) previewStarted.complete();
      await previewGate?.future;
      previewWrites++;
      preview = value;
      return true;
    },
    remove: () async {
      previewWrites++;
      preview = null;
      return true;
    },
  );
  late final store = DevicePreferencesStore(
    layout: layout,
    developerUi: developer,
    platform: DevicePreferencePlatform.windows,
  );
  void dispose() {
    store.dispose();
    layout.dispose();
    developer.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('platform-tagged snapshots round-trip known fields and reject unrecognized settings', () {
    expect(
      DesktopLayoutRegion.values.map((region) => region.name).toSet(),
      deviceLayoutRegionNames,
    );
    final original = PortableDevicePreferences(
      platform: DevicePreferencePlatform.windows,
      group: DevicePreferenceGroup.desktopLayout,
      values: _geometry(520),
    );
    final restored = PortableDevicePreferences.fromJson(
      jsonDecode(jsonEncode(original.toJson())),
    );
    expect(restored.toJson(), original.toJson());
    expect(restored.id, 'windows.desktopLayout');
    for (final invalid in [
      {...original.toJson(), 'permission': 'granted'},
      {...original.toJson(), 'platform': 'other'},
      {...original.toJson(), 'group': 'nativePermissions'},
      {...original.toJson(), 'version': 2},
      {
        ...original.toJson(),
        'values': {
          'regions': {
            'unknown': {'width': 25},
          },
        },
      },
      {
        ...original.toJson(),
        'values': {
          'regions': {
            'assistant': {'width': 0},
          },
        },
      },
      {
        ...original.toJson(),
        'values': {
          'regions': {
            'assistant': {'path': 'private'},
          },
        },
      },
      {
        ...original.toJson(),
        'group': 'developerUi',
        'values': {'assistantPreviewEnabled': 'yes'},
      },
    ]) {
      expect(
        () => PortableDevicePreferences.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test(
    'both live owners freeze immediately and drain previously accepted writes',
    () async {
      final fixture = _PreferencesFixture();
      addTearDown(fixture.dispose);
      await fixture.layout.load();
      await fixture.developer.load();
      fixture.geometryGate = Completer<void>();
      fixture.previewGate = Completer<void>();
      fixture.layout.setPreferredSize(
        DesktopLayoutRegion.assistant,
        const PreferredRegionSize(width: 360),
      );
      final previewSave = fixture.developer.setAssistantVisible(true);
      await fixture.previewStarted.future;
      var drained = false;
      final draining = fixture.store.freezeAndDrain().then(
        (_) => drained = true,
      );
      await fixture.geometryStarted.future;
      fixture.layout.setPreferredSize(
        DesktopLayoutRegion.assistant,
        const PreferredRegionSize(width: 900),
      );
      expect(await fixture.developer.setAssistantVisible(false), isFalse);
      expect(
        fixture.layout.preferenceFor(DesktopLayoutRegion.assistant)?.width,
        360,
      );
      fixture.geometryGate!.complete();
      await fixture.layout.flush();
      expect(drained, isFalse);
      fixture.previewGate!.complete();
      expect(await previewSave, isTrue);
      await draining;
      expect(await fixture.store.readAll(), {
        DevicePreferenceGroup.desktopLayout: _geometry(360),
        DevicePreferenceGroup.developerUi: {'assistantPreviewEnabled': true},
      });
      fixture.store.resume();
      expect(await fixture.developer.setAssistantVisible(false), isTrue);
      expect(fixture.previewWrites, 2);
    },
  );

  test('restoring a chosen group persists it and publishes it to the same UI owner', () async {
    final fixture = _PreferencesFixture();
    addTearDown(fixture.dispose);
    await fixture.store.freezeAndDrain();
    await fixture.store.restoreGroup(
      DevicePreferenceGroup.desktopLayout,
      _geometry(520),
      validateOwner: () {},
    );
    expect(
      await fixture.store.readGroup(DevicePreferenceGroup.desktopLayout),
      _geometry(520),
    );
    expect(fixture.store.layout, same(fixture.layout));
    expect(
      fixture.layout.preferenceFor(DesktopLayoutRegion.assistant)?.width,
      520,
    );
    expect(fixture.geometryWrites, 1);
    expect(fixture.previewWrites, 0);
    expect(fixture.preview, isFalse);
  });

  test(
    'restore requires both a frozen store and the callers live ownership',
    () async {
      final fixture = _PreferencesFixture();
      addTearDown(fixture.dispose);
      expect(
        () => fixture.store.restoreGroup(
          DevicePreferenceGroup.desktopLayout,
          _geometry(520),
          validateOwner: () {},
        ),
        throwsStateError,
      );
      await fixture.store.freezeAndDrain();
      expect(
        () => fixture.store.restoreGroup(
          DevicePreferenceGroup.desktopLayout,
          _geometry(520),
          validateOwner: () => throw StateError('expired owner'),
        ),
        throwsStateError,
      );
      expect(fixture.geometryWrites, 0);
      expect(fixture.previewWrites, 0);
    },
  );

  test(
    'a successful write reply cannot substitute for persisted readback',
    () async {
      final fixture = _PreferencesFixture()..persistGeometry = false;
      addTearDown(fixture.dispose);
      await fixture.store.freezeAndDrain();
      await expectLater(
        fixture.store.restoreGroup(
          DevicePreferenceGroup.desktopLayout,
          _geometry(520),
          validateOwner: () {},
        ),
        throwsStateError,
      );
      expect(
        await fixture.store.readGroup(DevicePreferenceGroup.desktopLayout),
        _geometry(280),
      );
      expect(
        fixture.layout.preferenceFor(DesktopLayoutRegion.assistant)?.width,
        280,
      );
      fixture.persistGeometry = true;
      await fixture.store.restoreGroup(
        DevicePreferenceGroup.desktopLayout,
        _geometry(520),
        validateOwner: () {},
      );
      expect(
        await fixture.store.readGroup(DevicePreferenceGroup.desktopLayout),
        _geometry(520),
      );
    },
  );

  test('a rejected acknowledgement retains the actual stored result for its caller to reconcile', () async {
    final fixture = _PreferencesFixture()..acceptGeometry = false;
    addTearDown(fixture.dispose);
    await fixture.store.freezeAndDrain();
    await expectLater(
      fixture.store.restoreGroup(
        DevicePreferenceGroup.desktopLayout,
        _geometry(520),
        validateOwner: () {},
      ),
      throwsStateError,
    );
    expect(
      await fixture.store.readGroup(DevicePreferenceGroup.desktopLayout),
      _geometry(520),
    );
    expect(fixture.geometryWrites, 1);
  });

  test('malformed stored device fields fail reading without replacing them with defaults', () async {
    for (final raw in [
      {'version': 1, 'regions': <String, Object?>{}},
      jsonEncode({
        'version': 1,
        'regions': {
          'unknownRole': {'width': 25},
        },
      }),
      jsonEncode({'version': 1, 'regions': {}, 'permission': 'granted'}),
    ]) {
      final fixture = _PreferencesFixture()..geometry = raw;
      try {
        await expectLater(
          fixture.store.readGroup(DevicePreferenceGroup.desktopLayout),
          throwsFormatException,
        );
        expect(fixture.geometryWrites, 0);
        expect(fixture.geometry, raw);
      } finally {
        fixture.dispose();
      }
    }
  });

  test('SharedPreferences snapshots survive new owners and explicit defaults remove only their keys', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('unrelated.test.value', 'keep');
    final first = DevicePreferencesStore(
      platform: DevicePreferencePlatform.windows,
    );
    addTearDown(first.dispose);
    await first.freezeAndDrain();
    await first.restoreGroup(
      DevicePreferenceGroup.desktopLayout,
      _geometry(520),
      validateOwner: () {},
    );
    await first.restoreGroup(DevicePreferenceGroup.developerUi, {
      'assistantPreviewEnabled': true,
    }, validateOwner: () {});
    first.resume();
    final reopened = DevicePreferencesStore(
      platform: DevicePreferencePlatform.windows,
    );
    addTearDown(reopened.dispose);
    expect(await reopened.readAll(), {
      DevicePreferenceGroup.desktopLayout: _geometry(520),
      DevicePreferenceGroup.developerUi: {'assistantPreviewEnabled': true},
    });
    await reopened.freezeAndDrain();
    await reopened.restoreGroup(DevicePreferenceGroup.desktopLayout, {
      'regions': {},
    }, validateOwner: () {});
    await reopened.restoreGroup(DevicePreferenceGroup.developerUi, {
      'assistantPreviewEnabled': null,
    }, validateOwner: () {});
    expect(
      preferences.containsKey(DesktopLayoutPreferences.storageKey),
      isFalse,
    );
    expect(preferences.containsKey(DeveloperUiPreferences.storageKey), isFalse);
    expect(preferences.getString('unrelated.test.value'), 'keep');
  });

  test('a frozen store cannot replace its live owners and borrowed owners outlive the binding', () async {
    final fixture = _PreferencesFixture();
    addTearDown(fixture.dispose);
    final replacement = DevicePreferencesStore.memory();
    addTearDown(replacement.dispose);
    final store = DevicePreferencesStore();
    store.bindServices(layout: fixture.layout, developerUi: fixture.developer);
    await store.freezeAndDrain();
    expect(
      () => store.bindServices(
        layout: replacement.layout,
        developerUi: replacement.developerUi,
      ),
      throwsStateError,
    );
    store.resume();
    store.dispose();
    await fixture.developer.load();
    expect(await fixture.developer.setAssistantVisible(true), isTrue);
  });
}
