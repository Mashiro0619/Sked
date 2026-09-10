import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-only presentation choice: never serialized in AppData or a backup.
class DeveloperUiPreferences extends ChangeNotifier {
  DeveloperUiPreferences({
    Future<bool?> Function()? read,
    Future<bool> Function(bool)? write,
    this.previewDefault = const bool.fromEnvironment('SKED_AI_LAYOUT_PREVIEW'),
  }) : _read = read ?? _readStored,
       _write = write ?? _writeStored;
  factory DeveloperUiPreferences.memory({bool visible = false}) =>
      DeveloperUiPreferences(
          read: () async => visible,
          write: (value) async {
            visible = value;
            return true;
          },
          previewDefault: visible,
        )
        .._visible = visible
        .._ready = true;
  static const storageKey = 'sked.developer.ui.assistant_visible.v1';
  static Future<bool?> _readStored() async =>
      (await SharedPreferences.getInstance()).getBool(storageKey);
  static Future<bool> _writeStored(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(storageKey, value);
  final Future<bool?> Function() _read;
  final Future<bool> Function(bool) _write;
  final bool previewDefault;
  bool _visible = false;
  bool _ready = false;
  bool _busy = false;
  bool _disposed = false;
  Object? _error;
  bool? _retryValue;
  Future<bool>? _pending;
  bool get assistantVisible => _visible;
  bool get ready => _ready;
  bool get busy => _busy;
  bool get hasError => _error != null;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    if (_busy) {
      await _pending;
      return;
    }
    if (_ready && !hasError) return;
    await _run(null);
  }

  Future<bool> setAssistantVisible(bool value) {
    if (_busy || _disposed || !_ready) return Future.value(false);
    if (value == _visible && !hasError) return Future.value(true);
    return _run(value);
  }

  Future<bool> retry() =>
      _busy || _disposed ? Future.value(false) : _run(_retryValue);
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

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
