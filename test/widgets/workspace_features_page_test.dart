import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/workspace_features_page.dart';
import 'package:sked/services/agenda_notification_service.dart';
import 'package:sked/services/agenda_notification_runtime_store.dart';

import '../support/workspace_harness.dart';

// UI tests exercise status/ retry presentation. Real cancellation and runtime
// lock failures remain covered by services/workspace_availability_test.dart.
class _NotificationService extends ChangeNotifier
    implements AgendaNotificationService {
  bool fail = true;
  @override
  AgendaNotificationStatus get status => _status;
  var _status = const AgendaNotificationStatus(
    notificationsEnabled: true,
    exactAlarmsAllowed: true,
    directScheduledCount: 0,
  );
  @override
  Future<AgendaNotificationStatus> reconcile(
    AppData data, {
    DateTime? anchor,
    AgendaNotificationReconcileMode mode =
        AgendaNotificationReconcileMode.authoritative,
    AgendaNotificationReconcileOrigin origin =
        AgendaNotificationReconcileOrigin.foreground,
    AgendaNotificationProjectionFence? projectionFence,
    void Function(String?)? onPayload,
    FutureOr<void> Function(String?, String?)? onAction,
  }) async {
    _status = AgendaNotificationStatus(
      notificationsEnabled: true,
      exactAlarmsAllowed: true,
      directScheduledCount: 0,
      lastError: fail ? StateError('cleanup unavailable') : null,
    );
    notifyListeners();
    return _status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'feature controls cancel, disable, preserve data, protect last domain and re-enable',
    (tester) async {
      final p = await workspaceProvider();
      final courses = p.studentMode.toJson();
      await tester.pumpWidget(
        WorkspaceHarness(provider: p, home: const WorkspaceFeaturesPage()),
      );
      await tester.pumpAndSettle();
      final student = find.byKey(const ValueKey('workspace-enabled-student'));
      final l = AppLocalizations.of(tester.element(student));
      await tester.tap(student);
      await tester.tap(student);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text(l.cancel));
      await tester.pumpAndSettle();
      expect(p.hasMultipleWorkspaces, isTrue);
      await tester.tap(student);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();
      expect(p.enabledWorkspaces, {AppMode.general});
      expect(p.activeMode, AppMode.general);
      expect(p.studentMode.toJson(), courses);
      expect(find.text(l.workspaceLastRequired), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('workspace-enabled-general')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(student);
      await tester.pumpAndSettle();
      expect(p.hasMultipleWorkspaces, isTrue);
      expect(p.activeMode, AppMode.general);
      await tester.tap(find.text(l.hideHomeWorkspaceNavigation));
      await tester.pumpAndSettle();
      expect(p.hideHomeWorkspaceNavigation, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    },
  );
  testWidgets(
    'notification cleanup failure keeps the domain disabled and retry is explicit',
    (tester) async {
      final p = await workspaceProvider();
      final service = _NotificationService();
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: WorkspaceFeaturesPage(notificationService: service),
        ),
      );
      await tester.pumpAndSettle();
      final student = find.byKey(const ValueKey('workspace-enabled-student'));
      final l = AppLocalizations.of(tester.element(student));
      await tester.tap(student);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.confirm));
      await tester.pumpAndSettle();
      expect(p.isWorkspaceEnabled(AppMode.student), isFalse);
      expect(find.text(l.workspaceReminderCleanupFailed), findsOneWidget);
      service.fail = false;
      await tester.tap(find.text(l.dataRecoveryRetryAction));
      await tester.pumpAndSettle();
      expect(find.text(l.workspaceReminderCleanupFailed), findsNothing);
      expect(p.isWorkspaceEnabled(AppMode.student), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
      service.dispose();
    },
  );
}
