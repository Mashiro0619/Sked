import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agenda_notification_identity.dart';
import 'agenda_notification_runtime_contract.dart';
import 'agenda_runtime_mutation_lock.dart';

export 'agenda_notification_runtime_contract.dart';
export 'agenda_notification_memory_store.dart';

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
        AgendaNotificationFencedRuntimeStore,
        AgendaNotificationRegistrationStore {
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

  // Intentionally outside runtimeGenerationKeyPrefix: clearRuntime must not
  // erase evidence of an already submitted reminder. Data clear changes fence.
  static const registrationKeyPrefix = 'sked.notification.registration.v1.';
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
        final canonicalId = runtimeNotificationActionId(
          action.payload,
          action.actionId,
        );
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
      // This mutation owns the queue. Public reads may enqueue stale-entry
      // cleanup, which would wait behind this same operation forever.
      final values = Map<String, DateTime>.from(
        await _readSnoozesForFence(preferences, fence),
      )..remove(key);
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
      final values = {
        ...await _readHandledOccurrenceIdsForFence(
          preferences,
          fence,
          persistCleanup: false,
        ),
      }..remove(occurrenceId);
      final records = await _readHandledRecords(fence)
        ..remove(occurrenceId);
      final now = _clock();
      for (final id in values) {
        records[id] ??= now;
      }
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
      final values = (await _readPendingActionsForFence(
        preferences,
        fence,
      )).where((item) => item.id != id).toList();
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
      final id = runtimeNotificationActionId(payload, actionId);
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
        generation: nextAgendaNotificationGeneration(current.generation),
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
        generation: nextAgendaNotificationGeneration(current.generation),
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

  String _registrationPrefix(AgendaNotificationProjectionFence fence) =>
      '${registrationKeyPrefix}g${fence.generation}.';
  String _registrationKey(
    AgendaNotificationRegistration registration,
    AgendaNotificationProjectionFence fence,
  ) =>
      '${_registrationPrefix(fence)}entry.${sha256.convert(utf8.encode(registration.identity))}';

  @override
  Future<AgendaNotificationRegistrationSnapshot> readRegistrationSnapshot(
    AgendaNotificationProjectionFence fence, {
    required DateTime now,
  }) async {
    var result = const AgendaNotificationRegistrationSnapshot();
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final prefix = _registrationPrefix(fence);
      final epochKey = '${prefix}epoch';
      final rawEpoch = preferences.getString(epochKey);
      final epoch = rawEpoch == null
          ? null
          : DateTime.tryParse(rawEpoch)?.toUtc();
      if (rawEpoch != null && epoch == null) {
        throw AgendaNotificationRuntimeStorageException(epochKey);
      }
      final records = <String, AgendaNotificationRegistration>{};
      final actions = <String, AgendaNotificationSnoozeReceipt>{};
      for (final key in preferences.getKeys()) {
        if (!key.startsWith(registrationKeyPrefix)) continue;
        if (!key.startsWith(prefix)) {
          await _remove(key);
          continue;
        }
        if (key == epochKey) continue;
        final raw = preferences.getString(key);
        Object? value;
        try {
          value = raw == null ? null : jsonDecode(raw);
        } on FormatException {
          throw AgendaNotificationRuntimeStorageException(key);
        }
        if (key.startsWith('${prefix}entry.')) {
          final record = AgendaNotificationRegistration.tryDecode(value);
          if (record == null || _registrationKey(record, fence) != key) {
            throw AgendaNotificationRuntimeStorageException(key);
          }
          if (now.isAfter(record.expiresAt)) {
            await _remove(key);
          } else {
            records[record.identity] = record;
          }
        } else if (key.startsWith('${prefix}action.')) {
          final receipt = AgendaNotificationSnoozeReceipt.tryDecode(value);
          if (receipt == null ||
              key != '${prefix}action.${receipt.actionIdentity}') {
            throw AgendaNotificationRuntimeStorageException(key);
          }
          if (now.isAfter(receipt.expiresAt)) {
            await _remove(key);
          } else {
            actions[receipt.actionIdentity] = receipt;
          }
        } else {
          throw AgendaNotificationRuntimeStorageException(key);
        }
      }
      result = AgendaNotificationRegistrationSnapshot(
        initializedAt: epoch,
        records: Map.unmodifiable(records),
        snoozeReceipts: Map.unmodifiable(actions),
      );
    });
    return result;
  }

  @override
  Future<bool> initializeRegistrationEpoch(
    DateTime at,
    AgendaNotificationProjectionFence fence,
  ) async {
    var saved = false;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      final key = '${_registrationPrefix(fence)}epoch';
      if (!preferences.containsKey(key)) {
        await _set(key, at.toUtc().toIso8601String());
      }
      saved = true;
    });
    return saved;
  }

  @override
  Future<bool> writeRegistration(
    AgendaNotificationRegistration registration,
    AgendaNotificationProjectionFence fence,
  ) async {
    final valid = AgendaNotificationRegistration.tryDecode(
      registration.toJson(),
    );
    if (valid == null) {
      throw const FormatException('Invalid notification registration');
    }
    return _writeRegistrationValue(
      _registrationKey(valid, fence),
      valid.toJson(),
      fence,
    );
  }

  @override
  Future<bool> writeSnoozeReceipt(
    AgendaNotificationSnoozeReceipt receipt,
    AgendaNotificationProjectionFence fence,
  ) async {
    final valid = AgendaNotificationSnoozeReceipt.tryDecode(receipt.toJson());
    if (valid == null) throw const FormatException('Invalid snooze receipt');
    return _writeRegistrationValue(
      '${_registrationPrefix(fence)}action.${valid.actionIdentity}',
      valid.toJson(),
      fence,
    );
  }

  Future<bool> _writeRegistrationValue(
    String key,
    Map<String, Object?> value,
    AgendaNotificationProjectionFence fence,
  ) async {
    var saved = false;
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _reload(preferences);
      if (!_isCurrentWritableFence(preferences, fence)) return;
      await _set(key, jsonEncode(value));
      saved = true;
    });
    return saved;
  }

  Future<void> _enqueueMutation(Future<void> Function() mutation) =>
      withAgendaRuntimeMutationLock(() {
        // Always acquire the cross-engine lock before reserving this instance's
        // queue. Otherwise an outside writer can reserve the tail while waiting
        // for a reconcile that owns the global lock and needs this same store.
        // The local tail still serializes concurrent work in a reentrant zone.
        final operation = _mutationTail.then<void>(
          (_) => mutation(),
          onError: (_, _) => mutation(),
        );
        _mutationTail = operation.then<void>((_) {}, onError: (_, _) {});
        return operation;
      });

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
        final id = runtimeNotificationActionId(action.payload, action.actionId);
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

AgendaNotificationProjectionFence _blockedProjectionFence() =>
    const AgendaNotificationProjectionFence(generation: 0, blocked: true);

class _HandledLimit {
  const _HandledLimit({required this.ids, required this.timestamped});

  final Set<String> ids;
  final Map<String, DateTime> timestamped;
}
