import '../support/agenda_notification_memory.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/app_scope.dart';
import 'package:sked/screens/notification_settings_page.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/services/notification_planner.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/data_transfer_codec.dart';

class _MemoryStorage implements TimetableStorage {
  _MemoryStorage(this.data);

  AppData data;

  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);

  @override
  Future<void> save(AppData value) async => data = value;

  @override
  Future<String?> filePath() async => 'memory://windows-coverage-notice';
}

class _CoverageService extends ChangeNotifier
    implements AgendaNotificationService {
  _CoverageService({required this.status, int capacity = 200})
    : planner = NotificationPlanner(maxScheduledNotifications: capacity);

  @override
  AgendaNotificationStatus status;

  @override
  final gateway = MemoryAgendaNotificationGateway();

  @override
  final NotificationPlanner planner;

  @override
  bool get isSupported => true;

  @override
  int? get schedulingWindowDays =>
      defaultTargetPlatform == TargetPlatform.windows ? 14 : null;

  void publish(AgendaNotificationStatus value) {
    status = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AgendaNotificationStatus _status({
  int count = 0,
  DateTime? end,
  AgendaNotificationCoverage coverage = AgendaNotificationCoverage.ready,
  bool overflow = false,
  Object? error,
}) => AgendaNotificationStatus(
  notificationsEnabled: true,
  exactAlarmsAllowed: true,
  directScheduledCount: count,
  coverage: coverage,
  hasCapacityOverflow: overflow,
  schedulingWindowEndExclusive: end,
  lastError: error,
);

Future<void> _mount(
  WidgetTester tester,
  _CoverageService service, {
  bool enabled = true,
  bool embedded = false,
  Locale locale = const Locale('en'),
  double width = 1000,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 850);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final data = buildInitialAppData(buildDefaultPeriodTimes())
      .copyWith(notificationSettings: NotificationSettings(enabled: enabled));
  final app = AppRuntime(
    dataTransferCodec: inlineDataTransferCodec,
    storage: _MemoryStorage(data),
    systemLocaleCodeResolver: () => locale.toLanguageTag(),
  );
  await app.lifecycle.load();
  addTearDown(app.dispose);
  final bridge = AndroidProductivityBridge(enabled: false);
  addTearDown(bridge.dispose);
  final page = NotificationSettingsPage(
    notificationService: service,
    productivityBridge: bridge,
    embedded: embedded,
  );
  await tester.pumpWidget(
    AppScope(
      app: app,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(brightness: brightness),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        ),
        home: embedded
            ? Scaffold(body: SingleChildScrollView(child: page))
            : page,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get _notice =>
    find.byKey(const ValueKey('notification-coverage-notice'));

String _noticeText(WidgetTester tester) =>
    tester.widget<SettingsConnectedTile>(_notice).subtitle!;

void _coverageTestWidgets(
  String description,
  Future<void> Function(WidgetTester) callback, {
  TargetPlatform platform = TargetPlatform.windows,
}) {
  testWidgets(
    description,
    callback,
    variant: TargetPlatformVariant.only(platform),
  );
}

void main() {
  for (final embedded in [false, true]) {
    _coverageTestWidgets(
      'Windows limit is visible before the first plan (embedded=$embedded)',
      (tester) async {
        final service = _CoverageService(status: _status());
        addTearDown(service.dispose);
        await _mount(tester, service, embedded: embedded);

        expect(_notice, findsOneWidget);
        final text = _noticeText(tester);
        expect(text, contains('next 14 days, up to 200'));
        expect(text, contains('Reopen the app regularly'));
        expect(text, isNot(contains('450')));
        expect(text, isNot(contains('scheduled.')));
        expect(text, isNot(contains('checked through')));
      },
    );
  }

  _coverageTestWidgets(
    'successful plan shows its real count and window deadline',
    (tester) async {
      final service = _CoverageService(
        status: _status(count: 1, end: DateTime(2031, 2, 18, 17, 45)),
      );
      addTearDown(service.dispose);
      await _mount(tester, service);

      final text = _noticeText(tester);
      expect(text, contains('1 reminder scheduled.'));
      expect(text, matches(RegExp(r'0?2/18/2031 17:45')));
      expect(text, isNot(contains('renewed in advance')));
      expect(text, isNot(contains('limit has been reached')));
    },
  );

  _coverageTestWidgets(
    'an empty successful plan reports zero without claiming delivery',
    (tester) async {
      final service = _CoverageService(
        status: _status(end: DateTime(2031, 2, 18, 17, 45)),
      );
      addTearDown(service.dispose);
      await _mount(tester, service);

      expect(_noticeText(tester), contains('No reminders scheduled.'));
      expect(_noticeText(tester), contains('Last plan checked through'));
      expect(_noticeText(tester), isNot(contains('long-term coverage')));
    },
  );

  _coverageTestWidgets(
    'blocked or failed plans hide stale successful summaries',
    (tester) async {
      final service = _CoverageService(
        status: _status(count: 1, end: DateTime(2031, 2, 18, 17, 45)),
      );
      addTearDown(service.dispose);
      await _mount(tester, service);
      expect(_noticeText(tester), contains('1 reminder scheduled.'));

      for (final coverage in [
        AgendaNotificationCoverage.blocked,
        AgendaNotificationCoverage.failed,
      ]) {
        service.publish(
          _status(
            count: 9,
            end: DateTime(2031, 2, 18, 17, 45),
            coverage: coverage,
            overflow: true,
            error: coverage == AgendaNotificationCoverage.failed
                ? StateError('test projection failure')
                : null,
          ),
        );
        await tester.pumpAndSettle();
        final text = _noticeText(tester);
        expect(text, contains('next 14 days, up to 200'));
        expect(text, isNot(contains('checked through')));
        expect(text, isNot(contains('9 reminders scheduled')));
        expect(text, isNot(contains('limit has been reached')));
      }

      service.publish(_status(count: 2, end: DateTime(2031, 2, 19, 8, 30)));
      await tester.pumpAndSettle();
      expect(_noticeText(tester), contains('2 reminders scheduled.'));
      expect(_noticeText(tester), matches(RegExp(r'0?2/19/2031 08:30')));
    },
  );

  _coverageTestWidgets(
    'capacity warning does not imply every checked reminder is queued',
    (tester) async {
      final service = _CoverageService(
        capacity: 3,
        status: _status(
          count: 3,
          end: DateTime(2031, 2, 18, 17, 45),
          coverage: AgendaNotificationCoverage.capacityLimited,
          overflow: true,
        ),
      );
      addTearDown(service.dispose);
      await _mount(tester, service);

      final text = _noticeText(tester);
      expect(text, contains('next 14 days, up to 3'));
      expect(text, contains('3 reminders scheduled.'));
      expect(text, contains('Some reminders are not yet scheduled'));
      expect(text, contains('after upcoming reminders have fired'));
      expect(text, isNot(contains('450')));
    },
  );

  _coverageTestWidgets('disabling app notifications hides the Windows notice', (
    tester,
  ) async {
    final service = _CoverageService(
      status: _status(count: 1, end: DateTime(2031, 2, 18, 17, 45)),
    );
    addTearDown(service.dispose);
    await _mount(tester, service, enabled: false);
    expect(_notice, findsNothing);
  });

  for (final coverage in [
    AgendaNotificationCoverage.renewable,
    AgendaNotificationCoverage.capacityLimited,
  ]) {
    _coverageTestWidgets(
      'Android keeps its existing $coverage coverage notice',
      (tester) async {
        final service = _CoverageService(status: _status(coverage: coverage));
        addTearDown(service.dispose);
        await _mount(tester, service);

        final text = _noticeText(tester);
        expect(text, isNot(contains('Windows')));
        expect(
          text,
          coverage == AgendaNotificationCoverage.renewable
              ? contains('background renewal')
              : contains('Android can directly hold up to 450'),
        );
      },
      platform: TargetPlatform.android,
    );
  }

  for (final brightness in Brightness.values) {
    for (final locale in [
      const Locale('en'),
      const Locale('zh'),
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ]) {
      _coverageTestWidgets(
        'coverage notice wraps at 320dp and 2x text ($brightness, $locale)',
        (tester) async {
          final service = _CoverageService(
            status: _status(
              count: 200,
              end: DateTime(2031, 2, 18, 17, 45),
              coverage: AgendaNotificationCoverage.capacityLimited,
              overflow: true,
            ),
          );
          addTearDown(service.dispose);
          await _mount(
            tester,
            service,
            width: 320,
            textScale: 2,
            brightness: brightness,
            locale: locale,
          );
          expect(_notice, findsOneWidget);
          await Scrollable.ensureVisible(tester.element(_notice));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(_noticeText(tester), contains('200'));
          expect(_noticeText(tester), contains('2031'));
        },
      );
    }
  }
}
