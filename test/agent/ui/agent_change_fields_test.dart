import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sked/agent/ui/agent_change_fields.dart';
import 'package:sked/agent/ui/agent_plan_preview.dart';
import 'package:sked/agent/ui/agent_selectable_text.dart';
import 'package:sked/l10n/app_localizations.dart';

import 'agent_ui_test_support.dart';

void main() {
  testWidgets('imported timetable exposes native fields and nested courses', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const timetable = {
      'id': 'timetable-1',
      'config': {
        'name': 'Spring semester',
        'startDate': '2026-03-02',
        'totalWeeks': 18,
      },
      'courses': [
        {
          'id': 'course-1',
          'name': 'Mathematics',
          'dayOfWeek': 2,
          'semesterWeeks': [1, 2, 3],
          'periods': [1, 2],
          'startMinutes': 480,
          'endMinutes': 580,
          'teacher': 'Teacher Chen',
          'location': 'Room 201',
        },
      ],
    };
    const details = <String, Object?>{
      'planId': 'import-plan',
      'changes': [
        {'before': null, 'after': timetable},
      ],
    };
    final original = jsonEncode(details);
    await mountAgentUi(
      tester,
      const SingleChildScrollView(child: AgentPlanPreview(details: details)),
      size: const Size(390, 844),
      locale: const Locale('zh'),
    );
    await tester.tap(find.text('Spring semester'));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentPlanPreview)),
    );
    expect(find.text(l.semesterStartDate), findsOneWidget);
    expect(find.text(l.totalWeeks), findsOneWidget);
    expect(find.text(l.schoolWebImportCourseCount(1)), findsOneWidget);
    final nested = find.widgetWithText(ExpansionTile, 'Mathematics').last;
    await tester.ensureVisible(nested);
    await tester.tap(find.text('Mathematics'));
    await tester.pumpAndSettle();
    expect(find.text('Teacher Chen'), findsOneWidget);
    expect(find.text('Room 201'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('09:40'), findsOneWidget);
    expect(find.textContaining('星期二'), findsOneWidget);
    expect(jsonEncode(details), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edits show changed fields and retain complete original JSON', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    const change = {
      'before': {
        'name': 'Mathematics',
        'teacher': 'Old teacher',
        'location': 'Room 201',
        'customFields': {'original': 'retained'},
      },
      'after': {
        'name': 'Mathematics',
        'teacher': 'New teacher',
        'location': '',
        'customFields': {'new': 'also retained'},
      },
    };
    await mountAgentUi(
      tester,
      const SingleChildScrollView(child: AgentChangeFields(change: change)),
      size: const Size(320, 844),
      scale: 2,
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentChangeFields)),
    );
    expect(find.text(l.name), findsNothing);
    expect(find.text('${l.agentValueBefore}: Old teacher'), findsOneWidget);
    expect(find.text('${l.agentValueAfter}: New teacher'), findsOneWidget);
    expect(find.text('${l.agentValueAfter}: —'), findsOneWidget);
    await tester.ensureVisible(find.text(l.agentPlanDetails));
    await tester.tap(find.text(l.agentPlanDetails));
    await tester.pumpAndSettle();
    final expected = const JsonEncoder.withIndent('  ').convert({
      l.agentValueBefore: change['before'],
      l.agentValueAfter: change['after'],
    });
    expect(find.widgetWithText(AgentSelectableText, expected), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested removals and additions remain individually inspectable', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final change = {
      'before': {
        'name': 'Day periods',
        'periodTimes': [
          {'index': 25, 'startMinutes': 900, 'endMinutes': 950},
        ],
      },
      'after': {
        'name': 'Day periods',
        'periodTimes': [
          for (var i = 1; i <= 21; i++)
            {'index': i, 'startMinutes': i * 50, 'endMinutes': i * 50 + 40},
        ],
      },
    };
    await mountAgentUi(
      tester,
      SingleChildScrollView(child: AgentChangeFields(change: change)),
    );
    final l = AppLocalizations.of(
      tester.element(find.byType(AgentChangeFields)),
    );
    expect(find.text(l.periodNumberLabel(21)), findsNothing);
    await tester.ensureVisible(find.text(l.agentShowMoreChanges));
    await tester.tap(find.text(l.agentShowMoreChanges));
    await tester.pumpAndSettle();
    expect(find.text(l.periodNumberLabel(21)), findsOneWidget);
    expect(find.text(l.periodNumberLabel(25)), findsOneWidget);
    final removed = find.widgetWithText(ExpansionTile, l.periodNumberLabel(25));
    expect(
      find.descendant(of: removed, matching: find.text(l.delete)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('event timestamps keep zone information and recurrence limits', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    late Map<String, String> fields;
    late AppLocalizations l;
    await mountAgentUi(
      tester,
      Builder(
        builder: (context) {
          l = AppLocalizations.of(context);
          fields = agentReadableFields(context, {
            'title': 'Meeting',
            'start': '2026-11-05T09:30:00+08:00',
            'end': '2026-11-05T02:30:00Z',
            'isAllDay': false,
            'recurrenceRule': {
              'type': 'custom',
              'interval': 2,
              'unit': 'week',
              'untilDate': '2027-01-01',
              'count': 5,
            },
          });
          return const SizedBox();
        },
      ),
    );
    expect(fields[l.startTime], contains('01:30 UTC'));
    expect(fields[l.endTime], contains('02:30 UTC'));
    expect(fields[l.allDay], l.none);
    expect(fields[l.eventRecurrence], l.repeatsEvery(2, l.recurrenceWeeks));
    expect(fields[l.recurrenceRepeatCount], '5');
    expect(fields[l.recurrenceEndDate], contains('2027'));
  });
}
