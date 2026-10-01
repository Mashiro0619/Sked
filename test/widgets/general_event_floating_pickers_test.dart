import 'package:flutter/gestures.dart';
import 'package:sked/providers/timetable_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/l10n/app_localizations.dart';
import 'package:sked/models/timetable_models.dart';
import 'package:sked/widgets/general_event_editor_sheet.dart';
import 'package:sked/widgets/sked_adaptive_picker_dialog.dart';
import 'package:sked/widgets/sked_date_picker.dart';
import 'package:sked/widgets/sked_floating_surface.dart';
import 'package:sked/widgets/sked_task_dialog.dart';

import '../support/workspace_harness.dart';

Finder k(String key) => find.byKey(ValueKey(key));
final desktop = TargetPlatformVariant.only(TargetPlatform.windows);
GeneralEvent event({
  List<int> reminders = const [17, 60],
  GeneralEventRecurrenceRule rule = const GeneralEventRecurrenceRule(),
}) => GeneralEvent(
  id: 'floating-event',
  calendarId: 'floating-calendar',
  title: 'Planning',
  startDateTimeIso: '2026-10-16T09:00:00.000',
  endDateTimeIso: '2026-10-16T10:00:00.000',
  recurrenceRule: rule,
  reminders: [
    for (final minutes in reminders)
      GeneralEventReminder(minutesBefore: minutes),
  ],
);

Future<TimetableProvider> mount(
  WidgetTester t, {
  double scale = 1,
  String locale = 'en',
  TextDirection direction = TextDirection.ltr,
  GeneralEvent? initial,
  Future<void> Function(GeneralEvent)? onSave,
  ValueNotifier<bool>? showEditor,
}) async {
  t.view.devicePixelRatio = 1;
  t.view.physicalSize = const Size(1366, 1000);
  addTearDown(t.view.reset);
  final p = await workspaceProvider(mode: AppMode.general, locale: locale);
  addTearDown(p.dispose);
  final editor = GeneralEventEditorSheet(
    initialEvent: initial ?? event(),
    calendars: const [
      GeneralSchedule(id: 'floating-calendar', name: 'Work', events: []),
    ],
    activeCalendarId: 'floating-calendar',
    onSave: onSave,
  );
  await t.pumpWidget(
    WorkspaceHarness(
      provider: p,
      locale: Locale(locale),
      textScale: scale,
      textDirection: direction,
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 400,
            child: showEditor == null
                ? editor
                : ValueListenableBuilder<bool>(
                    valueListenable: showEditor,
                    builder: (_, show, _) =>
                        show ? editor : const Text('Editor removed'),
                  ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return p;
}

Future<void> open(WidgetTester t, String which) async {
  await t.ensureVisible(k('event-$which-field'));
  await t.pumpAndSettle();
  await t.tap(k('event-$which-field'));
  await t.pumpAndSettle();
}

Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Finder surface(String which) => find
    .ancestor(
      of: k('general-$which-panel'),
      matching: find.byType(SkedFloatingSurface),
    )
    .first;
Future<void> save(WidgetTester t) async {
  final l = AppLocalizations.of(
    t.element(find.byType(GeneralEventEditorSheet)),
  );
  await tap(t, find.widgetWithText(FilledButton, l.save));
}

void main() {
  testWidgets(
    'multi-step mouse title drag never reverses and body choices do not move the panel',
    (t) async {
      await mount(t);
      for (final which in ['recurrence', 'reminder']) {
        await open(t, which);
        final before = t.getRect(surface(which));
        final mouse = await t.startGesture(
          t.getCenter(k('sked-picker-drag-handle')),
          kind: PointerDeviceKind.mouse,
        );
        for (var step = 0; step < 8; step++) {
          await mouse.moveBy(const Offset(-6.25, -3.125));
          await t.pump();
        }
        await mouse.up();
        await t.pumpAndSettle();
        final moved = t.getRect(surface(which));
        expect(moved.left, closeTo(before.left - 50, 1));
        expect(moved.top, closeTo(before.top - 25, 1));
        await tap(
          t,
          k(
            which == 'recurrence'
                ? 'general-recurrence-choice-weekly'
                : 'general-reminder-choice-5',
          ),
        );
        expect(t.getRect(surface(which)).topLeft, moved.topLeft);
        await tap(t, k('general-$which-cancel'));
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final replaceData in [true, false]) {
    for (final which in ['recurrence', 'reminder']) {
      testWidgets(
        '$which blocks ${replaceData ? 'data replacement' : 'workspace disable'} through the editor guard',
        (t) async {
          final saved = <GeneralEvent>[];
          final p = await mount(t, onSave: (value) async => saved.add(value));
          final backup = await p.exportAppDataJson();
          await open(t, which);
          await tap(
            t,
            k(
              which == 'recurrence'
                  ? 'general-recurrence-choice-weekly'
                  : 'general-reminder-none',
            ),
          );
          if (replaceData) {
            await expectLater(
              p.importAppDataJson(backup, mode: AppImportMode.replaceAll),
              throwsA(isA<WorkspaceChangeCancelledException>()),
            );
          } else {
            await p.setWorkspaceEnabled(AppMode.general, false);
          }
          await t.pumpAndSettle();
          expect(k('general-$which-panel'), findsOneWidget);
          expect(p.isWorkspaceEnabled(AppMode.general), isTrue);
          expect(saved, isEmpty);
          await tap(t, k('general-$which-cancel'));
          await save(t);
          expect(saved.single.recurrenceRule.type, GeneralEventRecurrence.none);
          expect(saved.single.reminders.map((r) => r.minutesBefore), [17, 60]);
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
        variant: desktop,
      );
    }
  }

  testWidgets(
    'failed event save retains confirmed recurrence and reminder drafts for retry',
    (t) async {
      final attempts = <GeneralEvent>[];
      await mount(
        t,
        onSave: (value) async {
          attempts.add(value);
          if (attempts.length == 1) throw StateError('Retryable event save');
        },
      );
      await open(t, 'recurrence');
      await tap(t, k('general-recurrence-choice-custom'));
      await t.enterText(k('recurrence-interval-value'), '999');
      await tap(t, k('general-recurrence-confirm'));
      expect(
        find.descendant(
          of: k('event-recurrence-field'),
          matching: find.textContaining('999'),
        ),
        findsOneWidget,
      );
      await open(t, 'reminder');
      await tap(t, k('general-reminder-choice-5'));
      await tap(t, k('general-reminder-confirm'));
      expect(attempts, isEmpty);
      await save(t);
      expect(attempts, hasLength(1));
      expect(find.byType(GeneralEventEditorSheet), findsOneWidget);
      expect(find.text('Save failed. Please try again later.'), findsOneWidget);
      await open(t, 'recurrence');
      expect(
        t.widget<TextField>(k('recurrence-interval-value')).controller!.text,
        '999',
      );
      await tap(t, k('general-recurrence-cancel'));
      await save(t);
      expect(attempts, hasLength(2));
      for (final value in attempts) {
        expect(value.recurrenceRule.interval, 999);
        expect(value.reminders.map((r) => r.minutesBefore), [5, 17, 60]);
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  for (final locale in ['en', 'zh']) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'general pickers attach left, drag and reopen: $locale $scale',
        (t) async {
          await mount(t, scale: scale, locale: locale);
          for (final which in ['recurrence', 'reminder']) {
            await open(t, which);
            final field = t.getRect(k('event-$which-field'));
            final rect = t.getRect(surface(which));
            expect(rect.right, closeTo(field.left - 6, 1));
            expect(rect.width, which == 'recurrence' ? 360 : 320);
            expect(rect.top, greaterThanOrEqualTo(8));
            expect(rect.bottom, lessThanOrEqualTo(992));
            expect(
              ModalRoute.of(t.element(k('general-$which-panel')))!.barrierColor,
              Colors.transparent,
            );
            expect(find.byType(AlertDialog), findsNothing);
            final drag = k('sked-picker-drag-handle');
            await t.drag(drag, const Offset(-50, -30));
            await t.pumpAndSettle();
            final moved = t.getRect(surface(which));
            expect(moved.left, closeTo(rect.left - 50, 1));
            await t.sendKeyEvent(LogicalKeyboardKey.escape);
            await t.pumpAndSettle();
            expect(k('general-$which-panel'), findsNothing);
            await open(t, which);
            expect(t.getRect(surface(which)), rect);
            await tap(t, k('floating-form-close'));
          }
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
        variant: desktop,
      );
    }
  }

  for (final direction in TextDirection.values) {
    testWidgets(
      'both panels stay usable after resize and keyboard in $direction',
      (t) async {
        await mount(t, direction: direction, scale: 2);
        for (final which in ['recurrence', 'reminder']) {
          await open(t, which);
          t.view.physicalSize = const Size(560, 640);
          t.view.viewInsets = const FakeViewPadding(bottom: 150);
          await t.pumpAndSettle();
          final rect = t.getRect(surface(which));
          expect(rect.left, greaterThanOrEqualTo(8));
          expect(rect.right, lessThanOrEqualTo(552));
          expect(rect.bottom, lessThanOrEqualTo(482));
          expect(k('floating-form-close').hitTestable(), findsOneWidget);
          expect(k('general-$which-confirm').hitTestable(), findsOneWidget);
          await tap(t, k('floating-form-close'));
          t.view.resetViewInsets();
          t.view.physicalSize = const Size(1366, 1000);
          await t.pumpAndSettle();
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
      variant: desktop,
    );
  }

  testWidgets(
    'field focus returns after close, but never steals a newer picker',
    (t) async {
      await mount(t);
      await t.ensureVisible(k('event-recurrence-field'));
      await t.pumpAndSettle();
      final focus = skedFloatingAnchorFocus(
        t.element(k('event-recurrence-field')),
      );
      expect(focus, isNotNull);
      await open(t, 'recurrence');
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
      expect(
        FocusScope.of(t.element(k('general-recurrence-panel'))).hasFocus,
        isTrue,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(focus!.hasFocus, isTrue);
      await open(t, 'reminder');
      expect(
        FocusScope.of(t.element(k('general-reminder-panel'))).hasFocus,
        isTrue,
      );
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pumpAndSettle();
      expect(k('general-reminder-panel'), findsNothing);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'recurrence validates and preserves custom values while choosing presets',
    (t) async {
      final saved = <GeneralEvent>[];
      await mount(t, onSave: (value) async => saved.add(value));
      await open(t, 'recurrence');
      await tap(t, k('general-recurrence-choice-custom'));
      final interval = k('recurrence-interval-value');
      for (final bad in ['0', '']) {
        await t.enterText(interval, bad);
        await tap(t, k('general-recurrence-confirm'));
        expect(k('general-recurrence-panel'), findsOneWidget);
        expect(saved, isEmpty);
      }
      await t.enterText(interval, '1000');
      expect(
        t.widget<TextField>(interval).controller!.text.length,
        lessThanOrEqualTo(3),
      );
      await t.enterText(interval, '999');
      await t.pump();
      expect(
        t.widget<IconButton>(k('recurrence-interval-increment')).onPressed,
        isNull,
      );
      await t.enterText(interval, '1');
      await t.pump();
      expect(
        t.widget<IconButton>(k('recurrence-interval-decrement')).onPressed,
        isNull,
      );
      await t.enterText(interval, '3');
      final l = AppLocalizations.of(t.element(k('general-recurrence-panel')));
      final count = find.widgetWithText(TextFormField, l.recurrenceRepeatCount);
      await t.enterText(count, '0');
      await tap(t, k('general-recurrence-confirm'));
      expect(k('general-recurrence-panel'), findsOneWidget);
      await t.enterText(count, '4');
      for (final mode in ['none', 'daily', 'weekly', 'monthly', 'custom']) {
        await tap(t, k('general-recurrence-choice-$mode'));
      }
      expect(t.widget<TextField>(interval).controller!.text, '3');
      expect(t.widget<TextFormField>(count).controller!.text, '4');
      await tap(t, k('general-recurrence-confirm'));
      expect(saved, isEmpty);
      await save(t);
      expect(saved, hasLength(1));
      expect(saved.single.recurrenceRule.type, GeneralEventRecurrence.custom);
      expect(saved.single.recurrenceRule.interval, 3);
      expect(saved.single.recurrenceRule.count, 4);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'nested end date keeps recurrence position and blocks parent closing',
    (t) async {
      await mount(t);
      await open(t, 'recurrence');
      await tap(t, k('general-recurrence-choice-custom'));
      await t.drag(k('sked-picker-drag-handle'), const Offset(-90, -20));
      await t.pumpAndSettle();
      final before = t.getRect(surface('recurrence'));
      final cancelBeforeChild = t
          .widget<TextButton>(k('general-recurrence-cancel'))
          .onPressed!;
      final l = AppLocalizations.of(t.element(k('general-recurrence-panel')));
      await tap(t, find.text(l.recurrenceEndDate));
      expect(find.byType(SkedDatePicker), findsOneWidget);
      cancelBeforeChild();
      await t.pumpAndSettle();
      expect(find.byType(SkedDatePicker), findsOneWidget);
      final parent = find.byKey(
        const ValueKey('general-recurrence-panel'),
        skipOffstage: false,
      );
      final parentContext = t.element(parent);
      final pop = find.ancestor(of: parent, matching: find.byType(PopScope));
      expect(t.widget<PopScope>(pop.first).canPop, isFalse);
      await Navigator.of(parentContext).maybePop();
      await t.pumpAndSettle();
      expect(
        k('general-recurrence-panel'),
        findsOneWidget,
      ); // closes the top date only
      expect(t.getRect(surface('recurrence')), before);
      await tap(t, find.text(l.recurrenceEndDate));
      await tap(t, k('sked-date-confirm'));
      expect(k('general-recurrence-panel'), findsOneWidget);
      expect(t.getRect(surface('recurrence')).topLeft, before.topLeft);
      expect(find.byTooltip(l.clearEndDate), findsOneWidget);
      await tap(t, find.byTooltip(l.clearEndDate));
      expect(find.text(l.recurrenceEndDate), findsOneWidget);
      await tap(t, k('general-recurrence-cancel'));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'reminder presets preserve imported values, cancel is local and confirm saves only draft',
    (t) async {
      final saved = <GeneralEvent>[];
      await mount(t, onSave: (value) async => saved.add(value));
      await open(t, 'reminder');
      expect(k('general-reminder-choice-17'), findsOneWidget);
      await tap(t, k('general-reminder-none'));
      await tap(t, k('general-reminder-cancel'));
      await open(t, 'reminder');
      final selected17 = find
          .descendant(
            of: k('general-reminder-choice-17'),
            matching: find.byType(Semantics),
          )
          .first;
      expect(t.widget<Semantics>(selected17).properties.selected, isTrue);
      await tap(t, k('general-reminder-choice-5'));
      await tap(t, k('general-reminder-confirm'));
      expect(saved, isEmpty);
      await save(t);
      expect(saved, hasLength(1));
      expect(saved.single.reminders.map((r) => r.minutesBefore).toList(), [
        5,
        17,
        60,
      ]);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'none explicitly clears reminders and outside cancellation keeps recurrence',
    (t) async {
      final saved = <GeneralEvent>[];
      await mount(t, onSave: (value) async => saved.add(value));
      await open(t, 'recurrence');
      await tap(t, k('general-recurrence-choice-weekly'));
      await t.tapAt(const Offset(50, 500));
      await t.pumpAndSettle();
      await open(t, 'recurrence');
      expect(k('recurrence-interval-value'), findsNothing);
      await tap(t, k('general-recurrence-cancel'));
      await open(t, 'reminder');
      await tap(t, k('general-reminder-none'));
      await tap(t, k('general-reminder-confirm'));
      expect(saved, isEmpty);
      await save(t);
      expect(saved.single.reminders, isEmpty);
      expect(saved.single.recurrenceRule.type, GeneralEventRecurrence.none);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'parent removal retires an open selection without applying stale results',
    (t) async {
      final show = ValueNotifier(true);
      addTearDown(show.dispose);
      await mount(t, showEditor: show);
      await open(t, 'reminder');
      final confirm = t
          .widget<FilledButton>(k('general-reminder-confirm'))
          .onPressed!;
      show.value = false;
      await t.pump();
      confirm();
      await t.pumpAndSettle();
      expect(find.byType(GeneralEventEditorSheet), findsNothing);
      expect(k('general-reminder-panel'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
    variant: desktop,
  );

  testWidgets(
    'session invalidation during the closing animation discards the result',
    (t) async {
      var current = true;
      var finished = false;
      int? result;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showSkedAdaptivePickerDialog<int>(
                    context: context,
                    routeName: 'session-test',
                    waitForTransitionComplete: true,
                    isSessionCurrent: () => current,
                    builder: (context) => SkedTaskDialog(
                      title: const Text('Choice'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(7),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                  finished = true;
                },
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Confirm'));
      await t.pump();
      current = false;
      await t.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, isNull);
    },
    variant: desktop,
  );

  testWidgets(
    'waitForTransitionComplete keeps caller blocked until route subtree retires',
    (t) async {
      var finished = false;
      int? result;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  result = await showSkedAdaptivePickerDialog<int>(
                    context: context,
                    routeName: 'wait-test',
                    waitForTransitionComplete: true,
                    builder: (context) => SkedTaskDialog(
                      title: const Text('Waiting'),
                      content: const Text('Body'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(7),
                          child: const Text('Finish'),
                        ),
                      ],
                    ),
                  );
                  finished = true;
                },
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      await t.tap(find.text('Finish'));
      await t.pump();
      expect(finished, isFalse);
      expect(find.text('Waiting'), findsOneWidget);
      await t.pumpAndSettle();
      expect(finished, isTrue);
      expect(result, 7);
      expect(find.text('Waiting'), findsNothing);
    },
    variant: desktop,
  );
}
