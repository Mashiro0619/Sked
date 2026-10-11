import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stable presentation roles, never individual course, event or task ids.
enum DesktopLayoutRegion {
  resources,
  settingsNavigation,
  periodTimeSets,
  schoolSites,
  importPreview,
  themePreview,
  monthAgenda,
  monthAgendaBottom,
  allDayTimeline,
  courseEditor,
  timetableEditor,
  eventEditor,
  courseDetails,
  eventDetails,
  reminderList,
  dayAgenda,
  occurrenceList,
  calendarManager,
  categoryManager,
  categoryNameEditor,
  assistant,
}

@immutable
class PreferredRegionSize {
  const PreferredRegionSize({this.width, this.height, this.dockedWidth});

  final double? width;
  final double? height;
  final double? dockedWidth;

  bool get isEmpty => width == null && height == null && dockedWidth == null;

  /// Unspecified fields retain the other presentation mode's preference.
  /// Construct a new value when an individual field should be cleared.
  PreferredRegionSize copyWith({
    double? width,
    double? height,
    double? dockedWidth,
  }) => PreferredRegionSize(
    width: width ?? this.width,
    height: height ?? this.height,
    dockedWidth: dockedWidth ?? this.dockedWidth,
  );

  Map<String, double> toJson() => {
    'width': ?width,
    'height': ?height,
    'dockedWidth': ?dockedWidth,
  };

  @override
  bool operator ==(Object other) =>
      other is PreferredRegionSize &&
      width == other.width &&
      height == other.height &&
      dockedWidth == other.dockedWidth;

  @override
  int get hashCode => Object.hash(width, height, dockedWidth);
}

/// Device-only geometry; it never participates in AppData or app backups.
///
/// Hosts own their window and text-scale constraints. Only explicit user
/// choices belong here, not the constrained size measured during layout.
class DesktopLayoutPreferences extends ChangeNotifier {
  DesktopLayoutPreferences({
    Future<Object?> Function()? read,
    Future<bool> Function(String)? write,
    Future<bool> Function()? remove,
    this.saveDelay = const Duration(milliseconds: 200),
  }) : _read = read ?? _readStored,
       _write = write ?? _writeStored,
       _remove = remove ?? _removeStored;

  factory DesktopLayoutPreferences.memory({
    Map<DesktopLayoutRegion, PreferredRegionSize> initialValues = const {},
  }) {
    final values = {
      for (final entry in initialValues.entries)
        if (!entry.value.isEmpty) entry.key: entry.value,
    };
    Object? stored = values.isEmpty ? null : _encode(values);
    return DesktopLayoutPreferences(
        read: () async => stored,
        write: (value) async {
          stored = value;
          return true;
        },
        remove: () async {
          stored = null;
          return true;
        },
        saveDelay: Duration.zero,
      )
      .._values.addAll(values)
      .._loaded = true
      .._ready = true;
  }

  static const storageKey = 'sked.desktop.layout.v1';
  static Future<Object?> _readStored() async =>
      (await SharedPreferences.getInstance()).get(storageKey);
  static Future<bool> _writeStored(String source) async =>
      (await SharedPreferences.getInstance()).setString(storageKey, source);
  static Future<bool> _removeStored() async =>
      (await SharedPreferences.getInstance()).remove(storageKey);

  final Future<Object?> Function() _read;
  final Future<bool> Function(String) _write;
  final Future<bool> Function() _remove;
  final Duration saveDelay;
  final _values = <DesktopLayoutRegion, PreferredRegionSize>{};
  final _edits = <DesktopLayoutRegion, int>{};
  var _revision = 0;
  var _ready = false;
  var _loaded = false;
  var _disposed = false;
  var _frozen = false;
  Object? _error;
  Timer? _saveTimer;
  Future<void>? _loading;
  Future<bool>? _flushing;
  Future<void>? _clearing;

  /// A failed read still permits the app to open using default geometry.
  bool get ready => _ready;
  bool get hasError => _error != null;
  bool get hasUnsavedChanges => _edits.isNotEmpty;

  PreferredRegionSize? preferenceFor(DesktopLayoutRegion region) =>
      _values[region];

  /// Replaces one role. An empty value removes its explicit preference.
  /// Use [PreferredRegionSize.copyWith] to retain another mode's dimensions.
  void setPreferredSize(DesktopLayoutRegion region, PreferredRegionSize size) {
    if (_disposed || _frozen) return;
    for (final value in [size.width, size.height, size.dockedWidth]) {
      if (value != null && (!value.isFinite || value <= 0)) {
        throw ArgumentError.value(value, 'size', 'Must be finite and positive');
      }
    }
    final next = size.isEmpty ? null : size;
    if ((_loaded || _edits.containsKey(region)) && _values[region] == next) {
      return;
    }
    if (next == null) {
      _values.remove(region);
    } else {
      _values[region] = next;
    }
    _edits[region] = ++_revision;
    _changed();
    _scheduleSave();
  }

  Future<void> load() {
    if (_disposed || _frozen || _loaded) return Future.value();
    final pending = _loading;
    if (pending != null) return pending;
    final completion = Completer<void>();
    _loading = completion.future;
    unawaited(_performLoad(completion));
    return completion.future;
  }

  Future<void> _performLoad(Completer<void> completion) async {
    try {
      final raw = await _read();
      if (_disposed || _frozen) return;
      Map<DesktopLayoutRegion, PreferredRegionSize> stored;
      try {
        stored = _decode(raw);
        _error = null;
      } on FormatException catch (error) {
        // A known corrupt record can be replaced by the next explicit change.
        // Loading itself never writes defaults over it.
        stored = {};
        _error = error;
      }
      for (final region in _edits.keys) {
        final value = _values[region];
        if (value == null) {
          stored.remove(region);
        } else {
          stored[region] = value;
        }
      }
      _values
        ..clear()
        ..addAll(stored);
      _loaded = true;
    } catch (error) {
      // Keep explicit edits, but retry the read before writing so unread roles
      // are not lost to a temporary storage failure.
      if (!_disposed && !_frozen) _error = error;
    } finally {
      if (!_disposed && !_frozen) {
        _ready = true;
        _changed();
      }
      _loading = null;
      completion.complete();
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(saveDelay, () {
      _saveTimer = null;
      unawaited(flush());
    });
  }

  /// Flushes the latest intent, including edits accepted during an older save.
  /// Failure is reported without reverting geometry or preventing app close.
  Future<bool> flush() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final pending = _flushing;
    if (pending != null) return pending;
    if (_frozen || _disposed) return Future.value(!hasUnsavedChanges);
    final completion = Completer<bool>();
    _flushing = completion.future;
    unawaited(_performFlush(completion));
    return completion.future;
  }

  Future<bool> retry() {
    if (hasError && !hasUnsavedChanges && _flushing == null) _loaded = false;
    return flush();
  }

  Future<void> _performFlush(Completer<bool> completion) async {
    var success = false;
    try {
      await load();
      if (!_loaded || _frozen || _disposed) return;
      while (hasUnsavedChanges && !_frozen && !_disposed) {
        final revision = _revision;
        final values = Map<DesktopLayoutRegion, PreferredRegionSize>.of(
          _values,
        );
        final saved = values.isEmpty
            ? await _remove()
            : await _write(_encode(values));
        if (!saved) throw StateError('Desktop layout preference was not saved');
        _edits.removeWhere((_, editRevision) => editRevision <= revision);
        _error = null;
        _changed();
      }
      success = !hasUnsavedChanges && !hasError;
    } catch (error) {
      _error = error;
      _changed();
    } finally {
      if (success) {
        _saveTimer?.cancel();
        _saveTimer = null;
      }
      _flushing = null;
      completion.complete(success);
    }
  }

  /// Freezes synchronously, drains accepted I/O, then removes only our key.
  /// It stays frozen after a successful clear, even if process exit fails.
  Future<void> clearForDataClear() {
    final pending = _clearing;
    if (pending != null) return pending;
    _frozen = true;
    _saveTimer?.cancel();
    _saveTimer = null;
    final completion = Completer<void>();
    _clearing = completion.future;
    unawaited(_performClear(completion));
    return completion.future;
  }

  Future<void> _performClear(Completer<void> completion) async {
    try {
      await _loading;
      await _flushing;
      if (!await _remove()) {
        throw StateError('Desktop layout preference could not be cleared');
      }
      _values.clear();
      _edits.clear();
      _loaded = true;
      _ready = true;
      _error = null;
      _changed();
      completion.complete();
    } catch (error, stackTrace) {
      _error = error;
      _changed();
      completion.completeError(error, stackTrace);
    }
  }

  /// Called only when the enclosing app-data clear did not commit.
  void resumeAfterFailedDataClear() {
    if (_disposed || !_frozen) return;
    _frozen = false;
    _clearing = null;
    if (hasUnsavedChanges) _scheduleSave();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  static String _encode(Map<DesktopLayoutRegion, PreferredRegionSize> values) =>
      jsonEncode({
        'version': 1,
        'regions': {
          for (final entry in values.entries)
            entry.key.name: entry.value.toJson(),
        },
      });

  static Map<DesktopLayoutRegion, PreferredRegionSize> _decode(Object? raw) {
    if (raw == null) return {};
    if (raw is! String) {
      throw const FormatException('Desktop layout preference is not text');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['regions'] is! Map) {
      throw const FormatException('Unsupported desktop layout preference');
    }
    final records = decoded['regions'] as Map;
    final values = <DesktopLayoutRegion, PreferredRegionSize>{};
    for (final region in DesktopLayoutRegion.values) {
      final record = records[region.name];
      if (record is! Map) continue;
      final size = PreferredRegionSize(
        width: _positiveNumber(record['width']),
        height: _positiveNumber(record['height']),
        dockedWidth: _positiveNumber(record['dockedWidth']),
      );
      if (!size.isEmpty) values[region] = size;
    }
    return values;
  }

  static double? _positiveNumber(Object? value) =>
      value is num && value.isFinite && value > 0 ? value.toDouble() : null;

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }
}
