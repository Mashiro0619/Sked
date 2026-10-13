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
