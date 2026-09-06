import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/timetable_models.dart';
import 'agenda_projection_service.dart';

/// Computes the canonical identity of the user-visible notification copy.
///
/// The scheduler and action router share this function. A payload can only be
/// accepted when it still describes the current occurrence and source
/// metadata, rather than merely having valid JSON.
String agendaNotificationFingerprint({
  required AgendaOccurrence occurrence,
  required AppData data,
  required AgendaSourceDescriptor descriptor,
}) {
  final value = jsonEncode({
    'localeCode': data.localeCode,
    'title': occurrence.title,
    'location': occurrence.location,
    'target': occurrence.target.toJson(),
    'lockScreenShowTitles': data.notificationSettings.lockScreenShowTitles,
    'bodyStart': occurrence.start.toIso8601String(),
    'bodyEnd': occurrence.end.toIso8601String(),
    'bodyAllDay': occurrence.isAllDay,
    'reminders':
        occurrence.reminders
            .map((reminder) => reminder.normalized().minutesBefore)
            .toList()
          ..sort(),
    'sourceLabel': descriptor.labelFor(data.localeCode),
    'channelId': descriptor.channelId,
    'channelName': descriptor.channelNameFor(data.localeCode),
    'channelDescription': descriptor.channelDescriptionFor(data.localeCode),
  });
  return sha1.convert(utf8.encode(value)).toString();
}

/// Stable runtime identity for one concrete occurrence revision.
///
/// The platform notification key intentionally stays stable when an item is
/// edited so an existing alarm can be replaced. Runtime actions have a
/// different lifecycle: handling or snoozing the 07:15 revision must not
/// suppress a later edit of the same course to 07:20.
String agendaOccurrenceRevision(AgendaOccurrence occurrence) {
  final value = jsonEncode({
    'sourceType': occurrence.sourceType,
    'stableId': occurrence.stableId,
    'start': occurrence.start.toIso8601String(),
    'end': occurrence.end.toIso8601String(),
    'isAllDay': occurrence.isAllDay,
    'target': occurrence.target.toJson(),
    'reminders':
        occurrence.reminders
            .map((reminder) => reminder.normalized().minutesBefore)
            .toList()
          ..sort(),
  });
  return sha1.convert(utf8.encode(value)).toString();
}

String agendaRuntimeOccurrenceId({
  required String occurrenceId,
  required String revision,
}) => '$occurrenceId|$revision';

/// Returns whether [value] is the revision-scoped runtime identity emitted by
/// [agendaRuntimeOccurrenceId]. Bare occurrence IDs and planner keys are
/// legacy runtime state that must be migrated against a live projection.
bool isAgendaRuntimeOccurrenceId(String value) {
  final separator = value.lastIndexOf('|');
  if (separator <= 0 || separator == value.length - 1) return false;
  final occurrenceId = value.substring(0, separator);
  final revision = value.substring(separator + 1);
  return occurrenceId.contains('|') &&
      RegExp(r'^[0-9a-f]{40}$').hasMatch(revision);
}
