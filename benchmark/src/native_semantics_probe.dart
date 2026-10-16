import 'dart:ui' as ui;

import 'package:flutter/semantics.dart';

/// Observes native/framework semantics without creating a semantics handle.
///
/// Framework notifications and the two native endpoints are recorded. This
/// does not intercept the engine callback or prove continuous native state.
class NativeSemanticsProbe {
  NativeSemanticsProbe({required this.requireStableNative})
    : _nativeStart = ui.PlatformDispatcher.instance.semanticsEnabled,
      _frameworkStart = SemanticsBinding.instance.semanticsEnabled {
    if (requireStableNative && _nativeStart != _frameworkStart) {
      throw StateError(
        'Native semantics must agree before Profile work: '
        'native=$_nativeStart framework=$_frameworkStart.',
      );
    }
    _binding.addSemanticsEnabledListener(_onFrameworkChanged);
  }

  final bool requireStableNative;
  final SemanticsBinding _binding = SemanticsBinding.instance;
  final bool _nativeStart;
  final bool _frameworkStart;
  final _observedChanges = <Map<String, bool>>[];
  late bool _nativeEnd;
  late bool _frameworkEnd;
  bool _closed = false;

  void _onFrameworkChanged() {
    _observedChanges.add({
      'native': ui.PlatformDispatcher.instance.semanticsEnabled,
      'framework': _binding.semanticsEnabled,
    });
  }

  void close() {
    if (_closed) return;
    _nativeEnd = ui.PlatformDispatcher.instance.semanticsEnabled;
    _frameworkEnd = _binding.semanticsEnabled;
    _binding.removeSemanticsEnabledListener(_onFrameworkChanged);
    _closed = true;
  }

  Map<String, Object> toJson() {
    if (!_closed) {
      throw StateError('Close the native semantics probe before reporting.');
    }
    if (requireStableNative &&
        (_nativeStart != _frameworkStart ||
            _nativeEnd != _frameworkEnd ||
            _nativeEnd != _nativeStart ||
            _frameworkEnd != _frameworkStart ||
            _observedChanges.isNotEmpty)) {
      throw StateError(
        'Native semantics changed during Profile work: '
        'native=$_nativeStart/$_nativeEnd '
        'framework=$_frameworkStart/$_frameworkEnd '
        'observedChanges=$_observedChanges.',
      );
    }
    return {
      'nativeStart': _nativeStart,
      'frameworkStart': _frameworkStart,
      'nativeEnd': _nativeEnd,
      'frameworkEnd': _frameworkEnd,
      'observedChanges': List<Map<String, bool>>.unmodifiable(_observedChanges),
    };
  }
}
