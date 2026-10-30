import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_credential_store.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/services/desktop_layout_preferences.dart';

import 'acceptance_harness.dart';
import 'write_tool_coverage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AcceptanceHarness h;
  setUp(() async {
    h = AcceptanceHarness();
    await h.initialize();
  });
  tearDown(() => h.close());

  test('all actual tools have an explicit effect and regression owner', () {
    expect(
      readOnlyToolInventory.intersection(writeToolCoverage.keys.toSet()),
      isEmpty,
    );
    expect(h.app.agent.tools.registeredNames, {
      ...readOnlyToolInventory,
      ...writeToolCoverage.keys,
    }, reason: 'Classify new tools and connect their domain failure suite.');
    for (final coverage in writeToolCoverage.values) {
      expect(sharedFailureSuites[coverage.boundary], isNotEmpty);
      expect(coverage.domainSuite, startsWith('test/'));
    }
  });

  test('every write entry rejects unknown fields before any persisted or native effect', () async {
    await h.run(() async {
      final before = h.saved.encode();
      final beforeConversations = h.conversations.source;
      final beforePermission = h.gateway.permission;
      final beforeCredentials = {
        for (final slot in AgentCredentialSlot.values)
          slot: await h.credentials.read(slot),
      };
      for (final name in writeToolCoverage.keys) {
        await expectLater(
          h.call(name, {'unregistered_argument': true}),
          throwsA(
            isA<OperationProblem>().having(
              (error) => error.code,
              'code',
              OperationErrorCode.invalidArgument,
            ),
          ),
          reason: '$name must reject unknown tool fields before starting work.',
        );
        expect(h.saved.encode(), before, reason: name);
        expect(h.conversations.source, beforeConversations, reason: name);
        expect(h.gateway.permission, beforePermission, reason: name);
        expect(h.writtenArtifacts, isEmpty, reason: name);
        expect(h.navigationTargets, isEmpty, reason: name);
        expect(h.developer.assistantVisible, isFalse, reason: name);
        for (final region in DesktopLayoutRegion.values) {
          expect(h.layout.preferenceFor(region), isNull, reason: name);
        }
        for (final slot in AgentCredentialSlot.values) {
          expect(
            await h.credentials.read(slot),
            beforeCredentials[slot],
            reason: name,
          );
        }
      }
      expect((await h.call('school_sites.list'))['items'], isEmpty);
    });
  });
}
