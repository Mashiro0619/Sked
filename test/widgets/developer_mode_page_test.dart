import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/developer_mode_page.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/services/agenda_coordinator.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/developer_sample_data_service.dart';

class _DeveloperPageStorage implements TimetableStorage {
  _DeveloperPageStorage(this.data);

  AppData? data;
  Object? nextSaveError;
  Completer<void>? nextSaveBarrier;
  var saveCount = 0;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData next) async {
    saveCount += 1;
    final barrier = nextSaveBarrier;
    nextSaveBarrier = null;
    if (barrier != null) await barrier.future;
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) throw error;
    data = next;
  }

  @override
  Future<String?> filePath() async => 'memory://developer-mode-page';
}

Future<(TimetableProvider, _DeveloperPageStorage)> _createProvider({
  String localeCode = 'en',
}) async {
  final storage = _DeveloperPageStorage(
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: localeCode),
  );
  final provider = TimetableProvider(
    storage: storage,
    systemLocaleCodeResolver: () => localeCode,
  );
  await provider.load();
  storage.saveCount = 0;
  return (provider, storage);
}

Future<void> _pumpDeveloperPage(
  WidgetTester tester,
  TimetableProvider provider, {
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
  AgendaCoordinator? agendaCoordinator,
  AndroidProductivityBridge? productivityBridge,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: DeveloperModePage(
              agendaCoordinator: agendaCoordinator,
              productivityBridge: productivityBridge,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpSettingsPage(
  WidgetTester tester,
  TimetableProvider provider,
) async {
  PackageInfo.setMockInitialValues(
    appName: 'Sked',
    packageName: 'com.example.sked',
    version: '2.1.0',
    buildNumber: '10',
    buildSignature: '',
  );
  await tester.pumpWidget(
    ChangeNotifierProvider<TimetableProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('settings-check-for-updates')),
  );
  await tester.pumpAndSettle();
}

Set<DeveloperSampleLanguage> _selectedLanguage(WidgetTester tester) {
  return tester
      .widget<SegmentedButton<DeveloperSampleLanguage>>(
        find.byKey(const ValueKey('developer-sample-language')),
      )
      .selected;
}

const _productivityChannel = MethodChannel(AndroidProductivityChannel.name);

void _mockAndroidNotificationDiagnostics({
  required bool notificationsEnabled,
  required bool exactAlarmsAllowed,
  bool? postNotificationsGranted,
  List<Map<String, Object?>> channels = const [],
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_productivityChannel, (call) async {
        if (call.method ==
            AndroidProductivityChannel.getNotificationDiagnostics) {
          return <String, Object?>{
            'supported': true,
            'appNotificationsEnabled': notificationsEnabled,
            'postNotificationsGranted':
                postNotificationsGranted ?? notificationsEnabled,
            'exactAlarmsAllowed': exactAlarmsAllowed,
            'channels': channels,
          };
        }
        return null;
      });
}

AgendaCoordinator _developerNotificationCoordinator(
  TimetableProvider provider,
  MemoryAgendaNotificationGateway gateway, {
  MemoryAgendaNotificationRuntimeStore? runtimeStore,
}) {
  return AgendaCoordinator(
    provider: provider,
    notificationService: AgendaNotificationService(
      enabled: true,
      gateway: gateway,
      runtimeStore: runtimeStore ?? MemoryAgendaNotificationRuntimeStore(),
    ),
    productivityBridge: AndroidProductivityBridge(enabled: false),
  );
}

AgendaNotificationDiagnostics _developerNotificationDiagnostics({
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  return AgendaNotificationDiagnostics(
    recordedAt: current,
    mode: AgendaNotificationReconcileMode.maintenance,
    origin: AgendaNotificationReconcileOrigin.background,
    result: AgendaNotificationDiagnosticResult.success,
    notificationsEnabled: false,
    exactAlarmsAllowed: false,
    plannedCount: 205,
    scheduledCount: 200,
    truncatedCount: 5,
    retainedPendingCount: 1,
    plan: [
      AgendaNotificationDiagnosticPlanItem(
        key: 'course:next',
        fireAt: current.add(const Duration(minutes: 5)),
        sourceType: 'course',
      ),
    ],
    nextMaintenanceAt: current.add(const Duration(days: 1)),
    platformPendingCount: 200,
    platformActiveCount: 3,
    platformSampledAt: current,
  );
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_productivityChannel, null);
  });

  testWidgets('developer page follows the Chinese app locale at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final (provider, _) = await _createProvider(localeCode: 'zh');
    addTearDown(provider.dispose);

    await _pumpDeveloperPage(
      tester,
      provider,
      locale: const Locale('zh'),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('开发者模式'), findsWidgets);
    expect(find.text('示例数据语言'), findsOneWidget);
    expect(find.text('添加示例数据'), findsOneWidget);
    expect(_selectedLanguage(tester), {
      DeveloperSampleLanguage.simplifiedChinese,
    });
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('developer page adds the selected samples and stays open', (
    tester,
  ) async {
    final (provider, storage) = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpDeveloperPage(tester, provider);

    expect(_selectedLanguage(tester), {DeveloperSampleLanguage.english});
    await tester.tap(find.text('中文'));
    await tester.pump();
    expect(_selectedLanguage(tester), {
      DeveloperSampleLanguage.simplifiedChinese,
    });

    await tester.tap(find.byKey(const ValueKey('developer-add-sample-data')));
    await tester.pumpAndSettle();

    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(1));
    expect(provider.generalSchedules, hasLength(4));
    expect(find.byType(DeveloperModePage), findsOneWidget);
    expect(
      find.text('Sample timetable and schedule data added.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'developer page retains selection and allows retry after failure',
    (tester) async {
      final (provider, storage) = await _createProvider();
      addTearDown(provider.dispose);
      storage.nextSaveError = StateError('save failed');
      await _pumpDeveloperPage(tester, provider);

      final addTile = find.byKey(const ValueKey('developer-add-sample-data'));
      await tester.tap(addTile);
      await tester.pumpAndSettle();

      expect(storage.saveCount, 1);
      expect(provider.timetables, isEmpty);
      expect(find.text('Save failed. Please try again later.'), findsOneWidget);
      expect(tester.widget<FilledButton>(addTile).onPressed, isNotNull);
      expect(_selectedLanguage(tester), {DeveloperSampleLanguage.english});

      await tester.tap(addTile);
      await tester.pumpAndSettle();
      expect(storage.saveCount, 2);
      expect(provider.timetables, hasLength(1));
      expect(
        find.text('Sample timetable and schedule data added.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('developer page blocks repeated adds while saving', (
    tester,
  ) async {
    final (provider, storage) = await _createProvider();
    addTearDown(provider.dispose);
    final saveBarrier = Completer<void>();
    storage.nextSaveBarrier = saveBarrier;
    addTearDown(() {
      if (!saveBarrier.isCompleted) saveBarrier.complete();
    });
    await _pumpDeveloperPage(tester, provider);

    final addButton = find.byKey(const ValueKey('developer-add-sample-data'));
    await tester.tap(addButton);
    await tester.pump();

    expect(storage.saveCount, 1);
    expect(tester.widget<FilledButton>(addButton).onPressed, isNull);
    expect(
      tester.widget<PopScope<void>>(find.byType(PopScope<void>)).canPop,
      isFalse,
    );

    await tester.tap(addButton);
    await tester.pump();
    expect(storage.saveCount, 1);

    saveBarrier.complete();
    await tester.pumpAndSettle();
    expect(storage.saveCount, 1);
    expect(provider.timetables, hasLength(1));
  });

  testWidgets('notification diagnostics safely degrade outside Android', (
    tester,
  ) async {
    final (provider, _) = await _createProvider();
    addTearDown(provider.dispose);
    final bridge = AndroidProductivityBridge(enabled: false);
    addTearDown(bridge.dispose);

    await _pumpDeveloperPage(tester, provider, productivityBridge: bridge);

    expect(
      find.byKey(const ValueKey('developer-notification-unsupported')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('developer-notification-immediate-test')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('developer-notification-thirty-second-test')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('developer-notification-immediate-test')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(
              const ValueKey('developer-notification-thirty-second-test'),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'notification diagnostics show Android channel state through the bridge',
    (tester) async {
      final (provider, _) = await _createProvider();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = _developerNotificationCoordinator(provider, gateway);
      addTearDown(coordinator.dispose);
      final bridge = AndroidProductivityBridge(
        channel: _productivityChannel,
        enabled: true,
      );
      addTearDown(bridge.dispose);
      _mockAndroidNotificationDiagnostics(
        notificationsEnabled: false,
        exactAlarmsAllowed: false,
        channels: const [
          <String, Object?>{
            'id': 'sked_course_reminders',
            'name': 'Course reminders',
            'exists': true,
            'enabled': true,
            'importance': 4,
          },
          <String, Object?>{
            'id': 'sked_schedule_reminders',
            'name': 'Schedule reminders',
            'exists': true,
            'enabled': false,
            'importance': 0,
          },
        ],
      );

      await _pumpDeveloperPage(
        tester,
        provider,
        agendaCoordinator: coordinator,
        productivityBridge: bridge,
      );

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('Inexact fallback'), findsOneWidget);
      expect(find.text('Course reminders'), findsWidgets);
      expect(find.text('Schedule reminders'), findsWidgets);
      expect(find.textContaining('Importance: 4'), findsOneWidget);
      expect(find.textContaining('Importance: 0'), findsOneWidget);
      expect(
        find.text(
          'Tests are unavailable because system notifications are blocked.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'developer-notification-channel-sked_schedule_reminders',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notification diagnostics show the runtime plan and latest background result',
    (tester) async {
      final (provider, _) = await _createProvider();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final runtimeStore = MemoryAgendaNotificationRuntimeStore()
        ..diagnostics = _developerNotificationDiagnostics();
      final coordinator = _developerNotificationCoordinator(
        provider,
        gateway,
        runtimeStore: runtimeStore,
      );
      addTearDown(coordinator.dispose);
      final bridge = AndroidProductivityBridge(
        channel: _productivityChannel,
        enabled: true,
      );
      addTearDown(bridge.dispose);
      _mockAndroidNotificationDiagnostics(
        notificationsEnabled: true,
        exactAlarmsAllowed: false,
      );

      await _pumpDeveloperPage(
        tester,
        provider,
        agendaCoordinator: coordinator,
        productivityBridge: bridge,
      );

      expect(
        find.byKey(const ValueKey('developer-notification-app-switch-status')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Disabled for normal reminders; developer tests can still run',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('developer-notification-time-zone')),
        findsOneWidget,
      );
      expect(find.text('200 scheduled, 205 planned'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('developer-notification-next-reminder')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('developer-notification-next-maintenance')),
        findsOneWidget,
      );
      expect(find.text('5 omitted by the plan limit'), findsOneWidget);
      expect(
        find.textContaining('Background · Maintenance · Succeeded'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'developer-notification-channel-sked_course_reminders',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'developer-notification-channel-sked_schedule_reminders',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Not created yet. A developer test will create it.'),
        findsNWidgets(2),
      );
    },
  );

  testWidgets(
    'notification diagnostics localize Simplified and Traditional Chinese',
    (tester) async {
      final (provider, _) = await _createProvider(localeCode: 'zh');
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = _developerNotificationCoordinator(provider, gateway);
      addTearDown(coordinator.dispose);
      final bridge = AndroidProductivityBridge(
        channel: _productivityChannel,
        enabled: true,
      );
      addTearDown(bridge.dispose);
      _mockAndroidNotificationDiagnostics(
        notificationsEnabled: true,
        exactAlarmsAllowed: true,
      );

      await _pumpDeveloperPage(
        tester,
        provider,
        locale: const Locale('zh'),
        agendaCoordinator: coordinator,
        productivityBridge: bridge,
      );
      expect(find.text('应用提醒开关'), findsOneWidget);
      expect(find.text('本地时区'), findsOneWidget);

      await _pumpDeveloperPage(
        tester,
        provider,
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
        agendaCoordinator: coordinator,
        productivityBridge: bridge,
      );
      expect(find.text('應用程式提醒開關'), findsOneWidget);
      expect(find.text('本地時區'), findsOneWidget);
    },
  );

  testWidgets(
    'notification diagnostic tests block a disabled selected channel',
    (tester) async {
      final (provider, _) = await _createProvider();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = _developerNotificationCoordinator(provider, gateway);
      addTearDown(coordinator.dispose);
      final bridge = AndroidProductivityBridge(
        channel: _productivityChannel,
        enabled: true,
      );
      addTearDown(bridge.dispose);
      _mockAndroidNotificationDiagnostics(
        notificationsEnabled: true,
        exactAlarmsAllowed: true,
        channels: const [
          <String, Object?>{
            'id': 'sked_course_reminders',
            'name': 'Course reminders',
            'exists': true,
            'enabled': true,
            'importance': 4,
          },
          <String, Object?>{
            'id': 'sked_schedule_reminders',
            'name': 'Schedule reminders',
            'exists': true,
            'enabled': false,
            'importance': 0,
          },
        ],
      );

      await _pumpDeveloperPage(
        tester,
        provider,
        agendaCoordinator: coordinator,
        productivityBridge: bridge,
      );

      final channelSelector = find.byKey(
        const ValueKey('developer-notification-test-channel'),
      );
      await tester.ensureVisible(channelSelector);
      await tester.pumpAndSettle();
      final scheduleSegment = find.descendant(
        of: channelSelector,
        matching: find.text('Schedule reminders'),
      );
      await tester.tap(scheduleSegment);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Tests are unavailable because the selected notification channel is blocked.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(
                const ValueKey('developer-notification-immediate-test'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                const ValueKey('developer-notification-thirty-second-test'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(gateway.testNotifications, isEmpty);
    },
  );

  testWidgets(
    'notification diagnostic tests use the coordinator-owned service',
    (tester) async {
      final (provider, _) = await _createProvider();
      addTearDown(provider.dispose);
      final gateway = MemoryAgendaNotificationGateway();
      final coordinator = _developerNotificationCoordinator(provider, gateway);
      addTearDown(coordinator.dispose);
      final bridge = AndroidProductivityBridge(
        channel: _productivityChannel,
        enabled: true,
      );
      addTearDown(bridge.dispose);
      _mockAndroidNotificationDiagnostics(
        notificationsEnabled: true,
        exactAlarmsAllowed: true,
      );

      await _pumpDeveloperPage(
        tester,
        provider,
        agendaCoordinator: coordinator,
        productivityBridge: bridge,
      );

      final immediateButton = find.byKey(
        const ValueKey('developer-notification-immediate-test'),
      );
      await tester.ensureVisible(immediateButton);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(immediateButton).onPressed, isNotNull);
      await tester.tap(immediateButton);
      await tester.pumpAndSettle();
      expect(gateway.testNotifications, hasLength(1));
      final immediate = gateway.testNotifications.values.single;
      expect(immediate.channel, AgendaNotificationTestChannel.course);
      expect(immediate.fireAt, isNull);

      final scheduleChannel = find.descendant(
        of: find.byKey(const ValueKey('developer-notification-test-channel')),
        matching: find.text('Schedule reminders'),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('developer-notification-test-channel')),
      );
      await tester.pumpAndSettle();
      await tester.tap(scheduleChannel);
      await tester.pumpAndSettle();
      final delayedButton = find.byKey(
        const ValueKey('developer-notification-thirty-second-test'),
      );
      await tester.ensureVisible(delayedButton);
      await tester.pumpAndSettle();
      await tester.tap(delayedButton);
      await tester.pumpAndSettle();
      expect(gateway.testNotifications, hasLength(2));
      final delayed = gateway.testNotifications.values.singleWhere(
        (request) => request.channel == AgendaNotificationTestChannel.schedule,
      );
      expect(delayed.fireAt, isNotNull);
      expect(
        delayed.fireAt!.difference(DateTime.now()).inSeconds,
        inInclusiveRange(25, 30),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('developer entry unlocks at three seconds but not at 2999ms', (
    tester,
  ) async {
    final (provider, _) = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpSettingsPage(tester, provider);
    final entry = find.byKey(const ValueKey('settings-check-for-updates'));
    final center = tester.getCenter(entry);

    final shortPress = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.byType(DeveloperModePage), findsNothing);
    await shortPress.cancel();
    await tester.pump();

    final unlockPress = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.byType(DeveloperModePage), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await unlockPress.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DeveloperModePage), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DeveloperModePage), findsOneWidget);
  });

  testWidgets('developer entry ignores right click and accepts mouse primary', (
    tester,
  ) async {
    final (provider, _) = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpSettingsPage(tester, provider);
    final entry = find.byKey(const ValueKey('settings-check-for-updates'));
    final center = tester.getCenter(entry);

    final secondaryPress = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pump(const Duration(seconds: 4));
    await secondaryPress.up();
    await tester.pump();
    expect(find.byType(DeveloperModePage), findsNothing);

    final primaryPress = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(seconds: 3));
    await primaryPress.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DeveloperModePage), findsOneWidget);
  });

  testWidgets('developer entry cancels on early release and drag', (
    tester,
  ) async {
    final (provider, _) = await _createProvider();
    addTearDown(provider.dispose);
    await _pumpSettingsPage(tester, provider);
    final entry = find.byKey(const ValueKey('settings-check-for-updates'));
    final center = tester.getCenter(entry);

    final earlyRelease = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 2999));
    await earlyRelease.up();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DeveloperModePage), findsNothing);

    final draggedPress = await tester.startGesture(center);
    await tester.pump(const Duration(seconds: 1));
    await draggedPress.moveBy(const Offset(0, -96));
    await tester.pump(const Duration(seconds: 3));
    await draggedPress.up();
    await tester.pump();
    expect(find.byType(DeveloperModePage), findsNothing);
  });
}
