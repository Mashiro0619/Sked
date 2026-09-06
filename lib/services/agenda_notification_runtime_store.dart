import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agenda_runtime_mutation_lock.dart';

/// A notification action captured by the platform while the Flutter UI was
/// not running. The queue is runtime-only and is never included in AppData or
/// user backups.
class AgendaNotificationAction {
  const AgendaNotificationAction({
    required this.id,
    required this.payload,
    required this.actionId,
    required this.enqueuedAt,
  });

  final String id;
  final String payload;
  final String actionId;
  final DateTime enqueuedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'payload': payload,
    'actionId': actionId,
    'enqueuedAt': enqueuedAt.toIso8601String(),
  };

  static AgendaNotificationAction? tryDecode(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final payload = value['payload'];
    final actionId = value['actionId'];
    final enqueuedAt = value['enqueuedAt'];
    if (id is! String || id.isEmpty || id.length > maxIdLength) return null;
    if (payload is! String ||
        payload.isEmpty ||
        payload.length > maxPayloadLength) {
      return null;
    }
    if (actionId is! String ||
        actionId.isEmpty ||
        actionId.length > maxActionIdLength) {
      return null;
    }
    if (enqueuedAt is! String) return null;
    final parsed = DateTime.tryParse(enqueuedAt);
    if (parsed == null) return null;
    return AgendaNotificationAction(
      id: id,
      payload: payload,
      actionId: actionId,
      enqueuedAt: parsed,
    );
  }

  static const maxIdLength = 128;
  static const maxPayloadLength = 16 * 1024;
  static const maxActionIdLength = 128;
}

/// Minimal rendered data required to reschedule a snooze from Android's
/// background notification isolate. It is runtime-only and intentionally does
/// not contain an AppData snapshot or any provider state.
class AgendaNotificationBackgroundRequest {
  const AgendaNotificationBackgroundRequest({
    required this.key,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.payload,
    required this.fireAt,
    required this.localeCode,
    required this.lockScreenShowTitles,
    this.channelId,
    this.channelName,
    this.channelDescription,
  });

  final String key;
  final int notificationId;
  final String title;
  final String body;
  final String payload;
  final DateTime fireAt;
  final String localeCode;
  final bool lockScreenShowTitles;
  final String? channelId;
  final String? channelName;
  final String? channelDescription;

  AgendaNotificationBackgroundRequest copyWith({
    String? payload,
    DateTime? fireAt,
  }) => AgendaNotificationBackgroundRequest(
    key: key,
    notificationId: notificationId,
    title: title,
    body: body,
    payload: payload ?? this.payload,
    fireAt: fireAt ?? this.fireAt,
    localeCode: localeCode,
    lockScreenShowTitles: lockScreenShowTitles,
    channelId: channelId,
    channelName: channelName,
    channelDescription: channelDescription,
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'notificationId': notificationId,
    'title': title,
    'body': body,
    'payload': payload,
    'fireAt': fireAt.toIso8601String(),
    'localeCode': localeCode,
    'lockScreenShowTitles': lockScreenShowTitles,
    if (channelId != null) 'channelId': channelId,
    if (channelName != null) 'channelName': channelName,
    if (channelDescription != null) 'channelDescription': channelDescription,
  };

  static AgendaNotificationBackgroundRequest? tryDecode(Object? value) {
    if (value is! Map) return null;
    String? requiredString(String field, int maximum) {
      final raw = value[field];
      if (raw is! String || raw.trim().isEmpty || raw.length > maximum) {
        return null;
      }
      return raw;
    }

    String? optionalString(String field, int maximum) {
      final raw = value[field];
      if (raw == null) return null;
      if (raw is! String || raw.trim().isEmpty || raw.length > maximum) {
        return null;
      }
      return raw;
    }

    final key = requiredString('key', maxKeyLength);
    final payload = requiredString('payload', maxPayloadLength);
    final title = requiredString('title', maxRenderedTextLength);
    final body = requiredString('body', maxRenderedTextLength);
    final localeCode = requiredString('localeCode', maxLocaleLength);
    final fireAtValue = value['fireAt'];
    final fireAt = fireAtValue is String
        ? DateTime.tryParse(fireAtValue)
        : null;
    final id = value['notificationId'];
    if (key == null ||
        payload == null ||
        title == null ||
        body == null ||
        localeCode == null ||
        fireAt == null ||
        id is! num ||
        !id.isFinite ||
        id % 1 != 0 ||
        id < 1 ||
        id > 0x7fffffff) {
      return null;
    }
    final channelId = optionalString('channelId', maxChannelTextLength);
    final channelName = optionalString('channelName', maxChannelTextLength);
    final channelDescription = optionalString(
      'channelDescription',
      maxRenderedTextLength,
    );
    if ((value['channelId'] != null && channelId == null) ||
        (value['channelName'] != null && channelName == null) ||
        (value['channelDescription'] != null && channelDescription == null)) {
      return null;
    }
    return AgendaNotificationBackgroundRequest(
      key: key,
      notificationId: id.toInt(),
      title: title,
      body: body,
      payload: payload,
      fireAt: fireAt,
      localeCode: localeCode,
      lockScreenShowTitles: value['lockScreenShowTitles'] == true,
      channelId: channelId,
      channelName: channelName,
      channelDescription: channelDescription,
    );
  }

  static const maxKeyLength = 1024;
  static const maxPayloadLength = 16 * 1024;
  static const maxRenderedTextLength = 4096;
  static const maxChannelTextLength = 256;
  static const maxLocaleLength = 64;
}

/// Identifies whether a projection is allowed to fully replace the platform
/// notification plan or is only maintaining an already published plan.
///
/// A maintenance pass is deliberately weaker than an authoritative foreground
/// pass: it must not race a notification that has just become due.
enum AgendaNotificationReconcileMode { authoritative, maintenance }

/// Identifies whether a notification projection was performed by a foreground
/// Flutter host or the Android headless maintenance worker.
///
/// The distinction is runtime diagnostic information only. It deliberately
/// does not change reconciliation semantics, which remain governed by
/// [AgendaNotificationReconcileMode].
enum AgendaNotificationReconcileOrigin { foreground, background }

/// Terminal result recorded for the most recent notification projection.
enum AgendaNotificationDiagnosticResult { success, skipped, blocked, failed }

/// A durable fence around notification projection work.
///
/// The foreground application and Android's headless WorkManager engine do
/// not share an isolate. A background worker can therefore load an AppData
/// file immediately before the foreground clears it. Incrementing this fence
/// makes that previously loaded snapshot unusable without putting runtime
/// state into AppData or a user backup.
class AgendaNotificationProjectionFence {
  const AgendaNotificationProjectionFence({
    required this.generation,
    required this.blocked,
  });

  /// Monotonic enough for stale-worker detection. The value is intentionally
  /// runtime-only and has no relationship with the AppData schema version.
  final int generation;

  /// A clear is in progress or has completed. Only a later foreground path
  /// that knows it has a durable AppData snapshot may unblock the fence.
  final bool blocked;

  bool matches(AgendaNotificationProjectionFence other) =>
      generation == other.generation && blocked == other.blocked;

  static const initial = AgendaNotificationProjectionFence(
    generation: 0,
    blocked: false,
  );
}

/// A privacy-minimised entry from the computed notification plan.
///
/// The runtime diagnostic intentionally records stable keys and fire times,
/// but never titles, locations, notes, or other user-visible agenda content.
class AgendaNotificationDiagnosticPlanItem {
  const AgendaNotificationDiagnosticPlanItem({
    required this.key,
    required this.fireAt,
    required this.sourceType,
  });

  final String key;
  final DateTime fireAt;
  final String sourceType;

  Map<String, Object?> toJson() => {
    'key': key,
    'fireAt': fireAt.toIso8601String(),
    'sourceType': sourceType,
  };

  static AgendaNotificationDiagnosticPlanItem? tryDecode(Object? value) {
    if (value is! Map) return null;
    final key = value['key'];
    final sourceType = value['sourceType'];
    final rawFireAt = value['fireAt'];
    final fireAt = rawFireAt is String ? DateTime.tryParse(rawFireAt) : null;
    if (key is! String ||
        key.isEmpty ||
        key.length > maxKeyLength ||
        sourceType is! String ||
        sourceType.isEmpty ||
        sourceType.length > maxSourceTypeLength ||
        fireAt == null) {
      return null;
    }
    return AgendaNotificationDiagnosticPlanItem(
      key: key,
      fireAt: fireAt,
      sourceType: sourceType,
    );
  }

  static const maxKeyLength = 1024;
  static const maxSourceTypeLength = 128;
}

/// Runtime-only observability for notification reconciliation.
///
/// This is intentionally stored outside AppData and exports. It lets a
/// developer-facing diagnostic surface explain the last plan without putting
/// private schedule content into user backups.
class AgendaNotificationDiagnostics {
  const AgendaNotificationDiagnostics({
    required this.recordedAt,
    required this.mode,
    required this.result,
    required this.notificationsEnabled,
    required this.exactAlarmsAllowed,
    this.batteryOptimizationIgnored = true,
    required this.plannedCount,
    required this.scheduledCount,
    required this.truncatedCount,
    required this.retainedPendingCount,
    required this.plan,
    this.origin = AgendaNotificationReconcileOrigin.foreground,
    this.nextMaintenanceAt,
    this.overflowCatchUpAt,
    this.platformPendingCount,
    this.platformActiveCount,
    this.platformSampledAt,
    this.error,
  });

  final DateTime recordedAt;
  final AgendaNotificationReconcileMode mode;
  final AgendaNotificationReconcileOrigin origin;
  final AgendaNotificationDiagnosticResult result;
  final bool notificationsEnabled;
  final bool exactAlarmsAllowed;
  final bool batteryOptimizationIgnored;
  final int plannedCount;
  final int scheduledCount;
  final int truncatedCount;
  final int retainedPendingCount;
  final List<AgendaNotificationDiagnosticPlanItem> plan;
  final DateTime? nextMaintenanceAt;
  final DateTime? overflowCatchUpAt;
  final int? platformPendingCount;
  final int? platformActiveCount;
  final DateTime? platformSampledAt;
  final String? error;

  AgendaNotificationDiagnostics copyWithPlatformSnapshot(
    int pendingCount,
    int activeCount,
    DateTime sampledAt,
  ) => AgendaNotificationDiagnostics(
    recordedAt: recordedAt,
    mode: mode,
    origin: origin,
    result: result,
    notificationsEnabled: notificationsEnabled,
    exactAlarmsAllowed: exactAlarmsAllowed,
    batteryOptimizationIgnored: batteryOptimizationIgnored,
    plannedCount: plannedCount,
    scheduledCount: scheduledCount,
    truncatedCount: truncatedCount,
    retainedPendingCount: retainedPendingCount,
    plan: plan,
    nextMaintenanceAt: nextMaintenanceAt,
    overflowCatchUpAt: overflowCatchUpAt,
    platformPendingCount: pendingCount,
    platformActiveCount: activeCount,
    platformSampledAt: sampledAt,
    error: error,
  );

  Map<String, Object?> toJson() => {
    'v': schemaVersion,
    'recordedAt': recordedAt.toIso8601String(),
    'mode': mode.name,
    'origin': origin.name,
    'result': result.name,
    'notificationsEnabled': notificationsEnabled,
    'exactAlarmsAllowed': exactAlarmsAllowed,
    'batteryOptimizationIgnored': batteryOptimizationIgnored,
    'plannedCount': plannedCount,
    'scheduledCount': scheduledCount,
    'truncatedCount': truncatedCount,
    'retainedPendingCount': retainedPendingCount,
    'plan': plan.map((item) => item.toJson()).toList(growable: false),
    if (nextMaintenanceAt != null)
      'nextMaintenanceAt': nextMaintenanceAt!.toIso8601String(),
    if (overflowCatchUpAt != null)
      'overflowCatchUpAt': overflowCatchUpAt!.toIso8601String(),
    if (platformPendingCount != null)
      'platformPendingCount': platformPendingCount,
    if (platformActiveCount != null) 'platformActiveCount': platformActiveCount,
    if (platformSampledAt != null)
      'platformSampledAt': platformSampledAt!.toIso8601String(),
    if (error != null && error!.isNotEmpty) 'error': error,
  };

  static AgendaNotificationDiagnostics? tryDecode(Object? value) {
    if (value is! Map || value['v'] != schemaVersion) return null;
    final rawRecordedAt = value['recordedAt'];
    final recordedAt = rawRecordedAt is String
        ? DateTime.tryParse(rawRecordedAt)
        : null;
    final mode = _parseReconcileMode(value['mode']);
    final origin = value['origin'] == null
        ? AgendaNotificationReconcileOrigin.foreground
        : _parseReconcileOrigin(value['origin']);
    final result = _parseDiagnosticResult(value['result']);
    final plannedCount = _decodeNonNegativeInt(value['plannedCount']);
    final scheduledCount = _decodeNonNegativeInt(value['scheduledCount']);
    final truncatedCount = _decodeNonNegativeInt(value['truncatedCount']);
    final retainedPendingCount = _decodeNonNegativeInt(
      value['retainedPendingCount'],
    );
    if (recordedAt == null ||
        mode == null ||
        origin == null ||
        result == null ||
        value['notificationsEnabled'] is! bool ||
        value['exactAlarmsAllowed'] is! bool ||
        (value['batteryOptimizationIgnored'] != null &&
            value['batteryOptimizationIgnored'] is! bool) ||
        plannedCount == null ||
        scheduledCount == null ||
        truncatedCount == null ||
        retainedPendingCount == null) {
      return null;
    }

    DateTime? decodeOptionalDate(String field) {
      final raw = value[field];
      if (raw == null) return null;
      return raw is String ? DateTime.tryParse(raw) : null;
    }

    final nextMaintenanceAt = decodeOptionalDate('nextMaintenanceAt');
    final overflowCatchUpAt = decodeOptionalDate('overflowCatchUpAt');
    final platformSampledAt = decodeOptionalDate('platformSampledAt');
    final platformPendingCount = _decodeNullableNonNegativeInt(
      value['platformPendingCount'],
    );
    final platformActiveCount = _decodeNullableNonNegativeInt(
      value['platformActiveCount'],
    );
    if ((value['nextMaintenanceAt'] != null && nextMaintenanceAt == null) ||
        (value['overflowCatchUpAt'] != null && overflowCatchUpAt == null) ||
        (value['platformSampledAt'] != null && platformSampledAt == null) ||
        (value.containsKey('platformPendingCount') &&
            platformPendingCount == null) ||
        (value.containsKey('platformActiveCount') &&
            platformActiveCount == null)) {
      return null;
    }

    final rawPlan = value['plan'];
    if (rawPlan is! List) return null;
    final plan = <AgendaNotificationDiagnosticPlanItem>[];
    for (final rawItem in rawPlan.take(maxPlanItems)) {
      final item = AgendaNotificationDiagnosticPlanItem.tryDecode(rawItem);
      if (item == null) return null;
      plan.add(item);
    }
    if (rawPlan.length > maxPlanItems) return null;

    final rawError = value['error'];
    if (rawError != null &&
        (rawError is! String || rawError.length > maxErrorLength)) {
      return null;
    }
    return AgendaNotificationDiagnostics(
      recordedAt: recordedAt,
      mode: mode,
      origin: origin,
      result: result,
      notificationsEnabled: value['notificationsEnabled'] as bool,
      exactAlarmsAllowed: value['exactAlarmsAllowed'] as bool,
      batteryOptimizationIgnored: value['batteryOptimizationIgnored'] == null
          ? true
          : value['batteryOptimizationIgnored'] as bool,
      plannedCount: plannedCount,
      scheduledCount: scheduledCount,
      truncatedCount: truncatedCount,
      retainedPendingCount: retainedPendingCount,
      plan: List.unmodifiable(plan),
      nextMaintenanceAt: nextMaintenanceAt,
      overflowCatchUpAt: overflowCatchUpAt,
      platformPendingCount: platformPendingCount,
      platformActiveCount: platformActiveCount,
      platformSampledAt: platformSampledAt,
      error: rawError as String?,
    );
  }

  static const schemaVersion = 1;
  static const maxPlanItems = 32;
  static const maxErrorLength = 2048;
}

AgendaNotificationReconcileMode? _parseReconcileMode(Object? value) {
  if (value is! String) return null;
  for (final mode in AgendaNotificationReconcileMode.values) {
    if (mode.name == value) return mode;
  }
  return null;
}

AgendaNotificationReconcileOrigin? _parseReconcileOrigin(Object? value) {
  if (value is! String) return null;
  for (final origin in AgendaNotificationReconcileOrigin.values) {
    if (origin.name == value) return origin;
  }
  return null;
}

AgendaNotificationDiagnosticResult? _parseDiagnosticResult(Object? value) {
  if (value is! String) return null;
  for (final result in AgendaNotificationDiagnosticResult.values) {
    if (result.name == value) return result;
  }
  return null;
}

int? _decodeNonNegativeInt(Object? value) {
  if (value is int && value >= 0) return value;
  if (value is num && value.isFinite && value >= 0 && value % 1 == 0) {
    return value.toInt();
  }
  return null;
}

int? _decodeNullableNonNegativeInt(Object? value) {
  if (value == null) return null;
  return _decodeNonNegativeInt(value);
}

/// Runtime-only notification state.
///
/// This state is deliberately separate from [AppData]: snoozes and handled
/// acknowledgements are device/runtime concerns and must not be copied into a
/// user backup or exported agenda file.
abstract interface class AgendaNotificationRuntimeStore {
  Future<Map<String, DateTime>> readSnoozes();

  Future<Set<String>> readHandledOccurrenceIds();

  Future<void> setSnooze(String key, DateTime fireAt);

  Future<void> removeSnooze(String key);

  Future<void> addHandledOccurrence(String occurrenceId);

  Future<void> removeHandledOccurrence(String occurrenceId);

  Future<void> clear();
}

/// Optional cross-engine coordination for agenda projection.
///
/// This stays separate from [AgendaNotificationRuntimeStore] so small custom
/// stores used by integrations retain source compatibility. Production stores
/// implement it and persist the fence outside AppData and user backups.
abstract interface class AgendaNotificationProjectionFenceStore {
  /// Reads the currently active fence. A malformed persisted value must fail
  /// closed by returning a blocked fence.
  Future<AgendaNotificationProjectionFence> readProjectionFence();

  /// Durably invalidates any projection that captured an earlier generation.
  /// This must happen before runtime state or platform alarms are cleared.
  Future<AgendaNotificationProjectionFence> blockProjectionForDataClear();

  /// Reopens projections after a foreground caller has confirmed a fresh
  /// AppData snapshot was committed to storage.
  Future<AgendaNotificationProjectionFence>
  activateProjectionAfterDurableData();
}

/// Optional runtime store extension for persisted diagnostic snapshots.
abstract interface class AgendaNotificationDiagnosticsStore {
  Future<AgendaNotificationDiagnostics?> readNotificationDiagnostics();

  Future<void> writeNotificationDiagnostics(
    AgendaNotificationDiagnostics diagnostics,
  );
}

/// Optional extension implemented by stores that can receive actions from a
/// background notification isolate. Keeping it separate preserves source
/// compatibility for injected stores that only support snoozes/handled state.
abstract interface class AgendaNotificationActionStore {
  Future<List<AgendaNotificationAction>> readPendingActions();

  Future<void> enqueueAction({
    required String payload,
    required String actionId,
  });

  Future<void> removePendingAction(String id);
}

/// Optional store for enough rendered notification data to reschedule a
/// snooze before a foreground Flutter engine is available.
abstract interface class AgendaNotificationBackgroundRequestStore {
  Future<AgendaNotificationBackgroundRequest?> readBackgroundRequest(
    String key,
  );

  Future<void> saveBackgroundRequest(
    AgendaNotificationBackgroundRequest request,
  );

  Future<void> removeBackgroundRequest(String key);

  Future<void> pruneBackgroundRequests({required DateTime now});
}

/// Optional index of logical keys with persisted rendered notification
/// ownership. It allows a restarted service to find legacy active cards even
/// when Android no longer exposes their old untagged notification metadata.
abstract interface class AgendaNotificationBackgroundRequestIndex {
  Future<Set<String>> backgroundRequestKeys();

  /// Reads ownership metadata without applying the short snooze-recovery TTL.
  /// Active notification cards can outlive the scheduled fire time and still
  /// need to be canceled after a later authoritative data edit.
  Future<AgendaNotificationBackgroundRequest?>
  readBackgroundRequestForOwnership(String key);
}

/// Optional transactional view used by the Android background notification
/// callback.
///
/// The callback can outlive a foreground data clear because it runs in a
/// separate, short-lived Flutter isolate. It captures one fence before making
/// any runtime mutation, then uses that same fence for every write. A clear
/// that advances the generation makes those late writes invisible to the next
/// foreground projection instead of allowing them to repopulate runtime
/// state.
///
/// This is intentionally optional so small injected runtime stores retain the
/// original [AgendaNotificationRuntimeStore] contract. Production stores
/// implement it.
abstract interface class AgendaNotificationFencedRuntimeStore {
  /// Captures a writable runtime generation, or returns null while a data
  /// clear is in progress or has not yet been followed by a durable commit.
  Future<AgendaNotificationProjectionFence?> captureWritableRuntimeFence();

  /// Returns whether [fence] is still the active writable generation.
  Future<bool> isRuntimeFenceCurrent(AgendaNotificationProjectionFence fence);

  Future<void> setSnoozeForRuntimeFence(
    String key,
    DateTime fireAt,
    AgendaNotificationProjectionFence fence,
  );

  Future<void> addHandledOccurrenceForRuntimeFence(
    String occurrenceId,
    AgendaNotificationProjectionFence fence,
  );

  Future<void> enqueueActionForRuntimeFence({
    required String payload,
    required String actionId,
    required AgendaNotificationProjectionFence fence,
  });

  Future<AgendaNotificationBackgroundRequest?>
  readBackgroundRequestForRuntimeFence(
    String key,
    AgendaNotificationProjectionFence fence,
  );

  Future<void> saveBackgroundRequestForRuntimeFence(
    AgendaNotificationBackgroundRequest request,
    AgendaNotificationProjectionFence fence,
  );
}

/// Raised when the platform reports that a runtime-only preference write did
/// not reach durable storage. Runtime actions must not be treated as accepted
/// when this happens, otherwise a notification can disappear without its
/// snooze/handled state surviving a process restart.
class AgendaNotificationRuntimeStorageException implements Exception {
  const AgendaNotificationRuntimeStorageException(this.key);

  final String key;

  @override
  String toString() =>
      'Unable to persist notification runtime state for preference "$key".';
}

/// In-memory implementation for tests and hosts without persistent
/// preferences.
class MemoryAgendaNotificationRuntimeStore
    implements
        AgendaNotificationRuntimeStore,
        AgendaNotificationActionStore,
        AgendaNotificationBackgroundRequestStore,
        AgendaNotificationBackgroundRequestIndex,
        AgendaNotificationDiagnosticsStore,
        AgendaNotificationProjectionFenceStore,
        AgendaNotificationFencedRuntimeStore {
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
      generation: _nextProjectionGeneration(projectionFence.generation),
      blocked: true,
    );
    return projectionFence;
  }

  @override
  Future<AgendaNotificationProjectionFence>
  activateProjectionAfterDurableData() async {
    if (!projectionFence.blocked) return projectionFence;
    projectionFence = AgendaNotificationProjectionFence(
      generation: _nextProjectionGeneration(projectionFence.generation),
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
    final id = _actionId(payload, actionId);
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

/// SharedPreferences-backed runtime state used by Android and other native
/// hosts. The keys are namespaced and can be removed independently during the
/// app's clear-data flow.
class SharedPreferencesAgendaNotificationRuntimeStore
    implements
        AgendaNotificationRuntimeStore,
        AgendaNotificationActionStore,
        AgendaNotificationBackgroundRequestStore,
        AgendaNotificationBackgroundRequestIndex,
        AgendaNotificationDiagnosticsStore,
        AgendaNotificationProjectionFenceStore,
        AgendaNotificationFencedRuntimeStore {
  SharedPreferencesAgendaNotificationRuntimeStore({
    Future<SharedPreferences> Function()? preferencesProvider,
    DateTime Function()? clock,
    Future<bool> Function(SharedPreferences, String, String)? stringWriter,
    Future<bool> Function(SharedPreferences, String, List<String>)?
    stringListWriter,
    Future<bool> Function(SharedPreferences, String)? keyRemover,
  }) : _preferencesProvider =
           preferencesProvider ?? SharedPreferences.getInstance,
       _clock = clock ?? DateTime.now,
       _stringWriter = stringWriter ?? _writeString,
       _stringListWriter = stringListWriter ?? _writeStringList,
       _keyRemover = keyRemover ?? _removeKey;

  static const snoozeKey = 'sked.notification.runtime.snoozes';
  static const handledKey = 'sked.notification.runtime.handled';
  static const actionsKey = 'sked.notification.runtime.actions';
  static const handledRecordsKey = 'sked.notification.runtime.handledAt';
  static const backgroundRequestKeyPrefix =
      'sked.notification.runtime.background_request.';
  static const runtimeGenerationKeyPrefix =
      'sked.notification.runtime.generation.';
  static const diagnosticsKey = 'sked.notification.runtime.diagnostics.v1';
  static const projectionFenceKey =
      'sked.notification.runtime.projection_fence.v1';
  static const maxPendingActions = 32;
  static const maxHandledOccurrences = 256;
  static const pendingActionTtl = Duration(hours: 24);
  static const handledTtl = Duration(days: 30);
  static const backgroundRequestTtl = Duration(days: 2);

  final Future<SharedPreferences> Function() _preferencesProvider;
  final DateTime Function() _clock;
  final Future<bool> Function(SharedPreferences, String, String) _stringWriter;
  final Future<bool> Function(SharedPreferences, String, List<String>)
  _stringListWriter;
  final Future<bool> Function(SharedPreferences, String) _keyRemover;
  Future<SharedPreferences>? _preferencesFuture;
  Future<void> _mutationTail = Future<void>.value();

  static Future<bool> _writeString(
    SharedPreferences preferences,
    String key,
    String value,
  ) => preferences.setString(key, value);

  static Future<bool> _writeStringList(
    SharedPreferences preferences,
    String key,
    List<String> value,
  ) => preferences.setStringList(key, value);

  static Future<bool> _removeKey(SharedPreferences preferences, String key) =>
      preferences.remove(key);

  Future<SharedPreferences> get _preferences {
    final current = _preferencesFuture;
    if (current != null) return current;
    final next = _preferencesProvider();
    _preferencesFuture = next;
    return next;
  }

  @override
  Future<Map<String, DateTime>> readSnoozes() async {
    final preferences = await _preferences;
    await _reload(preferences);
    final fence = _readProjectionFence(preferences);
    if (fence.blocked) return const {};
    final storageKey = _snoozeStorageKey(fence);
    final raw =
        preferences.getString(storageKey) ??
        (_usesLegacyRuntimeState(fence)
            ? preferences.getString(snoozeKey)
            : null);
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final now = _clock();
      final result = <String, DateTime>{};
      var dirty = false;
      for (final entry in decoded.entries) {
        if (entry.key is! String || (entry.key as String).isEmpty) {
          dirty = true;
          continue;
        }
        final value = entry.value;
        final parsed = value is String ? DateTime.tryParse(value) : null;
        if (parsed != null && parsed.isAfter(now)) {
          result[entry.key as String] = parsed;
        } else {
          dirty = true;
        }
      }
      if (dirty) {
        // Cleanup is itself a read-modify-write. Queue it with the other
        // mutations and reread the latest value so an action from another
        // Flutter isolate cannot be overwritten by this stale snapshot.
        await _enqueueMutation(() async {
          await _reload(preferences);
          if (!_isCurrentWritableFence(preferences, fence)) return;
          final latest = await _readSnoozesForFence(preferences, fence);
          await _writeSnoozes(latest, fence);
        });
      }
      return Map.unmodifiable(result);
    } on FormatException {
      return const {};
    }
  }

  @override
  Future<Set<String>> readHandledOccurrenceIds() async {
    final preferences = await _preferences;
    await _reload(preferences);
    final fence = _readProjectionFence(preferences);
    if (fence.blocked) return const {};
    return _readHandledOccurrenceIdsForFence(preferences, fence);
  }

  Future<Set<String>> _readHandledOccurrenceIdsForFence(
    SharedPreferences preferences,
    AgendaNotificationProjectionFence fence, {
    bool persistCleanup = true,
  }) async {
    try {
      final now = _clock();
      final handledStorageKey = _handledStorageKey(fence);
      final recordsStorageKey = _handledRecordsStorageKey(fence);
      final legacy =
          preferences
              .getStringList(handledStorageKey)
              ?.map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toSet() ??
          (_usesLegacyRuntimeState(fence)
              ? preferences
                        .getStringList(handledKey)
                        ?.map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toSet() ??
                    <String>{}
              : <String>{});
      final rawRecords =
          preferences.getString(recordsStorageKey) ??
          (_usesLegacyRuntimeState(fence)
              ? preferences.getString(handledRecordsKey)
              : null);
      final records = <String, DateTime>{};
      final recordKeys = <String>{};
      var dirty = false;
      if (rawRecords != null && rawRecords.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawRecords);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              if (entry.key is! String ||
                  (entry.key as String).trim().isEmpty) {
                dirty = true;
                continue;
              }
              final id = (entry.key as String).trim();
              recordKeys.add(id);
              final parsed = entry.value is String
                  ? DateTime.tryParse(entry.value as String)
                  : null;
              if (parsed != null &&
                  now.difference(parsed) <= handledTtl &&
                  !parsed.isAfter(now.add(const Duration(minutes: 5)))) {
                records[id] = parsed;
              } else {
                dirty = true;
              }
            }
          } else {
            dirty = true;
          }
        } on FormatException {
          dirty = true;
        }
      }
      // Migrate legacy handled IDs to timestamped records on first read. IDs
      // that were present in the timestamped store but have expired are not
      // resurrected from the legacy list.
      for (final id in legacy) {
        if (records.containsKey(id)) continue;
        if (recordKeys.contains(id)) {
          dirty = true;
          continue;
        }
        records[id] = now;
        dirty = true;
      }
      final result = <String>{...records.keys};
      final bounded = _limitHandledIds(result, records);
      final existingIds = legacy;
      final idsChanged =
          existingIds.length != bounded.ids.length ||
          !existingIds.containsAll(bounded.ids) ||
          !bounded.ids.containsAll(existingIds);
      if (dirty || records.length != bounded.timestamped.length || idsChanged) {
        if (!persistCleanup) {
          return Set.unmodifiable(bounded.ids);
        }
        // Cleanup is a read-modify-write. Serialize it and reread before
        // persisting so a concurrent action from another isolate is retained.
        await _enqueueMutation(() async {
          await _reload(preferences);
          if (!_isCurrentWritableFence(preferences, fence)) return;
          final latestIds = await _readHandledOccurrenceIdsForFence(
            preferences,
            fence,
            persistCleanup: false,
          );
          final latestRecords = await _readHandledRecords(fence);
          final now = _clock();
          for (final id in latestIds) {
            latestRecords[id] ??= now;
          }
          await _writeHandledState(
            _limitHandledIds(latestIds, latestRecords),
            fence,
          );
        });
      }
      return Set.unmodifiable(bounded.ids);
    } on AgendaNotificationRuntimeStorageException {
      rethrow;
    } on Object {
      // SharedPreferences can contain a value written by an older build or a
      // third-party test double under the same key. Treat that runtime state
      // as empty rather than preventing notification startup.
      return const {};
    }
  }

  @override
  Future<List<AgendaNotificationAction>> readPendingActions() async {
    final preferences = await _preferences;
    await _reload(preferences);
    final fence = _readProjectionFence(preferences);
    if (fence.blocked) return const [];
    final raw =
        preferences.getString(_actionsStorageKey(fence)) ??
        (_usesLegacyRuntimeState(fence)
            ? preferences.getString(actionsKey)
            : null);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final now = _clock();
      final result = <AgendaNotificationAction>[];
      final seen = <String>{};
      var dirty = false;
      for (final value in decoded) {
        final action = AgendaNotificationAction.tryDecode(value);
        if (action == null ||
            now.difference(action.enqueuedAt) > pendingActionTtl ||
            action.enqueuedAt.isAfter(now.add(const Duration(minutes: 5)))) {
          dirty = true;
          continue;
        }
        final canonicalId = _actionId(action.payload, action.actionId);
        final normalized = canonicalId == action.id
            ? action
            : AgendaNotificationAction(
                id: canonicalId,
                payload: action.payload,
                actionId: action.actionId,
                enqueuedAt: action.enqueuedAt,
              );
        if (canonicalId != action.id) dirty = true;
        if (!seen.add(canonicalId)) {
          dirty = true;
          continue;
        }
        result.add(normalized);
      }
      result.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
      if (result.length > maxPendingActions) {
        result.removeRange(0, result.length - maxPendingActions);
        dirty = true;
      }
      if (dirty) {
        // Queue stale-entry cleanup and reread the current queue first. A
        // background action may have been appended while this snapshot was
        // being decoded.
        await _enqueueMutation(() async {
          await _reload(preferences);
          if (!_isCurrentWritableFence(preferences, fence)) return;
          final latest = await _readPendingActionsForFence(preferences, fence);
          await _writePendingActions(latest, fence);
        });
      }
      return List.unmodifiable(result);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> setSnooze(String key, DateTime fireAt) async {
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await setSnoozeForRuntimeFence(key, fireAt, fence);
  }

  @override
  Future<void> removeSnooze(String key) async {
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final values = Map<String, DateTime>.from(await readSnoozes())
        ..remove(key);
      await _writeSnoozes(values, fence);
    });
  }

  @override
  Future<void> setSnoozeForRuntimeFence(
    String key,
    DateTime fireAt,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked || key.trim().isEmpty) return;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final values = Map<String, DateTime>.from(
        await _readSnoozesForFence(preferences, fence),
      );
      values[key] = fireAt;
      await _writeSnoozes(values, fence);
    });
  }

  @override
  Future<void> addHandledOccurrence(String occurrenceId) async {
    if (occurrenceId.trim().isEmpty) return;
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await addHandledOccurrenceForRuntimeFence(occurrenceId, fence);
  }

  @override
  Future<void> removeHandledOccurrence(String occurrenceId) async {
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final values = {...await readHandledOccurrenceIds()}
        ..remove(occurrenceId);
      final records = await _readHandledRecords(fence)
        ..remove(occurrenceId);
      await _writeHandledState(_limitHandledIds(values, records), fence);
    });
  }

  @override
  Future<void> addHandledOccurrenceForRuntimeFence(
    String occurrenceId,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (fence.blocked || occurrenceId.trim().isEmpty) return;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final values = {
        ...await _readHandledOccurrenceIdsForFence(
          preferences,
          fence,
          persistCleanup: false,
        ),
        occurrenceId,
      };
      final records = await _readHandledRecords(fence);
      final now = _clock();
      for (final id in values) {
        records[id] ??= now;
      }
      records[occurrenceId] = now;
      await _writeHandledState(_limitHandledIds(values, records), fence);
    });
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
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await enqueueActionForRuntimeFence(
      payload: payload,
      actionId: actionId,
      fence: fence,
    );
  }

  @override
  Future<void> removePendingAction(String id) async {
    if (id.isEmpty) return;
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final values = (await readPendingActions())
          .where((item) => item.id != id)
          .toList();
      await _writePendingActions(values, fence);
    });
  }

  @override
  Future<void> enqueueActionForRuntimeFence({
    required String payload,
    required String actionId,
    required AgendaNotificationProjectionFence fence,
  }) async {
    if (fence.blocked ||
        payload.isEmpty ||
        payload.length > AgendaNotificationAction.maxPayloadLength ||
        actionId.isEmpty ||
        actionId.length > AgendaNotificationAction.maxActionIdLength) {
      return;
    }
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final values = (await _readPendingActionsForFence(
        preferences,
        fence,
      )).toList();
      final id = _actionId(payload, actionId);
      if (values.any(
        (item) =>
            item.id == id ||
            (item.payload == payload && item.actionId == actionId),
      )) {
        return;
      }
      values.add(
        AgendaNotificationAction(
          id: id,
          payload: payload,
          actionId: actionId,
          enqueuedAt: _clock(),
        ),
      );
      values.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
      final bounded = values.length > maxPendingActions
          ? values.sublist(values.length - maxPendingActions)
          : values;
      await _writePendingActions(bounded, fence);
    });
  }

  @override
  Future<AgendaNotificationBackgroundRequest?> readBackgroundRequest(
    String key,
  ) async {
    if (key.trim().isEmpty) return null;
    final preferences = await _preferences;
    await _reload(preferences);
    final fence = _readProjectionFence(preferences);
    if (fence.blocked) return null;
    return readBackgroundRequestForRuntimeFence(key, fence);
  }

  @override
  Future<AgendaNotificationBackgroundRequest?>
  readBackgroundRequestForRuntimeFence(
    String key,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (key.trim().isEmpty || fence.blocked) return null;
    final preferences = await _preferences;
    await _reload(preferences);
    if (!_isCurrentWritableFence(preferences, fence)) return null;
    final storageKey = _backgroundRequestStorageKey(key, fence);
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = AgendaNotificationBackgroundRequest.tryDecode(
        jsonDecode(raw),
      );
      if (decoded == null || decoded.key != key) {
        await _remove(storageKey);
        return null;
      }
      if (_clock().difference(decoded.fireAt) > backgroundRequestTtl) {
        await _remove(storageKey);
        return null;
      }
      return decoded;
    } on FormatException {
      await _remove(storageKey);
      return null;
    }
  }

  @override
  Future<void> saveBackgroundRequest(
    AgendaNotificationBackgroundRequest request,
  ) async {
    final decoded = AgendaNotificationBackgroundRequest.tryDecode(
      request.toJson(),
    );
    if (decoded == null) return;
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await saveBackgroundRequestForRuntimeFence(decoded, fence);
  }

  @override
  Future<void> saveBackgroundRequestForRuntimeFence(
    AgendaNotificationBackgroundRequest request,
    AgendaNotificationProjectionFence fence,
  ) async {
    await _enqueueMutation(() async {
      final decoded = AgendaNotificationBackgroundRequest.tryDecode(
        request.toJson(),
      );
      if (decoded == null || fence.blocked) return;
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      await _set(
        _backgroundRequestStorageKey(decoded.key, fence),
        jsonEncode(decoded.toJson()),
      );
    });
  }

  @override
  Future<void> removeBackgroundRequest(String key) async {
    if (key.trim().isEmpty) return;
    final fence = await _captureWritableFence();
    if (fence == null) return;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      await _remove(_backgroundRequestStorageKey(key, fence));
    });
  }

  @override
  Future<void> pruneBackgroundRequests({required DateTime now}) async {
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      final fence = _readProjectionFence(preferences);
      if (fence.blocked) return;
      final keys = preferences
          .getKeys()
          .where(
            (key) => key.startsWith(_backgroundRequestStorageKeyPrefix(fence)),
          )
          .toList(growable: false);
      for (final storageKey in keys) {
        final raw = preferences.getString(storageKey);
        AgendaNotificationBackgroundRequest? decoded;
        try {
          decoded = raw == null
              ? null
              : AgendaNotificationBackgroundRequest.tryDecode(jsonDecode(raw));
        } on FormatException {
          decoded = null;
        }
        if (decoded == null ||
            now.difference(decoded.fireAt) > backgroundRequestTtl) {
          await _remove(storageKey);
        }
      }
    });
  }

  @override
  Future<Set<String>> backgroundRequestKeys() async {
    final preferences = await _preferences;
    await _reload(preferences);
    final fence = _readProjectionFence(preferences);
    if (fence.blocked) return const {};
    final prefix = _backgroundRequestStorageKeyPrefix(fence);
    final keys = <String>{};
    for (final storageKey in preferences.getKeys().where(
      (key) => key.startsWith(prefix),
    )) {
      final raw = preferences.getString(storageKey);
      if (raw == null) continue;
      try {
        final request = AgendaNotificationBackgroundRequest.tryDecode(
          jsonDecode(raw),
        );
        if (request != null) keys.add(request.key);
      } on FormatException {
        // The normal prune path removes malformed records; do not expose one
        // as a valid ownership key during this read.
      }
    }
    return Set.unmodifiable(keys);
  }

  @override
  Future<AgendaNotificationBackgroundRequest?>
  readBackgroundRequestForOwnership(String key) async {
    if (key.trim().isEmpty) return null;
    final preferences = await _preferences;
    await _reload(preferences);
    final fence = _readProjectionFence(preferences);
    if (fence.blocked) return null;
    final raw = preferences.getString(_backgroundRequestStorageKey(key, fence));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final request = AgendaNotificationBackgroundRequest.tryDecode(
        jsonDecode(raw),
      );
      return request?.key == key ? request : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<AgendaNotificationDiagnostics?> readNotificationDiagnostics() async {
    final preferences = await _preferences;
    await _reload(preferences);
    final raw = preferences.getString(diagnosticsKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = AgendaNotificationDiagnostics.tryDecode(jsonDecode(raw));
      if (decoded != null) return decoded;
    } on FormatException {
      // Treat a partial or pre-release diagnostic snapshot as absent. It must
      // never prevent notification initialization or scheduling.
    }
    // Do not delete a fresh diagnostic record written by another isolate
    // while this malformed snapshot was being decoded.
    await _enqueueMutation(() async {
      await _reload(preferences);
      if (preferences.getString(diagnosticsKey) == raw) {
        await _remove(diagnosticsKey);
      }
    });
    return null;
  }

  @override
  Future<void> writeNotificationDiagnostics(
    AgendaNotificationDiagnostics diagnostics,
  ) async {
    await _enqueueMutation(() async {
      final decoded = AgendaNotificationDiagnostics.tryDecode(
        diagnostics.toJson(),
      );
      if (decoded == null) return;
      await _set(diagnosticsKey, jsonEncode(decoded.toJson()));
    });
  }

  @override
  Future<AgendaNotificationProjectionFence> readProjectionFence() async {
    final preferences = await _preferences;
    await _reload(preferences);
    return _readProjectionFence(preferences);
  }

  @override
  Future<AgendaNotificationProjectionFence>
  blockProjectionForDataClear() async {
    late AgendaNotificationProjectionFence result;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      final current = _readProjectionFence(preferences);
      result = AgendaNotificationProjectionFence(
        generation: _nextProjectionGeneration(current.generation),
        blocked: true,
      );
      await _set(projectionFenceKey, _encodeProjectionFence(result));
    });
    return result;
  }

  @override
  Future<AgendaNotificationProjectionFence>
  activateProjectionAfterDurableData() async {
    late AgendaNotificationProjectionFence result;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      final current = _readProjectionFence(preferences);
      if (!current.blocked) {
        result = current;
        return;
      }
      result = AgendaNotificationProjectionFence(
        generation: _nextProjectionGeneration(current.generation),
        blocked: false,
      );
      await _set(projectionFenceKey, _encodeProjectionFence(result));
    });
    return result;
  }

  @override
  Future<void> clear() async {
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _remove(snoozeKey);
      await _remove(handledKey);
      await _remove(handledRecordsKey);
      await _remove(actionsKey);
      await _remove(diagnosticsKey);
      // Keep [projectionFenceKey]. A clear must leave behind the durable
      // tombstone that stops a headless worker from projecting an AppData
      // snapshot it read before this operation began.
      for (final key in preferences.getKeys()) {
        if (key.startsWith(backgroundRequestKeyPrefix) ||
            key.startsWith(runtimeGenerationKeyPrefix)) {
          await _remove(key);
        }
      }
    });
  }

  Future<void> _enqueueMutation(Future<void> Function() mutation) {
    final operation = _mutationTail.then<void>(
      (_) => _runMutationWithLock(mutation),
      onError: (_, _) => _runMutationWithLock(mutation),
    );
    _mutationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  var _mutationLockHeld = false;

  Future<void> _runMutationWithLock(Future<void> Function() mutation) async {
    if (_mutationLockHeld) {
      await mutation();
      return;
    }
    await withAgendaRuntimeMutationLock(() async {
      _mutationLockHeld = true;
      try {
        await mutation();
      } finally {
        _mutationLockHeld = false;
      }
    });
  }

  Future<void> _writeSnoozes(
    Map<String, DateTime> values,
    AgendaNotificationProjectionFence fence,
  ) async {
    final encoded = <String, String>{
      for (final entry in values.entries)
        entry.key: entry.value.toIso8601String(),
    };
    await _set(_snoozeStorageKey(fence), jsonEncode(encoded));
    await _removeLegacyRuntimeKey(snoozeKey, fence);
  }

  Future<Map<String, DateTime>> _readHandledRecords(
    AgendaNotificationProjectionFence fence,
  ) async {
    final preferences = await _preferences;
    final raw =
        preferences.getString(_handledRecordsStorageKey(fence)) ??
        (_usesLegacyRuntimeState(fence)
            ? preferences.getString(handledRecordsKey)
            : null);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final now = _clock();
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String ||
            (entry.key as String).trim().isEmpty ||
            entry.value is! String) {
          continue;
        }
        final parsed = DateTime.tryParse(entry.value as String);
        if (parsed == null ||
            now.difference(parsed) > handledTtl ||
            parsed.isAfter(now.add(const Duration(minutes: 5)))) {
          continue;
        }
        result[entry.key as String] = parsed;
      }
      return result;
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeHandledState(
    _HandledLimit values,
    AgendaNotificationProjectionFence fence,
  ) async {
    await _setStringList(
      _handledStorageKey(fence),
      values.ids.toList()..sort(),
    );
    await _writeHandledRecords(values.timestamped, fence);
    await _removeLegacyRuntimeKey(handledKey, fence);
    await _removeLegacyRuntimeKey(handledRecordsKey, fence);
  }

  Future<void> _writeHandledRecords(
    Map<String, DateTime> values,
    AgendaNotificationProjectionFence fence,
  ) async {
    final storageKey = _handledRecordsStorageKey(fence);
    if (values.isEmpty) {
      await _remove(storageKey);
      return;
    }
    await _set(
      storageKey,
      jsonEncode({
        for (final entry in values.entries)
          entry.key: entry.value.toIso8601String(),
      }),
    );
  }

  Future<void> _writePendingActions(
    List<AgendaNotificationAction> values,
    AgendaNotificationProjectionFence fence,
  ) async {
    final storageKey = _actionsStorageKey(fence);
    if (values.isEmpty) {
      await _remove(storageKey);
      await _removeLegacyRuntimeKey(actionsKey, fence);
      return;
    }
    await _set(
      storageKey,
      jsonEncode(values.map((item) => item.toJson()).toList(growable: false)),
    );
    await _removeLegacyRuntimeKey(actionsKey, fence);
  }

  Future<void> _reload(SharedPreferences preferences) async {
    try {
      await preferences.reload();
    } catch (_) {
      // Test doubles and older hosts may not implement reload. Their cached
      // values are still safe to read.
    }
  }

  Future<AgendaNotificationProjectionFence?> _captureWritableFence() async {
    final preferences = await _preferences;
    await _reload(preferences);
    final fence = _readProjectionFence(preferences);
    return fence.blocked ? null : fence;
  }

  /// Checks a previously captured token against the freshly reloaded
  /// preferences snapshot. This closes the window between capturing a fence
  /// and entering a serialized read-modify-write operation: a data clear may
  /// advance the generation while that operation is queued.
  bool _isCurrentWritableFence(
    SharedPreferences preferences,
    AgendaNotificationProjectionFence fence,
  ) {
    final current = _readProjectionFence(preferences);
    return !current.blocked && current.matches(fence);
  }

  @override
  Future<AgendaNotificationProjectionFence?> captureWritableRuntimeFence() =>
      _captureWritableFence();

  @override
  Future<bool> isRuntimeFenceCurrent(
    AgendaNotificationProjectionFence fence,
  ) async {
    final preferences = await _preferences;
    await _reload(preferences);
    final current = _readProjectionFence(preferences);
    return !current.blocked && current.matches(fence);
  }

  Future<Map<String, DateTime>> _readSnoozesForFence(
    SharedPreferences preferences,
    AgendaNotificationProjectionFence fence,
  ) async {
    final raw =
        preferences.getString(_snoozeStorageKey(fence)) ??
        (_usesLegacyRuntimeState(fence)
            ? preferences.getString(snoozeKey)
            : null);
    if (raw == null || raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final now = _clock();
      final result = <String, DateTime>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.key.isEmpty) continue;
        final parsed = entry.value is String
            ? DateTime.tryParse(entry.value as String)
            : null;
        if (parsed != null && parsed.isAfter(now)) {
          result[entry.key as String] = parsed;
        }
      }
      return result;
    } on FormatException {
      return const {};
    }
  }

  Future<List<AgendaNotificationAction>> _readPendingActionsForFence(
    SharedPreferences preferences,
    AgendaNotificationProjectionFence fence,
  ) async {
    final raw =
        preferences.getString(_actionsStorageKey(fence)) ??
        (_usesLegacyRuntimeState(fence)
            ? preferences.getString(actionsKey)
            : null);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final now = _clock();
      final seen = <String>{};
      final result = <AgendaNotificationAction>[];
      for (final value in decoded) {
        final action = AgendaNotificationAction.tryDecode(value);
        if (action == null ||
            now.difference(action.enqueuedAt) > pendingActionTtl ||
            action.enqueuedAt.isAfter(now.add(const Duration(minutes: 5)))) {
          continue;
        }
        final id = _actionId(action.payload, action.actionId);
        if (!seen.add(id)) continue;
        result.add(
          id == action.id
              ? action
              : AgendaNotificationAction(
                  id: id,
                  payload: action.payload,
                  actionId: action.actionId,
                  enqueuedAt: action.enqueuedAt,
                ),
        );
      }
      result.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
      if (result.length > maxPendingActions) {
        result.removeRange(0, result.length - maxPendingActions);
      }
      return result;
    } on FormatException {
      return const [];
    }
  }

  bool _usesLegacyRuntimeState(AgendaNotificationProjectionFence fence) =>
      fence.generation == 0 && !fence.blocked;

  String _generationScopedRuntimeKey(
    AgendaNotificationProjectionFence fence,
    String suffix,
  ) => '$runtimeGenerationKeyPrefix${fence.generation}.$suffix';

  String _snoozeStorageKey(AgendaNotificationProjectionFence fence) =>
      _usesLegacyRuntimeState(fence)
      ? snoozeKey
      : _generationScopedRuntimeKey(fence, 'snoozes');

  String _handledStorageKey(AgendaNotificationProjectionFence fence) =>
      _usesLegacyRuntimeState(fence)
      ? handledKey
      : _generationScopedRuntimeKey(fence, 'handled');

  String _handledRecordsStorageKey(AgendaNotificationProjectionFence fence) =>
      _usesLegacyRuntimeState(fence)
      ? handledRecordsKey
      : _generationScopedRuntimeKey(fence, 'handledAt');

  String _actionsStorageKey(AgendaNotificationProjectionFence fence) =>
      _usesLegacyRuntimeState(fence)
      ? actionsKey
      : _generationScopedRuntimeKey(fence, 'actions');

  Future<void> _removeLegacyRuntimeKey(
    String key,
    AgendaNotificationProjectionFence fence,
  ) async {
    if (!_usesLegacyRuntimeState(fence)) await _remove(key);
  }

  Future<void> _set(String key, String value) async {
    final preferences = await _preferences;
    final persisted = await _stringWriter(preferences, key, value);
    if (!persisted) {
      throw AgendaNotificationRuntimeStorageException(key);
    }
  }

  Future<void> _setStringList(String key, List<String> value) async {
    final preferences = await _preferences;
    final persisted = await _stringListWriter(preferences, key, value);
    if (!persisted) {
      throw AgendaNotificationRuntimeStorageException(key);
    }
  }

  Future<void> _remove(String key) async {
    final preferences = await _preferences;
    final removed = await _keyRemover(preferences, key);
    if (!removed) {
      throw AgendaNotificationRuntimeStorageException(key);
    }
  }

  AgendaNotificationProjectionFence _readProjectionFence(
    SharedPreferences preferences,
  ) {
    final raw = preferences.getString(projectionFenceKey);
    if (raw == null || raw.trim().isEmpty) {
      return AgendaNotificationProjectionFence.initial;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _blockedProjectionFence();
      if (decoded['v'] != 1) return _blockedProjectionFence();
      final generation = decoded['generation'];
      final blocked = decoded['blocked'];
      if (generation is! num ||
          !generation.isFinite ||
          generation % 1 != 0 ||
          generation < 0 ||
          generation > 0x7fffffff ||
          blocked is! bool) {
        return _blockedProjectionFence();
      }
      return AgendaNotificationProjectionFence(
        generation: generation.toInt(),
        blocked: blocked,
      );
    } on Object {
      return _blockedProjectionFence();
    }
  }

  String _encodeProjectionFence(AgendaNotificationProjectionFence fence) =>
      jsonEncode({
        'v': 1,
        'generation': fence.generation,
        'blocked': fence.blocked,
      });

  String _backgroundRequestStorageKey(
    String key,
    AgendaNotificationProjectionFence fence,
  ) {
    final digest = sha256.convert(utf8.encode(key)).toString();
    return '${_backgroundRequestStorageKeyPrefix(fence)}$digest';
  }

  String _backgroundRequestStorageKeyPrefix(
    AgendaNotificationProjectionFence fence,
  ) => _usesLegacyRuntimeState(fence)
      ? backgroundRequestKeyPrefix
      : _generationScopedRuntimeKey(fence, 'background_request.');

  _HandledLimit _limitHandledIds(
    Set<String> ids,
    Map<String, DateTime> records,
  ) {
    final timestamped = records.keys.toList()
      ..sort((a, b) => records[b]!.compareTo(records[a]!));
    final legacy = ids.where((id) => !records.containsKey(id)).toList()..sort();
    final keep = [
      ...timestamped,
      ...legacy,
    ].take(maxHandledOccurrences).toSet();
    return _HandledLimit(
      ids: keep,
      timestamped: {
        for (final id in keep)
          if (records[id] != null) id: records[id]!,
      },
    );
  }
}

int _nextProjectionGeneration(int current) {
  // Avoid wrapping to zero: a process that observes an old generation must
  // never mistake a wrapped value for a fresh one. In practice this branch is
  // unreachable, but failing closed is safer than reusing a token.
  if (current >= 0x7fffffff) return 0x7fffffff;
  return current + 1;
}

AgendaNotificationProjectionFence _blockedProjectionFence() =>
    const AgendaNotificationProjectionFence(generation: 0, blocked: true);

String _actionId(String payload, String actionId) {
  // A queue item can be created in the Android background isolate and then
  // read by the foreground isolate. Use a cryptographic digest so the same
  // payload/action pair cannot collide with another pending action.
  final digest = sha256.convert(utf8.encode('$actionId\u0000$payload'));
  return 'action-${digest.toString()}';
}

class _HandledLimit {
  const _HandledLimit({required this.ids, required this.timestamped});

  final Set<String> ids;
  final Map<String, DateTime> timestamped;
}
