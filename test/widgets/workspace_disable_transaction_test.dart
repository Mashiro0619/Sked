import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/settings_page.dart';
import 'package:sked/screens/theme_settings_page.dart';
import 'package:sked/screens/workspace_features_page.dart';

import '../support/workspace_harness.dart';

class _PendingStorage extends WorkspaceMemoryStorage {
  _PendingStorage(super.data);

  Completer<void>? pending;
  int writes = 0;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await pending?.future;
    await super.save(value);
  }
}

Future<(TimetableProvider, _PendingStorage)> _fixture() async {
  final seed = await workspaceProvider();
  final storage = _PendingStorage(seed.appData);
  seed.dispose();
  return (await workspaceProvider(storage: storage), storage);
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _finishTransitions(WidgetTester tester) async {
  // An indeterminate save indicator intentionally keeps scheduling frames.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump();
}

Finder get _studentSwitch =>
    find.byKey(const ValueKey('workspace-enabled-student'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final fails in [false, true]) {
    testWidgets(
      'workspace disable protects back and returns safely after ${fails ? 'failed' : 'successful'} save',
      (tester) async {
        _viewport(tester, const Size(393, 900));
        final (provider, storage) = await _fixture();
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          WorkspaceHarness(provider: provider, home: const SettingsPage()),
        );
        await tester.pumpAndSettle();
        final features = find.byKey(
          const ValueKey('settings-workspace-features'),
        );
        await tester.ensureVisible(features);
        await tester.pumpAndSettle();
        await tester.tap(features);
        await tester.pumpAndSettle();
        final l = AppLocalizations.of(tester.element(_studentSwitch));

        storage.pending = Completer<void>();
        if (fails) storage.saveError = StateError('disk full');
        final writesBefore = storage.writes;
        await tester.tap(_studentSwitch);
        await tester.pumpAndSettle();
        await tester.tap(find.text(l.confirm));
        await _finishTransitions(tester);
        expect(storage.writes, writesBefore + 1);
        expect(provider.isWorkspaceEnabled(AppMode.student), isTrue);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        await tester.pageBack();
        await _finishTransitions(tester);
        await tester.binding.handlePopRoute();
        await _finishTransitions(tester);
        expect(find.byType(WorkspaceFeaturesPage), findsOneWidget);
        expect(storage.pending!.isCompleted, isFalse);
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(430, 900);
        await _finishTransitions(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(provider.appData.enabledWorkspaces, provider.enabledWorkspaces);

        storage.pending!.complete();
        await tester.pumpAndSettle();
        storage.pending = null;
        expect(provider.isWorkspaceEnabled(AppMode.student), fails);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        if (fails) {
          expect(find.text(l.saveFailedRetry), findsOneWidget);
        }

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceFeaturesPage), findsNothing);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(tester.takeException(), isNull);
        expect(provider.activeMode, fails ? AppMode.student : AppMode.general);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.windows,
      }),
    );

    testWidgets(
      'visible theme survives resize while workspace disable ${fails ? 'fails' : 'succeeds'}',
      (tester) async {
        _viewport(tester, const Size(393, 900));
        final (provider, storage) = await _fixture();
        addTearDown(provider.dispose);
        await tester.pumpWidget(
          WorkspaceHarness(
            provider: provider,
            home: const ThemeSettingsPage(initialWorkspace: AppMode.student),
          ),
        );
        await tester.pumpAndSettle();
        storage.pending = Completer<void>();
        if (fails) storage.saveError = StateError('disk full');
        final disable = provider.setWorkspaceEnabled(AppMode.student, false);
        final completion = fails
            ? expectLater(disable, throwsStateError)
            : disable;
        await _finishTransitions(tester);
        expect(provider.isWorkspaceEnabled(AppMode.student), isTrue);

        tester.view.physicalSize = const Size(900, 1000);
        await _finishTransitions(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
        expect(find.byType(ThemeSettingsPage), findsOneWidget);

        storage.pending!.complete();
        await tester.pumpAndSettle();
        await completion;
        expect(provider.isWorkspaceEnabled(AppMode.student), fails);
        expect(tester.takeException(), isNull);
        expect(find.byType(ErrorWidget), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets('embedded workspace controls retain their save and back guard', (
    tester,
  ) async {
    _viewport(tester, const Size(393, 900));
    final (provider, storage) = await _fixture();
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      WorkspaceHarness(
        provider: provider,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Workspace settings')),
                    body: const WorkspaceFeaturesPage(embedded: true),
                  ),
                ),
              ),
              child: const Text('Open workspace settings'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open workspace settings'));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(_studentSwitch));
    storage.pending = Completer<void>();
    await tester.tap(_studentSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.confirm));
    await _finishTransitions(tester);

    await tester.pageBack();
    await _finishTransitions(tester);
    expect(find.byType(WorkspaceFeaturesPage), findsOneWidget);
    expect(provider.isWorkspaceEnabled(AppMode.student), isTrue);
    expect(tester.takeException(), isNull);

    storage.pending!.complete();
    await tester.pumpAndSettle();
    expect(provider.isWorkspaceEnabled(AppMode.student), isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceFeaturesPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
