import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/agenda_runtime_mutation_lock.dart';

import '../support/workspace_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('clearing a custom view and switching workspace never wait for notification projection', () async {
    final seed = await workspaceProvider(mode: AppMode.general);
    final data = seed.appData.copyWith(
      generalMode: seed.generalMode.copyWith(
        selectedDateIso: '2026-09-03',
        customDateRange: GeneralDateRange(
          DateTime(2026, 9, 3),
          DateTime(2026, 9, 12),
        ),
      ),
    );
    seed.dispose();
    final storage = WorkspaceMemoryStorage(data);
    final provider = await workspaceProvider(
      storage: storage,
      workspaceMutationLock: withAgendaRuntimeMutationLock<void>,
    );
    addTearDown(provider.dispose);
    final entered = Completer<void>(), release = Completer<void>();
    final projection = withAgendaRuntimeMutationLock(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final navigation = provider.clearGeneralDateRange();
    final workspaceSwitch = provider.switchMode(AppMode.student);
    var completed = false;
    try {
      await Future.wait([navigation, workspaceSwitch])
          .timeout(const Duration(milliseconds: 600));
      completed = true;
    } on TimeoutException {
      // Clean up both accepted UI operations before checking the regression.
    } finally {
      release.complete();
      await projection;
      await navigation;
      await workspaceSwitch;
    }
    expect(
      completed,
      isTrue,
      reason: 'UI navigation must not queue behind unrelated platform notifications.',
    );
    expect(provider.customGeneralDateRange, isNull);
    expect(storage.data.generalMode.customDateRange, isNull);
    expect(provider.activeMode, AppMode.student);
  });
}
