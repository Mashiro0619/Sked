import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:sked/agent/connection/agent_connection_manager.dart';
import 'package:sked/application/operation_contracts.dart';
import 'package:sked/models/agent_settings.dart';
import 'package:sked/models/ai_api_settings.dart';
import 'package:sked/services/secret_store.dart';

class Vault extends AgentCredentialStore {
  Vault({this.storageKind = AgentCredentialStorageKind.platformSecureStorage})
    : super.base();
  final AgentCredentialStorageKind storageKind;
  final values = <AgentCredentialSlot, String>{};
  final events = <String>[];
  Future<void> Function(AgentCredentialSlot, String?)? beforeWrite;
  void Function(AgentCredentialSlot, String?)? afterWrite;
  void Function(AgentCredentialSlot)? beforeRead;
  @override
  AgentCredentialStorageKind get kind => storageKind;
  @override
  Future<String?> read(AgentCredentialSlot slot) async {
    events.add('read:${slot.name}');
    beforeRead?.call(slot);
    return values[slot];
  }

  @override
  Future<void> write(AgentCredentialSlot slot, String? value) async {
    events.add('write:${slot.name}:${value == null ? 'delete' : 'value'}');
    await beforeWrite?.call(slot, value);
    if (value == null) {
      values.remove(slot);
    } else {
      values[slot] = value;
    }
    afterWrite?.call(slot, value);
  }
}

class LegacySecrets implements SecretStore {
  String key = '';
  bool failRead = false;
  bool failWrite = false;
  int reads = 0;
  int clears = 0;
  @override
  Future<String> readCustomSchoolImportApiKey() async {
    reads++;
    if (failRead) throw StateError('secret-in-backend-error');
    return key;
  }

  @override
  Future<void> writeCustomSchoolImportApiKey(String value) async {
    if (failWrite) throw StateError('secret-in-backend-error');
    key = value;
    if (value.isEmpty) clears++;
  }
}

void main() {
  late Vault vault;
  late LegacySecrets legacySecrets;
  late AgentSettings current;
  late AiApiSettings legacy;
  Future<void> Function(AgentSettings)? persist;
  Future<void> Function()? retire;
  var sequence = 0;
  var commits = 0;
  AgentConnectionManager manager() => AgentConnectionManager(
    store: vault,
    readSettings: () => current,
    persistSettings: (next) async {
      commits++;
      if (persist != null) {
        await persist!(next);
      } else {
        current = next;
      }
    },
    readLegacySettings: () => legacy,
    legacyStore: legacySecrets,
    retireLegacyKey: retire,
    referenceGenerator: () => 'credential-${++sequence}',
  );
  const configured = AgentSettings(
    endpoint: 'https://example.test/v1',
    model: 'model-a',
  );
  Matcher error(AgentConnectionErrorCode code) => throwsA(
    isA<AgentConnectionException>().having((e) => e.code, 'code', code),
  );
  Future<AgentConnectionManager> seeded() async {
    final result = manager();
    await result.initialize(migrateLegacy: false);
    await result.save(
      configured,
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'old-key',
    );
    return result;
  }

  setUp(() {
    vault = Vault();
    legacySecrets = LegacySecrets();
    current = const AgentSettings();
    legacy = const AiApiSettings();
    persist = null;
    retire = null;
    sequence = 0;
    commits = 0;
  });

  test('normalization binds full endpoints including path and query', () {
    expect(
      normalizeAgentEndpoint('HTTPS://EXAMPLE.TEST:443/v1/'),
      'https://example.test/v1',
    );
    expect(
      normalizeAgentEndpoint('http://EXAMPLE.TEST:80'),
      'http://example.test/',
    );
    expect(
      normalizeAgentEndpoint('https://example.test:8443/v1?q=a%2Fb'),
      'https://example.test:8443/v1?q=a%2Fb',
    );
    for (final endpoint in [
      'file:///path',
      'https://user:key@example.test',
      'https://example.test/#x',
    ]) {
      expect(
        () => normalizeAgentEndpoint(endpoint),
        error(AgentConnectionErrorCode.invalidConfiguration),
      );
    }
  });

  test('replacement verifies pending before settings and leaves only the active slot', () async {
    final connection = await seeded();
    expect(current.credentialRef, 'credential-1');
    expect(current.toJson().toString(), isNot(contains('old-key')));
    expect(await connection.readKeyFor(current), 'old-key');
    expect(vault.values.keys, [AgentCredentialSlot.active]);
    final pendingWrite = vault.events.indexOf('write:pending:value');
    expect(vault.events[pendingWrite + 1], 'read:pending');
    expect(
      connection.status.storageKind,
      AgentCredentialStorageKind.platformSecureStorage,
    );
  });

  test(
    'legacy pending credential digest survives the model-list schema migration',
    () async {
      await seeded();
      final oldRecord = jsonDecode(
        vault.values[AgentCredentialSlot.active]!,
      ) as Map<String, dynamic>;
      oldRecord['connectionDigest'] = sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'endpoint': normalizeAgentEndpoint(current.endpoint),
                'model': current.model,
                'protocol': current.protocol.name,
                'credentialRef': current.credentialRef,
              }),
            ),
          )
          .toString();
      vault.values
        ..remove(AgentCredentialSlot.active)
        ..[AgentCredentialSlot.pending] = jsonEncode(oldRecord);
      current = AgentSettings.fromJson(current.toJson());
      final recovered = manager();
      await recovered.initialize(migrateLegacy: false);
      expect(await recovered.readKeyFor(current), 'old-key');
      expect(vault.values.keys, [AgentCredentialSlot.active]);
      expect(recovered.status.needsRecovery, isFalse);
    },
  );

  test('connection writes preserve preferences edited while the credential is staged', () async {
    final connection = await seeded();
    final staged = Completer<void>(), release = Completer<void>();
    vault.beforeWrite = (slot, value) async {
      if (slot == AgentCredentialSlot.pending && value != null) {
        staged.complete();
        await release.future;
      }
    };
    final saving = connection.save(
      current.copyWith(model: 'model-b'),
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'replacement-key',
    );
    await staged.future;
    current = current.copyWith(
      enabled: true,
      permissionMode: AgentPermissionMode.plan,
      systemInstructions: 'Latest instructions',
      maxModelRounds: 9,
      maxToolCalls: 27,
      maxTotalTokens: 9000,
      historyRetentionDays: 14,
    );
    release.complete();
    await saving;
    expect(current.model, 'model-b');
    expect(await connection.readKeyFor(current), 'replacement-key');
    expect(current.enabled, isTrue);
    expect(current.permissionMode, AgentPermissionMode.plan);
    expect(current.systemInstructions, 'Latest instructions');
    expect(current.maxModelRounds, 9);
    expect(current.maxToolCalls, 27);
    expect(current.maxTotalTokens, 9000);
    expect(current.historyRetentionDays, 14);
  });

  test(
    'preferences alone do not suppress legacy connection migration',
    () async {
      current = const AgentSettings(
        enabled: true,
        permissionMode: AgentPermissionMode.plan,
        systemInstructions: 'Keep guidance',
        maxModelRounds: 8,
        maxToolCalls: 25,
        maxTotalTokens: 8192,
        historyRetentionDays: 30,
      );
      legacy = const AiApiSettings(
        customBaseUrl: 'https://legacy.test/v1',
        customModel: 'legacy-model',
      );
      legacySecrets.key = 'legacy-key';
      final connection = manager();
      await connection.initialize();
      expect(current.endpoint, 'https://legacy.test/v1');
      expect(current.model, 'legacy-model');
      expect(await connection.readKeyFor(current), 'legacy-key');
      expect(current.enabled, isTrue);
      expect(current.permissionMode, AgentPermissionMode.plan);
      expect(current.systemInstructions, 'Keep guidance');
      expect(current.maxModelRounds, 8);
      expect(current.maxToolCalls, 25);
      expect(current.maxTotalTokens, 8192);
      expect(current.historyRetentionDays, 30);
      expect(legacySecrets.key, isEmpty);
    },
  );

  test(
    'keep cannot send a saved key to another path, query or endpoint',
    () async {
      final connection = await seeded();
      final original = current;
      for (final endpoint in [
        'https://other.test/v1',
        'https://example.test/v2',
        'https://example.test/v1?tenant=2',
      ]) {
        await expectLater(
          connection.save(
            current.copyWith(endpoint: endpoint),
            credentialAction: AgentCredentialAction.keep,
          ),
          error(AgentConnectionErrorCode.endpointChanged),
        );
        await expectLater(
          connection.readKeyFor(current.copyWith(endpoint: endpoint)),
          error(AgentConnectionErrorCode.credentialMissing),
        );
      }
      expect(current, original);
      expect(await connection.readKeyFor(current), 'old-key');
      await connection.save(
        current.copyWith(model: 'model-b'),
        credentialAction: AgentCredentialAction.keep,
      );
      expect(current.model, 'model-b');
      expect(current.credentialRef, original.credentialRef);
    },
  );

  test(
    'connection save preserves current feature and permission settings',
    () async {
      final connection = await seeded();
      current = current.copyWith(
        enabled: true,
        permissionMode: AgentPermissionMode.plan,
      );
      await connection.save(
        configured.copyWith(
          enabled: false,
          permissionMode: AgentPermissionMode.full,
        ),
        credentialAction: AgentCredentialAction.keep,
      );
      expect(current.enabled, isTrue);
      expect(current.permissionMode, AgentPermissionMode.plan);
    },
  );

  test(
    'pending write failure leaves old configuration and credential untouched',
    () async {
      final connection = await seeded();
      final old = current;
      final oldActive = vault.values[AgentCredentialSlot.active];
      vault.beforeWrite = (slot, value) async {
        if (slot == AgentCredentialSlot.pending) throw StateError('new-key');
      };
      await expectLater(
        connection.save(
          current,
          credentialAction: AgentCredentialAction.replace,
          rawKey: 'new-key',
        ),
        error(AgentConnectionErrorCode.storageFailure),
      );
      expect(current, old);
      expect(vault.values[AgentCredentialSlot.active], oldActive);
      expect(connection.status.needsRecovery, isTrue);
      vault.beforeWrite = null;
      await connection.initialize();
      expect(await connection.readKeyFor(current), 'old-key');
    },
  );

  test(
    'reported write error is accepted only when actual readback matches',
    () async {
      final connection = await seeded();
      vault.afterWrite = (slot, value) {
        throw StateError('backend-secret');
      };
      await connection.save(
        current,
        credentialAction: AgentCredentialAction.replace,
        rawKey: 'new-key',
      );
      expect(await connection.readKeyFor(current), 'new-key');
      expect(connection.status.needsRecovery, isFalse);
    },
  );

  for (final commitBeforeFailure in [false, true]) {
    test(
      'settings failure recovers from authoritative ${commitBeforeFailure ? 'new' : 'old'} configuration',
      () async {
        final connection = await seeded();
        final old = current;
        persist = (next) async {
          if (commitBeforeFailure) current = next;
          throw StateError('new-key');
        };
        await expectLater(
          connection.save(
            current,
            credentialAction: AgentCredentialAction.replace,
            rawKey: 'new-key',
          ),
          error(AgentConnectionErrorCode.settingsFailure),
        );
        expect(vault.values.length, 2);
        expect(vault.values[AgentCredentialSlot.active], contains('old-key'));
        expect(vault.values[AgentCredentialSlot.pending], contains('new-key'));
        await expectLater(
          connection.readKeyFor(current),
          error(AgentConnectionErrorCode.recoveryRequired),
        );
        persist = null;
        final restarted = manager();
        await restarted.initialize();
        expect(
          await restarted.readKeyFor(current),
          commitBeforeFailure ? 'new-key' : 'old-key',
        );
        expect(current == old, !commitBeforeFailure);
        expect(vault.values.keys, [AgentCredentialSlot.active]);
      },
    );
  }

  test('an uncommitted success callback is rejected instead of retiring the old key', () async {
    final connection = await seeded();
    persist = (_) async {};
    await expectLater(
      connection.save(
        current,
        credentialAction: AgentCredentialAction.replace,
        rawKey: 'new-key',
      ),
      error(AgentConnectionErrorCode.settingsFailure),
    );
    expect(vault.values[AgentCredentialSlot.active], contains('old-key'));
  });

  for (final failedSlot in AgentCredentialSlot.values) {
    test(
      'post-commit ${failedSlot.name} failure retains a recoverable new key',
      () async {
        final connection = await seeded();
        vault.beforeWrite = (slot, value) async {
          if (slot == failedSlot &&
              (slot == AgentCredentialSlot.active || value == null)) {
            throw StateError('backend-secret');
          }
        };
        await expectLater(
          connection.save(
            current,
            credentialAction: AgentCredentialAction.replace,
            rawKey: 'new-key',
          ),
          error(AgentConnectionErrorCode.storageFailure),
        );
        expect(current.credentialRef, 'credential-2');
        expect(vault.values[AgentCredentialSlot.pending], contains('new-key'));
        vault.beforeWrite = null;
        final restarted = manager();
        await restarted.initialize();
        expect(await restarted.readKeyFor(current), 'new-key');
        expect(vault.values.keys, [AgentCredentialSlot.active]);
      },
    );
  }

  test('pending readback failure preserves old and candidate slots without leaking errors', () async {
    final connection = await seeded();
    var written = false;
    vault.afterWrite = (slot, value) {
      if (slot == AgentCredentialSlot.pending) written = true;
    };
    vault.beforeRead = (slot) {
      if (written && slot == AgentCredentialSlot.pending) {
        throw StateError('new-key');
      }
    };
    try {
      await connection.save(
        current,
        credentialAction: AgentCredentialAction.replace,
        rawKey: 'new-key',
      );
      fail('Expected failure');
    } on AgentConnectionException catch (e) {
      expect(e.toString(), isNot(contains('new-key')));
    }
    expect(vault.values.length, 2);
    expect(current.credentialRef, 'credential-1');
  });

  test('legacy migration copies only connection fields then retires through the injected callback', () async {
    legacy = const AiApiSettings(
      customBaseUrl: 'https://EXAMPLE.test:443/v1/',
      customModel: 'legacy-model',
      customPrompt: 'Untrusted old prompt',
      customApiKey: 'overlay-key-is-not-source',
    );
    legacySecrets.key = 'stored-legacy-key';
    var overlayCleared = false;
    retire = () async {
      expect(current.endpoint, 'https://example.test/v1');
      expect(
        vault.values[AgentCredentialSlot.active],
        contains('stored-legacy-key'),
      );
      await legacySecrets.writeCustomSchoolImportApiKey('');
      overlayCleared = true;
    };
    final connection = manager();
    final status = await connection.initialize();
    expect(current.enabled, isTrue);
    expect(current.permissionMode, AgentPermissionMode.ask);
    expect(current.model, 'legacy-model');
    expect(await connection.readKeyFor(current), 'stored-legacy-key');
    expect(legacy.customPrompt, 'Untrusted old prompt');
    expect(vault.values.values.join(), isNot(contains('Untrusted old prompt')));
    expect(legacySecrets.key, isEmpty);
    expect(overlayCleared, isTrue);
    expect(
      status.migrationStatus,
      AgentLegacyMigrationStatus.credentialMigrated,
    );
  });

  test('failed legacy retirement retries without replacing the migrated connection again', () async {
    legacy = const AiApiSettings(
      customBaseUrl: 'https://example.test/v1',
      customModel: 'legacy-model',
    );
    legacySecrets.key = 'legacy-key';
    legacySecrets.failWrite = true;
    final connection = manager();
    await expectLater(
      connection.initialize(),
      error(AgentConnectionErrorCode.legacyFailure),
    );
    final migrated = current;
    expect(legacySecrets.key, 'legacy-key');
    expect(vault.values[AgentCredentialSlot.active], contains('legacy-key'));
    legacySecrets.failWrite = false;
    final restarted = manager();
    await restarted.initialize();
    expect(current, migrated);
    expect(commits, 1);
    expect(legacySecrets.key, isEmpty);
  });

  test('new configuration is never overwritten and clearing it does not reintroduce legacy fields', () async {
    current = configured;
    legacy = const AiApiSettings(
      customBaseUrl: 'https://old.test',
      customModel: 'old',
    );
    legacySecrets.key = 'old-key';
    final connection = manager();
    await connection.initialize();
    expect(current, configured);
    expect(legacySecrets.reads, 0);
    await connection.save(
      const AgentSettings(),
      credentialAction: AgentCredentialAction.clear,
    );
    await manager().initialize();
    expect(current.endpoint, isEmpty);
    expect(current.model, isEmpty);
    expect(legacySecrets.key, 'old-key');
  });

  test('Web memory migration returns connection-only status and keeps the durable legacy key', () async {
    vault = Vault(storageKind: AgentCredentialStorageKind.memoryOnly);
    legacy = const AiApiSettings(
      customBaseUrl: 'https://old.test',
      customModel: 'old',
    );
    legacySecrets.key = 'durable-legacy-key';
    final connection = manager();
    final status = await connection.initialize();
    expect(current.endpoint, 'https://old.test/');
    expect(current.credentialRef, isNull);
    expect(status.storageKind, AgentCredentialStorageKind.memoryOnly);
    expect(
      status.migrationStatus,
      AgentLegacyMigrationStatus.connectionOnlyMemory,
    );
    expect(status.legacyCredentialRetained, isTrue);
    expect(legacySecrets.key, 'durable-legacy-key');
    expect(legacySecrets.clears, 0);
  });

  test('missing ephemeral credentials require replacement rather than borrowing a legacy key', () async {
    current = configured.copyWith(credentialRef: 'lost-reference');
    legacySecrets.key = 'unrelated-old-key';
    final connection = manager();
    final status = await connection.initialize();
    expect(status.credentialAvailable, isFalse);
    await expectLater(
      connection.readKeyFor(current),
      error(AgentConnectionErrorCode.credentialMissing),
    );
    await connection.save(
      current,
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'replacement',
    );
    expect(await connection.readKeyFor(current), 'replacement');
    expect(legacySecrets.reads, 0);
  });

  test('clear does not delete secrets until the credential reference is durably removed', () async {
    final connection = await seeded();
    persist = (_) async {
      throw StateError('write failed');
    };
    await expectLater(
      connection.clearAll(),
      error(AgentConnectionErrorCode.settingsFailure),
    );
    expect(vault.values[AgentCredentialSlot.active], contains('old-key'));
    persist = null;
    await connection.clearAll();
    expect(current.credentialRef, isNull);
    expect(vault.values, isEmpty);
  });

  test(
    'freeze cancels pending admission and clear waits out the owned queue',
    () async {
      final connection = await seeded();
      final gate = Completer<void>();
      final started = Completer<void>();
      vault.beforeWrite = (slot, value) async {
        if (slot == AgentCredentialSlot.pending && value != null) {
          started.complete();
          await gate.future;
        }
      };
      final saving = connection.save(
        current,
        credentialAction: AgentCredentialAction.replace,
        rawKey: 'late-key',
      );
      final rejected = expectLater(
        saving,
        error(AgentConnectionErrorCode.frozen),
      );
      await started.future;
      connection.freeze();
      final clearing = connection.clearAll();
      gate.complete();
      await rejected;
      await clearing;
      await connection.waitForPendingWrites();
      expect(vault.values, isEmpty);
      expect(current.credentialRef, isNull);
      await expectLater(
        connection.save(
          configured,
          credentialAction: AgentCredentialAction.clear,
        ),
        error(AgentConnectionErrorCode.frozen),
      );
    },
  );

  test('invalid legacy configuration preserves old credentials and allows manual connection setup', () async {
    legacy = const AiApiSettings(
      customBaseUrl: 'not-an-endpoint',
      customModel: 'old-model',
    );
    legacySecrets.key = 'old-key';
    final connection = manager();
    final status = await connection.initialize();
    expect(
      status.migrationStatus,
      AgentLegacyMigrationStatus.invalidLegacyConfiguration,
    );
    expect(status.initialized, isTrue);
    expect(current, const AgentSettings());
    expect(legacySecrets.key, 'old-key');
    await connection.save(
      configured,
      credentialAction: AgentCredentialAction.replace,
      rawKey: 'manual-key',
    );
    expect(await connection.readKeyFor(current), 'manual-key');
  });

  test(
    'a newer legacy credential is preserved instead of retiring the wrong key',
    () async {
      legacy = const AiApiSettings(
        customBaseUrl: 'https://example.test/v1',
        customModel: 'old',
      );
      legacySecrets.key = 'old-key';
      persist = (next) async {
        current = next;
        legacySecrets.key = 'newer-parser-key';
      };
      final connection = manager();
      final status = await connection.initialize();
      expect(await connection.readKeyFor(current), 'old-key');
      expect(legacySecrets.key, 'newer-parser-key');
      expect(
        status.migrationStatus,
        AgentLegacyMigrationStatus.changedLegacyCredentialRetained,
      );
      expect(status.legacyCredentialRetained, isTrue);
    },
  );

  test(
    'callbacks cannot leak their exception text through manager APIs',
    () async {
      final connection = AgentConnectionManager(
        store: vault,
        readSettings: () => throw StateError('secret-in-callback'),
        persistSettings: (_) async {},
      );
      try {
        await connection.initialize();
        fail('Expected failure');
      } on AgentConnectionException catch (e) {
        expect(e.toString(), isNot(contains('secret-in-callback')));
      }
    },
  );

  test('reusing the current reference for a replacement is rejected before staging', () async {
    await seeded();
    final connection = AgentConnectionManager(
      store: vault,
      readSettings: () => current,
      persistSettings: (next) async => current = next,
      referenceGenerator: () => current.credentialRef!,
    );
    await connection.initialize();
    await expectLater(
      connection.save(
        current,
        credentialAction: AgentCredentialAction.replace,
        rawKey: 'new-key',
      ),
      error(AgentConnectionErrorCode.invalidConfiguration),
    );
    expect(vault.values.keys, [AgentCredentialSlot.active]);
    expect(await connection.readKeyFor(current), 'old-key');
  });

  test('memory-only stores discard credentials with their instance', () async {
    final store = MemoryAgentCredentialStore();
    await store.write(AgentCredentialSlot.active, 'transient-test-value');
    expect(store.kind, AgentCredentialStorageKind.memoryOnly);
    expect(
      await store.read(AgentCredentialSlot.active),
      'transient-test-value',
    );
    expect(
      await MemoryAgentCredentialStore().read(AgentCredentialSlot.active),
      isNull,
    );
  });

  for (final futureSlot in AgentCredentialSlot.values) {
    test(
      'a future ${futureSlot.name} credential blocks reconciliation beside a valid slot',
      () async {
        await seeded();
        final valid = vault.values[AgentCredentialSlot.active]!;
        final future = jsonDecode(valid) as Map<String, dynamic>;
        future['version'] = (future['version'] as int) + 1;
        for (final slot in AgentCredentialSlot.values) {
          vault.values[slot] = slot == futureSlot ? jsonEncode(future) : valid;
        }
        legacy = const AiApiSettings(
          customBaseUrl: 'https://legacy.example.test/v1',
          customModel: 'legacy-model',
        );
        legacySecrets.key = 'retained-legacy-key';
        final beforeSlots = Map<AgentCredentialSlot, String>.from(vault.values);
        final beforeSettings = current.toJson();
        final beforeLegacy = legacy.toJson();
        final beforeCommits = commits;
        final beforeLegacyReads = legacySecrets.reads;
        vault.events.clear();

        final connection = manager();
        await expectLater(
          connection.initialize(),
          error(AgentConnectionErrorCode.storageFailure),
        );
        expect(connection.status.initialized, isFalse);
        expect(connection.status.needsRecovery, isTrue);
        expect(connection.status.credentialAvailable, isFalse);
        await expectLater(
          connection.readKeyFor(current),
          error(AgentConnectionErrorCode.recoveryRequired),
        );
        await expectLater(
          connection.save(
            configured,
            credentialAction: AgentCredentialAction.replace,
            rawKey: 'must-not-replace-either-slot',
          ),
          error(AgentConnectionErrorCode.recoveryRequired),
        );
        await expectLater(
          connection.initialize(migrateLegacy: false),
          error(AgentConnectionErrorCode.storageFailure),
        );
        await connection.waitForPendingWrites();

        expect(vault.values, beforeSlots);
        expect(
          vault.events.where((event) => event.startsWith('write:')),
          isEmpty,
        );
        expect(current.toJson(), beforeSettings);
        expect(commits, beforeCommits);
        expect(legacy.toJson(), beforeLegacy);
        expect(legacySecrets.key, 'retained-legacy-key');
        expect(legacySecrets.reads, beforeLegacyReads);
        expect(legacySecrets.clears, 0);
      },
    );
  }

  test(
    'corrupt secure records stay untouched and report only a sanitized failure',
    () async {
      vault.values[AgentCredentialSlot.active] = '{bad-key-data';
      final connection = manager();
      await expectLater(
        connection.initialize(),
        error(AgentConnectionErrorCode.storageFailure),
      );
      expect(vault.values[AgentCredentialSlot.active], '{bad-key-data');
      expect(current, const AgentSettings());
    },
  );
}
