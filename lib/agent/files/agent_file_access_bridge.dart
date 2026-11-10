import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../utils/unique_id.dart';
import '../bridge/generated/api/file_contracts.dart';

/// Queries Android's current permissions and the resources selected by its
/// document picker. Interactive methods are reserved for application UI.
class AgentFileAccessBridge {
  AgentFileAccessBridge({
    MethodChannel? channel,
    bool? supported,
    bool Function()? canInteract,
  }) : _channel = channel ?? const MethodChannel(channelName),
       isSupported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
       _canInteract = canInteract ?? (() => true);

  static const channelName = 'com.mashiro.sked/agent_file_access';
  final MethodChannel _channel;
  final bool isSupported;
  final bool Function() _canInteract;
  final String _lifetimeId = generateUuidV4();
  final _owners = <String>{};
  final _pending = <Future<void>>{};
  bool _closed = false;
  Future<void>? _closing;

  bool get isAvailable => isSupported && !_closed && _canInteract();

  Future<AgentFileAccessStatus> status() async {
    _checkAvailable();
    return AgentFileAccessStatus.decode(await _invoke('status'));
  }

  Future<AgentFileAccessResult> requestAccess(String ownerId) =>
      _interact('requestAccess', ownerId);

  Future<AgentFileAccessResult> pickDocument(String ownerId) =>
      _interact('pickDocument', ownerId);

  Future<AgentFileAccessResult> pickDirectory(String ownerId) =>
      _interact('pickDirectory', ownerId);

  Future<AgentFileAccessStatus> releaseGrant(String grantId) async {
    _checkAvailable();
    return AgentFileAccessStatus.decode(
      await _invoke('releaseGrant', {'grantId': grantId}),
    );
  }

  Future<AgentFileAccessResult> _interact(String method, String ownerId) {
    _checkAvailable();
    if (!_owners.add(ownerId)) {
      throw StateError('This file access task already has a pending request.');
    }
    return () async {
      try {
        return AgentFileAccessResult.decode(
          await _invoke(method, {'ownerId': ownerId}),
        );
      } finally {
        _owners.remove(ownerId);
      }
    }();
  }

  Future<void> cancelPending(String ownerId) async {
    if (!isSupported) return;
    await _invoke('cancelPending', {'ownerId': ownerId});
  }

  /// Native cleanup invalidates old picker results before releasing only this
  /// file service's grants. It remains callable during application maintenance.
  Future<void> clearGrants() async {
    if (!isSupported) return;
    AgentFileAccessStatus.decode(await _invoke('clearGrants'));
    await _drain();
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    Object? failure;
    StackTrace? failureStack;
    // A native owner cancellation also waits for retired-engine cleanup. The
    // bridge's own lifetime participates even when no picker is currently open.
    for (final owner in [..._owners, _lifetimeId]) {
      try {
        await cancelPending(owner);
      } catch (error, stack) {
        failure ??= error;
        failureStack ??= stack;
      }
    }
    await _drain();
    if (failure != null) Error.throwWithStackTrace(failure, failureStack!);
  }

  Future<void> _drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  Future<Object?> _invoke(String method, [Map<String, Object?>? arguments]) {
    final result = _channel.invokeMethod<Object?>(method, arguments);
    late final Future<void> marker;
    marker = result
        .then<void>((_) {}, onError: (Object _, StackTrace _) {})
        .whenComplete(() => _pending.remove(marker));
    _pending.add(marker);
    return result;
  }

  void _checkAvailable() {
    if (!isAvailable) {
      throw StateError('File access settings are unavailable.');
    }
  }
}

class AgentFileAccessStatus {
  AgentFileAccessStatus._(this._value, this.resources);

  factory AgentFileAccessStatus.decode(Object? value) {
    final data = _map(value);
    if (data['platform'] != 'android' ||
        data['sdkInt'] is! int ||
        data['resources'] is! List) {
      throw const FormatException('Invalid Android file access status.');
    }
    for (final key in [
      'allFilesAccess',
      'legacyStorage',
      'readExternalStorage',
      'writeExternalStorage',
      'pathRead',
      'pathWrite',
    ]) {
      _flag(data, key);
    }
    final resources = List<AgentFileGrant>.unmodifiable(
      (data['resources']! as List).map(AgentFileGrant.decode),
    );
    return AgentFileAccessStatus._(Map.unmodifiable(data), resources);
  }

  final Map<String, Object?> _value;
  final List<AgentFileGrant> resources;
  int get sdkInt => _value['sdkInt']! as int;
  bool get allFilesAccess => _value['allFilesAccess']! as bool;
  bool get legacyStorage => _value['legacyStorage']! as bool;
  bool get pathRead => _value['pathRead']! as bool;
  bool get pathWrite => _value['pathWrite']! as bool;

  Map<String, Object?> toJson() => {
    ..._value,
    'resources': [for (final resource in resources) resource.toJson()],
  };
}

class AgentFileGrant {
  AgentFileGrant._(this._value, this.resource, this.kind);

  factory AgentFileGrant.decode(Object? value) {
    final data = _map(value);
    _text(data, 'grantId');
    final uri = _text(data, 'uri');
    final rawResource = _map(data['resource']);
    final location = _text(rawResource, 'value');
    if (rawResource['kind'] != FileResourceKind.contentUri.name ||
        Uri.tryParse(uri)?.scheme != 'content' ||
        Uri.tryParse(location)?.scheme != 'content') {
      throw const FormatException('Invalid selected document resource.');
    }
    final kind = FileKind.values
        .where((kind) => kind.name == data['kind'])
        .firstOrNull;
    if (kind == null) throw const FormatException('Invalid document kind.');
    for (final key in [
      'read',
      'write',
      'persistedRead',
      'persistedWrite',
      'persisted',
      'ownedRead',
      'ownedWrite',
      'persistable',
      'available',
    ]) {
      _flag(data, key);
    }
    for (final key in ['name', 'mimeType', 'persistenceError']) {
      if (data[key] != null && data[key] is! String) {
        throw const FormatException('Invalid document metadata.');
      }
    }
    final capabilities = _map(data['capabilities']);
    for (final key in ['read', 'list', 'create', 'modify']) {
      _flag(capabilities, key);
    }
    final error = data['error'];
    if (error != null) {
      final details = _map(error);
      _text(details, 'code');
      _text(details, 'message');
      if (details['osCode'] != null && details['osCode'] is! int) {
        throw const FormatException('Invalid document error.');
      }
      data['error'] = Map<String, Object?>.unmodifiable(details);
    }
    data['capabilities'] = Map<String, Object?>.unmodifiable(capabilities);
    data['resource'] = Map<String, Object?>.unmodifiable(rawResource);
    return AgentFileGrant._(
      Map.unmodifiable(data),
      FileResourceRef(kind: FileResourceKind.contentUri, value: location),
      kind,
    );
  }

  final Map<String, Object?> _value;
  final FileResourceRef resource;
  final FileKind kind;
  String get grantId => _value['grantId']! as String;
  String? get name => _value['name'] as String?;
  bool get read => _value['read']! as bool;
  bool get write => _value['write']! as bool;
  bool get persisted => _value['persisted']! as bool;
  bool get available => _value['available']! as bool;
  String? get errorMessage => (_value['error'] as Map?)?['message'] as String?;
  Map<String, Object?> toJson() => Map.of(_value);
}

class AgentFileAccessResult {
  AgentFileAccessResult._(this.cancelled, this.status, this.resource);

  factory AgentFileAccessResult.decode(Object? value) {
    final data = _map(value);
    return AgentFileAccessResult._(
      _flag(data, 'cancelled'),
      AgentFileAccessStatus.decode(data['status']),
      data['resource'] == null ? null : AgentFileGrant.decode(data['resource']),
    );
  }

  final bool cancelled;
  final AgentFileAccessStatus status;
  final AgentFileGrant? resource;
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Invalid file access response.');
  }
  return Map<String, Object?>.from(value);
}

bool _flag(Map<String, Object?> value, String key) {
  final flag = value[key];
  if (flag is! bool) throw const FormatException('Invalid file access flag.');
  return flag;
}

String _text(Map<String, Object?> value, String key) {
  final text = value[key];
  if (text is! String || text.isEmpty) {
    throw const FormatException('Invalid file access identity.');
  }
  return text;
}
