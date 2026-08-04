import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/migrations/migration.dart';
import '../l10n/app_locale.dart';
import '../models/app_backup.dart';
import '../models/app_data.dart';
import '../utils/constants.dart';
import '../utils/shared_preferences_recovery.dart';

enum AppBackupRestoreJournalLoadStatus {
  missing,
  valid,
  corrupt,
  unsupportedVersion,
  ioFailure,
}

enum AppBackupRestoreApiKeyPolicy { clear, preserve }

enum AppBackupRestoreJournalPhase {
  prepared,
  dataCommitted,
  secretPolicyApplied,
}

class AppBackupRestoreJournalLoadResult {
  const AppBackupRestoreJournalLoadResult({
    required this.status,
    this.source,
    this.backupSource,
    this.backup,
    this.apiKeyPolicy = AppBackupRestoreApiKeyPolicy.clear,
    this.phase = AppBackupRestoreJournalPhase.prepared,
    this.journalRecoveryArtifacts = const [],
    this.recoveryArtifacts = const [],
    this.error,
  });

  final AppBackupRestoreJournalLoadStatus status;
  final String? source;
  final String? backupSource;
  final AppBackupData? backup;
  final AppBackupRestoreApiKeyPolicy apiKeyPolicy;
  final AppBackupRestoreJournalPhase phase;
  final List<String> journalRecoveryArtifacts;
  final List<String> recoveryArtifacts;
  final Object? error;
}

class AppBackupRestoreJournalException implements Exception {
  const AppBackupRestoreJournalException(this.message, {this.cause});

  final String message;
  final Object? cause;

  bool get stateUnknown => false;

  @override
  String toString() => cause == null ? message : '$message: $cause';
}

class AppBackupRestoreJournalStateUnknownException
    extends AppBackupRestoreJournalException {
  const AppBackupRestoreJournalStateUnknownException({
    required this.operationError,
    required this.verificationError,
  }) : super(
         'The app-backup restore journal state could not be confirmed after '
         'a failed persistence operation.',
         cause: verificationError,
       );

  final Object operationError;
  final Object verificationError;

  @override
  bool get stateUnknown => true;
}

abstract class AppBackupRestoreJournal {
  factory AppBackupRestoreJournal() = SharedPreferencesAppBackupRestoreJournal;

  const AppBackupRestoreJournal.base();

  String get pendingArtifactPath;

  Future<String?> read();

  Future<void> write(String source);

  Future<void> clear();

  Future<String> preserveForRecovery(String source);

  Future<List<String>> listRecoveryArtifacts() async => const [];

  Future<Uint8List?> readRecoveryArtifact(String artifactPath);

  Future<AppBackupRestoreJournalLoadResult> load({
    String localeCode = defaultLocaleCode,
  }) async {
    late final String? source;
    try {
      source = await read();
    } on _StoredJournalValueCorruptException catch (error) {
      final historicalArtifacts = await _tryListRecoveryArtifacts();
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.corrupt,
        source: error.source,
        recoveryArtifacts: _mergeRecoveryArtifacts([
          error.recoveryArtifact,
          ...historicalArtifacts,
        ]),
        error: error,
      );
    } catch (error) {
      final historicalArtifacts = await _tryListRecoveryArtifacts();
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.ioFailure,
        recoveryArtifacts: _mergeRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
        ]),
        error: error,
      );
    }
    final historicalArtifacts = await _tryListRecoveryArtifacts();
    if (source == null) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.missing,
        recoveryArtifacts: historicalArtifacts,
      );
    }

    try {
      final result = _decodeJournalSource(
        source,
        localeCode: localeCode,
        pendingArtifactPath: pendingArtifactPath,
      );
      return _withRecoveryArtifacts(result, historicalArtifacts);
    } on UnsupportedSchemaVersionException catch (error) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.unsupportedVersion,
        source: source,
        recoveryArtifacts: _mergeRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
        ]),
        error: error,
      );
    } on _UnsupportedJournalVersionException catch (error) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.unsupportedVersion,
        source: source,
        recoveryArtifacts: _mergeRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
        ]),
        error: error,
      );
    } on _UnsupportedJournalPhaseException catch (error) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.unsupportedVersion,
        source: source,
        recoveryArtifacts: _mergeRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
        ]),
        error: error,
      );
    } catch (error) {
      return AppBackupRestoreJournalLoadResult(
        status: AppBackupRestoreJournalLoadStatus.corrupt,
        source: source,
        recoveryArtifacts: _mergeRecoveryArtifacts([
          pendingArtifactPath,
          ...historicalArtifacts,
        ]),
        error: error,
      );
    }
  }

  Future<List<String>> _tryListRecoveryArtifacts() async {
    try {
      return await listRecoveryArtifacts();
    } catch (_) {
      return const [];
    }
  }

  Future<AppBackupRestoreJournalLoadResult> writePrepared(
    String appBackupSource, {
    AppBackupRestoreApiKeyPolicy apiKeyPolicy =
        AppBackupRestoreApiKeyPolicy.clear,
    List<String> recoveryArtifacts = const [],
    String localeCode = defaultLocaleCode,
  }) {
    return _writeStateConfirmed(
      appBackupSource,
      apiKeyPolicy: apiKeyPolicy,
      phase: AppBackupRestoreJournalPhase.prepared,
      recoveryArtifacts: recoveryArtifacts,
      localeCode: localeCode,
    );
  }

  Future<AppBackupRestoreJournalLoadResult> advancePhase(
    AppBackupRestoreJournalLoadResult current,
    AppBackupRestoreJournalPhase nextPhase, {
    String localeCode = defaultLocaleCode,
  }) {
    final appBackupSource = current.backupSource;
    if (current.status != AppBackupRestoreJournalLoadStatus.valid ||
        appBackupSource == null) {
      throw StateError('A valid restore journal is required to advance phase.');
    }
    if (nextPhase.index != current.phase.index + 1) {
      throw StateError(
        'Restore journal phase must advance exactly once from '
        '${current.phase.name} to ${nextPhase.name}.',
      );
    }
    return _writeStateConfirmed(
      appBackupSource,
      apiKeyPolicy: current.apiKeyPolicy,
      phase: nextPhase,
      recoveryArtifacts: current.journalRecoveryArtifacts,
      localeCode: localeCode,
    );
  }

  Future<AppBackupRestoreJournalLoadResult> writeReconciliation(
    String appBackupSource, {
    required String recoveryArtifact,
    String localeCode = defaultLocaleCode,
  }) {
    return writePrepared(
      appBackupSource,
      apiKeyPolicy: AppBackupRestoreApiKeyPolicy.preserve,
      recoveryArtifacts: [recoveryArtifact],
      localeCode: localeCode,
    );
  }

  Future<AppBackupRestoreJournalLoadResult> _writeStateConfirmed(
    String appBackupSource, {
    required AppBackupRestoreApiKeyPolicy apiKeyPolicy,
    required AppBackupRestoreJournalPhase phase,
    required List<String> recoveryArtifacts,
    required String localeCode,
  }) async {
    final source = _encodeJournalSource(
      appBackupSource,
      apiKeyPolicy: apiKeyPolicy,
      phase: phase,
      recoveryArtifacts: recoveryArtifacts,
    );
    await write(source);
    final confirmed = await load(localeCode: localeCode);
    if (confirmed.status == AppBackupRestoreJournalLoadStatus.valid &&
        confirmed.source == source &&
        confirmed.phase == phase &&
        confirmed.apiKeyPolicy == apiKeyPolicy) {
      return confirmed;
    }
    throw AppBackupRestoreJournalStateUnknownException(
      operationError: 'Restore journal phase ${phase.name} was written.',
      verificationError:
          confirmed.error ??
          StateError(
            'Restore journal phase ${phase.name} could not be read back.',
          ),
    );
  }
}

class SharedPreferencesAppBackupRestoreJournal extends AppBackupRestoreJournal {
  SharedPreferencesAppBackupRestoreJournal({
    Future<SharedPreferences> Function()? preferencesProvider,
    Future<bool> Function(SharedPreferences, String, String)? stringWriter,
    Future<bool> Function(SharedPreferences, String)? keyRemover,
    Future<void> Function(SharedPreferences)? preferencesReloader,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _stringWriter =
           stringWriter ??
           ((preferences, key, value) => preferences.setString(key, value)),
       _keyRemover =
           keyRemover ?? ((preferences, key) => preferences.remove(key)),
       _preferencesReloader =
           preferencesReloader ?? ((preferences) => preferences.reload()),
       super.base();

  static const _storageKey = 'Sked_pending_app_backup_restore';
  static const _recoveryStoragePrefix = 'Sked_app_backup_restore_recovery_';
  static const _artifactPrefix = 'shared-preferences://sked/';
  final Future<SharedPreferences> Function() _preferencesProvider;
  final Future<bool> Function(SharedPreferences, String, String) _stringWriter;
  final Future<bool> Function(SharedPreferences, String) _keyRemover;
  final Future<void> Function(SharedPreferences) _preferencesReloader;
  Future<void> _operationTail = Future<void>.value();

  @override
  String get pendingArtifactPath => '$_artifactPrefix$_storageKey';

  @override
  Future<String?> read() => _enqueue(() async {
    try {
      final preferences = await _preferencesProvider();
      await _preferencesReloader(preferences);
      final value = preferences.get(_storageKey);
      if (value == null) return null;
      if (value is String) return value;

      final source = encodeSharedPreferencesRecoveryEnvelope(
        originalKey: _storageKey,
        value: value,
      );
      final recoveryArtifact = await _preserveSourceNow(preferences, source);
      await _writeStringConfirmed(
        preferences,
        _storageKey,
        source,
        rejectionMessage:
            'Storage rejected the invalid restore-journal recovery marker.',
      );
      throw _StoredJournalValueCorruptException(
        source: source,
        recoveryArtifact: recoveryArtifact,
      );
    } on AppBackupRestoreJournalException {
      rethrow;
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to read the pending app-backup restore journal.',
        cause: error,
      );
    }
  });

  @override
  Future<void> write(String source) => _enqueue(() async {
    try {
      final preferences = await _preferencesProvider();
      await _preferencesReloader(preferences);
      await _writeStringConfirmed(
        preferences,
        _storageKey,
        source,
        rejectionMessage: 'Storage rejected the app-backup restore journal.',
      );
    } on AppBackupRestoreJournalException {
      rethrow;
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to persist the app-backup restore journal.',
        cause: error,
      );
    }
  });

  @override
  Future<void> clear() => _enqueue(() async {
    try {
      final preferences = await _preferencesProvider();
      await _preferencesReloader(preferences);
      if (!preferences.containsKey(_storageKey)) return;
      await _removeConfirmed(
        preferences,
        _storageKey,
        rejectionMessage:
            'Storage rejected removal of the app-backup restore journal.',
      );
    } on AppBackupRestoreJournalException {
      rethrow;
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to clear the app-backup restore journal.',
        cause: error,
      );
    }
  });

  @override
  Future<String> preserveForRecovery(String source) => _enqueue(() async {
    try {
      final preferences = await _preferencesProvider();
      await _preferencesReloader(preferences);
      return _preserveSourceNow(preferences, source);
    } on AppBackupRestoreJournalException {
      rethrow;
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to preserve the invalid app-backup restore journal.',
        cause: error,
      );
    }
  });

  @override
  Future<List<String>> listRecoveryArtifacts() => _enqueue(() async {
    try {
      final preferences = await _preferencesProvider();
      await _preferencesReloader(preferences);
      final artifacts =
          preferences
              .getKeys()
              .where(_isRecoveryStorageKey)
              .map((key) => '$_artifactPrefix$key')
              .toList()
            ..sort();
      return List.unmodifiable(artifacts);
    } catch (error) {
      throw AppBackupRestoreJournalException(
        'Unable to enumerate app-backup restore recovery artifacts.',
        cause: error,
      );
    }
  });

  @override
  Future<Uint8List?> readRecoveryArtifact(String artifactPath) =>
      _enqueue(() async {
        final key = _recoveryArtifactKey(artifactPath);
        if (key == null) return null;
        try {
          final preferences = await _preferencesProvider();
          await _preferencesReloader(preferences);
          final value = preferences.get(key);
          if (value == null) return null;
          final source = sharedPreferencesRecoverySource(
            originalKey: key,
            value: value,
          );
          return Uint8List.fromList(utf8.encode(source));
        } catch (error) {
          throw AppBackupRestoreJournalException(
            'Unable to read the app-backup restore recovery artifact.',
            cause: error,
          );
        }
      });

  Future<String> _preserveSourceNow(
    SharedPreferences preferences,
    String source,
  ) async {
    final digest = sha256.convert(utf8.encode(source));
    final key = '$_recoveryStoragePrefix$digest';
    final existing = preferences.get(key);
    if (existing != null && (existing is! String || existing != source)) {
      throw const AppBackupRestoreJournalException(
        'A restore-journal recovery key collision was detected.',
      );
    }
    if (existing == null) {
      await _writeStringConfirmed(
        preferences,
        key,
        source,
        rejectionMessage:
            'Storage rejected the restore-journal recovery artifact.',
      );
    }
    return '$_artifactPrefix$key';
  }

  Future<void> _writeStringConfirmed(
    SharedPreferences preferences,
    String key,
    String source, {
    required String rejectionMessage,
  }) async {
    Object? operationError;
    try {
      final saved = await _stringWriter(preferences, key, source);
      if (!saved) {
        operationError = AppBackupRestoreJournalException(rejectionMessage);
      }
    } catch (error) {
      operationError = error;
    }

    try {
      await _preferencesReloader(preferences);
      if (preferences.get(key) == source) return;
    } catch (verificationError) {
      throw AppBackupRestoreJournalStateUnknownException(
        operationError: operationError ?? 'The journal write reported success.',
        verificationError: verificationError,
      );
    }

    operationError ??= AppBackupRestoreJournalException(rejectionMessage);
    if (operationError is AppBackupRestoreJournalException) {
      throw operationError;
    }
    throw AppBackupRestoreJournalException(
      rejectionMessage,
      cause: operationError,
    );
  }

  Future<void> _removeConfirmed(
    SharedPreferences preferences,
    String key, {
    required String rejectionMessage,
  }) async {
    Object? operationError;
    try {
      final removed = await _keyRemover(preferences, key);
      if (!removed) {
        operationError = AppBackupRestoreJournalException(rejectionMessage);
      }
    } catch (error) {
      operationError = error;
    }

    try {
      await _preferencesReloader(preferences);
      if (!preferences.containsKey(key)) return;
    } catch (verificationError) {
      throw AppBackupRestoreJournalStateUnknownException(
        operationError:
            operationError ?? 'The journal removal reported success.',
        verificationError: verificationError,
      );
    }

    operationError ??= AppBackupRestoreJournalException(rejectionMessage);
    if (operationError is AppBackupRestoreJournalException) {
      throw operationError;
    }
    throw AppBackupRestoreJournalException(
      rejectionMessage,
      cause: operationError,
    );
  }

  String? _recoveryArtifactKey(String artifactPath) {
    if (!artifactPath.startsWith(_artifactPrefix)) return null;
    final key = artifactPath.substring(_artifactPrefix.length);
    if (key == _storageKey) return key;
    if (!_isRecoveryStorageKey(key)) return null;
    return key;
  }

  bool _isRecoveryStorageKey(String key) {
    if (!key.startsWith(_recoveryStoragePrefix)) return false;
    final digest = key.substring(_recoveryStoragePrefix.length);
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(digest);
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _operationTail.then((_) => action());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}

class _StoredJournalValueCorruptException
    extends AppBackupRestoreJournalException {
  const _StoredJournalValueCorruptException({
    required this.source,
    required this.recoveryArtifact,
  }) : super(
         'The pending app-backup restore journal had an invalid value type.',
       );

  final String source;
  final String recoveryArtifact;
}

const _journalSchema = 'app-backup-restore-journal';
const _journalVersion = 2;
const _legacyJournalVersion = 1;
const _clearApiKeyPolicy = 'clear';
const _preserveApiKeyPolicy = 'preserve';
const _preparedPhase = 'prepared';
const _dataCommittedPhase = 'dataCommitted';
const _secretPolicyAppliedPhase = 'secretPolicyApplied';

AppBackupRestoreJournalLoadResult _withRecoveryArtifacts(
  AppBackupRestoreJournalLoadResult result,
  Iterable<String> historicalArtifacts,
) {
  return AppBackupRestoreJournalLoadResult(
    status: result.status,
    source: result.source,
    backupSource: result.backupSource,
    backup: result.backup,
    apiKeyPolicy: result.apiKeyPolicy,
    phase: result.phase,
    journalRecoveryArtifacts: result.journalRecoveryArtifacts,
    recoveryArtifacts: _mergeRecoveryArtifacts([
      ...result.recoveryArtifacts,
      ...historicalArtifacts,
    ]),
    error: result.error,
  );
}

List<String> _mergeRecoveryArtifacts(Iterable<String> artifacts) {
  return List.unmodifiable(artifacts.toSet().toList()..sort());
}

AppBackupRestoreJournalLoadResult _decodeJournalSource(
  String source, {
  required String localeCode,
  required String pendingArtifactPath,
}) {
  final envelope = ImportExportEnvelope.decode(source);
  var backupSource = source;
  var apiKeyPolicy = AppBackupRestoreApiKeyPolicy.clear;
  var phase = AppBackupRestoreJournalPhase.prepared;
  var recoveryArtifacts = const <String>[];

  if (envelope.schema.trim() == _journalSchema) {
    if (envelope.version > _journalVersion) {
      throw _UnsupportedJournalVersionException(envelope.version);
    }
    if (envelope.version < _legacyJournalVersion) {
      throw const FormatException('Restore journal version is invalid.');
    }
    final rawBackupSource = envelope.data['backupSource'];
    final rawApiKeyPolicy = envelope.data['apiKeyPolicy'];
    final rawArtifacts = envelope.data['recoveryArtifacts'];
    if (rawBackupSource is! String ||
        rawArtifacts is! List ||
        rawArtifacts.any((value) => value is! String)) {
      throw const FormatException('Restore journal format is invalid.');
    }
    backupSource = rawBackupSource;
    recoveryArtifacts = List<String>.unmodifiable(rawArtifacts.cast<String>());
    if (envelope.version == _legacyJournalVersion) {
      if (rawApiKeyPolicy != _preserveApiKeyPolicy) {
        throw const FormatException('Restore journal format is invalid.');
      }
      apiKeyPolicy = AppBackupRestoreApiKeyPolicy.preserve;
    } else {
      apiKeyPolicy = switch (rawApiKeyPolicy) {
        _clearApiKeyPolicy => AppBackupRestoreApiKeyPolicy.clear,
        _preserveApiKeyPolicy => AppBackupRestoreApiKeyPolicy.preserve,
        _ => throw const FormatException(
          'Restore journal API key policy is invalid.',
        ),
      };
      phase = switch (envelope.data['phase']) {
        _preparedPhase => AppBackupRestoreJournalPhase.prepared,
        _dataCommittedPhase => AppBackupRestoreJournalPhase.dataCommitted,
        _secretPolicyAppliedPhase =>
          AppBackupRestoreJournalPhase.secretPolicyApplied,
        final Object? value => throw _UnsupportedJournalPhaseException(value),
      };
    }
  } else if (isImportExportSchema(envelope.schema, appBackupSchema) &&
      envelope.version > appBackupVersion) {
    throw _UnsupportedJournalVersionException(envelope.version);
  }

  final backup = decodeAppBackup(backupSource, localeCode: localeCode);
  if (!backup.includesSchoolSites) {
    throw const FormatException(
      'Pending app-backup restore journal does not include school sites.',
    );
  }
  return AppBackupRestoreJournalLoadResult(
    status: AppBackupRestoreJournalLoadStatus.valid,
    source: source,
    backupSource: backupSource,
    backup: backup,
    apiKeyPolicy: apiKeyPolicy,
    phase: phase,
    journalRecoveryArtifacts: recoveryArtifacts,
    recoveryArtifacts: recoveryArtifacts,
  );
}

String _encodeJournalSource(
  String appBackupSource, {
  required AppBackupRestoreApiKeyPolicy apiKeyPolicy,
  required AppBackupRestoreJournalPhase phase,
  required List<String> recoveryArtifacts,
}) {
  return ImportExportEnvelope(
    schema: _journalSchema,
    version: _journalVersion,
    data: {
      'backupSource': appBackupSource,
      'apiKeyPolicy': switch (apiKeyPolicy) {
        AppBackupRestoreApiKeyPolicy.clear => _clearApiKeyPolicy,
        AppBackupRestoreApiKeyPolicy.preserve => _preserveApiKeyPolicy,
      },
      'phase': switch (phase) {
        AppBackupRestoreJournalPhase.prepared => _preparedPhase,
        AppBackupRestoreJournalPhase.dataCommitted => _dataCommittedPhase,
        AppBackupRestoreJournalPhase.secretPolicyApplied =>
          _secretPolicyAppliedPhase,
      },
      'recoveryArtifacts': recoveryArtifacts,
    },
  ).encode();
}

class _UnsupportedJournalVersionException implements Exception {
  const _UnsupportedJournalVersionException(this.version);

  final int version;

  @override
  String toString() =>
      'App-backup restore journal version $version is not supported.';
}

class _UnsupportedJournalPhaseException implements Exception {
  const _UnsupportedJournalPhaseException(this.phase);

  final Object? phase;

  @override
  String toString() =>
      'App-backup restore journal phase $phase is not supported.';
}
