import 'dart:async';

import 'package:material_ui/material_ui.dart';

enum ReminderDetailMode { hidden, preview, independent }

/// One detail per workspace, temporarily anchored or independently displayed. No routes, persistence or data writes.
class ReminderDetailSessionController extends ChangeNotifier {
  ReminderDetailSessionController({
    Timer Function(Duration, VoidCallback)? createTimer,
  }) : _createTimer = createTimer ?? Timer.new;
  final Timer Function(Duration, VoidCallback) _createTimer;
  ReminderDetailMode mode = ReminderDetailMode.hidden;
  String? selectedKey;
  int revision = 0;
  bool busy = false, childTask = false;
  Offset? manualPosition;
  String? _hovered, _candidate, _suppressed;
  bool _inPanel = false;
  Timer? _openTimer, _closeTimer;
  bool get visible => mode != ReminderDetailMode.hidden;
  bool get independent => mode == ReminderDetailMode.independent;
  bool get blocked => busy || childTask;
  bool isCurrent(int version, String key) =>
      visible && revision == version && selectedKey == key;

  void enterRow(String key) {
    _hovered = key;
    if (independent || blocked || _suppressed == key) return;
    _closeTimer?.cancel();
    if (selectedKey == key && visible) {
      _cancelCandidate();
      return;
    }
    _cancelCandidate();
    _candidate = key;
    _openTimer = _createTimer(const Duration(milliseconds: 300), () {
      if (_hovered != key || _candidate != key || independent || blocked) {
        return;
      }
      _candidate = null;
      _select(key, ReminderDetailMode.preview);
    });
  }

  void leaveRow(String key) {
    if (_suppressed == key) _suppressed = null;
    if (_hovered == key) _hovered = null;
    if (_candidate == key) _cancelCandidate();
    _scheduleClose();
  }

  void enterPanel() {
    _inPanel = true;
    _cancelCandidate();
    _closeTimer?.cancel();
  }

  void leavePanel() {
    _inPanel = false;
    _scheduleClose();
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    if (mode != ReminderDetailMode.preview || _inPanel || _hovered != null) {
      return;
    }
    _closeTimer = _createTimer(const Duration(milliseconds: 200), () {
      if (!_inPanel && _hovered == null && mode == ReminderDetailMode.preview) {
        close(explicit: false);
      }
    });
  }

  bool detach([String? key]) {
    final target = key ?? selectedKey;
    if (target == null || blocked) return false;
    _cancelCandidate();
    _closeTimer?.cancel();
    _select(target, ReminderDetailMode.independent);
    return true;
  }

  void _select(String key, ReminderDetailMode next) {
    if (selectedKey != key) {
      revision++;
      selectedKey = key;
      busy = childTask = false;
    }
    mode = next;
    notifyListeners();
  }

  void setBusy(bool value) {
    if (busy != value) {
      busy = value;
      notifyListeners();
    }
  }

  void setChildTask(bool value) {
    if (childTask != value) {
      childTask = value;
      notifyListeners();
    }
  }

  void moveTo(Offset value) {
    if (!independent || blocked) return;
    manualPosition = value;
    notifyListeners();
  }

  bool close({bool explicit = true, bool force = false}) {
    if (!visible) {
      if (force) {
        _cancelCandidate();
        _closeTimer?.cancel();
        revision++;
      }
      return false;
    }
    if (blocked && !force) return false;
    _suppressed = explicit ? _hovered : null;
    _cancelCandidate();
    _closeTimer?.cancel();
    mode = ReminderDetailMode.hidden;
    selectedKey = null;
    manualPosition = null;
    busy = childTask = _inPanel = false;
    revision++;
    notifyListeners();
    return true;
  }

  /// Retire a changed list context without affecting an independent window or
  /// the open timer belonging to a candidate in another list.
  void invalidateHoverRows(Set<String> keys) {
    final hoveredWasRemoved = keys.contains(_hovered);
    if (hoveredWasRemoved) _hovered = null;
    if (keys.contains(_suppressed)) _suppressed = null;
    if (keys.contains(_candidate)) _cancelCandidate();
    if (mode == ReminderDetailMode.preview && keys.contains(selectedKey)) {
      _closeTimer?.cancel();
      mode = ReminderDetailMode.hidden;
      selectedKey = null;
      manualPosition = null;
      _inPanel = false;
      revision++;
      notifyListeners();
    } else if (hoveredWasRemoved) {
      _scheduleClose();
    }
  }

  void dismissPreview() {
    _cancelCandidate();
    if (mode == ReminderDetailMode.preview) close(explicit: false);
  }

  void _cancelCandidate() {
    _openTimer?.cancel();
    _openTimer = null;
    _candidate = null;
  }

  @override
  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }
}
