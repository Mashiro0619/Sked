import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AgentCredentialSlot { active, pending }

enum AgentCredentialStorageKind { platformSecureStorage, memoryOnly }

/// A separate namespace from the retired parser credential. No enumeration or
/// unbounded per-reference key creation is needed: this store has two slots.
abstract class AgentCredentialStore {
  AgentCredentialStore.base();

  factory AgentCredentialStore() =>
      kIsWeb ? MemoryAgentCredentialStore() : SecureAgentCredentialStore();

  AgentCredentialStorageKind get kind;
  Future<String?> read(AgentCredentialSlot slot);
  Future<void> write(AgentCredentialSlot slot, String? value);
}

class SecureAgentCredentialStore extends AgentCredentialStore {
  SecureAgentCredentialStore({
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(migrateWithBackup: true),
    ),
  }) : super.base();

  final FlutterSecureStorage _storage;

  static String keyForSlot(AgentCredentialSlot slot) =>
      'sked.agent.credential.${slot.name}.v1';

  @override
  AgentCredentialStorageKind get kind =>
      AgentCredentialStorageKind.platformSecureStorage;

  @override
  Future<String?> read(AgentCredentialSlot slot) =>
      _storage.read(key: keyForSlot(slot));

  @override
  Future<void> write(AgentCredentialSlot slot, String? value) => value == null
      ? _storage.delete(key: keyForSlot(slot))
      : _storage.write(key: keyForSlot(slot), value: value);
}

/// The Web fallback is intentionally session memory, not an OS keyring or a
/// claim of persistent browser security. Reloading discards these credentials.
class MemoryAgentCredentialStore extends AgentCredentialStore {
  MemoryAgentCredentialStore() : super.base();
  final _values = <AgentCredentialSlot, String>{};

  @override
  AgentCredentialStorageKind get kind => AgentCredentialStorageKind.memoryOnly;
  @override
  Future<String?> read(AgentCredentialSlot slot) async => _values[slot];
  @override
  Future<void> write(AgentCredentialSlot slot, String? value) async {
    if (value == null) {
      _values.remove(slot);
    } else {
      _values[slot] = value;
    }
  }
}
