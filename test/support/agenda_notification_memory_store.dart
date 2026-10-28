import 'package:sked/services/agenda_notification_identity.dart';
import 'package:sked/services/agenda_notification_runtime_contract.dart';

/// In-memory runtime state for tests and isolated benchmark/preview hosts.
class MemoryAgendaNotificationRuntimeStore
    implements
        AgendaNotificationRuntimeStore,
        AgendaNotificationActionStore,
        AgendaNotificationBackgroundRequestStore,
        AgendaNotificationBackgroundRequestIndex,
        AgendaNotificationDiagnosticsStore,
        AgendaNotificationProjectionFenceStore,
        AgendaNotificationFencedRuntimeStore,
        AgendaNotificationRegistrationStore {
  MemoryAgendaNotificationRuntimeStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<int, Map<String, DateTime>> _snoozesByGeneration = {};
  final Map<int, Set<String>> _handledOccurrenceIdsByGeneration = {};
  final Map<int, Map<String, DateTime>> _handledAtByGeneration = {};
  final Map<int, List<AgendaNotificationAction>> _pendingActionsByGeneration =
      {};
  final Map<int, Map<String, AgendaNotificationBackgroundRequest>>
  _backgroundRequestsByGeneration = {};
  final Map<int, Map<String, AgendaNotificationRegistration>> _registrations =
      {};
  final Map<int, Map<String, AgendaNotificationSnoozeReceipt>> _snoozeReceipts =
      {};
  final Map<int, DateTime> _registrationEpochs = {};
  AgendaNotificationDiagnostics? diagnostics;
  AgendaNotificationProjectionFence projectionFence =
      AgendaNotificationProjectionFence.initial;

  static const maxHandledOccurrences = 256;
  static const handledTtl = Duration(days: 30);
  static const maxPendingActions = 32;
  static const pendingActionTtl = Duration(hours: 24);
  static const backgroundRequestTtl = Duration(days: 2);

  /// Exposed test state for the active generation. Production callers should
  /// use the runtime-store methods so a blocked clear fence is respected.
  Map<String, DateTime> get snoozes => _snoozesFor(projectionFence.generation);
  Set<String> get handledOccurrenceIds =>
      _handledOccurrenceIdsFor(projectionFence.generation);
  List<AgendaNotificationAction> get pendingActions =>
      _pendingActionsFor(projectionFence.generation);
  Map<String, AgendaNotificationBackgroundRequest> get backgroundRequests =>
      _backgroundRequestsFor(projectionFence.generation);

  int? get _activeGeneration =>
      projectionFence.blocked ? null : projectionFence.generation;

  @override
  Future<Map<String, DateTime>> readSnoozes() async {
    final generation = _activeGeneration;
    if (generation == null) return const {};
    return Map.unmodifiable(_snoozesFor(generation));
  }

  @override
  Future<Set<String>> readHandledOccurrenceIds() async {
    final generation = _activeGeneration;
    if (generation == null) return const {};
    final handled = _handledOccurrenceIdsFor(generation);
    final handledAt = _handledAtFor(generation);
    final now = _clock();
    final expired = handledAt.entries
        .where((entry) => now.difference(entry.value) > handledTtl)
        .map((entry) => entry.key)
        .toList();
    for (final id in expired) {
      handledAt.remove(id);
      handled.remove(id);
    }
    _trimHandled(generation);
    return Set.unmodifiable(handled);
  }

  @override
  Future<List<AgendaNotificationAction>> readPendingActions() async {
    final generation = _activeGeneration;
    if (generation == null) return const [];
    final actions = _pendingActionsFor(generation);
    final now = _clock();
    actions.removeWhere(
      (action) =>
          now.difference(action.enqueuedAt) > pendingActionTtl ||
          action.enqueuedAt.isAfter(now.add(const Duration(minutes: 5))),
    );
    actions.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    if (actions.length > maxPendingActions) {
      actions.removeRange(0, actions.length - maxPendingActions);
    }
    return List.unmodifiable(actions);
  }

  @override
  Future<void> setSnooze(String key, DateTime fireAt) async {
    final fence = await captureWritableRuntimeFence();
    if (fence == null) return;
    await setSnoozeForRuntimeFence(key, fireAt, fence);
  }

  @override
  Future<void> removeSnooze(String key) async {
    final generation = _activeGeneration;
    if (generation == null) return;
    _snoozesFor(generation).remove(key);
  }

  @override
  Future<void> addHandledOccurrence(String occurrenceId) async {
    if (occurrenceId.trim().isEmpty) return;
    final fence = await captureWritableRuntimeFence();
    if (fence == null) return;
    await addHandledOccurrenceForRuntimeFence(occurrenceId, fence);
  }

  @override
  Future<void> removeHandledOccurrence(String occurrenceId) async {
    final generation = _activeGeneration;
    if (generation == null) return;
    _handledOccurrenceIdsFor(generation).remove(occurrenceId);
    _handledAtFor(generation).remove(occurrenceId);
  }

  @override
  Future<void> enqueueAction({
    required String payload,
    required String actionId,
  }) async {
    if (payload.isEmpty ||
        payload.length > AgendaNotificationAction.maxPayloadLength ||
        actionId.isEmpty ||
        actionId.length > AgendaNotificationAction.maxActionIdLength) {
      return;
    }
    final fence = await captureWritableRuntimeFence();
    if (fence == null) return;
    await enqueueActionForRuntimeFence(
      payload: payload,
      actionId: actionId,
      fence: fence,
    );
  }

  @override
  Future<void> removePendingAction(String id) async {
    final generation = _activeGeneration;
    if (generation == null) return;
    _pendingActionsFor(generation).removeWhere((item) => item.id == id);
  }

  @override
  Future<AgendaNotificationBackgroundRequest?> readBackgroundRequest(
    String key,
  ) async {
    final fence = await captureWritableRuntimeFence();
    if (fence == null) return null;
    return readBackgroundRequestForRuntimeFence(key, fence);
  }

  @override
  Future<void> saveBackgroundRequest(
    AgendaNotificationBackgroundRequest request,
  ) async {
    if (AgendaNotificationBackgroundRequest.tryDecode(request.toJson()) ==
        null) {
      return;
    }
    final fence = await captureWritableRuntimeFence();
    if (fence == null) return;
    await saveBackgroundRequestForRuntimeFence(request, fence);
  }

  @override
  Future<void> removeBackgroundRequest(String key) async {
    final generation = _activeGeneration;
    if (generation == null) return;
    _backgroundRequestsFor(generation).remove(key);
  }

  @override
  Future<void> pruneBackgroundRequests({required DateTime now}) async {
    final generation = _activeGeneration;
    if (generation == null) return;
    _backgroundRequestsFor(generation).removeWhere(
      (_, request) => now.difference(request.fireAt) > backgroundRequestTtl,
    );
  }

  @override
  Future<Set<String>> backgroundRequestKeys() async {
    final generation = _activeGeneration;
    if (generation == null) return const {};
    return Set.unmodifiable(_backgroundRequestsFor(generation).keys);
  }

  @override
  Future<AgendaNotificationBackgroundRequest?>
  readBackgroundRequestForOwnership(String key) async {
    final generation = _activeGeneration;
    if (generation == null || key.trim().isEmpty) return null;
    return _backgroundRequestsFor(generation)[key];
  }

  @override
  Future<AgendaNotificationDiagnostics?> readNotificationDiagnostics() async =>
      diagnostics;

  @override
  Future<void> writeNotificationDiagnostics(
    AgendaNotificationDiagnostics value,
  ) async {
    diagnostics = value;
  }

  @override
  Future<AgendaNotificationProjectionFence> readProjectionFence() async =>
      projectionFence;

  @override
  Future<AgendaNotificationProjectionFence>
  blockProjectionForDataClear() async {
    projectionFence = AgendaNotificationProjectionFence(
      generation: nextAgendaNotificationGeneration(projectionFence.generation),
      blocked: true,
    );
    return projectionFence;
  }

  @override
  Future<AgendaNotificationProjectionFence>
  activateProjectionAfterDurableData() async {
    if (!projectionFence.blocked) return projectionFence;
    projectionFence = AgendaNotificationProjectionFence(
      generation: nextAgendaNotificationGeneration(projectionFence.generation),
      blocked: false,
    );
    return projectionFence;
  }

  @override
  Future<void> clear() async {
    _snoozesByGeneration.clear();
    _handledOccurrenceIdsByGeneration.clear();
    _handledAtByGeneration.clear();
    _pendingActionsByGeneration.clear();
    _backgroundRequestsByGeneration.clear();
    diagnostics = null;
  }

  @override
  Future<AgendaNotificationProjectionFence?>
  captureWritableRuntimeFence() async {
    return projectionFence.blocked ? null : projectionFence;
  }

  @override
  Future<bool> isRuntimeFenceCurrent(
    AgendaNotificationProjectionFence fence,
  ) async => !projectionFence.blocked && projectionFence.matches(fence);

  @override
  Future<void> setSnoozeForRuntimeFence(
    String key,
    DateTime fireAt,
    AgendaNotificationProjectionFence fence,
  ) async {
    // A background isolate may hold a token captured immediately before a
    // foreground clear advances the generation.  Checking only `blocked`
    // would let that late write recreate an old generation record after the
    // clear cleanup has completed.
    if (fence.blocked || !projectionFence.matches(fence)) return;
    _snoozesFor(fence.generation)[key] = fireAt;
  }

  @override
  Future<void> addHandledOccurrenceForRuntimeFence(
    String occurrenceId,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked ||
        !projectionFence.matches(fence) ||
        occurrenceId.trim().isEmpty) {
      return;
    }
    final handled = _handledOccurrenceIdsFor(fence.generation);
    final handledAt = _handledAtFor(fence.generation);
    final now = _clock();
    final expired = handledAt.entries
        .where((entry) => now.difference(entry.value) > handledTtl)
        .map((entry) => entry.key)
        .toList();
    for (final id in expired) {
      handledAt.remove(id);
      handled.remove(id);
    }
    handled.add(occurrenceId);
    handledAt[occurrenceId] = now;
    _trimHandled(fence.generation);
  }

  @override
  Future<void> enqueueActionForRuntimeFence({
    required String payload,
    required String actionId,
    required AgendaNotificationProjectionFence fence,
  }) async {
    if (fence.blocked ||
        !projectionFence.matches(fence) ||
        payload.isEmpty ||
        payload.length > AgendaNotificationAction.maxPayloadLength ||
        actionId.isEmpty ||
        actionId.length > AgendaNotificationAction.maxActionIdLength) {
      return;
    }
    final actions = _pendingActionsFor(fence.generation);
    final id = runtimeNotificationActionId(payload, actionId);
    if (actions.any(
      (item) =>
          item.id == id ||
          (item.payload == payload && item.actionId == actionId),
    )) {
      return;
    }
    actions.add(
      AgendaNotificationAction(
        id: id,
        payload: payload,
        actionId: actionId,
        enqueuedAt: _clock(),
      ),
    );
    actions.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    if (actions.length > maxPendingActions) {
      actions.removeRange(0, actions.length - maxPendingActions);
    }
  }

  @override
  Future<AgendaNotificationBackgroundRequest?>
  readBackgroundRequestForRuntimeFence(
    String key,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked || !projectionFence.matches(fence)) return null;
    return _backgroundRequestsFor(fence.generation)[key];
  }

  @override
  Future<void> saveBackgroundRequestForRuntimeFence(
    AgendaNotificationBackgroundRequest request,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked ||
        !projectionFence.matches(fence) ||
        AgendaNotificationBackgroundRequest.tryDecode(request.toJson()) ==
            null) {
      return;
    }
    _backgroundRequestsFor(fence.generation)[request.key] = request;
  }

  @override
  Future<AgendaNotificationRegistrationSnapshot> readRegistrationSnapshot(
    AgendaNotificationProjectionFence fence, {
    required DateTime now,
  }) async {
    if (fence.blocked || !projectionFence.matches(fence)) {
      return const AgendaNotificationRegistrationSnapshot();
    }
    _registrations.removeWhere(
      (generation, _) => generation != fence.generation,
    );
    _snoozeReceipts.removeWhere(
      (generation, _) => generation != fence.generation,
    );
    _registrationEpochs.removeWhere(
      (generation, _) => generation != fence.generation,
    );
    final records = _registrations.putIfAbsent(fence.generation, () => {});
    final actions = _snoozeReceipts.putIfAbsent(fence.generation, () => {});
    records.removeWhere((_, record) => now.isAfter(record.expiresAt));
    actions.removeWhere((_, receipt) => now.isAfter(receipt.expiresAt));
    return AgendaNotificationRegistrationSnapshot(
      initializedAt: _registrationEpochs[fence.generation],
      records: Map.unmodifiable(records),
      snoozeReceipts: Map.unmodifiable(actions),
    );
  }

  @override
  Future<bool> initializeRegistrationEpoch(
    DateTime at,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked || !projectionFence.matches(fence)) return false;
    _registrationEpochs.putIfAbsent(fence.generation, () => at.toUtc());
    return true;
  }

  @override
  Future<bool> writeRegistration(
    AgendaNotificationRegistration registration,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked || !projectionFence.matches(fence)) return false;
    final valid = AgendaNotificationRegistration.tryDecode(
      registration.toJson(),
    );
    if (valid == null) {
      throw const FormatException('Invalid notification registration');
    }
    _registrations.putIfAbsent(fence.generation, () => {})[valid.identity] =
        valid;
    return true;
  }

  @override
  Future<bool> writeSnoozeReceipt(
    AgendaNotificationSnoozeReceipt receipt,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked || !projectionFence.matches(fence)) return false;
    final valid = AgendaNotificationSnoozeReceipt.tryDecode(receipt.toJson());
    if (valid == null) throw const FormatException('Invalid snooze receipt');
    _snoozeReceipts.putIfAbsent(
      fence.generation,
      () => {},
    )[valid.actionIdentity] = valid;
    return true;
  }

  Map<String, DateTime> _snoozesFor(int generation) =>
      _snoozesByGeneration.putIfAbsent(generation, () => {});

  Set<String> _handledOccurrenceIdsFor(int generation) =>
      _handledOccurrenceIdsByGeneration.putIfAbsent(generation, () => {});

  Map<String, DateTime> _handledAtFor(int generation) =>
      _handledAtByGeneration.putIfAbsent(generation, () => {});

  List<AgendaNotificationAction> _pendingActionsFor(int generation) =>
      _pendingActionsByGeneration.putIfAbsent(generation, () => []);

  Map<String, AgendaNotificationBackgroundRequest> _backgroundRequestsFor(
    int generation,
  ) => _backgroundRequestsByGeneration.putIfAbsent(generation, () => {});

  void _trimHandled(int generation) {
    final handled = _handledOccurrenceIdsFor(generation);
    if (handled.length <= maxHandledOccurrences) return;
    final handledAt = _handledAtFor(generation);
    final timestamped = handledAt.keys.toList()
      ..sort((a, b) => handledAt[b]!.compareTo(handledAt[a]!));
    final legacy = handled.where((id) => !handledAt.containsKey(id)).toList()
      ..sort();
    final keep = {
      ...timestamped,
      ...legacy,
    }.take(maxHandledOccurrences).toSet();
    handled.retainAll(keep);
    handledAt.removeWhere((id, _) => !keep.contains(id));
  }
}
