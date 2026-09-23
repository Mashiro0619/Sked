import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/desktop_window_bridge.dart';
import 'package:sked/widgets/desktop_window_host.dart';

import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));

class _StartupStorage extends WorkspaceMemoryStorage {
  _StartupStorage({this.recovery = false})
    : super(buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'));

  final bool recovery;
  int writes = 0;

  @override
  Future<StorageLoadResult> load() async => recovery
      ? const StorageLoadResult(
          data: null,
          recoveryStatus: RecoveryStatus.failedBackupRestore,
        )
      : await super.load();

  @override
  Future<void> save(AppData value) async {
    writes++;
    await super.save(value);
  }
}

Future<TimetableProvider> _pumpStartup(
  WidgetTester t, {
  Size size = const Size(1280, 800),
  double scale = 1,
  bool loaded = true,
  _StartupStorage? storage,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  final source = storage ?? _StartupStorage();
  final provider = loaded
      ? await workspaceProvider(storage: source)
      : TimetableProvider(storage: source);
  addTearDown(provider.dispose);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      textScale: scale,
      home: const AppHomeScreen(),
    ),
  );
  if (loaded) {
    await t.pumpAndSettle();
  } else {
    await t.pump();
  }
  return provider;
}

Future<void> _mouseDrag(WidgetTester t, Offset point) async {
  await t.dragFrom(point, const Offset(80, 20), kind: PointerDeviceKind.mouse);
  // Let the shared double-tap recognizer retire its short-lived tracker.
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  const windowChannel = MethodChannel('com.mashiro.sked/window');
  const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final calls = <String>[];
  final launches = <MethodCall>[];

  setUp(() async {
    calls.clear();
    launches.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, (call) async {
          calls.add(call.method);
          return call.method == 'initialize'
              ? {'maximized': false, 'focused': true}
              : null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlChannel, (call) async {
          launches.add(call);
          return true;
        });
    await DesktopWindowBridge.instance.initialize();
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    DesktopWindowBridge.instance.available = false;
    DesktopWindowBridge.instance.prepareClose = null;
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, null);
    messenger.setMockMethodCallHandler(urlChannel, null);
  });

  for (final (size, scale) in [
    (const Size(1280, 800), 1.0),
    (const Size(640, 560), 1.0),
    (const Size(480, 420), 2.0),
  ]) {
    testWidgets('first launch has one native drag row at $size / $scale', (
      t,
    ) async {
      final storage = _StartupStorage();
      final p = await _pumpStartup(
        t,
        size: size,
        scale: scale,
        storage: storage,
      );
      expect(k('first-launch-onboarding'), findsOneWidget);
      final toolbar = t.getRect(k('startup-window-toolbar'));
      final minimize = t.getRect(find.bySemanticsLabel('Minimize'));
      expect(toolbar.top, 0);
      expect(toolbar.height, minimize.height);
      expect(t.getRect(k('first-launch-scroll-view')).top, toolbar.bottom);
      expect(find.byType(WorkbenchAppBar), findsOneWidget);
      final writes = storage.writes;
      for (final x in [40.0, minimize.left / 2, minimize.left - 20]) {
        calls.clear();
        await _mouseDrag(t, Offset(x, toolbar.center.dy));
        expect(calls.where((value) => value == 'startDrag'), hasLength(1));
      }
      expect(storage.writes, writes);
      expect(p.acceptedPrivacyPolicyVersion, isNull);
      expect(t.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
  }

  testWidgets(
    'startup blank caption retains double click, system menu and buttons',
    (t) async {
      await _pumpStartup(t);
      final point = t.getRect(k('startup-window-toolbar')).center;
      calls.clear();
      await t.tapAt(point, kind: PointerDeviceKind.mouse);
      await t.pump(const Duration(milliseconds: 80));
      await t.tapAt(point, kind: PointerDeviceKind.mouse);
      await t.pump();
      expect(calls.where((value) => value == 'toggleMaximize'), hasLength(1));
      calls.clear();
      final secondary = await t.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await secondary.down(point);
      await secondary.up();
      await t.pump();
      expect(calls, contains('systemMenu'));
      final l = AppLocalizations.of(t.element(k('startup-window-toolbar')));
      for (final (label, command) in [
        (l.minimizeWindow, 'minimize'),
        (l.maximizeWindow, 'toggleMaximize'),
        (l.closeWindow, 'confirmClose'),
      ]) {
        calls.clear();
        await t.tap(find.bySemanticsLabel(label));
        await t.pumpAndSettle();
        expect(calls.where((value) => value == command), hasLength(1));
        expect(calls, isNot(contains('startDrag')));
      }
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'onboarding content and privacy link do not drag or accept a mode',
    (t) async {
      final storage = _StartupStorage();
      final p = await _pumpStartup(t, storage: storage);
      final writes = storage.writes;
      calls.clear();
      await _mouseDrag(t, const Offset(16, 170));
      final privacy = k('first-launch-privacy-consent');
      final paragraph = t.renderObject<RenderParagraph>(privacy);
      final start = paragraph.text.toPlainText().indexOf('Privacy Policy');
      expect(start, greaterThanOrEqualTo(0));
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: start,
              extentOffset: start + 'Privacy Policy'.length,
            ),
          )
          .first
          .toRect();
      await t.tapAt(
        paragraph.localToGlobal(box.center),
        kind: PointerDeviceKind.mouse,
      );
      await t.pumpAndSettle();
      expect(launches, hasLength(1));
      expect(p.acceptedPrivacyPolicyVersion, isNull);
      expect(storage.writes, writes);
      expect(calls, isNot(contains('startDrag')));
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final (card, mode, enabled) in [
    ('student', AppMode.student, {AppMode.student}),
    ('general', AppMode.general, {AppMode.general}),
    ('both', AppMode.student, AppMode.values.toSet()),
  ]) {
    testWidgets(
      'startup $card choice still completes onboarding without window gestures',
      (t) async {
        final p = await _pumpStartup(t);
        calls.clear();
        await t.tap(k('first-launch-$card-card'));
        await t.pumpAndSettle();
        expect(p.acceptedPrivacyPolicyVersion, isNotNull);
        expect(p.activeMode, mode);
        expect(p.enabledWorkspaces.toSet(), enabled);
        expect(k('first-launch-onboarding'), findsNothing);
        expect(k('startup-window-toolbar'), findsNothing);
        expect(calls, isNot(contains('startDrag')));
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final loaded in [false, true]) {
    testWidgets(
      'startup drag also works while ${loaded ? 'recovering data' : 'loading'}',
      (t) async {
        final storage = _StartupStorage(recovery: loaded);
        await _pumpStartup(t, loaded: loaded, storage: storage);
        expect(
          loaded
              ? k('data-recovery-screen')
              : find.byType(CircularProgressIndicator),
          findsOneWidget,
        );
        calls.clear();
        await _mouseDrag(t, t.getRect(k('startup-window-toolbar')).center);
        expect(calls.where((value) => value == 'startDrag'), hasLength(1));
        expect(storage.writes, 0);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'no extra startup caption on $platform without active native chrome',
      (t) async {
        if (platform == TargetPlatform.windows) {
          DesktopWindowBridge.instance.available = false;
        }
        await _pumpStartup(t, size: const Size(393, 852));
        expect(k('first-launch-onboarding'), findsOneWidget);
        expect(k('startup-window-toolbar'), findsNothing);
        expect(find.bySemanticsLabel('Minimize'), findsNothing);
        expect(t.getRect(k('first-launch-scroll-view')).top, 0);
        calls.clear();
        await _mouseDrag(t, const Offset(50, 24));
        expect(calls, isNot(contains('startDrag')));
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }
}
