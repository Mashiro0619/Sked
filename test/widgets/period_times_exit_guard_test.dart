import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/widgets/sked_time_picker.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

class _ExitStorage extends WorkspaceMemoryStorage {
  _ExitStorage()
    : super(buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en'));

  bool fail = false;
  int writes = 0;
  Completer<void>? pending;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await pending?.future;
    if (fail) throw StateError('period save failed');
    await super.save(value);
  }
}

Future<void> _openEditor(
  WidgetTester t,
  TimetableProvider p, {
  bool asHome = false,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1280, 800);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  Widget editor() =>
      PeriodTimesPage(periodTimeSetId: p.periodTimeSets.first.id);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      home: asHome
          ? editor()
          : Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context)
                      .push<void>(MaterialPageRoute(builder: (_) => editor())),
                  child: const Text('Open editor'),
                ),
              ),
            ),
    ),
  );
  if (!asHome) await t.tap(find.text('Open editor'));
  await t.pumpAndSettle();
}

Future<void> _makeInvalidDraft(WidgetTester t) async {
  await t.tap(_key('period-start-time-action').first);
  await t.pumpAndSettle();
  t
      .widget<SkedTimePicker>(find.byType(SkedTimePicker))
      .onSelected(const TimeOfDay(hour: 8, minute: 50));
  await t.pumpAndSettle();
  expect(_key('period-error-1'), findsOneWidget);
}

String _replacementBackup(_ExitStorage storage) {
  final set = storage.data.studentMode.periodTimeSets.first;
  return encodeAppDataEnvelope(
    storage.data.copyWith(
      studentMode: storage.data.studentMode.copyWith(
        periodTimeSets: [
          set.copyWith(
            name: 'Restored times',
            periodTimes: [
              for (final time in set.periodTimes)
                time.copyWith(
                  startMinutes: time.startMinutes + 30,
                  endMinutes: time.endMinutes + 30,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets(
    'replacement flushes a debounced name before retiring the old snapshot',
    (t) async {
      final storage = _ExitStorage();
      final backup = _replacementBackup(storage);
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await _openEditor(t, p);
      await t.enterText(_key('period-times-name'), 'Pending old name');
      expect(storage.writes, 0);
      final restore = p.importAppDataJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      await t.pumpAndSettle();
      await restore;
      expect(find.byType(PeriodTimesPage), findsNothing);
      expect(p.periodTimeSets.first.name, 'Restored times');
      expect(p.periodTimeSets.first.periodTimes.first.startMinutes, 510);
      final writesAfterRestore = storage.writes;
      await t.pump(const Duration(seconds: 1));
      expect(storage.writes, writesAfterRestore);
      expect(
        storage.data.studentMode.periodTimeSets.first.name,
        'Restored times',
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'discarding a failed save through window close does not retry during disposal',
    (t) async {
      final storage = _ExitStorage()..fail = true;
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await _openEditor(t, p);
      await t.enterText(_key('period-times-name'), 'Discarded old name');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      final close = p.prepareForWindowClose();
      await t.pumpAndSettle();
      final writesBeforeDiscard = storage.writes;
      await t.tap(find.text('Discard and exit'));
      await t.pumpAndSettle();
      expect(await close, isTrue);
      expect(find.byType(PeriodTimesPage), findsNothing);
      expect(storage.writes, writesBeforeDiscard);
      expect(
        storage.data.studentMode.periodTimeSets.first.name,
        isNot('Discarded old name'),
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('native close confirms an invalid period draft and can cancel', (
    t,
  ) async {
    final storage = _ExitStorage();
    final p = await workspaceProvider(storage: storage);
    addTearDown(p.dispose);
    await _openEditor(t, p);
    await _makeInvalidDraft(t);

    final close = p.prepareForWindowClose();
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(await p.prepareForWindowClose(), isFalse);
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(await close, isFalse);
    expect(_key('period-error-1'), findsOneWidget);
    expect(p.periodTimeSets.first.periodTimes.first.startMinutes, 480);

    final discard = p.prepareForWindowClose();
    await t.pumpAndSettle();
    await t.tap(find.text('Discard and exit'));
    await t.pumpAndSettle();
    expect(await discard, isTrue);
    expect(find.byType(PeriodTimesPage), findsNothing);
    expect(storage.writes, 0);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'workspace disable preserves an invalid draft until discard is confirmed',
    (t) async {
      final storage = _ExitStorage();
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await _openEditor(t, p);
      await _makeInvalidDraft(t);

      final cancel = p.setWorkspaceEnabled(AppMode.student, false);
      await t.pumpAndSettle();
      expect(p.isWorkspaceEnabled(AppMode.student), isTrue);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      await cancel;
      expect(p.isWorkspaceEnabled(AppMode.student), isTrue);
      expect(_key('period-error-1'), findsOneWidget);

      final discard = p.setWorkspaceEnabled(AppMode.student, false);
      await t.pumpAndSettle();
      await t.tap(find.text('Discard and exit'));
      await t.pumpAndSettle();
      await discard;
      expect(p.isWorkspaceEnabled(AppMode.student), isFalse);
      expect(find.byType(PeriodTimesPage, skipOffstage: false), findsNothing);
      expect(
        storage
            .data
            .studentMode
            .periodTimeSets
            .first
            .periodTimes
            .first
            .startMinutes,
        480,
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'window close waits for a pending period save before retiring the editor',
    (t) async {
      final storage = _ExitStorage()..pending = Completer<void>();
      addTearDown(() {
        if (!storage.pending!.isCompleted) storage.pending!.complete();
      });
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await _openEditor(t, p);
      await t.enterText(_key('period-times-name'), 'Pending period name');
      bool? result;
      final close = p.prepareForWindowClose().then((value) => result = value);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(result, isNull);
      expect(storage.writes, 1);
      expect(find.byType(PeriodTimesPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      storage.pending!.complete();
      await t.pumpAndSettle();
      await close;
      expect(result, isTrue);
      expect(
        storage.data.studentMode.periodTimeSets.first.name,
        'Pending period name',
      );
      expect(find.byType(PeriodTimesPage), findsNothing);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('window close offers retry after period persistence fails', (
    t,
  ) async {
    final storage = _ExitStorage()..fail = true;
    final p = await workspaceProvider(storage: storage);
    addTearDown(p.dispose);
    await _openEditor(t, p);
    await t.enterText(_key('period-times-name'), 'Retryable period name');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    final close = p.prepareForWindowClose();
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(storage.writes, 2);
    storage.fail = false;
    await t.tap(find.widgetWithText(FilledButton, 'Retry save'));
    await t.pumpAndSettle();
    expect(await close, isTrue);
    expect(storage.writes, 3);
    expect(
      storage.data.studentMode.periodTimeSets.first.name,
      'Retryable period name',
    );
    expect(find.byType(PeriodTimesPage), findsNothing);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('workspace exit does not race an open period time picker', (
    t,
  ) async {
    final storage = _ExitStorage();
    final p = await workspaceProvider(storage: storage);
    addTearDown(p.dispose);
    await _openEditor(t, p);
    await t.tap(_key('period-start-time-action').first);
    await t.pumpAndSettle();
    expect(await p.prepareForWindowClose(), isFalse);
    expect(find.byType(SkedTimePicker), findsOneWidget);
    await t.tap(_key('sked-time-cancel'));
    await t.pumpAndSettle();
    expect(find.byType(PeriodTimesPage), findsOneWidget);
    expect(storage.writes, 0);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'replace-all retires the old period route without popping the restore route',
    (t) async {
      final storage = _ExitStorage();
      final backup = _replacementBackup(storage);
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await _openEditor(t, p);
      final staleNameChanged = t
          .widget<TextField>(_key('period-times-name'))
          .onChanged!;
      final navigator = Navigator.of(t.element(find.byType(PeriodTimesPage)));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Restore route')),
          ),
        ),
      );
      await t.pumpAndSettle();
      final restore = p.importAppDataJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      await t.pumpAndSettle();
      await restore;
      expect(find.text('Restore route'), findsOneWidget);
      expect(find.byType(PeriodTimesPage, skipOffstage: false), findsNothing);
      staleNameChanged('Obsolete callback');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(p.periodTimeSets.first.name, 'Restored times');
      expect(p.periodTimeSets.first.periodTimes.first.startMinutes, 510);
      expect(
        storage
            .data
            .studentMode
            .periodTimeSets
            .first
            .periodTimes
            .first
            .startMinutes,
        510,
      );
      navigator.pop();
      await t.pumpAndSettle();
      await t.tap(find.text('Open editor'));
      await t.pumpAndSettle();
      expect(
        t.widget<TextField>(_key('period-times-name')).controller!.text,
        'Restored times',
      );
      expect(find.text('08:30'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'replace-all can be cancelled without losing an invalid period draft',
    (t) async {
      final storage = _ExitStorage();
      final backup = _replacementBackup(storage);
      final p = await workspaceProvider(storage: storage);
      addTearDown(p.dispose);
      await _openEditor(t, p);
      await _makeInvalidDraft(t);
      final restore = p.importAppDataJson(
        backup,
        mode: AppImportMode.replaceAll,
      );
      final cancelled = expectLater(
        restore,
        throwsA(isA<WorkspaceChangeCancelledException>()),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      await cancelled;
      expect(_key('period-error-1'), findsOneWidget);
      expect(p.periodTimeSets.first.periodTimes.first.startMinutes, 480);
      expect(storage.writes, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('a first-route period editor is inert after replacement', (
    t,
  ) async {
    final storage = _ExitStorage();
    final backup = _replacementBackup(storage);
    final p = await workspaceProvider(storage: storage);
    addTearDown(p.dispose);
    await _openEditor(t, p, asHome: true);
    final staleNameChanged = t
        .widget<TextField>(_key('period-times-name'))
        .onChanged!;
    final restore = p.importAppDataJson(backup, mode: AppImportMode.replaceAll);
    await t.pumpAndSettle();
    await restore;
    expect(_key('period-times-name'), findsNothing);
    staleNameChanged('Obsolete callback');
    await t.pump(const Duration(milliseconds: 500));
    expect(p.periodTimeSets.first.periodTimes.first.startMinutes, 510);
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
