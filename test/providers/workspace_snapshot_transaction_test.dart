import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/providers/workspace_theme_target.dart';

import '../support/workspace_harness.dart';

class _PendingStorage extends WorkspaceMemoryStorage {
  _PendingStorage(super.data);

  final started = Completer<void>();
  final pending = Completer<void>();

  @override
  Future<void> save(AppData value) async {
    started.complete();
    await pending.future;
    await super.save(value);
  }
}

AppData _initialData() =>
    buildInitialAppData(buildDefaultPeriodTimes())
        .copyWith(themeSeedColorValue: 0xff123456)
        .copyWith(activeMode: AppMode.general, themeSeedColorValue: 0xffabcdef)
        .copyWith(activeMode: AppMode.student);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fails in [false, true]) {
    test(
      'workspace readers keep a consistent snapshot until disable ${fails ? 'rolls back' : 'commits'}',
      () async {
        final original = _initialData();
        final storage = _PendingStorage(original);
        if (fails) storage.saveError = StateError('disk full');
        final provider = await workspaceProvider(storage: storage);
        addTearDown(provider.dispose);
        final commits = <AppDataCommit>[];
        final subscription = provider.session.commits.listen(commits.add);
        addTearDown(subscription.cancel);

        final disable = provider.workspaces.setEnabled(AppMode.student, false);
        final completion = fails
            ? expectLater(disable, throwsStateError)
            : disable;
        await storage.started.future;

        expect(provider.workspaceView.activeMode, AppMode.student);
        expect(
          provider.workspaceView.enabledWorkspaces,
          AppMode.values.toSet(),
        );
        expect(
          provider.workspaceView.data.activeMode,
          provider.workspaceView.activeMode,
        );
        expect(
          provider.workspaceView.data.enabledWorkspaces,
          provider.workspaceView.enabledWorkspaces,
        );
        expect(provider.workspaceView.data.themeSeedColorValue, 0xff123456);
        expect(
          WorkspaceThemeTarget(
            settings: provider.settingsView,
            settingsCommands: provider.settingsCommands,
            general: provider.generalView,
            generalCommands: provider.generalCommands,
            activeMode: AppMode.student,
          ).themeSeedColorValue,
          0xff123456,
        );
        expect(
          WorkspaceThemeTarget(
            settings: provider.settingsView,
            settingsCommands: provider.settingsCommands,
            general: provider.generalView,
            generalCommands: provider.generalCommands,
            activeMode: AppMode.general,
          ).themeSeedColorValue,
          0xffabcdef,
        );
        expect(provider.session.committedData, same(original));
        expect(commits, isEmpty);
        // A valid read snapshot must not permit edits to the pending disable.
        await expectLater(
          provider.settingsCommands.updateThemeMode(
            'dark',
            workspace: AppMode.student,
          ),
          throwsStateError,
        );

        storage.pending.complete();
        await completion;
        await Future<void>.delayed(Duration.zero);

        final expectedMode = fails ? AppMode.student : AppMode.general;
        final expectedWorkspaces = fails
            ? AppMode.values.toSet()
            : {AppMode.general};
        expect(provider.workspaceView.activeMode, expectedMode);
        expect(provider.workspaceView.data.activeMode, expectedMode);
        expect(provider.workspaceView.enabledWorkspaces, expectedWorkspaces);
        expect(
          provider.workspaceView.data.enabledWorkspaces,
          expectedWorkspaces,
        );
        expect(storage.data.enabledWorkspaces, expectedWorkspaces);
        expect(
          provider.session.committedData.enabledWorkspaces,
          expectedWorkspaces,
        );
        expect(
          provider.settingsView.themeDataFor(expectedMode).themeSeedColorValue,
          fails ? 0xff123456 : 0xffabcdef,
        );
        expect(commits, hasLength(fails ? 0 : 1));
        if (!fails) {
          expect(commits.single.snapshot.enabledWorkspaces, expectedWorkspaces);
          expect(
            () => provider.settingsView.themeDataFor(AppMode.student),
            throwsStateError,
          );
        }
      },
    );
  }

  test('mode switch keeps appData and the visible mode aligned', () async {
    final storage = _PendingStorage(_initialData());
    final provider = await workspaceProvider(storage: storage);
    addTearDown(provider.dispose);

    final switching = provider.workspaces.switchMode(AppMode.general);
    await storage.started.future;
    expect(provider.workspaceView.activeMode, AppMode.student);
    expect(provider.workspaceView.data.activeMode, AppMode.student);
    expect(
      provider.workspaceView.data.themeSeedColorValue,
      provider.settingsView.themeSeedColorValue,
    );

    storage.pending.complete();
    await switching;
    expect(provider.workspaceView.activeMode, AppMode.general);
    expect(provider.workspaceView.data.activeMode, AppMode.general);
    expect(provider.workspaceView.data.themeSeedColorValue, 0xffabcdef);
  });
}
