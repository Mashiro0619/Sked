import 'package:flutter/foundation.dart';

import 'agent_ui_contribution_contracts.dart';

typedef _EntryKey = (AgentUiContributionLifetime, String, String);

/// One application's native and configuration inventories. Replacing a native
/// core does not remove the profile's settings destinations.
class AgentUiContributionRegistry extends ChangeNotifier {
  final _entries = <_EntryKey, AgentUiContributionEntry>{};
  Object? _nativeSession;
  int _nativeRevision = -1;
  bool _disposed = false;

  Object? get nativeSession => _nativeSession;
  int? get nativeRevision => _nativeRevision < 0 ? null : _nativeRevision;

  List<AgentUiContributionEntry> entries(AgentUiContributionSlot slot) {
    final result =
        _entries.values
            .where((entry) => entry.contribution.slot == slot)
            .toList()
          ..sort((a, b) {
            final order = a.contribution.order.compareTo(b.contribution.order);
            if (order != 0) return order;
            final lifetime = a.owner.lifetime.index.compareTo(
              b.owner.lifetime.index,
            );
            if (lifetime != 0) return lifetime;
            final owner = a.owner.instanceId.compareTo(b.owner.instanceId);
            return owner != 0
                ? owner
                : a.contribution.id.compareTo(b.contribution.id);
          });
    return List.unmodifiable(result);
  }

  /// Called by the core owner at open/retirement, before accepting snapshots.
  void beginNativeSession(Object? token) {
    if (_disposed || identical(token, _nativeSession)) return;
    _nativeSession = token;
    _nativeRevision = -1;
    _entries.removeWhere(
      (key, _) => key.$1 == AgentUiContributionLifetime.native,
    );
    notifyListeners();
  }

  bool applyNativeSnapshot(
    Object sessionToken,
    AgentUiContributionSnapshot snapshot,
  ) {
    if (_disposed || !identical(sessionToken, _nativeSession)) return false;
    if (snapshot.contractVersion != agentUiContributionContractVersion) {
      throw ArgumentError.value(snapshot.contractVersion, 'contractVersion');
    }
    if (snapshot.revision < 0) {
      throw ArgumentError.value(snapshot.revision, 'revision');
    }
    if (snapshot.revision <= _nativeRevision) return false;
    final next = <_EntryKey, AgentUiContributionEntry>{};
    final owners = <String>{};
    for (final snapshotOwner in snapshot.owners) {
      if (!owners.add(snapshotOwner.instanceId)) {
        throw ArgumentError('Duplicate UI contribution owner.');
      }
      final owner = AgentUiContributionOwner(
        lifetime: AgentUiContributionLifetime.native,
        sessionToken: sessionToken,
        instanceId: snapshotOwner.instanceId,
        generation: snapshotOwner.generation,
      );
      _addOwner(next, owner, snapshotOwner.contributions);
    }
    // Validate the full inventory before retiring any previous entry.
    _entries.removeWhere(
      (key, _) => key.$1 == AgentUiContributionLifetime.native,
    );
    _entries.addAll(next);
    _nativeRevision = snapshot.revision;
    notifyListeners();
    return true;
  }

  void replaceProfileOwner(
    AgentUiContributionOwner owner,
    Iterable<AgentUiContribution> contributions,
  ) {
    if (_disposed) return;
    if (owner.lifetime != AgentUiContributionLifetime.profile) {
      throw ArgumentError(
        'Configuration contributions require a profile owner.',
      );
    }
    final next = <_EntryKey, AgentUiContributionEntry>{};
    _addOwner(next, owner, contributions);
    _entries.removeWhere(
      (key, _) => key.$1 == owner.lifetime && key.$2 == owner.instanceId,
    );
    _entries.addAll(next);
    notifyListeners();
  }

  /// An old owner's cleanup cannot withdraw a replacement generation.
  void removeProfileOwner(AgentUiContributionOwner owner) {
    if (_disposed || owner.lifetime != AgentUiContributionLifetime.profile) {
      return;
    }
    final before = _entries.length;
    _entries.removeWhere((_, entry) => entry.owner.sameOwner(owner));
    if (_entries.length != before) notifyListeners();
  }

  void _addOwner(
    Map<_EntryKey, AgentUiContributionEntry> target,
    AgentUiContributionOwner owner,
    Iterable<AgentUiContribution> contributions,
  ) {
    if (owner.instanceId.isEmpty || owner.generation < 0) {
      throw ArgumentError('Invalid UI contribution owner.');
    }
    for (final contribution in contributions) {
      if (contribution.id.isEmpty || contribution.rendererId.isEmpty) {
        throw ArgumentError('Invalid UI contribution declaration.');
      }
      final key = (owner.lifetime, owner.instanceId, contribution.id);
      if (target.containsKey(key)) {
        throw ArgumentError('Duplicate UI contribution ID in one owner.');
      }
      final previous = _entries[key];
      target[key] =
          previous != null &&
              previous.owner.sameOwner(owner) &&
              previous.contribution == contribution
          ? previous
          : AgentUiContributionEntry._(this, key, owner, contribution);
    }
  }

  bool _contains(AgentUiContributionEntry entry) =>
      !_disposed && identical(_entries[entry._key], entry);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _nativeSession = null;
    _entries.clear();
    notifyListeners();
    super.dispose();
  }
}

@immutable
class AgentUiContributionEntry {
  const AgentUiContributionEntry._(
    this._registry,
    this._key,
    this.owner,
    this.contribution,
  );

  final AgentUiContributionRegistry _registry;
  final _EntryKey _key;
  final AgentUiContributionOwner owner;
  final AgentUiContribution contribution;

  bool get isCurrent => _registry._contains(this);
  AgentUiContributionLease lease() => AgentUiContributionLease._(this);
}

/// Revocation is latched. The lease gates new UI actions and source feedback;
/// it never cancels a save already accepted by the operation's own service.
class AgentUiContributionLease extends ChangeNotifier {
  AgentUiContributionLease._(this.entry) {
    _current = entry.isCurrent;
    if (_current) {
      entry._registry.addListener(_check);
      _listening = true;
    }
  }

  final AgentUiContributionEntry entry;
  late bool _current;
  bool _listening = false;
  bool _disposed = false;

  bool get isCurrent {
    if (_disposed || !_current) return false;
    if (!entry.isCurrent) _retire();
    return _current;
  }

  void _check() {
    if (!entry.isCurrent) _retire();
  }

  void _retire() {
    if (!_current) return;
    _current = false;
    if (_listening) {
      _listening = false;
      entry._registry.removeListener(_check);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _retire();
    _disposed = true;
    super.dispose();
  }
}
