import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/models/timetable_models.dart';

import '../support/reminder_summary_harness.dart';
import '../support/workspace_harness.dart';

final _now = DateTime(2026, 10, 1, 19);
Finder _key(String key) => find.byKey(ValueKey(key));
Finder get _list => _key('general-reminders-list');
Finder _title(int index) => find.descendant(
  of: _list,
  matching: find.text('Item ${index.toString().padLeft(3, '0')}'),
);

AppData _groupedData() =>
    buildInitialAppData(buildDefaultPeriodTimes(), localeCode: 'en').copyWith(
      activeMode: AppMode.general,
      generalMode: GeneralScheduleData(
        activeScheduleId: 'reminders',
        selectedDateIso: '2026-10-01',
        defaultView: generalViewList,
        schedules: [
          GeneralSchedule(
            id: 'reminders',
            name: 'Reminders',
            events: List.generate(
              300,
              (index) => GeneralEvent(
                id: 'event-$index',
                calendarId: 'reminders',
                title: 'Item ${index.toString().padLeft(3, '0')}',
                startDateTimeIso: _now
                    .add(Duration(minutes: (index ~/ 100) - 1))
                    .toIso8601String(),
                endDateTimeIso: _now
                    .add(Duration(minutes: index ~/ 100))
                    .toIso8601String(),
                reminders: const [GeneralEventReminder(minutesBefore: 1440)],
              ),
            ),
          ),
        ],
      ),
    );

Future<void> _mount(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.reset);
  final provider = await workspaceProvider(
    mode: AppMode.general,
    storage: WorkspaceMemoryStorage(_groupedData()),
  );
  addTearDown(provider.dispose);
  await tester.pumpWidget(
    reminderSummaryHarness(provider, ReminderSummaryClock()),
  );
  await tester.pumpAndSettle();
  await tester.tap(_key('general-reminders-action'));
  await tester.pumpAndSettle();
  expect(_list, findsOneWidget);
}

int? _focusedReminder() {
  int? result;
  FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
    if (element.widget.key case ValueKey<String>(value: final key)) {
      if (key.startsWith('general-reminder-v2|')) {
        result = int.parse(key.split('|')[2].split('-').last);
        return false;
      }
    }
    return true;
  });
  return result;
}

Future<void> _traverseReminders(
  WidgetTester tester,
  List<int> expected, {
  bool reverse = false,
}) async {
  final visited = <int>[];
  if (reverse) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  try {
    for (var step = 0; step < expected.length * 3; step++) {
      final reminder = _focusedReminder();
      expect(reminder, isNotNull, reason: 'Focus left reminders at step $step');
      if (visited.isEmpty || visited.last != reminder) {
        visited.add(reminder!);
        expect(visited, expected.take(visited.length).toList());
      }
      if (visited.length == expected.length) break;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
  } finally {
    if (reverse) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  expect(visited, expected);
}

void main() {
  testWidgets(
    'Tab and reverse Tab reach every reminder across lazy status groups',
    (tester) async {
      try {
        await _mount(tester);
        final order = [
          for (var index = 100; index < 300; index++) index,
          for (var index = 0; index < 100; index++) index,
        ];
        Focus.of(
          tester.element(_title(order.first)),
          createDependency: false,
        ).requestFocus();
        await tester.pumpAndSettle();
        await _traverseReminders(tester, order);
        Focus.of(
          tester.element(_title(order.last)),
          createDependency: false,
        ).requestFocus();
        await tester.pumpAndSettle();
        await _traverseReminders(
          tester,
          order.reversed.toList(),
          reverse: true,
        );
        expect(
          find
              .descendant(
                of: _list,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget.runtimeType.toString() == '_ReminderSummaryRow',
                ),
              )
              .evaluate()
              .length,
          lessThan(60),
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
