import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_resource_view.dart';
import 'package:sked/application/resource_contracts.dart';
import 'package:sked/models/timetable_models.dart';

import '../../support/workspace_harness.dart';

void main() {
  testWidgets(
    'stored resource inspection works for disabled workspaces and follows commits',
    (tester) async {
      final app = await workspaceProvider(mode: AppMode.general);
      addTearDown(app.dispose);
      addTearDown(tester.view.reset);
      final timetable = app.session.committedData.studentMode.timetables
          .firstWhere((t) => t.courses.isNotEmpty);
      final course = timetable.courses.first;
      await app.workspaces.setEnabled(AppMode.student, false);
      final selected = app.session.committedData.activeMode;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: app,
          textScale: 2,
          home: AgentResourceView(
            session: app.session,
            ref: ResourceRef(
              kind: ResourceKind.course,
              id: course.id,
              parentId: timetable.id,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(course.name), findsOneWidget);
      expect(
        app.session.committedData.isWorkspaceEnabled(AppMode.student),
        isFalse,
      );
      expect(app.session.committedData.activeMode, selected);
      expect(tester.takeException(), isNull);
      await app.workspaces.setEnabled(AppMode.student, true);
      await app.studentCommands.saveCourse(
        course.copyWith(name: 'Changed after opening'),
        timetableId: timetable.id,
      );
      await tester.pumpAndSettle();
      expect(find.text('Changed after opening'), findsOneWidget);
      expect(find.text(course.name), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
