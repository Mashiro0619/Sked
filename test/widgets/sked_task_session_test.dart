import 'package:provider/provider.dart';
import 'package:sked/controllers/app_session.dart';
import 'package:sked/controllers/settings_commands.dart';
import 'package:sked/controllers/settings_view_state.dart';
import 'package:sked/providers/app_scope.dart';

import 'package:sked/widgets/expressive_dialog.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/sked_task_route.dart';
import 'package:sked/widgets/sked_adaptive_picker_dialog.dart';
import 'package:sked/widgets/sked_task_dialog.dart';
import 'package:sked/controllers/app_backup_controller.dart' show AppImportMode;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_task_session.dart';

import '../support/workspace_harness.dart';

void main() {
  testWidgets(
    'an adaptive picker uses its source scope across the root Navigator',
    (tester) async {
      final outer = await workspaceProvider(locale: 'en');
      final inner = await workspaceProvider(locale: 'ja');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        inner.dispose();
        outer.dispose();
      });
      await tester.pumpWidget(
        WorkspaceHarness(
          provider: outer,
          home: AppScope(
            app: inner,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showSkedAdaptivePickerDialog<void>(
                    context: context,
                    workspace: AppMode.student,
                    routeName: 'scoped-adaptive-picker',
                    builder: (_) => Consumer<SettingsViewState>(
                      builder: (taskContext, settings, _) {
                        expect(
                          taskContext.read<AppSession>(),
                          same(inner.session),
                        );
                        return SkedTaskDialog(
                          title: const Text('Scoped picker'),
                          content: TextButton(
                            onPressed: () => taskContext
                                .read<SettingsCommands>()
                                .updateLocaleCode('zh'),
                            child: Text(settings.localeCode),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  completeSkedTaskRoute(taskContext),
                              child: const Text('Close picker'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  child: const Text('Open scoped picker'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open scoped picker'));
      await tester.pumpAndSettle();
      expect(find.text('ja').hitTestable(), findsOneWidget);
      await tester.tap(find.text('ja'));
      await tester.pumpAndSettle();
      expect(find.text('zh'), findsOneWidget);
      expect(inner.settingsView.localeCode, 'zh');
      expect(outer.settingsView.localeCode, 'en');

      expect(find.text('Close picker').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Close picker'));
      await tester.pumpAndSettle();
      await inner.settingsCommands.updateLocaleCode('en');
      expect(inner.settingsView.localeCode, 'en');
      expect(find.text('Scoped picker'), findsNothing);
      expect(find.text('Open scoped picker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.windows,
    }),
  );

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
      final session = SkedTaskSession(
        maintenance: p.maintenance,
        workspaceView: p.workspaceView,
        workspaces: p.workspaces,
        workspace: AppMode.general,
      );
      addTearDown(session.dispose);
      final backup = await p.backups.exportJson();
      await p.backups.importJson(backup, mode: AppImportMode.replaceAll);
      expect(session.isCurrent, isFalse);
    },
  );
  test(
    'domain maintenance invalidates tasks before replacement begins',
    () async {
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      final session = SkedTaskSession(
        maintenance: p.maintenance,
        workspaceView: p.workspaceView,
        workspaces: p.workspaces,
        workspace: AppMode.general,
      );
      addTearDown(session.dispose);
      var notices = 0;
      session.addListener(() => notices++);

      final reservation = p.maintenance.reserve();
      expect(notices, 1);
      expect(session.isCurrent, isFalse);
      p.maintenance.release(reservation);
      expect(session.isCurrent, isFalse);
      expect(notices, 1);
    },
  );
  test('domain workspace changes cannot revive a retired task', () async {
    final p = await workspaceProvider(mode: AppMode.general);
    addTearDown(p.dispose);
    final session = SkedTaskSession(
      maintenance: p.maintenance,
      workspaceView: p.workspaceView,
      workspaces: p.workspaces,
      workspace: AppMode.general,
    );
    addTearDown(session.dispose);
    var notices = 0;
    session.addListener(() => notices++);

    await p.workspaces.setEnabled(AppMode.general, false);
    expect(notices, 1);
    expect(session.isCurrent, isFalse);
    await p.workspaces.setEnabled(AppMode.general, true);
    expect(session.isCurrent, isFalse);
    expect(notices, 1);
  });
  test('a target domain retires a task when its calendar is deleted', () async {
    final p = await workspaceProvider(mode: AppMode.general);
    addTearDown(p.dispose);
    final calendarId = p.generalView.schedules.last.id;
    final session = SkedTaskSession(
      maintenance: p.maintenance,
      workspaceView: p.workspaceView,
      workspaces: p.workspaces,
      targetChanges: p.generalView,
      workspace: AppMode.general,
      isTargetCurrent: () =>
          p.generalView.schedules.any((calendar) => calendar.id == calendarId),
    );
    addTearDown(session.dispose);
    var notices = 0;
    session.addListener(() => notices++);

    await p.generalCommands.deleteSchedule(calendarId);
    expect(p.workspaceView.isEnabled(AppMode.general), isTrue);
    expect(notices, 1);
    expect(session.isCurrent, isFalse);
  });
  test('disposed domain tasks detach their target listener', () {
    final target = ValueNotifier(true);
    addTearDown(target.dispose);
    var reads = 0;
    final session = SkedTaskSession(
      targetChanges: target,
      isTargetCurrent: () {
        reads++;
        return target.value;
      },
    );
    expect(session.isCurrent, isTrue);
    final beforeDispose = reads;
    session.dispose();
    target.value = false;
    expect(reads, beforeDispose);
  });
  testWidgets('domain guard retires only its route during maintenance', (
    t,
  ) async {
    final p = await workspaceProvider(mode: AppMode.general);
    addTearDown(p.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => SkedTaskRouteGuard(
                maintenance: p.maintenance,
                workspaceView: p.workspaceView,
                workspaces: p.workspaces,
                workspace: AppMode.general,
                child: const AlertDialog(title: Text('Domain task')),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    final ownContext = t.element(find.text('Domain task'));
    final route = ModalRoute.of(ownContext)!;
    final newer = showDialog<void>(
      context: ownContext,
      builder: (_) => const AlertDialog(title: Text('Newer domain task')),
    );
    await t.pumpAndSettle();

    final reservation = p.maintenance.reserve();
    try {
      await t.pumpAndSettle();
      expect(route.isActive, isFalse);
      expect(find.text('Domain task'), findsNothing);
      expect(find.text('Newer domain task'), findsOneWidget);
    } finally {
      p.maintenance.release(reservation);
    }
    completeSkedTaskRoute(t.element(find.text('Newer domain task')));
    await newer;
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
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
