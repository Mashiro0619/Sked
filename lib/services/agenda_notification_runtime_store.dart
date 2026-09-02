import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        AgendaNotificationBackgroundRequestStore {
  MemoryAgendaNotificationRuntimeStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, DateTime> snoozes = {};
  final Set<String> handledOccurrenceIds = {};
  final Map<String, DateTime> _handledAt = {};
  final List<AgendaNotificationAction> pendingActions = [];
  final Map<String, AgendaNotificationBackgroundRequest> backgroundRequests =
      {};

  static const maxHandledOccurrences = 256;
  static const handledTtl = Duration(days: 30);
  static const maxPendingActions = 32;
  static const pendingActionTtl = Duration(hours: 24);
  static const backgroundRequestTtl = Duration(days: 2);

  @override
  Future<Map<String, DateTime>> readSnoozes() async {
    return Map.unmodifiable(snoozes);
  }

  @override
  Future<Set<String>> readHandledOccurrenceIds() async {
    final now = _clock();
    final expired = _handledAt.entries
        .where((entry) => now.difference(entry.value) > handledTtl)
        .map((entry) => entry.key)
        .toList();
    for (final id in expired) {
      _handledAt.remove(id);
      handledOccurrenceIds.remove(id);
    }
    _trimHandled();
    return Set.unmodifiable(handledOccurrenceIds);
  }

  @override
  Future<List<AgendaNotificationAction>> readPendingActions() async {
    final now = _clock();
    pendingActions.removeWhere(
      (action) =>
          now.difference(action.enqueuedAt) > pendingActionTtl ||
          action.enqueuedAt.isAfter(now.add(const Duration(minutes: 5))),
    );
    pendingActions.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    if (pendingActions.length > maxPendingActions) {
      pendingActions.removeRange(0, pendingActions.length - maxPendingActions);
    }
    return List.unmodifiable(pendingActions);
  }

  @override
  Future<void> setSnooze(String key, DateTime fireAt) async {
    snoozes[key] = fireAt;
  }

  @override
  Future<void> removeSnooze(String key) async {
    snoozes.remove(key);
  }

  @override
  Future<void> addHandledOccurrence(String occurrenceId) async {
    if (occurrenceId.trim().isEmpty) return;
    await readHandledOccurrenceIds();
    handledOccurrenceIds.add(occurrenceId);
    _handledAt[occurrenceId] = _clock();
    _trimHandled();
  }

  @override
  Future<void> removeHandledOccurrence(String occurrenceId) async {
    handledOccurrenceIds.remove(occurrenceId);
    _handledAt.remove(occurrenceId);
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
    final id = _actionId(payload, actionId);
    final existing = pendingActions.indexWhere(
      (item) =>
          item.id == id ||
          (item.payload == payload && item.actionId == actionId),
    );
    if (existing != -1) return;
    pendingActions.add(
      AgendaNotificationAction(
        id: id,
        payload: payload,
        actionId: actionId,
        enqueuedAt: _clock(),
      ),
    );
    pendingActions.sort((a, b) => a.enqueuedAt.compareTo(b.enqueuedAt));
    if (pendingActions.length > maxPendingActions) {
      pendingActions.removeRange(0, pendingActions.length - maxPendingActions);
    }
  }

  @override
  Future<void> removePendingAction(String id) async {
    pendingActions.removeWhere((item) => item.id == id);
  }

  @override
  Future<AgendaNotificationBackgroundRequest?> readBackgroundRequest(
    String key,
  ) async => backgroundRequests[key];

  @override
  Future<void> saveBackgroundRequest(
    AgendaNotificationBackgroundRequest request,
  ) async {
    if (AgendaNotificationBackgroundRequest.tryDecode(request.toJson()) ==
        null) {
      return;
    }
    backgroundRequests[request.key] = request;
  }

  @override
  Future<void> removeBackgroundRequest(String key) async {
    backgroundRequests.remove(key);
  }

  @override
  Future<void> pruneBackgroundRequests({required DateTime now}) async {
    backgroundRequests.removeWhere(
      (_, request) => now.difference(request.fireAt) > backgroundRequestTtl,
    );
  }

  @override
  Future<void> clear() async {
    snoozes.clear();
    handledOccurrenceIds.clear();
    _handledAt.clear();
    pendingActions.clear();
    backgroundRequests.clear();
  }

  void _trimHandled() {
    if (handledOccurrenceIds.length <= maxHandledOccurrences) return;
    final timestamped = _handledAt.keys.toList()
      ..sort((a, b) => _handledAt[b]!.compareTo(_handledAt[a]!));
    final legacy =
        handledOccurrenceIds.where((id) => !_handledAt.containsKey(id)).toList()
          ..sort();
    final keep = {
      ...timestamped,
      ...legacy,
    }.take(maxHandledOccurrences).toSet();
    handledOccurrenceIds.retainAll(keep);
    _handledAt.removeWhere((id, _) => !keep.contains(id));
  }
}

/// SharedPreferences-backed runtime state used by Android and other native
/// hosts. The keys are namespaced and can be removed independently during the
/// app's clear-data flow.
class SharedPreferencesAgendaNotificationRuntimeStore
    implements
        AgendaNotificationRuntimeStore,
        AgendaNotificationActionStore,
        AgendaNotificationBackgroundRequestStore {
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
    final raw = preferences.getString(snoozeKey);
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
        await _writeSnoozes(result);
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
    try {
      final now = _clock();
      final legacy =
          preferences
              .getStringList(handledKey)
              ?.map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toSet() ??
          <String>{};
      final rawRecords = preferences.getString(handledRecordsKey);
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
        await _setStringList(handledKey, bounded.ids.toList()..sort());
        await _writeHandledRecords(bounded.timestamped);
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
    final raw = preferences.getString(actionsKey);
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
      if (dirty) await _writePendingActions(result);
      return List.unmodifiable(result);
    } on FormatException {
      return const [];
    }
  }

  @override
  Future<void> setSnooze(String key, DateTime fireAt) async {
    await _enqueueMutation(() async {
      final values = Map<String, DateTime>.from(await readSnoozes());
      values[key] = fireAt;
      await _writeSnoozes(values);
    });
  }

  @override
  Future<void> removeSnooze(String key) async {
    await _enqueueMutation(() async {
      final values = Map<String, DateTime>.from(await readSnoozes())
        ..remove(key);
      await _writeSnoozes(values);
    });
  }

  @override
  Future<void> addHandledOccurrence(String occurrenceId) async {
    await _enqueueMutation(() async {
      final values = {...await readHandledOccurrenceIds(), occurrenceId};
      final records = await _readHandledRecords();
      final now = _clock();
      for (final id in values) {
        records[id] ??= now;
      }
      records[occurrenceId] = now;
      final bounded = _limitHandledIds(values, records);
      await _setStringList(handledKey, bounded.ids.toList()..sort());
      await _writeHandledRecords(bounded.timestamped);
    });
  }

  @override
  Future<void> removeHandledOccurrence(String occurrenceId) async {
    await _enqueueMutation(() async {
      final values = {...await readHandledOccurrenceIds()}
        ..remove(occurrenceId);
      final records = await _readHandledRecords()
        ..remove(occurrenceId);
      await _setStringList(handledKey, values.toList()..sort());
      await _writeHandledRecords(records);
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
    await _enqueueMutation(() async {
      final values = (await readPendingActions()).toList();
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
      await _writePendingActions(bounded);
    });
  }

  @override
  Future<void> removePendingAction(String id) async {
    if (id.isEmpty) return;
    await _enqueueMutation(() async {
      final values = (await readPendingActions())
          .where((item) => item.id != id)
          .toList();
      await _writePendingActions(values);
    });
  }

  @override
  Future<AgendaNotificationBackgroundRequest?> readBackgroundRequest(
    String key,
  ) async {
    if (key.trim().isEmpty) return null;
    final preferences = await _preferences;
    await _reload(preferences);
    final storageKey = _backgroundRequestStorageKey(key);
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
    await _set(
      _backgroundRequestStorageKey(decoded.key),
      jsonEncode(decoded.toJson()),
    );
  }

  @override
  Future<void> removeBackgroundRequest(String key) async {
    if (key.trim().isEmpty) return;
    await _remove(_backgroundRequestStorageKey(key));
  }

  @override
  Future<void> pruneBackgroundRequests({required DateTime now}) async {
    final preferences = await _preferences;
    await _reload(preferences);
    final keys = preferences
        .getKeys()
        .where((key) => key.startsWith(backgroundRequestKeyPrefix))
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
  }

  @override
  Future<void> clear() async {
    await _enqueueMutation(() async {
      final preferences = await _preferences;
      await _remove(snoozeKey);
      await _remove(handledKey);
      await _remove(handledRecordsKey);
      await _remove(actionsKey);
      for (final key in preferences.getKeys()) {
        if (key.startsWith(backgroundRequestKeyPrefix)) {
          await _remove(key);
        }
      }
    });
  }

  Future<void> _enqueueMutation(Future<void> Function() mutation) {
    final operation = _mutationTail.then<void>(
      (_) => mutation(),
      onError: (_, _) => mutation(),
    );
    _mutationTail = operation.then<void>((_) {}, onError: (_, _) {});
    return operation;
  }

  Future<void> _writeSnoozes(Map<String, DateTime> values) async {
    final encoded = <String, String>{
      for (final entry in values.entries)
        entry.key: entry.value.toIso8601String(),
    };
    await _set(snoozeKey, jsonEncode(encoded));
  }

  Future<Map<String, DateTime>> _readHandledRecords() async {
    final preferences = await _preferences;
    final raw = preferences.getString(handledRecordsKey);
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

  Future<void> _writeHandledRecords(Map<String, DateTime> values) async {
    if (values.isEmpty) {
      await _remove(handledRecordsKey);
      return;
    }
    await _set(
      handledRecordsKey,
      jsonEncode({
        for (final entry in values.entries)
          entry.key: entry.value.toIso8601String(),
      }),
    );
  }

  Future<void> _writePendingActions(
    List<AgendaNotificationAction> values,
  ) async {
    if (values.isEmpty) {
      await _remove(actionsKey);
      return;
    }
    await _set(
      actionsKey,
      jsonEncode(values.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  Future<void> _reload(SharedPreferences preferences) async {
    try {
      await preferences.reload();
    } catch (_) {
      // Test doubles and older hosts may not implement reload. Their cached
      // values are still safe to read.
    }
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

  String _backgroundRequestStorageKey(String key) {
    final digest = sha256.convert(utf8.encode(key)).toString();
    return '$backgroundRequestKeyPrefix$digest';
  }

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
