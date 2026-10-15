import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/app_runtime.dart';
import 'package:sked/screens/period_times_page.dart';
import 'package:sked/widgets/desktop_window_host.dart';
import 'package:sked/widgets/period_time_set_manager.dart';
import 'package:sked/widgets/period_time_set_picker_dialog.dart';
import 'package:sked/widgets/sked_time_picker.dart';
import 'package:sked/widgets/text_transfer_widgets.dart';

import '../support/workspace_harness.dart';

Finder _key(String value) => find.byKey(ValueKey(value));
Finder get _back => _key('period-time-set-manager-back');
Finder get _name => _key('period-times-name');
Finder get _menu => _key('period-time-set-menu');
Finder get _scroll => _key('period-times-editor-scroll-view');

class _Storage extends WorkspaceMemoryStorage {
  _Storage(super.data);

  int writes = 0;
  bool fail = false;
  Completer<void>? pending;

  @override
  Future<void> save(AppData value) async {
    writes++;
    await pending?.future;
    if (fail) throw StateError('period storage unavailable');
    await super.save(value);
  }
}

Future<(AppRuntime, _Storage)> _fixture({
  bool hasTimetables = true,
  bool secondSet = true,
}) async {
  final seed = await workspaceProvider();
  final base = hasTimetables
      ? seed.workspaceView.data
      : buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en');
  seed.dispose();
  final first = base.studentMode.periodTimeSets.first;
  final storage = _Storage(
    base.copyWith(
      studentMode: base.studentMode.copyWith(
        periodTimeSets: [
          first.copyWith(name: 'Morning'),
          ...base.studentMode.periodTimeSets.skip(1),
          if (secondSet)
            PeriodTimeSet(
              id: 'evening-period-set',
              name: 'Evening',
              periodTimes: buildDefaultPeriodTimes(),
            ),
        ],
      ),
    ),
  );
  return (await workspaceProvider(storage: storage), storage);
}

Future<void> _openManager(
  WidgetTester t,
  AppRuntime p, {
  Size size = const Size(1280, 800),
  double textScale = 1,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = size;
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      textScale: textScale,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const PeriodTimeSetManagerPage(),
              ),
            ),
            child: const Text('Open period manager'),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('Open period manager'));
  await t.pumpAndSettle();
}

Future<void> _select(WidgetTester t, String id) async {
  await t.tap(_key('period-time-set-$id'));
  await t.pumpAndSettle();
}

String _draftName(WidgetTester t) =>
    t.widget<TextField>(_name).controller!.text;

Map<String, String> _bindings(AppRuntime p) => {
  for (final timetable in p.studentView.timetables)
    timetable.id: timetable.config.periodTimeSetId,
};

Completer<void> _blockWrites(_Storage storage) {
  final pending = Completer<void>();
  storage.pending = pending;
  addTearDown(() {
    if (!pending.isCompleted) pending.complete();
  });
  return pending;
}

Future<void> _invalidDraft(WidgetTester t, AppRuntime p) async {
  final end = p.studentView.periodTimeSets.first.periodTimes.first.endMinutes;
  await t.tap(_key('period-start-time-action').first);
  await t.pumpAndSettle();
  t
      .widget<SkedTimePicker>(find.byType(SkedTimePicker))
      .onSelected(TimeOfDay(hour: end ~/ 60, minute: end % 60));
  await t.pumpAndSettle();
  expect(_key('period-error-1'), findsOneWidget);
}

int _firstVisiblePeriod(WidgetTester t, int count) {
  final viewport = t.getRect(_scroll);
  for (var index = 1; index <= count; index++) {
    final row = t.getRect(_key('period-row-$index'));
    if (row.bottom > viewport.top && row.top < viewport.bottom) return index;
  }
  throw StateError('No period row is visible');
}

void main() {
  testWidgets(
    'manager has a single application bar and puts resource actions by its name',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      await _openManager(t, p);
      await _select(t, p.studentView.periodTimeSets.first.id);

      expect(find.byType(WorkbenchAppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PeriodTimesPage),
          matching: find.byType(WorkbenchAppBar),
        ),
        findsNothing,
      );
      expect(_back, findsOneWidget);
      expect(
        t.widget<WorkbenchAppBar>(find.byType(WorkbenchAppBar)).bottom,
        isNull,
      );
      expect(_menu.hitTestable(), findsOneWidget);
      expect(
        t.getRect(_menu).center.dy,
        inInclusiveRange(
          t.getRect(_name).top,
          t.getRect(_key('period-times-save-status')).bottom,
        ),
      );
      expect(storage.writes, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'wide back waits for saving and leaves the manager with one click',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final id = p.studentView.periodTimeSets.first.id;
      final bindings = _bindings(p);
      await _openManager(t, p);
      await _select(t, id);
      final pending = _blockWrites(storage);
      await t.enterText(_name, 'Saved before leaving');
      await t.pump();
      final editorTop = t.getTopLeft(_scroll).dy;
      await t.tap(_back);
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));

      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
      expect(find.byType(PeriodTimesPage), findsOneWidget);
      expect(storage.writes, 1);
      expect(t.getTopLeft(_scroll).dy, editorTop);
      pending.complete();
      await t.pumpAndSettle();

      expect(find.byType(PeriodTimeSetManagerPage), findsNothing);
      expect(find.text('Open period manager'), findsOneWidget);
      expect(
        storage.data.studentMode.periodTimeSets.first.name,
        'Saved before leaving',
      );
      expect(_bindings(p), bindings);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'narrow back returns from detail to list and then to the caller',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      await _openManager(t, p, size: const Size(393, 900), textScale: 1.6);
      await _select(t, p.studentView.periodTimeSets.first.id);
      expect(find.byType(WorkbenchAppBar), findsOneWidget);
      await t.enterText(_name, 'Narrow saved name');
      await t.pump();
      await t.tap(_back);
      await t.pumpAndSettle();

      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
      expect(find.byType(PeriodTimesPage), findsNothing);
      expect(
        _key('period-time-set-${p.studentView.periodTimeSets.first.id}')
            .hitTestable(),
        findsOneWidget,
      );
      expect(
        storage.data.studentMode.periodTimeSets.first.name,
        'Narrow saved name',
      );
      await t.tap(_back);
      await t.pumpAndSettle();
      expect(find.text('Open period manager'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'one selection waits for a pending save and opens the requested resource',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final first = p.studentView.periodTimeSets.first;
      final target = p.studentView.periodTimeSets.last;
      final bindings = _bindings(p);
      await _openManager(t, p);
      await _select(t, first.id);
      final pending = _blockWrites(storage);
      await t.enterText(_name, 'Saved while switching');
      await t.pump();
      await t.tap(_key('period-time-set-${target.id}'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));

      expect(_draftName(t), 'Saved while switching');
      expect(storage.writes, 1);
      pending.complete();
      await t.pumpAndSettle();

      expect(_draftName(t), target.name);
      expect(
        t.widget<PeriodTimesPage>(find.byType(PeriodTimesPage)).periodTimeSetId,
        target.id,
      );
      expect(
        storage.data.studentMode.periodTimeSets.first.name,
        'Saved while switching',
      );
      expect(_bindings(p), bindings);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'failed switching keeps the current draft on cancel and continues to the target on retry',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final first = p.studentView.periodTimeSets.first;
      final target = p.studentView.periodTimeSets.last;
      await _openManager(t, p);
      await _select(t, first.id);
      storage.fail = true;
      await t.enterText(_name, 'Recoverable period name');
      await t.pump();
      await _select(t, target.id);

      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(_draftName(t), 'Recoverable period name');
      expect(
        t.widget<PeriodTimesPage>(find.byType(PeriodTimesPage)).periodTimeSetId,
        first.id,
      );
      expect(storage.data.studentMode.periodTimeSets.first.name, first.name);

      await _select(t, target.id);
      expect(find.byType(AlertDialog), findsOneWidget);
      storage.fail = false;
      await t.tap(find.widgetWithText(FilledButton, 'Retry save'));
      await t.pumpAndSettle();
      expect(_draftName(t), target.name);
      expect(
        storage.data.studentMode.periodTimeSets.first.name,
        'Recoverable period name',
      );
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'discarding a failed save opens the original target without a disposal write',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final first = p.studentView.periodTimeSets.first;
      final target = p.studentView.periodTimeSets.last;
      await _openManager(t, p);
      await _select(t, first.id);
      storage.fail = true;
      await t.enterText(_name, 'Discarded period name');
      await t.pump();
      await _select(t, target.id);
      expect(find.byType(AlertDialog), findsOneWidget);
      final writesBeforeDiscard = storage.writes;
      await t.tap(find.widgetWithText(TextButton, 'Discard and exit'));
      await t.pumpAndSettle();
      await t.pump(const Duration(seconds: 1));

      expect(_draftName(t), target.name);
      expect(storage.data.studentMode.periodTimeSets.first.name, first.name);
      expect(storage.writes, writesBeforeDiscard);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'resizing retains the invalid draft and its visible period anchor',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      await _openManager(t, p, size: const Size(1280, 650));
      await _select(t, p.studentView.periodTimeSets.first.id);
      await _invalidDraft(t, p);
      await t.enterText(_name, 'Unpersisted draft across resize');
      final state = t.state(find.byType(PeriodTimesPage));
      final nameController = t.widget<TextField>(_name).controller;
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pump();
      final controller = t.widget<ListView>(_scroll).controller!;
      controller.jumpTo(controller.position.maxScrollExtent);
      await t.pumpAndSettle();
      final count = p.studentView.periodTimeSets.first.periodTimes.length;
      final anchor = _firstVisiblePeriod(t, count);
      expect(anchor, greaterThan(1));

      t.view.physicalSize = const Size(393, 650);
      await t.pumpAndSettle();
      expect(t.state(find.byType(PeriodTimesPage)), same(state));
      expect(_firstVisiblePeriod(t, count), anchor);
      t.view.physicalSize = const Size(1280, 650);
      await t.pumpAndSettle();
      expect(t.state(find.byType(PeriodTimesPage)), same(state));
      expect(t.widget<TextField>(_name).controller, same(nameController));
      expect(_draftName(t), 'Unpersisted draft across resize');
      expect(_firstVisiblePeriod(t, count), anchor);
      expect(storage.writes, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'invalid back cancellation retains the editor and discard exits directly on wide screens',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      await _openManager(t, p);
      await _select(t, p.studentView.periodTimeSets.first.id);
      await _invalidDraft(t, p);
      await t.tap(_back);
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry save'), findsNothing);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(_key('period-error-1'), findsOneWidget);
      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);

      await t.tap(_back);
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Discard and exit'));
      await t.pumpAndSettle();
      expect(find.text('Open period manager'), findsOneWidget);
      expect(storage.writes, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'deleting the last resource leaves the manager at its empty state',
    (t) async {
      final (p, storage) = await _fixture(
        hasTimetables: false,
        secondSet: false,
      );
      addTearDown(p.dispose);
      await _openManager(t, p);
      await _select(t, p.studentView.periodTimeSets.single.id);
      await t.tap(_menu);
      await t.pumpAndSettle();
      await t.tap(find.text('Delete period time set'));
      // The resource action remains busy while confirmation is open.
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      await t.tap(find.widgetWithText(FilledButton, 'Delete'));
      await t.pumpAndSettle();

      expect(p.studentView.periodTimeSets, isEmpty);
      expect(storage.data.studentMode.periodTimeSets, isEmpty);
      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
      expect(find.byType(PeriodTimesPage), findsNothing);
      expect(find.text('No available period time set'), findsOneWidget);
      expect(_key('period-time-set-create').hitTestable(), findsOneWidget);
      expect(_back.hitTestable(), findsOneWidget);
      expect(find.byType(WorkbenchAppBar), findsOneWidget);
      await t.tap(_back);
      await t.pumpAndSettle();
      expect(find.text('Open period manager'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'template text import has one page bar and returns to the same resource on cancel',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      final resource = p.studentView.periodTimeSets.first;
      final bindings = _bindings(p);
      await _openManager(t, p);
      await _select(t, resource.id);
      final editorState = t.state(find.byType(PeriodTimesPage));
      await t.tap(_menu);
      await t.pumpAndSettle();
      await t.tap(find.text('Import period template from text'));
      await t.pumpAndSettle();

      expect(find.byType(TextImportPage), findsOneWidget);
      expect(find.byType(WorkbenchAppBar), findsOneWidget);
      expect(_back, findsNothing);
      expect(find.byType(BackButton), findsOneWidget);
      await t.enterText(find.byType(TextField), 'Unsubmitted template content');
      await t.pageBack();
      await t.pumpAndSettle();

      expect(find.byType(TextImportPage), findsNothing);
      expect(find.byType(WorkbenchAppBar), findsOneWidget);
      expect(t.state(find.byType(PeriodTimesPage)), same(editorState));
      expect(_draftName(t), resource.name);
      expect(_bindings(p), bindings);
      expect(storage.writes, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'an externally removed selection cannot keep displaying an editable draft',
    (t) async {
      final (p, storage) = await _fixture(hasTimetables: false);
      addTearDown(p.dispose);
      final target = p.studentView.periodTimeSets.last;
      await _openManager(t, p);
      await _select(t, target.id);
      await p.studentCommands.deletePeriodTimeSet(target.id);
      await t.pumpAndSettle();

      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
      expect(_name, findsNothing);
      expect(_menu, findsNothing);
      expect(
        storage.data.studentMode.periodTimeSets.map((set) => set.id),
        isNot(contains(target.id)),
      );
      await _select(t, p.studentView.periodTimeSets.single.id);
      expect(_draftName(t), p.studentView.periodTimeSets.single.name);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'desktop picker management returns to its unchanged selection draft',
    (t) async {
      final (p, storage) = await _fixture();
      addTearDown(p.dispose);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 800);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final bindings = _bindings(p);
      var completed = false;
      String? selected;
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showPeriodTimeSetPickerDialog(
                    context,
                    selectedPeriodTimeSetId:
                        p.studentView.periodTimeSets.first.id,
                  );
                  completed = true;
                },
                child: const Text('Choose periods'),
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Choose periods'));
      await t.pumpAndSettle();
      await t.tap(_key('period-time-set-manage'));
      await t.pumpAndSettle();
      await _select(t, p.studentView.periodTimeSets.last.id);
      expect(find.byType(WorkbenchAppBar), findsOneWidget);
      await t.tap(_back);
      await t.pumpAndSettle();
      expect(find.byType(PeriodTimeSetManagerPage), findsNothing);
      final picker = t.widget<PeriodTimeSetPickerDialogView>(
        find.byType(PeriodTimeSetPickerDialogView),
      );
      expect(
        picker.selectedPeriodTimeSetId,
        p.studentView.periodTimeSets.first.id,
      );
      expect(picker.blocked, isFalse);
      await t.tap(find.widgetWithText(TextButton, 'Cancel'));
      await t.pumpAndSettle();
      expect(completed, isTrue);
      expect(selected, isNull);
      expect(_bindings(p), bindings);
      expect(storage.writes, 0);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets('system back and Escape use the same guarded manager return', (
    t,
  ) async {
    final (p, storage) = await _fixture();
    addTearDown(p.dispose);
    final first = p.studentView.periodTimeSets.first;
    await _openManager(t, p);
    await _select(t, first.id);
    await t.enterText(_name, 'Saved by system back');
    await t.pump();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(PeriodTimeSetManagerPage), findsNothing);
    expect(
      storage.data.studentMode.periodTimeSets.first.name,
      'Saved by system back',
    );

    await t.tap(find.text('Open period manager'));
    await t.pumpAndSettle();
    await _select(t, first.id);
    await t.enterText(_name, 'Saved by Escape');
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pumpAndSettle();
    expect(find.byType(PeriodTimeSetManagerPage), findsNothing);
    expect(
      storage.data.studentMode.periodTimeSets.first.name,
      'Saved by Escape',
    );
    expect(t.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'template import closes when its source is removed and never targets another set',
    (t) async {
      final (p, storage) = await _fixture(hasTimetables: false);
      addTearDown(p.dispose);
      final target = p.studentView.periodTimeSets.last;
      final retained = p.studentView.periodTimeSets.first;
      await _openManager(t, p);
      await _select(t, target.id);
      await t.tap(_menu);
      await t.pumpAndSettle();
      await t.tap(find.text('Import period template from text'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'Unsubmitted import');
      await p.studentCommands.deletePeriodTimeSet(target.id);
      await t.pumpAndSettle();
      expect(find.byType(TextImportPage), findsNothing);
      expect(find.byType(PeriodTimeSetManagerPage), findsOneWidget);
      expect(find.byType(PeriodTimesPage), findsNothing);
      expect(p.studentView.periodTimeSets.single.id, retained.id);
      expect(p.studentView.periodTimeSets.single.name, retained.name);
      expect(storage.writes, 1);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'opening a missing resource never fabricates an editable default time set',
    (t) async {
      final (p, storage) = await _fixture(hasTimetables: false);
      addTearDown(p.dispose);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(1280, 800);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(
        WorkspaceHarness(
          provider: p,
          home: const PeriodTimesPage(periodTimeSetId: 'missing-resource'),
        ),
      );
      await t.pumpAndSettle();

      expect(_name, findsNothing);
      expect(_key('period-start-time-action'), findsNothing);
      expect(find.text('No available period time set'), findsOneWidget);
      expect(storage.writes, 0);
      expect(p.studentView.periodTimeSetForId('missing-resource'), isNull);
      expect(t.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
