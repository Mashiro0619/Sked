import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/widgets/school_import_replace_confirmation.dart';
import 'package:sked/widgets/sked_task_route.dart';
import 'package:sked/widgets/sked_task_session.dart';

import '../support/workspace_harness.dart';

class _ConfirmationRun {
  late BuildContext ownerContext;
  late MaterialPageRoute<String> ownerRoute;
  late Future<bool> completed;
}

Future<_ConfirmationRun> _openConfirmation(
  WidgetTester tester,
  TimetableProvider provider, {
  SkedTaskSession? parent,
}) async {
  final run = _ConfirmationRun();
  late BuildContext home;
  await tester.pumpWidget(
    WorkspaceHarness(
      provider: provider,
      home: Builder(
        builder: (context) {
          home = context;
          return const Scaffold(body: Text('Import home'));
        },
      ),
    ),
  );
  run.ownerRoute = MaterialPageRoute<String>(
    builder: (_) {
      final owner = Builder(
        builder: (context) {
          run.ownerContext = context;
          return const Scaffold(body: Text('Import owner'));
        },
      );
      return parent == null
          ? owner
          : SkedTaskSessionScope(session: parent, child: owner);
    },
  );
  unawaited(Navigator.of(home).push(run.ownerRoute));
  await tester.pumpAndSettle();
  run.completed = confirmSchoolImportReplacement(run.ownerContext);
  await tester.pumpAndSettle();
  return run;
}

void main() {
  for (final confirm in [false, true]) {
    testWidgets(
      'replacement decision completes once without popping its owner: $confirm',
      (tester) async {
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        final run = await _openConfirmation(tester, provider);
        final callback = confirm
            ? tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!
            : tester.widget<TextButton>(find.byType(TextButton)).onPressed!;

        callback();
        callback();
        await tester.pumpAndSettle();

        expect(await run.completed, confirm);
        expect(run.ownerRoute.isCurrent, isTrue);
        expect(find.text('Import owner'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final retirement in [
    'parent disposal',
    'owner removal',
    'workspace disable',
    'target change',
    'data replacement',
  ]) {
    testWidgets(
      'replacement confirmation retires after $retirement and preserves newer tasks',
      (tester) async {
        final provider = await workspaceProvider();
        addTearDown(provider.dispose);
        if (retirement == 'workspace disable') {
          await provider.setWorkspaceEnabled(AppMode.general, true);
        }
        final parent = retirement == 'parent disposal'
            ? SkedTaskSession()
            : null;
        if (parent != null) addTearDown(parent.dispose);
        final run = await _openConfirmation(tester, provider, parent: parent);
        final confirm = tester
            .widget<FilledButton>(find.byType(FilledButton))
            .onPressed!;
        final confirmationRoute = ModalRoute.of(
          tester.element(find.byType(AlertDialog)),
        )!;
        final newer = showDialog<void>(
          context: run.ownerContext,
          builder: (_) => const AlertDialog(title: Text('Newer task')),
        );
        await tester.pumpAndSettle();

        switch (retirement) {
          case 'parent disposal':
            parent!.dispose();
          case 'owner removal':
            run.ownerRoute.navigator!.removeRoute(run.ownerRoute);
          case 'workspace disable':
            await provider.setWorkspaceEnabled(AppMode.student, false);
          case 'target change':
            final original = provider.activeTimetableOrNull!;
            await provider.addTimetable(
              original.config.copyWith(name: 'Another timetable'),
            );
            await provider.switchTimetable(original.id);
          case 'data replacement':
            final backup = await provider.exportAppDataJson();
            await provider.importAppDataJson(
              backup,
              mode: AppImportMode.replaceAll,
            );
        }
        await tester.pumpAndSettle();
        confirm();
        await tester.pumpAndSettle();

        expect(await run.completed, isFalse);
        expect(confirmationRoute.isActive, isFalse);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Newer task'), findsOneWidget);
        expect(run.ownerRoute.isActive, retirement != 'owner removal');
        completeSkedTaskRoute(tester.element(find.text('Newer task')));
        await tester.pumpAndSettle();
        await newer;
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
