import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_preferences_models.dart';

/// Device presentation choice. Only explicit selective device backups include
/// it; AppData and legacy whole-application JSON do not.
class DeveloperUiPreferences extends ChangeNotifier {
  DeveloperUiPreferences({
    Future<bool?> Function()? read,
    Future<bool> Function(bool)? write,
    Future<bool> Function()? remove,
    this.previewDefault = const bool.fromEnvironment('SKED_AI_LAYOUT_PREVIEW'),
  }) : _read = read ?? _readStored,
       _write = write ?? _writeStored,
       _remove = remove ?? _removeStored;
  factory DeveloperUiPreferences.memory({bool visible = false}) {
    bool? stored = visible;
    return DeveloperUiPreferences(
        read: () async => stored,
        write: (value) async {
          stored = value;
          return true;
        },
        remove: () async {
          stored = null;
          return true;
        },
        previewDefault: visible,
      )
      .._visible = visible
      .._ready = true;
  }
  static const storageKey = 'sked.developer.ui.assistant_visible.v1';
  static Future<bool?> _readStored() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    return preferences.getBool(storageKey);
  }

  static Future<bool> _writeStored(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(storageKey, value);
  static Future<bool> _removeStored() async =>
      (await SharedPreferences.getInstance()).remove(storageKey);
  final Future<bool?> Function() _read;
  final Future<bool> Function(bool) _write;
  final Future<bool> Function() _remove;
  final bool previewDefault;
  bool _visible = false;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  bool _restoreFrozen = false;
  Object? _error;
  bool? _retryValue;
  Future<bool>? _pending;

  /// Legacy name/key for feature enablement, not the panel's open state.
  /// Loading/enabling it reveals the entry, never opens the panel.
  /// Closing the panel must not persist a change to this preference.
  bool get assistantVisible => _visible;
  bool get ready => _ready;
  bool get busy => _busy;
  bool get hasError => _error != null;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || _restoreFrozen) return;
    if (_busy) {
      await _pending;
      return;
    }
    if (_ready && !hasError) return;
    await _run(null);
  }

  Future<bool> setAssistantVisible(bool value) {
    if (_busy || _disposed || _restoreFrozen || !_ready) {
      return Future.value(false);
    }
    if (value == _visible && !hasError) return Future.value(true);
    return _run(value);
  }

  Future<bool> retry() => _busy || _disposed || _restoreFrozen
      ? Future.value(false)
      : _run(_retryValue);
  Future<bool> _run(bool? value) {
    _busy = true;
    _error = null;
    _retryValue = value;
    // Publish the operation before notifying, so close guards see the write.
    final operation = _perform(value);
    _pending = operation;
    _changed();
    return operation.whenComplete(() {
      if (identical(_pending, operation)) _pending = null;
    });
  }

  Future<bool> _perform(bool? value) async {
    try {
      if (value == null) {
        final stored = await _read();
        _visible = stored ?? previewDefault;
        _ready = true;
      } else {
        if (!await _write(value)) {
          throw StateError('Developer preference was not saved');
        }
        _visible = value;
      }
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _busy = false;
      _changed();
    }
  }

  Future<bool> waitForPendingSave() async {
    // A failed read has no unsaved user intent. Only writes hold window close.
    if (_retryValue == null) return true;
    return await _pending ?? !hasError;
  }

  Future<void> freezeAndDrainForRestore() async {
    if (_disposed) throw StateError('Developer preferences are unavailable');
    _restoreFrozen = true;
    await _pending;
    if (!await waitForPendingSave()) {
      throw StateError('Developer preferences have an unconfirmed save');
    }
  }

  Future<Map<String, Object?>> readBackupSnapshot() async {
    if (_disposed) throw StateError('Developer preferences are unavailable');
    await _pending;
    if (!await waitForPendingSave()) {
      throw StateError('Developer preferences have an unconfirmed save');
    }
    final stored = await _read();
    if (_busy) throw StateError('Developer preferences changed while reading');
    if (_restoreFrozen) {
      _visible = stored ?? previewDefault;
      _ready = true;
      _error = null;
      _retryValue = null;
      _changed();
    }
    return {'assistantPreviewEnabled': stored};
  }

  Future<void> restoreBackupSnapshot(
    Map<String, Object?> values, {
    required void Function() validateOwner,
  }) async {
    validateOwner();
    if (!_restoreFrozen || _disposed || _busy) {
      throw StateError('Developer preference restore does not own the store');
    }
    final target = validateDevicePreferenceValues(
      DevicePreferenceGroup.developerUi,
      values,
    );
    final enabled = target['assistantPreviewEnabled'] as bool?;
    final saved = enabled == null ? await _remove() : await _write(enabled);
    validateOwner();
    if (!saved) {
      throw StateError('Developer preference restore was not confirmed');
    }
    if ((await readBackupSnapshot())['assistantPreviewEnabled'] != enabled) {
      throw StateError(
        'Developer preference restore did not persist its target',
      );
    }
  }

  void resumeAfterBackupRestore() {
    if (!_disposed) _restoreFrozen = false;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
