import 'dart:convert';

import 'package:sked/data/timetable_storage.dart';
import 'package:sked/models/timetable_models.dart';

/// Serializes between reads and writes, including legacy key-migration input.
class MemoryTimetableStorage implements TimetableStorage {
  MemoryTimetableStorage({AppData? initialData})
    : _content = _encodeInitialMemoryData(initialData);

  String? _content;
  int saveCount = 0;

  String? get encodedData => _content;

  AppData? get data {
    final content = _content;
    if (content == null || content.trim().isEmpty) {
      return null;
    }
    return AppData.decode(content);
  }

  @override
  Future<StorageLoadResult> load() async {
    if (_content == null || _content!.trim().isEmpty) {
      return const StorageLoadResult.empty();
    }
    return StorageLoadResult(
      data: AppData.decode(_content!),
      recoveryStatus: RecoveryStatus.none,
    );
  }

  @override
  Future<void> save(AppData data) async {
    saveCount += 1;
    _content = data.encode();
  }

  @override
  Future<String?> filePath() async => 'memory://Sked-test';
}

String? _encodeInitialMemoryData(AppData? data) {
  if (data == null) {
    return null;
  }
  final encoded = data.encode();
  final apiKey = data.aiApiSettings.customApiKey;
  if (apiKey.trim().isEmpty) {
    return encoded;
  }
  final json = jsonDecode(encoded) as Map<String, dynamic>;
  final apiSettings = json['aiApiSettings'];
  if (apiSettings is Map<String, dynamic>) {
    apiSettings['customApiKey'] = apiKey.trim();
  }
  return jsonEncode(json);
}

/// Retains model identity for interaction tests and consumes one save failure.
class WorkspaceMemoryStorage implements TimetableStorage {
  WorkspaceMemoryStorage(
    this.data, {
    this.path = 'memory://adaptive-workspaces',
  });
  AppData data;
  final String path;
  Object? saveError;
  @override
  Future<StorageLoadResult> load() async =>
      StorageLoadResult(data: data, recoveryStatus: RecoveryStatus.none);
  @override
  Future<void> save(AppData value) async {
    if (saveError != null) {
      final error = saveError!;
      saveError = null;
      throw error;
    }
    data = value;
  }

  @override
  Future<String?> filePath() async => path;
}
