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
    'bodyAllDay': occurrence.isAllDay,
    'sourceLabel': descriptor.labelFor(data.localeCode),
    'channelId': descriptor.channelId,
    'channelName': descriptor.channelNameFor(data.localeCode),
    'channelDescription': descriptor.channelDescriptionFor(data.localeCode),
  });
  return sha1.convert(utf8.encode(value)).toString();
}
