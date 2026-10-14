import 'dart:convert';

import 'package:crypto/crypto.dart';

const developerNotificationIdStart = 2000000001;

/// Converts a stable planner key into the positive Android integer ID range.
int notificationIdForKey(String key) {
  final digest = sha1.convert(utf8.encode(key)).bytes;
  var value = 0;
  for (final byte in digest.take(4)) {
    value = (value << 8) | byte;
  }
  value &= 0x7fffffff;
  // Keep the highest portion of Android's positive integer range reserved
  // for developer diagnostic notifications. A regular agenda key must never
  // collide with a test that deliberately uses a fixed, discoverable ID.
  return (value % (developerNotificationIdStart - 1)) + 1;
}

const developerNotificationIdEnd = 2147483647;

bool isDeveloperNotificationId(int id) =>
    id >= developerNotificationIdStart && id <= developerNotificationIdEnd;

int nextDeveloperNotificationId(int id) =>
    id >= developerNotificationIdEnd ? developerNotificationIdStart : id + 1;

const backgroundNotificationActionIds = <String>{'snooze_10m', 'handled'};

String developerNotificationPayload(String channelName, int id) =>
    'sked.developer.notification-test.v1:$channelName:$id';

String developerNotificationTag(int id) => 'sked_developer_test_$id';

const _windowsActionPrefix = 'sked.windows.action.v1:';

String encodeWindowsNotificationAction(String actionId, String payload) {
  if (!backgroundNotificationActionIds.contains(actionId)) {
    throw ArgumentError.value(actionId, 'actionId');
  }
  final encoded = base64Url.encode(utf8.encode(payload)).replaceAll('=', '');
  return '$_windowsActionPrefix$actionId:$encoded';
}

({String actionId, String payload})? decodeWindowsNotificationAction(
  String? value,
) {
  if (value == null || !value.startsWith(_windowsActionPrefix)) return null;
  final body = value.substring(_windowsActionPrefix.length);
  final separator = body.indexOf(':');
  if (separator <= 0 || separator == body.length - 1) return null;
  final actionId = body.substring(0, separator);
  if (!backgroundNotificationActionIds.contains(actionId)) return null;
  try {
    final encoded = body.substring(separator + 1);
    final padding = (4 - encoded.length % 4) % 4;
    final payload = utf8.decode(base64Url.decode('$encoded${'=' * padding}'));
    if (payload.isEmpty) return null;
    return (actionId: actionId, payload: payload);
  } on FormatException {
    return null;
  }
}

// Android's active-notification API exposes the tag after a scheduled request
// has fired and disappeared from flutter_local_notifications' pending cache.
// Keep the logical planner key in the tag so a fresh gateway instance can
// recover ownership and cancel a still-visible card after a data edit. Planner
// keys are bounded by the payload contract and contain no user-facing text.
const agendaNotificationTagPrefix = 'sked_agenda:';

String agendaNotificationTag(String key) => '$agendaNotificationTagPrefix$key';

bool isDeveloperNotificationPayload(String? payload) =>
    payload?.startsWith('sked.developer.notification-test.v1:') == true;
