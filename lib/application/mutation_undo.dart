import 'dart:convert';

import '../models/application_ledger.dart';
import '../models/timetable_models.dart';
import 'mutation_draft.dart';
import 'operation_contracts.dart';
import 'resource_contracts.dart';
import 'setting_registry.dart';

/// Compiles a host-owned receipt into an object-level reverse candidate.
/// Authorization, generation checks and durable idempotency belong to the
/// coordinator; this compiler neither writes nor looks up a receipt by ID.
class MutationUndoCompiler {
  MutationUndoCompiler({SettingRegistry? settings})
    : _settings = settings ?? SettingRegistry();

  final SettingRegistry _settings;

  MutationDraft prepare(AppData base, OperationReceipt receipt) {
    final undo = receipt.undo;
    if (undo == null) {
      throw const OperationProblem(
        OperationErrorCode.unsupported,
        'This operation has no reversible application changes.',
      );
    }
    if (undo.keys.any((key) => key != 'changes') || undo['changes'] is! List) {
      _invalidUndo('The receipt has no supported reverse change list.');
    }
    final rawChanges = undo['changes'] as List;
    if (rawChanges.length > 10000) {
      _invalidUndo('The reverse change list exceeds its admission limit.');
    }
    final changesByKey = <String, _UndoChange>{};
    for (final raw in rawChanges) {
      final change = _decodeChange(raw);
      final existing = changesByKey[change.key];
      if (existing != null) {
        if (!_sameUndoJson(existing.toJson(), change.toJson())) {
          _invalidUndo('Duplicate reverse changes disagree.');
        }
        continue;
      }
      changesByKey[change.key] = change;
    }
    final changes = _withoutCoveredChildren(changesByKey)
        .where((change) => !_sameUndoJson(change.before, change.after))
        .toList();
    if (changes.isEmpty) {
      return MutationDraft(candidate: base, changes: const []);
    }
    final original = _mutableUndoJson(base.toJson()) as Map<String, dynamic>;
    for (final change in changes) {
      if (!_sameUndoJson(_read(base, original, change), change.after)) {
        _undoConflict(
          'A changed object no longer matches the committed result.',
          change.key,
        );
      }
    }

    final rawCandidate = _mutableUndoJson(original) as Map<String, dynamic>;
    final resources = changes.where((change) => change.ref != null).toList();
    // Restore owners before touching child lists. A complete owner snapshot
    // already includes every covered child, which was checked and removed.
    _restoreResources(
      rawCandidate,
      resources.where((change) => change.ref!.parentId == null),
    );
    _restoreResources(
      rawCandidate,
      resources.where((change) => change.ref!.parentId != null),
    );
    if (resources.any((change) => change.ref!.kind == ResourceKind.calendar)) {
      final calendars =
          _undoObject(rawCandidate['generalMode'])['schedules'] as List;
      for (var index = 0; index < calendars.length; index++) {
        _undoObject(calendars[index])['sortOrder'] = index;
      }
    }
    for (final change in changes.where((change) => change.ref == null)) {
      _writeSettingOrAuxiliary(rawCandidate, change.key, change.before);
    }
    try {
      _canonicalizeOptionalSettings(rawCandidate);
    } on FormatException {
      _invalidUndo('A reverse setting has an invalid stored value.');
    }

    late final AppData candidate;
    try {
      candidate = AppData.decodeStorageSnapshot(jsonEncode(rawCandidate));
    } on FormatException {
      _undoConflict(
        'The reverse changes would leave invalid data or resource bindings.',
      );
    }
    // The legacy decoder may normalize missing bindings or incompatible data.
    // Reversal never authorizes those extra repairs, including edits to objects
    // that were added after the original operation.
    if (!_sameUndoJson(candidate.toJson(), rawCandidate)) {
      _undoConflict('The reverse changes require an unrelated data repair.');
    }
    final pureSettings = changes
        .where(
          (change) =>
              change.ref == null && !_undoAuxiliaryKeys.contains(change.key),
        )
        .toList();
    try {
      // Validate the final setting values together against the restored
      // resources. Discard this validation candidate: ordinary setters may
      // intentionally derive flags that a complete reverse receipt restores.
      _settings.prepare(candidate, [
        for (final change in pureSettings)
          SettingEdit.set(change.key, change.before),
      ]);
    } on SettingValidationException {
      _invalidUndo('A reverse setting is outside its registered contract.');
    }
    final restored = candidate.toJson();
    for (final change in changes) {
      if (!_sameUndoJson(_read(candidate, restored, change), change.before)) {
        _undoConflict(
          'The recorded object cannot be restored exactly.',
          change.key,
        );
      }
    }
    final reverseChanges = [
      for (final change in changes)
        ResourceChange(
          key: change.key,
          ref: change.ref,
          before: change.after,
          after: change.before,
        ),
      ..._additionalCalendarPositions(
        base,
        candidate,
        changesByKey.keys.toSet(),
      ),
    ];
    final parentKeys = reverseChanges
        .where((change) => change.ref != null && change.ref!.parentId == null)
        .map((change) => change.key)
        .toSet();
    return MutationDraft(
      candidate: candidate,
      changes: reverseChanges.where((change) {
        final ref = change.ref;
        if (ref?.parentId == null) return true;
        final parent = ResourceRef(
          kind: ref!.kind == ResourceKind.course
              ? ResourceKind.timetable
              : ResourceKind.calendar,
          id: ref.parentId!,
        );
        return !parentKeys.contains(resourceChangeKey(parent));
      }).toList(),
    );
  }

  _UndoChange _decodeChange(Object? raw) {
    final json = _undoObject(raw);
    if (json.keys.any(
          (key) => !const {
            'key',
            'ref',
            'before',
            'after',
            'beforeIndex',
          }.contains(key),
        ) ||
        json['key'] is! String ||
        !json.containsKey('before') ||
        !json.containsKey('after')) {
      _invalidUndo('A reverse change is incomplete or has unknown fields.');
    }
    final key = json['key'] as String;
    ResourceRef? ref;
    int? beforeIndex;
    if (json['ref'] != null) {
      final target = _undoObject(json['ref']);
      if (target.keys.any(
            (key) => !const {'kind', 'id', 'parentId'}.contains(key),
          ) ||
          target['id'] is! String) {
        _invalidUndo('A reverse resource reference is invalid.');
      }
      final kind = ResourceKind.values
          .where((kind) => kind.name == target['kind'])
          .firstOrNull;
      if (kind == null || kind == ResourceKind.occurrence) {
        _invalidUndo('Reverse records require persisted resource identities.');
      }
      final child = kind == ResourceKind.course || kind == ResourceKind.event;
      if (child ? target['parentId'] is! String : target['parentId'] != null) {
        _invalidUndo('A reverse resource reference has the wrong owner.');
      }
      ref = ResourceRef(
        kind: kind,
        id: target['id'] as String,
        parentId: target['parentId'] as String?,
      );
      if (ref.id.trim().isEmpty ||
          ref.id != ref.id.trim() ||
          (ref.parentId != null &&
              (ref.parentId!.trim().isEmpty ||
                  ref.parentId != ref.parentId!.trim())) ||
          key != resourceChangeKey(ref)) {
        _invalidUndo(
          'A reverse resource key does not match its exact reference.',
        );
      }
      if (!json.containsKey('beforeIndex') ||
          (json['before'] == null
              ? json['beforeIndex'] != null
              : json['beforeIndex'] is! int ||
                    (json['beforeIndex'] as int) < 0)) {
        _invalidUndo('A reverse resource needs its original list position.');
      }
      beforeIndex = json['beforeIndex'] as int?;
      _validateResourceIdentity(json['before'], ref);
      _validateResourceIdentity(json['after'], ref);
      if (json['before'] == null && json['after'] == null) {
        _invalidUndo('An absent resource cannot be a reverse change.');
      }
    } else {
      if (json.containsKey('beforeIndex')) {
        _invalidUndo('Only resource changes have list positions.');
      }
      if (!_undoAuxiliaryKeys.contains(key)) {
        try {
          final descriptor = _settings.descriptor(key);
          if (!descriptor.canPrepare || descriptor.sensitive) {
            _invalidUndo('This setting requires its owning workflow.');
          }
        } on SettingValidationException {
          _invalidUndo('The reverse setting is not registered.');
        }
      }
      _settingStorageField(key);
    }
    return _UndoChange(key, ref, json['before'], json['after'], beforeIndex);
  }

  Object? _read(AppData data, Map<String, dynamic> json, _UndoChange change) {
    final ref = change.ref;
    if (ref != null) {
      final matches = (_resourceList(json, ref) ?? const <Object?>[])
          .where((item) => _undoObject(item)['id'] == ref.id)
          .toList();
      if (matches.length > 1) {
        _undoConflict('The resource identity is ambiguous.', change.key);
      }
      return matches.firstOrNull;
    }
    if (change.key == 'general.reminderAcknowledgements') {
      return data.generalMode.reminderAcknowledgements
          .map((item) => item.toJson())
          .toList();
    }
    return _settings.read(data, change.key);
  }
}

const _undoAuxiliaryKeys = {
  'general.activeScheduleId',
  'general.reminderAcknowledgements',
  'student.activeTimetableId',
  'student.conflictDisplayCourseIds',
  'student.courseNameColorValues',
  'student.liveCourseOutlineCustomColorInitialized',
};

class _UndoChange {
  const _UndoChange(
    this.key,
    this.ref,
    this.before,
    this.after,
    this.beforeIndex,
  );
  final String key;
  final ResourceRef? ref;
  final Object? before;
  final Object? after;
  final int? beforeIndex;
  Map<String, Object?> toJson() => {
    'key': key,
    'ref': ref?.toJson(),
    'before': before,
    'after': after,
    'beforeIndex': beforeIndex,
  };
}

List<_UndoChange> _withoutCoveredChildren(Map<String, _UndoChange> byKey) {
  final result = <_UndoChange>[];
  for (final change in byKey.values) {
    final ref = change.ref;
    if (ref != null && ref.parentId != null) {
      final parentRef = ResourceRef(
        kind: ref.kind == ResourceKind.course
            ? ResourceKind.timetable
            : ResourceKind.calendar,
        id: ref.parentId!,
      );
      final parent = byKey[resourceChangeKey(parentRef)];
      if (parent != null) {
        final childKey = ref.kind == ResourceKind.course ? 'courses' : 'events';
        Object? embedded(Object? value) {
          if (value == null) return null;
          final children = _undoObject(value)[childKey];
          if (children is! List) {
            _invalidUndo('A reverse owner snapshot has no child list.');
          }
          final matches = children
              .where((child) => _undoObject(child)['id'] == ref.id)
              .toList();
          if (matches.length > 1) {
            _invalidUndo('A reverse owner contains ambiguous children.');
          }
          return matches.firstOrNull;
        }

        if (!_sameUndoJson(embedded(parent.before), change.before) ||
            !_sameUndoJson(embedded(parent.after), change.after)) {
          _invalidUndo(
            'A reverse owner snapshot disagrees with its child change.',
          );
        }
        if (change.before != null) {
          final children = _undoObject(parent.before)[childKey] as List;
          if (children.indexWhere(
                (child) => _undoObject(child)['id'] == ref.id,
              ) !=
              change.beforeIndex) {
            _invalidUndo('A child position disagrees with its owner snapshot.');
          }
        }
        continue;
      }
    }
    result.add(change);
  }
  return result;
}

List<ResourceChange> _additionalCalendarPositions(
  AppData before,
  AppData after,
  Set<String> recordedKeys,
) {
  final previous = {
    for (final calendar in before.generalMode.schedules) calendar.id: calendar,
  };
  return [
    for (final calendar in after.generalMode.schedules)
      if (previous[calendar.id] != null &&
          previous[calendar.id]!.sortOrder != calendar.sortOrder &&
          !recordedKeys.contains(
            resourceChangeKey(
              ResourceRef(kind: ResourceKind.calendar, id: calendar.id),
            ),
          ))
        ResourceChange(
          key: resourceChangeKey(
            ResourceRef(kind: ResourceKind.calendar, id: calendar.id),
          ),
          ref: ResourceRef(kind: ResourceKind.calendar, id: calendar.id),
          before: previous[calendar.id]!.toJson(),
          after: calendar.toJson(),
        ),
  ];
}

void _validateResourceIdentity(Object? value, ResourceRef ref) {
  if (value == null) return;
  final resource = _undoObject(value);
  if (resource['id'] != ref.id ||
      (ref.kind == ResourceKind.event &&
          resource['calendarId'] != ref.parentId)) {
    _invalidUndo('The reverse snapshot belongs to a different resource.');
  }
}

List<dynamic>? _resourceList(Map<String, dynamic> json, ResourceRef ref) {
  final student = _undoObject(json['studentMode']);
  final general = _undoObject(json['generalMode']);
  if (ref.parentId == null) {
    return switch (ref.kind) {
      ResourceKind.timetable => student['timetables'] as List,
      ResourceKind.periodTimeSet => student['periodTimeSets'] as List,
      ResourceKind.calendar => general['schedules'] as List,
      _ => _invalidUndo('This resource has no supported reverse list.'),
    };
  }
  final parents =
      (ref.kind == ResourceKind.course
              ? student['timetables']
              : general['schedules'])
          as List;
  final matches = parents
      .where((item) => _undoObject(item)['id'] == ref.parentId)
      .toList();
  if (matches.length > 1) {
    _undoConflict('The owning resource identity is ambiguous.');
  }
  if (matches.isEmpty) return null;
  final parent = _undoObject(matches.single);
  return parent[ref.kind == ResourceKind.course ? 'courses' : 'events'] as List;
}

void _restoreResources(
  Map<String, dynamic> json,
  Iterable<_UndoChange> changes,
) {
  final groups = <String, List<_UndoChange>>{};
  for (final change in changes) {
    final ref = change.ref!;
    final groupKey =
        '${ref.kind.name}:${Uri.encodeComponent(ref.parentId ?? '')}';
    groups.putIfAbsent(groupKey, () => []).add(change);
  }
  for (final group in groups.values) {
    final list = _resourceList(json, group.first.ref!);
    if (list == null) {
      _undoConflict(
        'The original owning resource is no longer available.',
        group.first.key,
      );
    }
    final changedIds = group.map((change) => change.ref!.id).toSet();
    list.removeWhere((item) => changedIds.contains(_undoObject(item)['id']));
    final restored = group.where((change) => change.before != null).toList()
      ..sort((left, right) => left.beforeIndex!.compareTo(right.beforeIndex!));
    final usedPositions = <int>{};
    for (final change in restored) {
      if (!usedPositions.add(change.beforeIndex!)) {
        _invalidUndo(
          'Reverse resources disagree about their original positions.',
        );
      }
      final index = change.beforeIndex!.clamp(0, list.length);
      list.insert(index, _mutableUndoJson(change.before));
    }
  }
}

({String? container, String field}) _settingStorageField(String key) {
  if (key.startsWith('agent.')) {
    return (container: 'agentSettings', field: key.substring('agent.'.length));
  }
  if (key.startsWith('student.')) {
    return (container: 'studentMode', field: key.substring('student.'.length));
  }
  if (key.startsWith('general.')) {
    return (container: 'generalMode', field: key.substring('general.'.length));
  }
  if (key.startsWith('app.notifications.')) {
    return (
      container: 'notificationSettings',
      field: key.substring('app.notifications.'.length),
    );
  }
  return (
    container: null,
    field: switch (key) {
      'app.hideHomeWorkspaceNavigation' => 'hideHomeBottomNavigationBar',
      'app.homeWorkspaceNavigationCollapsed' =>
        'homeWorkspaceNavigationCollapsed',
      'app.localeCode' => 'localeCode',
      'app.workspacePanelDisplayMode' => 'workspacePanelDisplayMode',
      'app.includePrereleaseUpdates' => 'includePrereleaseUpdates',
      'app.ignoredUpdateVersion' => 'ignoredUpdateVersion',
      _ => _invalidUndo('This setting has no supported reverse storage field.'),
    },
  );
}

void _writeSettingOrAuxiliary(
  Map<String, dynamic> json,
  String key,
  Object? value,
) {
  final path = _settingStorageField(key);
  Map<String, dynamic> container;
  if (path.container == null) {
    container = json;
  } else {
    if (path.container == 'notificationSettings' &&
        json[path.container] == null) {
      json[path.container!] = const NotificationSettings().toJson();
    }
    container = _undoObject(json[path.container]);
  }
  if (value == null &&
      key != 'app.notifications.courseDefaultMinutesBefore' &&
      key != 'app.notifications.generalDefaultMinutesBefore') {
    container.remove(path.field);
  } else {
    container[path.field] = _mutableUndoJson(value);
  }
}

void _canonicalizeOptionalSettings(Map<String, dynamic> json) {
  if (json['workspacePanelDisplayMode'] == 'overlay') {
    json.remove('workspacePanelDisplayMode');
  }
  final notifications = json['notificationSettings'];
  if (notifications != null) {
    final parsed = NotificationSettings.fromJson(_undoObject(notifications));
    if (parsed == const NotificationSettings()) {
      json.remove('notificationSettings');
    } else if (parsed.remindHiddenGeneralCalendars == false) {
      _undoObject(notifications).remove('remindHiddenGeneralCalendars');
    }
  }
}

Map<String, dynamic> _undoObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    _invalidUndo('Expected a reverse JSON object.');
  }
  return value.cast<String, dynamic>();
}

Object? _mutableUndoJson(Object? value) => jsonDecode(jsonEncode(value));

bool _sameUndoJson(Object? left, Object? right) {
  Object? canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.cast<String>().toList()..sort();
      return {for (final key in keys) key: canonical(value[key])};
    }
    if (value is List) return [for (final item in value) canonical(item)];
    return value;
  }

  return jsonEncode(canonical(left)) == jsonEncode(canonical(right));
}

Never _invalidUndo(String message) => throw OperationProblem(
  OperationErrorCode.invalidArgument,
  message,
  field: 'undo',
);
Never _undoConflict(String message, [String? key]) =>
    throw OperationProblem(OperationErrorCode.conflict, message, field: key);
