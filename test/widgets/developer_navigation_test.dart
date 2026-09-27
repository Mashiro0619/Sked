import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/developer_mode_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/developer_ui_preferences.dart';
import 'package:sked/widgets/adaptive_navigation_scope.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

void _viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> _pumpSettings(
  WidgetTester t,
  TimetableProvider provider,
  DeveloperUiPreferences preferences,
) async {
  await t.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      developerUiPreferences: preferences,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            key: const ValueKey('launch-settings'),
            onPressed: () => unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    packageInfoLoader: () async => PackageInfo(
                      appName: 'Sked',
                      packageName: 'com.mashiro.sked.test',
                      version: '2.3.0-alpha.1',
                      buildNumber: '14',
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Open settings'),
          ),
        ),
      ),
    ),
  );
  await t.tap(_key('launch-settings'));
  await t.pumpAndSettle();
}

Future<void> _unlockDeveloper(WidgetTester t) async {
  final entry = _key('settings-check-for-updates');
  await t.ensureVisible(entry);
  await t.pumpAndSettle();
  final press = await t.startGesture(
    t.getCenter(entry),
    kind: PointerDeviceKind.mouse,
  );
  await t.pump(const Duration(seconds: 3));
  await press.up();
  await t.pumpAndSettle();
}

void main() {
  for (final secondary in [false, true]) {
    for (final (size, platform) in [
      (const Size(1440, 900), TargetPlatform.windows),
      (const Size(393, 852), TargetPlatform.android),
    ]) {
      testWidgets(
        'developer entry keeps settings navigator and one back button: secondary=$secondary $platform',
        (t) async {
          _viewport(t, size);
          final provider = await workspaceProvider();
          addTearDown(provider.dispose);
          final preferences = DeveloperUiPreferences.memory(visible: true);
          addTearDown(preferences.dispose);
          await _pumpSettings(t, provider, preferences);
          if (secondary) {
            await t.ensureVisible(_key('settings-about'));
            await t.pumpAndSettle();
            await t.tap(_key('settings-about'));
            await t.pumpAndSettle();
          }
          await t.ensureVisible(_key('settings-check-for-updates'));
          await t.pumpAndSettle();
          final origin = t.element(_key('settings-check-for-updates'));
          final navigator = Navigator.of(origin);
          final route = ModalRoute.of(origin);
          await _unlockDeveloper(t);
          final developer = find.byType(DeveloperModePage);
          expect(developer, findsOneWidget);
          expect(Navigator.of(t.element(developer)), same(navigator));
          expect(
            t.element(developer).read<DeveloperUiPreferences>(),
            same(preferences),
          );
          expect(find.byType(BackButton), findsOneWidget);
          final wide = platform == TargetPlatform.windows;
          expect(AdaptiveNavigationScope.isWide(t.element(developer)), wide);
          expect(
            _key('settings-category-about'),
            wide ? findsOneWidget : findsNothing,
          );
          final state = t.state(developer);
          if (wide) {
            t.view.physicalSize = const Size(393, 900);
            await t.pumpAndSettle();
            expect(t.state(developer), same(state));
            expect(find.byType(BackButton), findsOneWidget);
            expect(_key('settings-category-about'), findsNothing);
            t.view.physicalSize = size;
            await t.pumpAndSettle();
            expect(t.state(developer), same(state));
            expect(find.byType(BackButton), findsOneWidget);
          }
          if (wide) {
            await t.pageBack();
          } else {
            await t.binding.handlePopRoute();
          }
          await t.pumpAndSettle();
          expect(developer, findsNothing);
          final returned = t.element(_key('settings-check-for-updates'));
          expect(Navigator.of(returned), same(navigator));
          expect(ModalRoute.of(returned), same(route));
          // The flow guard must be released when the nested route closes.
          await _unlockDeveloper(t);
          expect(developer, findsOneWidget);
          expect(find.byType(BackButton), findsOneWidget);
          await t.pageBack();
          await t.pumpAndSettle();
          if (secondary) {
            await t.pageBack();
            await t.pumpAndSettle();
          }
          expect(
            find.byKey(const PageStorageKey('settings-overview-scroll')),
            findsOneWidget,
          );
          await t.pageBack();
          await t.pumpAndSettle();
          expect(_key('launch-settings'), findsOneWidget);
          expect(t.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  for (final secondary in [false, true]) {
    testWidgets(
      'developer page sidebar respects in-flight sample saves: secondary=$secondary',
      (t) async {
        _viewport(t, const Size(1440, 900));
        final storage = _DelayedSampleStorage(
          buildInitialAppData(buildDefaultPeriodTimes()),
        );
        final provider = await workspaceProvider(storage: storage);
        addTearDown(provider.dispose);
        final preferences = DeveloperUiPreferences.memory();
        addTearDown(preferences.dispose);
        await _pumpSettings(t, provider, preferences);
        if (secondary) {
          await t.ensureVisible(_key('settings-about'));
          await t.pumpAndSettle();
          await t.tap(_key('settings-about'));
          await t.pumpAndSettle();
        }
        await _unlockDeveloper(t);
        final developer = find.byType(DeveloperModePage);
        final state = t.state(developer);
        final barrier = Completer<void>();
        storage.barrier = barrier;
        addTearDown(() {
          if (!barrier.isCompleted) barrier.complete();
        });
        await t.tap(_key('developer-add-sample-data'));
        await t.pump();
        expect(storage.waiting, isTrue);
        expect(find.byType(BackButton), findsOneWidget);
        await t.pageBack();
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(t.state(developer), same(state));
        await t.tap(_key('settings-category-appearance'));
        await t.pump();
        await t.pump(const Duration(milliseconds: 100));
        expect(t.state(developer), same(state));
        barrier.complete();
        await t.pumpAndSettle();
        await t.pageBack();
        await t.pumpAndSettle();
        expect(developer, findsNothing);
        expect(_key('settings-check-for-updates'), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}

class _DelayedSampleStorage extends WorkspaceMemoryStorage {
  _DelayedSampleStorage(super.data);
  Completer<void>? barrier;
  bool waiting = false;

  @override
  Future<void> save(AppData value) async {
    if (barrier != null) {
      waiting = true;
      await barrier!.future;
      barrier = null;
      waiting = false;
    }
    await super.save(value);
  }
}
