import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sked/data/app_repository.dart';
import 'package:sked/data/timetable_storage.dart';
import 'package:sked/main.dart' show AppStartupDependencies;
import 'package:sked/models/timetable_models.dart';
import 'package:sked/services/app_backup_restore_journal.dart';
import 'package:sked/services/app_instance_lease.dart';
import 'package:sked/services/school_site_service.dart';
import 'package:sked/services/secret_store.dart';

import 'startup_clock.dart' show startupClockProtocolId;
import 'startup_memory.dart' show startupMemoryProtocolId;

export 'startup_clock.dart'
    show startupClockProtocolId, startupClockToleranceUs;
export 'startup_memory.dart' show startupMemoryProtocolId;

const startupProtocolVersion = 1;
const startupReadableProtocolId = 'startup-readable-v1';
const startupDatasets = ['sparse', '1000', '5000'];
const startupPrivacyVersion = '2026-08-07';
const startupSelectedDate = '2026-08-17';
const startupInputDate = '2026-08-18';
const startupSyntheticSecret = 'sked-startup-synthetic-secret-only';

/// Baseline/current adapters only map existing composition and read-only state.
abstract interface class StartupRuntime {
  AppData get data;
  bool get loaded;
  bool get loading;
  bool get writable;
  bool get privacyAccepted;
  Listenable get changes;
  AppRepository get repository;
}

class StartupDependencies {
  const StartupDependencies({
    required this.storage,
    required this.lease,
    required this.services,
    required this.secrets,
    required this.sites,
    required this.journal,
  });
  final TimetableStorage storage;
  final AppInstanceLease lease;
  final AppStartupDependencies services;
  final SecretStore secrets;
  final SchoolSiteService sites;
  final AppBackupRestoreJournal journal;
}

Object? canonicalJson(Object? value) => switch (value) {
  Map() => {
    for (final key in value.keys.cast<String>().toList()..sort())
      key: canonicalJson(value[key]),
  },
  List() => value.map(canonicalJson).toList(),
  _ => value,
};

String semanticHash(AppData data) => sha256
    .convert(utf8.encode(jsonEncode(canonicalJson(data.toJson()))))
    .toString();

Map<String, Object> semanticSummary(AppData data) => {
  'activeMode': data.activeMode.value,
  'locale': data.localeCode,
  'selectedDate': data.generalMode.selectedDateIso ?? '',
  'events': data.generalMode.schedules.fold<int>(
    0,
    (count, item) => count + item.events.length,
  ),
  'courses': data.studentMode.timetables.fold<int>(
    0,
    (count, item) => count + item.courses.length,
  ),
  'privacyVersion': data.privacyPolicyAcceptedVersion ?? '',
  'notificationsEnabled': data.notificationSettings.enabled,
};

Future<Directory> checkedDirectory(String source) async {
  if (!path.isAbsolute(source)) {
    throw ArgumentError('Use an absolute run root.');
  }
  final normalized = path.normalize(source);
  final directory = Directory(normalized);
  if (await FileSystemEntity.type(normalized, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw StateError('The run root must be an existing regular directory.');
  }
  final resolved = await directory.resolveSymbolicLinks();
  if (!path.equals(normalized.toLowerCase(), resolved.toLowerCase())) {
    throw StateError('Run roots must not use filesystem aliases.');
  }
  return Directory(resolved);
}

Future<File> checkedFile(Directory root, String relativePath) async {
  final candidate = path.normalize(path.join(root.path, relativePath));
  if (path.isAbsolute(relativePath) || !path.isWithin(root.path, candidate)) {
    throw StateError('File escaped the run root: $relativePath');
  }
  if (await FileSystemEntity.type(candidate, followLinks: false) !=
      FileSystemEntityType.file) {
    throw StateError('Expected a regular file: $relativePath');
  }
  final file = File(candidate);
  final resolved = await file.resolveSymbolicLinks();
  if (!path.equals(candidate.toLowerCase(), resolved.toLowerCase())) {
    throw StateError('File aliases are outside the startup protocol.');
  }
  return file;
}

Future<void> writeJson(File file, Object data) async {
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(data)}\n',
    flush: true,
  );
}

class StartupRunSpec {
  StartupRunSpec(this.root, this.value);
  final Directory root;
  final Map<String, dynamic> value;
  String get dataset => value['dataset'] as String;
  String get revision => value['revision'] as String;
  Map<String, dynamic> get fixture =>
      (value['fixture'] as Map).cast<String, dynamic>();
  Directory get archive => Directory(path.join(root.path, 'archive'));
  String get notificationLock =>
      path.join(root.path, 'notification-runtime.lock');
  File file(String name) => File(path.join(root.path, name));

  static Future<StartupRunSpec> read(String rootPath) async {
    final root = await checkedDirectory(rootPath);
    final source = await checkedFile(root, 'run.json');
    final value = (jsonDecode(await source.readAsString()) as Map)
        .cast<String, dynamic>();
    if (value['protocolVersion'] != startupProtocolVersion ||
        value['clockProtocolId'] != startupClockProtocolId ||
        value['memoryProtocolId'] != startupMemoryProtocolId ||
        !startupDatasets.contains(value['dataset']) ||
        value['revision'] is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(value['revision'] as String)) {
      throw StateError('Invalid startup run manifest.');
    }
    final spec = StartupRunSpec(root, value);
    await checkedDirectory(spec.archive.path);
    for (final name in [
      'archive/Sked_data.json',
      'archive/Sked_school_sites.json',
      'desktop-layout.json',
      'developer-ui.json',
    ]) {
      await checkedFile(root, name);
    }
    if (await spec.file('result.json').exists() ||
        await File(spec.notificationLock).exists() ||
        await File(path.join(spec.archive.path, 'Sked_instance.lock'))
            .exists()) {
      throw StateError('A run directory cannot be reused.');
    }
    return spec;
  }
}
