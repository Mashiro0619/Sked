import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sked/services/app_backup_restore_journal.dart';

class _TestAppBackupRestoreJournalState {
  String? source;
  final recoverySources = <String, String>{};
  var nextRecoveryArtifact = 0;

  void reset() {
    source = null;
    recoverySources.clear();
    nextRecoveryArtifact = 0;
  }
}

class _TestAppBackupRestoreJournal extends AppBackupRestoreJournal {
  _TestAppBackupRestoreJournal(this._state) : super.base();

  static const _pendingArtifactPath = 'memory://app-backup-restore/pending';
  static const _recoveryArtifactPrefix =
      'memory://app-backup-restore/recovery/';

  final _TestAppBackupRestoreJournalState _state;

  @override
  Future<AppBackupRestoreJournalLoadResult> load({String localeCode = 'zh'}) {
    final source = _state.source;
    if (source == null) {
      return SynchronousFuture(
        AppBackupRestoreJournalLoadResult(
          status: AppBackupRestoreJournalLoadStatus.missing,
          recoveryArtifacts: _state.recoverySources.keys.toList()..sort(),
        ),
      );
    }
    return super.load(localeCode: localeCode);
  }

  @override
  String get pendingArtifactPath => _pendingArtifactPath;

  @override
  Future<String?> read() async => _state.source;

  @override
  Future<void> write(String source) async {
    _state.source = source;
  }

  @override
  Future<void> clear() async {
    _state.source = null;
  }

  @override
  Future<String> preserveForRecovery(String source) async {
    final artifact = '$_recoveryArtifactPrefix${_state.nextRecoveryArtifact++}';
    _state.recoverySources[artifact] = source;
    return artifact;
  }

  @override
  Future<List<String>> listRecoveryArtifacts() async =>
      _state.recoverySources.keys.toList()..sort();

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) async {
    if (artifactPath == pendingArtifactPath) {
      final source = _state.source;
      return source == null ? null : Uint8List.fromList(utf8.encode(source));
    }
    final source = _state.recoverySources[artifactPath];
    return source == null ? null : Uint8List.fromList(utf8.encode(source));
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final appBackupRestoreJournalState = _TestAppBackupRestoreJournalState();
  debugSetAppBackupRestoreJournalFactory(
    () => _TestAppBackupRestoreJournal(appBackupRestoreJournalState),
  );
  setUp(() {
    appBackupRestoreJournalState.reset();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  tearDownAll(() {
    debugSetAppBackupRestoreJournalFactory(null);
  });
  await testMain();
}
