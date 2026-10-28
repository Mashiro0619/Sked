import 'package:sked/services/agenda_notification_contract.dart';
import 'package:sked/services/agenda_notification_identity.dart';

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
