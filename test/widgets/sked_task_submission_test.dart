import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/sked_task_session.dart';
import 'package:sked/widgets/sked_task_submission_controller.dart';

import '../support/workspace_harness.dart';

void main() {
  testWidgets('submission gate rejects duplicates and releases after failure', (
    t,
  ) async {
    final p = await workspaceProvider(mode: AppMode.general);
    addTearDown(p.dispose);
    final session = SkedTaskSession(provider: p, workspace: AppMode.general);
    addTearDown(session.dispose);
    final submit = SkedTaskSubmissionController(session: session);
    addTearDown(submit.dispose);
    late BuildContext context;
    await t.pumpWidget(
      WorkspaceHarness(
        provider: p,
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final gate = Completer<void>();
    var calls = 0;
    final first = submit.run(
      context: context,
      debugLabel: 'Expected failure',
      command: () async {
        calls++;
        await gate.future;
        throw StateError('Expected');
      },
    );
    expect(submit.busy, isTrue);
    expect(
      await submit.run(
        context: context,
        debugLabel: 'Duplicate',
        command: () async {
          calls++;
        },
      ),
      isFalse,
    );
    await p.setWorkspaceEnabled(AppMode.general, false);
    expect(p.isWorkspaceEnabled(AppMode.general), isTrue);
    gate.complete();
    expect(await first, isFalse);
    expect(submit.busy, isFalse);
    expect(calls, 1);
    expect(
      await submit.run(
        context: context,
        debugLabel: 'Retry',
        command: () async {
          calls++;
        },
      ),
      isTrue,
    );
    expect(calls, 2);
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'invalidation suppresses a successful result without owning the parent session',
    (t) async {
      final p = await workspaceProvider(mode: AppMode.general);
      addTearDown(p.dispose);
      final session = SkedTaskSession(provider: p, workspace: AppMode.general);
      addTearDown(session.dispose);
      final submit = SkedTaskSubmissionController(session: session);
      late BuildContext context;
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      final gate = Completer<void>();
      final result = submit.run(
        context: context,
        debugLabel: 'Pending',
        command: () => gate.future,
      );
      session.invalidate();
      gate.complete();
      expect(await result, isFalse);
      expect(submit.busy, isFalse);
      submit.dispose();
      expect(session.isCurrent, isFalse);
      await t.pumpWidget(const SizedBox());
    },
  );
}
