import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/screens/language_settings_page.dart';
import 'package:sked/screens/timetable_display_settings_page.dart';
import 'package:sked/screens/general_display_settings_page.dart';
import 'package:sked/screens/notification_settings_page.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/workspace_harness.dart';

Finder k(String value) => find.byKey(ValueKey(value));
void viewport(WidgetTester t, Size size) {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
}

Future<void> choose(WidgetTester t, String key, String label) async {
  await t.ensureVisible(k(key));
  await t.pumpAndSettle();
  await t.tap(k(key));
  await t.pumpAndSettle();
  final option = find.text(label).last;
  await t.ensureVisible(option);
  await t.pumpAndSettle();
  await t.tap(option);
  await t.pumpAndSettle();
}

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);
  int writes = 0;
  @override
  Future<void> save(AppData data) async {
    writes++;
    await super.save(data);
  }
}

class _PendingGateway extends MemoryAgendaNotificationGateway {
  final pending = Completer<bool>();
  @override
  Future<bool> requestPermission() => pending.future;
}

class _Gateway extends MemoryAgendaNotificationGateway {
  int requests = 0;
  bool fail = false;
  bool Function()? persisted;
  @override
  Future<bool> requestPermission() async {
    expect(
      persisted?.call(),
      isTrue,
      reason: 'Permission is requested only after the preference is durable.',
    );
    requests++;
    if (fail) throw StateError('permission request unavailable');
    return super.requestPermission();
  }
}

void main() {
  const channel = MethodChannel(AndroidProductivityChannel.name);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets(
    'inline notification saving blocks toolbar and system back until the request settles',
    (t) async {
      viewport(t, const Size(393, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final gateway = _PendingGateway();
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(service.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(notificationService: service),
                  ),
                ),
                child: const Text('Open settings'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open settings'));
      await t.pumpAndSettle();
      await t.ensureVisible(k('notification-settings-enabled'));
      await t.pumpAndSettle();
      await t.tap(k('notification-settings-enabled'));
      await t.pump(const Duration(milliseconds: 200));
      expect(p.notificationsEnabled, isTrue);
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pump();
      expect(find.byType(SettingsPage), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(find.byType(SettingsPage), findsOneWidget);
      gateway.pending.complete(true);
      await t.pumpAndSettle();
      await t.tap(find.byType(BackButton).hitTestable().first);
      await t.pumpAndSettle();
      expect(find.text('Open settings'), findsOneWidget);
      expect(find.byType(SettingsPage), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
  for (final (size, scale, brightness) in [
    (const Size(320, 700), 2.0, Brightness.light),
    (const Size(393, 852), 1.3, Brightness.dark),
    (const Size(1280, 900), 1.0, Brightness.light),
  ]) {
    testWidgets(
      'overview has clear entries without advanced controls or per-row cards at $size/$scale/$brightness',
      (t) async {
        viewport(t, size);
        final p = await workspaceProvider(locale: 'zh');
        addTearDown(p.dispose);
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            locale: const Locale('zh'),
            textScale: scale,
            brightness: brightness,
            home: const SettingsPage(),
          ),
        );
        await t.pumpAndSettle();
        for (final id in [
          'appearance',
          'student',
          'general',
          'notifications',
          'features',
          'data',
          'about',
        ]) {
          expect(k('settings-overview-$id'), findsOneWidget);
          expect(
            t.widget<SettingsConnectedGroup>(k('settings-overview-$id')).tonal,
            isTrue,
          );
        }
        for (final id in [
          'theme-brightness-choice',
          'settings-theme-seed',
          'settings-language',
          'settings-student-display',
          'settings-period-times',
          'settings-general-display',
          'notification-settings-enabled',
          'settings-notifications',
          'settings-workspace-features',
          'settings-data-privacy',
          'settings-about',
        ]) {
          expect(k(id), findsOneWidget);
        }
        expect(
          find.byWidgetPredicate((w) => w is ThemeSettingsPage && !w.embedded),
          findsNothing,
        );
        for (final id in [
          'student-fit-week-columns-setting',
          'student-grid-lines-setting',
          'general-default-view',
          'general-show-weekends-setting',
          'general-show-lunar-setting',
          'general-custom-column-width-mode',
          'notification-course-default-reminder',
          'notification-general-default-reminder',
          'settings-clear-app-data',
        ]) {
          expect(k(id), findsNothing);
        }
        await t.ensureVisible(k('settings-student-display'));
        await t.pumpAndSettle();
        await t.tap(k('settings-student-display'));
        await t.pumpAndSettle();
        expect(find.byType(TimetableDisplaySettingsPage), findsOneWidget);
        final grid = k('student-grid-lines-setting');
        final previous = p.showTimetableGridLines;
        await t.ensureVisible(grid);
        await t.pumpAndSettle();
        await t.tap(grid);
        await t.pumpAndSettle();
        expect(p.showTimetableGridLines, !previous);
        await t.tap(find.byType(BackButton).hitTestable().first);
        await t.pumpAndSettle();
        expect(k('settings-overview-general'), findsOneWidget);
        await t.ensureVisible(k('settings-check-for-updates'));
        await t.pumpAndSettle();
        expect(k('settings-check-for-updates').hitTestable(), findsOneWidget);
        expect(t.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'custom column width previews locally, saves once, and resets to auto',
    (t) async {
      viewport(t, const Size(393, 900));
      final storage = _Storage(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
      );
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(k('settings-general-display'));
      await t.pumpAndSettle();
      await t.tap(k('settings-general-display'));
      await t.pumpAndSettle();
      await choose(t, 'general-custom-column-width-mode', 'Minimum width');
      expect(p.generalCustomDayMinWidth, 96);
      final slider = find.descendant(
        of: k('general-custom-column-width-slider'),
        matching: find.byType(Slider),
      );
      await t.ensureVisible(slider);
      final writes = storage.writes;
      t.widget<Slider>(slider).onChangeStart?.call(96);
      t.widget<Slider>(slider).onChanged!(160);
      await t.pump();
      expect(find.text('160 dp'), findsOneWidget);
      expect(storage.writes, writes);
      expect(p.generalCustomDayMinWidth, 96);
      t.widget<Slider>(slider).onChangeEnd!(160);
      await t.pumpAndSettle();
      expect(storage.writes, writes + 1);
      expect(p.generalCustomDayMinWidth, 160);
      await choose(t, 'general-custom-column-width-mode', 'Automatic');
      expect(p.generalCustomDayMinWidth, isNull);
      expect(k('general-custom-column-width-slider'), findsNothing);
      storage.saveError = StateError('disk full');
      await choose(t, 'general-custom-column-width-mode', 'Minimum width');
      expect(p.generalCustomDayMinWidth, isNull);
      expect(k('general-custom-column-width-slider'), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'appearance targets the chosen workspace and advanced pages return to the same overview position',
    (t) async {
      viewport(t, const Size(393, 900));
      final p = await workspaceProvider();
      addTearDown(p.dispose);
      final studentTheme = p.appData.studentMode.themeMode;
      await t.pumpWidget(
        WorkspaceHarness(provider: p, home: const SettingsPage()),
      );
      await t.pumpAndSettle();
      await choose(t, 'theme-workspace-target', 'Schedule');
      await choose(t, 'theme-brightness-choice', 'Dark');
      expect(p.activeMode, AppMode.student);
      expect(p.appData.generalMode.themeMode, 'dark');
      expect(p.appData.studentMode.themeMode, studentTheme);
      await t.tap(k('settings-theme-seed'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.text('Cancel').last);
      await t.pumpAndSettle();
      await t.ensureVisible(k('settings-language'));
      await t.pumpAndSettle();
      await t.tap(k('settings-language'));
      await t.pumpAndSettle();
      expect(find.byType(LanguageSettingsPage), findsOneWidget);
      await t.enterText(k('language-search'), 'Deutsch');
      await t.pumpAndSettle();
      await t.tap(k('language-option-de'));
      await t.pumpAndSettle();
      expect(p.localeCode, 'de');
      expect(find.byType(LanguageSettingsPage), findsNothing);
      final display = k('settings-general-display');
      await t.ensureVisible(display);
      await t.pumpAndSettle();
      final scroll = t
          .widget<ListView>(
            find.byKey(const PageStorageKey('settings-overview-scroll')),
          )
          .controller!;
      final offset = scroll.offset;
      await t.tap(display);
      await t.pumpAndSettle();
      expect(find.byType(GeneralDisplaySettingsPage), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      expect(scroll.offset, closeTo(offset, .01));
      expect(display.hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'notification master saves before permissions and defaults stay on their detail page',
    (t) async {
      viewport(t, const Size(393, 900));
      final storage = _Storage(
        buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'),
      );
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      final gateway = _Gateway()
        ..permissionGranted = false
        ..fail = true;
      gateway.persisted = () => storage.data.notificationSettings.enabled;
      final service = AgendaNotificationService(
        enabled: true,
        gateway: gateway,
        runtimeStore: MemoryAgendaNotificationRuntimeStore(),
      );
      addTearDown(service.dispose);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: SettingsPage(notificationService: service),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(k('notification-settings-enabled'));
      await t.pumpAndSettle();
      await t.tap(k('notification-settings-enabled'));
      await t.pumpAndSettle();
      expect(p.notificationsEnabled, isTrue);
      expect(gateway.requests, 1);
      expect(k('notification-course-default-reminder'), findsNothing);
      await t.ensureVisible(k('settings-notifications'));
      await t.pumpAndSettle();
      await t.tap(k('settings-notifications'));
      await t.pumpAndSettle();
      await choose(t, 'notification-course-default-reminder', '10 min before');
      await choose(t, 'notification-general-default-reminder', '5 min before');
      expect(p.courseDefaultReminderMinutesBefore, 10);
      expect(p.generalDefaultReminderMinutesBefore, 5);
      await t.ensureVisible(k('notification-troubleshooting'));
      await t.pumpAndSettle();
      await t.tap(k('notification-troubleshooting'));
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is NotificationSettingsPage && w.troubleshooting,
        ),
        findsOneWidget,
      );
      final permissions = t.widget<NotificationSettingsPage>(
        find.byWidgetPredicate(
          (w) => w is NotificationSettingsPage && w.troubleshooting,
        ),
      );
      expect(permissions.notificationService, same(service));
      expect(
        t.widget<IconButton>(k('notification-permission-action')).onPressed,
        isNotNull,
      );
      expect(find.text('Blocked by the system'), findsOneWidget);
      gateway.fail = false;
      await t.ensureVisible(k('notification-permission-action'));
      await t.pumpAndSettle();
      await t.tap(k('notification-permission-action'));
      await t.pumpAndSettle();
      expect(gateway.requests, 2);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
