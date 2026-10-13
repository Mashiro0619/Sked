import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localization_delegates.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/app_modal_sheet.dart';
import 'package:sked/widgets/editor_exit_guard.dart';

enum _Dismiss {
  slowDrag,
  sheetDrag,
  handleAction,
  barrier,
  systemBack,
  cancelButton,
}

Finder get _editor => find.byType(_Editor);
Finder get _sheet => find.byType(BottomSheet).last;

Finder _handle(WidgetTester tester) {
  final label = MaterialLocalizations.of(tester.element(_sheet))
      .modalBarrierDismissLabel;
  return find.descendant(
    of: _sheet,
    matching: find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    ),
  );
}

Future<void> _dismiss(WidgetTester tester, _Dismiss method) async {
  switch (method) {
    case _Dismiss.slowDrag:
      await tester.timedDrag(
        _handle(tester),
        const Offset(0, 450),
        const Duration(seconds: 1),
      );
    case _Dismiss.sheetDrag:
      // Exercise the real sheet recognizer, including its reverse animation.
      await tester.fling(_handle(tester), const Offset(0, 450), 1600);
    case _Dismiss.handleAction:
      final handle = _handle(tester);
      final node = tester.getSemantics(handle);
      tester
          .renderObject(handle)
          .owner!
          .semanticsOwner!
          .performAction(node.id, SemanticsAction.tap);
    case _Dismiss.barrier:
      await tester.tapAt(const Offset(8, 28));
    case _Dismiss.systemBack:
      await tester.binding.handlePopRoute();
    case _Dismiss.cancelButton:
      await tester.tap(
        find.descendant(of: _editor, matching: find.text('Cancel')),
      );
  }
  await tester.pumpAndSettle();
}

Future<void> _mount(
  WidgetTester tester, {
  required Future<void> Function() onSave,
  required void Function(String?) onClosed,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(393, 852);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await showAppModalSheet<String>(
                  context: context,
                  enableDrag: true,
                  showDragHandle: true,
                  builder: (_) => _Editor(onSave: onSave),
                );
                onClosed(result);
              },
              child: const Text('Open from source'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open from source'));
  await tester.pumpAndSettle();
  expect(_editor, findsOneWidget);
  final sheet = tester.widget<BottomSheet>(_sheet);
  expect(sheet.enableDrag, isTrue);
  expect(sheet.showDragHandle, isTrue);
}

void main() {
  testWidgets(
    'authorized completion accepts an int result on a guarded num route',
    (tester) async {
      final results = <num?>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  results.add(
                    await showAppModalSheet<num>(
                      context: context,
                      builder: (sheetContext) => PopScope<num>(
                        canPop: false,
                        child: SizedBox(
                          height: 180,
                          child: TextButton(
                            onPressed: () =>
                                completeEditorRoute(sheetContext, 1),
                            child: const Text('Complete one'),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open typed sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open typed sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Complete one'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(results, [1]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final method in _Dismiss.values) {
    testWidgets(
      '$method closes a clean editor once without writing or confirming',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var saves = 0;
          final results = <String?>[];
          await _mount(
            tester,
            onSave: () async => saves++,
            onClosed: results.add,
          );
          await _dismiss(tester, method);
          expect(_editor, findsNothing);
          expect(find.byType(AlertDialog), findsNothing);
          expect(results, ['discarded']);
          expect(saves, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      '$method confirms a dirty editor, preserves it on cancel and closes once',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          var saves = 0;
          final results = <String?>[];
          await _mount(
            tester,
            onSave: () async {
              saves++;
            },
            onClosed: results.add,
          );
          final state = tester.state<_EditorState>(_editor);
          final sheetBounds = tester.getRect(_sheet);
          await tester.enterText(find.byType(TextField), 'Uncommitted draft');
          await _dismiss(tester, method);
          final dialog = find.byType(AlertDialog);
          expect(dialog, findsOneWidget);
          expect(results, isEmpty);
          await tester.tap(
            find.descendant(of: dialog, matching: find.text('Cancel')),
          );
          await tester.pumpAndSettle();
          expect(tester.state(_editor), same(state));
          expect(state.input.text, 'Uncommitted draft');
          expect(tester.getRect(_sheet), sheetBounds);
          expect(saves, 0);

          await _dismiss(tester, method);
          final l = AppLocalizations.of(tester.element(_editor));
          await tester.tap(find.text(l.discardChangesAndExit));
          await tester.pumpAndSettle();
          expect(_editor, findsNothing);
          expect(find.text('Open from source').hitTestable(), findsOneWidget);
          expect(results, ['discarded']);
          expect(saves, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }

  testWidgets(
    'drag and handle activation cannot retire a pending save; failure retries once',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        var saves = 0;
        final results = <String?>[];
        await _mount(
          tester,
          onSave: () async {
            saves++;
            if (saves == 1) {
              await gate.future;
              throw StateError('Expected save failure');
            }
          },
          onClosed: results.add,
        );
        final state = tester.state<_EditorState>(_editor);
        await tester.enterText(find.byType(TextField), 'Retry draft');
        await tester.tap(find.text('Save'));
        await tester.pump();
        for (final method in _Dismiss.values) {
          await _dismiss(tester, method);
          expect(tester.state(_editor), same(state));
          expect(find.byType(AlertDialog), findsNothing);
          expect(results, isEmpty);
        }
        expect(saves, 1);
        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('Retry draft'), findsOneWidget);
        expect(find.text('Save failed; retry the draft'), findsOneWidget);
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(results, ['saved']);
        expect(saves, 2);
        expect(_editor, findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'completion removes only its guarded sheet beneath a newer task',
    (tester) async {
      final gate = Completer<void>();
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final results = <String?>[];
      await _mount(tester, onSave: () => gate.future, onClosed: results.add);
      final state = tester.state<_EditorState>(_editor);
      await tester.tap(find.text('Save'));
      await tester.pump();
      unawaited(
        Navigator.of(state.context).push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Newer task')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Newer task'), findsOneWidget);
      expect(find.byType(_Editor, skipOffstage: false), findsNothing);
      expect(results, ['saved']);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open from source').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

class _Editor extends StatefulWidget {
  const _Editor({required this.onSave});
  final Future<void> Function() onSave;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> with EditorExitGuard<_Editor> {
  final input = TextEditingController(text: 'Original');
  bool _saving = false;
  bool _closed = false;
  bool _failed = false;

  @override
  String get draftFingerprint => input.text;
  @override
  bool get exitBlocked => _saving || _closed;
  @override
  AppMode get editorWorkspace => AppMode.student;

  @override
  void initState() {
    super.initState();
    initializeDraftGuard();
  }

  @override
  void closeEditor() {
    if (_closed) return;
    setState(() => _closed = true);
    completeEditorRoute(context, 'discarded');
  }

  Future<void> _save() async {
    if (exitBlocked) return;
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (!mounted || _closed) return;
      setState(() => _closed = true);
      completeEditorRoute(context, 'saved');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: _closed,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(requestEditorExit());
    },
    child: AppSheetScaffold(
      title: const Text('Guarded editor'),
      onClose: () => unawaited(requestEditorExit()),
      closeEnabled: !exitBlocked,
      actions: [
        TextButton(
          onPressed: exitBlocked ? null : () => unawaited(requestEditorExit()),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: exitBlocked ? null : () => unawaited(_save()),
          child: const Text('Save'),
        ),
      ],
      child: SizedBox(
        height: 220,
        child: Column(
          children: [
            TextField(controller: input),
            if (_failed) const Text('Save failed; retry the draft'),
          ],
        ),
      ),
    ),
  );
}
