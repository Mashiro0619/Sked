import 'package:flutter_test/flutter_test.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/settings_destination.dart';

import '../../support/workspace_harness.dart';

/// This exhaustive switch connects actual UI entry points to their management
/// surface. A new destination requires an explicit classification at compile
/// time; labels or the contents of a hand-maintained Markdown table are not the
/// source of truth. Domain-field completeness is checked by the resource and
/// SettingRegistry contract suites rather than repeated here.
({Set<String> settings, Set<String> tools}) _destinationOwners(
  SettingsDestination destination,
) => switch (destination) {
  SettingsDestination.appearance => (
    settings: {'student.themeMode', 'general.themeMode'},
    tools: {'settings.update', 'device.layout.apply'},
  ),
  SettingsDestination.notifications => (
    settings: {'app.notifications.enabled'},
    tools: {'notifications.status', 'settings.update'},
  ),
  SettingsDestination.language => (
    settings: {'app.localeCode'},
    tools: {'settings.update'},
  ),
  SettingsDestination.data => (
    settings: {},
    tools: {
      'file_imports.apply',
      'exports.generate',
      'backups.restore',
      'maintenance.clear',
    },
  ),
  SettingsDestination.features => (
    settings: {'agent.enabled'},
    tools: {'workspaces.apply', 'settings.update'},
  ),
  SettingsDestination.agent => (
    settings: {'agent.protocol', 'agent.endpoint', 'agent.model'},
    tools: {'connection.apply', 'credentials.request_input'},
  ),
  SettingsDestination.about => (
    settings: {'app.includePrereleaseUpdates', 'app.ignoredUpdateVersion'},
    tools: {'settings.get', 'settings.update'},
  ),
  SettingsDestination.student || SettingsDestination.studentPreferences => (
    settings: {'student.showFutureCourses', 'student.toolbarNavigationOrder'},
    tools: {'settings.update', 'courses.display.apply'},
  ),
  SettingsDestination.general || SettingsDestination.generalPreferences => (
    settings: {'general.showWeekends', 'general.toolbarNavigationOrder'},
    tools: {'settings.update', 'navigation.range.apply'},
  ),
  SettingsDestination.schoolImport => (
    settings: {'agent.protocol', 'agent.endpoint', 'agent.model'},
    tools: {'connection.apply', 'credentials.request_input'},
  ),
  SettingsDestination.notificationPermissions => (
    settings: {},
    tools: {
      'notifications.permission.apply',
      'notifications.exact_alarm.apply',
      'platform.request_action',
    },
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppRuntime app;
  setUp(() async {
    app = await workspaceProvider();
  });
  tearDown(() async {
    await app.agent.close();
    app.dispose();
  });

  test(
    'settings destinations retain registered business management owners',
    () {
      final settings = SettingRegistry();
      for (final destination in SettingsDestination.values) {
        final owners = _destinationOwners(destination);
        expect(owners.tools, isNotEmpty, reason: destination.name);
        for (final key in owners.settings) {
          final field = settings.descriptor(key);
          expect(field.readOnly, isFalse, reason: '$destination: $key');
          expect(field.resetMeaning, isNotEmpty);
        }
        expect(
          app.agent.tools.registeredNames,
          containsAll(owners.tools),
          reason: destination.name,
        );
      }
    },
  );
}
