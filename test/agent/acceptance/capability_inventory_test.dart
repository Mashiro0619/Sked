import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/agent/conversations/conversation_models.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/application/setting_registry.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/school_site_models.dart';
import 'package:sked/models/settings_destination.dart';
import 'package:sked/services/desktop_layout_preferences.dart';

import 'acceptance_harness.dart';

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
  late AcceptanceHarness h;
  setUp(() async {
    h = AcceptanceHarness();
    await h.initialize();
  });
  tearDown(() => h.close());

  test('actual settings destinations have registered management owners', () {
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
        h.app.agent.tools.registeredNames,
        containsAll(owners.tools),
        reason: destination.name,
      );
    }
  });

  test(
    'side-store dimensions and every device role support persisted set/reset',
    () async {
      await h.run(() async {
        const size = PreferredRegionSize(
          width: 401,
          height: 502,
          dockedWidth: 303,
        );
        final dimensions = size.toJson().keys.toSet();
        final registry = SettingRegistry();
        final description = await h.call('device.layout.describe');
        expect((description['dimensions'] as List).toSet(), dimensions);
        expect(
          (description['roles'] as List).map((role) => role['region']).toSet(),
          DesktopLayoutRegion.values.map((role) => role.name).toSet(),
        );
        final schema = await h.call('capabilities.describe', {
          'names': ['device.layout.apply'],
        });
        final properties =
            (schema['tools'] as List).single['parameters']['properties'] as Map;
        expect(
          (properties['values']['properties'] as Map).keys.toSet(),
          dimensions,
        );
        expect((properties['region']['enum'] as List).toSet(), {
          'all',
          ...DesktopLayoutRegion.values.map((role) => role.name),
        });
        for (final role in DesktopLayoutRegion.values) {
          for (final dimension in dimensions) {
            final descriptor = registry.descriptor(
              'device.layout.${role.name}.$dimension',
            );
            expect(descriptor.adapterTool, 'device.layout.apply');
            expect(descriptor.nullable, isTrue);
          }
          final plan = await h.call('device.layout.apply', {
            'region': role.name,
            'action': 'set',
            'values': size.toJson(),
          });
          expect(plan['effectStatus'], 'applied');
          expect(h.layout.preferenceFor(role), size, reason: role.name);
          expect(h.layout.hasUnsavedChanges, isFalse);
        }
        final reset = await h.call('device.layout.apply', {
          'region': 'all',
          'action': 'reset',
        });
        expect(reset['effectStatus'], 'applied');
        for (final role in DesktopLayoutRegion.values) {
          expect(h.layout.preferenceFor(role), isNull, reason: role.name);
        }
      });
    },
  );

  test(
    'school-site schema exposes exactly the persisted configurable fields',
    () async {
      await h.run(() async {
        const site = SchoolSite(
          id: 'schema-fixture',
          name: 'Campus',
          loginUrl: 'https://campus.invalid',
        );
        final schema = await h.call('capabilities.describe', {
          'names': ['school_sites.apply'],
        });
        final properties =
            (schema['tools'] as List).single['parameters']['properties'] as Map;
        expect(
          (properties['site']['properties'] as Map).keys.toSet(),
          site.toJson().keys.toSet().difference({'id'}),
        );
        expect(site.toJson().keys.toSet(), {'id', 'name', 'loginUrl'});
        expect(
          SettingRegistry().descriptor('device.schoolSites').adapterTool,
          'school_sites.apply',
        );
        final plan = await h.call('school_sites.apply', {
          'action': 'create',
          'site': site.toJson()..remove('id'),
        });
        expect(plan['effectStatus'], 'applied');
        final exported = await h.call('school_sites.export');
        final actual =
            (jsonDecode(exported['text'] as String) as List).single as Map;
        expect(validSchoolSiteId(actual['id'] as String), isTrue);
        expect(actual['id'], isNot(site.id));
        expect(
          Map<String, dynamic>.from(actual)..remove('id'),
          site.toJson()..remove('id'),
        );
      });
    },
  );

  test('legacy device preference is separate from Agent enablement and resets normally', () async {
    await h.run(() async {
      final enabled = h.saved.agentSettings.enabled;
      final description = await h.call('device.preferences.describe');
      expect(description['key'], 'device.assistantPreviewEnabled');
      expect(
        SettingRegistry().descriptor(description['key'] as String).adapterTool,
        'device.preferences.apply',
      );
      for (final args in [
        {'action': 'set', 'value': true},
        {'action': 'reset'},
      ]) {
        final plan = await h.call('device.preferences.apply', args);
        expect(plan['effectStatus'], 'applied');
        expect(h.developer.assistantVisible, args['action'] == 'set');
        expect(h.developer.busy, isFalse);
        expect(h.saved.agentSettings.enabled, enabled);
      }
    });
  });

  test('protocol and secure-slot additions must retain an explicit owner', () async {
    await h.run(() async {
      final connection = await h.call('connection.describe');
      expect(
        (connection['protocols'] as List).toSet(),
        AgentModelProtocol.values.map((value) => value.name).toSet(),
      );
      expect(
        AgentCredentialSlot.values.toSet(),
        {AgentCredentialSlot.active, AgentCredentialSlot.pending},
        reason:
            'New secret slots need replacement, recovery and clear ownership.',
      );
      expect(connection['credentialActions'], ['keep', 'replace', 'clear']);
      expect(connection['writableFields'], [
        'protocol',
        'endpoint',
        'model',
        'models',
      ]);
      final credential = SettingRegistry().descriptor('agent.credentialRef');
      expect(credential.sensitive, isTrue);
      expect(credential.requiresAdapter, isTrue);
      expect(connection.containsKey('credentialRef'), isFalse);
    });
  });

  test('conversation archive metadata is classified outside raw setting writes', () async {
    const owners = {
      'version': 'storage_format',
      'revision': 'storage_persistence',
      'selectedId': 'host_navigation',
      'conversations': 'semantic_conversation_tools',
      'handoffs': 'atomic_source_handoff',
      'terminatedIds': 'deletion_tombstones',
    };
    expect(
      (jsonDecode(ConversationArchive().encode()) as Map).keys.toSet(),
      owners.keys.toSet(),
    );
    await h.run(() async {
      final before = h.saved.encode();
      // Scope facts, restored generations and platform grants cannot be forged
      // through the generic setting API, even while running in full mode.
      for (final field in SettingRegistry().descriptors.where(
        (d) => d.readOnly,
      )) {
        await expectLater(
          h.call('settings.update', {
            'edits': [
              {'key': field.key, 'action': 'reset'},
            ],
          }),
          throwsA(
            isA<OperationProblem>().having(
              (e) => e.code,
              'code',
              OperationErrorCode.invalidArgument,
            ),
          ),
          reason: field.key,
        );
      }
      for (final key in owners.keys) {
        await expectLater(
          h.call('settings.update', {
            'edits': [
              {'key': 'conversations.$key', 'action': 'set', 'value': 'forged'},
            ],
          }),
          throwsA(
            isA<OperationProblem>().having(
              (e) => e.code,
              'code',
              OperationErrorCode.invalidArgument,
            ),
          ),
        );
      }
      expect(h.saved.encode(), before);
    });
  });
}
