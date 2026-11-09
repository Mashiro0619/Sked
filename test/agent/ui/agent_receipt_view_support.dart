import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:sked/agent/operations/tool_outcome.dart';
import 'package:sked/agent/ui/agent_operation_card.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/workspace_harness.dart';
import 'agent_ui_test_support.dart';

Future<AppRuntime> receiptWorkspace(WidgetTester tester, AppData data) async {
  final app = (await tester.runAsync(
    () => workspaceProvider(storage: WorkspaceMemoryStorage(data)),
  ))!;
  addTearDown(() async {
    await app.agent.close();
    app.dispose();
  });
  return app;
}

Future<void> mountReceiptView(
  WidgetTester tester,
  Map<String, Object?> receipt, {
  required Locale locale,
  required List<Map<String, Object?>> opened,
  AppRuntime? app,
}) {
  Widget body = Builder(
    builder: (context) => SingleChildScrollView(
      child: AgentOperationCard(
        outcome: ToolOutcome.fromResult(
          app?.agent.tools.describeCommitResult(receipt) ?? receipt,
        ),
        onOpenResource: (ref) {
          opened.add(ref);
          if (app != null) unawaited(AgentResourceView.open(context, ref));
        },
      ),
    ),
  );
  if (app != null) {
    body = Provider<AppSession>.value(value: app.session, child: body);
  }
  return mountAgentUi(
    tester,
    body,
    locale: locale,
    scale: 2,
    size: const Size(390, 844),
  );
}
