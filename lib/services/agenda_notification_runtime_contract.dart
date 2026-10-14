import 'agenda_notification_registration.dart';

export 'agenda_notification_registration.dart';

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

/// Identifies whether a projection may fully replace the platform plan or is
/// recovering it after lifecycle work such as boot, time-zone changes, or a
/// best-effort renewal.
///
/// A recovery pass is deliberately weaker than an authoritative foreground
/// pass: it must not race a notification that has just become due.
enum AgendaNotificationReconcileMode { authoritative, recovery }

/// Identifies whether a notification projection was performed by a foreground
/// Flutter host or the Android headless maintenance worker.
///
/// The distinction is runtime diagnostic information only. It deliberately
/// does not change reconciliation semantics, which remain governed by
/// [AgendaNotificationReconcileMode].
enum AgendaNotificationReconcileOrigin { foreground, background }

/// Terminal result recorded for the most recent notification projection.
enum AgendaNotificationDiagnosticResult { success, skipped, blocked, failed }

/// Describes how completely Android currently covers future reminders.
enum AgendaNotificationCoverage {
  /// Every known finite reminder is directly scheduled with the platform.
  ready,

  /// Infinite recurring reminders have direct coverage for the current
  /// window, then need a best-effort renewal before that window ends.
  renewable,

  /// Direct platform capacity is full; later reminders depend on renewal.
  capacityLimited,

  /// A required Android permission, channel, or battery allowlist is absent.
  blocked,

  /// Scheduling failed for a reason other than a known capability block.
  failed,
}

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
    this.coverage = AgendaNotificationCoverage.ready,
    required this.directScheduledCount,
    required this.directCapacity,
    this.hasUnboundedRecurrence = false,
    this.hasCapacityOverflow = false,
    this.retainedPendingCount = 0,
    this.lateRecoveryCount = 0,
    this.registrationDecisions = const [],
    this.duplicatePendingRemoved = 0,
    required this.plan,
    this.origin = AgendaNotificationReconcileOrigin.foreground,
    this.nextRenewalAt,
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
  final AgendaNotificationCoverage coverage;
  final int directScheduledCount;
  final int directCapacity;
  final bool hasUnboundedRecurrence;
  final bool hasCapacityOverflow;
  final int retainedPendingCount;
  final int lateRecoveryCount;
  final List<AgendaNotificationRegistrationDiagnostic> registrationDecisions;
  final int duplicatePendingRemoved;
  final List<AgendaNotificationDiagnosticPlanItem> plan;
  final DateTime? nextRenewalAt;
  final int? platformPendingCount;
  final int? platformActiveCount;
  final DateTime? platformSampledAt;
  final String? error;

  AgendaNotificationDiagnostics copyWithPlatformSnapshot(
    int pendingCount,
    int activeCount,
    DateTime sampledAt,
  ) => copyWithRegistrationDecisions(
    registrationDecisions,
    duplicatePendingRemoved,
    pendingCount: pendingCount,
    activeCount: activeCount,
    sampledAt: sampledAt,
  );

  AgendaNotificationDiagnostics copyWithRegistrationDecisions(
    List<AgendaNotificationRegistrationDiagnostic> decisions,
    int duplicates, {
    int? pendingCount,
    int? activeCount,
    DateTime? sampledAt,
  }) => AgendaNotificationDiagnostics(
    recordedAt: recordedAt,
    mode: mode,
    origin: origin,
    result: result,
    notificationsEnabled: notificationsEnabled,
    exactAlarmsAllowed: exactAlarmsAllowed,
    batteryOptimizationIgnored: batteryOptimizationIgnored,
    coverage: coverage,
    directScheduledCount: directScheduledCount,
    directCapacity: directCapacity,
    hasUnboundedRecurrence: hasUnboundedRecurrence,
    hasCapacityOverflow: hasCapacityOverflow,
    retainedPendingCount: retainedPendingCount,
    lateRecoveryCount: lateRecoveryCount,
    registrationDecisions: List.unmodifiable(decisions.take(maxPlanItems)),
    duplicatePendingRemoved: duplicates,
    plan: plan,
    nextRenewalAt: nextRenewalAt,
    platformPendingCount: pendingCount ?? platformPendingCount,
    platformActiveCount: activeCount ?? platformActiveCount,
    platformSampledAt: sampledAt ?? platformSampledAt,
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
    'coverage': coverage.name,
    'directScheduledCount': directScheduledCount,
    'directCapacity': directCapacity,
    'hasUnboundedRecurrence': hasUnboundedRecurrence,
    'hasCapacityOverflow': hasCapacityOverflow,
    'retainedPendingCount': retainedPendingCount,
    'lateRecoveryCount': lateRecoveryCount,
    'registrationDecisions': registrationDecisions
        .map((item) => item.toJson())
        .toList(),
    'duplicatePendingRemoved': duplicatePendingRemoved,
    'plan': plan.map((item) => item.toJson()).toList(growable: false),
    if (nextRenewalAt != null)
      'nextRenewalAt': nextRenewalAt!.toIso8601String(),
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
    final coverage = _parseNotificationCoverage(value['coverage']);
    final directScheduledCount = _decodeNonNegativeInt(
      value['directScheduledCount'],
    );
    final directCapacity = _decodeNonNegativeInt(value['directCapacity']);
    final retainedPendingCount = _decodeNonNegativeInt(
      value['retainedPendingCount'],
    );
    final lateRecoveryCount = _decodeNonNegativeInt(value['lateRecoveryCount']);
    if (recordedAt == null ||
        mode == null ||
        origin == null ||
        result == null ||
        value['notificationsEnabled'] is! bool ||
        value['exactAlarmsAllowed'] is! bool ||
        (value['batteryOptimizationIgnored'] != null &&
            value['batteryOptimizationIgnored'] is! bool) ||
        coverage == null ||
        directScheduledCount == null ||
        directCapacity == null ||
        value['hasUnboundedRecurrence'] is! bool ||
        value['hasCapacityOverflow'] is! bool ||
        retainedPendingCount == null ||
        lateRecoveryCount == null) {
      return null;
    }

    DateTime? decodeOptionalDate(String field) {
      final raw = value[field];
      if (raw == null) return null;
      return raw is String ? DateTime.tryParse(raw) : null;
    }

    final nextRenewalAt = decodeOptionalDate('nextRenewalAt');
    final platformSampledAt = decodeOptionalDate('platformSampledAt');
    final platformPendingCount = _decodeNullableNonNegativeInt(
      value['platformPendingCount'],
    );
    final platformActiveCount = _decodeNullableNonNegativeInt(
      value['platformActiveCount'],
    );
    if ((value['nextRenewalAt'] != null && nextRenewalAt == null) ||
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

    final rawDecisions = value['registrationDecisions'] ?? const [];
    final duplicates = _decodeNonNegativeInt(
      value['duplicatePendingRemoved'] ?? 0,
    );
    if (rawDecisions is! List ||
        rawDecisions.length > maxPlanItems ||
        duplicates == null) {
      return null;
    }
    final decisions = <AgendaNotificationRegistrationDiagnostic>[];
    for (final raw in rawDecisions) {
      final decision = AgendaNotificationRegistrationDiagnostic.tryDecode(raw);
      if (decision == null) return null;
      decisions.add(decision);
    }
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
      coverage: coverage,
      directScheduledCount: directScheduledCount,
      directCapacity: directCapacity,
      hasUnboundedRecurrence: value['hasUnboundedRecurrence'] as bool,
      hasCapacityOverflow: value['hasCapacityOverflow'] as bool,
      retainedPendingCount: retainedPendingCount,
      lateRecoveryCount: lateRecoveryCount,
      registrationDecisions: List.unmodifiable(decisions),
      duplicatePendingRemoved: duplicates,
      plan: List.unmodifiable(plan),
      nextRenewalAt: nextRenewalAt,
      platformPendingCount: platformPendingCount,
      platformActiveCount: platformActiveCount,
      platformSampledAt: platformSampledAt,
      error: rawError as String?,
    );
  }

  static const schemaVersion = 2;
  static const maxPlanItems = 32;
  static const maxErrorLength = 2048;
}

AgendaNotificationCoverage? _parseNotificationCoverage(Object? value) {
  if (value is! String) return null;
  for (final coverage in AgendaNotificationCoverage.values) {
    if (coverage.name == value) return coverage;
  }
  return null;
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

/// Optional durable evidence of registration, independent of pending/active
/// notifications and runtime cleanup. All methods are fenced; callers hold the
/// existing runtime mutation lock across the read/claim/platform/accept cycle.
abstract interface class AgendaNotificationRegistrationStore {
  Future<AgendaNotificationRegistrationSnapshot> readRegistrationSnapshot(
    AgendaNotificationProjectionFence fence, {
    required DateTime now,
  });
  Future<bool> initializeRegistrationEpoch(
    DateTime at,
    AgendaNotificationProjectionFence fence,
  );
  Future<bool> writeRegistration(
    AgendaNotificationRegistration registration,
    AgendaNotificationProjectionFence fence,
  );
  Future<bool> writeSnoozeReceipt(
    AgendaNotificationSnoozeReceipt receipt,
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

int nextAgendaNotificationGeneration(int current) {
  // Avoid wrapping to zero: a process that observes an old generation must
  // never mistake a wrapped value for a fresh one. In practice this branch is
  // unreachable, but failing closed is safer than reusing a token.
  if (current >= 0x7fffffff) return 0x7fffffff;
  return current + 1;
}
