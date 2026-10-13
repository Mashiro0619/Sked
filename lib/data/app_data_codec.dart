import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import '../models/app_data.dart';

/// CPU work for durable snapshots. Files, recovery decisions and write ordering
/// remain with the storage owner; only immutable values cross the isolate.
abstract final class AppDataCodec {
  static Future<Uint8List> encodeStorage(AppData data) =>
      compute(_encodeStorage, data, debugLabel: 'sked.storage.encode');

  static Future<AppData> decodeStorage(List<int> bytes) =>
      compute(_decodeStorage, bytes, debugLabel: 'sked.storage.decode');

  static Future<AppData> decodeStorageText(String source) => compute(
    AppData.decodeStorageSnapshot,
    source,
    debugLabel: 'sked.storage.decode',
  );

  static Future<String> sanitizeStorage(String source) =>
      compute(_sanitizeStorage, source, debugLabel: 'sked.storage.sanitize');

  static Uint8List _encodeStorage(AppData data) => utf8.encode(data.encode());

  static AppData _decodeStorage(List<int> bytes) =>
      AppData.decodeStorageSnapshot(utf8.decode(bytes, allowMalformed: false));

  static String _sanitizeStorage(String source) =>
      AppData.decodeStorageSnapshot(source).encode();
}
