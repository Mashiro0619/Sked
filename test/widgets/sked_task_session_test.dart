import 'package:sked/providers/timetable_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_task_session.dart';

import '../support/workspace_harness.dart';

void main() {
  test('session invalidation propagates once and cannot revive', () {
    var valid = true;
    final parent = SkedTaskSession(isTargetCurrent: () => valid);
    final child = SkedTaskSession(parent: parent);
    var notices = 0;
    child.addListener(() => notices++);
    valid = false;
    parent.check();
    expect(child.isCurrent, isFalse);
    expect(notices, 1);
    valid = true;
    parent.check();
    expect(child.isCurrent, isFalse);
    parent.invalidate();
    expect(notices, 1);
    child.dispose();
    parent.dispose();
  });
  test(
    'disposed parent invalidates children and detached children do not notify',
    () {
      final parent = SkedTaskSession();
      final child = SkedTaskSession(parent: parent);
      final detached = SkedTaskSession(parent: parent);
      detached.dispose();
      parent.dispose();
      expect(child.isCurrent, isFalse);
      expect(detached.isCurrent, isFalse);
      child.dispose();
    },
  );
  test(
    'target identity and data replacement cannot revive a session',
    () async {
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      final session = SkedTaskSession(provider: p, workspace: AppMode.general);
      addTearDown(session.dispose);
      final backup = await p.exportAppDataJson();
      await p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
      expect(session.isCurrent, isFalse);
    },
  );
  testWidgets('route guard removes only owned route beneath a newer dialog', (
    t,
  ) async {
    final session = SkedTaskSession();
    addTearDown(session.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SkedTaskRouteGuard(
                parent: session,
                child: const AlertDialog(
                  key: ValueKey('owned'),
                  title: Text('Owned'),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final context = t.element(find.byKey(const ValueKey('owned')));
    final route = ModalRoute.of(context)!;
    final newer = showDialog<void>(
      context: context,
      builder: (_) =>
          const AlertDialog(key: ValueKey('newer'), title: Text('Newer')),
    );
    await t.pumpAndSettle();
    session.invalidate();
    await t.pumpAndSettle();
    expect(route.isActive, isFalse);
    expect(find.byKey(const ValueKey('owned')), findsNothing);
    expect(find.byKey(const ValueKey('newer')), findsOneWidget);
    Navigator.of(t.element(find.byKey(const ValueKey('newer')))).pop();
    await newer;
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
