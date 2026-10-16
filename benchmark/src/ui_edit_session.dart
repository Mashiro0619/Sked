import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/data/timetable_storage_io.dart';
import 'package:sked/models/timetable_models.dart';

import 'data_operations_runtime.dart';
import 'ui_performance_harness.dart';

abstract interface class UiEditSession {
  Widget get app;
  AppData get data;
  UiEditDiskStorage get storage;
  Future<void> load();
  Future<void> quiesce();
  Future<void> close();
}

typedef UiEditSessionFactory = UiEditSession Function(
  DataOperationsDependencies dependencies,
);

/// Reuses the existing UI host's storage interface while retaining all native
/// IoTimetableStorage recovery/secret-scrub interfaces through inheritance.
class UiEditDiskStorage extends IoTimetableStorage
    implements UiPerformanceMemoryStorage {
  UiEditDiskStorage(this.directory, this.data)
    : super(directoryProvider: () async => directory);

  final Directory directory;
  @override
  AppData data;
  @override
  int writes = 0;

  @override
  Future<StorageLoadResult> load() async {
    final result = await super.load();
    if (result.data case final value?) data = value;
    return result;
  }

  @override
  Future<void> save(AppData value) async {
    await super.save(value);
    data = value;
    writes += 1;
  }
}
