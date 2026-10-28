import '../support/agenda_notification_memory.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/screens/notification_settings_page.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/android_productivity_bridge.dart';
import 'package:sked/widgets/settings_list.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final (supported, notifications, exactAlarm) in [
    (true, false, true),
    (true, true, true),
    (true, true, false),
    (false, false, false),
  ]) {
    testWidgets(
      'permission summary identifies each status: '
      '$supported / $notifications / $exactAlarm',
      (tester) async {
        final provider = await workspaceProvider(locale: 'en');
        final gateway = MemoryAgendaNotificationGateway()
          ..permissionGranted = notifications
          ..exactAlarmGranted = exactAlarm;
        final service = AgendaNotificationService(
          enabled: supported,
          gateway: gateway,
          runtimeStore: MemoryAgendaNotificationRuntimeStore(),
        );
        final bridge = AndroidProductivityBridge(enabled: false);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          bridge.dispose();
          service.dispose();
          provider.dispose();
        });
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: NotificationSettingsPage(
              notificationService: service,
              productivityBridge: bridge,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final summary = find.byKey(
          const ValueKey('notification-troubleshooting'),
        );
        await tester.ensureVisible(summary);
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(tester.element(summary));
        final text = tester.widget<SettingsConnectedTile>(summary).subtitle!;
        expect(text, startsWith('${l10n.notificationPermission}: '));
        final notificationStatus = !supported
            ? l10n.notificationPlatformUnsupported
            : defaultTargetPlatform == TargetPlatform.windows
            ? l10n.developerNotificationWindowsPermissionManaged
            : notifications
            ? l10n.notificationPermissionGranted
            : l10n.notificationPermissionDenied;
        expect(
          text.split('\n').first,
          '${l10n.notificationPermission}: $notificationStatus',
        );
        if (supported && defaultTargetPlatform == TargetPlatform.android) {
          expect(
            text.split('\n').last,
            '${l10n.notificationExactAlarm}: '
            '${exactAlarm ? l10n.notificationExactAlarmAllowed : l10n.notificationExactAlarmRequired}',
          );
        } else {
          expect(text, isNot(contains(l10n.notificationExactAlarm)));
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }
}
