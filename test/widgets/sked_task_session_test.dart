import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/sked_task_route.dart';
import 'package:sked/widgets/sked_adaptive_picker_dialog.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_task_session.dart';

import '../support/workspace_harness.dart';

void main() {
  for (final waitForTransition in [false, true]) {
    testWidgets(
      'adaptive picker retires with owner and preserves newer route; wait=$waitForTransition',
      (t) async {
        final p = await workspaceProvider();
        addTearDown(p.dispose);
        late BuildContext home;
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Builder(
              builder: (c) {
                home = c;
                return const SizedBox();
              },
            ),
          ),
        );
        await t.pumpAndSettle();
        late BuildContext owner;
        final route = MaterialPageRoute<void>(
          builder: (c) {
            owner = c;
            return const Scaffold(body: Text('Owner'));
          },
        );
        Navigator.of(home).push(route);
        await t.pumpAndSettle();
        final results = <String?>[];
        final picker = showSkedAdaptivePickerDialog<String>(
          context: owner,
          routeName: 'owner-retirement',
          waitForTransitionComplete: waitForTransition,
          builder: (_) => const SkedTaskDialog(title: Text('Child picker')),
        ).then(results.add);
        await t.pumpAndSettle();
        final childRoute = ModalRoute.of(t.element(find.text('Child picker')))!;
        final newer = showDialog<void>(
          context: home,
          builder: (_) => const AlertDialog(title: Text('Newer task')),
        );
        await t.pumpAndSettle();
        Navigator.of(home).removeRoute(route);
        await t.pumpAndSettle();
        await picker;
        expect(childRoute.isActive, isFalse);
        expect(find.text('Child picker'), findsNothing);
        expect(find.text('Newer task'), findsOneWidget);
        expect(results, [null]);
        completeSkedTaskRoute(t.element(find.text('Newer task')));
        await newer;
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );
  }

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
  testWidgets(
    'adaptive picker propagates session invalidation on desktop and touch',
    (t) async {
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      final session = SkedTaskSession();
      addTearDown(session.dispose);
      final results = <String?>[];
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  results.add(
                    await showSkedAdaptivePickerDialog<String>(
                      context: context,
                      routeName: 'session-test',
                      workspace: AppMode.general,
                      session: session,
                      waitForTransitionComplete: true,
                      builder: (_) => const SkedTaskDialog(
                        key: ValueKey('session-picker'),
                        title: Text('Picker'),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('session-picker')), findsOneWidget);
      session.invalidate();
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('session-picker')), findsNothing);
      expect(results, [null]);
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('session-picker')), findsNothing);
      expect(results, [null, null]);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );
  for (final host in ['dialog', 'sheet']) {
    testWidgets(
      '$host only retires its session beneath unrelated routes',
      (t) async {
        final p = await workspaceProvider(mode: AppMode.general);
        addTearDown(p.dispose);
        final session = SkedTaskSession();
        addTearDown(session.dispose);
        final results = <String?>[];
        await t.pumpWidget(
          WorkspaceHarness(
            provider: p,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    Widget body(BuildContext context) => const SizedBox(
                      key: ValueKey('owned-task'),
                      width: 300,
                      height: 200,
                      child: Text('Owned task'),
                    );
                    results.add(
                      host == 'dialog'
                          ? await showExpressiveDialog<String>(
                              context: context,
                              session: session,
                              builder: body,
                            )
                          : await showAppModalSheet<String>(
                              context: context,
                              session: session,
                              workspace: AppMode.general,
                              builder: body,
                            ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        final ownContext = t.element(find.byKey(const ValueKey('owned-task')));
        final extra = showDialog<void>(
          context: ownContext,
          builder: (_) => const AlertDialog(
            key: ValueKey('unrelated'),
            title: Text('Unrelated'),
          ),
        );
        await t.pumpAndSettle();
        session.invalidate();
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('owned-task')), findsNothing);
        expect(find.byKey(const ValueKey('unrelated')), findsOneWidget);
        expect(results, [null]);
        completeSkedTaskRoute(
          t.element(find.byKey(const ValueKey('unrelated'))),
        );
        await extra;
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.android,
      }),
    );
  }
}
