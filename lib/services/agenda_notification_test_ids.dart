import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'agenda_notification_contract.dart';
import 'agenda_notification_identity.dart';

/// Deterministic allocator used by in-memory gateways and tests.
class MemoryAgendaNotificationTestIdAllocator
    implements AgendaNotificationTestIdAllocator {
  MemoryAgendaNotificationTestIdAllocator({int? nextId})
    : _nextId = nextId ?? developerNotificationIdStart;

  int _nextId;

  @override
  Future<int> allocate({required Set<int> occupiedIds}) async {
    var candidate = _nextId;
    for (
      var offset = 0;
      offset <= developerNotificationIdEnd - developerNotificationIdStart;
      offset++
    ) {
      if (!occupiedIds.contains(candidate)) {
        _nextId = nextDeveloperNotificationId(candidate);
        return candidate;
      }
      candidate = nextDeveloperNotificationId(candidate);
    }
    throw StateError('No developer notification test IDs are available.');
  }
}

/// SharedPreferences-backed developer-test ID allocator.
///
/// The cursor is advanced before the ID is returned.  If scheduling is
/// interrupted, that ID is intentionally skipped rather than reused on the
/// next process launch, which prevents a stale visible notification from being
/// replaced after a crash.  A random first cursor also avoids colliding with
/// the two fixed IDs used by pre-2.2.0 builds when their active notification
/// list is temporarily unavailable on an OEM device.
class SharedPreferencesAgendaNotificationTestIdAllocator
    implements AgendaNotificationTestIdAllocator {
  SharedPreferencesAgendaNotificationTestIdAllocator({
    Future<SharedPreferences> Function()? preferencesProvider,
    math.Random? random,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _random = random ?? math.Random.secure();

  static const storageKey =
      'sked.notification.runtime.developer_test_next_id.v1';

  // A static tail serializes allocators created by multiple gateway instances
  // in the same isolate.  The persisted/random cursor still protects the
  // process-restart case where no Dart object survives.
  static Future<void> _allocationTail = Future<void>.value();

  final Future<SharedPreferences> Function() _preferencesProvider;
  final math.Random _random;

  @override
  Future<int> allocate({required Set<int> occupiedIds}) {
    final occupied = Set<int>.of(occupiedIds);
    final previous = _allocationTail;
    final operation = previous.then<int>(
      (_) => _allocate(occupied),
      onError: (_, _) => _allocate(occupied),
    );
    _allocationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<int> _allocate(Set<int> occupiedIds) async {
    var candidate = _randomCandidate();
    try {
      final preferences = await _preferencesProvider();
      final stored = preferences.getInt(storageKey);
      if (stored != null && isDeveloperNotificationId(stored)) {
        candidate = stored;
      }
      for (
        var offset = 0;
        offset <= developerNotificationIdEnd - developerNotificationIdStart;
        offset++
      ) {
        if (!occupiedIds.contains(candidate)) {
          final next = nextDeveloperNotificationId(candidate);
          // A false result is unusual; the current process still has a unique
          // ID, while the next launch will use a fresh random cursor if this
          // runtime-only write was rejected by the platform.
          if (!await preferences.setInt(storageKey, next)) {
            // Do not treat an unpersisted cursor as durable. Fall through to
            // the random in-process fallback so a later process cannot reuse
            // this ID after a failed SharedPreferences write.
            throw StateError('Developer notification ID cursor was not saved.');
          }
          return candidate;
        }
        candidate = nextDeveloperNotificationId(candidate);
      }
    } catch (_) {
      // Diagnostics should remain usable if SharedPreferences is temporarily
      // unavailable (for example while Android is restoring application data).
      // The random fallback is still safe against ordinary ID reuse.
    }

    // If the persistent store could not be read, allocate from a fresh random
    // point and probe the IDs reserved for developer diagnostics.  The local
    // gateway also tracks its returned IDs, so rapid taps remain distinct.
    candidate = _randomCandidate();
    for (
      var offset = 0;
      offset <= developerNotificationIdEnd - developerNotificationIdStart;
      offset++
    ) {
      if (!occupiedIds.contains(candidate)) return candidate;
      candidate = nextDeveloperNotificationId(candidate);
    }
    throw StateError('No developer notification test IDs are available.');
  }

  int _randomCandidate() =>
      developerNotificationIdStart +
      _random.nextInt(
        developerNotificationIdEnd - developerNotificationIdStart + 1,
      );
}
