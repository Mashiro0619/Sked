import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/agent/provider/provider.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/screens/app_home_screen.dart';
import 'package:sked/services/export_service.dart';

import '../../support/workspace_harness.dart';

class _Exports extends ExportService {
  final payloads = <ExportPayload>[];
  ExportSaveStatus status = ExportSaveStatus.saved;

  @override
  Future<ExportSaveResult> saveFile(ExportPayload payload) async {
    payloads.add(payload);
    return ExportSaveResult(
      status: status,
      path: status == ExportSaveStatus.saved ? 'memory://export.json' : null,
    );
  }
}

void main() {
  late AppRuntime app;
  late OperationScope scope;
  late _Exports exports;
  late WidgetTester activeTester;
  var call = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    app = await workspaceProvider(mode: AppMode.general);
    await app.lifecycle.completeFirstLaunch(
      AppMode.general,
      hideWorkspaceNavigation: false,
    );
    scope = OperationScope(
      id: 'host-scope',
      policy: OperationPolicy(enabled: true, mode: AgentPermissionMode.full),
    );
    exports = _Exports();
    call = 0;
  });
  tearDown(() {
    scope.cancel();
    app.dispose();
  });

  Future<Map<String, Object?>> tool(
    String name,
    Map<String, Object?> args,
  ) async {
    Object? failure;
    StackTrace? failureStack;
    final result = await activeTester.runAsync(() async {
      try {
        return await app.agent.tools
            .execute(
              ProviderToolCall(
                id: 'host-call-${++call}',
                name: name,
                arguments: jsonEncode(args),
              ),
              scope,
              (_) => throw StateError('Full mode must not request approval.'),
            )
            .timeout(const Duration(seconds: 10));
      } catch (error, stack) {
        failure = error;
        failureStack = stack;
        return null;
      }
    });
    if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
    return result!;
  }

  Future<void> mount(WidgetTester tester) async {
    activeTester = tester;
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: app,
        home: AppHomeScreen(agentExportService: exports),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'navigation host selects the requested course and opens its actual stored detail',
    (tester) async {
      await mount(tester);
      final timetable = app.session.committedData.studentMode.timetables
          .firstWhere((t) => t.courses.isNotEmpty);
      final course = timetable.courses.first;
      final prepared = await tool('navigation.open', {
        'workspace': 'student',
        'ref': {'kind': 'course', 'id': course.id, 'parentId': timetable.id},
        'week': 2,
      });
      final result = await tool('external.commit', {
        'planId': prepared['planId'],
      });
      await tester.pumpAndSettle();
      expect(result['effectStatus'], 'applied');
      expect(app.session.committedData.activeMode, AppMode.student);
      expect(
        app.session.committedData.studentMode.activeTimetableId,
        timetable.id,
      );
      expect(app.studentView.selectedWeek, 2);
      expect(find.byType(AgentResourceView), findsOneWidget);
      expect(find.text(course.name), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'out-of-range navigation fails without changing workspace or selected week',
    (tester) async {
      await mount(tester);
      final before = app.session.committedData;
      final timetable = before.studentMode.timetables.first;
      final selectedWeek = app.studentView.selectedWeek;
      final prepared = await tool('navigation.open', {
        'workspace': 'student',
        'ref': {'kind': 'timetable', 'id': timetable.id},
        'week': timetable.config.totalWeeks + 1,
      });
      final result = await tool('external.commit', {
        'planId': prepared['planId'],
      });
      expect(result['effectStatus'], isNot('applied'));
      expect(app.session.committedData.activeMode, before.activeMode);
      expect(app.studentView.selectedWeek, selectedWeek);
      expect(find.byType(AgentResourceView), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'file destination cancellation remains a failed effect and unmount revokes pending plans',
    (tester) async {
      await mount(tester);
      final id = app.session.committedData.studentMode.timetables.first.id;
      final artifact = await tool('exports.prepare', {
        'format': 'timetables_json',
        'ids': [id],
      });
      final cancelled = await tool('exports.write', {
        'artifactId': artifact['artifactId'],
      });
      exports.status = ExportSaveStatus.cancelled;
      final result = await tool('external.commit', {
        'planId': cancelled['planId'],
      });
      expect(result['effectStatus'], 'failed');
      expect(exports.payloads, hasLength(1));
      final pending = await tool('exports.write', {
        'artifactId': artifact['artifactId'],
      });
      await tester.pumpWidget(const SizedBox());
      await expectLater(
        tool('external.commit', {'planId': pending['planId']}),
        throwsA(isA<OperationProblem>()),
      );
      expect(exports.payloads, hasLength(1));
    },
  );
}
