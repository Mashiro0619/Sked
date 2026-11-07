import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/operations/tool_outcome.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/application/operation_contracts.dart';

import 'core_tool_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'setting discovery includes the step and exclusive minimum used by edits',
    () async {
      final app = CoreToolHarness();
      await app.initialize();
      addTearDown(app.close);
      addTearDown(app.tools.dispose);
      final scope = OperationScope(
        id: 'setting-metadata',
        policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
      );
      var callId = 0;
      ProviderToolCall call(String name, Map<String, Object?> arguments) =>
          ProviderToolCall(
            id: 'call-${callId++}',
            name: name,
            arguments: jsonEncode(arguments),
          );
      final discovered = <String, Map>{};
      var offset = 0;
      while (true) {
        final page = await app.tools.execute(
          call('settings.describe', {'offset': offset, 'limit': 100}),
          scope,
          (_) async => fail('Description cannot request approval.'),
        );
        final items = (page['settings'] as List).cast<Map>();
        for (final item in items) {
          discovered[item['key'] as String] = item;
        }
        if (page['hasMore'] == false) break;
        offset += items.length;
      }
      final width = discovered['general.customDayMinWidth']!;
      expect(width['step'], 8);
      expect(discovered['general.timeGridHourHeight']!['step'], 4);
      final dimension = app.tools.settings.descriptors.firstWhere(
        (item) => item.minimumExclusive,
      );
      expect(discovered[dimension.key]!['minimum'], 0);
      expect(discovered[dimension.key]!['minimumExclusive'], isTrue);
      expect(width['default'], width['defaultValue']);

      final allowedWidth = (width['minimum'] as int) + (width['step'] as int);
      final saved = await app.tools.executeOutcome(
        call('settings.update', {
          'edits': [
            {
              'key': 'general.customDayMinWidth',
              'action': 'set',
              'value': allowedWidth,
            },
          ],
        }),
        scope,
        (_) async => fail('Full permission uses the current grant.'),
      );
      expect(saved.kind, ToolOutcomeKind.saved);
      expect(
        app.session.committedData.generalMode.customDayMinWidth,
        allowedWidth,
      );
      final rejected = await app.tools.executeOutcome(
        call('settings.update', {
          'edits': [
            {
              'key': 'general.customDayMinWidth',
              'action': 'set',
              'value': allowedWidth + 1,
            },
          ],
        }),
        scope,
        (_) async => fail('An invalid value cannot request approval.'),
      );
      expect(rejected.kind, ToolOutcomeKind.correctableError);
      expect(
        app.session.committedData.generalMode.customDayMinWidth,
        allowedWidth,
      );
    },
  );
}
