import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_models.dart'
    show formatDayOfWeekLabel, formatSemesterWeeksValue;
import '../../utils/time_utils.dart';
import 'agent_selectable_text.dart';

/// Formats known business fields without changing their stored values. Unknown
/// fields remain available in the complete plan detail owned by the caller.
Map<String, String> agentReadableFields(BuildContext context, Map value) {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final material = MaterialLocalizations.of(context);
  final data = <Object?, Object?>{...value};
  if (value['config'] case final Map config) data.addAll(config);
  final fields = <String, String>{};
  void add(String label, Object? value) {
    if (value == null || value == '' || value is List && value.isEmpty) return;
    fields[label] = value is List ? value.join(', ') : '$value';
  }

  String date(Object? value, {bool time = false}) {
    if (value is! String) return '$value';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final day = material.formatFullDate(parsed);
    if (!time) return day;
    // Identify absolute timestamps explicitly; no implicit device-zone shift
    // or fallback date changes the proposed operation in this preview.
    return '$day ${material.formatTimeOfDay(TimeOfDay.fromDateTime(parsed), alwaysUse24HourFormat: true)}${parsed.isUtc ? ' UTC' : ''}';
  }

  add(l.name, data['name'] ?? data['title']);
  add(l.timetableName, data['timetableName']);
  add(l.calendar, data['calendarName']);
  if (data['startDate'] != null) {
    add(l.semesterStartDate, date(data['startDate']));
  }
  add(l.totalWeeks, data['totalWeeks']);
  if (data['courses'] case final List courses) {
    add(l.agentActivityCourses, l.schoolWebImportCourseCount(courses.length));
  }
  if (data['periodTimes'] case final List periods) {
    add(l.periodTimesTitle, l.schoolWebImportPeriodCount(periods.length));
  }
  final weekday = data['dayOfWeek'];
  if (weekday is int && weekday >= 1 && weekday <= 7) {
    add(l.dayOfWeek, formatDayOfWeekLabel(weekday, localeCode: locale));
  }
  final weeks = data['semesterWeeks'];
  if (weeks is List && weeks.every((v) => v is int)) {
    add(
      l.semesterWeeks,
      formatSemesterWeeksValue(weeks.cast<int>(), localeCode: locale),
    );
  }
  final periods = data['periods'];
  if (periods is List && periods.every((p) => p is int)) {
    add(
      l.periodTimesTitle,
      periods.cast<int>().map(l.periodNumberLabel).join(', '),
    );
  }
  if (data['index'] case final int index) {
    add(l.periodTimesTitle, l.periodNumberLabel(index));
  }
  final effective = data['effectiveTime'];
  final startMinutes = effective is Map
      ? effective['startMinutes']
      : data['startMinutes'];
  final endMinutes = effective is Map
      ? effective['endMinutes']
      : data['endMinutes'];
  if (data['start'] != null) {
    add(l.startTime, date(data['start'], time: true));
  } else if (startMinutes is int &&
      endMinutes is int &&
      endMinutes > startMinutes) {
    add(l.startTime, formatMinutes(startMinutes));
  }
  if (data['end'] != null) {
    add(l.endTime, date(data['end'], time: true));
  } else if (startMinutes is int &&
      endMinutes is int &&
      endMinutes > startMinutes) {
    add(l.endTime, formatMinutes(endMinutes));
  }
  if (data['isAllDay'] case final bool allDay) {
    add(l.allDay, allDay ? l.allDay : l.none);
  }
  if (data['recurrenceRule'] case final Map rule) {
    final unit = switch (rule['unit']) {
      'day' => l.recurrenceDays,
      'week' => l.recurrenceWeeks,
      'month' => l.recurrenceMonths,
      _ => null,
    };
    final interval = rule['interval'];
    final summary = switch (rule['type']) {
      'none' => l.recurrenceNone,
      'daily' => l.repeatsDaily,
      'weekly' => l.repeatsWeekly,
      'monthly' => l.repeatsMonthly,
      'custom' when unit != null && interval is int && interval > 0 =>
        l.repeatsEvery(interval, unit),
      _ => null,
    };
    if (summary != null) {
      add(l.eventRecurrence, summary);
      if (rule['type'] != 'none') {
        if (rule['untilDate'] != null) {
          add(l.recurrenceEndDate, date(rule['untilDate']));
        }
        if (rule['count'] case final int count when count > 0) {
          add(l.recurrenceRepeatCount, count);
        }
      }
    }
  }
  add(l.teacherName, data['teacher']);
  add(l.location, data['location']);
  add(l.credits, data['credit']);
  add(l.remarks, data['remarks'] ?? data['notes']);
  return fields;
}

/// The human-readable difference is primary; full native JSON stays inspectable.
class AgentChangeFields extends StatefulWidget {
  const AgentChangeFields({super.key, required this.change, this.depth = 0});
  final Map change;
  final int depth;

  @override
  State<AgentChangeFields> createState() => _AgentChangeFieldsState();
}

class _AgentChangeFieldsState extends State<AgentChangeFields> {
  var _shown = 20;

  @override
  void didUpdateWidget(AgentChangeFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.change, widget.change)) _shown = 20;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final before = widget.change['before'];
    final after = widget.change['after'];
    final previous = before is Map
        ? agentReadableFields(context, before)
        : <String, String>{};
    final next = after is Map
        ? agentReadableFields(context, after)
        : <String, String>{};
    final labels = {
      ...previous.keys,
      ...next.keys,
    }.where((key) => previous[key] != next[key]).toList();
    // The containing object row already names new/deleted objects. A rename
    // still needs both names; a name-only object retains a readable value.
    if (labels.length > 1 && (before == null || after == null)) {
      labels.remove(l.name);
    }
    final raw = Align(
      alignment: AlignmentDirectional.centerStart,
      child: AgentSelectableText(
        const JsonEncoder.withIndent('  ')
            .convert({l.agentValueBefore: before, l.agentValueAfter: after}),
      ),
    );
    final nested = <Map<String, Object?>>[];
    if (widget.depth == 0) {
      for (final field in ['courses', 'periodTimes']) {
        final oldItems = before is Map && before[field] is List
            ? (before[field] as List).whereType<Map>().toList()
            : <Map>[];
        final newItems = after is Map && after[field] is List
            ? (after[field] as List).whereType<Map>().toList()
            : <Map>[];
        Object identity(Map value) => value['id'] ?? value['index'] ?? value;
        final previousById = {
          for (final item in oldItems) identity(item): item,
        };
        for (final item in newItems) {
          final original = previousById.remove(identity(item));
          if (jsonEncode(original) != jsonEncode(item)) {
            nested.add({'before': original, 'after': item});
          }
        }
        for (final item in previousById.values) {
          nested.add({'before': item, 'after': null});
        }
      }
    }
    if (labels.isEmpty && nested.isEmpty) return raw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                if (previous[label] case final String value)
                  AgentSelectableText(
                    after == null ? value : '${l.agentValueBefore}: $value',
                  ),
                if (before != null &&
                    after != null &&
                    !previous.containsKey(label))
                  AgentSelectableText('${l.agentValueBefore}: —'),
                if (next[label] case final String value)
                  AgentSelectableText(
                    before == null ? value : '${l.agentValueAfter}: $value',
                  ),
                if (before != null && after != null && !next.containsKey(label))
                  AgentSelectableText('${l.agentValueAfter}: —'),
              ],
            ),
          ),
        for (final item in nested.take(_shown))
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(_nestedTitle(item, l)),
            subtitle: Text(
              item['before'] == null
                  ? l.agentKnowledgeAdd
                  : item['after'] == null
                  ? l.delete
                  : l.agentKnowledgeEdit,
            ),
            children: [
              AgentChangeFields(change: item, depth: widget.depth + 1),
            ],
          ),
        if (nested.length > _shown)
          TextButton(
            onPressed: () => setState(() => _shown += 20),
            child: Text(l.agentShowMoreChanges),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.agentPlanDetails),
          children: [raw],
        ),
      ],
    );
  }

  String _nestedTitle(Map item, AppLocalizations l) {
    final value = (item['after'] ?? item['before']) as Map;
    return value['name'] is String
        ? value['name'] as String
        : value['index'] is int
        ? l.periodNumberLabel(value['index'] as int)
        : l.agentPlanDetails;
  }
}
