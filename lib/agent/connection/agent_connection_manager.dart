import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../models/agent_settings.dart';
import '../../models/ai_api_settings.dart';
import '../../services/secret_store.dart';
import '../../utils/unique_id.dart';
import 'agent_credential_action.dart';
import 'agent_credential_store.dart';

export 'agent_credential_action.dart';
export 'agent_credential_store.dart';

enum AgentConnectionErrorCode {
  frozen,
  notInitialized,
  recoveryRequired,
  invalidConfiguration,
  endpointChanged,
  credentialMissing,
  storageFailure,
  settingsFailure,
  configurationChanged,
  legacyFailure,
}

enum AgentLegacyMigrationStatus {
  notAttempted,
  skippedExistingConfiguration,
  noLegacyConnection,
  invalidLegacyConfiguration,
  connectionOnly,
  connectionOnlyMemory,
  credentialPendingRetirement,
  credentialMigrated,
  changedLegacyCredentialRetained,
}

/// Exceptions deliberately contain neither raw keys nor underlying exceptions.
class AgentConnectionException implements Exception {
  const AgentConnectionException(
    this.code, {
    this.settingsMayHaveCommitted = false,
  });
  final AgentConnectionErrorCode code;
  final bool settingsMayHaveCommitted;
  @override
  String toString() => 'Agent connection operation failed (${code.name}).';
}

class AgentConnectionStatus {
  const AgentConnectionStatus({
    required this.storageKind,
    required this.initialized,
    required this.needsRecovery,
    required this.credentialAvailable,
    required this.legacyCredentialRetained,
    required this.migrationStatus,
  });
  final AgentCredentialStorageKind storageKind;
  final bool initialized;
  final bool needsRecovery;
  final bool credentialAvailable;
  final bool legacyCredentialRetained;
  final AgentLegacyMigrationStatus migrationStatus;
}

/// The host must provide committed settings and call initialize only after
/// resolving any unknown AppData write outcome. Legacy writers must be held
/// inactive while startup migration runs; the optional wait drains their queue.
class AgentConnectionManager {
  AgentConnectionManager({
    AgentCredentialStore? store,
    required this._readSettings,
    required this._persistSettings,
    this._readLegacySettings,
    this._legacyStore,
    this._waitForLegacyWrites,
    this._retireLegacyKey,
    String Function()? referenceGenerator,
  }) : _store = store ?? AgentCredentialStore(),
       _newReference = referenceGenerator ?? generateUuidV4;

  final AgentCredentialStore _store;
  final AgentSettings Function() _readSettings;
  final Future<void> Function(AgentSettings) _persistSettings;
  final AiApiSettings Function()? _readLegacySettings;
  final SecretStore? _legacyStore;
  final Future<void> Function()? _waitForLegacyWrites;
  final Future<void> Function()? _retireLegacyKey;
  final String Function() _newReference;
  Future<void> _tail = Future.value();
  bool _frozen = false;
  bool _initialized = false;
  bool _needsRecovery = false;
  bool _credentialAvailable = false;
  bool _legacyCredentialRetained = false;
  AgentLegacyMigrationStatus _migrationStatus =
      AgentLegacyMigrationStatus.notAttempted;

  AgentConnectionStatus get status => AgentConnectionStatus(
    storageKind: _store.kind,
    initialized: _initialized,
    needsRecovery: _needsRecovery,
    credentialAvailable: _credentialAvailable,
    legacyCredentialRetained:
        _legacyCredentialRetained ||
        _migrationStatus == AgentLegacyMigrationStatus.connectionOnlyMemory ||
        _migrationStatus ==
            AgentLegacyMigrationStatus.changedLegacyCredentialRetained,
    migrationStatus: _migrationStatus,
  );

  Future<AgentConnectionStatus> initialize({bool migrateLegacy = true}) =>
      _enqueue(() async {
        _initialized = false;
        _needsRecovery = false;
        try {
          var record = await _reconcile();
          if (migrateLegacy && record != null && !record.migrationDone) {
            record = await _migrateLegacy(record);
          }
          if (record?.legacyRetirement != null) {
            record = await _retireLegacy(record!);
          }
          final settings = _current();
          _migrationStatus =
              record?.migrationStatus ??
              AgentLegacyMigrationStatus.skippedExistingConfiguration;
          _credentialAvailable =
              record?.keyMatches(settings) == true && record?.key != null;
          _initialized = true;
          return status;
        } on AgentConnectionException {
          rethrow;
        } catch (_) {
          throw _failure(AgentConnectionErrorCode.storageFailure);
        }
      });

  /// Only connection fields are changed. Feature enablement and the default
  /// permission mode are always read fresh from the host's committed state.
  Future<AgentSettings> save(
    AgentSettings settings, {
    required AgentCredentialAction credentialAction,
    String? rawKey,
  }) => _enqueue(() async {
    _requireReady();
    return _save(settings, credentialAction: credentialAction, rawKey: rawKey);
  });

  Future<String> readKeyFor(AgentSettings snapshot) => _enqueue(() async {
    _requireReady();
    _validate(snapshot);
    if (snapshot.credentialRef == null) return '';
    final records = await _records();
    for (final record in records) {
      if (record != null && record.keyMatches(snapshot)) return record.key!;
    }
    throw const AgentConnectionException(
      AgentConnectionErrorCode.credentialMissing,
    );
  });

  /// Call after cancelling runs, before discarding this manager. It remains
  /// callable after freeze, and runs behind all previously admitted operations.
  Future<void> clearAll() => _enqueue(() async {
    final current = _current();
    if (current.credentialRef != null) {
      await _commitSettings(current.copyWith(credentialRef: null));
    }
    try {
      await _writeVerified(AgentCredentialSlot.pending, null);
      await _writeVerified(AgentCredentialSlot.active, null);
      if (_legacyStore != null) {
        await _waitForLegacyWrites?.call();
        await _clearLegacyVerified();
      }
    } on AgentConnectionException catch (error) {
      throw AgentConnectionException(
        error.code,
        settingsMayHaveCommitted:
            current.credentialRef != null || error.settingsMayHaveCommitted,
      );
    } catch (_) {
      throw _failure(
        AgentConnectionErrorCode.storageFailure,
        committed: current.credentialRef != null,
      );
    }
    _initialized = false;
    _needsRecovery = false;
    _credentialAvailable = false;
    _legacyCredentialRetained = false;
    _migrationStatus = AgentLegacyMigrationStatus.notAttempted;
  }, allowFrozen: true);

  void freeze() => _frozen = true;

  Future<void> waitForPendingWrites() async {
    while (true) {
      final pending = _tail;
      await pending;
      if (identical(pending, _tail)) return;
    }
  }

  Future<T> _enqueue<T>(
    Future<T> Function() action, {
    bool allowFrozen = false,
  }) {
    if (_frozen && !allowFrozen) {
      return Future.error(
        const AgentConnectionException(AgentConnectionErrorCode.frozen),
      );
    }
    final result = _tail.then((_) async {
      if (_frozen && !allowFrozen) {
        throw const AgentConnectionException(AgentConnectionErrorCode.frozen);
      }
      try {
        return await action();
      } on AgentConnectionException {
        rethrow;
      } catch (_) {
        throw _failure(AgentConnectionErrorCode.storageFailure);
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _requireReady() {
    if (_needsRecovery) {
      throw const AgentConnectionException(
        AgentConnectionErrorCode.recoveryRequired,
      );
    }
    if (!_initialized) {
      throw const AgentConnectionException(
        AgentConnectionErrorCode.notInitialized,
      );
    }
  }

  void _checkActive() {
    if (_frozen) {
      throw const AgentConnectionException(AgentConnectionErrorCode.frozen);
    }
  }

  AgentSettings _current() {
    final value = _readSettings();
    _validate(value);
    return value;
  }

  void _validate(AgentSettings settings) {
    try {
      settings.validate();
    } catch (_) {
      throw const AgentConnectionException(
        AgentConnectionErrorCode.invalidConfiguration,
      );
    }
  }

  AgentConnectionException _failure(
    AgentConnectionErrorCode code, {
    bool committed = false,
  }) {
    _needsRecovery = true;
    return AgentConnectionException(code, settingsMayHaveCommitted: committed);
  }

  Future<List<_CredentialRecord?>> _records() async {
    try {
      final active = await _store.read(AgentCredentialSlot.active);
      final pending = await _store.read(AgentCredentialSlot.pending);
      return [
        active == null ? null : _CredentialRecord.decode(active),
        pending == null ? null : _CredentialRecord.decode(pending),
      ];
    } catch (_) {
      throw _failure(AgentConnectionErrorCode.storageFailure);
    }
  }

  Future<void> _writeVerified(
    AgentCredentialSlot slot,
    _CredentialRecord? record,
  ) async {
    final expected = record?.encode();
    try {
      await _store.write(slot, expected);
    } catch (_) {
      /* Readback decides. */
    }
    try {
      if (await _store.read(slot) != expected) {
        throw const FormatException('Credential readback mismatch.');
      }
    } catch (_) {
      throw _failure(AgentConnectionErrorCode.storageFailure);
    }
  }

  Future<void> _commitSettings(AgentSettings desired) async {
    try {
      await _persistSettings(desired);
      if (_connectionDigest(_current()) != _connectionDigest(desired)) {
        throw const FormatException('Connection settings were not committed.');
      }
    } catch (_) {
      throw _failure(AgentConnectionErrorCode.settingsFailure, committed: true);
    }
  }

  Future<_CredentialRecord?> _reconcile() async {
    final current = _current();
    final records = await _records();
    var active = records[0];
    final pending = records[1];
    if (pending != null &&
        pending.keyMatches(current) &&
        (pending.connectionDigest == _connectionDigest(current) ||
            pending.connectionDigest ==
                _connectionDigest(current, legacy: true))) {
      await _writeVerified(AgentCredentialSlot.active, pending);
      active = pending;
      await _writeVerified(AgentCredentialSlot.pending, null);
    } else if (pending != null) {
      // The host has resolved the main-data outcome before this recovery call.
      await _writeVerified(AgentCredentialSlot.pending, null);
    }
    if (active?.keyMatches(current) == true) {
      if (active!.connectionDigest != _connectionDigest(current)) {
        active = active.withConnection(current);
        await _writeVerified(AgentCredentialSlot.active, active);
      }
      return active;
    }
    if (current.credentialRef != null) {
      // Missing platform credentials (including a Web reload) are replaceable,
      // not repaired with an unrelated key or a legacy credential.
      return null;
    }
    final empty = _CredentialRecord.forSettings(
      current,
      migrationDone:
          active?.migrationDone ?? _hasConnectionConfiguration(current),
      migrationStatus:
          active?.migrationStatus ??
          (!_hasConnectionConfiguration(current)
              ? AgentLegacyMigrationStatus.notAttempted
              : AgentLegacyMigrationStatus.skippedExistingConfiguration),
    );
    await _writeVerified(AgentCredentialSlot.active, empty);
    return empty;
  }

  Future<AgentSettings> _save(
    AgentSettings input, {
    required AgentCredentialAction credentialAction,
    String? rawKey,
    _LegacyRetirement? legacyRetirement,
    AgentLegacyMigrationStatus? migrationStatus,
  }) async {
    _checkActive();
    _validate(input);
    final original = _current();
    final canonical = normalizeAgentEndpoint(input.endpoint);
    String? key;
    String? reference;
    if (credentialAction == AgentCredentialAction.replace) {
      key = _normalizeKey(rawKey);
      if (canonical.isEmpty) {
        throw const AgentConnectionException(
          AgentConnectionErrorCode.invalidConfiguration,
        );
      }
      reference = _newReference();
      if (reference == original.credentialRef ||
          (await _records()).any((record) => record?.reference == reference)) {
        throw const AgentConnectionException(
          AgentConnectionErrorCode.invalidConfiguration,
        );
      }
    } else {
      if (rawKey != null && rawKey.isNotEmpty) {
        throw const AgentConnectionException(
          AgentConnectionErrorCode.invalidConfiguration,
        );
      }
      if (credentialAction == AgentCredentialAction.keep &&
          original.credentialRef != null) {
        if (canonical != normalizeAgentEndpoint(original.endpoint)) {
          throw const AgentConnectionException(
            AgentConnectionErrorCode.endpointChanged,
          );
        }
        for (final record in await _records()) {
          if (record?.keyMatches(original) == true) key = record!.key;
        }
        if (key == null) {
          throw const AgentConnectionException(
            AgentConnectionErrorCode.credentialMissing,
          );
        }
        reference = original.credentialRef;
      }
    }
    var desired = original.copyWith(
      endpoint: canonical,
      model: input.model.trim(),
      models: input.availableModels,
      protocol: input.protocol,
      credentialRef: reference,
    );
    final record = _CredentialRecord.forSettings(
      desired,
      key: key,
      migrationDone: true,
      legacyRetirement: legacyRetirement,
      migrationStatus:
          migrationStatus ??
          AgentLegacyMigrationStatus.skippedExistingConfiguration,
    );
    await _writeVerified(AgentCredentialSlot.pending, record);
    _checkActive();
    final latest = _current();
    if (_connectionDigest(latest) != _connectionDigest(original)) {
      throw _failure(AgentConnectionErrorCode.configurationChanged);
    }
    desired = latest.copyWith(
      endpoint: desired.endpoint,
      model: desired.model,
      models: desired.models,
      protocol: desired.protocol,
      credentialRef: desired.credentialRef,
    );
    await _commitSettings(desired);
    try {
      await _writeVerified(AgentCredentialSlot.active, record);
      await _writeVerified(AgentCredentialSlot.pending, null);
    } on AgentConnectionException catch (error) {
      throw AgentConnectionException(
        error.code,
        settingsMayHaveCommitted: true,
      );
    }
    _credentialAvailable = key != null;
    _migrationStatus = record.migrationStatus;
    return desired;
  }

  Future<_CredentialRecord> _migrateLegacy(_CredentialRecord record) async {
    final current = _current();
    if (_hasConnectionConfiguration(current) || _readLegacySettings == null) {
      final completed = record.completedMigration(
        _hasConnectionConfiguration(current)
            ? AgentLegacyMigrationStatus.skippedExistingConfiguration
            : AgentLegacyMigrationStatus.noLegacyConnection,
      );
      await _writeVerified(AgentCredentialSlot.active, completed);
      return completed;
    }
    AiApiSettings legacy;
    try {
      await _waitForLegacyWrites?.call();
      legacy = _readLegacySettings();
    } catch (_) {
      throw _failure(AgentConnectionErrorCode.legacyFailure);
    }
    late final AgentSettings input;
    try {
      input = current.copyWith(
        endpoint: legacy.customBaseUrl.trim(),
        model: legacy.customModel.trim(),
      );
      _validate(input);
    } catch (_) {
      final invalid = record.invalidLegacyConfiguration();
      await _writeVerified(AgentCredentialSlot.active, invalid);
      return invalid;
    }
    if (input.endpoint.isEmpty && input.model.isEmpty) {
      final completed = record.completedMigration(
        AgentLegacyMigrationStatus.noLegacyConnection,
      );
      await _writeVerified(AgentCredentialSlot.active, completed);
      return completed;
    }
    String? key;
    if (_store.kind == AgentCredentialStorageKind.platformSecureStorage &&
        _legacyStore != null &&
        input.endpoint.isNotEmpty) {
      try {
        final stored = (await _legacyStore.readCustomSchoolImportApiKey())
            .trim();
        if (stored.isNotEmpty) key = _normalizeKey(stored);
      } catch (_) {
        throw _failure(AgentConnectionErrorCode.legacyFailure);
      }
    } else if (_legacyStore != null &&
        _store.kind == AgentCredentialStorageKind.memoryOnly) {
      _legacyCredentialRetained = true;
    }
    final retirement = key == null
        ? null
        : _LegacyRetirement(
            endpointDigest: _endpointDigest(input.endpoint),
            keyDigest: _digest(key),
          );
    await _save(
      input,
      credentialAction: key == null
          ? AgentCredentialAction.clear
          : AgentCredentialAction.replace,
      rawKey: key,
      legacyRetirement: retirement,
      migrationStatus: _store.kind == AgentCredentialStorageKind.memoryOnly
          ? AgentLegacyMigrationStatus.connectionOnlyMemory
          : key == null
          ? AgentLegacyMigrationStatus.connectionOnly
          : AgentLegacyMigrationStatus.credentialPendingRetirement,
    );
    return (await _records())[0]!;
  }

  Future<_CredentialRecord> _retireLegacy(_CredentialRecord record) async {
    final retirement = record.legacyRetirement!;
    if (_legacyStore == null || _readLegacySettings == null) {
      _legacyCredentialRetained = true;
      return record;
    }
    try {
      await _waitForLegacyWrites?.call();
      final legacy = _readLegacySettings();
      final stored = (await _legacyStore.readCustomSchoolImportApiKey()).trim();
      if (stored.isNotEmpty &&
          (_endpointDigest(legacy.customBaseUrl) != retirement.endpointDigest ||
              _digest(stored) != retirement.keyDigest)) {
        // A newer parser credential is not the old credential we migrated.
        _legacyCredentialRetained = true;
      } else {
        await _clearLegacyVerified();
      }
      final completed = record.withoutLegacyRetirement(
        _legacyCredentialRetained
            ? AgentLegacyMigrationStatus.changedLegacyCredentialRetained
            : AgentLegacyMigrationStatus.credentialMigrated,
      );
      await _writeVerified(AgentCredentialSlot.active, completed);
      return completed;
    } on AgentConnectionException catch (error) {
      throw AgentConnectionException(
        error.code,
        settingsMayHaveCommitted: true,
      );
    } catch (_) {
      throw _failure(AgentConnectionErrorCode.legacyFailure, committed: true);
    }
  }

  Future<void> _clearLegacyVerified() async {
    try {
      if (_retireLegacyKey != null) {
        await _retireLegacyKey();
      } else {
        await _legacyStore!.writeCustomSchoolImportApiKey('');
      }
    } catch (_) {
      /* Readback decides. */
    }
    try {
      if ((await _legacyStore!.readCustomSchoolImportApiKey())
          .trim()
          .isNotEmpty) {
        throw const FormatException(
          'Legacy credential removal was not confirmed.',
        );
      }
    } catch (_) {
      throw _failure(AgentConnectionErrorCode.legacyFailure, committed: true);
    }
  }
}

String normalizeAgentEndpoint(String endpoint) {
  final trimmed = endpoint.trim();
  if (trimmed.isEmpty) return '';
  try {
    AgentSettings(endpoint: trimmed).validate();
    final uri = Uri.parse(trimmed);
    var path = uri.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      path: path.isEmpty ? '/' : path,
      query: uri.hasQuery ? uri.query : null,
      port: uri.hasPort && uri.port != (uri.scheme == 'https' ? 443 : 80)
          ? uri.port
          : null,
    ).toString();
  } catch (_) {
    throw const AgentConnectionException(
      AgentConnectionErrorCode.invalidConfiguration,
    );
  }
}

String _normalizeKey(String? value) {
  final key = value?.trim();
  if (key == null ||
      key.isEmpty ||
      key.length > 16384 ||
      key.codeUnits.any((unit) => unit < 32 || unit == 127)) {
    throw const AgentConnectionException(
      AgentConnectionErrorCode.invalidConfiguration,
    );
  }
  return key;
}

String _digest(String value) => sha256.convert(utf8.encode(value)).toString();
String _endpointDigest(String endpoint) =>
    _digest(normalizeAgentEndpoint(endpoint));
bool _hasConnectionConfiguration(AgentSettings settings) =>
    settings.endpoint.isNotEmpty ||
    settings.model.isNotEmpty ||
    settings.credentialRef != null ||
    settings.protocol != AgentModelProtocol.chatCompletions;

String _connectionDigest(AgentSettings value, {bool legacy = false}) => _digest(
  jsonEncode({
    'endpoint': normalizeAgentEndpoint(value.endpoint),
    'model': value.model,
    if (!legacy)
      'models': value.availableModels.map((model) => model.toJson()).toList(),
    'protocol': value.protocol.name,
    'credentialRef': value.credentialRef,
  }),
);

class _LegacyRetirement {
  const _LegacyRetirement({
    required this.endpointDigest,
    required this.keyDigest,
  });
  final String endpointDigest;
  final String keyDigest;
  Map<String, Object?> toJson() => {
    'endpointDigest': endpointDigest,
    'keyDigest': keyDigest,
  };
}

class _CredentialRecord {
  const _CredentialRecord({
    required this.reference,
    required this.endpointDigest,
    required this.connectionDigest,
    required this.key,
    required this.migrationDone,
    required this.migrationStatus,
    this.legacyRetirement,
  });
  factory _CredentialRecord.forSettings(
    AgentSettings settings, {
    String? key,
    required bool migrationDone,
    AgentLegacyMigrationStatus migrationStatus =
        AgentLegacyMigrationStatus.notAttempted,
    _LegacyRetirement? legacyRetirement,
  }) => _CredentialRecord(
    reference: settings.credentialRef,
    endpointDigest: _endpointDigest(settings.endpoint),
    connectionDigest: _connectionDigest(settings),
    key: key,
    migrationDone: migrationDone,
    migrationStatus: migrationStatus,
    legacyRetirement: legacyRetirement,
  );
  final String? reference;
  final String endpointDigest;
  final String connectionDigest;
  final String? key;
  final bool migrationDone;
  final AgentLegacyMigrationStatus migrationStatus;
  final _LegacyRetirement? legacyRetirement;
  bool keyMatches(AgentSettings settings) =>
      reference == settings.credentialRef &&
      endpointDigest == _endpointDigest(settings.endpoint) &&
      ((reference == null && key == null) ||
          (reference != null && key != null));
  _CredentialRecord withConnection(AgentSettings settings) =>
      _CredentialRecord.forSettings(
        settings,
        key: key,
        migrationDone: migrationDone,
        migrationStatus: migrationStatus,
        legacyRetirement: legacyRetirement,
      );
  _CredentialRecord completedMigration(AgentLegacyMigrationStatus status) =>
      _CredentialRecord(
        reference: reference,
        endpointDigest: endpointDigest,
        connectionDigest: connectionDigest,
        key: key,
        migrationDone: true,
        migrationStatus: status,
        legacyRetirement: legacyRetirement,
      );
  _CredentialRecord invalidLegacyConfiguration() => _CredentialRecord(
    reference: reference,
    endpointDigest: endpointDigest,
    connectionDigest: connectionDigest,
    key: key,
    migrationDone: false,
    migrationStatus: AgentLegacyMigrationStatus.invalidLegacyConfiguration,
  );
  _CredentialRecord withoutLegacyRetirement(
    AgentLegacyMigrationStatus status,
  ) => _CredentialRecord(
    reference: reference,
    endpointDigest: endpointDigest,
    connectionDigest: connectionDigest,
    key: key,
    migrationDone: migrationDone,
    migrationStatus: status,
  );
  String encode() => jsonEncode({
    'version': 1,
    'reference': reference,
    'endpointDigest': endpointDigest,
    'connectionDigest': connectionDigest,
    'key': key,
    'migrationDone': migrationDone,
    'migrationStatus': migrationStatus.name,
    'legacyRetirement': legacyRetirement?.toJson(),
  });
  factory _CredentialRecord.decode(String source) {
    if (source.length > 40000) {
      throw const FormatException('Credential record is too large.');
    }
    final raw = jsonDecode(source);
    const fields = {
      'version',
      'reference',
      'endpointDigest',
      'connectionDigest',
      'key',
      'migrationDone',
      'migrationStatus',
      'legacyRetirement',
    };
    bool hash(Object? value) =>
        value is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
    if (raw is! Map ||
        raw.length != fields.length ||
        raw.keys.any((key) => !fields.contains(key)) ||
        raw['version'] != 1 ||
        raw['version'] is! int ||
        !hash(raw['endpointDigest']) ||
        !hash(raw['connectionDigest']) ||
        raw['migrationDone'] is! bool ||
        !AgentLegacyMigrationStatus.values.any(
          (value) => value.name == raw['migrationStatus'],
        ) ||
        (raw['reference'] != null &&
            (raw['reference'] is! String ||
                (raw['reference'] as String).isEmpty ||
                (raw['reference'] as String).length > 256)) ||
        (raw['key'] != null && raw['key'] is! String) ||
        ((raw['reference'] == null) != (raw['key'] == null))) {
      throw const FormatException('Credential record is invalid.');
    }
    if (raw['key'] != null &&
        _normalizeKey(raw['key'] as String) != raw['key']) {
      throw const FormatException('Credential record key is invalid.');
    }
    final retirement = raw['legacyRetirement'];
    if (retirement != null &&
        (retirement is! Map ||
            retirement.length != 2 ||
            !hash(retirement['endpointDigest']) ||
            !hash(retirement['keyDigest']))) {
      throw const FormatException('Legacy retirement metadata is invalid.');
    }
    return _CredentialRecord(
      reference: raw['reference'] as String?,
      endpointDigest: raw['endpointDigest'] as String,
      connectionDigest: raw['connectionDigest'] as String,
      key: raw['key'] as String?,
      migrationDone: raw['migrationDone'] as bool,
      migrationStatus: AgentLegacyMigrationStatus.values.singleWhere(
        (value) => value.name == raw['migrationStatus'],
      ),
      legacyRetirement: retirement == null
          ? null
          : _LegacyRetirement(
              endpointDigest: retirement['endpointDigest'] as String,
              keyDigest: retirement['keyDigest'] as String,
            ),
    );
  }
}
